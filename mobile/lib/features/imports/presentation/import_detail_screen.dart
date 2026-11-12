import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/imports/application/imports_providers.dart';
import 'package:montra_mobile/features/imports/data/imports_api.dart';
import 'package:montra_mobile/features/imports/domain/import_display.dart';

enum _ImportAction {
  mapping,
  rows,
  failedRows,
  confirm,
  cancel,
  retry,
  rollback,
}

/// One statement import: status in words (re-read every few seconds while
/// the server reads or imports the file), counts and balance check from the
/// server, and the next step: choose the columns, review the rows and
/// confirm (Idempotency-Key), or after the import retry failed rows,
/// cancel, or roll back (confirmed).
class ImportDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [importId].
  const ImportDetailScreen({required this.importId, super.key});

  /// The import.
  final String importId;

  /// How often the screen re-reads a working import at first; it slows down
  /// after a while ([pollDelay]).
  static const Duration pollInterval = Duration(seconds: 2);

  /// The longest the screen keeps re-reading on its own (the user can still
  /// pull to refresh).
  static const Duration pollLimit = Duration(minutes: 10);

  /// Delay before re-read number [attempt] (0-based).
  static Duration pollDelay(int attempt) => attempt < 15
      ? pollInterval
      : (attempt < 45
            ? const Duration(seconds: 5)
            : const Duration(seconds: 15));

  @override
  ConsumerState<ImportDetailScreen> createState() => _ImportDetailScreenState();
}

