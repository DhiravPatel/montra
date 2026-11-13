// Structure of the help guides (HELP-001): topics, sections and
// paragraphs. The text is in the ARB files (`helpGuide*` keys), in
// English and Hindi, and matches the web guides.

import 'package:flutter/foundation.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/help/help_guide.dart';

/// Reads one string from the localizations.
typedef L10nText = String Function(AppLocalizations l10n);

/// Groups of guides, in display order.
enum HelpGuideTopic {
  /// Getting started
  start(_topicStart),

  /// How Montra calculates
  calculations(_topicCalculations),

  /// Statements and reconciliation
  statements(_topicStatements),

  /// Privacy, security and limits
  account(_topicAccount),

  /// Troubleshooting
  troubleshooting(_topicTroubleshooting);

  const HelpGuideTopic(this.title);

  /// Heading.
  final L10nText title;
}

String _topicStart(AppLocalizations l) => l.helpGuideTopicStart;
String _topicCalculations(AppLocalizations l) => l.helpGuideTopicCalculations;
String _topicStatements(AppLocalizations l) => l.helpGuideTopicStatements;
String _topicAccount(AppLocalizations l) => l.helpGuideTopicAccount;
String _topicTroubleshooting(AppLocalizations l) =>
    l.helpGuideTopicTroubleshooting;

/// One paragraph or bullet.
@immutable
class HelpGuideBlock {
  /// Creates the block.
  const HelpGuideBlock(this.text, {this.bullet = false});

  /// The text.
  final L10nText text;

  /// Whether it is a list item.
  final bool bullet;
}

/// A titled part of a guide.
@immutable
class HelpGuideSection {
  /// Creates the section.
  const HelpGuideSection(this.id, this.title, this.blocks);

  /// Stable id (for anchors).
  final String id;

  /// Heading.
  final L10nText title;

  /// Paragraphs and bullets in order.
  final List<HelpGuideBlock> blocks;
}

/// One guide's content.
@immutable
class HelpGuideContent {
  /// Creates the content.
  const HelpGuideContent({
    required this.guide,
    required this.topic,
    required this.summary,
    required this.linkLabel,
    required this.sections,
  });

  /// Which guide.
  final HelpGuide guide;

  /// Its topic.
  final HelpGuideTopic topic;

  /// One-line summary.
  final L10nText summary;

  /// Label of the link to the screen the guide is about.
  final L10nText linkLabel;

  /// Sections in order.
  final List<HelpGuideSection> sections;

  /// Every string of the guide, for searching.
  Iterable<String> texts(AppLocalizations l10n) sync* {
    yield guide.title(l10n);
    yield summary(l10n);
    for (final HelpGuideSection section in sections) {
      yield section.title(l10n);
      for (final HelpGuideBlock block in section.blocks) {
        yield block.text(l10n);
      }
    }
  }
}

