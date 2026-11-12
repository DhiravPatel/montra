import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_codes.dart';

/// Inbox filters (`GET /receipts?status=`): `''` lists everything except
/// discarded receipts.
const List<String> receiptFilters = <String>[
  '',
  'needs_review',
  'reviewed',
  'matched',
  'discarded',
];

/// Name of an inbox filter.
String receiptFilterLabel(AppLocalizations l10n, String filter) =>
    switch (filter) {
      'needs_review' => l10n.receiptFilterToReview,
      'reviewed' => l10n.receiptFilterReviewed,
      'matched' => l10n.receiptFilterLinked,
      'discarded' => l10n.receiptFilterDiscarded,
      _ => l10n.receiptFilterOpen,
    };

/// A receipt status (wire value) in words.
String receiptStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'uploaded' => l10n.receiptStatusUploaded,
      'processing' => l10n.receiptStatusProcessing,
      'needs_review' => l10n.receiptStatusNeedsReview,
      'reviewed' => l10n.receiptStatusReviewed,
      'matched' => l10n.receiptStatusMatched,
      'failed' => l10n.receiptStatusFailed,
      'discarded' => l10n.receiptStatusDiscarded,
      _ => l10n.receiptStatusOther,
    };

/// Tone of a receipt status (always shown with its icon and words).
StatusTone receiptStatusTone(String status) => switch (status) {
  'needs_review' || 'failed' || 'uploaded' => StatusTone.caution,
  'matched' => StatusTone.positive,
  _ => StatusTone.neutral,
};

/// Icon of a receipt status.
IconData receiptStatusIcon(String status) => switch (status) {
  'uploaded' => Icons.cloud_done_outlined,
  'processing' => Icons.hourglass_top,
  'needs_review' => Icons.edit_note,
  'reviewed' => Icons.fact_check_outlined,
  'matched' => Icons.link,
  'failed' => Icons.error_outline,
  'discarded' => Icons.delete_outline,
  _ => Icons.help_outline,
};

/// What the user can do next with a receipt in [status].
String receiptStatusHelp(AppLocalizations l10n, String status) =>
    switch (status) {
      'reviewed' => l10n.receiptHelpReviewed,
      'matched' => l10n.receiptHelpMatched,
      'discarded' => l10n.receiptHelpDiscarded,
      'processing' => l10n.receiptHelpProcessing,
      _ => l10n.receiptHelpNeedsReview,
    };

/// A receipt's title: the merchant typed by the user, or "Receipt".
String receiptTitle(AppLocalizations l10n, ReceiptExtractionDto? current) {
  final String? merchant = current?.merchantName?.trim();
  return merchant == null || merchant.isEmpty ? l10n.receiptUntitled : merchant;
}

/// Whether the receipt's details can be entered or changed (the server
/// refuses reviews of linked, discarded or processing receipts).
bool canReviewReceipt(String status) =>
    status != 'matched' && status != 'discarded' && status != 'processing';

/// Whether a reviewed receipt can be linked or recorded.
bool canLinkReceipt(String status, String? transactionId) =>
    status == 'reviewed' && transactionId == null;

/// Whether the receipt's current values were typed or confirmed by the user
/// (only such values can be recorded as a transaction).
bool isManualReview(ReceiptExtractionDto? current) =>
    current?.method == ReceiptExtractionDtoMethod.manual;

/// Whether a reviewed receipt can be recorded as a new expense: the server
/// records only values the user reviewed by hand.
bool canRecordReceipt(
  String status,
  String? transactionId,
  ReceiptExtractionDto? current,
) => canLinkReceipt(status, transactionId) && isManualReview(current);

/// Error codes after which the receipt changed on the server (linked,
/// discarded, being read, restored or edited elsewhere): the screen reloads
/// it.
const Set<String> receiptStateCodes = <String>{
  'receipt_linked',
  'receipt_discarded',
  'receipt_processing',
  'receipt_not_linked',
  'receipt_not_discarded',
  'receipt_not_reviewed',
  'file_in_use',
};

/// Whether [error] means the receipt changed on the server underneath the
/// screen (edited elsewhere, linked, discarded, being read…): the screen
/// reloads it so it shows the current state.
bool receiptChangedUnderneath(Object error) {
  if (error is! ApiException) {
    return false;
  }
  if (error.code == ErrorObjectCode.versionConflict) {
    return true;
  }
  return error.details.any(
    (Detail d) => d.code != null && receiptStateCodes.contains(d.code),
  );
}

/// Why a transaction may be the receipt's purchase, from the English
/// reason when no code was sent.
String receiptReasonText(AppLocalizations l10n, String reason) =>
    switch (reason) {
      'Same amount as the total' => l10n.receiptReasonSameAmount,
      'Amount within 20% of the total (tip or fees)' =>
        l10n.receiptReasonCloseAmount,
      'Same date' => l10n.receiptReasonSameDate,
      'Within 3 days' => l10n.receiptReasonNearDate,
      'Same merchant' => l10n.receiptReasonSameMerchant,
      _ => reason,
    };

