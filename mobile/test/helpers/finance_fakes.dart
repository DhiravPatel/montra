import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/dashboard/domain/widget_info.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

import 'fakes.dart';

// Mocks of the typed API classes (the network boundary of each feature).
class MockAccountsApi extends Mock implements AccountsApi {}

class MockTransactionsApi extends Mock implements TransactionsApi {}

class MockDashboardApi extends Mock implements DashboardApi {}

class MockLabelsApi extends Mock implements LabelsApi {}

class MockPaymentMethodsApi extends Mock implements PaymentMethodsApi {}

class MockPreferencesApi extends Mock implements PreferencesApi {}

/// Registers fallback values for `any()` matchers.
void registerFinanceFallbacks() {
  registerFallbackValue(const TransactionFilter());
  registerFallbackValue(const DateRangeChoice.named('this_month'));
  registerFallbackValue(
    const AccountInput(
      accountType: AccountInputAccountType.cash,
      currency: 'INR',
      name: 'x',
    ),
  );
  registerFallbackValue(const AccountPatch(version: 1));
  registerFallbackValue(const AdjustmentInput(reason: 'x'));
  registerFallbackValue(
    const TransactionInput(
      accountId: 'a',
      amount: '1',
      typeValue: TransactionInputType.expense,
    ),
  );
  registerFallbackValue(const TransactionPatch(version: 1));
  registerFallbackValue(const RefundInput(amount: '1'));
  registerFallbackValue(
    const TransferInput(amount: '1', fromAccountId: 'a', toAccountId: 'b'),
  );
  registerFallbackValue(const BulkUpdateInput(transactionIds: <String>['x']));
  registerFallbackValue(
    const PaymentMethodInput(kind: PaymentMethodInputKind.cash, label: 'x'),
  );
  registerFallbackValue(const PaymentMethodPatch());
  registerFallbackValue(const PreferencesPatch());
  registerFallbackValue(<DashboardWidget>[]);
}

/// Minor units of a decimal string for test fixtures only (the app never
/// derives money this way).
int _minor(String amount, int exponent) {
  final bool negative = amount.startsWith('-');
  final String digits = negative ? amount.substring(1) : amount;
  final List<String> parts = digits.split('.');
  final String fraction = (parts.length > 1 ? parts[1] : '').padRight(
    exponent,
    '0',
  );
  final int value = int.parse('${parts[0]}${fraction.substring(0, exponent)}');
  return negative ? -value : value;
}

/// A `Money` JSON object.
Map<String, Object?> moneyJson(String amount, {String currency = 'INR'}) {
  final int exponent = currency == 'JPY' ? 0 : (currency == 'KWD' ? 3 : 2);
  return <String, Object?>{
    'amount': amount,
    'amount_minor': _minor(amount, exponent),
    'currency': currency,
  };
}

/// A `Money` value.
Money money(String amount, {String currency = 'INR'}) =>
    Money.fromJson(moneyJson(amount, currency: currency));

/// An `AccountDTO` JSON object.
Map<String, Object?> accountJson({
  String id = 'acc-1',
  String name = 'HDFC Savings',
  String type = 'savings',
  String currency = 'INR',
  String balance = '25000.50',
  String status = 'active',
  bool owned = true,
  bool includeInOverview = true,
  String? institution = 'HDFC',
  String? masked = '4821',
  String? creditLimit,
  String? availableCredit,
  int? statementDay,
  int? paymentDueDay,
  int version = 1,
  String balanceSource = 'calculated',
}) => <String, Object?>{
  'id': id,
  'name': name,
  'account_type': type,
  'is_liability': type == 'credit_card' || type == 'loan',
  'currency': currency,
  'institution_label': ?institution,
  'masked_number': ?masked,
  'include_in_overview': includeInOverview,
  if (creditLimit != null)
    'credit_limit': moneyJson(creditLimit, currency: currency),
  if (availableCredit != null)
    'available_credit': moneyJson(availableCredit, currency: currency),
  'statement_day': ?statementDay,
  'payment_due_day': ?paymentDueDay,
  'opening_date': '2026-11-01',
  'balance': moneyJson(balance, currency: currency),
  'balance_source': balanceSource,
  'status': status,
  'display_order': 0,
  'shared_with_group': false,
  'owned': owned,
  'version': version,
  'created_at': '2026-11-01T08:00:00Z',
  'updated_at': '2026-11-01T08:00:00Z',
};

