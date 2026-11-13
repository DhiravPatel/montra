import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/analytics/data/analytics_api.dart';
import 'package:montra_mobile/features/fx/data/fx_api.dart';
import 'package:montra_mobile/features/reconciliation/data/reconciliation_api.dart';
import 'package:montra_mobile/features/reports/data/reports_api.dart';

import 'finance_fakes.dart';

// Mocks of the round-3 insight APIs (analytics, reports, exchange rates,
// reconciliation).
class MockAnalyticsApi extends Mock implements AnalyticsApi {}

class MockReportsApi extends Mock implements ReportsApi {}

class MockFxApi extends Mock implements FxApi {}

class MockReconciliationApi extends Mock implements ReconciliationApi {}

/// Registers fallback values for `any()` matchers.
void registerInsightsFallbacks() {
  registerFallbackValue(const DateRangeChoice.named('this_month'));
  registerFallbackValue(
    const ReportInput(
      format: ReportInputFormat.csv,
      reportType: ReportInputReportType.monthlySummary,
    ),
  );
  registerFallbackValue(
    const ScheduleInput(
      cadence: ScheduleInputCadence.weekly,
      format: ScheduleInputFormat.csv,
      reportType: ScheduleInputReportType.cashFlow,
    ),
  );
  registerFallbackValue(const SchedulePatch(version: 1));
  registerFallbackValue(
    const ManualRateInput(baseValue: 'USD', quote: 'INR', rate: '1'),
  );
  registerFallbackValue(
    const ReconBalanceInput(statementBalance: '0', statementDate: '2026-11-01'),
  );
  registerFallbackValue(
    const ReconMatchInput(
      accountId: 'acc-1',
      kind: ReconMatchInputKind.pendingToPosted,
      transactionIds: <String>['tx-1'],
    ),
  );
}

// ---------------------------------------------------------------- Analytics

/// A `Window` JSON object.
Map<String, Object?> windowJson({
  String from = '2026-11-01',
  String to = '2026-11-30',
  int days = 30,
}) => <String, Object?>{
  'from': from,
  'to': to,
  'days': days,
  'timezone': 'Asia/Kolkata',
};

/// A `CashFlowTotals` JSON object.
Map<String, Object?> cashFlowTotalsJson({
  String currency = 'INR',
  String income = '85000.00',
  String grossExpense = '4609.50',
  String refunds = '0.00',
  String netExpense = '4609.50',
  String net = '80390.50',
  int? savingsRateBp = 9458,
  int count = 5,
}) => <String, Object?>{
  'currency': currency,
  'income': moneyJson(income, currency: currency),
  'gross_expense': moneyJson(grossExpense, currency: currency),
  'refunds': moneyJson(refunds, currency: currency),
  'net_expense': moneyJson(netExpense, currency: currency),
  'net_cash_flow': moneyJson(net, currency: currency),
  'savings_rate_bp': ?savingsRateBp,
  'transaction_count': count,
};

/// A `SeriesPoint` JSON object.
Map<String, Object?> seriesPointJson(
  String bucket, {
  String currency = 'INR',
  String income = '0.00',
  String netExpense = '0.00',
  String net = '0.00',
}) => <String, Object?>{
  'bucket': bucket,
  'currency': currency,
  'income': moneyJson(income, currency: currency),
  'net_expense': moneyJson(netExpense, currency: currency),
  'net': moneyJson(net, currency: currency),
};