/// Every guide, in display order within its topic.
const List<HelpGuideContent> helpGuides = <HelpGuideContent>[
  HelpGuideContent(
    guide: HelpGuide.gettingStarted,
    topic: HelpGuideTopic.start,
    summary: _gettingStartedSummary,
    linkLabel: _gettingStartedLink,
    sections: <HelpGuideSection>[
      HelpGuideSection(
        'how',
        _helpGuideGettingStartedHowTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideGettingStartedHowB1),
          HelpGuideBlock(_helpGuideGettingStartedHowB2),
        ],
      ),
      HelpGuideSection(
        'steps',
        _helpGuideGettingStartedStepsTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideGettingStartedStepsB1, bullet: true),
          HelpGuideBlock(_helpGuideGettingStartedStepsB2, bullet: true),
          HelpGuideBlock(_helpGuideGettingStartedStepsB3, bullet: true),
          HelpGuideBlock(_helpGuideGettingStartedStepsB4, bullet: true),
          HelpGuideBlock(_helpGuideGettingStartedStepsB5, bullet: true),
        ],
      ),
      HelpGuideSection(
        'accurate',
        _helpGuideGettingStartedAccurateTitle,
        <HelpGuideBlock>[HelpGuideBlock(_helpGuideGettingStartedAccurateB1)],
      ),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.noBank,
    topic: HelpGuideTopic.start,
    summary: _noBankSummary,
    linkLabel: _noBankLink,
    sections: <HelpGuideSection>[
      HelpGuideSection('today', _helpGuideNoBankTodayTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideNoBankTodayB1),
        HelpGuideBlock(_helpGuideNoBankTodayB2),
      ]),
      HelpGuideSection('never', _helpGuideNoBankNeverTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideNoBankNeverB1, bullet: true),
        HelpGuideBlock(_helpGuideNoBankNeverB2, bullet: true),
        HelpGuideBlock(_helpGuideNoBankNeverB3, bullet: true),
      ]),
      HelpGuideSection(
        'instead',
        _helpGuideNoBankInsteadTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideNoBankInsteadB1, bullet: true),
          HelpGuideBlock(_helpGuideNoBankInsteadB2, bullet: true),
          HelpGuideBlock(_helpGuideNoBankInsteadB3, bullet: true),
        ],
      ),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.balances,
    topic: HelpGuideTopic.calculations,
    summary: _balancesSummary,
    linkLabel: _balancesLink,
    sections: <HelpGuideSection>[
      HelpGuideSection(
        'formula',
        _helpGuideBalancesFormulaTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideBalancesFormulaB1),
          HelpGuideBlock(_helpGuideBalancesFormulaB2),
        ],
      ),
      HelpGuideSection(
        'notSpending',
        _helpGuideBalancesNotSpendingTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideBalancesNotSpendingB1, bullet: true),
          HelpGuideBlock(_helpGuideBalancesNotSpendingB2, bullet: true),
          HelpGuideBlock(_helpGuideBalancesNotSpendingB3, bullet: true),
        ],
      ),
      HelpGuideSection(
        'currencies',
        _helpGuideBalancesCurrenciesTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideBalancesCurrenciesB1),
          HelpGuideBlock(_helpGuideBalancesCurrenciesB2),
        ],
      ),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.budgets,
    topic: HelpGuideTopic.calculations,
    summary: _budgetsSummary,
    linkLabel: _budgetsLink,
    sections: <HelpGuideSection>[
      HelpGuideSection('spent', _helpGuideBudgetsSpentTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideBudgetsSpentB1),
        HelpGuideBlock(_helpGuideBudgetsSpentB2, bullet: true),
        HelpGuideBlock(_helpGuideBudgetsSpentB3, bullet: true),
        HelpGuideBlock(_helpGuideBudgetsSpentB4, bullet: true),
      ]),
      HelpGuideSection(
        'refunds',
        _helpGuideBudgetsRefundsTitle,
        <HelpGuideBlock>[HelpGuideBlock(_helpGuideBudgetsRefundsB1)],
      ),
      HelpGuideSection('pace', _helpGuideBudgetsPaceTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideBudgetsPaceB1),
        HelpGuideBlock(_helpGuideBudgetsPaceB2, bullet: true),
        HelpGuideBlock(_helpGuideBudgetsPaceB3, bullet: true),
        HelpGuideBlock(_helpGuideBudgetsPaceB4, bullet: true),
        HelpGuideBlock(_helpGuideBudgetsPaceB5, bullet: true),
        HelpGuideBlock(_helpGuideBudgetsPaceB6),
      ]),
      HelpGuideSection(
        'rollover',
        _helpGuideBudgetsRolloverTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideBudgetsRolloverB1),
          HelpGuideBlock(_helpGuideBudgetsRolloverB2, bullet: true),
          HelpGuideBlock(_helpGuideBudgetsRolloverB3, bullet: true),
          HelpGuideBlock(_helpGuideBudgetsRolloverB4, bullet: true),
          HelpGuideBlock(_helpGuideBudgetsRolloverB5),
        ],
      ),
      HelpGuideSection('alerts', _helpGuideBudgetsAlertsTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideBudgetsAlertsB1),
      ]),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.recurring,
    topic: HelpGuideTopic.calculations,
    summary: _recurringSummary,
    linkLabel: _recurringLink,
    sections: <HelpGuideSection>[
      HelpGuideSection(
        'schedule',
        _helpGuideRecurringScheduleTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideRecurringScheduleB1),
          HelpGuideBlock(_helpGuideRecurringScheduleB2),
        ],
      ),
      HelpGuideSection('bills', _helpGuideRecurringBillsTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideRecurringBillsB1),
      ]),
      HelpGuideSection(
        'subscriptions',
        _helpGuideRecurringSubscriptionsTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideRecurringSubscriptionsB1),
          HelpGuideBlock(_helpGuideRecurringSubscriptionsB2),
        ],
      ),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.goals,
    topic: HelpGuideTopic.calculations,
    summary: _goalsSummary,
    linkLabel: _goalsLink,
    sections: <HelpGuideSection>[
      HelpGuideSection('saved', _helpGuideGoalsSavedTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideGoalsSavedB1),
        HelpGuideBlock(_helpGuideGoalsSavedB2),
      ]),
      HelpGuideSection(
        'milestones',
        _helpGuideGoalsMilestonesTitle,
        <HelpGuideBlock>[HelpGuideBlock(_helpGuideGoalsMilestonesB1)],
      ),
      HelpGuideSection(
        'forecast',
        _helpGuideGoalsForecastTitle,
        <HelpGuideBlock>[HelpGuideBlock(_helpGuideGoalsForecastB1)],
      ),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.groupBalances,
    topic: HelpGuideTopic.calculations,
    summary: _groupBalancesSummary,
    linkLabel: _groupBalancesLink,
    sections: <HelpGuideSection>[
      HelpGuideSection('net', _helpGuideGroupBalancesNetTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideGroupBalancesNetB1),
        HelpGuideBlock(_helpGuideGroupBalancesNetB2),
      ]),
      HelpGuideSection(
        'settlements',
        _helpGuideGroupBalancesSettlementsTitle,
        <HelpGuideBlock>[HelpGuideBlock(_helpGuideGroupBalancesSettlementsB1)],
      ),
      HelpGuideSection(
        'personal',
        _helpGuideGroupBalancesPersonalTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideGroupBalancesPersonalB1),
          HelpGuideBlock(_helpGuideGroupBalancesPersonalB2),
        ],
      ),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.imports,
    topic: HelpGuideTopic.statements,
    summary: _importsSummary,
    linkLabel: _importsLink,
    sections: <HelpGuideSection>[
      HelpGuideSection('steps', _helpGuideImportsStepsTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideImportsStepsB1, bullet: true),
        HelpGuideBlock(_helpGuideImportsStepsB2, bullet: true),
        HelpGuideBlock(_helpGuideImportsStepsB3, bullet: true),
        HelpGuideBlock(_helpGuideImportsStepsB4, bullet: true),
      ]),
      HelpGuideSection('failed', _helpGuideImportsFailedTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideImportsFailedB1),
        HelpGuideBlock(_helpGuideImportsFailedB2, bullet: true),
        HelpGuideBlock(_helpGuideImportsFailedB3, bullet: true),
        HelpGuideBlock(_helpGuideImportsFailedB4, bullet: true),
        HelpGuideBlock(_helpGuideImportsFailedB5, bullet: true),
      ]),
      HelpGuideSection('rows', _helpGuideImportsRowsTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideImportsRowsB1),
        HelpGuideBlock(_helpGuideImportsRowsB2),
      ]),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.reconciliation,
    topic: HelpGuideTopic.statements,
    summary: _reconciliationSummary,
    linkLabel: _reconciliationLink,
    sections: <HelpGuideSection>[
      HelpGuideSection(
        'matches',
        _helpGuideReconciliationMatchesTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideReconciliationMatchesB1),
          HelpGuideBlock(_helpGuideReconciliationMatchesB2),
          HelpGuideBlock(_helpGuideReconciliationMatchesB3, bullet: true),
          HelpGuideBlock(_helpGuideReconciliationMatchesB4, bullet: true),
          HelpGuideBlock(_helpGuideReconciliationMatchesB5, bullet: true),
        ],
      ),
      HelpGuideSection(
        'balance',
        _helpGuideReconciliationBalanceTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideReconciliationBalanceB1),
          HelpGuideBlock(_helpGuideReconciliationBalanceB2),
        ],
      ),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.privacy,
    topic: HelpGuideTopic.account,
    summary: _privacySummary,
    linkLabel: _privacyLink,
    sections: <HelpGuideSection>[
      HelpGuideSection(
        'consents',
        _helpGuidePrivacyConsentsTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuidePrivacyConsentsB1),
          HelpGuideBlock(_helpGuidePrivacyConsentsB2),
        ],
      ),
      HelpGuideSection('export', _helpGuidePrivacyExportTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuidePrivacyExportB1),
      ]),
      HelpGuideSection(
        'deactivate',
        _helpGuidePrivacyDeactivateTitle,
        <HelpGuideBlock>[HelpGuideBlock(_helpGuidePrivacyDeactivateB1)],
      ),
      HelpGuideSection('delete', _helpGuidePrivacyDeleteTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuidePrivacyDeleteB1),
        HelpGuideBlock(_helpGuidePrivacyDeleteB2),
      ]),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.twoStep,
    topic: HelpGuideTopic.account,
    summary: _twoStepSummary,
    linkLabel: _twoStepLink,
    sections: <HelpGuideSection>[
      HelpGuideSection('setup', _helpGuideTwoStepSetupTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideTwoStepSetupB1, bullet: true),
        HelpGuideBlock(_helpGuideTwoStepSetupB2, bullet: true),
        HelpGuideBlock(_helpGuideTwoStepSetupB3, bullet: true),
      ]),
      HelpGuideSection('signIn', _helpGuideTwoStepSignInTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideTwoStepSignInB1),
        HelpGuideBlock(_helpGuideTwoStepSignInB2),
      ]),
      HelpGuideSection(
        'recovery',
        _helpGuideTwoStepRecoveryTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideTwoStepRecoveryB1),
          HelpGuideBlock(_helpGuideTwoStepRecoveryB2),
          HelpGuideBlock(_helpGuideTwoStepRecoveryB3),
        ],
      ),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.fairUse,
    topic: HelpGuideTopic.account,
    summary: _fairUseSummary,
    linkLabel: _fairUseLink,
    sections: <HelpGuideSection>[
      HelpGuideSection('what', _helpGuideFairUseWhatTitle, <HelpGuideBlock>[
        HelpGuideBlock(_helpGuideFairUseWhatB1),
        HelpGuideBlock(_helpGuideFairUseWhatB2, bullet: true),
        HelpGuideBlock(_helpGuideFairUseWhatB3, bullet: true),
        HelpGuideBlock(_helpGuideFairUseWhatB4, bullet: true),
        HelpGuideBlock(_helpGuideFairUseWhatB5, bullet: true),
      ]),
      HelpGuideSection(
        'reached',
        _helpGuideFairUseReachedTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideFairUseReachedB1),
          HelpGuideBlock(_helpGuideFairUseReachedB2),
        ],
      ),
    ],
  ),
  HelpGuideContent(
    guide: HelpGuide.troubleshooting,
    topic: HelpGuideTopic.troubleshooting,
    summary: _troubleshootingSummary,
    linkLabel: _troubleshootingLink,
    sections: <HelpGuideSection>[
      HelpGuideSection(
        'signIn',
        _helpGuideTroubleshootingSignInTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideTroubleshootingSignInB1, bullet: true),
          HelpGuideBlock(_helpGuideTroubleshootingSignInB2, bullet: true),
          HelpGuideBlock(_helpGuideTroubleshootingSignInB3, bullet: true),
          HelpGuideBlock(_helpGuideTroubleshootingSignInB4, bullet: true),
          HelpGuideBlock(_helpGuideTroubleshootingSignInB5, bullet: true),
        ],
      ),
      HelpGuideSection(
        'sync',
        _helpGuideTroubleshootingSyncTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(_helpGuideTroubleshootingSyncB1),
          HelpGuideBlock(_helpGuideTroubleshootingSyncB2, bullet: true),
          HelpGuideBlock(_helpGuideTroubleshootingSyncB3, bullet: true),
        ],
      ),
      HelpGuideSection(
        'notifications',
        _helpGuideTroubleshootingNotificationsTitle,
        <HelpGuideBlock>[
          HelpGuideBlock(
            _helpGuideTroubleshootingNotificationsB1,
            bullet: true,
          ),
          HelpGuideBlock(
            _helpGuideTroubleshootingNotificationsB2,
            bullet: true,
          ),
          HelpGuideBlock(
            _helpGuideTroubleshootingNotificationsB3,
            bullet: true,
          ),
          HelpGuideBlock(
            _helpGuideTroubleshootingNotificationsB4,
            bullet: true,
          ),
        ],
      ),
      HelpGuideSection(
        'stillStuck',
        _helpGuideTroubleshootingStillStuckTitle,
        <HelpGuideBlock>[HelpGuideBlock(_helpGuideTroubleshootingStillStuckB1)],
      ),
    ],
  ),
];

