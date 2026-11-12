import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/budgets/application/budgets_providers.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_detail_sections.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_member_sheet.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';

enum _BudgetAction { edit, pause, resume, restore, archive, leave }

/// One budget: this period's progress and how it is calculated, earlier
/// periods, counted transactions, allocations, who it is shared with and
/// its settings. Owners and editors can edit, pause, resume, archive and
/// restore it; owners manage members; members can leave.
class BudgetDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [budgetId].
  const BudgetDetailScreen({required this.budgetId, super.key});

  /// The budget.
  final String budgetId;

  @override
  ConsumerState<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends ConsumerState<BudgetDetailScreen> {
  bool _busy = false;

  /// Days inside the earlier periods being looked at (most recent last);
  /// empty for the current period.
  List<String> _periods = <String>[];

  BudgetDetailController get _controller =>
      ref.read(budgetDetailProvider(widget.budgetId).notifier);

  bool _canEdit(BudgetDto b) =>
      b.access == BudgetDtoAccess.owner || b.access == BudgetDtoAccess.editor;

  bool _isMember(BudgetDto b) {
    final String? me = ref.read(currentUserIdProvider);
    return b.access != BudgetDtoAccess.owner &&
        b.members.any((MemberDto m) => m.userId == me);
  }

  /// Runs a server action, shows its outcome and keeps the screen usable.
  Future<bool> _guard(Future<void> Function() action, String done) async {
    if (_busy) {
      return false;
    }
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        showSnack(context, done);
      }
      return true;
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.versionConflict) {
        ref.invalidate(budgetDetailProvider(widget.budgetId));
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

  /// The message for a failed action: a concurrent change, a person who
  /// can't be added (`body.user_id`), a share that isn't a valid amount
  /// (`body.allocation`), or the coded rule.
  String _errorText(AppLocalizations l10n, ApiException error) {
    if (error.code == ErrorObjectCode.versionConflict) {
      return l10n.versionConflictReloaded;
    }
    if (error.code == ErrorObjectCode.validationError) {
      for (final Detail d in error.details) {
        final String? field = d.field;
        if (field == null) {
          continue;
        }
        if (field == 'body.user_id' || field.endsWith('.user_id')) {
          return l10n.budgetMemberCannotAdd;
        }
        if (field == 'body.allocation' || field.endsWith('.allocation')) {
          return l10n.budgetMemberShareInvalid;
        }
      }
    }
    return describeError(l10n, error);
  }

  Future<void> _run(_BudgetAction action, BudgetDto budget) async {
    final AppLocalizations l10n = context.l10n;
    switch (action) {
      case _BudgetAction.edit:
        await context.push<Object?>(AppRoutes.editBudget(budget.id));
      case _BudgetAction.pause:
        await _guard(_controller.pause, l10n.budgetPaused);
      case _BudgetAction.resume:
        await _guard(_controller.resume, l10n.budgetResumed);
      case _BudgetAction.restore:
        await _guard(_controller.restore, l10n.budgetRestored);
      case _BudgetAction.archive:
        final bool confirmed = await showConfirmDialog(
          context,
          title: l10n.budgetArchiveTitle,
          body: l10n.budgetArchiveBody(budget.name),
          confirmLabel: l10n.budgetArchive,
          destructive: true,
        );
        if (confirmed && mounted) {
          await _guard(_controller.archive, l10n.budgetArchived);
        }
      case _BudgetAction.leave:
        await _leave();
    }
  }

  Future<void> _leave() async {
    final AppLocalizations l10n = context.l10n;
    final String? me = ref.read(currentUserIdProvider);
    if (me == null) {
      return;
    }
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.budgetLeaveTitle,
      body: l10n.budgetLeaveBody,
      confirmLabel: l10n.budgetLeave,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final GoRouter router = GoRouter.of(context);
    final bool left = await _guard(
      () => _controller.removeMember(me, leaving: true),
      l10n.budgetLeaveDone,
    );
    if (left && mounted) {
      router.pop();
    }
  }

  Future<void> _addMember(BudgetDto budget) async {
    final AppLocalizations l10n = context.l10n;
    final PersonChoice? person = await showPersonPicker(
      context,
      groupId: budget.groupId,
      excludeIds: <String>{
        budget.ownerUserId,
        for (final MemberDto m in budget.members) m.userId,
      },
    );
    if (person == null || !mounted) {
      return;
    }
    final BudgetMemberChoice? choice = await showBudgetMemberSheet(
      context,
      name: person.displayName,
      currency: budget.currency,
    );
    if (choice == null || !mounted) {
      return;
    }
    await _guard(
      () => _controller.addMember(
        MemberInput(
          userId: person.userId,
          role: choice.role,
          allocation: choice.allocation,
        ),
      ),
      l10n.budgetMemberAdded(person.displayName),
    );
  }

  Future<void> _editMember(BudgetDto budget, MemberDto member) async {
    final AppLocalizations l10n = context.l10n;
    final BudgetMemberChoice? choice = await showBudgetMemberSheet(
      context,
      name: member.displayName,
      currency: budget.currency,
      existing: true,
      role: member.role,
      allocation: member.allocation,
    );
    if (choice == null || !mounted) {
      return;
    }
    if (choice.remove) {
      final bool confirmed = await showConfirmDialog(
        context,
        title: l10n.budgetMemberRemoveTitle(member.displayName),
        body: l10n.budgetMemberRemoveBody,
        confirmLabel: l10n.budgetMemberRemove,
        destructive: true,
      );
      if (confirmed && mounted) {
        await _guard(
          () => _controller.removeMember(member.userId),
          l10n.budgetMemberRemoved(member.displayName),
        );
      }
      return;
    }
    await _guard(
      () => _controller.updateMember(
        member.userId,
        BudgetsMembersUpdateRequest(
          role: choice.role == MemberInputRole.editor
              ? BudgetsMembersUpdateRequestRole.editor
              : BudgetsMembersUpdateRequestRole.viewer,
          allocation: choice.allocation,
        ),
      ),
      l10n.budgetMemberUpdated,
    );
  }

  Future<void> _refresh() async {
    final String? date = _periods.isEmpty ? null : _periods.last;
    final BudgetPeriodKey key = (budgetId: widget.budgetId, date: date);
    ref
      ..invalidate(budgetDetailProvider(widget.budgetId))
      ..invalidate(budgetHistoryProvider(key))
      ..invalidate(budgetTransactionsProvider(key));
    try {
      await ref.read(budgetDetailProvider(widget.budgetId).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  List<PopupMenuEntry<_BudgetAction>> _menu(
    AppLocalizations l10n,
    BudgetDto b,
  ) => <PopupMenuEntry<_BudgetAction>>[
    if (_canEdit(b) && b.status != BudgetDtoStatus.archived)
      PopupMenuItem<_BudgetAction>(
        value: _BudgetAction.edit,
        child: Text(l10n.actionEdit),
      ),
    if (_canEdit(b) && b.status == BudgetDtoStatus.active)
      PopupMenuItem<_BudgetAction>(
        value: _BudgetAction.pause,
        child: Text(l10n.budgetPause),
      ),
    if (_canEdit(b) && b.status == BudgetDtoStatus.paused)
      PopupMenuItem<_BudgetAction>(
        value: _BudgetAction.resume,
        child: Text(l10n.budgetResume),
      ),
    if (_canEdit(b) && b.status == BudgetDtoStatus.archived)
      PopupMenuItem<_BudgetAction>(
        value: _BudgetAction.restore,
        child: Text(l10n.actionRestore),
      ),
    if (_canEdit(b) && b.status != BudgetDtoStatus.archived)
      PopupMenuItem<_BudgetAction>(
        value: _BudgetAction.archive,
        child: Text(l10n.budgetArchive),
      ),
    if (_isMember(b))
      PopupMenuItem<_BudgetAction>(
        value: _BudgetAction.leave,
        child: Text(l10n.budgetLeave),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<BudgetDto> budget = ref.watch(
      budgetDetailProvider(widget.budgetId),
    );
    final BudgetDto? loaded = budget.value;
    final List<PopupMenuEntry<_BudgetAction>> menu = loaded == null
        ? const <PopupMenuEntry<_BudgetAction>>[]
        : _menu(l10n, loaded);
    final String? date = _periods.isEmpty ? null : _periods.last;
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? l10n.budgetDetailTitle),
        bottom: _busy || (budget.isLoading && budget.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          if (loaded != null && menu.isNotEmpty)
            PopupMenuButton<_BudgetAction>(
              tooltip: l10n.actionMore,
              enabled: !_busy,
              onSelected: (_BudgetAction a) => _run(a, loaded),
              itemBuilder: (BuildContext context) => menu,
            ),
        ],
      ),
      body: AsyncValueView<BudgetDto>(
        value: budget,
        onRetry: () => ref.invalidate(budgetDetailProvider(widget.budgetId)),
        data: (BudgetDto b) {
          final bool owner = b.access == BudgetDtoAccess.owner;
          final bool archived = b.status == BudgetDtoStatus.archived;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(Insets.md),
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                if (b.status == BudgetDtoStatus.paused) ...<Widget>[
                  NoticeBanner(message: l10n.budgetPausedNotice),
                  const SizedBox(height: Insets.md),
                ],
                if (archived) ...<Widget>[
                  NoticeBanner(message: l10n.budgetArchivedNotice),
                  const SizedBox(height: Insets.md),
                ],
                BudgetSummaryCard(budget: b),
                BudgetOwnAlerts(budgetId: b.id),
                if (b.progress != null) ...<Widget>[
                  const SizedBox(height: Insets.md),
                  BudgetProgressDetailsCard(budget: b),
                ],
                const SizedBox(height: Insets.md),
                BudgetHistoryCard(
                  budget: b,
                  date: date,
                  onEarlier: (String day) =>
                      setState(() => _periods = <String>[..._periods, day]),
                  onLater: _periods.isEmpty
                      ? null
                      : () => setState(
                          () => _periods = _periods.sublist(
                            0,
                            _periods.length - 1,
                          ),
                        ),
                ),
                const SizedBox(height: Insets.md),
                BudgetTransactionsCard(budget: b, date: date),
                if (b.allocations.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Insets.md),
                  BudgetAllocationsCard(budget: b),
                ],
                const SizedBox(height: Insets.md),
                BudgetMembersCard(
                  budget: b,
                  onAdd: owner && !archived && !_busy
                      ? () => _addMember(b)
                      : null,
                  onEdit: owner && !_busy
                      ? (MemberDto m) => _editMember(b, m)
                      : null,
                  onLeave: _isMember(b) && !_busy ? _leave : null,
                ),
                const SizedBox(height: Insets.md),
                BudgetSettingsCard(budget: b),
              ],
            ),
          );
        },
      ),
    );
  }
}