/// A `CashFlowReport` with INR activity (and USD when [withUsd]) like the
/// live server's: per-currency totals, the previous period and a weekly
/// series.
CashFlowReport cashFlowReport({
  bool withUsd = true,
  bool empty = false,
  String granularity = 'week',
}) => CashFlowReport.fromJson(<String, Object?>{
  'window': windowJson(),
  'totals': <Object?>[
    if (!empty) cashFlowTotalsJson(),
    if (!empty && withUsd)
      cashFlowTotalsJson(
        currency: 'USD',
        income: '300.00',
        grossExpense: '45.20',
        netExpense: '45.20',
        net: '254.80',
        savingsRateBp: 8493,
        count: 2,
      ),
  ],
  'previous_window': windowJson(from: '2026-10-02', to: '2026-10-31'),
  'previous_period': <Object?>[
    if (!empty)
      cashFlowTotalsJson(
        income: '0.00',
        grossExpense: '320.00',
        netExpense: '320.00',
        net: '-320.00',
        savingsRateBp: null,
        count: 1,
      ),
  ],
  'series': <Object?>[
    if (!empty) ...<Object?>[
      seriesPointJson(
        '2026-10-27',
        income: '85000.00',
        netExpense: '1749.50',
        net: '83250.50',
      ),
      seriesPointJson('2026-11-03', netExpense: '2860.00', net: '-2860.00'),
      if (withUsd)
        seriesPointJson(
          '2026-10-27',
          currency: 'USD',
          income: '300.00',
          netExpense: '45.20',
          net: '254.80',
        ),
    ],
  ],
  'series_granularity': granularity,
  'coverage': <String, Object?>{
    'transaction_count': empty ? 0 : 7,
    'uncategorized_count': empty ? 0 : 7,
    'pending_count': empty ? 0 : 1,
    'provider_synced': false,
  },
});

/// A `CategorySlice` JSON object.
Map<String, Object?> categorySliceJson({
  String? id = 'cat-groceries',
  String name = 'Groceries',
  String? systemKey,
  String amount = '1250.50',
  int shareBp = 2713,
  int count = 1,
  String currency = 'INR',
}) => <String, Object?>{
  'category_id': ?id,
  'name': name,
  'system_key': ?systemKey,
  'currency': currency,
  'amount': moneyJson(amount, currency: currency),
  'net_expense': moneyJson(amount, currency: currency),
  'count': count,
  'share_bp': shareBp,
  'subcategory': false,
  'drill_down_path':
      '/transactions?from=2026-11-01&to=2026-11-30&${id == null ? 'uncategorized=true' : 'category_id=$id'}',
};

/// A `CategoryReport`.
CategoryReport categoryReport({List<Map<String, Object?>>? slices}) =>
    CategoryReport.fromJson(<String, Object?>{
      'window': windowJson(),
      'kind': 'expense',
      'categories':
          slices ??
          <Object?>[
            categorySliceJson(
              id: null,
              name: 'Uncategorized',
              systemKey: 'uncategorized',
              amount: '3359.00',
              shareBp: 7287,
              count: 3,
            ),
            categorySliceJson(),
          ],
    });

/// A `MerchantReport`.
MerchantReport merchantReport({bool empty = false}) =>
    MerchantReport.fromJson(<String, Object?>{
      'window': windowJson(),
      'merchants': <Object?>[
        if (!empty) ...<Object?>[
          <String, Object?>{
            'merchant_id': 'mer-croma',
            'name': 'Croma',
            'currency': 'INR',
            'net_expense': moneyJson('2100.00'),
            'count': 1,
          },
          <String, Object?>{
            'merchant_id': 'mer-bigbazaar',
            'name': 'Big Bazaar',
            'currency': 'INR',
            'net_expense': moneyJson('1250.50'),
            'count': 2,
          },
        ],
      ],
    });

