import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/application/organize_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/domain/organize_display.dart';

/// Category rules in the order they run. Rules are edited, previewed,
/// applied and deleted from the rule form.
class CategoryRulesScreen extends ConsumerWidget {
  /// Creates the screen.
  const CategoryRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<RuleDto>> rules = ref.watch(categoryRulesProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoryRulesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newCategoryRule),
        icon: const Icon(Icons.add),
        label: Text(l10n.ruleNew),
      ),
      body: rules.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingStateView(),
        error: (Object error, StackTrace _) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(categoryRulesProvider),
        ),
        data: (List<RuleDto> list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(categoryRulesProvider);
            await ref.read(categoryRulesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Text(l10n.categoryRulesIntro),
              ),
              if (list.isEmpty)
                MessageStateView(
                  icon: Icons.rule,
                  title: l10n.categoryRulesEmptyTitle,
                  body: l10n.categoryRulesEmptyBody,
                )
              else
                for (final RuleDto rule in list)
                  _RuleTile(
                    rule: rule,
                    categoryName: switch (categories[rule.setCategoryId]) {
                      final CategoryDto c => categoryName(l10n, c),
                      null => l10n.ruleCategoryMissing,
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleTile extends ConsumerWidget {
  const _RuleTile({required this.rule, required this.categoryName});

  final RuleDto rule;
  final String categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = numberLocaleOf(context, ref);
    final String? amounts = ruleAmountsText(
      l10n,
      rule,
      money: (String amount, String? currency) {
        if (currency == null) {
          return amount;
        }
        try {
          return MoneyFormatter.formatAmount(amount, currency, locale: locale);
        } on FormatException {
          return '$amount $currency';
        }
      },
    );
    return ListTile(
      leading: Icon(rule.enabled ? Icons.rule : Icons.pause_circle_outline),
      title: Text(rule.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(ruleSummary(l10n, rule, categoryName: categoryName)),
          ?switch (amounts) {
            final String text => Text(text),
            null => null,
          },
          Text(
            <String>[
              l10n.rulePriorityValue(rule.priority),
              ruleApplyToLabel(
                l10n,
                RuleInputApplyTo.fromJson(rule.applyTo.json),
              ),
            ].join(' · '),
          ),
          if (!rule.enabled)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: StatusLabel(
                text: l10n.ruleStatusOff,
                icon: Icons.pause_circle_outline,
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.editCategoryRule(rule.id)),
    );
  }
}
