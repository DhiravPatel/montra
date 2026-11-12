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
import 'package:montra_mobile/core/formatting/frequency.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/recurring/application/recurring_providers.dart';
import 'package:montra_mobile/features/recurring/data/recurring_api.dart';
import 'package:montra_mobile/features/recurring/domain/lifecycle.dart';
import 'package:montra_mobile/features/recurring/domain/recurring_display.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';
import 'package:montra_mobile/features/recurring/presentation/occurrence_sheets.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_picker.dart';

enum _RuleAction { edit, pause, resume, skipNext, stop, delete }

enum _OccAction { confirm, link, setAmount, postpone, skip, reopen, open }

/// One recurring rule: what it records and when, its upcoming and past
/// occurrences, and actions on both (record, link, skip, postpone, change
/// the amount, reopen; pause, resume, skip next, stop, delete).
class RecurringDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [ruleId].
  const RecurringDetailScreen({required this.ruleId, super.key});

  /// The rule.
  final String ruleId;

  @override
  ConsumerState<RecurringDetailScreen> createState() =>
      _RecurringDetailScreenState();
}

class _RecurringDetailScreenState extends ConsumerState<RecurringDetailScreen> {
  final IdempotentSubmission _submission = IdempotentSubmission();
  bool _busy = false;

  RecurringApi get _api => ref.read(recurringApiProvider);

