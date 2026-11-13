import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/analytics/data/analytics_api.dart';
import 'package:montra_mobile/features/analytics/domain/analytics_query.dart';

/// The signed-in user's main currency (shown first among currencies).
final Provider<String?> analyticsBaseCurrencyProvider = Provider<String?>(
  (Ref ref) => ref.watch(
    authControllerProvider.select(
      (AuthState s) => s is SignedIn ? s.user.baseCurrency : null,
    ),
  ),
);

/// Cash flow for a period in every currency: the overview figures and the
/// currencies offered as chips. Re-read after finance writes.
final FutureProviderFamily<CashFlowReport, DateRangeChoice>
analyticsOverviewProvider = FutureProvider.autoDispose
    .family<CashFlowReport, DateRangeChoice>((Ref ref, DateRangeChoice range) {
      ref.watch(financeRevisionProvider);
      return ref.read(analyticsApiProvider).cashFlow(range);
    });

/// Currencies with activity in [report], ordered with [base] first.
List<String> reportCurrencies(CashFlowReport report, String? base) =>
    orderCurrencies(<String>[
      for (final CashFlowTotals t in report.totals)
        if (t.transactionCount > 0) t.currency,
    ], base);

/// A series report for one currency.
typedef SeriesArgs = ({
  AnalyticsReport report,
  DateRangeChoice range,
  String currency,
  String? granularity,
});

/// Cash flow, expenses or income over time in one currency.
final FutureProviderFamily<CashFlowReport, SeriesArgs> analyticsSeriesProvider =
    FutureProvider.autoDispose.family<CashFlowReport, SeriesArgs>((
      Ref ref,
      SeriesArgs args,
    ) {
      ref.watch(financeRevisionProvider);
      final AnalyticsApi api = ref.read(analyticsApiProvider);
      return switch (args.report) {
        AnalyticsReport.expenses => api.expenses(
          args.range,
          currency: args.currency,
          granularity: args.granularity,
        ),
        AnalyticsReport.income => api.income(
          args.range,
          currency: args.currency,
          granularity: args.granularity,
        ),
        _ => api.cashFlow(
          args.range,
          currency: args.currency,
          granularity: args.granularity,
        ),
      };
    });

/// The category breakdown in one currency.
typedef CategoryArgs = ({
  DateRangeChoice range,
  String currency,
  bool subcategories,
  bool income,
});

/// Spending (or income) by category in one currency.
final FutureProviderFamily<CategoryReport, CategoryArgs>
analyticsCategoriesProvider = FutureProvider.autoDispose
    .family<CategoryReport, CategoryArgs>((Ref ref, CategoryArgs args) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(analyticsApiProvider)
          .categories(
            args.range,
            currency: args.currency,
            subcategories: args.subcategories,
            income: args.income,
          );
    });

/// The top merchants in one currency.
typedef MerchantArgs = ({DateRangeChoice range, String currency});

/// Top merchants by spending in one currency.
final FutureProviderFamily<MerchantReport, MerchantArgs>
analyticsMerchantsProvider = FutureProvider.autoDispose
    .family<MerchantReport, MerchantArgs>((Ref ref, MerchantArgs args) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(analyticsApiProvider)
          .merchants(args.range, currency: args.currency);
    });

/// Spending by payment method in one currency.
final FutureProviderFamily<PaymentMethodReport, MerchantArgs>
analyticsPaymentMethodsProvider = FutureProvider.autoDispose
    .family<PaymentMethodReport, MerchantArgs>((Ref ref, MerchantArgs args) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(analyticsApiProvider)
          .paymentMethods(args.range, currency: args.currency);
    });

/// Assets, liabilities and net worth per currency.
final FutureProviderFamily<AccountsReport, bool> analyticsAccountsProvider =
    FutureProvider.autoDispose.family<AccountsReport, bool>((
      Ref ref,
      bool overviewOnly,
    ) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(analyticsApiProvider)
          .accounts(overviewOnly: overviewOnly);
    });

/// Budget performance.
final FutureProvider<BudgetPerformance> analyticsBudgetsProvider =
    FutureProvider.autoDispose<BudgetPerformance>((Ref ref) {
      ref.watch(financeRevisionProvider);
      return ref.read(analyticsApiProvider).budgets();
    });

/// Goal progress.
final FutureProvider<GoalReport> analyticsGoalsProvider =
    FutureProvider.autoDispose<GoalReport>((Ref ref) {
      ref.watch(financeRevisionProvider);
      return ref.read(analyticsApiProvider).goals();
    });

/// Subscription costs.
final FutureProvider<SubscriptionSummary> analyticsSubscriptionsProvider =
    FutureProvider.autoDispose<SubscriptionSummary>((Ref ref) {
      ref.watch(financeRevisionProvider);
      return ref.read(analyticsApiProvider).subscriptions();
    });

/// Recurring commitments.
final FutureProvider<RecurringReport> analyticsRecurringProvider =
    FutureProvider.autoDispose<RecurringReport>((Ref ref) {
      ref.watch(financeRevisionProvider);
      return ref.read(analyticsApiProvider).recurring();
    });

/// Two periods to compare.
typedef CompareArgs = ({
  DateRangeChoice range,
  String compareFrom,
  String compareTo,
});

/// A period compared with another one, per currency.
final FutureProviderFamily<Comparison, CompareArgs> analyticsCompareProvider =
    FutureProvider.autoDispose.family<Comparison, CompareArgs>((
      Ref ref,
      CompareArgs args,
    ) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(analyticsApiProvider)
          .compare(
            args.range,
            compareFrom: args.compareFrom,
            compareTo: args.compareTo,
          );
    });
