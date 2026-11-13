import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/help/help_guide_button.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/goals/application/goals_providers.dart';
import 'package:montra_mobile/features/goals/domain/goal_display.dart';
import 'package:montra_mobile/features/goals/presentation/goal_widgets.dart';

/// Savings goals with their progress, filtered by status.
class GoalsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  /// Null: every goal except archived ones.
  String? _status;

  Future<void> _refresh() async {
    ref.invalidate(goalsProvider(_status));
    try {
      await ref.read(goalsProvider(_status).future);
    } on Object {
      // Shown by the list state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<GoalDto>> goals = ref.watch(goalsProvider(_status));
    return Scaffold(
      appBar: AppBar(
        actions: const <Widget>[HelpGuideButton(HelpGuide.goals)],
        title: Text(l10n.goalsTitle),
        bottom: goals.isLoading && goals.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newGoal),
        icon: const Icon(Icons.add),
        label: Text(l10n.goalNew),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _StatusFilter(
            selected: _status,
            onChanged: (String? status) => setState(() => _status = status),
          ),
          Expanded(
            child: AsyncValueView<List<GoalDto>>(
              value: goals,
              onRetry: _refresh,
              data: (List<GoalDto> list) => RefreshIndicator(
                onRefresh: _refresh,
                child: list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: Insets.lg),
                            child: _status == null
                                ? MessageStateView(
                                    icon: Icons.savings_outlined,
                                    title: l10n.goalsEmptyTitle,
                                    body: l10n.goalsEmptyBody,
                                    action: FilledButton.icon(
                                      onPressed: () =>
                                          context.push(AppRoutes.newGoal),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.goalAddFirst),
                                    ),
                                  )
                                : MessageStateView(
                                    icon: Icons.filter_alt_off_outlined,
                                    title: l10n.goalsNoMatchTitle,
                                    body: l10n.goalsNoMatchBody,
                                  ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          top: Insets.xs,
                          bottom: 96,
                        ),
                        itemCount: list.length,
                        itemBuilder: (BuildContext context, int i) => GoalTile(
                          goal: list[i],
                          onTap: () =>
                              context.push(AppRoutes.goalDetail(list[i].id)),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Choice chips for the status filter; scrolls sideways so large text
/// never overflows.
class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.goalFilterLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.sm,
          Insets.md,
          Insets.xs,
        ),
        child: Row(
          children: <Widget>[
            for (final String? status in goalStatusFilters)
              Padding(
                padding: const EdgeInsets.only(right: Insets.sm),
                child: ChoiceChip(
                  label: Text(goalFilterLabel(l10n, status)),
                  selected: status == selected,
                  onSelected: (_) => onChanged(status),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
