import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';

/// Group types offered when creating a group, in the order shown.
const List<String> groupTypes = <String>[
  'household',
  'roommates',
  'trip',
  'event',
  'friends',
  'custom',
];

/// Split methods a group can default to, in the order shown.
const List<String> splitMethods = <String>[
  'equal',
  'exact',
  'percentage',
  'shares',
  'itemized',
];

/// Name of a group type (wire value), or the value for unknown ones.
String groupTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'household' => l10n.groupTypeHousehold,
  'roommates' => l10n.groupTypeRoommates,
  'trip' => l10n.groupTypeTrip,
  'event' => l10n.groupTypeEvent,
  'friends' => l10n.groupTypeFriends,
  'custom' => l10n.groupTypeCustom,
  _ => type,
};

/// Whether a group type has dates and a destination.
bool groupTypeHasDates(String type) => type == 'trip' || type == 'event';

/// Name of a split method (wire value).
String splitMethodLabel(AppLocalizations l10n, String method) =>
    switch (method) {
      'equal' => l10n.groupSplitEqual,
      'exact' => l10n.groupSplitExact,
      'percentage' => l10n.groupSplitPercentage,
      'shares' => l10n.groupSplitShares,
      'itemized' => l10n.groupSplitItemized,
      _ => method,
    };

/// Name of a member role (wire value).
String groupRoleLabel(AppLocalizations l10n, String role) => switch (role) {
  'owner' => l10n.groupRoleOwner,
  'admin' => l10n.groupRoleAdmin,
  'member' => l10n.groupRoleMember,
  _ => role,
};

/// Name of a notification level (wire value).
String notificationLevelLabel(AppLocalizations l10n, String level) =>
    switch (level) {
      'all' => l10n.groupNotifyAll,
      'important' => l10n.groupNotifyImportant,
      'none' => l10n.groupNotifyNone,
      _ => level,
    };

/// Status word of an invitation (`invitation_used`'s `status` param and
/// the invitation lists).
String invitationStatusWord(AppLocalizations l10n, String? status) =>
    switch (status) {
      'active' => l10n.groupInvitationStatusActive,
      'accepted' => l10n.groupInvitationStatusAccepted,
      'declined' => l10n.groupInvitationStatusDeclined,
      'revoked' => l10n.groupInvitationStatusRevoked,
      'expired' => l10n.groupInvitationStatusExpired,
      null || '' => l10n.statusWordUnknown,
      final String other => other.replaceAll('_', ' '),
    };

/// Status word of a join request.
String joinRequestStatusWord(AppLocalizations l10n, String status) =>
    switch (status) {
      'pending' => l10n.groupJoinRequestStatusPending,
      'approved' => l10n.groupJoinRequestStatusApproved,
      'declined' => l10n.groupJoinRequestStatusDeclined,
      'cancelled' => l10n.groupJoinRequestStatusCancelled,
      _ => status,
    };

/// Whether [role] may change the group, its members and invitations.
bool roleCanManage(String role) => role == 'owner' || role == 'admin';

/// [money] without its sign (the wording says who owes).
Money unsignedNet(Money money) => money.amount.startsWith('-')
    ? Money(
        amount: money.amount.substring(1),
        amountMinor: -money.amountMinor,
        currency: money.currency,
      )
    : money;

/// How the user's balance in a group reads: who owes whom, in words, with
/// the server's amount ([formatted], unsigned) — never recomputed.
({String text, StatusTone tone}) netBalanceWording(
  AppLocalizations l10n,
  Money net,
  String formatted,
) {
  if (net.amountMinor > 0) {
    return (text: l10n.groupNetOwedToYou(formatted), tone: StatusTone.positive);
  }
  if (net.amountMinor < 0) {
    return (text: l10n.groupNetYouOwe(formatted), tone: StatusTone.caution);
  }
  return (text: l10n.groupNetSettled, tone: StatusTone.neutral);
}

