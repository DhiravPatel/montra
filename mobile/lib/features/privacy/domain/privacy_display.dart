import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';

/// An optional consent shown on the privacy screen.
class OptionalConsent {
  /// Creates the entry.
  const OptionalConsent(this.type, {this.grantable = true});

  /// The consent type.
  final ConsentVersionDtoType type;

  /// Whether this app offers to give it. AI consents are withdraw-only:
  /// Montra's mobile app has no AI features, but a consent given elsewhere
  /// can always be withdrawn here.
  final bool grantable;
}

/// Optional consents in the order shown.
const List<OptionalConsent> optionalConsents = <OptionalConsent>[
  OptionalConsent(ConsentVersionDtoType.location),
  OptionalConsent(ConsentVersionDtoType.pushNotifications),
  OptionalConsent(ConsentVersionDtoType.marketingEmail),
  OptionalConsent(ConsentVersionDtoType.productAnalytics),
  OptionalConsent(ConsentVersionDtoType.contactsDiscovery),
  OptionalConsent(ConsentVersionDtoType.aiProcessing, grantable: false),
  OptionalConsent(ConsentVersionDtoType.aiReceiptProcessing, grantable: false),
];

/// Consents accepted at sign-up and needed to use Montra.
const List<ConsentVersionDtoType> requiredConsents = <ConsentVersionDtoType>[
  ConsentVersionDtoType.terms,
  ConsentVersionDtoType.privacyPolicy,
];

/// Title of a consent type.
String consentTitle(AppLocalizations l10n, ConsentVersionDtoType type) =>
    switch (type) {
      ConsentVersionDtoType.terms => l10n.privacyConsentTerms,
      ConsentVersionDtoType.privacyPolicy => l10n.privacyConsentPrivacyPolicy,
      ConsentVersionDtoType.location => l10n.privacyConsentLocation,
      ConsentVersionDtoType.pushNotifications => l10n.privacyConsentPush,
      ConsentVersionDtoType.marketingEmail => l10n.privacyConsentMarketing,
      ConsentVersionDtoType.productAnalytics => l10n.privacyConsentAnalytics,
      ConsentVersionDtoType.contactsDiscovery => l10n.privacyConsentContacts,
      ConsentVersionDtoType.aiProcessing => l10n.privacyConsentAi,
      ConsentVersionDtoType.aiReceiptProcessing =>
        l10n.privacyConsentAiReceipts,
      ConsentVersionDtoType.unrecognized => l10n.privacyConsentOther,
    };

/// What a consent allows and what happens when it is off.
String consentBody(
  AppLocalizations l10n,
  ConsentVersionDtoType type,
) => switch (type) {
  ConsentVersionDtoType.location => l10n.privacyConsentLocationBody,
  ConsentVersionDtoType.pushNotifications => l10n.privacyConsentPushBody,
  ConsentVersionDtoType.marketingEmail => l10n.privacyConsentMarketingBody,
  ConsentVersionDtoType.productAnalytics => l10n.privacyConsentAnalyticsBody,
  ConsentVersionDtoType.contactsDiscovery => l10n.privacyConsentContactsBody,
  ConsentVersionDtoType.aiProcessing => l10n.privacyConsentAiBody,
  ConsentVersionDtoType.aiReceiptProcessing =>
    l10n.privacyConsentAiReceiptsBody,
  ConsentVersionDtoType.terms ||
  ConsentVersionDtoType.privacyPolicy => l10n.privacyConsentRequiredBody,
  ConsentVersionDtoType.unrecognized => '',
};

/// The grant request type for a consent version type (same wire values).
MeConsentsGrantRequestConsentType grantTypeOf(ConsentVersionDtoType type) =>
    MeConsentsGrantRequestConsentType.fromJson(type.json);

