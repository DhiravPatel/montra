import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart' show Detail;
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';

/// Localized text for the coded errors of group money (docs/API.md
/// "Social and groups notes" and the domain rule tables): split and payer
/// checks, exchange rates, expense and settlement states and recurring
/// shared expenses. Returns null for codes of other areas.
String? groupMoneyDetailMessage(AppLocalizations l10n, Detail detail) {
  final Map<String, String> p = detail.params ?? const <String, String>{};
  return switch (detail.code) {
    'split_mismatch' => l10n.gxErrSplitMismatch,
    'payers_total_mismatch' => l10n.gxErrPayersMismatch,
    'items_exceed_total' => l10n.gxErrItemsExceedTotal,
    'items_need_amount' => l10n.gxErrItemsNeedAmount,
    'payer_only' => l10n.gxErrPayerOnly,
    'fx_rate_unavailable' => l10n.gxErrFxUnavailable(
      p['from'] ?? '',
      p['to'] ?? '',
      p['date'] == null
          ? ''
          : LocalDates.display(p['date']!, locale: l10n.localeName),
    ),
    'converted_too_small' => l10n.gxErrConvertedTooSmall(p['currency'] ?? ''),
    'expense_deleted' => l10n.gxErrExpenseDeleted,
    'expense_already_recorded' => l10n.gxErrExpenseAlreadyRecorded,
    'settlement_voided' => l10n.gxErrSettlementVoided,
    'settlement_not_proposed' => l10n.gxErrSettlementNotProposed(
      settlementStatusWord(l10n, p['status']),
    ),
    'settlement_not_confirmable' => l10n.gxErrSettlementNotConfirmable(
      settlementStatusWord(l10n, p['status']),
    ),
    'settlement_not_disputable' => l10n.gxErrSettlementNotDisputable(
      settlementStatusWord(l10n, p['status']),
    ),
    'settlement_already_recorded' => l10n.gxErrSettlementAlreadyRecorded,
    'settlement_not_confirmed' => l10n.gxErrSettlementNotConfirmed,
    'settlement_not_paid' => l10n.gxErrSettlementNotPaid,
    'settlement_dispute' => l10n.gxErrSettlementDispute,
    'recurring_member_inactive' => l10n.gxErrRecurringMemberInactive,
    'recurring_template_invalid' => l10n.gxErrRecurringTemplateInvalid,
    'group_archived' => l10n.gxErrGroupArchived,
    _ => null,
  };
}
