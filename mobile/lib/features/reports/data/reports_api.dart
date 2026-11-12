import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Reports` tag: reports and exports generated in the
/// background, short-lived download links, deleting a report, and
/// scheduled reports (edited, paused and resumed with `PATCH`).
class ReportsApi {
  /// Creates the API over [client].
  ReportsApi(this._client);

  final ApiClient _client;

  /// `GET /reports`: recent reports, newest first.
  Future<List<ReportDto>> list() => _client.send(
    ApiEndpoints.listReports,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListReportDto(json).data,
  );

  /// `POST /reports`: queues a report (`202`; generated in the background).
  Future<ReportDto> create(ReportInput input) => _client.send(
    ApiEndpoints.createReport,
    body: input.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeReportDto(json).data,
  );

  /// `GET /reports/{id}`.
  Future<ReportDto> get(String id) => _client.send(
    ApiEndpoints.getReport,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeReportDto(json).data,
  );

  /// `DELETE /reports/{id}`: deletes the report in any status (a queued or
  /// running generation is cancelled, the stored file is deleted and
  /// earlier download links stop working).
  Future<void> delete(String id) => _client.send(
    ApiEndpoints.deleteReport,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );

  /// `GET /reports/{id}/download`: a signed link valid for a few minutes
  /// (`410` once the report expired, `409` while it is not ready).
  Future<Access> download(String id) => _client.send(
    ApiEndpoints.downloadReport,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeAccess(json).data,
  );

  /// `GET /reports/schedules`.
  Future<List<ScheduleDto>> schedules() => _client.send(
    ApiEndpoints.listReportSchedules,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListScheduleDto(json).data,
  );

  /// `POST /reports/schedules`: a weekly or monthly report.
  Future<ScheduleDto> createSchedule(ScheduleInput input) => _client.send(
    ApiEndpoints.createReportSchedule,
    body: input.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeScheduleDto(json).data,
  );

  /// `PATCH /reports/schedules/{id}`: changes only the fields sent
  /// (title, format, cadence, filters, `enabled` to pause or resume) with
  /// the schedule's `version`.
  Future<ScheduleDto> updateSchedule(String id, SchedulePatch patch) =>
      _client.send(
        ApiEndpoints.updateReportSchedule,
        pathParameters: <String, String>{'id': id},
        body: patch.toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeScheduleDto(json).data,
      );

  /// `DELETE /reports/schedules/{id}`.
  Future<void> deleteSchedule(String id) => _client.send(
    ApiEndpoints.deleteReportSchedule,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );
}

/// Reports endpoints. Overridden in tests.
final Provider<ReportsApi> reportsApiProvider = Provider<ReportsApi>(
  (Ref ref) => ReportsApi(ref.watch(apiClientProvider)),
);