/// The content of [guide].
HelpGuideContent helpGuideContent(HelpGuide guide) =>
    helpGuides.firstWhere((HelpGuideContent c) => c.guide == guide);

String _gettingStartedSummary(AppLocalizations l) =>
    l.helpGuideGettingStartedSummary;
String _gettingStartedLink(AppLocalizations l) => l.helpGuideGettingStartedLink;
String _helpGuideGettingStartedHowTitle(AppLocalizations l) =>
    l.helpGuideGettingStartedHowTitle;
String _helpGuideGettingStartedHowB1(AppLocalizations l) =>
    l.helpGuideGettingStartedHowB1;
String _helpGuideGettingStartedHowB2(AppLocalizations l) =>
    l.helpGuideGettingStartedHowB2;
String _helpGuideGettingStartedStepsTitle(AppLocalizations l) =>
    l.helpGuideGettingStartedStepsTitle;
String _helpGuideGettingStartedStepsB1(AppLocalizations l) =>
    l.helpGuideGettingStartedStepsB1;
String _helpGuideGettingStartedStepsB2(AppLocalizations l) =>
    l.helpGuideGettingStartedStepsB2;
String _helpGuideGettingStartedStepsB3(AppLocalizations l) =>
    l.helpGuideGettingStartedStepsB3;