class _ImportDetailScreenState extends ConsumerState<ImportDetailScreen> {
  final IdempotentSubmission _confirmKey = IdempotentSubmission();
  Timer? _poll;
  int _attempts = 0;
  Duration _waited = Duration.zero;
  bool _pollStopped = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<ImportBatchDto>>(
      importProvider(widget.importId),
      _onBatch,
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _onBatch(
    AsyncValue<ImportBatchDto>? previous,
    AsyncValue<ImportBatchDto> next,
  ) {
    final ImportBatchDto? before = previous?.value;
    final ImportBatchDto? now = next.value;
    if (now == null) {
      return;
    }
    // Importing or rolling back finished: transactions were created or
    // voided, so balances and lists are re-read.
    if (before != null &&
        (before.status == ImportBatchDtoStatus.confirmed ||
            before.status == ImportBatchDtoStatus.processing) &&
        !importIsWorking(now)) {
      ref.financeChanged();
    }
    _schedule(now);
  }

  /// Rebuilds after the current frame (the listener can run during build).
  void _rebuildLater() => scheduleMicrotask(() {
    if (mounted) {
      setState(() {});
    }
  });

  void _schedule(ImportBatchDto batch) {
    if (!importIsWorking(batch)) {
      _poll?.cancel();
      _poll = null;
      _attempts = 0;
      _waited = Duration.zero;
      if (_pollStopped) {
        _pollStopped = false;
        _rebuildLater();
      }
      return;
    }
    if (_poll != null || _pollStopped) {
      return;
    }
    final Duration delay = ImportDetailScreen.pollDelay(_attempts);
    if (_waited + delay > ImportDetailScreen.pollLimit) {
      _pollStopped = true;
      _rebuildLater();
      return;
    }
    _poll = Timer(delay, () {
      _poll = null;
      _attempts++;
      _waited += delay;
      if (mounted) {
        ref.invalidate(importProvider(widget.importId));
      }
    });
  }

  Future<void> _refresh() async {
    if (_pollStopped) {
      setState(() {
        _pollStopped = false;
        _attempts = 0;
        _waited = Duration.zero;
      });
    }
    ref.invalidate(importProvider(widget.importId));
    try {
      await ref.read(importProvider(widget.importId).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  Future<void> _run(_ImportAction action, ImportBatchDto b) async {
    final AppLocalizations l10n = context.l10n;
    final ImportsApi api = ref.read(importsApiProvider);
    switch (action) {
      case _ImportAction.mapping:
        await context.push(AppRoutes.importMapping(b.id));
        return;
      case _ImportAction.rows:
        await context.push(AppRoutes.importRows(b.id));
        return;
      case _ImportAction.failedRows:
        await context.push(AppRoutes.importRows(b.id, status: 'failed'));
        return;
      case _ImportAction.confirm:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.importConfirmTitle,
          body: l10n.importConfirmBodyCount(b.toImportRows, _accountName(b)),
          confirmLabel: l10n.importConfirmAction,
        );
        if (!ok || !mounted) {
          return;
        }
        final String key = _confirmKey.keyFor(<String, Object?>{
          'import': b.id,
          'version': b.version,
        });
        await _write(
          () => api.confirm(b.id, version: b.version, key: key),
          l10n.importConfirmed,
          onSuccess: _confirmKey.reset,
          onIdempotencyConflict: _confirmKey.reset,
        );
        return;
      case _ImportAction.cancel:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.importCancelTitle,
          body: b.status == ImportBatchDtoStatus.processing
              ? l10n.importCancelProcessingBody
              : l10n.importCancelBody,
          confirmLabel: l10n.importCancelAction,
          destructive: true,
        );
        if (ok && mounted) {
          await _write(() => api.cancel(b.id), l10n.importCancelled);
        }
        return;
      case _ImportAction.retry:
        await _write(() => api.retryFailed(b.id), l10n.importRetrying);
        return;
      case _ImportAction.rollback:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.importRollbackTitle,
          body: l10n.importRollbackBody(b.importedCount),
          confirmLabel: l10n.importRollbackAction,
          destructive: true,
        );
        if (ok && mounted) {
          await _write(() => api.rollback(b.id), l10n.importRollingBack);
        }
        return;
    }
  }

  Future<void> _write(
    Future<ImportBatchDto> Function() call,
    String done, {
    VoidCallback? onSuccess,
    VoidCallback? onIdempotencyConflict,
  }) async {
    final AppLocalizations l10n = context.l10n;
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await call();
      onSuccess?.call();
      ref.financeChanged();
      if (mounted) {
        showSnack(context, done);
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        onIdempotencyConflict?.call();
      }
      if (error.code == ErrorObjectCode.versionConflict) {
        ref.invalidate(importProvider(widget.importId));
      }
      if (mounted) {
        showSnack(
          context,
          error.code == ErrorObjectCode.versionConflict
              ? l10n.versionConflictReloaded
              : describeError(l10n, error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _accountName(ImportBatchDto b) =>
      ref.read(accountIndexProvider)[b.accountId]?.name ??
      context.l10n.importUnknownAccount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ImportBatchDto> batch = ref.watch(
      importProvider(widget.importId),
    );
    final ImportBatchDto? b = batch.value;
    final bool working = b != null && importIsWorking(b);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.importDetailTitle),
        bottom: _busy || working || (batch.isLoading && batch.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: AsyncValueView<ImportBatchDto>(
        value: batch,
        onRetry: () => ref.invalidate(importProvider(widget.importId)),
        data: (ImportBatchDto b) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(Insets.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              _StatusCard(
                batch: b,
                busy: _busy,
                onAction: (_ImportAction a) => _run(a, b),
              ),
              if (_pollStopped && importIsWorking(b)) ...<Widget>[
                const SizedBox(height: Insets.md),
                NoticeBanner(
                  message: l10n.importStillWorking,
                  action: TextButton(
                    onPressed: _refresh,
                    child: Text(l10n.actionRetry),
                  ),
                ),
              ],
              if (b.previousImportOfFile
                  case final String previous) ...<Widget>[
                const SizedBox(height: Insets.md),
                NoticeBanner(
                  tone: NoticeTone.warning,
                  message: l10n.importPreviousFile,
                  action: TextButton(
                    onPressed: () =>
                        context.push(AppRoutes.importDetail(previous)),
                    child: Text(l10n.importOpenPrevious),
                  ),
                ),
              ],
              if (importMappingNotes(l10n, b) case final List<String> notes
                  when notes.isNotEmpty &&
                      (b.status == ImportBatchDtoStatus.needsMapping ||
                          b.status ==
                              ImportBatchDtoStatus.previewReady)) ...<Widget>[
                const SizedBox(height: Insets.md),
                NoticeBanner(
                  title: l10n.importNotesTitle,
                  message: notes.join('\n'),
                ),
              ],
              const SizedBox(height: Insets.md),
              _Summary(batch: b),
              if (b.totals != null) ...<Widget>[
                const SizedBox(height: Insets.md),
                _Totals(batch: b),
              ],
              const SizedBox(height: Insets.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.batch,
    required this.busy,
    required this.onAction,
  });

  final ImportBatchDto batch;
  final bool busy;
  final ValueChanged<_ImportAction> onAction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ImportBatchDto b = batch;
    final String? error = importErrorText(l10n, b);
    VoidCallback? act(_ImportAction a) => busy ? null : () => onAction(a);
    final List<Widget> actions = <Widget>[
      if (b.status == ImportBatchDtoStatus.needsMapping)
        FilledButton.icon(
          onPressed: act(_ImportAction.mapping),
          icon: const Icon(Icons.view_column_outlined),
          label: Text(l10n.importChooseColumns),
        ),
      if (b.status == ImportBatchDtoStatus.previewReady) ...<Widget>[
        FilledButton.icon(
          onPressed: b.toImportRows > 0 ? act(_ImportAction.confirm) : null,
          icon: const Icon(Icons.download_done),
          label: Text(l10n.importConfirmCount(b.toImportRows)),
        ),
        OutlinedButton.icon(
          onPressed: act(_ImportAction.rows),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(l10n.importReviewRows),
        ),
        TextButton.icon(
          onPressed: act(_ImportAction.mapping),
          icon: const Icon(Icons.view_column_outlined),
          label: Text(l10n.importChangeColumns),
        ),
      ],
      if (b.status == ImportBatchDtoStatus.completedWithErrors) ...<Widget>[
        FilledButton.icon(
          onPressed: act(_ImportAction.failedRows),
          icon: const Icon(Icons.edit_note),
          label: Text(l10n.importReviewFailed),
        ),
        OutlinedButton.icon(
          onPressed: act(_ImportAction.retry),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.importRetryFailed),
        ),
      ],
      if (b.status == ImportBatchDtoStatus.completed ||
          b.status == ImportBatchDtoStatus.completedWithErrors)
        OutlinedButton.icon(
          onPressed: act(_ImportAction.rows),
          icon: const Icon(Icons.list_alt),
          label: Text(l10n.importSeeRows),
        ),
      if ((b.status == ImportBatchDtoStatus.completed ||
              b.status == ImportBatchDtoStatus.completedWithErrors) &&
          (b.statementClosingBalance != null || b.totals != null))
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => context.push(
                  AppRoutes.newReconciliation(b.accountId, importBatchId: b.id),
                ),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(l10n.importCheckStatement),
        ),
      if (b.importedCount > 0 &&
          (b.status == ImportBatchDtoStatus.completed ||
              b.status == ImportBatchDtoStatus.completedWithErrors ||
              b.status == ImportBatchDtoStatus.cancelled))
        TextButton.icon(
          onPressed: act(_ImportAction.rollback),
          icon: const Icon(Icons.undo),
          label: Text(l10n.importRollbackAction),
        ),
      if (b.status == ImportBatchDtoStatus.failed)
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => context.pushReplacement(
                  AppRoutes.newImportFor(accountId: b.accountId),
                ),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(l10n.importTryAnotherFile),
        ),
      if (importIsWorking(b) && !b.cancelRequested ||
          b.status == ImportBatchDtoStatus.needsMapping ||
          b.status == ImportBatchDtoStatus.previewReady)
        TextButton.icon(
          onPressed: act(_ImportAction.cancel),
          icon: const Icon(Icons.close),
          label: Text(l10n.importCancelAction),
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              liveRegion: true,
              child: StatusLabel(
                text: importStatusLabel(l10n, b.status),
                tone: importStatusTone(b.status),
                icon: importStatusIcon(b.status),
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(importStatusHelp(l10n, b.status)),
            if (b.cancelRequested && importIsWorking(b)) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(l10n.importCancelRequested),
            ],
            if (b.status == ImportBatchDtoStatus.previewReady &&
                b.toImportRows == 0) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(l10n.importNothingToImport),
            ],
            if (error != null) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(
                error,
                style: b.status == ImportBatchDtoStatus.failed
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
            ],
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.md),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.batch});

  final ImportBatchDto batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final ImportBatchDto b = batch;
    final AccountDto? account = ref.watch(accountIndexProvider)[b.accountId];
    final bool done =
        b.status == ImportBatchDtoStatus.completed ||
        b.status == ImportBatchDtoStatus.completedWithErrors ||
        b.status == ImportBatchDtoStatus.cancelled;
    return SectionCard(
      title: l10n.importSummaryTitle,
      children: <Widget>[
        DetailRow(
          label: l10n.importAccountLabel,
          value: account?.name ?? l10n.importUnknownAccount,
          onTap: () => context.push(AppRoutes.accountDetail(b.accountId)),
        ),
        if (b.sourceFormat case final ImportBatchDtoSourceFormat format)
          DetailRow(
            label: l10n.importFormatLabel,
            value: format.json.toUpperCase(),
          ),
        DetailRow(
          label: l10n.importStartedLabel,
          value: formatDateTime(b.createdAt, locale: locale),
        ),
        if (b.statementStart != null && b.statementEnd != null)
          DetailRow(
            label: l10n.importPeriodLabel,
            value: LocalDates.displayRange(
              b.statementStart!,
              b.statementEnd!,
              locale: locale,
            ),
          ),
        if (b.totalRows > 0) ...<Widget>[
          DetailRow(label: l10n.importRowsInFile, value: '${b.totalRows}'),
          if (b.status == ImportBatchDtoStatus.previewReady ||
              importIsWorking(b))
            DetailRow(
              label: l10n.importRowsToImportLabel,
              value: '${b.toImportRows}',
            ),
          DetailRow(label: l10n.importRowsValid, value: '${b.validRows}'),
          if (b.invalidRows > 0)
            DetailRow(
              label: l10n.importRowsNeedFixing,
              value: '${b.invalidRows}',
            ),
          if (b.duplicateRows > 0)
            DetailRow(
              label: l10n.importRowsPossibleDuplicates,
              value: '${b.duplicateRows}',
            ),
        ],
        if (done || b.importedCount > 0) ...<Widget>[
          DetailRow(
            label: l10n.importRowsImportedLabel,
            value: '${b.importedCount}',
          ),
          DetailRow(
            label: l10n.importRowsSkippedLabel,
            value: '${b.skippedCount}',
          ),
          if (b.failedCount > 0)
            DetailRow(
              label: l10n.importRowsFailedLabel,
              value: '${b.failedCount}',
            ),
        ],
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.batch});

  final ImportBatchDto batch;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ImportBatchDto b = batch;
    final RowTotals t = b.totals!;
    Widget row(String label, Money? m, {MoneyFlow flow = MoneyFlow.none}) =>
        m == null
        ? const SizedBox.shrink()
        : DetailRow(
            label: label,
            child: MoneyText(m, flow: flow, label: label),
          );
    final (
      String check,
      StatusTone tone,
      IconData icon,
    ) = switch (t.balanceCheck) {
      RowTotalsBalanceCheck.ok => (
        l10n.importBalanceOk,
        StatusTone.positive,
        Icons.check_circle_outline,
      ),
      RowTotalsBalanceCheck.mismatch => (
        l10n.importBalanceMismatch,
        StatusTone.caution,
        Icons.error_outline,
      ),
      _ => (
        l10n.importBalanceNotAvailable,
        StatusTone.neutral,
        Icons.info_outline,
      ),
    };
    return SectionCard(
      title: l10n.importTotalsTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusLabel(text: check, tone: tone, icon: icon),
          ),
        ),
        if (t.mismatchedRows case final List<int> rows when rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(l10n.importMismatchedRows(rows.join(', '))),
          ),
        row(l10n.importTotalIn, t.inflow, flow: MoneyFlow.inflow),
        row(l10n.importTotalOut, t.outflow, flow: MoneyFlow.outflow),
        row(l10n.importTotalNet, t.net),
        row(
          l10n.importOpeningBalance,
          t.openingBalance ?? b.statementOpeningBalance,
        ),
        row(
          l10n.importClosingBalance,
          t.closingBalance ?? b.statementClosingBalance,
        ),
      ],
    );
  }
}