/// A `PaymentMethodReport` in the live shape: a card, an archived wallet,
/// the bucket without a payment method, and a USD card.
PaymentMethodReport paymentMethodReport({bool empty = false}) =>
    PaymentMethodReport.fromJson(<String, Object?>{
      'window': windowJson(),
      'payment_methods': <Object?>[
        if (!empty) ...<Object?>[
          <String, Object?>{
            'payment_method_id': 'pm-hdfc',
            'key': 'pm-hdfc',
            'label': 'HDFC Card',
            'kind': 'credit_card',
            'network': 'visa',
            'masked_hint': '4321',
            'archived': false,
            'currency': 'INR',
            'net_expense': moneyJson('300.00'),
            'count': 1,
            'share_bp': 5994,
            'drill_down_path':
                '/transactions?from=2026-11-01&to=2026-11-30&currency=INR'
                '&payment_method_id=pm-hdfc',
          },
          <String, Object?>{
            'key': 'unspecified',
            'label': 'Unspecified',
            'kind': 'unspecified',
            'archived': false,
            'currency': 'INR',
            'net_expense': moneyJson('200.50'),
            'count': 2,
            'share_bp': 4006,
            'drill_down_path':
                '/transactions?from=2026-11-01&to=2026-11-30&currency=INR'
                '&payment_method_id=none',
          },
          <String, Object?>{
            'payment_method_id': 'pm-old',
            'key': 'pm-old',
            'label': 'Old wallet',
            'kind': 'wallet',
            'archived': true,
            'currency': 'INR',
            'net_expense': moneyJson('0.50'),
            'count': 1,
            'share_bp': 0,
            'drill_down_path':
                '/transactions?from=2026-11-01&to=2026-11-30&currency=INR'
                '&payment_method_id=pm-old',
          },
          <String, Object?>{
            'payment_method_id': 'pm-amex',
            'key': 'pm-amex',
            'label': 'Travel card',
            'kind': 'credit_card',
            'archived': false,
            'currency': 'USD',
            'net_expense': <String, Object?>{
              'amount_minor': 9900,
              'amount': '99.00',
              'currency': 'USD',
            },
            'count': 1,
            'share_bp': 10000,
            'drill_down_path':
                '/transactions?currency=USD&payment_method_id=pm-amex',
          },
        ],
      ],
    });

/// An `AccountsReport` with INR and USD totals.
AccountsReport accountsReport({bool empty = false}) =>
    AccountsReport.fromJson(<String, Object?>{
      'totals': <Object?>[
        if (!empty) ...<Object?>[
          <String, Object?>{
            'currency': 'INR',
            'assets': moneyJson('131410.50'),
            'liabilities': moneyJson('-2100.00'),
            'net_worth': moneyJson('129310.50'),
            'account_count': 2,
          },
          <String, Object?>{
            'currency': 'USD',
            'assets': moneyJson('1454.80', currency: 'USD'),
            'liabilities': moneyJson('0.00', currency: 'USD'),
            'net_worth': moneyJson('1454.80', currency: 'USD'),
            'account_count': 1,
          },
        ],
      ],
    });

/// `GET /analytics/budgets` as the live server sent it (one budget over its
/// limit), or no budgets when [empty].
BudgetPerformance budgetPerformance({bool empty = false}) => empty
    ? BudgetPerformance.fromJson(<String, Object?>{
        'budgets': <Object?>[],
        'by_pace': <String, Object?>{},
        'over_count': 0,
      })
    : BudgetPerformance.fromJson(
        jsonDecode(liveBudgetPerformanceJson) as Map<String, Object?>,
      );

/// `GET /analytics/goals` as the live server sent it.
GoalReport goalReport({bool empty = false}) => empty
    ? GoalReport.fromJson(<String, Object?>{
        'totals': <Object?>[],
        'goals': <Object?>[],
      })
    : GoalReport.fromJson(
        jsonDecode(liveGoalReportJson) as Map<String, Object?>,
      );

/// `GET /analytics/subscriptions` as the live server sent it.
SubscriptionSummary subscriptionSummary({bool empty = false}) => empty
    ? SubscriptionSummary.fromJson(<String, Object?>{
        'totals': <Object?>[],
        'upcoming_renewals': <Object?>[],
        'trials_ending_soon': <Object?>[],
        'pending_detections': 0,
      })
    : SubscriptionSummary.fromJson(
        jsonDecode(liveSubscriptionSummaryJson) as Map<String, Object?>,
      );

