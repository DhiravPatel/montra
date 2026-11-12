import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/imports/data/imports_api.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';

/// Import history page by page (`''` = every account). Re-read after
/// finance writes.
final AsyncNotifierProviderFamily<
  ImportsListController,
  PagedList<ImportBatchDto>,
  String
>
importsProvider = AsyncNotifierProvider.autoDispose
    .family<ImportsListController, PagedList<ImportBatchDto>, String>(
      ImportsListController.new,
    );

/// See [importsProvider].
class ImportsListController extends PagedListController<ImportBatchDto> {
  /// Creates the controller for [accountId] (`''` for every account).
  ImportsListController(this.accountId);

  /// The account filter.
  final String accountId;

  @override
  Future<PagedList<ImportBatchDto>> build() {
    ref.watch(financeRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<ImportBatchDto>> fetchPage(String? cursor) => ref
      .read(importsApiProvider)
      .list(accountId: accountId.isEmpty ? null : accountId, cursor: cursor);

  @override
  String keyOf(ImportBatchDto item) => item.id;
}

/// One import batch. The detail screen re-reads it while the server works
/// on it (see `ImportDetailScreen`).
final FutureProviderFamily<ImportBatchDto, String> importProvider =
    FutureProvider.autoDispose.family<ImportBatchDto, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(financeRevisionProvider);
      return ref.read(importsApiProvider).get(id);
    });

/// The first rows of an import, as read from the file (column choices).
final FutureProviderFamily<List<ImportRowDto>, String> importSampleProvider =
    FutureProvider.autoDispose.family<List<ImportRowDto>, String>((
      Ref ref,
      String id,
    ) async {
      final ImportRowPage page = await ref
          .read(importsApiProvider)
          .rows(id, limit: 12);
      return page.rows;
    });

/// Which rows to list: an import and an optional status.
typedef ImportRowsQuery = ({String importId, String? status});

/// Loaded pages of an import's rows.
@immutable
class ImportRowsState {
  /// Creates the state.
  const ImportRowsState({
    required this.rows,
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// Rows loaded so far, in file order.
  final List<ImportRowDto> rows;

  /// `after_row` for the next page; null after the last page.
  final int? nextCursor;

  /// Whether the next page is being fetched.
  final bool loadingMore;

  /// Why the last "load more" failed (loaded rows stay visible).
  final Object? loadMoreError;

  /// Whether more rows exist.
  bool get hasMore => nextCursor != null;

  /// A copy with [row] replaced (after a correction or decision).
  ImportRowsState replace(ImportRowDto row) => ImportRowsState(
    rows: <ImportRowDto>[
      for (final ImportRowDto r in rows) r.id == row.id ? row : r,
    ],
    nextCursor: nextCursor,
  );
}

/// An import's rows, page by page (keyset on the row number).
final AsyncNotifierProviderFamily<
  ImportRowsController,
  ImportRowsState,
  ImportRowsQuery
>
importRowsProvider = AsyncNotifierProvider.autoDispose
    .family<ImportRowsController, ImportRowsState, ImportRowsQuery>(
      ImportRowsController.new,
    );

/// See [importRowsProvider].
class ImportRowsController extends AsyncNotifier<ImportRowsState> {
  /// Creates the controller for [query].
  ImportRowsController(this.query);

  /// The import and status.
  final ImportRowsQuery query;

  ImportsApi get _api => ref.read(importsApiProvider);

  @override
  Future<ImportRowsState> build() async {
    ref.watch(financeRevisionProvider);
    final ImportRowPage page = await _api.rows(
      query.importId,
      status: query.status,
    );
    return ImportRowsState(rows: page.rows, nextCursor: page.nextCursor);
  }

  /// Loads the next page, if any.
  Future<void> loadMore() async {
    final ImportRowsState? current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        state.isLoading) {
      return;
    }
    state = AsyncData<ImportRowsState>(
      ImportRowsState(
        rows: current.rows,
        nextCursor: current.nextCursor,
        loadingMore: true,
      ),
    );
    try {
      final ImportRowPage page = await _api.rows(
        query.importId,
        status: query.status,
        afterRow: current.nextCursor,
      );
      if (!ref.mounted) {
        return;
      }
      final Set<String> seen = <String>{
        for (final ImportRowDto r in current.rows) r.id,
      };
      state = AsyncData<ImportRowsState>(
        ImportRowsState(
          rows: <ImportRowDto>[
            ...current.rows,
            for (final ImportRowDto r in page.rows)
              if (!seen.contains(r.id)) r,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncData<ImportRowsState>(
        ImportRowsState(
          rows: current.rows,
          nextCursor: current.nextCursor,
          loadMoreError: error,
        ),
      );
    }
  }

  /// Puts the server's copy of a changed row in the list.
  void replace(ImportRowDto row) {
    final ImportRowsState? current = state.value;
    if (current != null) {
      state = AsyncData<ImportRowsState>(current.replace(row));
    }
  }
}
