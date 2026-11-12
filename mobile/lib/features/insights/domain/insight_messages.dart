import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';

/// Typed access to an insight's `message_params` (or an evidence map):
/// amounts are Money objects `{amount_minor, amount, currency}`, counts and
/// `percent_bp` numbers, names, dates (`YYYY-MM-DD`), months (`YYYY-MM`)
/// and IDs strings. Every reader returns null for a missing or
/// differently-typed value, so a malformed parameter never breaks a screen.
@immutable
class InsightParams {
  /// Wraps [values] (null reads as empty).
  const InsightParams(Map<String, Object?>? values)
    : _values = values ?? const <String, Object?>{};

  final Map<String, Object?> _values;

  /// Whether no value is present.
  bool get isEmpty => _values.isEmpty;

  /// The Money object under [key].
  Money? money(String key) {
    final Object? v = _values[key];
    if (v is! Map<String, Object?>) {
      return null;
    }
    try {
      return Money.fromJson(v);
    } on FormatException {
      return null;
    }
  }

  /// A whole number under [key] (numbers and digit strings).
  int? integer(String key) => switch (_values[key]) {
    final int i => i,
    final num n when n == n.roundToDouble() => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  /// A non-empty string under [key] (numbers are written out).
  String? text(String key) => switch (_values[key]) {
    final String s when s.trim().isNotEmpty => s,
    final num n => n.toString(),
    _ => null,
  };

  /// Every Money object in the map, by key, in the server's order.
  Map<String, Money> get amounts => <String, Money>{
    for (final String key in _values.keys)
      if (money(key) case final Money m) key: m,
  };
}

/// Localized title and body of an insight.
typedef InsightText = ({String title, String body});

/// The title and body of [insight] in the user's language, built from
/// `message_code` and `message_params` with amounts formatted for
/// [locale]. Falls back to the server's English `title` / `body` when the
/// code is absent (insights recorded before codes existed), unknown, or a
/// value it needs is missing.
InsightText insightText(
  AppLocalizations l10n,
  InsightDto insight, {
  required String locale,
}) {
  final InsightText? coded = _coded(
    l10n,
    insight.messageCode,
    InsightParams(insight.messageParams),
    locale,
  );
  return coded ?? (title: insight.title, body: insight.body);
}

InsightText? _coded(
  AppLocalizations l10n,
  String? code,
  InsightParams p,
  String locale,
) {
  if (code == null) {
    return null;
  }
  String? money(String key) =>
      p.money(key) == null ? null : formatMoneyText(p.money(key)!, locale);
  String? date(String key) => p.text(key) == null
      ? null
      : LocalDates.display(p.text(key)!, locale: locale);
  String? month(String key) {
    final String? v = p.text(key);
    final DateTime? d = v == null ? null : LocalDates.parse('$v-01');
    return d == null ? v : DateFormat.yMMMM(locale).format(d);
  }

  String? number(String key) {
    final String? v = p.text(key);
    final num? n = v == null ? null : num.tryParse(v);
    return n == null ? v : NumberFormat.decimalPattern(locale).format(n);
  }

  switch (code) {
    case 'unusual_amount':
      final String? category = p.text('category_name');
      final String? amount = money('amount');
      final String? median = money('baseline_median');
      final String? label = p.text('label');
      final String? on = date('local_date');
      final String? ratio = number('ratio');
      final int? count = p.integer('history_count');
      final int months = p.integer('window_months') ?? 6;
      if (category == null ||
          amount == null ||
          median == null ||
          label == null ||
          on == null ||
          ratio == null ||
          count == null) {
        return null;
      }
      return (
        title: l10n.insightMsgUnusualAmountTitle(category),
        body: l10n.insightMsgUnusualAmountBody(
          amount,
          label,
          on,
          ratio,
          category,
          median,
          count,
          months,
        ),
      );
    case 'category_spike':
      final String? category = p.text('category_name');
      final String? soFar = money('so_far');
      final String? average = money('monthly_average');
      final int months = p.integer('months_compared') ?? 3;
      if (category == null || soFar == null || average == null) {
        return null;
      }
      return (
        title: l10n.insightMsgCategorySpikeTitle(category),
        body: l10n.insightMsgCategorySpikeBody(
          soFar,
          category,
          average,
          months,
        ),
      );
    case 'new_merchant_large':
      final String? merchant = p.text('merchant_name');
      final String? amount = money('amount');
      final String? typical = money('typical_expense');
      final String? on = date('local_date');
      if (merchant == null || amount == null || typical == null || on == null) {
        return null;
      }
      return (
        title: l10n.insightMsgNewMerchantTitle(merchant),
        body: l10n.insightMsgNewMerchantBody(amount, merchant, on, typical),
      );
    case 'possible_duplicate':
      final String? label = p.text('label');
      final String? amount = money('amount');
      final String? first = date('first_date');
      final String? second = date('second_date');
      if (label == null || amount == null || first == null || second == null) {
        return null;
      }
      return (
        title: l10n.insightMsgDuplicateTitle(label),
        body: l10n.insightMsgDuplicateBody(amount, label, first, second),
      );
    case 'subscription_price_increase':
      final String? name = p.text('name');
      final String? before = money('old');
      final String? after = money('new');
      final String? on = date('local_date');
      final int? bp = p.integer('percent_bp');
      if (name == null ||
          before == null ||
          after == null ||
          on == null ||
          bp == null) {
        return null;
      }
      return (
        title: l10n.insightMsgPriceIncreaseTitle(name),
        body: l10n.insightMsgPriceIncreaseBody(
          name,
          before,
          after,
          percentFromBp(bp, locale),
          on,
        ),
      );
    case 'missing_recurring_payment':
      final String? name = p.text('name');
      final String? due = date('due');
      final String? amount = money('amount');
      if (name == null || due == null) {
        return null;
      }
      return (
        title: l10n.insightMsgMissingRecurringTitle(name),
        body: amount == null
            ? l10n.insightMsgMissingRecurringBody(name, due)
            : l10n.insightMsgMissingRecurringAmountBody(name, amount, due),
      );
    case 'cash_flow_change_spending' ||
        'cash_flow_change_income' ||
        'cash_flow_change_both':
      final String? when = month('month');
      final String? spending = money('spending');
      final String? usualSpending = money('usual_spending');
      final String? income = money('income');
      final String? usualIncome = money('usual_income');
      final int months = p.integer('months_compared') ?? 3;
      if (when == null) {
        return null;
      }
      final String title = l10n.insightMsgCashFlowTitle;
      if (code == 'cash_flow_change_spending' &&
          spending != null &&
          usualSpending != null) {
        return (
          title: title,
          body: l10n.insightMsgCashFlowSpendingBody(
            when,
            spending,
            usualSpending,
            months,
          ),
        );
      }
      if (code == 'cash_flow_change_income' &&
          income != null &&
          usualIncome != null) {
        return (
          title: title,
          body: l10n.insightMsgCashFlowIncomeBody(
            when,
            income,
            usualIncome,
            months,
          ),
        );
      }
      if (code == 'cash_flow_change_both' &&
          spending != null &&
          usualSpending != null &&
          income != null &&
          usualIncome != null) {
        return (
          title: title,
          body: l10n.insightMsgCashFlowBothBody(
            when,
            spending,
            usualSpending,
            income,
            usualIncome,
            months,
          ),
        );
      }
      return null;
    case 'subscription_costs':
      final int? count = p.integer('count');
      final String? monthly = money('monthly');
      final String? yearly = money('yearly');
      if (count == null || monthly == null || yearly == null) {
        return null;
      }
      return (
        title: l10n.insightMsgSubscriptionCostsTitle(count, monthly),
        body: l10n.insightMsgSubscriptionCostsBody(yearly),
      );
    case 'unusual_frequency':
      final String? merchant = p.text('merchant_name');
      final int? count = p.integer('recent_count');
      final String? average = number('baseline_weekly_average');
      final int days = p.integer('window_days') ?? 7;
      final int weeks = p.integer('baseline_weeks') ?? 12;
      if (merchant == null || count == null || average == null) {
        return null;
      }
      return (
        title: l10n.insightMsgFrequencyTitle(merchant),
        body: l10n.insightMsgFrequencyBody(
          count,
          merchant,
          days,
          average,
          weeks,
        ),
      );
    case 'recurring_amount_change_higher' || 'recurring_amount_change_lower':
      final String? name = p.text('name');
      final String? amount = money('amount');
      final String? usual = money('usual_amount');
      final String? on = date('local_date');
      final String? change = p.text('change_percent');
      final int? count = p.integer('history_count');
      if (name == null ||
          amount == null ||
          usual == null ||
          on == null ||
          change == null ||
          count == null) {
        return null;
      }
      final num? pct = num.tryParse(change);
      final String percent = pct == null
          ? change
          : NumberFormat('+#,##0.#;−#,##0.#', locale).format(pct);
      return (
        title: code == 'recurring_amount_change_higher'
            ? l10n.insightMsgRecurringHigherTitle(name)
            : l10n.insightMsgRecurringLowerTitle(name),
        body: l10n.insightMsgRecurringChangeBody(
          name,
          amount,
          on,
          usual,
          count,
          percent,
        ),
      );
    case 'repeated_budget_overspend':
      final String? budget = p.text('budget_name');
      final int? over = p.integer('over_count');
      final int? periods = p.integer('periods');
      final String? average = money('average_spent');
      final String? limit = money('limit');
      final String? overspend = money('average_overspend');
      if (budget == null ||
          over == null ||
          periods == null ||
          average == null ||
          limit == null ||
          overspend == null) {
        return null;
      }
      return (
        title: l10n.insightMsgOverspendTitle(budget, over, periods),
        body: l10n.insightMsgOverspendBody(periods, average, limit, overspend),
      );
    default:
      return null;
  }
}

/// A percentage from basis points (`1250` → `12.5%`) in [locale].
String percentFromBp(int bp, String locale) =>
    NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: bp % 100 == 0 ? 0 : (bp % 10 == 0 ? 1 : 2),
    ).format(bp / 10000);