/// `GET /analytics/recurring` (live shape).
RecurringReport recurringReport({bool empty = false}) =>
    RecurringReport.fromJson(<String, Object?>{
      'commitments': <Object?>[
        if (!empty) ...<Object?>[
          <String, Object?>{
            'kind': 'expense',
            'currency': 'INR',
            'monthly_equivalent': moneyJson('15000.00'),
            'rule_count': 1,
            'variable_count': 1,
            'next_30_days': moneyJson('15000.00'),
          },
          <String, Object?>{
            'kind': 'income',
            'currency': 'INR',
            'monthly_equivalent': moneyJson('85000.00'),
            'rule_count': 1,
            'variable_count': 0,
            'next_30_days': moneyJson('85000.00'),
          },
        ],
      ],
      'note':
          'Monthly equivalents use fixed rule amounts only; bills and income '
          'are expectations, not recorded money.',
      'note_code': 'fixed_amounts_expectations',
    });

/// `GET /analytics/compare` (live shape) for November against October.
Comparison comparison() => Comparison.fromJson(<String, Object?>{
  'window': windowJson(),
  'comparison_window': windowJson(
    from: '2026-10-01',
    to: '2026-10-31',
    days: 31,
  ),
  'currencies': <Object?>[
    <String, Object?>{
      'currency': 'INR',
      'current': cashFlowTotalsJson(),
      'comparison': cashFlowTotalsJson(
        income: '0.00',
        grossExpense: '320.00',
        netExpense: '320.00',
        net: '-320.00',
        savingsRateBp: null,
        count: 1,
      ),
      'change': totalsChangeJson(),
      'categories': <Object?>[
        <String, Object?>{
          'name': 'Uncategorized',
          'system_key': 'uncategorized',
          'current': moneyJson('4609.50'),
          'comparison': moneyJson('320.00'),
          'change': moneyJson('4289.50'),
          'change_bp': 134047,
        },
        <String, Object?>{
          'category_id': 'cat-books',
          'name': 'Books',
          'current': moneyJson('250.00'),
          'comparison': moneyJson('0.00'),
          'change': moneyJson('250.00'),
        },
      ],
    },
    <String, Object?>{
      'currency': 'USD',
      'current': cashFlowTotalsJson(
        currency: 'USD',
        income: '300.00',
        grossExpense: '45.20',
        netExpense: '45.20',
        net: '254.80',
        count: 2,
      ),
      'comparison': cashFlowTotalsJson(
        currency: 'USD',
        income: '0.00',
        grossExpense: '0.00',
        netExpense: '0.00',
        net: '0.00',
        savingsRateBp: null,
        count: 0,
      ),
      'change': totalsChangeJson(),
      'categories': <Object?>[],
    },
  ],
  'notes': <Object?>[
    'Both periods use the same filters and rules: transfers excluded, refunds reduce spending.',
    'Different period lengths are compared as totals, not per day.',
  ],
  'note_codes': <Object?>['same_filters_and_rules', 'compared_as_totals'],
});

/// A `TotalsChange` (`CurrencyComparison.change`).
Map<String, Object?> totalsChangeJson({
  String currency = 'INR',
}) => <String, Object?>{
  'income': <String, Object?>{
    'change': moneyJson('1500.00', currency: currency),
    'change_bp': 10000,
  },
  'gross_expense': <String, Object?>{
    'change': moneyJson('-200.00', currency: currency),
    'change_bp': -625,
  },
  'refunds': <String, Object?>{'change': moneyJson('0.00', currency: currency)},
  'net_expense': <String, Object?>{
    'change': moneyJson('-200.00', currency: currency),
    'change_bp': -625,
  },
  'net_cash_flow': <String, Object?>{
    'change': moneyJson('1700.00', currency: currency),
    'change_bp': 53125,
  },
  'transaction_count': 1,
};

// ---------------------------------------------------------------- Reports

