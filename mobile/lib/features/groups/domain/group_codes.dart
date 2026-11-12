import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart' show Detail;

/// Localized text for the coded 409/422 answers of groups, members,
/// invitations and join requests (docs/API.md "Social and groups notes");
/// null for codes this area does not own. Membership codes shared with
/// communities (`already_member`, `invitation_used`, …) are localized in
/// `core/widgets/error_messages.dart`.
String? groupDetailMessage(AppLocalizations l10n, Detail detail) {
  return switch (detail.code) {
    'join_request_pending' => l10n.groupCodeJoinRequestPending,
    'group_archived' => l10n.groupCodeArchived,
    'group_not_archived' => l10n.groupCodeNotArchived,
    'balance_open' => l10n.groupCodeBalanceOpen,
    'balances_open' => l10n.groupCodeBalancesOpen,
    'currency_locked' => l10n.groupCodeCurrencyLocked,
    _ => null,
  };
}