/// An `AccountDTO`.
AccountDto account({
  String id = 'acc-1',
  String name = 'HDFC Savings',
  String type = 'savings',
  String currency = 'INR',
  String balance = '25000.50',
  String status = 'active',
  bool owned = true,
  String? creditLimit,
  String? availableCredit,
  int version = 1,
}) => AccountDto.fromJson(
  accountJson(
    id: id,
    name: name,
    type: type,
    currency: currency,
    balance: balance,
    status: status,
    owned: owned,
    creditLimit: creditLimit,
    availableCredit: availableCredit,
    version: version,
  ),
);

/// A `TransactionDTO` JSON object.
Map<String, Object?> transactionJson({
  String id = 'tx-1',
  String type = 'expense',
  String direction = 'outflow',
  String status = 'posted',
  String amount = '1250.75',
  String currency = 'INR',
  String accountId = 'acc-1',
  String accountName = 'HDFC Savings',
  String localDate = '2026-11-04',
  String? merchant = 'Big Bazaar',
  String? categoryId = 'cat-groceries',
  String? categoryName = 'Groceries',
  String? description = 'Weekly groceries',
  String? notes,
  String refunded = '0.00',
  String? transferId,
  String? originalTransactionId,
  List<Map<String, Object?>> tags = const <Map<String, Object?>>[],
  bool owned = true,
  int version = 1,
  int attachmentCount = 0,
  String source = 'manual',
}) => <String, Object?>{
  'id': id,
  'account_id': accountId,
  'account_name': accountName,
  'type': type,
  'direction': direction,
  'status': status,
  'amount': moneyJson(amount, currency: currency),
  'occurred_at': '${localDate}T07:00:00Z',
  'local_date': localDate,
  'timezone': 'Asia/Kolkata',
  if (categoryId != null)
    'category': <String, Object?>{
      'id': categoryId,
      'name': categoryName ?? '',
      'icon': 'shopping_cart',
      'color': '#81B29A',
    },
  if (merchant != null)
    'merchant': <String, Object?>{'id': 'mer-1', 'name': merchant},
  'description': ?description,
  'notes': ?notes,
  'tags': tags,
  'refunded_total': moneyJson(refunded, currency: currency),
  'transfer_id': ?transferId,
  'original_transaction_id': ?originalTransactionId,
  'source': source,
  'reconciliation_state': 'unreconciled',
  'is_correction': false,
  'attachment_count': attachmentCount,
  'owned': owned,
  'version': version,
  'created_at': '2026-11-04T07:00:00Z',
  'updated_at': '2026-11-04T07:00:00Z',
  if (status == 'voided') 'deleted_at': '2026-11-04T08:00:00Z',
};

/// A `TransactionDTO`.
TransactionDto transaction({
  String id = 'tx-1',
  String type = 'expense',
  String direction = 'outflow',
  String status = 'posted',
  String amount = '1250.75',
  String currency = 'INR',
  String localDate = '2026-11-04',
  String? merchant = 'Big Bazaar',
  String? categoryId = 'cat-groceries',
  String? categoryName = 'Groceries',
  String? description = 'Weekly groceries',
  String refunded = '0.00',
  String? transferId,
  int version = 1,
  String accountId = 'acc-1',
  String accountName = 'HDFC Savings',
}) => TransactionDto.fromJson(
  transactionJson(
    id: id,
    type: type,
    direction: direction,
    status: status,
    amount: amount,
    currency: currency,
    localDate: localDate,
    merchant: merchant,
    categoryId: categoryId,
    categoryName: categoryName,
    description: description,
    refunded: refunded,
    transferId: transferId,
    version: version,
    accountId: accountId,
    accountName: accountName,
  ),
);

/// A `CreateResult` for [tx] with optional duplicate hints.
CreateResult createResult(
  TransactionDto tx, {
  List<String> duplicateIds = const <String>[],
}) => CreateResult.fromJson(<String, Object?>{
  'transaction': tx.toJson(),
  'possible_duplicates': <Map<String, Object?>>[
    for (final String id in duplicateIds)
      <String, Object?>{
        'transaction_id': id,
        'local_date': '2026-11-04',
        'reasons': <String>['same amount'],
        'reason_codes': <String>['same_account_amount', 'same_date'],
        'days_apart': 0,
      },
  ],
});

