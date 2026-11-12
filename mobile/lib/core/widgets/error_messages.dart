import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_error_code.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart' show Detail;
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_uploader.dart';
import 'package:montra_mobile/core/formatting/file_size.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/features/challenges/domain/challenge_codes.dart';
import 'package:montra_mobile/features/communities/domain/community_codes.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_codes.dart';
import 'package:montra_mobile/features/groups/domain/group_codes.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart'
    show invitationStatusWord;
import 'package:montra_mobile/features/integrations/domain/integration_codes.dart';
import 'package:montra_mobile/features/moderation/domain/moderation_codes.dart';
import 'package:montra_mobile/features/notifications/domain/notification_codes.dart';
import 'package:montra_mobile/features/privacy/domain/privacy_display.dart';
import 'package:montra_mobile/features/social/domain/social_codes.dart';
import 'package:montra_mobile/features/support/domain/support_display.dart';

/// Localized, user-facing text for any failure.
///
/// Codes come from the contract's closed enum ([ErrorObjectCode]); the
/// client action for each is documented in `docs/API.md`. Well-known codes
/// map to localized strings; coded details (`DOMAIN_RULE_VIOLATION`, coded
/// `CONFLICT` and `DUPLICATE` answers) are localized by [detailMessage];
/// for the rest the server's safe message is shown (it is written for end
/// users), and only then a generic fallback. Screens override specific
/// cases (for example `UNAUTHENTICATED` on the sign-in form, where it means
/// wrong credentials).
String describeError(AppLocalizations l10n, Object error) {
  if (error is FileRejected) {
    return fileProblemMessage(l10n, error.problem, error.purpose);
  }
  if (error is CameraUnavailable) {
    return l10n.fileCameraUnavailable;
  }
  if (error is! ApiException) {
    return l10n.errorGenericBody;
  }
  switch (error.kind) {
    case ApiErrorKind.network:
      return l10n.errorOfflineBody;
    case ApiErrorKind.timeout:
      return l10n.errorTimeout;
    case ApiErrorKind.invalidResponse:
      return l10n.errorInvalidResponse;
    case ApiErrorKind.sessionEnded:
      return l10n.errorSessionEnded;
    case ApiErrorKind.cancelled:
    case ApiErrorKind.unknown:
      return l10n.errorGenericBody;
    case ApiErrorKind.server:
      break;
  }
  final String fallback = error.message.isNotEmpty
      ? error.message
      : l10n.errorGenericBody;
  final Duration? wait = error.retryAfter;
  final bool hasWait = wait != null && wait > Duration.zero;
  final Detail? coded = error.details
      .where((Detail d) => d.code != null && d.code!.isNotEmpty)
      .firstOrNull;
  return switch (error.code) {
    ErrorObjectCode.forbidden => l10n.errorPermissionBody,
    ErrorObjectCode.notFound => l10n.errorNotFound,
    ErrorObjectCode.versionConflict => l10n.errorConflict,
    ErrorObjectCode.idempotencyInProgress => l10n.errorStillSaving,
    ErrorObjectCode.idempotencyConflict => l10n.errorRequestChanged,
    // Daily caps (posts, comments, reports, challenges, support requests)
    // say which limit was reached and when it opens again (Retry-After).
    ErrorObjectCode.rateLimited when coded?.code == 'daily_cap' =>
      hasWait
          ? l10n.errorDailyCapRetry(
              coded!.params?['limit'] ?? '',
              formatWait(l10n, wait),
            )
          : l10n.errorDailyCap(coded!.params?['limit'] ?? ''),
    ErrorObjectCode.rateLimited =>
      hasWait
          ? l10n.errorRateLimitedRetry(formatWait(l10n, wait))
          : l10n.errorRateLimited,
    ErrorObjectCode.loginThrottled =>
      hasWait
          ? l10n.signInThrottledRetry(formatWait(l10n, wait))
          : l10n.signInThrottled,
    ErrorObjectCode.accountLocked => l10n.signInAccountLocked,
    ErrorObjectCode.mfaCodeInvalid => l10n.mfaCodeInvalid,
    ErrorObjectCode.mfaChallengeExpired => l10n.mfaChallengeExpired,
    ErrorObjectCode.storageUnavailable => l10n.errorStorageUnavailable,
    ErrorObjectCode.featureNotConfigured => l10n.errorFeatureNotConfigured,
    ErrorObjectCode.serviceUnavailable ||
    ErrorObjectCode.providerUnavailable ||
    ErrorObjectCode.timeout => l10n.errorServiceUnavailable,
    ErrorObjectCode.payloadTooLarge => l10n.errorPayloadTooLarge,
    ErrorObjectCode.unsupportedMediaType => l10n.errorUnsupportedFile,
    ErrorObjectCode.internalError => l10n.errorGenericBody,
    ErrorObjectCode.unauthenticated => l10n.errorSessionEnded,
    ErrorObjectCode.validationError
        when coded?.code == 'cancellation_confirmation_required' =>
      l10n.errorCancellationConfirmationRequired,
    ErrorObjectCode.validationError =>
      error.details.isEmpty && error.message.isNotEmpty
          ? error.message
          : l10n.errorValidation,
    ErrorObjectCode.domainRuleViolation when error.details.isNotEmpty =>
      detailMessage(l10n, coded ?? error.details.first),
    ErrorObjectCode.conflict ||
    ErrorObjectCode.duplicate when coded != null => detailMessage(l10n, coded),
    _ => fallback,
  };
}