String _helpGuideGettingStartedStepsB4(AppLocalizations l) =>
    l.helpGuideGettingStartedStepsB4;
String _helpGuideGettingStartedStepsB5(AppLocalizations l) =>
    l.helpGuideGettingStartedStepsB5;
String _helpGuideGettingStartedAccurateTitle(AppLocalizations l) =>
    l.helpGuideGettingStartedAccurateTitle;
String _helpGuideGettingStartedAccurateB1(AppLocalizations l) =>
    l.helpGuideGettingStartedAccurateB1;
String _noBankSummary(AppLocalizations l) => l.helpGuideNoBankSummary;
String _noBankLink(AppLocalizations l) => l.helpGuideNoBankLink;
String _helpGuideNoBankTodayTitle(AppLocalizations l) =>
    l.helpGuideNoBankTodayTitle;
String _helpGuideNoBankTodayB1(AppLocalizations l) => l.helpGuideNoBankTodayB1;
String _helpGuideNoBankTodayB2(AppLocalizations l) => l.helpGuideNoBankTodayB2;
String _helpGuideNoBankNeverTitle(AppLocalizations l) =>
    l.helpGuideNoBankNeverTitle;
String _helpGuideNoBankNeverB1(AppLocalizations l) => l.helpGuideNoBankNeverB1;
String _helpGuideNoBankNeverB2(AppLocalizations l) => l.helpGuideNoBankNeverB2;
String _helpGuideNoBankNeverB3(AppLocalizations l) => l.helpGuideNoBankNeverB3;
String _helpGuideNoBankInsteadTitle(AppLocalizations l) =>
    l.helpGuideNoBankInsteadTitle;