/// A `ReportDTO` JSON object (live shape).
Map<String, Object?> reportJson({
  String id = 'rep-1',
  String type = 'monthly_summary',
  String title = 'Monthly summary',
  String format = 'csv',
  String status = 'completed',
  int? rows = 22,
  String? errorCode,
  String? expiresAt = '2036-11-12T09:49:59Z',
  Map<String, Object?> filters = const <String, Object?>{'range': 'this_month'},
}) => <String, Object?>{
  'id': id,
  'report_type': type,
  'title': title,
  'format': format,
  'filters': filters,
  'timezone': 'Asia/Kolkata',
  'status': status,
  'row_count': ?(status == 'completed' ? rows : null),
  'error_code': ?errorCode,
  'requested_at': '2026-11-05T09:49:58Z',
  if (status == 'completed') 'completed_at': '2026-11-05T09:49:59Z',
  if (status == 'completed' || status == 'expired') 'expires_at': ?expiresAt,
};

/// A `ReportDTO`.
ReportDto report({
  String id = 'rep-1',
  String type = 'monthly_summary',
  String title = 'Monthly summary',
  String format = 'csv',
  String status = 'completed',
  String? errorCode,
  String? expiresAt = '2036-11-12T09:49:59Z',
}) => ReportDto.fromJson(
  reportJson(
    id: id,
    type: type,
    title: title,
    format: format,
    status: status,
    errorCode: errorCode,
    expiresAt: expiresAt,
  ),
);

/// A `ScheduleDTO`.
ScheduleDto schedule({
  String id = 'sch-1',
  String type = 'cash_flow',
  String title = 'Cash flow (weekly)',
  String format = 'csv',
  String cadence = 'weekly',
  bool enabled = true,
  int version = 1,
}) => ScheduleDto.fromJson(<String, Object?>{
  'id': id,
  'report_type': type,
  'title': title,
  'format': format,
  'cadence': cadence,
  'filters': <String, Object?>{'range': 'last_month'},
  'next_run_at': '2026-11-09T00:30:00Z',
  'enabled': enabled,
  'version': version,
});

// ---------------------------------------------------------- Exchange rates

/// A `RateDTO` (the list sends 12 decimal places).
RateDto rateDto({
  String id = 'rate-1',
  String base = 'USD',
  String quote = 'INR',
  String rate = '83.123400000000',
  String source = 'manual',
  bool mine = true,
}) => RateDto.fromJson(<String, Object?>{
  'id': id,
  'base': base,
  'quote': quote,
  'rate': rate,
  'source': source,
  'as_of': '2026-11-05T09:50:10Z',
  'mine': mine,
  'created_at': '2026-11-05T09:50:10Z',
});

/// A `ConversionDTO` (live shape).
ConversionDto conversion({bool inverted = false}) => ConversionDto.fromJson(
  <String, Object?>{
    'from': inverted
        ? moneyJson('1000.00')
        : moneyJson('100.00', currency: 'USD'),
    'to': inverted ? moneyJson('12.03', currency: 'USD') : moneyJson('8312.34'),
    'rate': <String, Object?>{
      'base': inverted ? 'INR' : 'USD',
      'quote': inverted ? 'USD' : 'INR',
      'rate': inverted ? '0.012030306749' : '83.1234',
      'source': 'manual',
      'as_of': '2026-11-05T09:50:10Z',
      'inverted': inverted,
    },
    'policy': 'current',
    'rounding_delta': inverted ? '0.030674876148' : '0',
  },
);

// ---------------------------------------------------------- Reconciliation