/// Localized text for a coded error detail (finance rules carry a stable
/// `code` and `params`; docs/API.md "Domain rule codes"); falls back to the
/// server's message for codes this app does not know.
///
/// Field-level `VALIDATION_ERROR` details share the generic codes
/// (`required`, `too_short`, …) across every area; feature areas add their
/// own codes in [featureDetailMessage].
String detailMessage(AppLocalizations l10n, Detail detail) {
  final Map<String, String> p = detail.params ?? const <String, String>{};
  final String? currency = p['currency'];
  return switch (detail.code) {
    // Generic field codes (framework schema checks and community text).
    'required' => l10n.fieldRequired,
    'too_short' => l10n.fieldTooShort(p['min'] ?? ''),
    'too_long' => l10n.fieldTooLong(p['max'] ?? ''),
    'too_few' => l10n.fieldTooFew(p['min'] ?? ''),
    'too_many' => l10n.fieldTooMany(p['max'] ?? ''),
    'too_small' => l10n.fieldTooSmall,
    'too_large' => l10n.fieldTooLarge,
    'invalid_choice' => l10n.fieldInvalidChoice,
    'invalid_format' => l10n.fieldInvalidFormat,
    'invalid_type' => l10n.fieldInvalidType,
    'unexpected_property' => l10n.fieldUnexpected,
    'invalid_characters' => l10n.fieldInvalidCharacters,
    'contains_secret' => l10n.fieldContainsSecret,
    'too_many_links' => l10n.fieldTooManyLinks(p['max'] ?? ''),
    'insecure_link' => l10n.fieldInsecureLink,
    'link_required' => l10n.fieldLinkRequired,
    'moderators_only' => l10n.fieldModeratorsOnly,
    'poll_mismatch' => l10n.fieldPollMismatch,
    'duplicate_option' => l10n.fieldDuplicateOption,
    'must_be_future' => l10n.fieldMustBeFuture,
    'invalid_parent' => l10n.fieldInvalidParent,
    'invalid_option' => l10n.fieldInvalidOption,
    'invalid_topic' => l10n.fieldInvalidTopic,
    'self_not_allowed' => l10n.fieldSelfNotAllowed,
    'reason_required' => l10n.fieldReasonRequired,
    'share_required' => l10n.fieldShareRequired,
    'slug_taken' => l10n.fieldSlugTaken,
    'daily_cap' => l10n.errorDailyCap(p['limit'] ?? ''),
    // Membership codes shared by groups and communities.
    'already_member' => l10n.errorAlreadyMember,
    'invitation_used' when p['status'] != null => l10n.groupCodeInvitationUsed(
      invitationStatusWord(l10n, p['status']),
    ),
    'invitation_used' => l10n.communityErrorInvitationUsed,
    'invitation_inactive' => l10n.groupCodeInvitationInactive,
    'transfer_ownership_first' => l10n.groupCodeTransferFirst,
    // Transactions and accounts.
    'refund_exceeds_remaining' when p['remaining'] != null =>
      l10n.ruleRefundExceedsRemaining(p['remaining']!, currency ?? ''),
    'original_not_refundable' => l10n.ruleOriginalNotRefundable,
    'currency_mismatch' when currency != null => l10n.ruleCurrencyMismatch(
      currency,
    ),
    'account_inactive' => l10n.ruleAccountInactive,
    'group_linked' => l10n.ruleGroupLinked,
    'has_linked_refunds' => l10n.ruleHasLinkedRefunds,
    'transaction_voided' => l10n.errorRuleTransactionVoided,
    'file_not_ready' => l10n.errorRuleFileNotReady,
    'file_not_attachable' => l10n.errorRuleFileNotAttachable,
    // Lifecycle and fair-use caps (every planning area).
    'invalid_status_transition' => l10n.errorRuleStatusTransition(
      statusWord(l10n, p['from']),
      statusWord(l10n, p['to']),
    ),
    'record_limit_reached' => l10n.errorRuleRecordLimit(
      p['resource'] ?? '',
      p['limit'] ?? '',
    ),
    // Categories, rules, tags and merchants.
    'name_taken' when p['merchant_id'] != null => l10n.errorMerchantNameTaken(
      p['name'] ?? '',
    ),
    'name_taken' => l10n.errorNameTaken(p['name'] ?? ''),
    'category_in_use' => l10n.errorCategoryInUse,
    'rule_category_unavailable' => l10n.errorRuleCategoryUnavailable,
    'category_merged' => l10n.errorRuleCategoryMerged,
    'category_already_merged' => l10n.errorRuleCategoryAlreadyMerged,
    'category_depth' => l10n.errorRuleCategoryDepth,
    'parent_category_archived' => l10n.errorRuleParentArchived,
    'merge_target_inactive' => l10n.errorRuleMergeTargetInactive,
    'merge_target_must_be_top_level' => l10n.errorRuleMergeTargetTopLevel,
    // Budgets.
    'group_budget_type_unsupported' => l10n.errorRuleGroupBudgetType,
    'group_budget_filter_unsupported' => l10n.errorRuleGroupBudgetFilter,
    'group_budget_allocation_unsupported' =>
      l10n.errorRuleGroupBudgetAllocation,
    'group_budget' => l10n.errorRuleGroupBudget,
    'zero_based_unallocated' => l10n.errorRuleZeroBasedUnallocated,
    // Recurring payments and bills.
    'schedule_ended' => l10n.errorRuleScheduleEnded,
    'rule_in_use' => l10n.errorRuleRecurringInUse,
    'no_open_occurrence' => l10n.errorRuleNoOpenOccurrence,
    'occurrence_not_open' => l10n.errorRuleOccurrenceNotOpen,
    'occurrence_not_skipped' => l10n.errorRuleOccurrenceNotSkipped,
    'occurrence_already_handled' => l10n.errorRuleOccurrenceHandled,
    'postpone_needs_later_open_occurrence' => l10n.errorRulePostponeLater,
    'use_bill_screen' => l10n.errorRuleUseBillScreen,
    'auto_post_needs_amount_and_account' => l10n.errorRuleAutoPostNeeds,
    'bill_inactive' => l10n.errorRuleBillInactive,
    'bills_not_auto_posted' => l10n.errorRuleBillsNotAutoPosted,
    'transfer_needs_two_accounts' => l10n.errorRuleTransferTwoAccounts,
    'transfer_missing_destination' => l10n.errorRuleTransferDestination,
    'cross_currency_transfer_not_auto_posted' =>
      l10n.errorRuleCrossCurrencyAutoPost,
    // Subscriptions.
    'subscription_inactive' => l10n.errorRuleSubscriptionInactive,
    'subscription_not_cancelled' => l10n.errorRuleSubscriptionNotCancelled,
    'detection_already_decided' => l10n.errorRuleDetectionDecided,
    'detection_evidence_missing' => l10n.errorRuleDetectionEvidenceMissing,
    'payment_already_linked' => l10n.errorPaymentAlreadyLinked,
    'payment_linked_elsewhere' => l10n.errorPaymentLinkedElsewhere,
    'cancellation_confirmation_required' =>
      l10n.errorCancellationConfirmationRequired,
    // Goals.
    'goal_inactive' => l10n.errorRuleGoalInactive,
    'owner_role_fixed' => l10n.errorRuleOwnerRoleFixed,
    'owner_cannot_leave' => l10n.errorRuleOwnerCannotLeave,
    'member_controls_visibility' => l10n.errorRuleMemberVisibility,
    'contribution_not_planned' => l10n.errorRuleContributionNotPlanned,
    'contribution_voided' => l10n.errorRuleContributionVoided,
    'transaction_already_counted' => l10n.errorTransactionAlreadyCounted,
    'withdrawal_exceeds_saved' when p['saved'] != null =>
      l10n.errorRuleWithdrawalExceedsSaved(p['saved']!, currency ?? ''),
    // Files, receipts, imports, reconciliation and reports.
    'storage_quota_exceeded' => l10n.errorRuleStorageQuota(
      formatFileSize(l10n, int.tryParse(p['quota_bytes'] ?? '')),
    ),
    'receipt_incomplete' => l10n.errorRuleReceiptIncomplete,
    'file_in_use' => l10n.errorFileInUse,
    'page_not_ready' => l10n.errorPageNotReady,
    'receipt_linked' => l10n.errorReceiptLinked,
    'receipt_discarded' => l10n.errorReceiptDiscarded,
    'receipt_processing' => l10n.errorReceiptProcessing,
    'receipt_not_linked' => l10n.errorReceiptNotLinked,
    'receipt_not_discarded' => l10n.errorReceiptNotDiscarded,
    'transaction_has_receipt' => l10n.errorTransactionHasReceipt,
    'receipt_not_reviewed' => l10n.errorRuleReceiptNotReviewed,
    'no_rows' => l10n.errorRuleNoRows,
    'row_invalid' => l10n.errorRuleRowInvalid,
    'direction_mismatch' => l10n.errorRuleDirectionMismatch,
    'invalid_match_shape' => l10n.errorRuleInvalidMatchShape,
    'invalid_pair' => l10n.errorRuleInvalidPair,
    'sums_differ' when p['statement'] != null && p['ledger'] != null =>
      l10n.errorRuleSumsDiffer(p['statement']!, p['ledger']!, currency ?? ''),
    'report_too_large' => l10n.errorRuleReportTooLarge,
    'balance_already_matches' => l10n.errorRuleBalanceAlreadyMatches,
    'duplicate_item' => l10n.codeDuplicateItem,
    'transaction_already_matched' => l10n.codeTransactionAlreadyMatched,
    _ => featureDetailMessage(l10n, detail) ?? detail.message,
  };
}

