import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/goals/application/goals_providers.dart';
import 'package:montra_mobile/features/goals/domain/goal_display.dart';
import 'package:montra_mobile/features/goals/presentation/goal_paths.dart';
import 'package:montra_mobile/features/goals/presentation/goal_widgets.dart';
import 'package:montra_mobile/features/goals/presentation/record_contribution_sheet.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';

enum _GoalAction {
  edit,
  export,
  pause,
  resume,
  achieve,
  cancel,
  archive,
  leave,
}

enum _MemberChoice {
  contributor,
  viewer,
  amounts,
  percentOnly,
  hidden,
  remove,
  leave,
}

/// One goal: progress, outlook, milestones, contributions, the people it is
/// shared with and its details, with the actions the user's access allows.
class GoalDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [goalId].
  const GoalDetailScreen({required this.goalId, super.key});

  /// The goal.
  final String goalId;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  bool _busy = false;

  GoalDetailController get _controller =>
      ref.read(goalDetailProvider(widget.goalId).notifier);

  /// Runs [task] with the busy indicator and reports [success] or the
  /// error. Returns whether it succeeded.
  Future<bool> _guard(
    Future<void> Function() task, {
    required String success,
  }) async {
    if (_busy) {
      return false;
    }
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await task();
      if (mounted) {
        showSnack(context, success);
      }
      return true;
    } on ApiException catch (error) {
      final bool stale =
          error.code == ErrorObjectCode.versionConflict ||
          error.code == ErrorObjectCode.conflict;
      if (stale) {
        // The goal changed elsewhere (or is already in that state).
        ref.invalidate(goalDetailProvider(widget.goalId));
      }
      if (mounted) {
        showSnack(
          context,
          error.code == ErrorObjectCode.versionConflict
              ? l10n.versionConflictReloaded
              : describeError(l10n, error),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _run(_GoalAction action, GoalDto goal) async {
    final AppLocalizations l10n = context.l10n;
    switch (action) {
      case _GoalAction.edit:
        await context.push(AppRoutes.editGoal(goal.id));
        return;
      case _GoalAction.export:
        await context.push(GoalPaths.export(goal.id));
        return;
      case _GoalAction.pause:
      case _GoalAction.resume:
      case _GoalAction.achieve:
      case _GoalAction.cancel:
      case _GoalAction.archive:
      case _GoalAction.leave:
        break;
    }
    if (!mounted) {
      return;
    }
    final (String, String, String)? question = switch (action) {
      _GoalAction.achieve => (
        l10n.goalAchieveConfirmTitle,
        l10n.goalAchieveConfirmBody(goal.name),
        l10n.goalMarkAchieved,
      ),
      _GoalAction.cancel => (
        l10n.goalCancelConfirmTitle,
        l10n.goalCancelConfirmBody(goal.name),
        l10n.goalCancel,
      ),
      _GoalAction.archive => (
        l10n.goalArchiveConfirmTitle,
        l10n.goalArchiveConfirmBody(goal.name),
        l10n.goalArchive,
      ),
      _GoalAction.leave => (
        l10n.goalLeaveConfirmTitle,
        l10n.goalLeaveConfirmBody(goal.name),
        l10n.goalLeave,
      ),
      _ => null,
    };
    if (question != null) {
      final bool confirmed = await showConfirmDialog(
        context,
        title: question.$1,
        body: question.$2,
        confirmLabel: question.$3,
        destructive: action != _GoalAction.achieve,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    final String? me = ref.read(currentUserIdProvider);
    final GoalDetailController controller = _controller;
    final bool done = await _guard(
      () => switch (action) {
        _GoalAction.pause => controller.pause(),
        _GoalAction.resume => controller.resume(),
        _GoalAction.achieve => controller.achieve(),
        _GoalAction.cancel => controller.cancel(),
        _GoalAction.archive => controller.archive(),
        _GoalAction.leave => controller.leave(me ?? ''),
        _GoalAction.edit || _GoalAction.export => Future<void>.value(),
      },
      success: switch (action) {
        _GoalAction.pause => l10n.goalPausedDone,
        _GoalAction.resume => l10n.goalResumedDone,
        _GoalAction.achieve => l10n.goalAchievedDone,
        _GoalAction.cancel => l10n.goalCancelledDone,
        _GoalAction.archive => l10n.goalArchivedDone,
        _GoalAction.leave => l10n.goalLeftDone,
        _GoalAction.edit || _GoalAction.export => '',
      },
    );
    if (done && action == _GoalAction.leave && mounted) {
      context.pop();
    }
  }

  Future<void> _addMember(GoalDto goal) async {
    final AppLocalizations l10n = context.l10n;
    final String? me = ref.read(currentUserIdProvider);
    String? fromGroup;
    if (goal.groupId case final String groupId) {
      final String? source = await showOptionSheet<String>(
        context,
        title: l10n.goalAddMember,
        options: <SheetOption<String>>[
          SheetOption<String>(
            value: '',
            label: l10n.goalAddFromConnections,
            icon: Icons.people_outline,
          ),
          SheetOption<String>(
            value: groupId,
            label: l10n.goalAddFromGroup,
            icon: Icons.groups_outlined,
          ),
        ],
      );
      if (source == null || !mounted) {
        return;
      }
      fromGroup = source.isEmpty ? null : source;
    }
    final PersonChoice? person = await showPersonPicker(
      context,
      groupId: fromGroup,
      excludeIds: <String>{
        ?me,
        for (final GoalMember m in goal.members) m.userId,
      },
    );
    if (person == null || !mounted) {
      return;
    }
    final GoalMemberInputRole? role =
        await showOptionSheet<GoalMemberInputRole>(
          context,
          title: l10n.goalMemberRoleTitle(person.displayName),
          options: <SheetOption<GoalMemberInputRole>>[
            SheetOption<GoalMemberInputRole>(
              value: GoalMemberInputRole.contributor,
              label: l10n.goalMemberRoleContributor,
              icon: Icons.savings_outlined,
            ),
            SheetOption<GoalMemberInputRole>(
              value: GoalMemberInputRole.viewer,
              label: l10n.goalMemberRoleViewer,
              icon: Icons.visibility_outlined,
            ),
          ],
        );
    if (role == null || !mounted) {
      return;
    }
    final GoalDetailController controller = _controller;
    await _guard(
      () => controller.addMember(person.userId, role),
      success: l10n.goalMemberAddedDone(person.displayName),
    );
  }

  Future<void> _memberOptions(GoalDto goal, GoalMember member) async {
    final AppLocalizations l10n = context.l10n;
    final String? me = ref.read(currentUserIdProvider);
    final bool self = member.userId == me;
    final bool owner = canManageGoal(goal);
    if (!self && !owner) {
      return;
    }
    final _MemberChoice? choice = await showOptionSheet<_MemberChoice>(
      context,
      title: self ? l10n.goalMyVisibilityTitle : memberName(member),
      options: <SheetOption<_MemberChoice>>[
        if (owner && !self) ...<SheetOption<_MemberChoice>>[
          SheetOption<_MemberChoice>(
            value: _MemberChoice.contributor,
            label: l10n.goalMemberRoleContributor,
            icon: Icons.savings_outlined,
          ),
          SheetOption<_MemberChoice>(
            value: _MemberChoice.viewer,
            label: l10n.goalMemberRoleViewer,
            icon: Icons.visibility_outlined,
          ),
          SheetOption<_MemberChoice>(
            value: _MemberChoice.remove,
            label: l10n.goalMemberRemove,
            icon: Icons.person_remove_outlined,
            destructive: true,
          ),
        ],
        if (self) ...<SheetOption<_MemberChoice>>[
          SheetOption<_MemberChoice>(
            value: _MemberChoice.amounts,
            label: l10n.goalMemberVisibilityAmounts,
            icon: Icons.payments_outlined,
          ),
          SheetOption<_MemberChoice>(
            value: _MemberChoice.percentOnly,
            label: l10n.goalMemberVisibilityPercent,
            icon: Icons.percent,
          ),
          SheetOption<_MemberChoice>(
            value: _MemberChoice.hidden,
            label: l10n.goalMemberVisibilityHidden,
            icon: Icons.visibility_off_outlined,
          ),
          if (!owner)
            SheetOption<_MemberChoice>(
              value: _MemberChoice.leave,
              label: l10n.goalLeave,
              icon: Icons.logout,
              destructive: true,
            ),
        ],
      ],
      selected: self
          ? switch (member.contributionVisibility) {
              GoalMemberContributionVisibility.amounts => _MemberChoice.amounts,
              GoalMemberContributionVisibility.percentOnly =>
                _MemberChoice.percentOnly,
              GoalMemberContributionVisibility.hidden ||
              GoalMemberContributionVisibility.unrecognized =>
                _MemberChoice.hidden,
            }
          : member.role == GoalMemberRole.contributor
          ? _MemberChoice.contributor
          : _MemberChoice.viewer,
    );
    if (choice == null || !mounted) {
      return;
    }
    if (choice == _MemberChoice.leave) {
      await _run(_GoalAction.leave, goal);
      return;
    }
    if (choice == _MemberChoice.remove) {
      final bool confirmed = await showConfirmDialog(
        context,
        title: l10n.goalMemberRemoveConfirmTitle(memberName(member)),
        body: l10n.goalMemberRemoveConfirmBody(memberName(member)),
        confirmLabel: l10n.goalMemberRemove,
        destructive: true,
      );
      if (!confirmed || !mounted) {
        return;
      }
      final GoalDetailController controller = _controller;
      await _guard(
        () => controller.removeMember(member.userId),
        success: l10n.goalMemberRemovedDone(memberName(member)),
      );
      return;
    }
    final GoalMemberUpdate update = switch (choice) {
      _MemberChoice.contributor => const GoalMemberUpdate(
        role: GoalMemberUpdateRole.contributor,
      ),
      _MemberChoice.viewer => const GoalMemberUpdate(
        role: GoalMemberUpdateRole.viewer,
      ),
      _MemberChoice.amounts => const GoalMemberUpdate(
        contributionVisibility: GoalMemberUpdateContributionVisibility.amounts,
      ),
      _MemberChoice.percentOnly => const GoalMemberUpdate(
        contributionVisibility:
            GoalMemberUpdateContributionVisibility.percentOnly,
      ),
      _MemberChoice.hidden ||
      _MemberChoice.remove ||
      _MemberChoice.leave => const GoalMemberUpdate(
        contributionVisibility: GoalMemberUpdateContributionVisibility.hidden,
      ),
    };
    final GoalDetailController controller = _controller;
    await _guard(
      () => controller.updateMember(member.userId, update),
      success: l10n.goalMemberUpdatedDone,
    );
  }

  Future<void> _voidContribution(GoalContributionDto contribution) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.contributionVoidConfirmTitle,
      body: l10n.contributionVoidConfirmBody,
      confirmLabel: l10n.contributionVoid,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final GoalDetailController controller = _controller;
    await _guard(
      () => controller.voidContribution(contribution.id),
      success: l10n.contributionVoidedDone,
    );
  }

  Future<void> _recordContribution(
    GoalDto goal,
    GoalContributionDto contribution,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool recorded = await showRecordContributionSheet(
      context,
      goal: goal,
      contribution: contribution,
    );
    if (recorded && mounted) {
      showSnack(context, l10n.contributionRecordedDone);
    }
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(goalDetailProvider(widget.goalId))
      ..invalidate(goalContributionsProvider(widget.goalId))
      ..invalidate(goalForecastProvider(widget.goalId));
    try {
      await ref.read(goalDetailProvider(widget.goalId).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  List<PopupMenuEntry<_GoalAction>> _menu(AppLocalizations l10n, GoalDto g) {
    PopupMenuItem<_GoalAction> item(_GoalAction a, String label) =>
        PopupMenuItem<_GoalAction>(value: a, child: Text(label));
    final bool owner = canManageGoal(g);
    final bool open =
        g.status == GoalDtoStatus.active || g.status == GoalDtoStatus.paused;
    return <PopupMenuEntry<_GoalAction>>[
      if (owner && g.status != GoalDtoStatus.archived)
        item(_GoalAction.edit, l10n.actionEdit),
      item(_GoalAction.export, l10n.goalExport),
      if (owner && g.status == GoalDtoStatus.active)
        item(_GoalAction.pause, l10n.goalPause),
      if (owner && g.status == GoalDtoStatus.paused)
        item(_GoalAction.resume, l10n.goalResume),
      if (owner && open) item(_GoalAction.achieve, l10n.goalMarkAchieved),
      if (owner && open) item(_GoalAction.cancel, l10n.goalCancel),
      if (owner && g.status != GoalDtoStatus.archived)
        item(_GoalAction.archive, l10n.goalArchive),
      if (!owner) item(_GoalAction.leave, l10n.goalLeave),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<GoalDto> goal = ref.watch(
      goalDetailProvider(widget.goalId),
    );
    final GoalDto? loaded = goal.value;
    final String? me = ref.watch(currentUserIdProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? l10n.goalDetailTitle),
        bottom: _busy || (goal.isLoading && goal.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          if (loaded != null)
            PopupMenuButton<_GoalAction>(
              tooltip: l10n.actionMore,
              enabled: !_busy,
              onSelected: (_GoalAction a) => _run(a, loaded),
              itemBuilder: (BuildContext context) => _menu(l10n, loaded),
            ),
        ],
      ),
      body: AsyncValueView<GoalDto>(
        value: goal,
        onRetry: () => ref.invalidate(goalDetailProvider(widget.goalId)),
        data: (GoalDto g) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.md,
              Insets.md,
              Insets.xl,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              _ProgressCard(goal: g),
              if (_notice(l10n, g) case final NoticeBanner notice) ...<Widget>[
                const SizedBox(height: Insets.md),
                notice,
              ],
              if (canContribute(g)) ...<Widget>[
                const SizedBox(height: Insets.md),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => context.push(GoalPaths.contribute(g.id)),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.goalAddContribution),
                ),
              ],
              const SizedBox(height: Insets.md),
              _ForecastCard(goalId: g.id),
              const SizedBox(height: Insets.md),
              _MilestonesCard(goal: g),
              const SizedBox(height: Insets.md),
              _ContributionsCard(
                goal: g,
                onVoid: _busy || g.status == GoalDtoStatus.archived
                    ? null
                    : _voidContribution,
                onRecord: _busy || !canContribute(g)
                    ? null
                    : (GoalContributionDto c) => _recordContribution(g, c),
              ),
              if (canManageGoal(g) || g.members.isNotEmpty) ...<Widget>[
                const SizedBox(height: Insets.md),
                _MembersCard(
                  goal: g,
                  me: me,
                  onAdd:
                      canManageGoal(g) &&
                          !_busy &&
                          g.status != GoalDtoStatus.archived
                      ? () => _addMember(g)
                      : null,
                  onMember: _busy
                      ? null
                      : (GoalMember m) => _memberOptions(g, m),
                ),
              ],
              const SizedBox(height: Insets.md),
              _DetailsCard(goal: g),
            ],
          ),
        ),
      ),
    );
  }

  NoticeBanner? _notice(AppLocalizations l10n, GoalDto g) {
    final String dateLocale = Localizations.localeOf(context).toString();
    return switch (g.status) {
      GoalDtoStatus.paused => NoticeBanner(message: l10n.goalPausedNotice),
      GoalDtoStatus.achieved => NoticeBanner(
        tone: NoticeTone.success,
        message: switch (g.achievedAt) {
          final DateTime at => l10n.goalAchievedNotice(
            LocalDates.display(
              LocalDates.format(at.toLocal()),
              locale: dateLocale,
            ),
          ),
          null => l10n.goalAchievedNoticeNoDate,
        },
      ),
      GoalDtoStatus.cancelled => NoticeBanner(
        message: l10n.goalCancelledNotice,
      ),
      GoalDtoStatus.archived => NoticeBanner(message: l10n.goalArchivedNotice),
      GoalDtoStatus.active || GoalDtoStatus.unrecognized =>
        g.access == GoalDtoAccess.viewer
            ? NoticeBanner(message: l10n.goalViewerNotice)
            : null,
    };
  }
}

