import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/features/dashboard/domain/widget_info.dart';

/// Typed calls for the dashboard: the computed summary (server-side
/// aggregation; the app never totals transactions itself), the planning
/// cards and the widget layout.
class DashboardApi {
  /// Creates the API over [client].
  DashboardApi(this._client);

  final ApiClient _client;

  /// `GET /dashboard/summary` for [range] (a named range or custom dates;
  /// the server defaults to this month).
  Future<DashboardSummary> summary(DateRangeChoice range) => _client.send(
    ApiEndpoints.dashboardSummary,
    query: <String, Object?>{
      'range': range.range,
      if (range.range == null) 'from': range.from,
      if (range.range == null) 'to': range.to,
    },
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeDashboardSummary(json).data,
  );

  /// `GET /dashboard/planning`: the budgets, upcoming items, goals and
  /// group balances that need attention, with their counts. One request
  /// feeds all four planning cards.
  Future<DashboardPlanning> planning() => _client.send(
    ApiEndpoints.dashboardPlanning,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeDashboardPlanning(json).data,
  );

  /// `GET /dashboard/widgets`: the layout merged with the defaults (new
  /// widgets at the end, visible).
  Future<List<DashboardWidget>> widgets() =>
      _client.send(ApiEndpoints.dashboardWidgets, decode: decodeLayout);

  /// `PATCH /dashboard/widgets` with the full layout (order = position).
  /// Widgets this version does not know are sent back unchanged.
  Future<List<DashboardWidget>> saveWidgets(List<DashboardWidget> layout) =>
      _client.send(
        ApiEndpoints.updateDashboardWidgets,
        body: WidgetsPatch(
          widgets: <Item>[
            for (int i = 0; i < layout.length; i++)
              Item(
                key: layout[i].key,
                position: i,
                visible: layout[i].visible,
                settings: layout[i].settings ?? const <String, Object?>{},
              ),
          ],
        ).toJson(),
        decode: decodeLayout,
      );

  /// `PATCH /dashboard/widgets {"reset": true}` — default layout.
  Future<List<DashboardWidget>> resetWidgets() => _client.send(
    ApiEndpoints.updateDashboardWidgets,
    body: const WidgetsPatch(reset: true).toJson(),
    decode: decodeLayout,
  );

  /// Decodes a widget-layout envelope keeping every wire key (see
  /// [DashboardWidgetKind]). Throws [FormatException] on a wrong shape.
  static List<DashboardWidget> decodeLayout(Map<String, Object?> json) {
    final Object? data = json['data'];
    if (data is! List<Object?>) {
      throw const FormatException('The widget layout is not a list');
    }
    return <DashboardWidget>[
      for (final Object? item in data)
        if (item is Map<String, Object?>)
          DashboardWidget.fromJson(item)
        else
          throw const FormatException('A widget is not an object'),
    ];
  }
}

/// Dashboard endpoints. Overridden in tests.
final Provider<DashboardApi> dashboardApiProvider = Provider<DashboardApi>(
  (Ref ref) => DashboardApi(ref.watch(apiClientProvider)),
);
