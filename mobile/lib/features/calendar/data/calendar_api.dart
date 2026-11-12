import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// The planning calendar: what is due or expected on which day.
class CalendarApi {
  /// Creates the API over [client].
  CalendarApi(this._client);

  final ApiClient _client;

  /// Longest range the server accepts, in days.
  static const int maxRangeDays = 93;

  /// `GET /calendar?from&to` (`YYYY-MM-DD`, at most [maxRangeDays] days).
  Future<List<CalendarItem>> items({
    required String from,
    required String to,
  }) => _client.send(
    ApiEndpoints.planningCalendar,
    query: <String, Object?>{'from': from, 'to': to},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListCalendarItem(json).data,
  );
}

/// The [CalendarApi] over the shared client.
final Provider<CalendarApi> calendarApiProvider = Provider<CalendarApi>(
  (Ref ref) => CalendarApi(ref.watch(apiClientProvider)),
);