/// A data export's status in words.
(String, StatusTone) exportStatus(
  AppLocalizations l10n,
  ExportDto e,
) => switch (e.status) {
  ExportDtoStatus.queued => (l10n.privacyExportQueued, StatusTone.neutral),
  ExportDtoStatus.running => (l10n.privacyExportRunning, StatusTone.neutral),
  ExportDtoStatus.completed => (l10n.privacyExportReady, StatusTone.positive),
  ExportDtoStatus.failed => (l10n.privacyExportFailed, StatusTone.caution),
  ExportDtoStatus.expired => (l10n.privacyExportExpired, StatusTone.neutral),
  ExportDtoStatus.unrecognized => (l10n.statusWordUnknown, StatusTone.neutral),
};

/// Whether [e] is still being made.
bool exportWorking(ExportDto e) =>
    e.status == ExportDtoStatus.queued || e.status == ExportDtoStatus.running;

/// What deleting the account does, by code (same order as the English
/// `consequences`, which is the fallback).
String deletionConsequence(AppLocalizations l10n, String code, String text) =>
    switch (code) {
      'signed_out_and_integrations_revoked' =>
        l10n.deletionConsequenceSignedOut,
      'personal_records_deleted' => l10n.deletionConsequenceRecords,
      'documents_removed' => l10n.deletionConsequenceDocuments,
      'profile_removed_posts_anonymized' => l10n.deletionConsequenceProfile,
      'irreversible_after_date' => l10n.deletionConsequenceIrreversible,
      _ => text,
    };

/// What is kept after deletion and why, by code.
String deletionRetained(AppLocalizations l10n, String code, String text) =>
    switch (code) {
      'shared_group_records_anonymized' => l10n.deletionRetainedGroupRecords,
      'security_audit_records_retained' => l10n.deletionRetainedAudit,
      _ => text,
    };

/// How a group is affected by the deletion.
String groupImpactText(AppLocalizations l10n, GroupImpactDto impact) {
  final String name = impact.params['group_name'] ?? '';
  return switch (impact.code) {
    GroupImpactDtoCode.ownershipTransfer => l10n.deletionGroupTransfer(name),
    GroupImpactDtoCode.groupDeleted => l10n.deletionGroupDeleted(name),
    GroupImpactDtoCode.unrecognized => impact.text,
  };
}

/// The localized English text at [index] of [codes]/[texts] pairs.
List<String> pairedTexts(
  List<String> codes,
  List<String> texts,
  String Function(String code, String text) localize,
) => <String>[
  for (int i = 0; i < texts.length; i++)
    localize(i < codes.length ? codes[i] : '', texts[i]),
];

/// The name of a rate-limit policy.
String rateLimitPolicyLabel(AppLocalizations l10n, RateLimitPolicy p) =>
    switch (p) {
      RateLimitPolicy.defaultValue => l10n.limitsPolicyDefault,
      RateLimitPolicy.auth => l10n.limitsPolicyAuth,
      RateLimitPolicy.write => l10n.limitsPolicyWrite,
      RateLimitPolicy.upload => l10n.limitsPolicyUpload,
      RateLimitPolicy.ai => l10n.limitsPolicyAi,
      RateLimitPolicy.exportValue => l10n.limitsPolicyExport,
      RateLimitPolicy.social => l10n.limitsPolicySocial,
      RateLimitPolicy.unrecognized => l10n.limitsPolicyOther,
    };

/// Localized text for the privacy area's coded errors; null for others.
String? privacyDetailMessage(AppLocalizations l10n, Detail detail) =>
    switch (detail.code) {
      'required_consent' => l10n.privacyRequiredConsentError,
      'consent_version_outdated' => l10n.privacyConsentOutdated(
        detail.params?['version'] ?? '',
      ),
      'confirm_word_mismatch' => l10n.codeConfirmWordMismatch(
        detail.params?['word'] ?? 'DELETE',
      ),
      'deletion_already_scheduled' => l10n.codeDeletionAlreadyScheduled,
      'no_deletion_scheduled' => l10n.codeNoDeletionScheduled,
      _ => null,
    };