String _helpGuideNoBankInsteadB1(AppLocalizations l) =>
    l.helpGuideNoBankInsteadB1;
String _helpGuideNoBankInsteadB2(AppLocalizations l) =>
    l.helpGuideNoBankInsteadB2;
String _helpGuideNoBankInsteadB3(AppLocalizations l) =>
    l.helpGuideNoBankInsteadB3;
String _balancesSummary(AppLocalizations l) => l.helpGuideBalancesSummary;
String _balancesLink(AppLocalizations l) => l.helpGuideBalancesLink;
String _helpGuideBalancesFormulaTitle(AppLocalizations l) =>
    l.helpGuideBalancesFormulaTitle;
String _helpGuideBalancesFormulaB1(AppLocalizations l) =>
    l.helpGuideBalancesFormulaB1;
String _helpGuideBalancesFormulaB2(AppLocalizations l) =>
    l.helpGuideBalancesFormulaB2;
String _helpGuideBalancesNotSpendingTitle(AppLocalizations l) =>
    l.helpGuideBalancesNotSpendingTitle;
String _helpGuideBalancesNotSpendingB1(AppLocalizations l) =>
    l.helpGuideBalancesNotSpendingB1;
String _helpGuideBalancesNotSpendingB2(AppLocalizations l) =>
    l.helpGuideBalancesNotSpendingB2;
String _helpGuideBalancesNotSpendingB3(AppLocalizations l) =>
    l.helpGuideBalancesNotSpendingB3;
String _helpGuideBalancesCurrenciesTitle(AppLocalizations l) =>
    l.helpGuideBalancesCurrenciesTitle;
String _helpGuideBalancesCurrenciesB1(AppLocalizations l) =>
    l.helpGuideBalancesCurrenciesB1;
String _helpGuideBalancesCurrenciesB2(AppLocalizations l) =>
    l.helpGuideBalancesCurrenciesB2;
String _budgetsSummary(AppLocalizations l) => l.helpGuideBudgetsSummary;
String _budgetsLink(AppLocalizations l) => l.helpGuideBudgetsLink;
String _helpGuideBudgetsSpentTitle(AppLocalizations l) =>
    l.helpGuideBudgetsSpentTitle;
String _helpGuideBudgetsSpentB1(AppLocalizations l) =>
    l.helpGuideBudgetsSpentB1;
String _helpGuideBudgetsSpentB2(AppLocalizations l) =>
    l.helpGuideBudgetsSpentB2;
String _helpGuideBudgetsSpentB3(AppLocalizations l) =>
    l.helpGuideBudgetsSpentB3;
String _helpGuideBudgetsSpentB4(AppLocalizations l) =>
    l.helpGuideBudgetsSpentB4;
String _helpGuideBudgetsRefundsTitle(AppLocalizations l) =>
    l.helpGuideBudgetsRefundsTitle;
String _helpGuideBudgetsRefundsB1(AppLocalizations l) =>
    l.helpGuideBudgetsRefundsB1;
String _helpGuideBudgetsPaceTitle(AppLocalizations l) =>
    l.helpGuideBudgetsPaceTitle;
String _helpGuideBudgetsPaceB1(AppLocalizations l) => l.helpGuideBudgetsPaceB1;
String _helpGuideBudgetsPaceB2(AppLocalizations l) => l.helpGuideBudgetsPaceB2;
String _helpGuideBudgetsPaceB3(AppLocalizations l) => l.helpGuideBudgetsPaceB3;
String _helpGuideBudgetsPaceB4(AppLocalizations l) => l.helpGuideBudgetsPaceB4;
String _helpGuideBudgetsPaceB5(AppLocalizations l) => l.helpGuideBudgetsPaceB5;
String _helpGuideBudgetsPaceB6(AppLocalizations l) => l.helpGuideBudgetsPaceB6;
String _helpGuideBudgetsRolloverTitle(AppLocalizations l) =>
    l.helpGuideBudgetsRolloverTitle;