/// The sentence for one activity event, built from its typed `kind` and
/// `summary` (the server never sends English text). [actor] is the name
/// behind `actor_id`; [target] the name of the member the event is about
/// (`entity_id` of member events).
String activitySentence(
  AppLocalizations l10n,
  GroupActivityDto event, {
  required String actor,
  required String target,
}) {
  final GroupActivitySummary s = event.summary;
  final String name = s.name ?? s.description ?? '';
  return switch (event.kind) {
    GroupActivityDtoKind.groupCreated => l10n.groupActivityCreated(
      actor,
      groupTypeLabel(l10n, s.typeValue?.json ?? 'custom'),
    ),
    GroupActivityDtoKind.groupUpdated => l10n.groupActivityUpdated(actor),
    GroupActivityDtoKind.groupArchived => l10n.groupActivityArchived(actor),
    GroupActivityDtoKind.groupRestored => l10n.groupActivityRestored(actor),
    GroupActivityDtoKind.groupDeleted => l10n.groupActivityDeleted(actor),
    GroupActivityDtoKind.invitationCreated =>
      s.kind == GroupActivitySummaryKind.username
          ? l10n.groupActivityInvited(actor)
          : l10n.groupActivityLinkCreated(actor),
    GroupActivityDtoKind.invitationRevoked =>
      l10n.groupActivityInvitationRevoked(actor),
    GroupActivityDtoKind.joinRequested => l10n.groupActivityJoinRequested(
      actor,
    ),
    GroupActivityDtoKind.memberJoined =>
      s.via == GroupActivitySummaryVia.joinRequest
          ? l10n.groupActivityJoinedApproved(target)
          : l10n.groupActivityJoined(target),
    GroupActivityDtoKind.memberLeft => l10n.groupActivityLeft(target),
    GroupActivityDtoKind.memberRemoved => l10n.groupActivityRemoved(
      actor,
      target,
    ),
    GroupActivityDtoKind.memberRoleChanged => l10n.groupActivityRoleChanged(
      actor,
      target,
      groupRoleLabel(l10n, s.role?.json ?? 'member'),
    ),
    GroupActivityDtoKind.ownershipTransferred =>
      l10n.groupActivityOwnershipTransferred(actor, target),
    GroupActivityDtoKind.expenseAdded => l10n.groupActivityExpenseAdded(
      actor,
      name,
    ),
    GroupActivityDtoKind.expenseUpdated => l10n.groupActivityExpenseUpdated(
      actor,
      name,
    ),
    GroupActivityDtoKind.expenseDeleted => l10n.groupActivityExpenseDeleted(
      actor,
      name,
    ),
    GroupActivityDtoKind.expenseCommented => l10n.groupActivityExpenseCommented(
      actor,
      name,
    ),
    GroupActivityDtoKind.expenseDisputed => l10n.groupActivityExpenseDisputed(
      actor,
      name,
    ),
    // Disputes are about an expense (also when `target_type` is absent,
    // on older events) or a settlement.
    GroupActivityDtoKind.disputeResolved =>
      s.targetType == GroupActivitySummaryTargetType.settlement
          ? l10n.groupActivitySettlementDisputeResolved(actor)
          : l10n.groupActivityDisputeResolved(actor, name),
    GroupActivityDtoKind.disputeWithdrawn =>
      s.targetType == GroupActivitySummaryTargetType.settlement
          ? l10n.groupActivitySettlementDisputeWithdrawn(actor)
          : l10n.groupActivityDisputeWithdrawn(actor, name),
    GroupActivityDtoKind.settlementProposed =>
      l10n.groupActivitySettlementProposed(actor),
    GroupActivityDtoKind.settlementReported =>
      l10n.groupActivitySettlementReported(actor),
    GroupActivityDtoKind.settlementConfirmed =>
      l10n.groupActivitySettlementConfirmed(actor),
    GroupActivityDtoKind.settlementDisputed =>
      l10n.groupActivitySettlementDisputed(actor),
    GroupActivityDtoKind.settlementVoided => l10n.groupActivitySettlementVoided(
      actor,
    ),
    GroupActivityDtoKind.settlementCorrected =>
      l10n.groupActivitySettlementCorrected(actor),
    GroupActivityDtoKind.recurringExpenseCreated =>
      l10n.groupActivityRecurringCreated(actor, name),
    GroupActivityDtoKind.recurringExpenseUpdated =>
      l10n.groupActivityRecurringUpdated(actor, name),
    GroupActivityDtoKind.recurringExpensePaused =>
      l10n.groupActivityRecurringPaused(actor, name),
    GroupActivityDtoKind.recurringExpenseResumed =>
      l10n.groupActivityRecurringResumed(actor, name),
    GroupActivityDtoKind.recurringExpenseStopped =>
      l10n.groupActivityRecurringStopped(actor, name),
    GroupActivityDtoKind.recurringExpenseSkipped =>
      l10n.groupActivityRecurringSkipped(actor, name),
    GroupActivityDtoKind.unrecognized => l10n.groupActivityOther(actor),
  };
}

/// Where an activity event of group [groupId] leads: the expense, payment
/// or recurring expense it is about (disputes open their target; older
/// dispute events without `target_type` were always about expenses), or
/// null when there is nothing to open.
String? activityLink(String groupId, GroupActivityDto event) {
  final String? id = event.entityId;
  final GroupActivitySummary s = event.summary;
  if (event.kind == GroupActivityDtoKind.disputeResolved ||
      event.kind == GroupActivityDtoKind.disputeWithdrawn) {
    final String? target = s.target;
    if (target == null || target.isEmpty) {
      return null;
    }
    return s.targetType == GroupActivitySummaryTargetType.settlement
        ? AppRoutes.groupSettlementDetail(groupId, target)
        : AppRoutes.groupExpenseDetail(groupId, target);
  }
  if (id == null || id.isEmpty) {
    return null;
  }
  return switch (event.entityType) {
    GroupActivityDtoEntityType.groupExpense =>
      event.kind == GroupActivityDtoKind.expenseDeleted
          ? null
          : AppRoutes.groupExpenseDetail(groupId, id),
    GroupActivityDtoEntityType.settlement => AppRoutes.groupSettlementDetail(
      groupId,
      id,
    ),
    GroupActivityDtoEntityType.groupRecurringExpense =>
      AppRoutes.groupRecurringDetail(groupId, id),
    _ => null,
  };
}