/// A `ReconBalanceDTO` (live shape).
ReconBalanceDto reconBalance({
  String id = 'rb-1',
  bool balanced = false,
  String statement = '100000.00',
  String ledger = '131410.50',
  String difference = '-31410.50',
  int reconciled = 0,
  int unreconciled = 6,
  String? notes = 'October statement',
}) => ReconBalanceDto.fromJson(<String, Object?>{
  'id': id,
  'account_id': 'acc-1',
  'statement_date': '2026-11-04',
  'statement_balance': moneyJson(balanced ? ledger : statement),
  'ledger_balance': moneyJson(ledger),
  'difference': moneyJson(balanced ? '0.00' : difference),
  'status': balanced ? 'balanced' : 'unbalanced',
  'reconciled_count': reconciled,
  'unmatched_statement_rows': 0,
  'unreconciled_transactions': unreconciled,
  'notes': ?notes,
  'created_at': '2026-11-05T09:50:30Z',
});

/// A `ReconCandidateItem` JSON object.
Map<String, Object?> reconItemJson({
  String side = 'ledger',
  String? transactionId = 'tx-pending',
  String? importRowId,
  String date = '2026-11-05',
  String amount = '415.00',
  String direction = 'outflow',
  String? description = 'Uber Ride',
  String status = 'pending/manual',
}) => <String, Object?>{
  'side': side,
  'transaction_id': ?transactionId,
  'import_row_id': ?importRowId,
  'date': date,
  'amount': moneyJson(amount),
  'direction': direction,
  'description': ?description,
  'record_status': status.split('/').first,
  'source': status.contains('/') ? status.split('/').last : 'manual',
  'status': status,
};

/// A suggested match: a pending/posted pair by default (live shape).
ReconCandidate reconCandidate({
  String kind = 'pending_to_posted',
  Map<String, Object?>? left,
  List<Map<String, Object?>>? right,
}) => ReconCandidate.fromJson(<String, Object?>{
  'kind': kind,
  'cardinality': 'one_to_one',
  'left': left ?? reconItemJson(),
  'right':
      right ??
      <Object?>[
        reconItemJson(transactionId: 'tx-posted', status: 'posted/manual'),
      ],
  'confidence': '0.950',
  'reasons': <Object?>[
    'Same amount and direction',
    'Same date',
    'Similar description',
  ],
  'reason_codes': <Object?>[
    'same_amount_direction',
    'same_date',
    'similar_description',
  ],
  'reason_params': <String, Object?>{},
});

/// A confirmed match (live shape).
ReconMatchDto reconMatch({String status = 'confirmed'}) =>
    ReconMatchDto.fromJson(<String, Object?>{
      'id': 'match-1',
      'account_id': 'acc-1',
      'kind': 'pending_to_posted',
      'cardinality': 'one_to_one',
      'status': status,
      'reasons': <Object?>[
        'Pending authorization replaced by the posted transaction',
      ],
      'reason_codes': <Object?>['pending_replaced_by_posted'],
      'reason_params': <String, Object?>{},
      'total': moneyJson('415.00'),
      'items': <Object?>[
        <String, Object?>{
          'side': 'ledger',
          'transaction_id': 'tx-pending',
          'date': '2026-11-05',
          'amount': moneyJson('415.00'),
          'direction': 'outflow',
          'description': 'Uber Ride',
          'record_status': 'pending',
          'source': 'manual',
          'effect': 'voided',
          'active': status == 'confirmed',
        },
        <String, Object?>{
          'side': 'ledger',
          'transaction_id': 'tx-posted',
          'date': '2026-11-05',
          'amount': moneyJson('415.00'),
          'direction': 'outflow',
          'description': 'Uber Ride',
          'record_status': 'posted',
          'source': 'manual',
          'effect': 'none',
          'active': status == 'confirmed',
        },
      ],
      'confirmed_at': '2026-11-05T09:50:41Z',
      'created_at': '2026-11-05T09:50:41Z',
    });

// The live server's planning analytics.