  /// Runs [action], refreshes finance data and shows [done]; failures are
  /// explained in a snack bar.
  Future<bool> _guard(
    Future<void> Function() action, {
    required String Function() done,
  }) async {
    if (_busy) {
      return false;
    }
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() => _busy = true);
    try {
      await action();
      finance.bump();
      if (mounted) {
        showSnack(context, done());
      }
      return true;
    } on ApiException catch (error) {
      // A stale version or a lifecycle move that no longer fits: the rule
      // changed elsewhere, so show its current state.
      if (isVersionConflict(error) || isStaleStatus(error)) {
        ref.invalidate(recurringRuleProvider(widget.ruleId));
      }
      if (mounted) {
        showSnack(context, _errorText(l10n, error));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _errorText(AppLocalizations l10n, ApiException error) {
    if (error.code == ErrorObjectCode.versionConflict) {
      return l10n.versionConflictReloaded;
    }
    if (error.details.any((Detail d) => d.code == 'use_bill_screen')) {
      return l10n.recurringManagedByBill;
    }
    return describeError(l10n, error);
  }

  Future<void> _runRule(_RuleAction action, RecurringRuleDetail rule) async {
    final AppLocalizations l10n = context.l10n;
    switch (action) {
      case _RuleAction.edit:
        await context.push(AppRoutes.editRecurring(rule.id));
      case _RuleAction.pause:
        await _guard(
          () => _api.pause(rule.id, version: rule.version),
          done: () => l10n.recurringPaused,
        );
      case _RuleAction.resume:
        await _guard(
          () => _api.resume(rule.id, version: rule.version),
          done: () => l10n.recurringResumed,
        );
      case _RuleAction.skipNext:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.recurringSkipNextConfirmTitle,
          body: l10n.recurringSkipNextConfirmBody(rule.name),
          confirmLabel: l10n.recurringSkipNext,
        );
        if (ok && mounted) {
          await _guard(
            () => _api.skipNext(rule.id, version: rule.version),
            done: () => l10n.recurringSkippedNext,
          );
        }
      case _RuleAction.stop:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.recurringStopConfirmTitle,
          body: l10n.recurringStopConfirmBody(rule.name),
          confirmLabel: l10n.recurringStop,
          destructive: true,
        );
        if (ok && mounted) {
          await _guard(
            () => _api.stop(rule.id, version: rule.version),
            done: () => l10n.recurringStopped,
          );
        }
      case _RuleAction.delete:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.recurringDeleteConfirmTitle,
          body: l10n.recurringDeleteConfirmBody(rule.name),
          confirmLabel: l10n.actionDelete,
          destructive: true,
        );
        if (!ok || !mounted) {
          return;
        }
        RecurringDeleteResultOutcome? outcome;
        await _guard(
          () async => outcome = (await _api.delete(rule.id)).outcome,
          done: () => outcome == RecurringDeleteResultOutcome.deleted
              ? l10n.recurringDeleted
              : l10n.recurringEndedKept,
        );
        if (outcome == RecurringDeleteResultOutcome.deleted && mounted) {
          context.pop();
        }
    }
  }

  Future<void> _act(OccurrenceDto o, OccurrenceAction action) async {
    final AppLocalizations l10n = context.l10n;
    final Map<String, Object?> body = <String, Object?>{
      'occurrence': o.id,
      ...action.toJson(),
    };
    final bool ok = await _guard(
      () => _api.act(o.id, action, key: _submission.keyFor(body)),
      done: () => switch (action.action) {
        OccurrenceActionAction.confirm => l10n.occurrenceRecorded,
        OccurrenceActionAction.linkTransaction => l10n.occurrenceLinked,
        OccurrenceActionAction.skip => l10n.occurrenceSkipped,
        OccurrenceActionAction.postpone => l10n.occurrencePostponed,
        OccurrenceActionAction.setAmount => l10n.occurrenceAmountSet,
        OccurrenceActionAction.reopen => l10n.occurrenceReopened,
        OccurrenceActionAction.unrecognized => l10n.occurrenceUpdated,
      },
    );
    if (ok) {
      _submission.reset();
    }
  }

  Future<void> _onOccurrence(OccurrenceDto o, RecurringRuleDetail rule) async {
    final AppLocalizations l10n = context.l10n;
    final bool open = isOpenOccurrence(o);
    final bool canAct = rule.owned && isManagedHere(rule.kind.json);
    final String? transactionId = o.transactionId;
    final List<SheetOption<_OccAction>> options = <SheetOption<_OccAction>>[
      if (open && canAct) ...<SheetOption<_OccAction>>[
        SheetOption<_OccAction>(
          value: _OccAction.confirm,
          label: l10n.occurrenceConfirm,
          subtitle: l10n.occurrenceConfirmHelp,
          icon: Icons.check_circle_outline,
        ),
        SheetOption<_OccAction>(
          value: _OccAction.link,
          label: l10n.occurrenceLink,
          subtitle: l10n.occurrenceLinkHelp,
          icon: Icons.link,
        ),
        SheetOption<_OccAction>(
          value: _OccAction.setAmount,
          label: l10n.occurrenceSetAmount,
          icon: Icons.edit_outlined,
        ),
        SheetOption<_OccAction>(
          value: _OccAction.postpone,
          label: l10n.occurrencePostpone,
          icon: Icons.update,
        ),
        SheetOption<_OccAction>(
          value: _OccAction.skip,
          label: l10n.occurrenceSkip,
          icon: Icons.redo,
        ),
      ],
      if (!open && canAct && o.status == OccurrenceDtoStatus.skipped)
        SheetOption<_OccAction>(
          value: _OccAction.reopen,
          label: l10n.occurrenceReopen,
          icon: Icons.undo,
        ),
      if (transactionId != null)
        SheetOption<_OccAction>(
          value: _OccAction.open,
          label: l10n.occurrenceOpenTransaction,
          icon: Icons.receipt_outlined,
        ),
    ];
    if (options.isEmpty) {
      return;
    }
    final String locale = Localizations.localeOf(context).toString();
    final _OccAction? choice = await showOptionSheet<_OccAction>(
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
      case _OccAction.open:
        await context.push(AppRoutes.transactionDetail(transactionId!));
      case _OccAction.confirm:
        final ConfirmChoice? c = await showConfirmOccurrenceSheet(
          context,
          occurrence: o,
          needsAmount: o.amount == null,
          needsAccount: rule.accountId == null,
          currency: rule.currency,
        );
        if (c != null && mounted) {
          await _act(
            o,
            OccurrenceAction(
              action: OccurrenceActionAction.confirm,
              amount: c.amount,
              date: c.date,
              accountId: c.accountId,
            ),
          );
        }
      case _OccAction.link:
        final TransactionDto? t = await showTransactionPicker(
          context,
          title: l10n.occurrenceLinkTitle,
          filter: TransactionFilter(
            types: <String>{
              if (rule.kind == RecurringRuleDetailKind.income) 'income',
              if (rule.kind == RecurringRuleDetailKind.transfer) 'transfer',
              if (rule.kind != RecurringRuleDetailKind.income &&
                  rule.kind != RecurringRuleDetailKind.transfer)
                'expense',
            },
          ),
        );
        if (t != null && mounted) {
          await _act(
            o,
            OccurrenceAction(
              action: OccurrenceActionAction.linkTransaction,
              transactionId: t.id,
            ),
          );
        }
      case _OccAction.setAmount:
        final String? amount = await showOccurrenceAmountSheet(
          context,
          initial: o.amount?.amount,
          currency: o.amount?.currency ?? rule.currency,
        );
        if (amount != null && mounted) {
          await _act(
            o,
            OccurrenceAction(
              action: OccurrenceActionAction.setAmount,
              amount: amount,
            ),
          );
        }
      case _OccAction.postpone:
        final DateTime today = LocalDates.today();
        final DateTime current = LocalDates.parse(o.effectiveDate) ?? today;
        final DateTime initial = current.isBefore(today)
            ? today
            : current.add(const Duration(days: 1));
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: today,
          lastDate: DateTime(today.year + 2, 12, 31),
          helpText: l10n.occurrencePostponeTitle,
        );
        if (picked != null && mounted) {
          await _act(
            o,
            OccurrenceAction(
              action: OccurrenceActionAction.postpone,
              postponeTo: LocalDates.format(picked),
            ),
          );
        }
      case _OccAction.skip:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.occurrenceSkipConfirmTitle,
          body: l10n.occurrenceSkipConfirmBody(
            LocalDates.display(o.effectiveDate, locale: locale),
          ),
          confirmLabel: l10n.occurrenceSkip,
        );
        if (ok && mounted) {
          await _act(
            o,
            const OccurrenceAction(action: OccurrenceActionAction.skip),
          );
        }
      case _OccAction.reopen:
        await _act(
          o,
          const OccurrenceAction(action: OccurrenceActionAction.reopen),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<RecurringRuleDetail> rule = ref.watch(
      recurringRuleProvider(widget.ruleId),
    );
    final RecurringRuleDetail? loaded = rule.value;
    final bool manageable =
        loaded != null && loaded.owned && isManagedHere(loaded.kind.json);
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? l10n.recurringDetailTitle),
        bottom: _busy || (rule.isLoading && rule.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          if (manageable)
            PopupMenuButton<_RuleAction>(
              tooltip: l10n.actionMore,
              enabled: !_busy,
              onSelected: (_RuleAction a) => _runRule(a, loaded),
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_RuleAction>>[
                    if (loaded.status != RecurringRuleDetailStatus.ended)
                      PopupMenuItem<_RuleAction>(
                        value: _RuleAction.edit,
                        child: Text(l10n.actionEdit),
                      ),
                    if (loaded.status == RecurringRuleDetailStatus.active)
                      PopupMenuItem<_RuleAction>(
                        value: _RuleAction.skipNext,
                        child: Text(l10n.recurringSkipNext),
                      ),
                    if (loaded.status == RecurringRuleDetailStatus.active)
                      PopupMenuItem<_RuleAction>(
                        value: _RuleAction.pause,
                        child: Text(l10n.recurringPause),
                      ),
                    if (loaded.status == RecurringRuleDetailStatus.paused)
                      PopupMenuItem<_RuleAction>(
                        value: _RuleAction.resume,
                        child: Text(l10n.recurringResume),
                      ),
                    if (loaded.status != RecurringRuleDetailStatus.ended)
                      PopupMenuItem<_RuleAction>(
                        value: _RuleAction.stop,
                        child: Text(l10n.recurringStop),
                      ),
                    if (loaded.status != RecurringRuleDetailStatus.ended ||
                        loaded.completedCount == 0)
                      PopupMenuItem<_RuleAction>(
                        value: _RuleAction.delete,
                        child: Text(l10n.actionDelete),
                      ),
                  ],
            ),
        ],
      ),
      body: AsyncValueView<RecurringRuleDetail>(
        value: rule,
        onRetry: () => ref.invalidate(recurringRuleProvider(widget.ruleId)),
        data: (RecurringRuleDetail r) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recurringRuleProvider(widget.ruleId));
            try {
              await ref.read(recurringRuleProvider(widget.ruleId).future);
            } on Object {
              // Shown by the screen state.
            }
          },
          child: _RuleBody(
            rule: r,
            busy: _busy,
            onOccurrence: (OccurrenceDto o) => _onOccurrence(o, r),
          ),
        ),
      ),
    );
  }
}