class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({required this.goal});

  final GoalDto goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = numberLocaleOf(context, ref);
    final GoalProgress p = goal.progress;
    final GoalInputGoalType? type = goalTypeOf(goal);
    final List<Widget> chips = goalChips(l10n, goal);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ExcludeSemantics(child: Icon(goalTypeIcon(type))),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: Text(
                          goalTypeLabel(l10n, type),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (chips.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Insets.sm),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.xs,
                      children: chips,
                    ),
                  ],
                  const SizedBox(height: Insets.md),
                  Text(
                    l10n.goalPercentSaved(
                      formatGoalPercent(p.percentBp, locale),
                    ),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Insets.sm),
                  GoalProgressBar(percentBp: p.percentBp),
                  const SizedBox(height: Insets.sm),
                  Text(
                    l10n.goalSavedOfTarget(
                      formatMoneyText(p.saved, locale),
                      formatMoneyText(goal.target, locale),
                    ),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const Divider(height: Insets.lg),
            GoalMoneyRow(label: l10n.goalSavedLabel, money: p.saved),
            GoalMoneyRow(label: l10n.goalTargetLabel, money: goal.target),
            GoalMoneyRow(label: l10n.goalRemainingLabel, money: p.remaining),
            if (p.verified.amountMinor != 0)
              GoalMoneyRow(label: l10n.goalVerifiedLabel, money: p.verified),
            if (p.planned.amountMinor != 0)
              GoalMoneyRow(label: l10n.goalPlannedLabel, money: p.planned),
            if (goal.starting.amountMinor != 0)
              GoalMoneyRow(label: l10n.goalStartingLabel, money: goal.starting),
            CardText(
              l10n.goalContributionCount(p.contributionCount),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends ConsumerWidget {
  const _ForecastCard({required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AsyncValue<GoalForecast> forecast = ref.watch(
      goalForecastProvider(goalId),
    );
    final String locale = numberLocaleOf(context, ref);
    final String dateLocale = Localizations.localeOf(context).toString();
    String money(Money m) => formatMoneyText(m, locale);
    String date(String d) => LocalDates.display(d, locale: dateLocale);
    return SectionCard(
      title: l10n.goalForecastTitle,
      children: switch (forecast) {
        AsyncValue<GoalForecast>(:final GoalForecast value) => <Widget>[
          if (value.achieved)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.xs,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusLabel(
                  text: l10n.goalForecastAchieved,
                  tone: StatusTone.positive,
                ),
              ),
            )
          else ...<Widget>[
            if (value.onTrack case final bool onTrack)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.xs,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: onTrack
                      ? StatusLabel(
                          text: l10n.goalForecastOnTrack,
                          tone: StatusTone.positive,
                        )
                      : StatusLabel(
                          text: l10n.goalForecastNeedsMore,
                          icon: Icons.trending_up,
                        ),
                ),
              ),
            if (value.targetDate case final String target)
              DetailRow(
                label: l10n.goalTargetDateLabel,
                value: switch (value.daysLeft) {
                  final int days =>
                    '${date(target)} · '
                        '${l10n.goalForecastDaysLeft(days)}',
                  null => date(target),
                },
              ),
            if (value.requiredPerMonth case final Money perMonth)
              CardText(switch (value.requiredPerWeek) {
                final Money perWeek => l10n.goalForecastRequired(
                  money(perMonth),
                  money(perWeek),
                ),
                null => l10n.goalForecastRequiredMonthOnly(money(perMonth)),
              }),
            CardText(l10n.goalForecastPace(money(value.recentMonthlyPace))),
            CardText(switch (value.projectedCompletion) {
              final String projected => l10n.goalForecastProjected(
                date(projected),
              ),
              null => l10n.goalForecastNoPace,
            }),
            if (value.plannedCompletion case final String planned)
              CardText(l10n.goalForecastPlanned(date(planned))),
          ],
          if (goalAssumptions(l10n, value) case final List<String> assumptions
              when assumptions.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                0,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.goalForecastAssumptions,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
            for (final String assumption in assumptions)
              CardText('• $assumption', style: theme.textTheme.bodySmall),
          ],
        ],
        AsyncValue<GoalForecast>(:final Object error, hasError: true) =>
          <Widget>[
            CardText(describeError(l10n, error)),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                child: TextButton(
                  onPressed: () => ref.invalidate(goalForecastProvider(goalId)),
                  child: Text(l10n.actionRetry),
                ),
              ),
            ),
          ],
        _ => <Widget>[CardText(l10n.loadingLabel)],
      },
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard({required this.goal});

  final GoalDto goal;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String dateLocale = Localizations.localeOf(context).toString();
    final List<GoalMilestone> milestones = <GoalMilestone>[...goal.milestones]
      ..sort(
        (GoalMilestone a, GoalMilestone b) => a.percent.compareTo(b.percent),
      );
    return SectionCard(
      title: l10n.milestonesTitle,
      children: <Widget>[
        if (milestones.isEmpty) CardText(l10n.milestonesEmpty),
        for (final GoalMilestone m in milestones)
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ExcludeSemantics(
                    child: Icon(
                      m.reachedAt == null
                          ? Icons.radio_button_unchecked
                          : Icons.check_circle,
                      color: m.reachedAt == null
                          ? theme.colorScheme.outline
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(switch (m.label?.trim()) {
                          final String label when label.isNotEmpty =>
                            '$label · ${l10n.milestonePercent(m.percent)}',
                          _ => l10n.milestonePercent(m.percent),
                        }, style: theme.textTheme.bodyLarge),
                        Text(switch (m.reachedAt) {
                          final DateTime at => l10n.milestoneReachedOn(
                            LocalDates.display(
                              LocalDates.format(at.toLocal()),
                              locale: dateLocale,
                            ),
                          ),
                          null => l10n.milestoneNotReached,
                        }, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ContributionsCard extends ConsumerWidget {
  const _ContributionsCard({
    required this.goal,
    required this.onVoid,
    required this.onRecord,
  });

  final GoalDto goal;
  final void Function(GoalContributionDto contribution)? onVoid;
  final void Function(GoalContributionDto contribution)? onRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<PagedList<GoalContributionDto>> contributions = ref.watch(
      goalContributionsProvider(goal.id),
    );
    return SectionCard(
      title: l10n.contributionsTitle,
      children: switch (contributions) {
        AsyncValue<PagedList<GoalContributionDto>>(
          :final PagedList<GoalContributionDto> value,
        ) =>
          value.items.isEmpty
              ? <Widget>[CardText(l10n.contributionsEmpty)]
              : <Widget>[
                  for (final GoalContributionDto c in value.items)
                    _ContributionRow(
                      contribution: c,
                      onVoid: onVoid,
                      onRecord: onRecord,
                    ),
                  LoadMoreFooter(
                    list: value,
                    onLoadMore: () => ref
                        .read(goalContributionsProvider(goal.id).notifier)
                        .loadMore(),
                  ),
                ],
        AsyncValue<PagedList<GoalContributionDto>>(
          :final Object error,
          hasError: true,
        ) =>
          <Widget>[
            CardText(describeError(l10n, error)),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(goalContributionsProvider(goal.id)),
                  child: Text(l10n.actionRetry),
                ),
              ),
            ),
          ],
        _ => <Widget>[CardText(l10n.loadingLabel)],
      },
    );
  }
}

class _ContributionRow extends ConsumerWidget {
  const _ContributionRow({
    required this.contribution,
    required this.onVoid,
    required this.onRecord,
  });

  final GoalContributionDto contribution;
  final void Function(GoalContributionDto contribution)? onVoid;
  final void Function(GoalContributionDto contribution)? onRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = numberLocaleOf(context, ref);
    final String dateLocale = Localizations.localeOf(context).toString();
    final GoalContributionDto c = contribution;
    final String date = LocalDates.display(c.contributedOn, locale: dateLocale);
    final String amount = switch ((c.amount, c.percentBp)) {
      (final Money money, _) => formatMoneyText(money, locale),
      (null, final int bp) => l10n.contributionShareOfTarget(
        formatGoalPercent(bp, locale),
      ),
      (null, null) => l10n.contributionAmountHidden,
    };
    final String kind = c.kind == GoalContributionDtoKind.withdrawal
        ? l10n.contributionKindWithdrawal
        : l10n.contributionKindContribution;
    final String? transactionId = c.transactionId;
    final TextStyle? amountStyle = theme.textTheme.titleSmall?.copyWith(
      decoration: c.voided ? TextDecoration.lineThrough : null,
    );
    final void Function(GoalContributionDto contribution)? voidIt = onVoid;
    final void Function(GoalContributionDto contribution)? record = onRecord;
    final bool recordable =
        c.mine &&
        !c.voided &&
        c.status == GoalContributionDtoStatus.planned &&
        record != null;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(contributionStatusIcon(c.status), size: 20),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('$kind · $amount', style: amountStyle),
                      Text(
                        '${contributionStatusLabel(l10n, c.status)} · $date · '
                        '${c.mine ? l10n.contributionYou : (c.displayName ?? '').trim()}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (c.note case final String note
                          when note.trim().isNotEmpty)
                        Text(note, style: theme.textTheme.bodySmall),
                      if (c.voided)
                        Padding(
                          padding: const EdgeInsets.only(top: Insets.xs),
                          child: StatusLabel(
                            text: l10n.contributionVoided,
                            icon: Icons.block,
                          ),
                        ),
                      if (transactionId != null && !c.mine)
                        Text(
                          l10n.contributionLinkedTransaction,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (recordable)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    onPressed: () => record(c),
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: Text(
                      l10n.contributionRecord,
                      semanticsLabel: l10n.contributionRecordTooltip(date),
                    ),
                  ),
                if (transactionId != null && c.mine)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    onPressed: () => context.push(
                      AppRoutes.transactionDetail(transactionId),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(l10n.contributionOpenTransaction),
                  ),
              ],
            ),
          ),
          if (c.mine && !c.voided && voidIt != null)
            IconButton(
              tooltip: l10n.contributionVoidTooltip(date),
              icon: const Icon(Icons.undo),
              onPressed: () => voidIt(c),
            ),
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({
    required this.goal,
    required this.me,
    required this.onAdd,
    required this.onMember,
  });

  final GoalDto goal;
  final String? me;
  final VoidCallback? onAdd;
  final void Function(GoalMember member)? onMember;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<GoalMember> members = goal.members;
    final bool owner = canManageGoal(goal);
    final VoidCallback? add = onAdd;
    final void Function(GoalMember member)? tapMember = onMember;
    return SectionCard(
      title: l10n.goalMembersTitle,
      children: <Widget>[
        if (owner) CardText(l10n.goalOwnerNote),
        if (goalSharedMembers(goal).isEmpty) CardText(l10n.goalMembersEmpty),
        for (final GoalMember m in members)
          ListTile(
            leading: InitialsAvatar(name: memberName(m)),
            title: Text(
              m.userId == me
                  ? l10n.goalMemberYou(memberName(m))
                  : memberName(m),
            ),
            subtitle: Text(
              '${goalRoleLabel(l10n, m.role)} · '
              '${goalContributionVisibilityLabel(l10n, m.contributionVisibility)}',
            ),
            trailing: (owner || m.userId == me) && tapMember != null
                ? const Icon(Icons.more_vert)
                : null,
            onTap: (owner || m.userId == me) && tapMember != null
                ? () => tapMember(m)
                : null,
          ),
        if (add != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: add,
                icon: const Icon(Icons.person_add_alt),
                label: Text(l10n.goalAddMember),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({required this.goal});

  final GoalDto goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String dateLocale = Localizations.localeOf(context).toString();
    final String? accountId = goal.linkedAccountId;
    final String? groupId = goal.groupId;
    final String? accountName = accountId == null
        ? null
        : ref.watch(accountIndexProvider)[accountId]?.name;
    final String? groupName = groupId == null
        ? null
        : ref.watch(groupIndexProvider)[groupId]?.name;
    final GoalInputContributionSchedule schedule = goalScheduleOf(goal);
    return SectionCard(
      title: l10n.goalDetailsTitle,
      children: <Widget>[
        DetailRow(
          label: l10n.goalTypeLabel,
          value: goalTypeLabel(l10n, goalTypeOf(goal)),
        ),
        DetailRow(
          label: l10n.goalScheduleLabel,
          value: goalScheduleLabel(l10n, schedule),
        ),
        if (goal.plannedContribution case final Money planned
            when schedule != GoalInputContributionSchedule.none)
          GoalMoneyRow(
            label: l10n.goalPlannedContributionLabel,
            money: planned,
          ),
        DetailRow(
          label: l10n.goalPriorityLabel,
          value: goalPriorityLabel(l10n, goal.priority),
        ),
        DetailRow(
          label: l10n.goalStartDateLabel,
          value: LocalDates.display(goal.startDate, locale: dateLocale),
        ),
        DetailRow(
          label: l10n.goalTargetDateLabel,
          value: switch (goal.targetDate) {
            final String d => LocalDates.display(d, locale: dateLocale),
            null => l10n.notSetLabel,
          },
        ),
        if (accountName != null)
          DetailRow(label: l10n.goalLinkedAccountLabel, value: accountName),
        if (groupName != null)
          DetailRow(label: l10n.goalGroupLabel, value: groupName),
        DetailRow(
          label: l10n.goalVisibilityLabel,
          value: goal.visibility == GoalDtoVisibility.members
              ? l10n.goalVisibilityMembers
              : l10n.goalVisibilityPrivate,
        ),
        DetailRow(
          label: l10n.goalRemindersDetail,
          value: goal.remindersEnabled ? l10n.statusOn : l10n.statusOff,
        ),
        if (goal.description case final String d when d.trim().isNotEmpty)
          DetailRow(label: l10n.descriptionLabel, value: d),
        if (goal.notes case final String n when n.trim().isNotEmpty)
          DetailRow(label: l10n.notesLabel, value: n),
      ],
    );
  }
}