/// A `CategoryDTO` JSON object.
CategoryDto category({
  String id = 'cat-groceries',
  String name = 'Groceries',
  String? systemKey = 'groceries',
  String kind = 'expense',
  String? parentId,
  int sortOrder = 10,
}) => CategoryDto.fromJson(<String, Object?>{
  'id': id,
  'name': name,
  'kind': kind,
  'icon': 'shopping_cart',
  'color': '#81B29A',
  'system_key': ?systemKey,
  'parent_id': ?parentId,
  'include_in_budgets': true,
  'sort_order': sortOrder,
  'status': 'active',
  'transaction_count': 3,
  'version': 1,
  'updated_at': '2026-11-01T08:00:00Z',
});

/// A `TagDTO`.
TagDto tag({String id = 'tag-1', String name = 'home', int usage = 2}) =>
    TagDto.fromJson(<String, Object?>{
      'id': id,
      'name': name,
      'usage_count': usage,
      'version': 1,
    });

/// A `PaymentMethodDTO`.
PaymentMethodDto paymentMethod({
  String id = 'pm-1',
  String kind = 'upi',
  String label = 'GPay',
  String? hint = '••21',
  bool isDefault = false,
  bool archived = false,
  String? accountId,
}) => PaymentMethodDto.fromJson(<String, Object?>{
  'id': id,
  'kind': kind,
  'label': label,
  'masked_hint': ?hint,
  'is_default': isDefault,
  'account_id': ?accountId,
  if (archived) 'archived_at': '2026-11-02T08:00:00Z',
  'version': 1,
});

/// A `PreferencesDTO`.
PreferencesDto preferences({
  String baseCurrency = 'INR',
  String timezone = 'Asia/Kolkata',
  String? country = 'IN',
  String defaultRange = 'this_month',
  bool onboardingCompleted = false,
  String dateFormat = 'locale',
  int weekStart = 1,
  int monthStartDay = 1,
  String emailDigest = 'off',
  String locale = 'en-IN',
}) => PreferencesDto.fromJson(<String, Object?>{
  'locale': locale,
  'timezone': timezone,
  'base_currency': baseCurrency,
  'country': ?country,
  'date_format': dateFormat,
  'number_format': 'locale',
  'week_start': weekStart,
  'month_start_day': monthStartDay,
  'theme': 'system',
  'reduced_motion': false,
  'high_contrast': false,
  'text_scale_percent': 100,
  'default_date_range': defaultRange,
  'quiet_hours_enabled': false,
  'quiet_hours_start': '22:00',
  'quiet_hours_end': '07:00',
  'email_digest': emailDigest,
  'ai_enabled': false,
  'analytics_opt_in': false,
  'onboarding_completed': onboardingCompleted,
  'updated_at': '2026-11-01T08:00:00Z',
});

/// The server's default widget layout (all fifteen widgets) as wire keys.
const List<String> defaultWidgetKeys = <String>[
  'balances',
  'cash_flow',
  'alerts',
  'budgets',
  'upcoming',
  'renewals',
  'income_vs_expense',
  'cash_flow_trend',
  'category_breakdown',
  'top_merchants',
  'recurring',
  'goals',
  'group_balances',
  'recent_transactions',
  'data_coverage',
];

/// A widget layout; [hidden] keys are not visible.
List<DashboardWidget> widgetLayout({
  List<String> keys = defaultWidgetKeys,
  Set<String> hidden = const <String>{},
}) => <DashboardWidget>[
  for (int i = 0; i < keys.length; i++)
    DashboardWidget(
      key: keys[i],
      position: i,
      visible: !hidden.contains(keys[i]),
    ),
];

