import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/frequency.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/bills/application/bills_providers.dart';
import 'package:montra_mobile/features/bills/data/bills_api.dart';
import 'package:montra_mobile/features/bills/domain/bill_display.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/recurring/domain/lifecycle.dart';
import 'package:montra_mobile/features/recurring/domain/recurring_display.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';
import 'package:montra_mobile/features/recurring/presentation/recurring_detail_screen.dart';

enum _OccChoice { pay, skip, open }

/// One bill: payment state, next due and last paid, its payments, and
/// actions (mark paid, skip, edit, pause, resume, archive, restore).
class BillDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [billId].
  const BillDetailScreen({required this.billId, super.key});

  /// The bill.
  final String billId;

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  bool _busy = false;

  BillsApi get _api => ref.read(billsApiProvider);

  Future<void> _guard(
    Future<void> Function() action, {
    required String done,
  }) async {
    if (_busy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() => _busy = true);
    try {
      await action();
      finance.bump();
      if (mounted) {
        showSnack(context, done);
      }
    } on ApiException catch (error) {
      final bool conflict = error.code == ErrorObjectCode.versionConflict;
      // A refused lifecycle move means the bill changed elsewhere: show
      // its current state with the explanation.
      if (conflict || isStaleStatus(error)) {
        ref.invalidate(billProvider(widget.billId));
      }
      if (mounted) {
        showSnack(
          context,
          conflict ? l10n.versionConflictReloaded : describeError(l10n, error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _act(BillAction action, BillDetail bill) async {
    final AppLocalizations l10n = context.l10n;
    if (action == BillAction.archive) {
      final bool ok = await showConfirmDialog(
        context,
        title: l10n.billArchiveConfirmTitle,
        body: l10n.billArchiveConfirmBody(bill.name),
        confirmLabel: l10n.billArchive,
        destructive: true,
      );
      if (!ok || !mounted) {
        return;
      }
    }
    await _guard(
      () => _api.act(bill.id, action, version: bill.version),
      done: switch (action) {
        BillAction.pause => l10n.billPausedDone,
        BillAction.resume => l10n.billResumedDone,
        BillAction.archive => l10n.billArchivedDone,
        BillAction.restore => l10n.billRestoredDone,
      },
    );
  }

  Future<void> _skip(BillDetail bill, OccurrenceDto occurrence) async {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final bool ok = await showConfirmDialog(
      context,
      title: l10n.billSkipConfirmTitle,
      body: l10n.billSkipConfirmBody(
        LocalDates.display(occurrence.effectiveDate, locale: locale),
      ),
      confirmLabel: l10n.billSkip,
    );
    if (ok && mounted) {
      await _guard(
        () => _api.skip(bill.id, occurrenceId: occurrence.id),
        done: l10n.billSkippedDone,
      );
    }
  }

  Future<void> _onOccurrence(BillDetail bill, OccurrenceDto o) async {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final bool canPay =
        bill.owned &&
        bill.status == BillDetailStatus.active &&
        isOpenOccurrence(o);
    final String? transactionId = o.transactionId;
    final List<SheetOption<_OccChoice>> options = <SheetOption<_OccChoice>>[
      if (canPay) ...<SheetOption<_OccChoice>>[
        SheetOption<_OccChoice>(
          value: _OccChoice.pay,
          label: l10n.billMarkPaid,
          icon: Icons.check_circle_outline,
        ),
        SheetOption<_OccChoice>(
          value: _OccChoice.skip,
          label: l10n.billSkip,
          icon: Icons.redo,
        ),
      ],
      if (transactionId != null)
        SheetOption<_OccChoice>(
          value: _OccChoice.open,
          label: l10n.occurrenceOpenTransaction,
          icon: Icons.receipt_outlined,
        ),
    ];
    if (options.isEmpty) {
      return;
    }
    final _OccChoice? choice = await showOptionSheet<_OccChoice>(
      context,
      title: l10n.occurrenceSheetTitle(
        LocalDates.display(o.effectiveDate, locale: locale),
      ),
      options: options,
    );
    if (choice == null || !mounted) {
      return;
    }
    switch (choice) {
      case _OccChoice.pay:
        await context.push(billPayLocation(bill.id, occurrenceId: o.id));
      case _OccChoice.skip:
        await _skip(bill, o);
      case _OccChoice.open:
        await context.push(AppRoutes.transactionDetail(transactionId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<BillDetail> bill = ref.watch(billProvider(widget.billId));
    final BillDetail? loaded = bill.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? l10n.billDetailTitle),
        bottom: _busy || (bill.isLoading && bill.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          if (loaded != null &&
              loaded.owned &&
              loaded.status != BillDetailStatus.archived)
            IconButton(
              tooltip: l10n.actionEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy
                  ? null
                  : () => context.push(AppRoutes.editBill(loaded.id)),
            ),
          if (loaded != null &&
              loaded.owned &&
              billActionsFor(loaded.status).isNotEmpty)
            PopupMenuButton<BillAction>(
              tooltip: l10n.actionMore,
              enabled: !_busy,
              onSelected: (BillAction a) => _act(a, loaded),
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<BillAction>>[
                    for (final BillAction a in billActionsFor(loaded.status))
                      PopupMenuItem<BillAction>(
                        value: a,
                        child: Text(switch (a) {
                          BillAction.pause => l10n.billPause,
                          BillAction.resume => l10n.billResume,
                          BillAction.archive => l10n.billArchive,
                          BillAction.restore => l10n.actionRestore,
                        }),
                      ),
                  ],
            ),
        ],
      ),
      body: AsyncValueView<BillDetail>(
        value: bill,
        onRetry: () => ref.invalidate(billProvider(widget.billId)),
        data: (BillDetail b) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(billProvider(widget.billId));
            try {
              await ref.read(billProvider(widget.billId).future);
            } on Object {
              // Shown by the screen state.
            }
          },
          child: _BillBody(
            bill: b,
            busy: _busy,
            onPay: (OccurrenceDto o) =>
                context.push(billPayLocation(b.id, occurrenceId: o.id)),
            onSkip: (OccurrenceDto o) => _skip(b, o),
            onOccurrence: (OccurrenceDto o) => _onOccurrence(b, o),
          ),
        ),
      ),
    );
  }
}

class _BillBody extends ConsumerWidget {
  const _BillBody({
    required this.bill,
    required this.busy,
    required this.onPay,
    required this.onSkip,
    required this.onOccurrence,
  });

  final BillDetail bill;
  final bool busy;
  final ValueChanged<OccurrenceDto> onPay;
  final ValueChanged<OccurrenceDto> onSkip;
  final ValueChanged<OccurrenceDto> onOccurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final (String stateText, StatusTone tone, IconData icon) = billStateLabel(
      l10n,
      bill.state.json,
    );
    final ScheduleValue schedule = ScheduleValue.fromRule(bill.schedule);
    final OccurrenceDto? next = bill.nextDue;
    final OccurrenceDto? last = bill.lastPaid;
    final Money? nextAmount = next?.amount ?? bill.expectedAmount;
    final bool canPay =
        bill.owned && bill.status == BillDetailStatus.active && next != null;
    final CategoryDto? category = bill.categoryId == null
        ? null
        : categories[bill.categoryId];
    final List<OccurrenceDto> history = bill.occurrences;
    final List<int> reminders = bill.schedule.reminderDaysBefore;
    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (bill.providerName case final String p when p.isNotEmpty)
                  Text(p, style: theme.textTheme.bodyMedium),
                StatusLabel(
                  text: stateText,
                  tone: tone,
                  icon: icon,
                  semanticsLabel: l10n.billStateSemantics(stateText),
                ),
                const SizedBox(height: Insets.sm),
                if (nextAmount != null && !bill.amountIsVariable)
                  MoneyText(nextAmount, style: theme.textTheme.headlineMedium)
                else
                  Text(l10n.billVaries, style: theme.textTheme.titleLarge),
                const SizedBox(height: Insets.sm),
                if (next != null)
                  Text(
                    l10n.billDueOn(
                      LocalDates.displayLong(
                        next.effectiveDate,
                        locale: locale,
                      ),
                    ),
                    style: theme.textTheme.bodyLarge,
                  ),
                if (last != null)
                  Text(
                    l10n.billLastPaidOn(
                      LocalDates.display(last.effectiveDate, locale: locale),
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                Text(
                  scheduleSummary(l10n, schedule, locale: locale),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        if (bill.status != BillDetailStatus.active) ...<Widget>[
          const SizedBox(height: Insets.md),
          NoticeBanner(
            message: bill.status == BillDetailStatus.paused
                ? l10n.billPausedNotice
                : l10n.billArchivedNotice,
          ),
        ] else if (!bill.owned) ...<Widget>[
          const SizedBox(height: Insets.md),
          NoticeBanner(message: l10n.billSharedReadOnly),
        ],
        if (canPay) ...<Widget>[
          const SizedBox(height: Insets.md),
          FilledButton.icon(
            onPressed: busy ? null : () => onPay(next),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(l10n.billMarkPaid),
          ),
          const SizedBox(height: Insets.sm),
          OutlinedButton.icon(
            onPressed: busy ? null : () => onSkip(next),
            icon: const Icon(Icons.redo),
            label: Text(l10n.billSkipThis),
          ),
        ],
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.billHistoryTitle,
          children: <Widget>[
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                child: Text(l10n.billNoHistory),
              )
            else
              for (final OccurrenceDto o in history)
                OccurrenceTile(
                  occurrence: o,
                  enabled: !busy,
                  onTap: () => onOccurrence(o),
                ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.billDetailsTitle,
          children: <Widget>[
            DetailRow(
              label: l10n.billPaymentAccountLabel,
              value: bill.paymentAccountId == null
                  ? l10n.billNoPaymentAccount
                  : accounts[bill.paymentAccountId]?.name ?? '—',
            ),
            if (category != null)
              DetailRow(
                label: l10n.categoryFieldLabel,
                value: categoryName(l10n, category),
              ),
            DetailRow(
              label: l10n.reminderDaysLabel,
              value: reminders.isEmpty
                  ? l10n.reminderNone
                  : <String>[
                      for (final int d in reminders)
                        reminderOffsetLabel(l10n, d),
                    ].join(', '),
            ),
            DetailRow(
              label: l10n.scheduleTitle,
              value: scheduleRange(l10n, schedule, locale: locale),
            ),
            if (bill.notes case final String n when n.isNotEmpty)
              DetailRow(label: l10n.notesLabel, value: n),
          ],
        ),
      ],
    );
  }
}
