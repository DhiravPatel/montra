import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_codes.dart';

/// Loaded pages of the receipt inbox.
@immutable
class ReceiptsListState {
  /// Creates the state.
  const ReceiptsListState({
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// Receipts loaded so far, newest first.
  final List<ReceiptDto> items;

  /// Cursor of the next page; null after the last page.
  final String? nextCursor;

  /// Whether the next page is being fetched.
  final bool loadingMore;

  /// Why the last "load more" failed (loaded receipts stay visible).
  final Object? loadMoreError;

  /// Whether more pages exist.
  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

/// The receipt inbox for a status filter (`''` = everything but discarded
/// receipts), page by page. Re-read from the first page after every finance
/// write.
final AsyncNotifierProviderFamily<
  ReceiptsListController,
  ReceiptsListState,
  String
>
receiptsProvider = AsyncNotifierProvider.autoDispose
    .family<ReceiptsListController, ReceiptsListState, String>(
      ReceiptsListController.new,
    );

/// See [receiptsProvider].
class ReceiptsListController extends AsyncNotifier<ReceiptsListState> {
  /// Creates the controller for [status] (`''` = the open inbox).
  ReceiptsListController(this.status);

  /// The status filter.
  final String status;

  ReceiptsApi get _api => ref.read(receiptsApiProvider);

  String? get _status => status.isEmpty ? null : status;

  @override
  Future<ReceiptsListState> build() async {
    ref.watch(financeRevisionProvider);
    final CursorPage<ReceiptDto> page = await _api.list(status: _status);
    return ReceiptsListState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Loads the next page, if any. Failures keep the loaded receipts and are
  /// reported in [ReceiptsListState.loadMoreError].
  Future<void> loadMore() async {
    final ReceiptsListState? current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        state.isLoading) {
      return;
    }
    state = AsyncData<ReceiptsListState>(
      ReceiptsListState(
        items: current.items,
        nextCursor: current.nextCursor,
        loadingMore: true,
      ),
    );
    try {
      final CursorPage<ReceiptDto> page = await _api.list(
        status: _status,
        cursor: current.nextCursor,
      );
      if (!ref.mounted) {
        return;
      }
      final Set<String> seen = <String>{
        for (final ReceiptDto r in current.items) r.id,
      };
      state = AsyncData<ReceiptsListState>(
        ReceiptsListState(
          items: <ReceiptDto>[
            ...current.items,
            for (final ReceiptDto r in page.items)
              if (!seen.contains(r.id)) r,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncData<ReceiptsListState>(
        ReceiptsListState(
          items: current.items,
          nextCursor: current.nextCursor,
          loadMoreError: error,
        ),
      );
    }
  }
}

/// One receipt with its pages, history and coded warnings.
final FutureProviderFamily<ReceiptView, String> receiptProvider = FutureProvider
    .autoDispose
    .family<ReceiptView, String>((Ref ref, String id) {
      ref.watch(financeRevisionProvider);
      return ref.read(receiptsApiProvider).get(id);
    });

/// Existing expenses that may be a receipt's purchase.
final FutureProviderFamily<List<ReceiptMatchCandidate>, String>
receiptCandidatesProvider = FutureProvider.autoDispose
    .family<List<ReceiptMatchCandidate>, String>((Ref ref, String id) {
      ref.watch(financeRevisionProvider);
      return ref.read(receiptsApiProvider).matchCandidates(id);
    });

/// The content of a private file (a receipt page or an attachment), fetched
/// through a short-lived signed link. Kept only while a screen shows it.
final FutureProviderFamily<DownloadedFile, String> privateFileProvider =
    FutureProvider.autoDispose.family<DownloadedFile, String>((
      Ref ref,
      String fileId,
    ) {
      return ref.read(fileDownloaderProvider).download(fileId);
    });
