import 'package:montra_mobile/app/router/app_routes.dart';

/// Group money locations beyond those in [AppRoutes] (owned by the group
/// money feature).
abstract final class GroupMoneyPaths {
  /// Correct settlement [settlementId] of group [groupId] (records a new
  /// one and voids the original).
  static String correctSettlement(String groupId, String settlementId) =>
      '${AppRoutes.groupSettlementDetail(groupId, settlementId)}/correct';

  /// Edit recurring shared expense [ruleId] of group [groupId].
  static String editRecurring(String groupId, String ruleId) =>
      '${AppRoutes.groupRecurringDetail(groupId, ruleId)}/edit';
}