/// A match reason by its stable code (`ReceiptMatchCandidate.reason_codes`),
/// or null for codes this app does not know.
String? receiptReasonCodeText(
  AppLocalizations l10n,
  ReceiptMatchCandidateReasonCodesItem code,
) => switch (code) {
  ReceiptMatchCandidateReasonCodesItem.sameAmount =>
    l10n.receiptReasonSameAmount,
  ReceiptMatchCandidateReasonCodesItem.amountClose =>
    l10n.receiptReasonCloseAmount,
  ReceiptMatchCandidateReasonCodesItem.sameDate => l10n.receiptReasonSameDate,
  ReceiptMatchCandidateReasonCodesItem.nearDate => l10n.receiptReasonNearDate,
  ReceiptMatchCandidateReasonCodesItem.sameMerchant =>
    l10n.receiptReasonSameMerchant,
  ReceiptMatchCandidateReasonCodesItem.unrecognized => null,
};

/// The reasons of a suggestion in the user's language: by code (in the
/// order of the English reasons); a code this app does not know falls back
/// to the English text at the same position.
List<String> receiptSuggestionReasons(
  AppLocalizations l10n,
  ReceiptMatchCandidate candidate,
) {
  final List<String> english = candidate.reasons;
  final List<ReceiptMatchCandidateReasonCodesItem> codes =
      candidate.reasonCodes;
  if (codes.isEmpty) {
    return <String>[for (final String r in english) receiptReasonText(l10n, r)];
  }
  return <String>[
    for (int i = 0; i < codes.length; i++)
      receiptReasonCodeText(l10n, codes[i]) ??
          (i < english.length
              ? receiptReasonText(l10n, english[i])
              : codes[i].json.replaceAll('_', ' ')),
  ];
}

/// A remark about the entered values in the user's language. [money]
/// formats an amount parameter (a decimal string in a currency); codes this
/// app does not know fall back to the English text.
String receiptWarningMessage(
  AppLocalizations l10n,
  ReceiptWarning warning, {
  required String Function(String amount, String currency) money,
}) {
  final Map<String, String> p = warning.params;
  final String? currency = p['currency'];
  return switch (warning.code) {
    ReceiptExtractionDtoWarningCodesItem.totalsMismatch =>
      l10n.receiptWarningArithmetic,
    ReceiptExtractionDtoWarningCodesItem.lineItemsMismatch
        when p['line_items_total'] != null &&
            p['subtotal'] != null &&
            currency != null =>
      l10n.receiptWarningLineItemsAmounts(
        money(p['line_items_total']!, currency),
        money(p['subtotal']!, currency),
      ),
    ReceiptExtractionDtoWarningCodesItem.lineItemsMismatch =>
      l10n.receiptWarningLineItems,
    ReceiptExtractionDtoWarningCodesItem.amountUnreadable
        when (p['value'] ?? '').isNotEmpty =>
      l10n.receiptWarningAmountUnreadable(p['value']!),
    ReceiptExtractionDtoWarningCodesItem.amountUnreadable =>
      l10n.receiptWarningAmountUnreadableGeneric,
    ReceiptExtractionDtoWarningCodesItem.dateUnreadable =>
      l10n.receiptWarningDateUnreadable,
    ReceiptExtractionDtoWarningCodesItem.currencyUnrecognized =>
      l10n.receiptWarningCurrencyUnrecognized,
    ReceiptExtractionDtoWarningCodesItem.extractorNotConfigured ||
    ReceiptExtractionDtoWarningCodesItem.consentRequired ||
    ReceiptExtractionDtoWarningCodesItem.fileUnavailable ||
    ReceiptExtractionDtoWarningCodesItem.timeout ||
    ReceiptExtractionDtoWarningCodesItem.providerError =>
      l10n.receiptWarningReadingFailed,
    ReceiptExtractionDtoWarningCodesItem.readerNote => warning.text,
    ReceiptExtractionDtoWarningCodesItem.unrecognized ||
    null => receiptWarningText(l10n, warning.text),
  };
}

/// A server remark about the entered values from its English text, for
/// remarks sent without a code.
String receiptWarningText(AppLocalizations l10n, String warning) {
  if (warning.startsWith('Subtotal, tax, tip and discount')) {
    return l10n.receiptWarningArithmetic;
  }
  if (warning.startsWith('Line items add up to')) {
    return l10n.receiptWarningLineItems;
  }
  return warning;
}

/// How a version of the values was produced.
String receiptMethodLabel(AppLocalizations l10n, String method) =>
    switch (method) {
      'manual' => l10n.receiptMethodManual,
      _ => l10n.receiptMethodAutomatic,
    };