/// What the rule behind an insight checks (`rule_code`), in the user's
/// language; null for codes this app does not know.
String? insightRuleText(AppLocalizations l10n, String ruleCode) =>
    switch (ruleCode) {
      'amount_3x_median_above_p95' => l10n.insightRuleUnusualAmount,
      'month_to_date_above_3_month_average' => l10n.insightRuleCategorySpike,
      'first_at_merchant_2x_median_expense' => l10n.insightRuleNewMerchant,
      'same_account_amount_within_2_days' => l10n.insightRuleDuplicate,
      'recorded_price_change' => l10n.insightRulePriceChange,
      'overdue_recurring_occurrence' => l10n.insightRuleMissingRecurring,
      'spending_up_25_or_income_down_20_vs_3_months' =>
        l10n.insightRuleCashFlow,
      'active_subscriptions_normalized_monthly' =>
        l10n.insightRuleSubscriptionCosts,
      '4_in_7_days_and_3x_weekly_average' => l10n.insightRuleFrequency,
      'latest_differs_10_from_median_of_6' => l10n.insightRuleRecurringChange,
      'over_limit_2_of_last_3_periods' => l10n.insightRuleOverspend,
      _ => null,
    };

/// Name of an insight kind (subtype) for the mutes list.
String insightSubtypeLabel(AppLocalizations l10n, String subtype) =>
    switch (subtype) {
      'unusual_amount' => l10n.insightSubtypeUnusualAmount,
      'category_spike' => l10n.insightSubtypeCategorySpike,
      'new_merchant_large' => l10n.insightSubtypeNewMerchant,
      'possible_duplicate' => l10n.insightSubtypeDuplicate,
      'subscription_price_increase' => l10n.insightSubtypePriceIncrease,
      'missing_recurring_payment' => l10n.insightSubtypeMissingRecurring,
      'cash_flow_change' => l10n.insightSubtypeCashFlow,
      'subscription_costs' => l10n.insightSubtypeSubscriptionCosts,
      'unusual_frequency' => l10n.insightSubtypeFrequency,
      'recurring_amount_change' => l10n.insightSubtypeRecurringChange,
      'repeated_budget_overspend' => l10n.insightSubtypeOverspend,
      _ => subtype.replaceAll('_', ' '),
    };

