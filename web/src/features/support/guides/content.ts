import type { HelpGuideId } from '@/shared/help/guides';
import type { MessageKey } from '@/shared/i18n/types';

/**
 * The structure of each help guide: sections of paragraphs and list items,
 * by message key (helpContent.*). The text itself is in the catalogs, in
 * English and Hindi, from the same source as the mobile app's guides.
 */
export interface GuideBlock {
  kind: 'p' | 'li';
  key: MessageKey;
}

export interface GuideSection {
  /** Anchor on the guide page (`#pace`). */
  id: string;
  title: MessageKey;
  blocks: readonly GuideBlock[];
}

export const guideSections: Readonly<Record<HelpGuideId, readonly GuideSection[]>> = {
  gettingStarted: [
    {
      id: 'how',
      title: 'helpContent.gettingStarted.how.title',
      blocks: [
        { kind: 'p', key: 'helpContent.gettingStarted.how.1' },
        { kind: 'p', key: 'helpContent.gettingStarted.how.2' },
      ],
    },
    {
      id: 'steps',
      title: 'helpContent.gettingStarted.steps.title',
      blocks: [
        { kind: 'li', key: 'helpContent.gettingStarted.steps.1' },
        { kind: 'li', key: 'helpContent.gettingStarted.steps.2' },
        { kind: 'li', key: 'helpContent.gettingStarted.steps.3' },
        { kind: 'li', key: 'helpContent.gettingStarted.steps.4' },
        { kind: 'li', key: 'helpContent.gettingStarted.steps.5' },
      ],
    },
    {
      id: 'accurate',
      title: 'helpContent.gettingStarted.accurate.title',
      blocks: [{ kind: 'p', key: 'helpContent.gettingStarted.accurate.1' }],
    },
  ],
  noBank: [
    {
      id: 'today',
      title: 'helpContent.noBank.today.title',
      blocks: [
        { kind: 'p', key: 'helpContent.noBank.today.1' },
        { kind: 'p', key: 'helpContent.noBank.today.2' },
      ],
    },
    {
      id: 'never',
      title: 'helpContent.noBank.never.title',
      blocks: [
        { kind: 'li', key: 'helpContent.noBank.never.1' },
        { kind: 'li', key: 'helpContent.noBank.never.2' },
        { kind: 'li', key: 'helpContent.noBank.never.3' },
      ],
    },
    {
      id: 'instead',
      title: 'helpContent.noBank.instead.title',
      blocks: [
        { kind: 'li', key: 'helpContent.noBank.instead.1' },
        { kind: 'li', key: 'helpContent.noBank.instead.2' },
        { kind: 'li', key: 'helpContent.noBank.instead.3' },
      ],
    },
  ],
  balances: [
    {
      id: 'formula',
      title: 'helpContent.balances.formula.title',
      blocks: [
        { kind: 'p', key: 'helpContent.balances.formula.1' },
        { kind: 'p', key: 'helpContent.balances.formula.2' },
      ],
    },
    {
      id: 'not-spending',
      title: 'helpContent.balances.notSpending.title',
      blocks: [
        { kind: 'li', key: 'helpContent.balances.notSpending.1' },
        { kind: 'li', key: 'helpContent.balances.notSpending.2' },
        { kind: 'li', key: 'helpContent.balances.notSpending.3' },
      ],
    },
    {
      id: 'currencies',
      title: 'helpContent.balances.currencies.title',
      blocks: [
        { kind: 'p', key: 'helpContent.balances.currencies.1' },
        { kind: 'p', key: 'helpContent.balances.currencies.2' },
      ],
    },
  ],
  budgets: [
    {
      id: 'spent',
      title: 'helpContent.budgets.spent.title',
      blocks: [
        { kind: 'p', key: 'helpContent.budgets.spent.1' },
        { kind: 'li', key: 'helpContent.budgets.spent.2' },
        { kind: 'li', key: 'helpContent.budgets.spent.3' },
        { kind: 'li', key: 'helpContent.budgets.spent.4' },
      ],
    },
    {
      id: 'refunds',
      title: 'helpContent.budgets.refunds.title',
      blocks: [{ kind: 'p', key: 'helpContent.budgets.refunds.1' }],
    },
    {
      id: 'pace',
      title: 'helpContent.budgets.pace.title',
      blocks: [
        { kind: 'p', key: 'helpContent.budgets.pace.1' },
        { kind: 'li', key: 'helpContent.budgets.pace.2' },
        { kind: 'li', key: 'helpContent.budgets.pace.3' },
        { kind: 'li', key: 'helpContent.budgets.pace.4' },
        { kind: 'li', key: 'helpContent.budgets.pace.5' },
        { kind: 'p', key: 'helpContent.budgets.pace.6' },
      ],
    },
    {
      id: 'rollover',
      title: 'helpContent.budgets.rollover.title',
      blocks: [
        { kind: 'p', key: 'helpContent.budgets.rollover.1' },
        { kind: 'li', key: 'helpContent.budgets.rollover.2' },
        { kind: 'li', key: 'helpContent.budgets.rollover.3' },
        { kind: 'li', key: 'helpContent.budgets.rollover.4' },
        { kind: 'p', key: 'helpContent.budgets.rollover.5' },
      ],
    },
    {
      id: 'alerts',
      title: 'helpContent.budgets.alerts.title',
      blocks: [{ kind: 'p', key: 'helpContent.budgets.alerts.1' }],
    },
  ],
  recurring: [
    {
      id: 'schedule',
      title: 'helpContent.recurring.schedule.title',
      blocks: [
        { kind: 'p', key: 'helpContent.recurring.schedule.1' },
        { kind: 'p', key: 'helpContent.recurring.schedule.2' },
      ],
    },
    {
      id: 'bills',
      title: 'helpContent.recurring.bills.title',
      blocks: [{ kind: 'p', key: 'helpContent.recurring.bills.1' }],
    },
    {
      id: 'subscriptions',
      title: 'helpContent.recurring.subscriptions.title',
      blocks: [
        { kind: 'p', key: 'helpContent.recurring.subscriptions.1' },
        { kind: 'p', key: 'helpContent.recurring.subscriptions.2' },
      ],
    },
  ],
  goals: [
    {
      id: 'saved',
      title: 'helpContent.goals.saved.title',
      blocks: [
        { kind: 'p', key: 'helpContent.goals.saved.1' },
        { kind: 'p', key: 'helpContent.goals.saved.2' },
      ],
    },
    {
      id: 'milestones',
      title: 'helpContent.goals.milestones.title',
      blocks: [{ kind: 'p', key: 'helpContent.goals.milestones.1' }],
    },
    {
      id: 'forecast',
      title: 'helpContent.goals.forecast.title',
      blocks: [{ kind: 'p', key: 'helpContent.goals.forecast.1' }],
    },
  ],
  groupBalances: [
    {
      id: 'net',
      title: 'helpContent.groupBalances.net.title',
      blocks: [
        { kind: 'p', key: 'helpContent.groupBalances.net.1' },
        { kind: 'p', key: 'helpContent.groupBalances.net.2' },
      ],
    },
    {
      id: 'settlements',
      title: 'helpContent.groupBalances.settlements.title',
      blocks: [{ kind: 'p', key: 'helpContent.groupBalances.settlements.1' }],
    },
    {
      id: 'personal',
      title: 'helpContent.groupBalances.personal.title',
      blocks: [
        { kind: 'p', key: 'helpContent.groupBalances.personal.1' },
        { kind: 'p', key: 'helpContent.groupBalances.personal.2' },
      ],
    },
  ],
  imports: [
    {
      id: 'steps',
      title: 'helpContent.imports.steps.title',
      blocks: [
        { kind: 'li', key: 'helpContent.imports.steps.1' },
        { kind: 'li', key: 'helpContent.imports.steps.2' },
        { kind: 'li', key: 'helpContent.imports.steps.3' },
        { kind: 'li', key: 'helpContent.imports.steps.4' },
      ],
    },
    {
      id: 'failed',
      title: 'helpContent.imports.failed.title',
      blocks: [
        { kind: 'p', key: 'helpContent.imports.failed.1' },
        { kind: 'li', key: 'helpContent.imports.failed.2' },
        { kind: 'li', key: 'helpContent.imports.failed.3' },
        { kind: 'li', key: 'helpContent.imports.failed.4' },
        { kind: 'li', key: 'helpContent.imports.failed.5' },
      ],
    },
    {
      id: 'rows',
      title: 'helpContent.imports.rows.title',
      blocks: [
        { kind: 'p', key: 'helpContent.imports.rows.1' },
        { kind: 'p', key: 'helpContent.imports.rows.2' },
      ],
    },
  ],
  reconciliation: [
    {
      id: 'matches',
      title: 'helpContent.reconciliation.matches.title',
      blocks: [
        { kind: 'p', key: 'helpContent.reconciliation.matches.1' },
        { kind: 'p', key: 'helpContent.reconciliation.matches.2' },
        { kind: 'li', key: 'helpContent.reconciliation.matches.3' },
        { kind: 'li', key: 'helpContent.reconciliation.matches.4' },
        { kind: 'li', key: 'helpContent.reconciliation.matches.5' },
      ],
    },
    {
      id: 'balance',
      title: 'helpContent.reconciliation.balance.title',
      blocks: [
        { kind: 'p', key: 'helpContent.reconciliation.balance.1' },
        { kind: 'p', key: 'helpContent.reconciliation.balance.2' },
      ],
    },
  ],
  privacy: [
    {
      id: 'consents',
      title: 'helpContent.privacy.consents.title',
      blocks: [
        { kind: 'p', key: 'helpContent.privacy.consents.1' },
        { kind: 'p', key: 'helpContent.privacy.consents.2' },
      ],
    },
    {
      id: 'export',
      title: 'helpContent.privacy.export.title',
      blocks: [{ kind: 'p', key: 'helpContent.privacy.export.1' }],
    },
    {
      id: 'deactivate',
      title: 'helpContent.privacy.deactivate.title',
      blocks: [{ kind: 'p', key: 'helpContent.privacy.deactivate.1' }],
    },
    {
      id: 'delete',
      title: 'helpContent.privacy.delete.title',
      blocks: [
        { kind: 'p', key: 'helpContent.privacy.delete.1' },
        { kind: 'p', key: 'helpContent.privacy.delete.2' },
      ],
    },
  ],
  twoStep: [
    {
      id: 'setup',
      title: 'helpContent.twoStep.setup.title',
      blocks: [
        { kind: 'li', key: 'helpContent.twoStep.setup.1' },
        { kind: 'li', key: 'helpContent.twoStep.setup.2' },
        { kind: 'li', key: 'helpContent.twoStep.setup.3' },
      ],
    },
    {
      id: 'sign-in',
      title: 'helpContent.twoStep.signIn.title',
      blocks: [
        { kind: 'p', key: 'helpContent.twoStep.signIn.1' },
        { kind: 'p', key: 'helpContent.twoStep.signIn.2' },
      ],
    },
    {
      id: 'recovery',
      title: 'helpContent.twoStep.recovery.title',
      blocks: [
        { kind: 'p', key: 'helpContent.twoStep.recovery.1' },
        { kind: 'p', key: 'helpContent.twoStep.recovery.2' },
        { kind: 'p', key: 'helpContent.twoStep.recovery.3' },
      ],
    },
  ],
  fairUse: [
    {
      id: 'what',
      title: 'helpContent.fairUse.what.title',
      blocks: [
        { kind: 'p', key: 'helpContent.fairUse.what.1' },
        { kind: 'li', key: 'helpContent.fairUse.what.2' },
        { kind: 'li', key: 'helpContent.fairUse.what.3' },
        { kind: 'li', key: 'helpContent.fairUse.what.4' },
        { kind: 'li', key: 'helpContent.fairUse.what.5' },
      ],
    },
    {
      id: 'reached',
      title: 'helpContent.fairUse.reached.title',
      blocks: [
        { kind: 'p', key: 'helpContent.fairUse.reached.1' },
        { kind: 'p', key: 'helpContent.fairUse.reached.2' },
      ],
    },
  ],
  troubleshooting: [
    {
      id: 'sign-in',
      title: 'helpContent.troubleshooting.signIn.title',
      blocks: [
        { kind: 'li', key: 'helpContent.troubleshooting.signIn.1' },
        { kind: 'li', key: 'helpContent.troubleshooting.signIn.2' },
        { kind: 'li', key: 'helpContent.troubleshooting.signIn.3' },
        { kind: 'li', key: 'helpContent.troubleshooting.signIn.4' },
        { kind: 'li', key: 'helpContent.troubleshooting.signIn.5' },
      ],
    },
    {
      id: 'sync',
      title: 'helpContent.troubleshooting.sync.title',
      blocks: [
        { kind: 'p', key: 'helpContent.troubleshooting.sync.1' },
        { kind: 'li', key: 'helpContent.troubleshooting.sync.2' },
        { kind: 'li', key: 'helpContent.troubleshooting.sync.3' },
      ],
    },
    {
      id: 'notifications',
      title: 'helpContent.troubleshooting.notifications.title',
      blocks: [
        { kind: 'li', key: 'helpContent.troubleshooting.notifications.1' },
        { kind: 'li', key: 'helpContent.troubleshooting.notifications.2' },
        { kind: 'li', key: 'helpContent.troubleshooting.notifications.3' },
        { kind: 'li', key: 'helpContent.troubleshooting.notifications.4' },
      ],
    },
    {
      id: 'still-stuck',
      title: 'helpContent.troubleshooting.stillStuck.title',
      blocks: [{ kind: 'p', key: 'helpContent.troubleshooting.stillStuck.1' }],
    },
  ],
};
