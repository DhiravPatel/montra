import 'package:montra_mobile/app/router/app_routes.dart';

/// Report locations beyond those in [AppRoutes] (owned by the reports
/// feature).
abstract final class ReportPaths {
  /// Edit the schedule [id].
  static String editSchedule(String id) =>
      '${AppRoutes.reportSchedules}/${Uri.encodeComponent(id)}/edit';
}
