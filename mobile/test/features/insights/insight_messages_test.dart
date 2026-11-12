import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/features/insights/domain/insight_messages.dart';

import '../../helpers/insights_feature_fakes.dart';

Map<String, Object?> money(String amount, int minor) => <String, Object?>{
  'amount_minor': minor,
  'amount': amount,
  'currency': 'INR',
};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('hi');
  });

  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations hi = lookupAppLocalizations(const Locale('hi'));
  String fmt(String amount, int minor, String locale) =>
      formatMoneyText(Money.fromJson(money(amount, minor)), locale);

  group('InsightParams', () {
    const InsightParams p = InsightParams(<String, Object?>{
      'amount': <String, Object?>{
        'amount_minor': 450000,
        'amount': '4500.00',
        'currency': 'INR',
      },
      'count': 12,
      'count_text': '7',
      'ratio': '3.8',
      'bad_money': <String, Object?>{'amount': '1'},
      'name': '',
    });

    test('reads Money, numbers and strings, and ignores the rest', () {
      expect(p.money('amount')!.amountMinor, 450000);
      expect(p.money('bad_money'), isNull);
      expect(p.money('count'), isNull);
      expect(p.integer('count'), 12);
      expect(p.integer('count_text'), 7);
      expect(p.text('ratio'), '3.8');
      expect(p.text('name'), isNull);
      expect(p.text('missing'), isNull);
      expect(p.amounts.keys, <String>['amount']);
      expect(const InsightParams(null).isEmpty, isTrue);
    });
  });

  group('insightText', () {
    test('localizes by message_code with Money formatted for the locale', () {
      final InsightText t = insightText(en, insight(), locale: 'en');
      expect(t.title, 'Unusually large Groceries expense');
      expect(
        t.body,
        '${fmt('4500.00', 450000, 'en')} for Fresh Mart on Nov 3, 2026 is '
        'about 3.8× your usual Groceries transaction (median '
        '${fmt('1200.00', 120000, 'en')} over 12 transactions in the '
        "previous 6 months). If it's expected, mark it so.",
      );
      final InsightText h = insightText(hi, insight(), locale: 'hi');
      expect(h.title, 'असामान्य रूप से बड़ा Groceries खर्च');
      expect(h.body, contains(fmt('4500.00', 450000, 'hi')));
      expect(h.body, isNot(contains('English body')));
    });

    test('falls back to the English text without a code, for unknown '
        'codes and when a value is missing', () {
      for (final InsightDto i in <InsightDto>[
        insight(messageCode: null),
        insight(messageCode: 'something_new'),
        insight(params: <String, Object?>{'label': 'Fresh Mart'}),
      ]) {
        final InsightText t = insightText(en, i, locale: 'en');
        expect(t.title, 'Unusually large Groceries expense');
        expect(t.body, 'English body from the server.');
      }
    });

    test('every rule code with its parameters has a localized message', () {
      final Map<String, Map<String, Object?>> cases =
          <String, Map<String, Object?>>{
            'category_spike': <String, Object?>{
              'category_name': 'Dining',
              'so_far': money('6000.00', 600000),
              'monthly_average': money('4000.00', 400000),
              'months_compared': 3,
            },
            'new_merchant_large': <String, Object?>{
              'merchant_name': 'Croma',
              'amount': money('9000.00', 900000),
              'typical_expense': money('500.00', 50000),
              'local_date': '2026-11-02',
            },
            'possible_duplicate': <String, Object?>{
              'label': 'Uber',
              'amount': money('415.00', 41500),
              'first_date': '2026-11-01',
              'second_date': '2026-11-02',
            },
            'subscription_price_increase': <String, Object?>{
              'name': 'Streamly',
              'old': money('199.00', 19900),
              'new': money('249.00', 24900),
              'percent_bp': 2513,
              'local_date': '2026-11-01',
            },
            'missing_recurring_payment': <String, Object?>{
              'name': 'Rent',
              'due': '2026-11-01',
              'amount': money('25000.00', 2500000),
            },
            'cash_flow_change_spending': <String, Object?>{
              'month': '2026-10',
              'spending': money('50000.00', 5000000),
              'usual_spending': money('30000.00', 3000000),
              'months_compared': 3,
            },
            'cash_flow_change_income': <String, Object?>{
              'month': '2026-10',
              'income': money('20000.00', 2000000),
              'usual_income': money('60000.00', 6000000),
            },
            'cash_flow_change_both': <String, Object?>{
              'month': '2026-10',
              'spending': money('50000.00', 5000000),
              'usual_spending': money('30000.00', 3000000),
              'income': money('20000.00', 2000000),
              'usual_income': money('60000.00', 6000000),
            },
            'subscription_costs': <String, Object?>{
              'count': 3,
              'monthly': money('1500.00', 150000),
              'yearly': money('18000.00', 1800000),
            },
            'unusual_frequency': <String, Object?>{
              'merchant_name': 'Swiggy',
              'recent_count': 6,
              'baseline_weekly_average': '1.5',
              'window_days': 7,
              'baseline_weeks': 12,
            },
            'recurring_amount_change_higher': <String, Object?>{
              'name': 'Electricity',
              'amount': money('3200.00', 320000),
              'usual_amount': money('2400.00', 240000),
              'local_date': '2026-11-05',
              'change_percent': '+33.3',
              'history_count': 6,
            },
            'recurring_amount_change_lower': <String, Object?>{
              'name': 'Electricity',
              'amount': money('1200.00', 120000),
              'usual_amount': money('2400.00', 240000),
              'local_date': '2026-11-05',
              'change_percent': '-50.0',
              'history_count': 6,
            },
            'repeated_budget_overspend': <String, Object?>{
              'budget_name': 'Food',
              'over_count': 2,
              'periods': 3,
              'average_spent': money('12000.00', 1200000),
              'limit': money('10000.00', 1000000),
              'average_overspend': money('2500.00', 250000),
            },
          };
      for (final MapEntry<String, Map<String, Object?>> c in cases.entries) {
        final InsightDto i = insight(messageCode: c.key, params: c.value);
        for (final (AppLocalizations l, String locale)
            in <(AppLocalizations, String)>[(en, 'en'), (hi, 'hi')]) {
          final InsightText t = insightText(l, i, locale: locale);
          expect(t.body, isNot('English body from the server.'), reason: c.key);
          expect(t.body, isNot(contains('{')), reason: c.key);
          expect(t.title, isNot(contains('{')), reason: c.key);
        }
      }
      final InsightText price = insightText(
        en,
        insight(
          messageCode: 'subscription_price_increase',
          params: cases['subscription_price_increase'],
        ),
        locale: 'en',
      );
      expect(price.body, contains('25.13%'));
      final InsightText both = insightText(
        en,
        insight(
          messageCode: 'subscription_costs',
          params: cases['subscription_costs'],
        ),
        locale: 'en',
      );
      expect(both.title, startsWith('3 subscriptions cost about'));
    });
  });

  test('rule codes, kinds and statuses have words in both languages', () {
    for (final String code in <String>[
      'amount_3x_median_above_p95',
      'month_to_date_above_3_month_average',
      'first_at_merchant_2x_median_expense',
      'same_account_amount_within_2_days',
      'recorded_price_change',
      'overdue_recurring_occurrence',
      'spending_up_25_or_income_down_20_vs_3_months',
      'active_subscriptions_normalized_monthly',
      '4_in_7_days_and_3x_weekly_average',
      'latest_differs_10_from_median_of_6',
      'over_limit_2_of_last_3_periods',
    ]) {
      expect(insightRuleText(en, code), isNotNull, reason: code);
      expect(insightRuleText(hi, code), isNotNull, reason: code);
    }
    expect(insightRuleText(en, 'new_rule'), isNull);
    expect(percentFromBp(1250, 'en'), '12.5%');
    expect(percentFromBp(10000, 'en'), '100%');
    expect(insightSubtypeLabel(en, 'possible_duplicate'), 'Possible duplicate');
  });
}