/// Name of an insight kind filter.
String insightKindLabel(AppLocalizations l10n, InsightDtoKind kind) =>
    switch (kind) {
      InsightDtoKind.anomaly => l10n.insightKindAnomaly,
      InsightDtoKind.savings => l10n.insightKindSavings,
      InsightDtoKind.summary => l10n.insightKindSummary,
      InsightDtoKind.forecast => l10n.insightKindForecast,
      InsightDtoKind.budget => l10n.insightKindBudget,
      InsightDtoKind.subscription => l10n.insightKindSubscription,
      InsightDtoKind.recurring => l10n.insightKindRecurring,
      InsightDtoKind.unrecognized => l10n.insightKindOther,
    };

/// Name of a severity.
String insightSeverityLabel(AppLocalizations l10n, InsightDtoSeverity s) =>
    switch (s) {
      InsightDtoSeverity.warning => l10n.insightSeverityWarning,
      InsightDtoSeverity.notice => l10n.insightSeverityNotice,
      InsightDtoSeverity.info ||
      InsightDtoSeverity.unrecognized => l10n.insightSeverityInfo,
    };

/// Name of a status.
String insightStatusLabel(AppLocalizations l10n, InsightDtoStatus s) =>
    switch (s) {
      InsightDtoStatus.active => l10n.insightStatusActive,
      InsightDtoStatus.dismissed => l10n.insightStatusDismissed,
      InsightDtoStatus.snoozed => l10n.insightStatusSnoozed,
      InsightDtoStatus.expected => l10n.insightStatusExpected,
      InsightDtoStatus.resolved => l10n.insightStatusResolved,
      InsightDtoStatus.muted => l10n.insightStatusMuted,
      InsightDtoStatus.unrecognized => s.json,
    };

