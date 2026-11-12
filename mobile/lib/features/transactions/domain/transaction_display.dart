import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';

/// Localized transaction type.
String transactionTypeLabel(AppLocalizations l10n, TransactionDtoType type) =>
    switch (type) {
      TransactionDtoType.expense => l10n.txTypeExpense,
      TransactionDtoType.income => l10n.txTypeIncome,
      TransactionDtoType.transfer => l10n.txTypeTransfer,
      TransactionDtoType.refund => l10n.txTypeRefund,
      TransactionDtoType.reimbursement => l10n.txTypeReimbursement,
      TransactionDtoType.adjustment => l10n.txTypeAdjustment,
      TransactionDtoType.openingBalance => l10n.txTypeOpeningBalance,
      TransactionDtoType.groupExpense => l10n.txTypeGroupExpense,
      TransactionDtoType.settlement => l10n.txTypeSettlement,
      TransactionDtoType.unrecognized => l10n.txTypeOther,
    };

/// Icon for a transaction type.
IconData transactionTypeIcon(TransactionDtoType type) => switch (type) {
  TransactionDtoType.expense => Icons.shopping_bag_outlined,
  TransactionDtoType.income => Icons.savings_outlined,
  TransactionDtoType.transfer => Icons.swap_horiz,
  TransactionDtoType.refund => Icons.undo,
  TransactionDtoType.reimbursement => Icons.assignment_return_outlined,
  TransactionDtoType.adjustment => Icons.tune,
  TransactionDtoType.openingBalance => Icons.flag_outlined,
  TransactionDtoType.groupExpense => Icons.groups_outlined,
  TransactionDtoType.settlement => Icons.handshake_outlined,
  TransactionDtoType.unrecognized => Icons.receipt_outlined,
};

/// Localized status.
String transactionStatusLabel(
  AppLocalizations l10n,
  TransactionDtoStatus status,
) => switch (status) {
  TransactionDtoStatus.draft => l10n.txStatusDraft,
  TransactionDtoStatus.pending => l10n.txStatusPending,
  TransactionDtoStatus.posted => l10n.txStatusPosted,
  TransactionDtoStatus.voided => l10n.txStatusDeleted,
  TransactionDtoStatus.reversed => l10n.txStatusReversed,
  TransactionDtoStatus.unrecognized => l10n.txStatusPosted,
};

/// Localized provenance.
String transactionSourceLabel(AppLocalizations l10n, String source) =>
    switch (source) {
      'manual' => l10n.txSourceManual,
      'import' => l10n.txSourceImport,
      'receipt' => l10n.txSourceReceipt,
      'recurring' => l10n.txSourceRecurring,
      'integration' => l10n.txSourceIntegration,
      'correction' => l10n.txSourceCorrection,
      'group' => l10n.txSourceGroup,
      'system' => l10n.txSourceSystem,
      _ => source,
    };

/// Localized reconciliation state.
String reconciliationLabel(
  AppLocalizations l10n,
  TransactionDtoReconciliationState state,
) => switch (state) {
  TransactionDtoReconciliationState.unreconciled => l10n.reconUnreconciled,
  TransactionDtoReconciliationState.matched => l10n.reconMatched,
  TransactionDtoReconciliationState.reconciled => l10n.reconReconciled,
  TransactionDtoReconciliationState.excluded => l10n.reconExcluded,
  TransactionDtoReconciliationState.unrecognized => l10n.reconUnreconciled,
};

/// The flow sign for [t].
MoneyFlow flowOf(TransactionDto t) =>
    t.direction == TransactionDtoDirection.inflow
    ? MoneyFlow.inflow
    : MoneyFlow.outflow;

/// The main line of a transaction: merchant, description, category, or the
/// type.
String transactionTitle(
  AppLocalizations l10n,
  TransactionDto t, {
  String? categoryName,
}) {
  final String? merchant = t.merchant?.name;
  if (merchant != null && merchant.isNotEmpty) {
    return merchant;
  }
  final String? description = t.description?.trim();
  if (description != null && description.isNotEmpty) {
    return description;
  }
  if (categoryName != null && categoryName.isNotEmpty) {
    return categoryName;
  }
  return transactionTypeLabel(l10n, t.typeValue);
}

/// Types the user can change everything on (others only allow
/// description, notes, merchant and tags; the server enforces this).
bool isFullyEditable(TransactionDto t) =>
    t.owned &&
    (t.typeValue == TransactionDtoType.expense ||
        t.typeValue == TransactionDtoType.income ||
        t.typeValue == TransactionDtoType.refund ||
        t.typeValue == TransactionDtoType.reimbursement);

/// Whether [t] can be edited at all from the app.
bool isEditable(TransactionDto t) =>
    t.owned &&
    t.status != TransactionDtoStatus.voided &&
    t.typeValue != TransactionDtoType.groupExpense &&
    t.typeValue != TransactionDtoType.settlement;

/// Whether [t] can be voided from the app (group records change only from
/// the group).
bool isDeletable(TransactionDto t) =>
    t.owned &&
    t.status != TransactionDtoStatus.voided &&
    t.typeValue != TransactionDtoType.groupExpense &&
    t.typeValue != TransactionDtoType.settlement;

/// Only the user's own, active expenses take refunds and reimbursements.
bool canRefund(TransactionDto t) =>
    t.owned &&
    t.typeValue == TransactionDtoType.expense &&
    t.status != TransactionDtoStatus.voided;

/// Only the user's own expenses and income can be duplicated.
bool canDuplicate(TransactionDto t) =>
    t.owned &&
    (t.typeValue == TransactionDtoType.expense ||
        t.typeValue == TransactionDtoType.income);