String _helpGuideBudgetsRolloverB1(AppLocalizations l) =>
    l.helpGuideBudgetsRolloverB1;
String _helpGuideBudgetsRolloverB2(AppLocalizations l) =>
    l.helpGuideBudgetsRolloverB2;
String _helpGuideBudgetsRolloverB3(AppLocalizations l) =>
    l.helpGuideBudgetsRolloverB3;
String _helpGuideBudgetsRolloverB4(AppLocalizations l) =>
    l.helpGuideBudgetsRolloverB4;
String _helpGuideBudgetsRolloverB5(AppLocalizations l) =>
    l.helpGuideBudgetsRolloverB5;
String _helpGuideBudgetsAlertsTitle(AppLocalizations l) =>
    l.helpGuideBudgetsAlertsTitle;
String _helpGuideBudgetsAlertsB1(AppLocalizations l) =>
    l.helpGuideBudgetsAlertsB1;
String _recurringSummary(AppLocalizations l) => l.helpGuideRecurringSummary;
String _recurringLink(AppLocalizations l) => l.helpGuideRecurringLink;
String _helpGuideRecurringScheduleTitle(AppLocalizations l) =>
    l.helpGuideRecurringScheduleTitle;
String _helpGuideRecurringScheduleB1(AppLocalizations l) =>
    l.helpGuideRecurringScheduleB1;
String _helpGuideRecurringScheduleB2(AppLocalizations l) =>
    l.helpGuideRecurringScheduleB2;
String _helpGuideRecurringBillsTitle(AppLocalizations l) =>
    l.helpGuideRecurringBillsTitle;
String _helpGuideRecurringBillsB1(AppLocalizations l) =>
    l.helpGuideRecurringBillsB1;
String _helpGuideRecurringSubscriptionsTitle(AppLocalizations l) =>
    l.helpGuideRecurringSubscriptionsTitle;
String _helpGuideRecurringSubscriptionsB1(AppLocalizations l) =>
    l.helpGuideRecurringSubscriptionsB1;
String _helpGuideRecurringSubscriptionsB2(AppLocalizations l) =>
    l.helpGuideRecurringSubscriptionsB2;
String _goalsSummary(AppLocalizations l) => l.helpGuideGoalsSummary;
String _goalsLink(AppLocalizations l) => l.helpGuideGoalsLink;
String _helpGuideGoalsSavedTitle(AppLocalizations l) =>
    l.helpGuideGoalsSavedTitle;
String _helpGuideGoalsSavedB1(AppLocalizations l) => l.helpGuideGoalsSavedB1;
String _helpGuideGoalsSavedB2(AppLocalizations l) => l.helpGuideGoalsSavedB2;
String _helpGuideGoalsMilestonesTitle(AppLocalizations l) =>
    l.helpGuideGoalsMilestonesTitle;
String _helpGuideGoalsMilestonesB1(AppLocalizations l) =>
    l.helpGuideGoalsMilestonesB1;
String _helpGuideGoalsForecastTitle(AppLocalizations l) =>
    l.helpGuideGoalsForecastTitle;
String _helpGuideGoalsForecastB1(AppLocalizations l) =>
    l.helpGuideGoalsForecastB1;
String _groupBalancesSummary(AppLocalizations l) =>
    l.helpGuideGroupBalancesSummary;
String _groupBalancesLink(AppLocalizations l) => l.helpGuideGroupBalancesLink;
String _helpGuideGroupBalancesNetTitle(AppLocalizations l) =>
    l.helpGuideGroupBalancesNetTitle;
String _helpGuideGroupBalancesNetB1(AppLocalizations l) =>
    l.helpGuideGroupBalancesNetB1;
String _helpGuideGroupBalancesNetB2(AppLocalizations l) =>
    l.helpGuideGroupBalancesNetB2;
String _helpGuideGroupBalancesSettlementsTitle(AppLocalizations l) =>
    l.helpGuideGroupBalancesSettlementsTitle;
String _helpGuideGroupBalancesSettlementsB1(AppLocalizations l) =>
    l.helpGuideGroupBalancesSettlementsB1;
String _helpGuideGroupBalancesPersonalTitle(AppLocalizations l) =>
    l.helpGuideGroupBalancesPersonalTitle;
String _helpGuideGroupBalancesPersonalB1(AppLocalizations l) =>
    l.helpGuideGroupBalancesPersonalB1;
String _helpGuideGroupBalancesPersonalB2(AppLocalizations l) =>
    l.helpGuideGroupBalancesPersonalB2;
String _importsSummary(AppLocalizations l) => l.helpGuideImportsSummary;
String _importsLink(AppLocalizations l) => l.helpGuideImportsLink;
String _helpGuideImportsStepsTitle(AppLocalizations l) =>
    l.helpGuideImportsStepsTitle;
String _helpGuideImportsStepsB1(AppLocalizations l) =>
    l.helpGuideImportsStepsB1;
