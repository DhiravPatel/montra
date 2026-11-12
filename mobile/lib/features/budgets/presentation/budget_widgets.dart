import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/budgets/application/budgets_providers.dart';
import 'package:montra_mobile/features/budgets/domain/budget_display.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';

/// An amount as shown on screen and as read by screen readers.
typedef SpokenMoney = ({String text, String spoken});

/// Formats [money] for display and for screen readers.
SpokenMoney spokenMoney(BuildContext context, WidgetRef ref, Money money) {
  final String locale = numberLocaleOf(context, ref);
  return (
    text: formatMoneyText(money, locale),
    spoken: moneySemantics(context.l10n, money, locale),
  );
}

/// A thin bar showing how much of a limit is used. Decorative: the same
/// facts are always written next to it.
class BudgetProgressBar extends StatelessWidget {
  /// Creates the bar from basis points of the limit used.
  const BudgetProgressBar({
    required this.basisPoints,
    this.over = false,
    super.key,
  });

  /// Share of the limit used (10000 = all of it).
  final int basisPoints;

  /// Whether the limit is passed (drawn with the caution color).
  final bool over;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: budgetBarFraction(basisPoints),
          minHeight: 8,
          backgroundColor: scheme.surfaceContainerHighest,
          color: over ? StatusColors.of(context).warning : scheme.primary,
        ),
      ),
    );
  }
}

/// The pace in words with an icon (never color alone).
class BudgetPaceLabel extends StatelessWidget {
  /// Creates the label.
  const BudgetPaceLabel({required this.pace, super.key});

  /// The server's pace.
  final ProgressDtoPace pace;

  @override
  Widget build(BuildContext context) => StatusLabel(
    text: budgetPaceLabel(context.l10n, pace),
    tone: budgetPaceTone(pace),
    icon: budgetPaceIcon(pace),
  );
}

/// "₹4,000 spent of ₹10,000", a bar, the share used, what is left (or how
/// far over the limit it is) and the pace — all server figures.
class BudgetProgressSummary extends ConsumerWidget {
  /// Creates the summary.
  const BudgetProgressSummary({required this.progress, super.key});

  /// The period's progress.
  final ProgressDto progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = numberLocaleOf(context, ref);
    final SpokenMoney spent = spokenMoney(context, ref, progress.spent);
    final SpokenMoney limit = spokenMoney(context, ref, progress.limit);
    final bool over = progress.overspent.amountMinor > 0;
    final SpokenMoney rest = spokenMoney(
      context,
      ref,
      over ? progress.overspent : progress.remaining,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.budgetSpentOf(spent.text, limit.text),
          semanticsLabel: l10n.budgetSpentOf(spent.spoken, limit.spoken),
          style: text.titleMedium,
        ),
        const SizedBox(height: Insets.sm),
        BudgetProgressBar(basisPoints: progress.percentBp, over: over),
        const SizedBox(height: Insets.sm),
        Wrap(
          spacing: Insets.md,
          runSpacing: Insets.xs,
          children: <Widget>[
            Text(
              l10n.budgetPercentUsed(budgetPercent(progress.percentBp, locale)),
              style: text.bodyMedium,
            ),
            Text(
              over ? l10n.budgetOverBy(rest.text) : l10n.budgetLeft(rest.text),
              semanticsLabel: over
                  ? l10n.budgetOverBy(rest.spoken)
                  : l10n.budgetLeft(rest.spoken),
              style: text.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        BudgetPaceLabel(pace: progress.pace),
      ],
    );
  }
}

/// Type, period and sharing of [budget] in one line ("Shared by Asha ·
/// can edit" for collaborators).
String budgetSubtitle(
  AppLocalizations l10n,
  BudgetDto budget, {
  String? groupName,
}) => <String>[
  budgetTypeLabel(l10n, budgetInputType(budget.budgetType)),
  budgetPeriodLabel(l10n, budgetInputPeriod(budget.period)),
  if (budget.groupId != null)
    l10n.budgetGroupLabel(groupName ?? l10n.budgetGroupUnknown),
  ?budgetSharedByLabel(l10n, budget),
  if (budget.access == BudgetDtoAccess.owner && budget.members.isNotEmpty)
    l10n.budgetSharedWith(budget.members.length),
].join(' · ');