/// A `DashboardSummary` with activity in INR (and optionally USD).
DashboardSummary summary({
  bool empty = false,
  bool withUsd = false,
  String generatedAt = '2026-11-04T09:58:00Z',
}) {
  final List<Map<String, Object?>> cashFlow = empty
      ? <Map<String, Object?>>[]
      : <Map<String, Object?>>[
          <String, Object?>{
            'currency': 'INR',
            'income': moneyJson('85000.00'),
            'gross_expense': moneyJson('1260.75'),
            'refunds': moneyJson('250.75'),
            'net_expense': moneyJson('1010.00'),
            'net_cash_flow': moneyJson('83990.00'),
            'savings_rate_bp': 9881,
            'transaction_count': 4,
          },
          if (withUsd)
            <String, Object?>{
              'currency': 'USD',
              'income': moneyJson('0.00', currency: 'USD'),
              'gross_expense': moneyJson('40.00', currency: 'USD'),
              'refunds': moneyJson('0.00', currency: 'USD'),
              'net_expense': moneyJson('40.00', currency: 'USD'),
              'net_cash_flow': moneyJson('-40.00', currency: 'USD'),
              'transaction_count': 1,
            },
        ];
  return DashboardSummary.fromJson(<String, Object?>{
    'window': <String, Object?>{
      'from': '2026-11-01',
      'to': '2026-11-30',
      'days': 30,
      'timezone': 'Asia/Kolkata',
    },
    'balances': empty
        ? <Object?>[]
        : <Object?>[
            <String, Object?>{
              'currency': 'INR',
              'assets': moneyJson('97390.50'),
              'liabilities': moneyJson('3200.00'),
              'net_worth': moneyJson('94190.50'),
              'account_count': 2,
            },
          ],
    'cash_flow': cashFlow,
    'previous_cash_flow': <Object?>[],
    'trend': empty
        ? <Object?>[]
        : <Object?>[
            <String, Object?>{
              'bucket': '2026-11-03',
              'currency': 'INR',
              'income': moneyJson('0.00'),
              'net_expense': moneyJson('400.00'),
              'net': moneyJson('-400.00'),
            },
            <String, Object?>{
              'bucket': '2026-11-04',
              'currency': 'INR',
              'income': moneyJson('85000.00'),
              'net_expense': moneyJson('610.00'),
              'net': moneyJson('84390.00'),
            },
          ],
    'top_categories': empty
        ? <Object?>[]
        : <Object?>[
            <String, Object?>{
              'category_id': 'cat-groceries',
              'name': 'Groceries',
              'currency': 'INR',
              'amount': moneyJson('1000.00'),
              'net_expense': moneyJson('1000.00'),
              'count': 2,
              'share_bp': 9901,
              'subcategory': false,
              'drill_down_path': '/transactions?from=2026-11-01&to=2026-11-30&category_id=cat-groceries',
            },
          ],
    'top_merchants': empty
        ? <Object?>[]
        : <Object?>[
            <String, Object?>{
              'merchant_id': 'mer-1',
              'name': 'Big Bazaar',
              'currency': 'INR',
              'net_expense': moneyJson('1250.75'),
              'count': 1,
            },
          ],
    'recent_transactions': empty ? <Object?>[] : <Object?>[transactionJson()],
    'coverage': <String, Object?>{
      'transaction_count': empty ? 0 : 4,
      'uncategorized_count': 1,
      'pending_count': 0,
      'provider_synced': false,
      if (!empty) 'earliest_transaction': '2026-11-03',
      if (!empty) 'latest_transaction': '2026-11-04',
    },
    'generated_at': generatedAt,
    'notes': <String>[
      'Transfers between your accounts are excluded from income and spending.',
    ],
    'note_codes': <String>['excludes_transfers_adjustments'],
    'trend_granularity': 'day',
  });
}

/// A server error for tests.
ApiException serverError(
  ErrorObjectCode code, {
  int status = 422,
  String message = 'Server message',
  List<Detail> details = const <Detail>[],
  String requestId = 'req-err',
}) => ApiException(
  kind: ApiErrorKind.server,
  code: code,
  statusCode: status,
  message: message,
  details: details,
  requestId: requestId,
);

/// A transport failure for tests.
const ApiException offline = ApiException(kind: ApiErrorKind.network);

/// One page of transactions.
CursorPage<TransactionDto> page(List<TransactionDto> items, {String? next}) =>
    CursorPage<TransactionDto>(items, next);

/// Stubs the label APIs with empty (or given) data so pickers and name
/// lookups resolve in widget tests.
void stubLabels(
  MockLabelsApi labels, {
  List<CategoryDto> categories = const <CategoryDto>[],
  List<TagDto> tags = const <TagDto>[],
}) {
  when(
    () => labels.listCategories(includeArchived: any(named: 'includeArchived')),
  ).thenAnswer((_) async => categories);
  when(() => labels.listTags()).thenAnswer((_) async => tags);
  when(() => labels.searchMerchants(any(), limit: any(named: 'limit')))
      .thenAnswer((_) async => <MerchantDto>[]);
}

/// Overrides that put a signed-in user in the auth state (no network).
List<Override> signedInOverrides({bool onboardingCompleted = true}) =>
    <Override>[
      authControllerProvider.overrideWith(
        () => _SignedInController(onboardingCompleted),
      ),
    ];

class _SignedInController extends AuthController {
  _SignedInController(this.onboardingCompleted);

  final bool onboardingCompleted;

  @override
  AuthState build() => SignedIn(
    user: UserDto.fromJson(userJson(onboardingCompleted: onboardingCompleted)),
  );
}
