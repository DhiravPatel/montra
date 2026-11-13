import type { Message } from '../../types';

/** Help guides: topics, titles, summaries and the guide screens’ own strings */
const messages = {
  // Help guides: topics, titles and summaries (the guide text is in helpContent)
  'helpGuides.topic.start': 'Getting started',
  'helpGuides.topic.calculations': 'How Montra calculates',
  'helpGuides.topic.statements': 'Statements and reconciliation',
  'helpGuides.topic.account': 'Privacy, security and limits',
  'helpGuides.topic.troubleshooting': 'Troubleshooting',
  'helpGuides.ui.title': 'Guides',
  'helpGuides.ui.description': 'Step-by-step guides and how Montra works out your numbers.',
  'helpGuides.ui.search': 'Search the guides',
  'helpGuides.ui.searchHelp': 'Searches titles and text in the current language.',
  'helpGuides.ui.noResults':
    'No guide matches “{query}”. Try another word, or send us a request below.',
  'helpGuides.ui.resultCount': {
    one: '{count} guide found',
    other: '{count} guides found',
  },
  'helpGuides.ui.open': 'Read the guide',
  'helpGuides.ui.back': 'All guides',
  'helpGuides.ui.onThisPage': 'On this page',
  'helpGuides.ui.related': 'Where to do this',
  'helpGuides.ui.notFound': 'This guide doesn’t exist. It may have moved.',
  'helpGuides.ui.contact': 'Didn’t find an answer? Send a support request.',
  'helpGuides.ui.status': 'Service status',
  'helpGuides.ui.statusHelp': 'Check whether Montra is having problems right now.',
  'helpGuides.ui.affordance': 'How this works',
  'helpGuides.ui.affordanceFor': 'How this works: {guide}',
  'helpGuides.ui.topicGuides': 'Guides about {topic}',
  'helpGuides.ui.browseTitle': 'Guides and how-tos',
  'helpGuides.ui.searchAll': 'Search all guides',
  'helpGuides.gettingStarted.title': 'Getting started without a bank link',
  'helpGuides.gettingStarted.summary':
    'Set up accounts, record or import what happens, and plan ahead. Montra never needs your bank login.',
  'helpGuides.gettingStarted.link': 'Add an account',
  'helpGuides.noBank.title': 'Why don’t I see my bank?',
  'helpGuides.noBank.summary':
    'Montra can’t connect to any bank yet. Here’s why, and what to use instead.',
  'helpGuides.noBank.link': 'See connected services',
  'helpGuides.balances.title': 'How balances are calculated',
  'helpGuides.balances.summary':
    'Opening balance plus every counted transaction, with transfers and adjustments kept apart from spending.',
  'helpGuides.balances.link': 'Go to accounts',
  'helpGuides.budgets.title': 'How budgets are calculated',
  'helpGuides.budgets.summary':
    'What counts as spent, how pace and projections work, and how refunds and rollover change a budget.',
  'helpGuides.budgets.link': 'Go to budgets',
  'helpGuides.recurring.title': 'Recurring, bills and subscriptions',
  'helpGuides.recurring.summary':
    'How repeating transactions are scheduled and posted, how bill status works, and how subscription totals and detection are worked out.',
  'helpGuides.recurring.link': 'Go to bills and recurring',
  'helpGuides.goals.title': 'How goals are calculated',
  'helpGuides.goals.summary':
    'What counts as saved, how milestones are reached and what the forecast assumes.',
  'helpGuides.goals.link': 'Go to goals',
  'helpGuides.groupBalances.title': 'How group balances are calculated',
  'helpGuides.groupBalances.summary':
    'Who owes whom: what each person paid, their share, and settlements that were confirmed.',
  'helpGuides.groupBalances.link': 'Go to groups',
  'helpGuides.imports.title': 'Importing statements and fixing a failed import',
  'helpGuides.imports.summary':
    'Upload a statement file, check the columns, review rows and duplicates, and recover when something goes wrong.',
  'helpGuides.imports.link': 'Go to imports',
  'helpGuides.reconciliation.title': 'Reconciling an account',
  'helpGuides.reconciliation.summary':
    'Match statement lines with your transactions and check a balance against your statement.',
  'helpGuides.reconciliation.link': 'Go to accounts',
  'helpGuides.privacy.title': 'Privacy, export and deletion',
  'helpGuides.privacy.summary':
    'Choose optional consents, download a copy of your data, pause your account or delete it.',
  'helpGuides.privacy.link': 'Go to privacy and data',
  'helpGuides.twoStep.title': 'Two-step verification and recovery',
  'helpGuides.twoStep.summary':
    'Protect sign-in with an authenticator app, and keep recovery codes for when your phone isn’t available.',
  'helpGuides.twoStep.link': 'Go to security settings',
  'helpGuides.fairUse.title': 'Fair-use limits',
  'helpGuides.fairUse.summary':
    'The same limits apply to everyone. They keep Montra fast; they are never paid tiers.',
  'helpGuides.fairUse.link': 'See the limits and your usage',
  'helpGuides.troubleshooting.title': 'Troubleshooting sign-in, sync and notifications',
  'helpGuides.troubleshooting.summary':
    'What to check when you can’t sign in, your data looks out of date, or notifications don’t arrive.',
  'helpGuides.troubleshooting.link': 'Go to notification settings',
} as const satisfies Record<string, Message>;

export default messages;