/// Name of a feedback answer.
String insightFeedbackLabel(AppLocalizations l10n, FeedbackDtoFeedback f) =>
    switch (f) {
      FeedbackDtoFeedback.helpful => l10n.insightFeedbackHelpful,
      FeedbackDtoFeedback.notHelpful => l10n.insightFeedbackNotHelpful,
      FeedbackDtoFeedback.incorrect => l10n.insightFeedbackIncorrect,
      FeedbackDtoFeedback.expected => l10n.insightFeedbackExpected,
      FeedbackDtoFeedback.unrecognized => f.json,
    };

/// Names of evidence amounts (`evidence.amounts` keys).
String insightAmountLabel(AppLocalizations l10n, String key) => switch (key) {
  'amount' => l10n.insightAmountAmount,
  'baseline_median' || 'usual_amount' => l10n.insightAmountUsual,
  'baseline_p95' => l10n.insightAmountP95,
  'typical_expense' => l10n.insightAmountTypical,
  'so_far' => l10n.insightAmountSoFar,
  'monthly_average' => l10n.insightAmountMonthlyAverage,
  'old' => l10n.insightAmountOld,
  'new' => l10n.insightAmountNew,
  'spending' => l10n.insightAmountSpending,
  'usual_spending' => l10n.insightAmountUsualSpending,
  'income' => l10n.insightAmountIncome,
  'usual_income' => l10n.insightAmountUsualIncome,
  'monthly' => l10n.insightAmountMonthly,
  'yearly' => l10n.insightAmountYearly,
  'average_spent' => l10n.insightAmountAverageSpent,
  'average_overspend' => l10n.insightAmountAverageOverspend,
  'limit' => l10n.insightAmountLimit,
  _ => key.replaceAll('_', ' '),
};
