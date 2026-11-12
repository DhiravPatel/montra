import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/settings/application/preferences_providers.dart';

/// Widget keys the server registers today, in default order. Used when the
/// layout cannot be loaded.
const List<WidgetDtoKey> defaultWidgetKeys = <WidgetDtoKey>[
  WidgetDtoKey.balances,
  WidgetDtoKey.cashFlow,
  WidgetDtoKey.incomeVsExpense,
  WidgetDtoKey.cashFlowTrend,
  WidgetDtoKey.categoryBreakdown,
  WidgetDtoKey.topMerchants,
  WidgetDtoKey.recentTransactions,
  WidgetDtoKey.dataCoverage,
];

/// The dashboard period chosen by the user; starts from the user's
/// default range preference (or this month).
final NotifierProvider<DashboardRange, DateRangeChoice> dashboardRangeProvider =
    NotifierProvider.autoDispose<DashboardRange, DateRangeChoice>(
      DashboardRange.new,
    );

/// See [dashboardRangeProvider].
class DashboardRange extends Notifier<DateRangeChoice> {
  DateRangeChoice? _chosen;

  @override
  DateRangeChoice build() {
    final String? preferred = ref.watch(
      preferencesProvider.select(
        (AsyncValue<PreferencesDto> p) => p.value?.defaultDateRange,
      ),
    );
    return _chosen ??
        DateRangeChoice.named(
          preferred == null || preferred.isEmpty ? 'this_month' : preferred,
        );
  }

  /// Shows [range].
  void choose(DateRangeChoice range) {
    _chosen = range;
    state = range;
  }
}

/// The computed dashboard for a period; re-read after finance writes.
final FutureProviderFamily<DashboardSummary, DateRangeChoice>
dashboardSummaryProvider = FutureProvider.autoDispose
    .family<DashboardSummary, DateRangeChoice>((
      Ref ref,
      DateRangeChoice range,
    ) {
      ref.watch(financeRevisionProvider);
      return ref.read(dashboardApiProvider).summary(range);
    });

/// The widget layout (order and visibility), with save and reset.
final AsyncNotifierProvider<DashboardLayoutController, List<WidgetDto>>
dashboardLayoutProvider =
    AsyncNotifierProvider.autoDispose<
      DashboardLayoutController,
      List<WidgetDto>
    >(DashboardLayoutController.new);

/// See [dashboardLayoutProvider].
class DashboardLayoutController extends AsyncNotifier<List<WidgetDto>> {
  DashboardApi get _api => ref.read(dashboardApiProvider);

  @override
  Future<List<WidgetDto>> build() async {
    ref.watch(currentUserIdProvider);
    return sortLayout(await _api.widgets());
  }

  /// Saves [layout] (list order becomes the position).
  Future<void> save(List<WidgetDto> layout) async {
    state = AsyncData<List<WidgetDto>>(
      sortLayout(await _api.saveWidgets(layout)),
    );
  }

  /// Restores the default layout.
  Future<void> reset() async {
    state = AsyncData<List<WidgetDto>>(sortLayout(await _api.resetWidgets()));
  }

  /// Widgets by position (stable for equal positions).
  static List<WidgetDto> sortLayout(List<WidgetDto> widgets) {
    final List<(int, WidgetDto)> indexed =
        <(int, WidgetDto)>[
          for (int i = 0; i < widgets.length; i++) (i, widgets[i]),
        ]..sort(((int, WidgetDto) a, (int, WidgetDto) b) {
          final int p = a.$2.position.compareTo(b.$2.position);
          return p != 0 ? p : a.$1.compareTo(b.$1);
        });
    return List<WidgetDto>.unmodifiable(<WidgetDto>[
      for (final (int _, WidgetDto w) in indexed) w,
    ]);
  }
}
