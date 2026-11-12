import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_widgets.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/receipts/application/receipts_providers.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_display.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';

/// Receipt inbox (`GET /receipts`, page by page), filtered by status, with
/// "Add receipt": a photo or a file is uploaded (`receipt` purpose), the
/// receipt is created for manual entry with an Idempotency-Key, and its page
/// opens. Nothing is read automatically. If creating it fails, the uploaded
/// file and the key are kept so "Try again" cannot add it twice.
class ReceiptsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ReceiptsScreen({super.key});

  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> {
  final IdempotentSubmission _createKey = IdempotentSubmission();
  String _filter = '';
  bool _adding = false;

  /// An uploaded page whose receipt could not be created yet.
  FileDto? _pending;

  /// Why creating the receipt for [_pending] failed.
  Object? _pendingError;

  Future<void> _add() async {
    if (_adding) {
      return;
    }
    final PickedFile? picked = await pickFileFor(
      context,
      ref,
      purpose: UploadPurpose.receipt,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _adding = true);
    try {
      final FileDto? file = await uploadWithProgress(
        context,
        file: picked,
        purpose: UploadPurpose.receipt,
      );
      if (file == null || !mounted) {
        return;
      }
      _createKey.reset();
      await _create(file);
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  /// Creates the receipt for [file]; the same key is used until it
  /// succeeds, so a retry after a lost answer returns the first receipt.
  Future<void> _create(FileDto file) async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    final List<String> fileIds = <String>[file.id];
    setState(() {
      _pending = file;
      _pendingError = null;
    });
    try {
      final ReceiptDto receipt = await ref
          .read(receiptsApiProvider)
          .create(
            fileIds,
            key: _createKey.keyFor(<String, Object?>{'file_ids': fileIds}),
          );
      _createKey.reset();
      ref.financeChanged();
      if (!mounted) {
        return;
      }
      setState(() => _pending = null);
      showSnack(context, l10n.receiptAdded);
      await router.push(AppRoutes.receiptDetail(receipt.id));
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _createKey.reset();
      }
      if (mounted) {
        setState(() => _pendingError = error);
      }
    }
  }

  Future<void> _retryPending() async {
    final FileDto? file = _pending;
    if (file == null || _adding) {
      return;
    }
    setState(() => _adding = true);
    try {
      await _create(file);
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  void _dropPending() => setState(() {
    _pending = null;
    _pendingError = null;
    _createKey.reset();
  });

  Future<void> _refresh() async {
    ref.invalidate(receiptsProvider(_filter));
    try {
      await ref.read(receiptsProvider(_filter).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ReceiptsListState> receipts = ref.watch(
      receiptsProvider(_filter),
    );
    final Object? pendingError = _pendingError;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.receiptsTitle),
        bottom: _adding || (receipts.isLoading && receipts.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _adding ? null : _add,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(l10n.receiptAdd),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_pending != null && pendingError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                0,
              ),
              child: NoticeBanner(
                tone: NoticeTone.error,
                title: l10n.receiptAddFailedTitle,
                message: describeError(l10n, pendingError),
                requestId: requestIdOf(pendingError),
                action: Wrap(
                  spacing: Insets.sm,
                  children: <Widget>[
                    TextButton(
                      onPressed: _adding ? null : _dropPending,
                      child: Text(l10n.receiptAddForget),
                    ),
                    FilledButton(
                      onPressed: _adding ? null : _retryPending,
                      child: Text(l10n.actionRetry),
                    ),
                  ],
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              Insets.xs,
            ),
            child: Row(
              children: <Widget>[
                for (final String f in receiptFilters)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Insets.sm),
                    child: ChoiceChip(
                      label: Text(receiptFilterLabel(l10n, f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<ReceiptsListState>(
              value: receipts,
              onRetry: () => ref.invalidate(receiptsProvider(_filter)),
              isEmpty: (ReceiptsListState s) => s.items.isEmpty,
              empty: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    SizedBox(
                      height: 420,
                      child: MessageStateView(
                        icon: Icons.receipt_outlined,
                        title: _filter.isEmpty
                            ? l10n.receiptsEmptyTitle
                            : l10n.receiptsEmptyFiltered,
                        body: l10n.receiptsEmptyBody,
                      ),
                    ),
                  ],
                ),
              ),
              data: (ReceiptsListState s) => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: s.items.length + 2,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Insets.md,
                          Insets.xs,
                          Insets.md,
                          Insets.sm,
                        ),
                        child: Text(
                          l10n.receiptsManualNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    if (index == s.items.length + 1) {
                      return _LoadMore(
                        state: s,
                        onLoadMore: () => ref
                            .read(receiptsProvider(_filter).notifier)
                            .loadMore(),
                      );
                    }
                    return ReceiptTile(receipt: s.items[index - 1]);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({required this.state, required this.onLoadMore});

  final ReceiptsListState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(Insets.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final Object? error = state.loadMoreError;
    if (!state.hasMore && error == null) {
      return const SizedBox(height: Insets.md);
    }
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        children: <Widget>[
          if (error != null)
            Text(describeError(l10n, error), textAlign: TextAlign.center),
          OutlinedButton(
            onPressed: onLoadMore,
            child: Text(l10n.actionLoadMore),
          ),
        ],
      ),
    );
  }
}

/// One receipt in the inbox: merchant, date and total as entered, status in
/// words and a duplicate warning.
class ReceiptTile extends StatelessWidget {
  /// Creates the tile.
  const ReceiptTile({required this.receipt, super.key});

  /// The receipt.
  final ReceiptDto receipt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final ReceiptExtractionDto? current = receipt.current;
    final String status = receipt.status.json;
    final String? date = current?.receiptDate;
    final Money? total = current?.total;
    return ListTile(
      onTap: () => context.push(AppRoutes.receiptDetail(receipt.id)),
      leading: const CircleAvatar(
        child: ExcludeSemantics(child: Icon(Icons.receipt_outlined)),
      ),
      title: Text(receiptTitle(l10n, current)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xs),
          if (date == null && total == null)
            Text(l10n.receiptNoDetails)
          else
            Wrap(
              spacing: Insets.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (date != null)
                  Text(LocalDates.display(date, locale: locale)),
                if (total != null) MoneyText(total, label: l10n.receiptTotal),
              ],
            ),
          if (receipt.files.length > 1)
            Text(l10n.receiptPages(receipt.files.length)),
          const SizedBox(height: Insets.xs),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              StatusLabel(
                text: receiptStatusLabel(l10n, status),
                tone: receiptStatusTone(status),
                icon: receiptStatusIcon(status),
              ),
              if (receipt.duplicateOfId != null)
                StatusLabel(
                  text: l10n.receiptPossibleDuplicate,
                  tone: StatusTone.caution,
                  icon: Icons.content_copy_outlined,
                ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
