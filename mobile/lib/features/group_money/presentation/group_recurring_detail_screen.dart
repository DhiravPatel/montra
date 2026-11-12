import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_paths.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';
import 'package:montra_mobile/features/recurring/domain/lifecycle.dart';
import 'package:montra_mobile/features/recurring/domain/recurring_display.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';

/// One recurring shared expense: schedule, amount, split and occurrences.
/// Any member adds a due occurrence as an expense (with an
/// `Idempotency-Key`); its creator or an admin skips one, edits, pauses,
/// resumes or stops it.
class GroupRecurringDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GroupRecurringDetailScreen({
    required this.groupId,
    required this.ruleId,
    super.key,
  });

  /// The group.
  final String groupId;

  /// The rule.
  final String ruleId;

  @override
  ConsumerState<GroupRecurringDetailScreen> createState() =>
      _GroupRecurringDetailScreenState();
}

class _GroupRecurringDetailScreenState
    extends ConsumerState<GroupRecurringDetailScreen> {
  final IdempotentSubmission _add = IdempotentSubmission();
  bool _busy = false;

  GroupRecord get _record => (groupId: widget.groupId, id: widget.ruleId);
  GroupMoneyApi get _api => ref.read(groupMoneyApiProvider);

  Future<T?> _guard<T>(
    Future<T> Function() action, {
    required String done,
    GroupPeople? people,
  }) async {
    if (_busy) {
      return null;
    }
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final T result = await action();
      if (mounted) {
        groupMoneyChanged(ref, widget.groupId);
        showSnack(context, done);
      }
      return result;
    } on ApiException catch (error) {
      // Changed elsewhere (also a pause of a rule paused meanwhile,
      // `invalid_status_transition`): show where it stands now.
      if (error.code == ErrorObjectCode.conflict ||
          error.code == ErrorObjectCode.versionConflict ||
          isStaleStatus(error)) {
        ref.invalidate(groupRecurringProvider(_record));
      }
      if (mounted) {
        showSnack(context, _message(l10n, error, people));
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// The error text; a member who left is named.
  String _message(AppLocalizations l10n, ApiException error, GroupPeople? p) {
    final Detail? d = error.details
        .where((Detail d) => d.code == 'recurring_member_inactive')
        .firstOrNull;
    final String? userId = d?.params?['user_id'];
    if (p != null && userId != null) {
      return l10n.gxErrRecurringMemberInactiveNamed(p.name(l10n, userId));
    }
    return describeError(l10n, error);
  }

  Future<void> _action(GroupRecurringDto r, GroupRecurringAction a) async {
    final AppLocalizations l10n = context.l10n;
    if (a == GroupRecurringAction.stop) {
      final bool ok = await showConfirmDialog(
        context,
        title: l10n.gxRecurringStopTitle,
        body: l10n.gxRecurringStopBody(r.rule.name),
        confirmLabel: l10n.recurringStop,
        destructive: true,
      );
      if (!ok || !mounted) {
        return;
      }
    }
    await _guard(
      () => _api.recurringAction(widget.groupId, r.rule.id, a),
      done: switch (a) {
        GroupRecurringAction.pause => l10n.recurringPaused,
        GroupRecurringAction.resume => l10n.recurringResumed,
        GroupRecurringAction.stop => l10n.recurringStopped,
      },
    );
  }

  Future<void> _addNow(
    GroupRecurringDto r,
    OccurrenceDto o,
    GroupPeople people,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final bool ok = await showConfirmDialog(
      context,
      title: l10n.gxOccurrenceAddTitle,
      body: l10n.gxOccurrenceAddBody(
        r.rule.name,
        LocalDates.display(o.effectiveDate, locale: locale),
      ),
      confirmLabel: l10n.gxOccurrenceAdd,
    );
    if (!ok || !mounted) {
      return;
    }
    final GoRouter router = GoRouter.of(context);
    final GroupExpenseDetail? expense = await _guard(
      () => _api.addOccurrence(
        widget.groupId,
        r.rule.id,
        o.id,
        key: _add.keyFor(<String, Object?>{'occurrence': o.id}),
      ),
      done: l10n.gxOccurrenceAdded,
      people: people,
    );
    if (expense != null) {
      _add.reset();
      await router.push(
        AppRoutes.groupExpenseDetail(widget.groupId, expense.id),
      );
    }
  }

  Future<void> _skip(GroupRecurringDto r, OccurrenceDto o) async {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final bool ok = await showConfirmDialog(
      context,
      title: l10n.occurrenceSkipConfirmTitle,
      body: l10n.occurrenceSkipConfirmBody(
        LocalDates.display(o.effectiveDate, locale: locale),
      ),
      confirmLabel: l10n.occurrenceSkip,
    );
    if (!ok || !mounted) {
      return;
    }
    await _guard(
      () => _api.skipOccurrence(widget.groupId, r.rule.id, o.id),
      done: l10n.gxOccurrenceSkipped,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return GroupPeopleScope(
      groupId: widget.groupId,
      title: l10n.gxRecurringTitle,
      builder: (BuildContext context, GroupPeople people) {
        final AsyncValue<GroupRecurringDto> rule = ref.watch(
          groupRecurringProvider(_record),
        );
        final GroupRecurringDto? loaded = rule.value;
        final bool manage =
            loaded != null && canManageRecurring(loaded, people);
        final RecurringRuleDtoStatus? status = loaded?.rule.status;
        return Scaffold(
          appBar: AppBar(
            title: Text(loaded?.rule.name ?? l10n.gxRecurringTitle),
            bottom: _busy || (rule.isLoading && rule.hasValue)
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4),
                    child: LinearProgressIndicator(),
                  )
                : null,
            actions: <Widget>[
              if (manage && status != RecurringRuleDtoStatus.ended)
                IconButton(
                  tooltip: l10n.actionEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _busy
                      ? null
                      : () => context.push(
                          GroupMoneyPaths.editRecurring(
                            widget.groupId,
                            loaded.rule.id,
                          ),
                        ),
                ),
              if (manage && status != RecurringRuleDtoStatus.ended)
                PopupMenuButton<GroupRecurringAction>(
                  tooltip: l10n.actionMore,
                  enabled: !_busy,
                  onSelected: (GroupRecurringAction a) => _action(loaded, a),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<GroupRecurringAction>>[
                        if (status == RecurringRuleDtoStatus.active)
                          PopupMenuItem<GroupRecurringAction>(
                            value: GroupRecurringAction.pause,
                            child: Text(l10n.recurringPause),
                          ),
                        if (status == RecurringRuleDtoStatus.paused)
                          PopupMenuItem<GroupRecurringAction>(
                            value: GroupRecurringAction.resume,
                            child: Text(l10n.recurringResume),
                          ),
                        PopupMenuItem<GroupRecurringAction>(
                          value: GroupRecurringAction.stop,
                          child: Text(l10n.recurringStop),
                        ),
                      ],
                ),
            ],
          ),
          body: AsyncValueView<GroupRecurringDto>(
            value: rule,
            onRetry: () => ref.invalidate(groupRecurringProvider(_record)),
            data: (GroupRecurringDto r) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(groupRecurringProvider(_record));
                try {
                  await ref.read(groupRecurringProvider(_record).future);
                } on Object {
                  // Shown by the screen state.
                }
              },
              child: _body(context, r, people),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, GroupRecurringDto r, GroupPeople people) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final RecurringRuleDto rule = r.rule;
    final (String status, StatusTone tone) = recurringStatusLabel(
      l10n,
      rule.status.json,
    );
    final ScheduleValue schedule = ScheduleValue.fromRule(rule);
    final ({List<OccurrenceDto> open, List<OccurrenceDto> done}) occ =
        splitOccurrences(r.occurrences);
    final bool manage = canManageRecurring(r, people);
    final bool active = rule.status == RecurringRuleDtoStatus.active;
    final String method = r.template.splitMethod?.json ?? 'equal';
    final List<ExpensePayerInput> payers =
        r.template.payers ?? const <ExpensePayerInput>[];
    return ScrollableContent(
      children: <Widget>[
        if (rule.amount case final Money amount)
          MoneyText(amount, style: theme.textTheme.headlineMedium),
        const SizedBox(height: Insets.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusLabel(text: status, tone: tone),
        ),
        if (rule.status == RecurringRuleDtoStatus.paused) ...<Widget>[
          const SizedBox(height: Insets.sm),
          NoticeBanner(message: l10n.recurringPausedNotice),
        ],
        const SizedBox(height: Insets.md),
        SectionCard(
          children: <Widget>[
            DetailRow(
              label: l10n.gxScheduleSection,
              value: scheduleSummary(l10n, schedule, locale: locale),
            ),
            DetailRow(
              label: l10n.gxScheduleDates,
              value: scheduleRange(l10n, schedule, locale: locale),
            ),
            if (rule.nextOccurrence case final String next when active)
              DetailRow(
                label: l10n.gxNextLabel,
                value: LocalDates.display(next, locale: locale),
              ),
            DetailRow(
              label: l10n.gxAutoAddLabel,
              value: r.autoAdd ? l10n.gxAutoAddOn : l10n.gxAutoAddOff,
            ),
            DetailRow(
              label: l10n.categoryFieldLabel,
              value: groupCategoryLabel(l10n, r.template.categoryKey),
            ),
            DetailRow(
              label: l10n.gxCreatedBy,
              value: people.name(l10n, r.createdBy),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.gxSplitSection,
          children: <Widget>[
            DetailRow(
              label: l10n.gxSplitMethodLabel,
              value: splitMethodLabel(l10n, method),
            ),
            for (final ExpenseParticipantInput p in r.template.participants)
              DetailRow(
                label: people.name(l10n, p.userId),
                value:
                    splitValueText(l10n, method, p.value) ??
                    (method == 'exact' && p.value != null
                        ? formatMoney(
                            context,
                            ref,
                            moneyOfMinor(
                              minorOf(p.value!, exponentFor(people.currency)) ??
                                  0,
                              people.currency,
                            ),
                          )
                        : l10n.gxSharesEqually),
              ),
            DetailRow(
              label: l10n.gxWhoPays,
              value: payers.isEmpty
                  ? l10n.gxPayerAdder
                  : payers
                        .map(
                          (ExpensePayerInput p) => people.name(l10n, p.userId),
                        )
                        .join(', '),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.gxOccurrencesTitle,
          children: <Widget>[
            if (r.occurrences.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Text(l10n.gxOccurrencesEmpty),
              ),
            for (final OccurrenceDto o in <OccurrenceDto>[
              ...occ.open,
              ...occ.done,
            ])
              _OccurrenceTile(
                occurrence: o,
                busy: _busy,
                canAdd:
                    people.canWrite &&
                    rule.status != RecurringRuleDtoStatus.ended &&
                    isOpenOccurrence(o),
                canSkip: manage && isOpenOccurrence(o),
                onAdd: () => _addNow(r, o, people),
                onSkip: () => _skip(r, o),
                onOpen: o.groupExpenseId == null
                    ? null
                    : () => context.push(
                        AppRoutes.groupExpenseDetail(
                          widget.groupId,
                          o.groupExpenseId!,
                        ),
                      ),
              ),
          ],
        ),
        const SizedBox(height: Insets.lg),
      ],
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({
    required this.occurrence,
    required this.busy,
    required this.canAdd,
    required this.canSkip,
    required this.onAdd,
    required this.onSkip,
    required this.onOpen,
  });

  final OccurrenceDto occurrence;
  final bool busy;
  final bool canAdd;
  final bool canSkip;
  final VoidCallback onAdd;
  final VoidCallback onSkip;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final OccurrenceDto o = occurrence;
    final (String status, StatusTone tone, IconData icon) =
        occurrenceStatusLabel(l10n, o.status);
    final String? moved = movedTo(o);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ExcludeSemantics(child: Icon(icon, size: 20)),
              Text(LocalDates.display(o.effectiveDate, locale: locale)),
              StatusLabel(text: status, tone: tone),
            ],
          ),
          if (moved != null)
            Text(
              l10n.occurrenceMovedFrom(
                LocalDates.display(o.occurrenceDate, locale: locale),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Wrap(
            spacing: Insets.sm,
            children: <Widget>[
              if (canAdd)
                TextButton(
                  onPressed: busy ? null : onAdd,
                  child: Text(l10n.gxOccurrenceAdd),
                ),
              if (canSkip)
                TextButton(
                  onPressed: busy ? null : onSkip,
                  child: Text(l10n.occurrenceSkip),
                ),
              if (onOpen != null)
                TextButton(onPressed: onOpen, child: Text(l10n.gxOpenExpense)),
            ],
          ),
          const Divider(height: Insets.md),
        ],
      ),
    );
  }
}
