import 'package:montra_mobile/app/router/app_routes.dart';

/// Goal locations beyond those in [AppRoutes] (owned by the goals feature).
abstract final class GoalPaths {
  /// Add a contribution to goal [id].
  static String contribute(String id) =>
      '${AppRoutes.goalDetail(id)}/contribute';

  /// The CSV export of goal [id].
  static String export(String id) => '${AppRoutes.goalDetail(id)}/export';
}
