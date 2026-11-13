import type { Message } from '../../types';

/** Help guide text (HELP-001), generated from one source shared with mobile */
const messages = {
  // Help guide text, one key per section title and paragraph or list item
  'helpContent.gettingStarted.how.title': 'How Montra works',
  'helpContent.gettingStarted.how.1':
    'Montra doesn’t connect to your bank. You tell it what happens: you add your accounts, then record transactions as they happen or import a statement your bank gives you. Your numbers are “tracked”, not verified by a bank.',
  'helpContent.gettingStarted.how.2':
    'The first-time setup is optional and you can skip any step after the welcome. Nothing in it asks for bank details.',
  'helpContent.gettingStarted.steps.title': 'First steps',
  'helpContent.gettingStarted.steps.1':
    'Add your accounts: cash, bank, savings, card, wallet, UPI, loan and more. Enter today’s balance as the opening balance (for a card or loan, what you owe).',
  'helpContent.gettingStarted.steps.2':
    'Record expenses and income as they happen, and use a transfer when money moves between your own accounts.',
  'helpContent.gettingStarted.steps.3':
    'To bring in many transactions at once, import a statement file (CSV, XLSX, OFX or QFX). To keep a bill, add a photo of the receipt.',
  'helpContent.gettingStarted.steps.4':
    'Add salary, rent and other repeating money as recurring transactions or bills, so they show on the calendar before they’re due.',
  'helpContent.gettingStarted.steps.5': 'Then set a budget or a savings goal when you’re ready.',
  'helpContent.gettingStarted.accurate.title': 'Keeping it accurate',
  'helpContent.gettingStarted.accurate.1':
    'Now and then, compare a balance with your bank app or statement. If it’s different, reconcile the account or record a balance adjustment with a reason; the adjustment keeps a history and never counts as income or spending.',
  'helpContent.noBank.today.title': 'No bank linking yet',
  'helpContent.noBank.today.1':
    'Montra doesn’t link to any bank today, so no bank appears in the list. The connected services page shows the one option being considered, Account Aggregator (India), as unavailable: it needs an approved partner, registration and a legal review first.',
  'helpContent.noBank.today.2':
    'It isn’t a setting you’ve missed, and it isn’t a paid feature. When a connection becomes available, it will appear on that page.',
  'helpContent.noBank.never.title': 'What Montra will never do',
  'helpContent.noBank.never.1': 'Ask for your bank password, PIN, card number or OTP.',
  'helpContent.noBank.never.2': 'Read your SMS or notifications, or scrape your bank’s website.',
  'helpContent.noBank.never.3': 'Move money or make payments for you.',
  'helpContent.noBank.instead.title': 'What to use instead',
  'helpContent.noBank.instead.1': 'Import the statement file your bank lets you download.',
  'helpContent.noBank.instead.2': 'Add receipts from photos, and turn them into transactions.',
  'helpContent.noBank.instead.3':
    'Set up recurring transactions so regular income and bills record themselves.',
  'helpContent.balances.formula.title': 'The balance',
  'helpContent.balances.formula.1':
    'An account’s balance is its opening balance plus every posted and pending transaction in it. Drafts and deleted (voided) transactions don’t change it. Restoring a deleted transaction counts it again.',
  'helpContent.balances.formula.2':
    'Credit cards and loans are money you owe, so spending on them increases what you owe.',
  'helpContent.balances.notSpending.title': 'What isn’t income or spending',
  'helpContent.balances.notSpending.1':
    'Transfers between your own accounts change both balances but are never income or spending. A transfer fee is recorded as its own expense.',
  'helpContent.balances.notSpending.2':
    'Balance adjustments correct a balance to match reality. They keep a history with your reason and never count as income or spending.',
  'helpContent.balances.notSpending.3': 'Refunds reduce spending instead of counting as income.',
  'helpContent.balances.currencies.title': 'Several currencies',
  'helpContent.balances.currencies.1':
    'Amounts in different currencies are never simply added together. Totals are shown per currency, unless you choose a display currency; then Montra converts them and tells you which rate it used.',
  'helpContent.balances.currencies.2':
    'An account shared with you by your household is read-only for you, and its balance is the owner’s record.',
  'helpContent.budgets.spent.title': 'What counts as spent',
  'helpContent.budgets.spent.1':
    'A budget adds up the expenses in its period that match it: its accounts, categories and merchants, and only in the budget’s currency. Transactions in other currencies aren’t counted; the budget tells you how many were left out.',
  'helpContent.budgets.spent.2': 'Transfers and balance adjustments never count.',
  'helpContent.budgets.spent.3': 'Pending transactions count only if the budget includes pending.',
  'helpContent.budgets.spent.4':
    'Your share of group expenses counts when the budget includes group shares (the default).',
  'helpContent.budgets.refunds.title': 'Refunds',
  'helpContent.budgets.refunds.1':
    'When “refunds restore the budget” is on (the default), refunds and reimbursements are subtracted from what you spent. Spent never goes below zero. When it’s off, refunds don’t change the budget.',
  'helpContent.budgets.pace.title': 'Pace and projection',
  'helpContent.budgets.pace.1':
    'Pace compares what you’ve spent with an even pace through the period: the limit × days passed ÷ days in the period.',
  'helpContent.budgets.pace.2': 'On track: within 10% of the even pace.',
  'helpContent.budgets.pace.3': 'Spending faster than expected: more than 10% above it.',
  'helpContent.budgets.pace.4': 'Spending slower than expected: more than 10% below it.',
  'helpContent.budgets.pace.5': 'Over the limit: you’ve spent more than the limit.',
  'helpContent.budgets.pace.6':
    'The projection is what you’d spend by the end of the period at your current pace. It’s an estimate, not a promise. The daily amount left is what remains ÷ days left.',
  'helpContent.budgets.rollover.title': 'Rollover',
  'helpContent.budgets.rollover.1':
    'Rollover carries money from one period into the next. The carried amount is added to (or taken from) the next period’s limit.',
  'helpContent.budgets.rollover.2': 'Carry unused: what you didn’t spend is added.',
  'helpContent.budgets.rollover.3': 'Carry overspend: what you overspent is taken off.',
  'helpContent.budgets.rollover.4': 'Both: either one, whichever happened.',
  'helpContent.budgets.rollover.5':
    'An optional cap limits how much is carried either way. Budgets with a custom period don’t roll over. Editing a budget applies from the current period onward.',
  'helpContent.budgets.alerts.title': 'Alerts',
  'helpContent.budgets.alerts.1':
    'Each threshold you choose (for example 50%, 80% and 100%) alerts you once per period. A forecast alert warns when your pace would take you over the limit. You can dismiss or snooze alerts, and an empty threshold list turns threshold alerts off.',
  'helpContent.recurring.schedule.title': 'Schedules',
  'helpContent.recurring.schedule.1':
    'Every date is worked out from the start date, so a rule on the 31st lands on 31 January, 28 or 29 February and 31 March. Montra checks schedules about every 15 minutes and catches up after any downtime.',
  'helpContent.recurring.schedule.2':
    'Automatic posting needs a fixed amount and an account, and records exactly one transaction per occurrence. Otherwise you confirm each occurrence, or skip, postpone, change its amount or link a transaction you already recorded.',
  'helpContent.recurring.bills.title': 'Bills',
  'helpContent.recurring.bills.1':
    'A bill’s status comes from its due date and payments: overdue, due today, due soon, upcoming or paid. Mark it paid by linking the real payment (Montra suggests matching transactions) or by recording a new one. Reminders arrive the number of days before that you chose.',
  'helpContent.recurring.subscriptions.title': 'Subscriptions',
  'helpContent.recurring.subscriptions.1':
    'Monthly and yearly totals convert each price to a common cycle: a yearly plan counts as one twelfth of its price per month, and a weekly one as 52 payments a year. Totals are kept separate per currency.',
  'helpContent.recurring.subscriptions.2':
    'Once a day, Montra looks for charges at the same merchant at a regular interval (weekly to yearly) with similar amounts, and shows them for review. You confirm or dismiss each one. Montra never cancels anything for you; it gives you a checklist and records the cancellation once the provider confirms it.',
  'helpContent.goals.saved.title': 'Saved so far',
  'helpContent.goals.saved.1':
    'Saved is the starting amount plus recorded contributions minus recorded withdrawals. Planned contributions don’t count until you record them. A withdrawal can’t be more than what’s saved.',
  'helpContent.goals.saved.2':
    'Linking a contribution to a real transaction marks it verified; one transaction can back only one contribution. In a shared goal, contributions a member hides still count towards progress.',
  'helpContent.goals.milestones.title': 'Milestones',
  'helpContent.goals.milestones.1':
    'Milestones are reached at 25%, 50%, 75% and 100% of the target unless you set your own. Each one notifies the goal’s members once. Reaching the target marks the goal achieved.',
  'helpContent.goals.forecast.title': 'Forecast',
  'helpContent.goals.forecast.1':
    'The forecast shows how much you’d need to add each month (or week) to reach the target by its date, and when you’d reach it at your recent pace: what you saved in the last 90 days. If you planned contributions, it also shows when that plan would finish. It uses exact amounts with no interest or growth.',
  'helpContent.groupBalances.net.title': 'Your net balance',
  'helpContent.groupBalances.net.1':
    'For each person: what they paid, minus their share of the expenses, plus settlements they paid, minus settlements they received. A positive number means others owe them; a negative number means they owe.',
  'helpContent.groupBalances.net.2':
    'Splits (equal, exact amounts, percentages, shares or items) are worked out exactly in the smallest unit of the currency, and any leftover paisa or cent goes to members in a fixed order, so totals always add up.',
  'helpContent.groupBalances.settlements.title': 'Settlements',
  'helpContent.groupBalances.settlements.1':
    'Montra never moves money. When you record that you paid someone, it counts in balances only after they confirm it; until then it shows as pending. Settlement suggestions propose fewer payments that clear the same debts, but they don’t change any record.',
  'helpContent.groupBalances.personal.title': 'Your own spending',
  'helpContent.groupBalances.personal.1':
    'When you record a group payment in your own account, only your share counts as your spending. Expenses in another currency are converted with the rate typed in or Montra’s rate for the expense date.',
  'helpContent.groupBalances.personal.2':
    'The home screen shows only your own net balance in each group. Group members never see your personal accounts or transactions.',
  'helpContent.imports.steps.title': 'How an import works',
  'helpContent.imports.steps.1':
    'Download a statement from your bank as CSV, XLSX, OFX or QFX, and choose the account it belongs to. The statement must be in the account’s currency.',
  'helpContent.imports.steps.2':
    'Check the column mapping: which column is the date, amount or description, the date format and whether spending is shown as negative.',
  'helpContent.imports.steps.3':
    'Review the rows. Rows already imported, and possible duplicates of transactions you entered, are flagged. Correct a value or skip a row.',
  'helpContent.imports.steps.4':
    'Confirm. Montra creates the transactions in the background and notifies you when it’s done.',
  'helpContent.imports.failed.title': 'If the file can’t be read',
  'helpContent.imports.failed.1': 'The import page says why. Common reasons and fixes:',
  'helpContent.imports.failed.2':
    'Unsupported or damaged file: download the statement again as CSV or XLSX and upload that.',
  'helpContent.imports.failed.3':
    'Empty, too many rows or too many columns: split the period into smaller statements. One file can have up to 20,000 rows and 64 columns.',
  'helpContent.imports.failed.4':
    'Currency doesn’t match: choose the account in the statement’s currency, or create one.',
  'helpContent.imports.failed.5':
    'PDF statements: PDFs can’t be read today. Download CSV, XLSX, OFX or QFX instead.',
  'helpContent.imports.rows.title': 'If some rows fail',
  'helpContent.imports.rows.1':
    'Each refused row names the value to fix, such as a date or amount that can’t be read. Correct it in the row and confirm again. If the import finished with errors, retry the failed rows once you’ve fixed them.',
  'helpContent.imports.rows.2':
    'Imported the wrong file or into the wrong account? Undo the import: it deletes the transactions it created, except ones you edited since.',
  'helpContent.reconciliation.matches.title': 'Matching',
  'helpContent.reconciliation.matches.1':
    'After an import, Montra suggests matches: a statement line and the transaction you already entered for it, a pending transaction and its posted version, or a manual entry and an imported one. Each suggestion shows how sure it is and why.',
  'helpContent.reconciliation.matches.2':
    'Confirming a match keeps one record, so nothing is counted twice. You can also match a line by hand with one or more transactions whose amounts add up, and undo a match later.',
  'helpContent.reconciliation.matches.3':
    'Both sides must be money in or both money out, and the amounts must add up exactly.',
  'helpContent.reconciliation.matches.4': 'A transaction can be in only one match.',
  'helpContent.reconciliation.matches.5':
    'A pair more than a week apart is shown without confidence: check it yourself.',
  'helpContent.reconciliation.balance.title': 'Balance check',
  'helpContent.reconciliation.balance.1':
    'Enter the balance on your statement (for a card, the amount owed) and its date. Montra compares it with the account on that date and records whether it balanced. A balanced check is remembered as the last reconciled date.',
  'helpContent.reconciliation.balance.2':
    'If it doesn’t balance, look for missing or duplicate transactions around that date, unconfirmed matches and pending items. If the difference is real, record a balance adjustment with a reason.',
  'helpContent.privacy.consents.title': 'Consents',
  'helpContent.privacy.consents.1':
    'The terms and privacy policy are accepted at sign-up. Everything else (location, notifications, and others) is optional, and you can turn it off at any time. Some choices are only recorded today because the feature they’d enable doesn’t exist yet.',
  'helpContent.privacy.consents.2':
    'Montra’s staff have no default access to your financial data, and logs never contain your amounts, merchants or descriptions.',
  'helpContent.privacy.export.title': 'Download your data',
  'helpContent.privacy.export.1':
    'Ask for an export and confirm it’s you. Montra prepares a ZIP file with your data in the background and notifies you when it’s ready. The download link stays valid for 7 days.',
  'helpContent.privacy.deactivate.title': 'Deactivate',
  'helpContent.privacy.deactivate.1':
    'Deactivating signs you out everywhere and keeps your data. Signing in again reactivates the account.',
  'helpContent.privacy.delete.title': 'Delete your account',
  'helpContent.privacy.delete.1':
    'Deletion starts after a 7-day grace period, and you can cancel it until then. Montra shows what will happen to each group first. When it runs, your personal records and files are deleted, groups you own are handed over or archived, and what you shared in groups and communities stays as “Deleted member”. A confirmation is emailed to you.',
  'helpContent.privacy.delete.2': 'Download an export first if you want to keep a copy.',
  'helpContent.twoStep.setup.title': 'Turning it on',
  'helpContent.twoStep.setup.1':
    'In security settings, choose to turn on two-step verification and confirm your password.',
  'helpContent.twoStep.setup.2':
    'Scan the QR code (or type the key) into an authenticator app, then enter the 6-digit code it shows.',
  'helpContent.twoStep.setup.3':
    'Save the 10 recovery codes somewhere safe and offline. Each code works once.',
  'helpContent.twoStep.signIn.title': 'Signing in',
  'helpContent.twoStep.signIn.1':
    'After your password, enter the current code from the app, or one of your recovery codes. Codes change every 30 seconds and each code can be used only once, so if one is refused, wait for the next.',
  'helpContent.twoStep.signIn.2':
    'Sensitive actions (changing two-step verification, new recovery codes, exporting data, deactivating or deleting the account) ask you to confirm it’s you again if you haven’t in the last few minutes.',
  'helpContent.twoStep.recovery.title': 'Lost your phone?',
  'helpContent.twoStep.recovery.1':
    'Sign in with a recovery code. Then, in security settings, turn two-step verification off and on again to set up your new phone, or create new recovery codes. New codes replace all the old ones.',
  'helpContent.twoStep.recovery.2':
    'Montra staff can’t see your codes or skip the second step for you, so without your app or a recovery code you can’t sign in. Keep the recovery codes safe.',
  'helpContent.twoStep.recovery.3':
    'Montra emails you whenever two-step verification is turned on or off.',
  'helpContent.fairUse.what.title': 'What’s limited',
  'helpContent.fairUse.what.1':
    'Every feature is free, and the limits are the same for every person. The limits page shows the exact values and how much storage you use. The usual defaults are:',
  'helpContent.fairUse.what.2':
    'Storage: 2 GB of files in total, and up to 20 MB per file (some kinds of file have a lower limit).',
  'helpContent.fairUse.what.3': 'Imports: up to 20,000 rows per statement.',
  'helpContent.fairUse.what.4':
    'Open records: 500 recurring rules, 200 bills, 500 subscriptions and 200 goals.',
  'helpContent.fairUse.what.5': 'Support: 10 new requests and 10 messages a day.',
  'helpContent.fairUse.reached.title': 'When you reach a limit',
  'helpContent.fairUse.reached.1':
    'Montra tells you which limit you reached. For open records, archive, end or delete ones you no longer need. For storage, delete files you don’t need. If you’re asked to wait, Montra shows how long; daily caps reset the next day.',
  'helpContent.fairUse.reached.2':
    'Before uploading, Montra makes large photos smaller, so receipts and pictures use less of your storage. PDFs are uploaded as they are.',
  'helpContent.troubleshooting.signIn.title': 'Can’t sign in',
  'helpContent.troubleshooting.signIn.1':
    'New account? Open the link in the verification email first. You can ask for a new link; links expire after 24 hours.',
  'helpContent.troubleshooting.signIn.2':
    'The error doesn’t say whether the email or the password is wrong, to protect accounts. If you’re unsure, reset your password; the reset link works for 1 hour, and only the newest one counts.',
  'helpContent.troubleshooting.signIn.3':
    'After several failed attempts you’ll be asked to wait; the screen shows how long. Resetting your password also works.',
  'helpContent.troubleshooting.signIn.4':
    'Two-step code refused? Make sure your phone sets its time automatically, and wait for a new code. Or use a recovery code.',
  'helpContent.troubleshooting.signIn.5':
    'On the web, Montra needs cookies for this site. Changing or resetting your password signs you out on your other devices.',
  'helpContent.troubleshooting.sync.title': 'Data looks out of date',
  'helpContent.troubleshooting.sync.1':
    'There is no bank sync: Montra shows what you’ve recorded or imported. The web and the app read the same account, so a change on one appears on the other when the screen refreshes. Reload the page, or pull down to refresh in the app.',
  'helpContent.troubleshooting.sync.2':
    'Some figures update in the background a moment after a change: budget progress, imports, recurring occurrences (about every 15 minutes) and subscription suggestions (daily).',
  'helpContent.troubleshooting.sync.3':
    'When your phone is offline, the app shows a banner and changes can’t be saved. Try again when you’re back online: the same save is never recorded twice.',
  'helpContent.troubleshooting.notifications.title': 'Notifications don’t arrive',
  'helpContent.troubleshooting.notifications.1':
    'Check notification settings: each kind of notification can be on or off for in-app, email and browser notifications. Security and account messages are always on.',
  'helpContent.troubleshooting.notifications.2':
    'Quiet hours delay email and push until they end, and a daily or weekly digest collects non-urgent email (sent at 08:00 your time; weekly on Mondays).',
  'helpContent.troubleshooting.notifications.3':
    'Browser notifications need your browser’s permission, and the server must support them; if the option isn’t offered, they aren’t available yet. The phone app doesn’t receive push notifications yet: open the notification centre instead.',
  'helpContent.troubleshooting.notifications.4':
    'No email? Check your spam folder. Using an unsubscribe link turns off only that kind of email.',
  'helpContent.troubleshooting.stillStuck.title': 'Still stuck?',
  'helpContent.troubleshooting.stillStuck.1':
    'Send a support request and include the reference shown with the error, if there was one. Never include card numbers, PINs, OTPs or passwords.',
} as const satisfies Record<string, Message>;

export default messages;
