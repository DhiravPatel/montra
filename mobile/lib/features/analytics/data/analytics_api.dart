import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/analytics/domain/analytics_query.dart';

/// Typed calls for the `Analytics` tag of the contract. Every figure is
/// computed by the server, per currency; the app never adds amounts up or
/// compares them across currencies.
class AnalyticsApi {
  /// Creates the API over [client].
  AnalyticsApi(this._client);

  final ApiClient _client;

  /// `GET /analytics/cash-flow`: income, spending and net cash flow with
  /// the previous period and a series. [currency] limits it to one
  /// currency; [granularity] (`day`, `week`, `month`, `year`) sets the
  /// bucket size (the server chooses when null).
  Future<CashFlowReport> cashFlow(
    DateRangeChoice range, {
    String? currency,
    String? granularity,
  }) => _series(ApiEndpoints.analyticsCashFlow, range, currency, granularity);

  /// `GET /analytics/expenses` (same model as cash flow).
  Future<CashFlowReport> expenses(
    DateRangeChoice range, {
    String? currency,
    String? granularity,
  }) => _series(ApiEndpoints.analyticsExpenses, range, currency, granularity);

  /// `GET /analytics/income` (same model as cash flow).
  Future<CashFlowReport> income(
    DateRangeChoice range, {
    String? currency,
    String? granularity,
  }) => _series(ApiEndpoints.analyticsIncome, range, currency, granularity);

  Future<CashFlowReport> _series(
    ApiEndpoint endpoint,
    DateRangeChoice range,
    String? currency,
    String? granularity,
  ) => _client.send(
    endpoint,
    query: <String, Object?>{
      ...rangeQuery(range),
      'currency': currency,
      'granularity': granularity,
    },
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeCashFlowReport(json).data,
  );

  /// `GET /analytics/categories`: spending (net of refunds) or, with
  /// [income], income by category, rolled up to main categories unless
  /// [subcategories] is set. Categories are ranked within each currency.
  Future<CategoryReport> categories(
    DateRangeChoice range, {
    String? currency,
    bool subcategories = false,
    bool income = false,
  }) => _client.send(
    ApiEndpoints.analyticsCategories,
    query: <String, Object?>{
      ...rangeQuery(range),
      'currency': currency,
      if (subcategories) 'subcategories': true,
      if (income) 'kind': 'income',
    },
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeCategoryReport(json).data,
  );

  /// `GET /analytics/merchants`: the top [limit] merchants by net
  /// spending. Pass [currency] so the ranking stays within one currency.
  Future<MerchantReport> merchants(
    DateRangeChoice range, {
    String? currency,
    int limit = 20,
  }) => _client.send(
    ApiEndpoints.analyticsMerchants,
    query: <String, Object?>{
      ...rangeQuery(range),
      'currency': currency,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeMerchantReport(json).data,
  );

  /// `GET /analytics/accounts`: assets, liabilities and net worth per
  /// currency (only accounts in the overview when [overviewOnly]).
  Future<AccountsReport> accounts({bool overviewOnly = false}) => _client.send(
    ApiEndpoints.analyticsAccounts,
    query: <String, Object?>{if (overviewOnly) 'overview_only': true},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeAccountsReport(json).data,
  );

  /// `GET /analytics/budgets`: active budgets in their current periods.
  Future<BudgetPerformance> budgets() => _client.send(
    ApiEndpoints.analyticsBudgets,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeBudgetPerformance(json).data,
  );

  /// `GET /analytics/goals`: goal progress per currency.
  Future<GoalReport> goals() => _client.send(
    ApiEndpoints.analyticsGoals,
    decode: (Map<String, Object?> json) => decodeEnvelopeGoalReport(json).data,
  );

  /// `GET /analytics/subscriptions`: subscription costs per currency.
  Future<SubscriptionSummary> subscriptions() => _client.send(
    ApiEndpoints.analyticsSubscriptions,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeSubscriptionSummary(json).data,
  );

  /// `GET /analytics/recurring`: recurring commitments per month.
  Future<RecurringReport> recurring() => _client.send(
    ApiEndpoints.analyticsRecurring,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeRecurringReport(json).data,
  );

  /// `GET /analytics/compare`: [range] against [compareFrom] …
  /// [compareTo] (inclusive dates), per currency with category changes.
  Future<Comparison> compare(
    DateRangeChoice range, {
    required String compareFrom,
    required String compareTo,
    String? currency,
  }) => _client.send(
    ApiEndpoints.analyticsCompare,
    query: <String, Object?>{
      ...rangeQuery(range),
      'compare_from': compareFrom,
      'compare_to': compareTo,
      'currency': currency,
    },
    decode: (Map<String, Object?> json) => decodeEnvelopeComparison(json).data,
  );
}

/// Analytics endpoints. Overridden in tests.
final Provider<AnalyticsApi> analyticsApiProvider = Provider<AnalyticsApi>(
  (Ref ref) => AnalyticsApi(ref.watch(apiClientProvider)),
);