class _RuleBody extends ConsumerWidget {
  const _RuleBody({
    required this.rule,
    required this.busy,
    required this.onOccurrence,
  });

  final RecurringRuleDetail rule;
  final bool busy;
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
    final String kind = rule.kind.json;
    final ScheduleValue schedule = ScheduleValue.fromDetail(rule);
    final (String statusText, StatusTone tone) = recurringStatusLabel(
      l10n,
      rule.status.json,
    );
    final ({List<OccurrenceDto> open, List<OccurrenceDto> done}) parts =
        splitOccurrences(rule.occurrences);
    // Bill schedules name their bill (`bill_id`); older answers only had
    // it on the occurrences.
    final String? billId =
        rule.billId ??
        rule.occurrences
            .map((OccurrenceDto o) => o.billId)
            .whereType<String>()
            .firstOrNull;
    final CategoryDto? category = rule.categoryId == null
        ? null
        : categories[rule.categoryId];
    final Money? amount = rule.amount;
    final String? next = rule.nextOccurrence;
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
                Row(
                  children: <Widget>[
                    ExcludeSemantics(child: Icon(recurringKindIcon(kind))),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        recurringKindLabel(l10n, kind),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                if (amount != null && !rule.amountIsVariable)
                  MoneyText(amount, style: theme.textTheme.headlineMedium)
                else
                  Text(
                    l10n.recurringAmountVaries,
                    style: theme.textTheme.titleLarge,
                  ),
                const SizedBox(height: Insets.sm),
                Text(
                  scheduleSummary(l10n, schedule, locale: locale),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  scheduleRange(l10n, schedule, locale: locale),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    StatusLabel(
                      text: statusText,
                      tone: tone,
                      semanticsLabel: l10n.recurringStatusSemantics(statusText),
                    ),
                    if (rule.autoPost)
                      StatusLabel(
                        text: l10n.recurringAutoPostOn,
                        icon: Icons.bolt,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isManagedHere(kind)) ...<Widget>[
          const SizedBox(height: Insets.md),
          NoticeBanner(
            message: switch (kind) {
              'bill' => l10n.recurringManagedByBill,
              'subscription' => l10n.recurringManagedBySubscription,
              _ => l10n.recurringManagedByGroup,
            },
            action: kind == 'bill' && billId != null
                ? TextButton(
                    onPressed: () => context.push(AppRoutes.billDetail(billId)),
                    child: Text(l10n.recurringOpenBill),
                  )
                : null,
          ),
        ] else if (!rule.owned) ...<Widget>[
          const SizedBox(height: Insets.md),
          NoticeBanner(message: l10n.recurringSharedReadOnly),
        ],
        if (rule.status == RecurringRuleDetailStatus.paused) ...<Widget>[
          const SizedBox(height: Insets.md),
          NoticeBanner(message: l10n.recurringPausedNotice),
        ],
        if (rule.status == RecurringRuleDetailStatus.ended) ...<Widget>[
          const SizedBox(height: Insets.md),
          NoticeBanner(message: l10n.recurringEndedNotice),
        ],
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.recurringUpcomingTitle,
          children: <Widget>[
            if (next != null && parts.open.isEmpty)
              DetailRow(
                label: l10n.recurringNextLabel,
                value: LocalDates.displayLong(next, locale: locale),
              ),
            if (parts.open.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                child: Text(l10n.recurringNothingUpcoming),
              )
            else
              for (final OccurrenceDto o in parts.open)
                OccurrenceTile(
                  occurrence: o,
                  enabled: !busy,
                  onTap: () => onOccurrence(o),
                ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.recurringHistoryTitle,
          children: <Widget>[
            if (parts.done.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                child: Text(l10n.recurringNoHistory),
              )
            else
              for (final OccurrenceDto o in parts.done)
                OccurrenceTile(
                  occurrence: o,
                  enabled: !busy,
                  onTap: () => onOccurrence(o),
                ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.recurringDetailsTitle,
          children: <Widget>[
            if (rule.accountId != null)
              DetailRow(
                label: kind == 'transfer'
                    ? l10n.recurringFromAccountLabel
                    : l10n.accountFieldLabel,
                value: accounts[rule.accountId]?.name ?? '—',
              ),
            if (rule.toAccountId != null)
              DetailRow(
                label: l10n.recurringToAccountLabel,
                value: accounts[rule.toAccountId]?.name ?? '—',
              ),
            if (category != null)
              DetailRow(
                label: l10n.categoryFieldLabel,
                value: categoryName(l10n, category),
              ),
            if (rule.merchant case final MerchantRef m)
              DetailRow(label: l10n.merchantFieldLabel, value: m.name),
            DetailRow(
              label: l10n.recurringAutoPostLabel,
              value: rule.autoPost
                  ? l10n.recurringAutoPostOn
                  : l10n.recurringAutoPostOff,
            ),
            DetailRow(
              label: l10n.reminderDaysLabel,
              value: rule.reminderDaysBefore.isEmpty
                  ? l10n.reminderNone
                  : <String>[
                      for (final int d in rule.reminderDaysBefore)
                        reminderOffsetLabel(l10n, d),
                    ].join(', '),
            ),
            DetailRow(
              label: l10n.recurringCompletedLabel,
              value: '${rule.completedCount}',
            ),
            if (rule.description case final String d when d.isNotEmpty)
              DetailRow(label: l10n.descriptionLabel, value: d),
            if (rule.notes case final String n when n.isNotEmpty)
              DetailRow(label: l10n.notesLabel, value: n),
          ],
        ),
      ],
    );
  }
}

/// One occurrence: its scheduled date, status and amount. A moved
/// occurrence keeps its status and says where it moved ("Moved to …",
/// from `postponed_to`).
class OccurrenceTile extends StatelessWidget {
  /// Creates the tile.
  const OccurrenceTile({
    required this.occurrence,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  /// The occurrence.
  final OccurrenceDto occurrence;

  /// Opens its actions.
  final VoidCallback? onTap;

  /// Whether it can be tapped.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final OccurrenceDto o = occurrence;
    final (String text, StatusTone tone, IconData icon) = occurrenceStatusLabel(
      l10n,
      o.status,
    );
    final String? moved = movedTo(o);
    final String date = LocalDates.display(
      moved == null ? o.effectiveDate : o.occurrenceDate,
      locale: locale,
    );
    final Money? amount = o.amount;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      onTap: onTap,
      title: Text(date),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Insets.xs),
        child: Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            StatusLabel(text: text, tone: tone, icon: icon),
            if (moved != null)
              StatusLabel(
                text: l10n.occurrenceMovedTo(
                  LocalDates.display(moved, locale: locale),
                ),
                icon: Icons.update,
              ),
            if (o.transactionId != null) Text(l10n.occurrenceHasTransaction),
          ],
        ),
      ),
      trailing: amount == null ? null : MoneyText(amount),
    );
  }
}
