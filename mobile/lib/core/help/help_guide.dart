// Help guide identifiers and titles (HELP-001). The guide text is in the
// ARB files (`helpGuide*` keys); the structure is in
// features/support/domain/help_guide_content.dart.

import 'package:montra_mobile/app/l10n/l10n.dart';

/// One in-app help guide. Screens link to their guide with
/// `HelpGuideButton`; the path matches the web (`/help/guides/<slug>`).
enum HelpGuide {
  /// Getting started without a bank link
  gettingStarted('getting-started'),

  /// Why don’t I see my bank?
  noBank('no-bank'),

  /// How balances are calculated
  balances('balances'),

  /// How budgets are calculated
  budgets('budgets'),

  /// Recurring, bills and subscriptions
  recurring('recurring'),

  /// How goals are calculated
  goals('goals'),

  /// How group balances are calculated
  groupBalances('group-balances'),

  /// Importing statements and fixing a failed import
  imports('imports'),

  /// Reconciling an account
  reconciliation('reconciliation'),

  /// Privacy, export and deletion
  privacy('privacy'),

  /// Two-step verification and recovery
  twoStep('two-step'),

  /// Fair-use limits
  fairUse('fair-use'),

  /// Troubleshooting sign-in, sync and notifications
  troubleshooting('troubleshooting');

  const HelpGuide(this.slug);

  /// URL segment.
  final String slug;

  /// The guides list.
  static const String listPath = '/help/guides';

  /// This guide's screen.
  String get path => '$listPath/$slug';

  /// The guide for a URL [slug], or null.
  static HelpGuide? fromSlug(String slug) {
    for (final HelpGuide guide in values) {
      if (guide.slug == slug) {
        return guide;
      }
    }
    return null;
  }

  /// The guide's title in the current language.
  String title(AppLocalizations l10n) => switch (this) {
    HelpGuide.gettingStarted => l10n.helpGuideGettingStartedTitle,
    HelpGuide.noBank => l10n.helpGuideNoBankTitle,
    HelpGuide.balances => l10n.helpGuideBalancesTitle,
    HelpGuide.budgets => l10n.helpGuideBudgetsTitle,
    HelpGuide.recurring => l10n.helpGuideRecurringTitle,
    HelpGuide.goals => l10n.helpGuideGoalsTitle,
    HelpGuide.groupBalances => l10n.helpGuideGroupBalancesTitle,
    HelpGuide.imports => l10n.helpGuideImportsTitle,
    HelpGuide.reconciliation => l10n.helpGuideReconciliationTitle,
    HelpGuide.privacy => l10n.helpGuidePrivacyTitle,
    HelpGuide.twoStep => l10n.helpGuideTwoStepTitle,
    HelpGuide.fairUse => l10n.helpGuideFairUseTitle,
    HelpGuide.troubleshooting => l10n.helpGuideTroubleshootingTitle,
  };
}
