import type { Message } from '../../types';

/** English `organize` messages (source of truth for their keys). */
const messages = {
  // Round 2: organize (categories, category rules, tags, merchants)
  'organize.subnav.label': 'Organize',
  'organize.subnav.categories': 'Categories',
  'organize.subnav.rules': 'Rules',
  'organize.subnav.tags': 'Tags',
  'organize.subnav.merchants': 'Merchants',
  'organize.archived': 'Archived',
  'organize.showArchived': 'Show archived',
  'organize.actionsFor': 'Actions for {name}',
  'organize.viewTransactions': 'View transactions',
  'organize.transactionCount': { one: '{count} transaction', other: '{count} transactions' },
  'organize.color.label': 'Color',
  'organize.color.help': 'Helps you spot it in lists. The name is always shown too.',
  'organize.color.none': 'No color',
  'organize.color.current': 'Current color',
  'organize.color.teal': 'Teal',
  'organize.color.blue': 'Blue',
  'organize.color.indigo': 'Indigo',
  'organize.color.purple': 'Purple',
  'organize.color.pink': 'Pink',
  'organize.color.red': 'Red',
  'organize.color.orange': 'Orange',
  'organize.color.yellow': 'Yellow',
  'organize.color.green': 'Green',
  'organize.color.gray': 'Gray',
  'organize.categories.title': 'Categories',
  'organize.categories.description':
    'Group your spending and income. Rename the starter categories, add your own, or merge ones you don’t need.',
  'organize.categories.add': 'Add category',
  'organize.categories.merge': 'Merge categories',
  'organize.categories.list.title': 'Your categories',
  'organize.categories.loading': 'Loading categories…',
  'organize.categories.error': 'We couldn’t load your categories',
  'organize.categories.empty.title': 'No categories yet',
  'organize.categories.empty.body':
    'Add categories like “Groceries” or “Salary” to see where your money goes.',
  'organize.categories.notInBudgets': 'Not counted in budgets',
  'organize.categories.subcategories': 'Subcategories of {name}',
  'organize.categories.merged': 'Merged',
  'organize.categories.addSub': 'Add subcategory',
  'organize.categories.notFound': 'That category no longer exists.',
  'organize.categories.changedElsewhere':
    'This category was changed somewhere else. We loaded the latest version; check it and save again.',
  'organize.categories.archive.action': 'Archive',
  'organize.categories.archive.title': 'Archive this category?',
  'organize.categories.archive.body':
    '{name} won’t be offered for new transactions. Past transactions keep it, and you can restore it at any time.',
  'organize.categories.archive.confirm': 'Archive',
  'organize.categories.archive.done': 'Category archived',
  'organize.categories.restore.action': 'Restore',
  'organize.categories.restore.done': 'Category restored',
  'organize.categories.restore.failed': 'We couldn’t restore the category',
  'organize.categories.delete.action': 'Delete',
  'organize.categories.delete.title': 'Delete this category?',
  'organize.categories.delete.body':
    '{name} isn’t used by any transaction, so it can be deleted. This can’t be undone.',
  'organize.categories.delete.confirm': 'Delete',
  'organize.categories.delete.done': 'Category deleted',
  'organize.categories.delete.inUse':
    'This category is still used by other records, such as rules, budgets or bills. Archive it or merge it into another category instead.',
  'organize.categories.create.title': 'Add a category',
  'organize.categories.createSub.title': 'Add a subcategory',
  'organize.categories.create.submit': 'Add category',
  'organize.categories.create.done': 'Category added',
  'organize.categories.edit.title': 'Edit category',
  'organize.categories.edit.done': 'Category updated',
  'organize.categories.form.name': 'Name',
  'organize.categories.form.nameRequired': 'Enter a name.',
  'organize.categories.form.kind': 'Used for',
  'organize.categories.form.parent': 'Parent category',
  'organize.categories.form.parentNone': 'None (top level)',
  'organize.categories.form.parentHelp':
    'Subcategories add detail, like “Fruit” inside “Groceries”. Only one level is possible.',
  'organize.categories.form.parentLocked':
    'This category has subcategories, so it stays at the top level.',
  'organize.categories.form.budgets': 'Count in budgets',
  'organize.categories.form.budgetsHelp':
    'Turn this off for money you only move around, like savings deposits, so budgets count real spending.',
  'organize.categories.form.duplicate': 'A category with this name already exists at this level.',
  'organize.categories.form.depth': 'Subcategories can’t have subcategories of their own.',
  'organize.merge.title': 'Merge categories',
  'organize.merge.description':
    'Move everything from some categories into one, for example when “Food” and “Food & dining” mean the same.',
  'organize.merge.target': 'Keep this category',
  'organize.merge.targetPlaceholder': 'Choose a category',
  'organize.merge.targetRequired': 'Choose the category to keep.',
  'organize.merge.sources': 'Merge these into it',
  'organize.merge.sourcesRequired': 'Choose at least one category to merge.',
  'organize.merge.chooseTargetFirst': 'Choose the category to keep first.',
  'organize.merge.preview': 'Check what will change',
  'organize.merge.previewTitle': 'What will change',
  'organize.merge.previewIntro': 'Merging into {target} moves:',
  'organize.merge.nothing':
    'Nothing uses these categories yet, so only the categories themselves are merged.',
  'organize.merge.affected.transactions': {
    one: '{count} transaction',
    other: '{count} transactions',
  },
  'organize.merge.affected.subcategories': {
    one: '{count} subcategory',
    other: '{count} subcategories',
  },
  'organize.merge.affected.rules': {
    one: '{count} category rule',
    other: '{count} category rules',
  },
  'organize.merge.affected.budget_allocations': {
    one: '{count} budget limit',
    other: '{count} budget limits',
  },
  'organize.merge.affected.recurring_rules': {
    one: '{count} recurring item',
    other: '{count} recurring items',
  },
  'organize.merge.affected.bills': { one: '{count} bill', other: '{count} bills' },
  'organize.merge.affected.subscriptions': {
    one: '{count} subscription',
    other: '{count} subscriptions',
  },
  'organize.merge.affected.merchants': {
    one: '{count} merchant default',
    other: '{count} merchant defaults',
  },
  'organize.merge.affected.other': {
    one: '{count} other linked record',
    other: '{count} other linked records',
  },
  'organize.merge.warning': 'The merged categories are removed and can’t be separated again.',
  'organize.merge.confirm': 'Merge categories',
  'organize.merge.done': 'Categories merged',
  'organize.merge.topLevelOnly':
    'A category with subcategories can only be merged into a top-level category.',
  'organize.merge.notEnough': 'You need at least two active categories to merge.',
  'organize.merge.affected.budget_filters': {
    one: '{count} budget filter (that budget will leave out {target} instead)',
    other: '{count} budget filters (those budgets will leave out {target} instead)',
  },
  'organize.categories.inUse.budget_filters': {
    one: '{count} budget that leaves it out',
    other: '{count} budgets that leave it out',
  },
  'organize.categories.delete.inUseList':
    'This category is still used by {list}. Archive it or merge it into another category instead.',
  'organize.categories.form.duplicateNamed':
    'A category called “{name}” already exists at this level.',
  'organize.categories.form.removeIcon': 'Remove the saved icon',
  'organize.categories.form.removeIconHelp':
    'This category has an icon from the starter set. Removing it doesn’t change its name or color.',
  'organize.errors.category_merged':
    'This category was merged into another one, so it can’t be changed.',
  'organize.errors.category_already_merged':
    'One of these categories was already merged. Close this and check your categories again.',
  'organize.errors.merge_target_inactive': 'Choose an active category to keep.',
  'organize.errors.parent_category_archived':
    'Its parent category is archived. Restore the parent first, or choose another parent.',
  'organize.errors.name_taken': 'The name “{name}” is already used. Choose another name.',
  'organize.errors.name_taken_generic': 'This name is already used. Choose another name.',
} as const satisfies Record<string, Message>;

export default messages;
