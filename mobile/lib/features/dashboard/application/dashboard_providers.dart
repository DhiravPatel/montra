import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/budgets/application/budgets_providers.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/dashboard/domain/widget_info.dart';
import 'package:montra_mobile/features/goals/application/goals_providers.dart';
import 'package:montra_mobile/features/settings/application/preferences_providers.dart';

/// The default layout (every widget this version knows, in the server's
/// default order). Used when the layout cannot be loaded.
final List<DashboardWidget> defaultLayout = List<DashboardWidget>.unmodifiable(
  <DashboardWidget>[
    for (final DashboardWidgetKind kind in DashboardWidgetKind.values)
      DashboardWidget(key: kind.key, position: kind.index, visible: true),
  ],
);

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

/// The planning cards (budgets, upcoming items, goals, group balances):
/// one `GET /dashboard/planning` shared by all four cards; re-read after
/// finance, budget or goal writes.
final FutureProvider<DashboardPlanning> dashboardPlanningProvider =
    FutureProvider.autoDispose<DashboardPlanning>((Ref ref) {
      ref
        ..watch(currentUserIdProvider)
        ..watch(financeRevisionProvider)
        ..watch(budgetRevisionProvider)
        ..watch(goalsRevisionProvider);
      return ref.read(dashboardApiProvider).planning();
    });

/// The widget layout (order and visibility), with save and reset.
final AsyncNotifierProvider<DashboardLayoutController, List<DashboardWidget>>
dashboardLayoutProvider =
    AsyncNotifierProvider.autoDispose<
      DashboardLayoutController,
      List<DashboardWidget>
    >(DashboardLayoutController.new);

/// See [dashboardLayoutProvider].
class DashboardLayoutController extends AsyncNotifier<List<DashboardWidget>> {
  DashboardApi get _api => ref.read(dashboardApiProvider);

  @override
  Future<List<DashboardWidget>> build() async {
    ref.watch(currentUserIdProvider);
    return sortLayout(await _api.widgets());
  }

  /// Saves [layout] (list order becomes the position).
  Future<void> save(List<DashboardWidget> layout) async {
    state = AsyncData<List<DashboardWidget>>(
      sortLayout(await _api.saveWidgets(layout)),
    );
  }

  /// Restores the default layout.
  Future<void> reset() async {
    state = AsyncData<List<DashboardWidget>>(
      sortLayout(await _api.resetWidgets()),
    );
  }

  /// Widgets by position (stable for equal positions).
  static List<DashboardWidget> sortLayout(List<DashboardWidget> widgets) {
    final List<(int, DashboardWidget)> indexed =
        <(int, DashboardWidget)>[
          for (int i = 0; i < widgets.length; i++) (i, widgets[i]),
        ]..sort(((int, DashboardWidget) a, (int, DashboardWidget) b) {
          final int p = a.$2.position.compareTo(b.$2.position);
          return p != 0 ? p : a.$1.compareTo(b.$1);
        });
    return List<DashboardWidget>.unmodifiable(<DashboardWidget>[
      for (final (int _, DashboardWidget w) in indexed) w,
    ]);
  }
}