String _helpGuideImportsStepsB2(AppLocalizations l) =>
    l.helpGuideImportsStepsB2;
String _helpGuideImportsStepsB3(AppLocalizations l) =>
    l.helpGuideImportsStepsB3;
String _helpGuideImportsStepsB4(AppLocalizations l) =>
    l.helpGuideImportsStepsB4;
String _helpGuideImportsFailedTitle(AppLocalizations l) =>
    l.helpGuideImportsFailedTitle;
String _helpGuideImportsFailedB1(AppLocalizations l) =>
    l.helpGuideImportsFailedB1;
String _helpGuideImportsFailedB2(AppLocalizations l) =>
    l.helpGuideImportsFailedB2;
String _helpGuideImportsFailedB3(AppLocalizations l) =>
    l.helpGuideImportsFailedB3;
String _helpGuideImportsFailedB4(AppLocalizations l) =>
    l.helpGuideImportsFailedB4;
String _helpGuideImportsFailedB5(AppLocalizations l) =>
    l.helpGuideImportsFailedB5;
String _helpGuideImportsRowsTitle(AppLocalizations l) =>
    l.helpGuideImportsRowsTitle;
String _helpGuideImportsRowsB1(AppLocalizations l) => l.helpGuideImportsRowsB1;
String _helpGuideImportsRowsB2(AppLocalizations l) => l.helpGuideImportsRowsB2;
String _reconciliationSummary(AppLocalizations l) =>
    l.helpGuideReconciliationSummary;
String _reconciliationLink(AppLocalizations l) => l.helpGuideReconciliationLink;
String _helpGuideReconciliationMatchesTitle(AppLocalizations l) =>
    l.helpGuideReconciliationMatchesTitle;
String _helpGuideReconciliationMatchesB1(AppLocalizations l) =>
    l.helpGuideReconciliationMatchesB1;
String _helpGuideReconciliationMatchesB2(AppLocalizations l) =>
    l.helpGuideReconciliationMatchesB2;
String _helpGuideReconciliationMatchesB3(AppLocalizations l) =>
    l.helpGuideReconciliationMatchesB3;
String _helpGuideReconciliationMatchesB4(AppLocalizations l) =>
    l.helpGuideReconciliationMatchesB4;
String _helpGuideReconciliationMatchesB5(AppLocalizations l) =>
    l.helpGuideReconciliationMatchesB5;
String _helpGuideReconciliationBalanceTitle(AppLocalizations l) =>
    l.helpGuideReconciliationBalanceTitle;
String _helpGuideReconciliationBalanceB1(AppLocalizations l) =>
    l.helpGuideReconciliationBalanceB1;
String _helpGuideReconciliationBalanceB2(AppLocalizations l) =>
    l.helpGuideReconciliationBalanceB2;
String _privacySummary(AppLocalizations l) => l.helpGuidePrivacySummary;
String _privacyLink(AppLocalizations l) => l.helpGuidePrivacyLink;
String _helpGuidePrivacyConsentsTitle(AppLocalizations l) =>
    l.helpGuidePrivacyConsentsTitle;
String _helpGuidePrivacyConsentsB1(AppLocalizations l) =>
    l.helpGuidePrivacyConsentsB1;
String _helpGuidePrivacyConsentsB2(AppLocalizations l) =>
    l.helpGuidePrivacyConsentsB2;
String _helpGuidePrivacyExportTitle(AppLocalizations l) =>
    l.helpGuidePrivacyExportTitle;
String _helpGuidePrivacyExportB1(AppLocalizations l) =>
    l.helpGuidePrivacyExportB1;
String _helpGuidePrivacyDeactivateTitle(AppLocalizations l) =>
    l.helpGuidePrivacyDeactivateTitle;
String _helpGuidePrivacyDeactivateB1(AppLocalizations l) =>
    l.helpGuidePrivacyDeactivateB1;
String _helpGuidePrivacyDeleteTitle(AppLocalizations l) =>
    l.helpGuidePrivacyDeleteTitle;
String _helpGuidePrivacyDeleteB1(AppLocalizations l) =>
    l.helpGuidePrivacyDeleteB1;
String _helpGuidePrivacyDeleteB2(AppLocalizations l) =>
    l.helpGuidePrivacyDeleteB2;
String _twoStepSummary(AppLocalizations l) => l.helpGuideTwoStepSummary;
String _twoStepLink(AppLocalizations l) => l.helpGuideTwoStepLink;
String _helpGuideTwoStepSetupTitle(AppLocalizations l) =>
    l.helpGuideTwoStepSetupTitle;
String _helpGuideTwoStepSetupB1(AppLocalizations l) =>
    l.helpGuideTwoStepSetupB1;
String _helpGuideTwoStepSetupB2(AppLocalizations l) =>
    l.helpGuideTwoStepSetupB2;
