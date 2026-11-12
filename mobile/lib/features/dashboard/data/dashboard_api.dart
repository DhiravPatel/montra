import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';

/// Typed calls for the dashboard: the computed summary (server-side
/// aggregation; the app never totals transactions itself) and the widget
/// layout.
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

  /// `GET /dashboard/widgets` — layout merged with the defaults.
  Future<List<WidgetDto>> widgets() => _client.send(
    ApiEndpoints.dashboardWidgets,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListWidgetDto(json).data,
  );

  /// `PATCH /dashboard/widgets` with the full layout (order = position).
  Future<List<WidgetDto>> saveWidgets(List<WidgetDto> layout) => _client.send(
    ApiEndpoints.updateDashboardWidgets,
    body: WidgetsPatch(
      widgets: <Item>[
        for (int i = 0; i < layout.length; i++)
          Item(
            key: layout[i].key.json,
            position: i,
            visible: layout[i].visible,
            settings: layout[i].settings ?? const <String, Object?>{},
          ),
      ],
    ).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListWidgetDto(json).data,
  );

  /// `PATCH /dashboard/widgets {"reset": true}` — default layout.
  Future<List<WidgetDto>> resetWidgets() => _client.send(
    ApiEndpoints.updateDashboardWidgets,
    body: const WidgetsPatch(reset: true).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListWidgetDto(json).data,
  );
}

/// Dashboard endpoints. Overridden in tests.
final Provider<DashboardApi> dashboardApiProvider = Provider<DashboardApi>(
  (Ref ref) => DashboardApi(ref.watch(apiClientProvider)),
);