/// One budget in the list: name, type and period, and its progress.
class BudgetTile extends ConsumerWidget {
  /// Creates the tile.
  const BudgetTile({required this.budget, required this.onTap, super.key});

  /// The budget.
  final BudgetDto budget;

  /// Opens the budget.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final ProgressDto? progress = budget.progress;
    final String? groupId = budget.groupId;
    final String? groupName = groupId == null
        ? null
        : ref.watch(groupIndexProvider)[groupId]?.name;
    return Card(
      child: MergeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ExcludeSemantics(
                      child: Icon(
                        budgetTypeIcon(budgetInputType(budget.budgetType)),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(child: Text(budget.name, style: text.titleMedium)),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  budgetSubtitle(l10n, budget, groupName: groupName),
                  style: text.bodySmall,
                ),
                const SizedBox(height: Insets.sm),
                if (budget.status != BudgetDtoStatus.active)
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      StatusLabel(
                        text: budgetStatusLabel(l10n, budget.status),
                        icon: budget.status == BudgetDtoStatus.paused
                            ? Icons.pause_circle_outline
                            : Icons.inventory_2_outlined,
                      ),
                      Text(
                        budget.status == BudgetDtoStatus.paused
                            ? l10n.budgetNoProgressPaused
                            : l10n.budgetNoProgressArchived,
                        style: text.bodySmall,
                      ),
                    ],
                  )
                else if (progress != null)
                  BudgetProgressSummary(progress: progress),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What an allocation applies to, as text: its label, or the name of its
/// category, merchant, account or member.
class AllocationTitle extends ConsumerWidget {
  /// Creates the title.
  const AllocationTitle({
    this.label,
    this.categoryId,
    this.merchantId,
    this.accountId,
    this.memberUserId,
    this.knownName,
    this.memberNames = const <String, String>{},
    this.style,
    super.key,
  });

  /// The allocation's own name, if set.
  final String? label;

  /// Target category.
  final String? categoryId;

  /// Target merchant.
  final String? merchantId;

  /// Target account.
  final String? accountId;

  /// Target member (group budgets).
  final String? memberUserId;

  /// A name already known (for example chosen in the form).
  final String? knownName;

  /// Member names by user ID.
  final Map<String, String> memberNames;

  /// Text style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
    allocationName(
      context,
      ref,
      label: label,
      categoryId: categoryId,
      merchantId: merchantId,
      accountId: accountId,
      memberUserId: memberUserId,
      knownName: knownName,
      memberNames: memberNames,
    ),
    style: style,
  );
}

/// The text behind [AllocationTitle]: the allocation's own [label], a
/// [knownName], or the name of its category, merchant, account or member.
String allocationName(
  BuildContext context,
  WidgetRef ref, {
  String? label,
  String? categoryId,
  String? merchantId,
  String? accountId,
  String? memberUserId,
  String? knownName,
  Map<String, String> memberNames = const <String, String>{},
}) {
  final AppLocalizations l10n = context.l10n;
  if (label != null && label.trim().isNotEmpty) {
    return label;
  }
  if (knownName != null) {
    return knownName;
  }
  if (categoryId != null) {
    final CategoryDto? c = ref.watch(categoryIndexProvider)[categoryId];
    return c == null ? l10n.budgetAllocationRemoved : categoryName(l10n, c);
  }
  if (merchantId != null) {
    return ref.watch(budgetMerchantProvider(merchantId)).value?.name ??
        l10n.loadingLabel;
  }
  if (accountId != null) {
    return ref.watch(accountIndexProvider)[accountId]?.name ??
        l10n.budgetAllocationRemoved;
  }
  if (memberUserId != null) {
    if (memberUserId == ref.watch(currentUserIdProvider)) {
      return l10n.budgetAllocationYou;
    }
    final String? name = memberNames[memberUserId];
    return name == null
        ? l10n.budgetAllocationRemoved
        : l10n.budgetAllocationMember(name);
  }
  return l10n.budgetAllocationUnnamed;
}
