import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/goals/domain/goal_display.dart';

/// A bar filled to the server's progress. Decorative: the same numbers are
/// always written next to it. It is not animated.
class GoalProgressBar extends StatelessWidget {
  /// Creates the bar for [percentBp] basis points of the target.
  const GoalProgressBar({required this.percentBp, super.key});

  /// Server progress in basis points (10000 = 100%).
  final int percentBp;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: goalProgressFraction(percentBp),
        minHeight: 8,
      ),
    ),
  );
}

/// Chips saying whether a goal is paused, achieved… and whether it is
/// shared (by whom, for goals shared with the user). Empty for an active
/// goal of the user's own that isn't shared. The owner, listed first in
/// `members`, is not counted.
List<Widget> goalChips(AppLocalizations l10n, GoalDto goal) {
  final int members = goalSharedMembers(goal).length;
  final String owner = goal.owner.displayName?.trim() ?? '';
  return <Widget>[
    ?goalStatusChip(l10n, goal.status),
    if (goal.access != GoalDtoAccess.owner)
      StatusLabel(
        text: owner.isEmpty ? l10n.goalSharedWithYou : l10n.goalSharedBy(owner),
        icon: Icons.group_outlined,
      )
    else if (members > 0)
      StatusLabel(
        text: l10n.goalSharedCount(members),
        icon: Icons.group_outlined,
      ),
  ];
}

/// One goal in the list: name, status, progress in words and a bar.
class GoalTile extends ConsumerWidget {
  /// Creates the tile.
  const GoalTile({required this.goal, this.onTap, super.key});

  /// The goal.
  final GoalDto goal;

  /// Opens the goal.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = numberLocaleOf(context, ref);
    final String dateLocale = Localizations.localeOf(context).toString();
    final GoalInputGoalType? type = goalTypeOf(goal);
    final GoalProgress progress = goal.progress;
    final List<Widget> chips = goalChips(l10n, goal);
    final String? targetDate = goal.targetDate;
    return MergeSemantics(
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.xs,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ExcludeSemantics(child: Icon(goalTypeIcon(type))),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        goal.name,
                        style: theme.textTheme.titleMedium,
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
                GoalProgressBar(percentBp: progress.percentBp),
                const SizedBox(height: Insets.sm),
                Text(
                  l10n.goalProgressSummary(
                    formatGoalPercent(progress.percentBp, locale),
                    formatMoneyText(progress.saved, locale),
                    formatMoneyText(goal.target, locale),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                if (targetDate != null)
                  Text(
                    l10n.goalTargetDateShort(
                      LocalDates.display(targetDate, locale: dateLocale),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A label and a server amount on a details card.
class GoalMoneyRow extends ConsumerWidget {
  /// Creates the row.
  const GoalMoneyRow({required this.label, required this.money, super.key});

  /// What the amount is.
  final String label;

  /// Server amount.
  final Money money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String locale = numberLocaleOf(context, ref);
    return DetailRow(
      label: label,
      value: formatMoneyText(money, locale),
      semanticsValue: moneySemantics(context.l10n, money, locale),
    );
  }
}

/// Body text inside a [SectionCard], padded like its rows.
class CardText extends StatelessWidget {
  /// Creates the text.
  const CardText(this.text, {this.style, super.key});

  /// Text.
  final String text;

  /// Style; body medium by default.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: Insets.md,
      vertical: Insets.xs,
    ),
    child: Text(text, style: style ?? Theme.of(context).textTheme.bodyMedium),
  );
}