/// `GET /analytics/budgets`.
const String liveBudgetPerformanceJson = r'''
{
 "budgets": [
  {
   "id": "bud-1",
   "owner_user_id": "7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11",
   "owner_display_name": "Asha",
   "name": "Monthly spending",
   "budget_type": "total",
   "period": "monthly",
   "timezone": "Asia/Kolkata",
   "currency": "INR",
   "limit": {
    "amount_minor": 400000,
    "amount": "4000.00",
    "currency": "INR"
   },
   "rollover_policy": "none",
   "include_pending": false,
   "refunds_restore": true,
   "count_group_shares": true,
   "included_account_ids": [],
   "excluded_category_ids": [],
   "merchant_ids": [],
   "alert_thresholds": [
    50,
    75,
    90,
    100
   ],
   "alert_forecast": true,
   "visibility": "private",
   "status": "active",
   "starts_on": "2026-11-01",
   "access": "owner",
   "allocations": [],
   "members": [],
   "progress": {
    "period_start": "2026-11-01",
    "period_end": "2026-11-30",
    "base_limit": {
     "amount_minor": 400000,
     "amount": "4000.00",
     "currency": "INR"
    },
    "rollover_in": {
     "amount_minor": 0,
     "amount": "0.00",
     "currency": "INR"
    },
    "limit": {
     "amount_minor": 400000,
     "amount": "4000.00",
     "currency": "INR"
    },
    "spent": {
     "amount_minor": 566950,
     "amount": "5669.50",
     "currency": "INR"
    },
    "remaining": {
     "amount_minor": 0,
     "amount": "0.00",
     "currency": "INR"
    },
    "overspent": {
     "amount_minor": 166950,
     "amount": "1669.50",
     "currency": "INR"
    },
    "percent_bp": 14174,
    "elapsed_days": 5,
    "total_days": 30,
    "expected_by_now": {
     "amount_minor": 66667,
     "amount": "666.67",
     "currency": "INR"
    },
    "projected": {
     "amount_minor": 3401700,
     "amount": "34017.00",
     "currency": "INR"
    },
    "projected_over": {
     "amount_minor": 3001700,
     "amount": "30017.00",
     "currency": "INR"
    },
    "daily_allowance": {
     "amount_minor": 0,
     "amount": "0.00",
     "currency": "INR"
    },
    "pace": "over_budget",
    "transaction_count": 7,
    "other_currency_count": 1,
    "explanation": [
     "Spent 5669.50 of 4000.00 between 2026-11-01 and 2026-11-30.",
     "Transfers and balance adjustments never count; refunds restore budget.",
     "At the current pace you would spend about 34017.00 by the end of the period (an estimate, not a guarantee).",
     "1 matching transaction(s) in other currencies are not included."
    ],
    "explanation_items": [
     {
      "code": "spent_of_limit",
      "params": {
       "currency": "INR",
       "from": "2026-11-01",
       "limit": "4000.00",
       "spent": "5669.50",
       "to": "2026-11-30"
      }
     },
     {
      "code": "refunds_restore"
     },
     {
      "code": "projection_estimate",
      "params": {
       "currency": "INR",
       "projected": "34017.00"
      }
     },
     {
      "code": "other_currencies_excluded",
      "params": {
       "count": "1"
      }
     }
    ]
   },
   "version": 1,
   "created_at": "2026-11-05T09:52:04.121022Z",
   "updated_at": "2026-11-05T09:52:04.121022Z"
  }
 ],
 "by_pace": {
  "over_budget": 1
 },
 "over_count": 1
}
''';