String _helpGuideTwoStepSetupB3(AppLocalizations l) =>
    l.helpGuideTwoStepSetupB3;
String _helpGuideTwoStepSignInTitle(AppLocalizations l) =>
    l.helpGuideTwoStepSignInTitle;
String _helpGuideTwoStepSignInB1(AppLocalizations l) =>
    l.helpGuideTwoStepSignInB1;
String _helpGuideTwoStepSignInB2(AppLocalizations l) =>
    l.helpGuideTwoStepSignInB2;
String _helpGuideTwoStepRecoveryTitle(AppLocalizations l) =>
    l.helpGuideTwoStepRecoveryTitle;
String _helpGuideTwoStepRecoveryB1(AppLocalizations l) =>
    l.helpGuideTwoStepRecoveryB1;
String _helpGuideTwoStepRecoveryB2(AppLocalizations l) =>
    l.helpGuideTwoStepRecoveryB2;
String _helpGuideTwoStepRecoveryB3(AppLocalizations l) =>
    l.helpGuideTwoStepRecoveryB3;
String _fairUseSummary(AppLocalizations l) => l.helpGuideFairUseSummary;
String _fairUseLink(AppLocalizations l) => l.helpGuideFairUseLink;
String _helpGuideFairUseWhatTitle(AppLocalizations l) =>
    l.helpGuideFairUseWhatTitle;
String _helpGuideFairUseWhatB1(AppLocalizations l) => l.helpGuideFairUseWhatB1;
String _helpGuideFairUseWhatB2(AppLocalizations l) => l.helpGuideFairUseWhatB2;
String _helpGuideFairUseWhatB3(AppLocalizations l) => l.helpGuideFairUseWhatB3;
String _helpGuideFairUseWhatB4(AppLocalizations l) => l.helpGuideFairUseWhatB4;
String _helpGuideFairUseWhatB5(AppLocalizations l) => l.helpGuideFairUseWhatB5;
String _helpGuideFairUseReachedTitle(AppLocalizations l) =>
    l.helpGuideFairUseReachedTitle;
String _helpGuideFairUseReachedB1(AppLocalizations l) =>
    l.helpGuideFairUseReachedB1;
String _helpGuideFairUseReachedB2(AppLocalizations l) =>
    l.helpGuideFairUseReachedB2;
String _troubleshootingSummary(AppLocalizations l) =>
    l.helpGuideTroubleshootingSummary;
String _troubleshootingLink(AppLocalizations l) =>
    l.helpGuideTroubleshootingLink;
String _helpGuideTroubleshootingSignInTitle(AppLocalizations l) =>
    l.helpGuideTroubleshootingSignInTitle;
String _helpGuideTroubleshootingSignInB1(AppLocalizations l) =>
    l.helpGuideTroubleshootingSignInB1;
String _helpGuideTroubleshootingSignInB2(AppLocalizations l) =>
    l.helpGuideTroubleshootingSignInB2;
String _helpGuideTroubleshootingSignInB3(AppLocalizations l) =>
    l.helpGuideTroubleshootingSignInB3;
String _helpGuideTroubleshootingSignInB4(AppLocalizations l) =>
    l.helpGuideTroubleshootingSignInB4;
String _helpGuideTroubleshootingSignInB5(AppLocalizations l) =>
    l.helpGuideTroubleshootingSignInB5;
String _helpGuideTroubleshootingSyncTitle(AppLocalizations l) =>
    l.helpGuideTroubleshootingSyncTitle;
String _helpGuideTroubleshootingSyncB1(AppLocalizations l) =>
    l.helpGuideTroubleshootingSyncB1;
String _helpGuideTroubleshootingSyncB2(AppLocalizations l) =>
    l.helpGuideTroubleshootingSyncB2;
String _helpGuideTroubleshootingSyncB3(AppLocalizations l) =>
    l.helpGuideTroubleshootingSyncB3;
String _helpGuideTroubleshootingNotificationsTitle(AppLocalizations l) =>
    l.helpGuideTroubleshootingNotificationsTitle;
String _helpGuideTroubleshootingNotificationsB1(AppLocalizations l) =>
    l.helpGuideTroubleshootingNotificationsB1;
String _helpGuideTroubleshootingNotificationsB2(AppLocalizations l) =>
    l.helpGuideTroubleshootingNotificationsB2;
String _helpGuideTroubleshootingNotificationsB3(AppLocalizations l) =>
    l.helpGuideTroubleshootingNotificationsB3;
String _helpGuideTroubleshootingNotificationsB4(AppLocalizations l) =>
    l.helpGuideTroubleshootingNotificationsB4;
String _helpGuideTroubleshootingStillStuckTitle(AppLocalizations l) =>
    l.helpGuideTroubleshootingStillStuckTitle;
String _helpGuideTroubleshootingStillStuckB1(AppLocalizations l) =>
    l.helpGuideTroubleshootingStillStuckB1;
