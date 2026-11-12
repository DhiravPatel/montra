import 'package:montra_mobile/app/router/app_routes.dart';

/// Group locations beyond those in [AppRoutes] (owned by the groups
/// feature).
abstract final class GroupPaths {
  /// Edit the details of group [id].
  static String edit(String id) => '${AppRoutes.groupDetail(id)}/edit';
}