/// `GET /analytics/goals`.
const String liveGoalReportJson = r'''
{
 "totals": [
  {
   "currency": "INR",
   "target": {
    "amount_minor": 5000000,
    "amount": "50000.00",
    "currency": "INR"
   },
   "saved": {
    "amount_minor": 500000,
    "amount": "5000.00",
    "currency": "INR"
   },
   "count": 1,
   "achieved": 0
  }
 ],
 "goals": [
  {
   "id": "goal-1",
   "name": "Goa trip",
   "goal_type": "travel",
   "target": {
    "amount_minor": 5000000,
    "amount": "50000.00",
    "currency": "INR"
   },
   "starting": {
    "amount_minor": 500000,
    "amount": "5000.00",
    "currency": "INR"
   },
   "start_date": "2026-11-05",
   "priority": 3,
   "contribution_schedule": "none",
   "visibility": "private",
   "reminders_enabled": false,
   "status": "active",
   "owner_user_id": "7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11",
   "owner": {
    "user_id": "7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11",
    "display_name": "Asha"
   },
   "access": "owner",
   "progress": {
    "saved": {
     "amount_minor": 500000,
     "amount": "5000.00",
     "currency": "INR"
    },
    "remaining": {
     "amount_minor": 4500000,
     "amount": "45000.00",
     "currency": "INR"
    },
    "percent_bp": 1000,
    "verified": {
     "amount_minor": 0,
     "amount": "0.00",
     "currency": "INR"
    },
    "planned": {
     "amount_minor": 0,
     "amount": "0.00",
     "currency": "INR"
    },
    "contribution_count": 0
   },
   "milestones": [
    {
     "percent": 25
    },
    {
     "percent": 50
    },
    {
     "percent": 75
    },
    {
     "percent": 100
    }
   ],
   "members": [
    {
     "user_id": "7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11",
     "display_name": "Asha",
     "role": "owner",
     "contribution_visibility": "amounts",
     "joined_at": "2026-11-05T09:52:04.137911Z"
    }
   ],
   "version": 1,
   "created_at": "2026-11-05T09:52:04.137911Z"
  }
 ]
}
''';

/// `GET /analytics/subscriptions`.
const String liveSubscriptionSummaryJson = r'''
{
 "totals": [
  {
   "currency": "INR",
   "monthly": {
    "amount_minor": 11900,
    "amount": "119.00",
    "currency": "INR"
   },
   "annual": {
    "amount_minor": 142800,
    "amount": "1428.00",
    "currency": "INR"
   },
   "count": 1
  }
 ],
 "upcoming_renewals": [
  {
   "id": "sub-1",
   "name": "Music plan",
   "amount": {
    "amount_minor": 11900,
    "amount": "119.00",
    "currency": "INR"
   },
   "billing_frequency": "monthly",
   "interval_count": 1,
   "start_date": "2026-10-20",
   "next_renewal_date": "2026-11-20",
   "status": "active",
   "source": "manual",
   "cancellation_checklist": [],
   "reminder_days_before": [
    3
   ],
   "monthly_cost": {
    "amount_minor": 11900,
    "amount": "119.00",
    "currency": "INR"
   },
   "annual_cost": {
    "amount_minor": 142800,
    "amount": "1428.00",
    "currency": "INR"
   },
   "duplicate_warnings": [],
   "owned": true,
   "version": 1,
   "created_at": "2026-11-05T09:52:04.151786Z"
  }
 ],
 "trials_ending_soon": [],
 "pending_detections": 0
}
''';

/// A `StatementLineDTO` as JSON (live shape: a line skipped as a possible
/// duplicate).
Map<String, Object?> statementLineJson({
  String id = 'row-2',
  String date = '2026-11-04',
  String amount = '415.00',
  String direction = 'outflow',
  String? description = 'CAB AIRPORT 9921',
  String status = 'duplicate',
  String? errorCode = 'possible_duplicate',
  String? matchId,
}) => <String, Object?>{
  'import_row_id': id,
  'batch_id': 'b-1',
  'row_number': 2,
  'date': date,
  'amount': moneyJson(amount),
  'direction': direction,
  'description': ?description,
  'record_status': status,
  'error_code': ?errorCode,
  'match_id': ?matchId,
};

/// A `StatementLineDTO`.
StatementLineDto statementLine({
  String id = 'row-2',
  String? description = 'CAB AIRPORT 9921',
  String? matchId,
}) => StatementLineDto.fromJson(
  statementLineJson(id: id, description: description, matchId: matchId),
);