/// Codes owned by feature areas (each area localizes its own codes in
/// `features/<area>/domain/<area>_codes.dart`); null when none knows the
/// code.
String? featureDetailMessage(AppLocalizations l10n, Detail detail) {
  for (final String? Function(AppLocalizations, Detail) area in _featureCodes) {
    final String? text = area(l10n, detail);
    if (text != null) {
      return text;
    }
  }
  return null;
}

// MERGE: one entry per feature area (kept in alphabetical order).
const List<String? Function(AppLocalizations, Detail)> _featureCodes =
    <String? Function(AppLocalizations, Detail)>[
      challengeDetailMessage,
      communityDetailMessage,
      groupDetailMessage,
      groupMoneyDetailMessage,
      integrationDetailMessage,
      moderationDetailMessage,
      notificationDetailMessage,
      privacyDetailMessage,
      socialDetailMessage,
      supportDetailMessage,
    ];

/// A record status named in a coded error (`invalid_status_transition`'s
/// `from` / `to`), in the user's language.
String statusWord(AppLocalizations l10n, String? status) => switch (status) {
  'active' => l10n.statusWordActive,
  'paused' => l10n.statusWordPaused,
  'archived' => l10n.statusWordArchived,
  'ended' => l10n.statusWordEnded,
  'achieved' => l10n.statusWordAchieved,
  'cancelled' => l10n.statusWordCancelled,
  'cancellation_started' => l10n.statusWordCancelling,
  'trial' => l10n.statusWordTrial,
  'voided' => l10n.statusWordVoided,
  'pending' => l10n.statusWordPending,
  'posted' => l10n.statusWordPosted,
  null || '' => l10n.statusWordUnknown,
  final String other => other.replaceAll('_', ' '),
};

/// Why a file cannot be uploaded for [purpose], in the user's language.
String fileProblemMessage(
  AppLocalizations l10n,
  FileProblem problem,
  UploadPurpose purpose,
) => switch (problem) {
  FileProblem.empty => l10n.fileEmpty,
  FileProblem.tooLarge => l10n.fileTooLarge(
    formatFileSize(l10n, purpose.maxBytes),
  ),
  FileProblem.unsupportedType => l10n.fileTypeNotAccepted(
    acceptedTypesText(purpose),
  ),
};

/// The accepted file types of [purpose] for messages, e.g. "JPG, PNG, PDF".
String acceptedTypesText(UploadPurpose purpose) => <String>[
  for (final FileKind kind in purpose.kinds) kind.extension.toUpperCase(),
].join(', ');

/// The request reference to show with an error, if any.
String? requestIdOf(Object error) => error is ApiException
    ? (error.requestId?.isNotEmpty ?? false)
          ? error.requestId
          : null
    : null;
