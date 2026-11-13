import type { RouteObject } from 'react-router';
import { LandingPage } from '@/features/marketing/pages/LandingPage';
import { NotFoundPage } from '@/features/marketing/pages/NotFoundPage';
import { RouteErrorBoundary } from '../error-boundaries/RouteErrorBoundary';
import { PublicOnlyRoute } from '../guards/PublicOnlyRoute';
import { RequireAuth } from '../guards/RequireAuth';
import { PublicLayout } from '../layouts/PublicLayout';
import { RootLayout } from '../layouts/RootLayout';
import { page } from './lazyPage';
import { LegacyRedirect } from './LegacyRedirect';
import { RouteLoading } from './RouteLoading';

/** Data-dense screens use the wider content column (see AppShell). */
const wide = { wide: true } as const;

/**
 * Route tree. The landing and not-found pages load eagerly (first-visit
 * entry); everything else is code-split so its dependencies (form
 * validation, dialogs, QR codes) and its messages only load when needed.
 * `page()` loads a route module together with the message namespaces it
 * uses (routeMessages.gen.ts, from `pnpm i18n:gen`).
 *
 * New features add their routes under the AppShell branch and their
 * navigation entry in app/layouts/navigation.ts. Guided flows without the
 * main navigation (onboarding) use the FocusLayout branch.
 */
export const routes: RouteObject[] = [
  {
    element: <RootLayout />,
    errorElement: <RouteErrorBoundary />,
    hydrateFallbackElement: <RouteLoading />,
    children: [
      {
        element: <PublicLayout />,
        children: [
          { index: true, element: <LandingPage /> },
          { path: 'privacy', lazy: page('@/features/marketing/pages/PrivacyPage', 'PrivacyPage') },
          {
            path: 'security',
            lazy: page('@/features/marketing/pages/SecurityInfoPage', 'SecurityInfoPage'),
          },
          { path: 'terms', lazy: page('@/features/marketing/pages/TermsPage', 'TermsPage') },
          {
            path: 'verify-email',
            lazy: page('@/features/auth/pages/VerifyEmailPage', 'VerifyEmailPage'),
          },
          {
            path: 'forgot-password',
            lazy: page('@/features/auth/pages/ForgotPasswordPage', 'ForgotPasswordPage'),
          },
          {
            path: 'unsubscribe',
            lazy: page('@/features/notifications/pages/UnsubscribePage', 'UnsubscribePage'),
          },
          {
            path: 'contact',
            lazy: page('@/features/support/pages/ContactPage', 'ContactPage'),
          },
          {
            path: 'reset-password',
            lazy: page('@/features/auth/pages/ResetPasswordPage', 'ResetPasswordPage'),
          },
          {
            element: <PublicOnlyRoute />,
            children: [
              {
                path: 'sign-in',
                lazy: page('@/features/auth/pages/SignInPage', 'SignInPage'),
              },
              {
                path: 'sign-up',
                lazy: page('@/features/auth/pages/SignUpPage', 'SignUpPage'),
              },
            ],
          },
          { path: '*', element: <NotFoundPage /> },
        ],
      },
      {
        element: <RequireAuth />,
        children: [
          {
            lazy: page('@/app/layouts/FocusLayout', 'FocusLayout'),
            children: [
              {
                path: 'onboarding',
                lazy: page('@/features/onboarding/pages/OnboardingPage', 'OnboardingPage'),
              },
            ],
          },
          {
            lazy: page('@/app/layouts/AppShell', 'AppShell'),
            children: [
              {
                path: 'dashboard',
                handle: wide,
                lazy: page('@/features/dashboard/pages/DashboardPage', 'DashboardPage'),
              },
              {
                path: 'transactions',
                handle: wide,
                lazy: page('@/features/transactions/pages/TransactionsPage', 'TransactionsPage'),
              },
              {
                path: 'transactions/new',
                lazy: page(
                  '@/features/transactions/pages/TransactionCreatePage',
                  'TransactionCreatePage',
                ),
              },
              {
                path: 'transactions/:transactionId',
                handle: wide,
                lazy: page(
                  '@/features/transactions/pages/TransactionDetailPage',
                  'TransactionDetailPage',
                ),
              },
              {
                path: 'transactions/:transactionId/edit',
                lazy: page(
                  '@/features/transactions/pages/TransactionEditPage',
                  'TransactionEditPage',
                ),
              },
              {
                path: 'transfers/new',
                lazy: page(
                  '@/features/transactions/pages/TransferCreatePage',
                  'TransferCreatePage',
                ),
              },
              {
                path: 'accounts',
                handle: wide,
                lazy: page('@/features/accounts/pages/AccountsPage', 'AccountsPage'),
              },
              {
                path: 'accounts/new',
                lazy: page('@/features/accounts/pages/AccountCreatePage', 'AccountCreatePage'),
              },
              {
                path: 'accounts/payment-methods',
                lazy: page(
                  '@/features/payment-methods/pages/PaymentMethodsPage',
                  'PaymentMethodsPage',
                ),
              },
              {
                path: 'accounts/:accountId',
                handle: wide,
                lazy: page('@/features/accounts/pages/AccountDetailPage', 'AccountDetailPage'),
              },
              {
                path: 'accounts/:accountId/edit',
                lazy: page('@/features/accounts/pages/AccountEditPage', 'AccountEditPage'),
              },
              {
                path: 'categories',
                handle: wide,
                lazy: page('@/features/categories/pages/CategoriesPage', 'CategoriesPage'),
              },
              {
                path: 'categories/rules',
                handle: wide,
                lazy: page('@/features/categories/pages/CategoryRulesPage', 'CategoryRulesPage'),
              },
              {
                path: 'categories/tags',
                lazy: page('@/features/categories/pages/TagsPage', 'TagsPage'),
              },
              {
                path: 'categories/merchants',
                handle: wide,
                lazy: page('@/features/categories/pages/MerchantsPage', 'MerchantsPage'),
              },
              {
                path: 'categories/merchants/:merchantId',
                handle: wide,
                lazy: page('@/features/categories/pages/MerchantDetailPage', 'MerchantDetailPage'),
              },
              {
                path: 'budgets',
                handle: wide,
                lazy: page('@/features/budgets/pages/BudgetsPage', 'BudgetsPage'),
              },
              {
                path: 'budgets/new',
                lazy: page('@/features/budgets/pages/BudgetCreatePage', 'BudgetCreatePage'),
              },
              {
                path: 'budgets/:budgetId',
                handle: wide,
                lazy: page('@/features/budgets/pages/BudgetDetailPage', 'BudgetDetailPage'),
              },
              {
                path: 'budgets/:budgetId/edit',
                lazy: page('@/features/budgets/pages/BudgetEditPage', 'BudgetEditPage'),
              },
              {
                path: 'planning',
                handle: wide,
                lazy: page(
                  '@/features/planning/pages/PlanningCalendarPage',
                  'PlanningCalendarPage',
                ),
              },
              {
                path: 'planning/bills',
                handle: wide,
                lazy: page('@/features/planning/pages/BillsPage', 'BillsPage'),
              },
              {
                path: 'planning/bills/new',
                lazy: page('@/features/planning/pages/BillCreatePage', 'BillCreatePage'),
              },
              {
                path: 'planning/bills/:billId',
                handle: wide,
                lazy: page('@/features/planning/pages/BillDetailPage', 'BillDetailPage'),
              },
              {
                path: 'planning/bills/:billId/edit',
                lazy: page('@/features/planning/pages/BillEditPage', 'BillEditPage'),
              },
              {
                path: 'planning/recurring',
                handle: wide,
                lazy: page('@/features/planning/pages/RecurringRulesPage', 'RecurringRulesPage'),
              },
              {
                path: 'planning/recurring/new',
                lazy: page(
                  '@/features/planning/pages/RecurringRuleCreatePage',
                  'RecurringRuleCreatePage',
                ),
              },
              {
                path: 'planning/recurring/:ruleId',
                handle: wide,
                lazy: page(
                  '@/features/planning/pages/RecurringRuleDetailPage',
                  'RecurringRuleDetailPage',
                ),
              },
              {
                path: 'planning/recurring/:ruleId/edit',
                lazy: page(
                  '@/features/planning/pages/RecurringRuleEditPage',
                  'RecurringRuleEditPage',
                ),
              },
              {
                path: 'subscriptions',
                handle: wide,
                lazy: page('@/features/subscriptions/pages/SubscriptionsPage', 'SubscriptionsPage'),
              },
              {
                path: 'subscriptions/new',
                lazy: page(
                  '@/features/subscriptions/pages/SubscriptionCreatePage',
                  'SubscriptionCreatePage',
                ),
              },
              {
                path: 'subscriptions/review',
                handle: wide,
                lazy: page(
                  '@/features/subscriptions/pages/SubscriptionReviewPage',
                  'SubscriptionReviewPage',
                ),
              },
              {
                path: 'subscriptions/:subscriptionId',
                handle: wide,
                lazy: page(
                  '@/features/subscriptions/pages/SubscriptionDetailPage',
                  'SubscriptionDetailPage',
                ),
              },
              {
                path: 'subscriptions/:subscriptionId/edit',
                lazy: page(
                  '@/features/subscriptions/pages/SubscriptionEditPage',
                  'SubscriptionEditPage',
                ),
              },
              {
                path: 'goals',
                handle: wide,
                lazy: page('@/features/goals/pages/GoalsPage', 'GoalsPage'),
              },
              {
                path: 'goals/new',
                lazy: page('@/features/goals/pages/GoalCreatePage', 'GoalCreatePage'),
              },
              {
                path: 'goals/:goalId',
                handle: wide,
                lazy: page('@/features/goals/pages/GoalDetailPage', 'GoalDetailPage'),
              },
              {
                path: 'goals/:goalId/edit',
                lazy: page('@/features/goals/pages/GoalEditPage', 'GoalEditPage'),
              },
              {
                path: 'receipts',
                handle: wide,
                lazy: page('@/features/receipts/pages/ReceiptsPage', 'ReceiptsPage'),
              },
              {
                path: 'receipts/:receiptId',
                handle: wide,
                lazy: page('@/features/receipts/pages/ReceiptDetailPage', 'ReceiptDetailPage'),
              },
              {
                path: 'imports',
                handle: wide,
                lazy: page('@/features/imports/pages/ImportsPage', 'ImportsPage'),
              },
              {
                path: 'imports/new',
                handle: wide,
                lazy: page('@/features/imports/pages/ImportCreatePage', 'ImportCreatePage'),
              },
              {
                path: 'imports/:importId',
                handle: wide,
                lazy: page('@/features/imports/pages/ImportDetailPage', 'ImportDetailPage'),
              },
              {
                path: 'accounts/:accountId/reconcile',
                handle: wide,
                lazy: page(
                  '@/features/reconciliation/pages/ReconciliationPage',
                  'ReconciliationPage',
                ),
              },
              {
                path: 'analytics',
                handle: wide,
                lazy: page('@/features/analytics/pages/AnalyticsPage', 'AnalyticsPage'),
              },
              {
                path: 'reports',
                handle: wide,
                lazy: page('@/features/reports/pages/ReportsPage', 'ReportsPage'),
              },
              {
                path: 'settings/exchange-rates',
                handle: wide,
                lazy: page('@/features/fx/pages/ExchangeRatesPage', 'ExchangeRatesPage'),
              },
              {
                path: 'friends',
                handle: wide,
                lazy: page('@/features/social/pages/FriendsPage', 'FriendsPage'),
              },
              {
                path: 'groups',
                handle: wide,
                lazy: page('@/features/groups/pages/GroupsPage', 'GroupsPage'),
              },
              {
                path: 'groups/new',
                lazy: page('@/features/groups/pages/GroupCreatePage', 'GroupCreatePage'),
              },
              {
                path: 'groups/join',
                lazy: page('@/features/groups/pages/GroupJoinPage', 'GroupJoinPage'),
              },
              {
                path: 'groups/:groupId',
                handle: wide,
                lazy: page('@/features/groups/pages/GroupDetailPage', 'GroupDetailPage'),
              },
              {
                path: 'groups/:groupId/settings',
                handle: wide,
                lazy: page('@/features/groups/pages/GroupSettingsPage', 'GroupSettingsPage'),
              },
              {
                path: 'groups/:groupId/expenses',
                handle: wide,
                lazy: page('@/features/group-money/pages/GroupExpensesPage', 'GroupExpensesPage'),
              },
              {
                path: 'groups/:groupId/expenses/new',
                handle: wide,
                lazy: page(
                  '@/features/group-money/pages/GroupExpenseCreatePage',
                  'GroupExpenseCreatePage',
                ),
              },
              {
                path: 'groups/:groupId/expenses/:expenseId',
                handle: wide,
                lazy: page(
                  '@/features/group-money/pages/GroupExpenseDetailPage',
                  'GroupExpenseDetailPage',
                ),
              },
              {
                path: 'groups/:groupId/expenses/:expenseId/edit',
                handle: wide,
                lazy: page(
                  '@/features/group-money/pages/GroupExpenseEditPage',
                  'GroupExpenseEditPage',
                ),
              },
              {
                path: 'groups/:groupId/balances',
                handle: wide,
                lazy: page('@/features/group-money/pages/GroupBalancesPage', 'GroupBalancesPage'),
              },
              {
                path: 'groups/:groupId/settlements/:settlementId',
                handle: wide,
                lazy: page(
                  '@/features/group-money/pages/SettlementDetailPage',
                  'SettlementDetailPage',
                ),
              },
              {
                path: 'groups/:groupId/recurring',
                handle: wide,
                lazy: page('@/features/group-money/pages/GroupRecurringPage', 'GroupRecurringPage'),
              },
              {
                path: 'groups/:groupId/reports',
                handle: wide,
                lazy: page('@/features/group-money/pages/GroupReportsPage', 'GroupReportsPage'),
              },
              {
                path: 'communities',
                handle: wide,
                lazy: page('@/features/communities/pages/CommunitiesPage', 'CommunitiesPage'),
              },
              {
                path: 'communities/new',
                lazy: page(
                  '@/features/communities/pages/CommunityCreatePage',
                  'CommunityCreatePage',
                ),
              },
              {
                path: 'communities/join',
                lazy: page('@/features/communities/pages/CommunityJoinPage', 'CommunityJoinPage'),
              },
              {
                path: 'communities/:communityRef',
                handle: wide,
                lazy: page('@/features/communities/pages/CommunityPage', 'CommunityPage'),
              },
              {
                path: 'communities/:communityRef/settings',
                handle: wide,
                lazy: page(
                  '@/features/communities/pages/CommunitySettingsPage',
                  'CommunitySettingsPage',
                ),
              },
              {
                path: 'communities/:communityRef/moderation',
                handle: wide,
                lazy: page(
                  '@/features/communities/pages/CommunityModerationPage',
                  'CommunityModerationPage',
                ),
              },
              {
                path: 'posts/:postId',
                handle: wide,
                lazy: page('@/features/communities/pages/PostPage', 'PostPage'),
              },
              {
                path: 'challenges',
                handle: wide,
                lazy: page('@/features/challenges/pages/ChallengesPage', 'ChallengesPage'),
              },
              {
                path: 'challenges/new',
                lazy: page(
                  '@/features/challenges/pages/ChallengeCreatePage',
                  'ChallengeCreatePage',
                ),
              },
              {
                path: 'challenges/:challengeId',
                handle: wide,
                lazy: page(
                  '@/features/challenges/pages/ChallengeDetailPage',
                  'ChallengeDetailPage',
                ),
              },
              {
                path: 'settings/moderation',
                lazy: page('@/features/moderation/pages/MyModerationPage', 'MyModerationPage'),
              },
              {
                path: 'staff/moderation',
                handle: wide,
                lazy: page(
                  '@/features/moderation/pages/PlatformModerationPage',
                  'PlatformModerationPage',
                ),
              },
              {
                path: 'notifications',
                handle: wide,
                lazy: page('@/features/notifications/pages/NotificationsPage', 'NotificationsPage'),
              },
              {
                path: 'settings/notifications',
                lazy: page(
                  '@/features/notifications/pages/NotificationSettingsPage',
                  'NotificationSettingsPage',
                ),
              },
              {
                path: 'settings/integrations',
                lazy: page('@/features/integrations/pages/IntegrationsPage', 'IntegrationsPage'),
              },
              {
                path: 'settings/integrations/:provider/callback',
                lazy: page(
                  '@/features/integrations/pages/IntegrationCallbackPage',
                  'IntegrationCallbackPage',
                ),
              },
              {
                path: 'search',
                handle: wide,
                lazy: page('@/features/search/pages/SearchPage', 'SearchPage'),
              },
              {
                path: 'insights',
                handle: wide,
                lazy: page('@/features/insights/pages/InsightsPage', 'InsightsPage'),
              },
              {
                path: 'help',
                lazy: page('@/features/support/pages/HelpPage', 'HelpPage'),
              },
              {
                path: 'help/guides',
                lazy: page('@/features/support/pages/GuidesPage', 'GuidesPage'),
              },
              {
                path: 'help/guides/:guideId',
                handle: wide,
                lazy: page('@/features/support/pages/GuidePage', 'GuidePage'),
              },
              {
                path: 'help/requests/:requestId',
                lazy: page('@/features/support/pages/SupportRequestPage', 'SupportRequestPage'),
              },
              {
                path: 'staff/support',
                handle: wide,
                lazy: page('@/features/support/pages/SupportQueuePage', 'SupportQueuePage'),
              },
              {
                path: 'staff/usage',
                handle: wide,
                lazy: page('@/features/admin/pages/AdminUsagePage', 'AdminUsagePage'),
              },
              {
                path: 'staff/jobs',
                handle: wide,
                lazy: page('@/features/admin/pages/AdminJobsPage', 'AdminJobsPage'),
              },
              {
                path: 'staff/jobs/:jobId',
                handle: wide,
                lazy: page('@/features/admin/pages/AdminJobDetailPage', 'AdminJobDetailPage'),
              },
              {
                path: 'settings/privacy',
                lazy: page('@/features/privacy/pages/PrivacySettingsPage', 'PrivacySettingsPage'),
              },
              {
                path: 'settings/limits',
                lazy: page('@/features/privacy/pages/LimitsPage', 'LimitsPage'),
              },
              {
                path: 'insights/:insightId',
                handle: wide,
                lazy: page('@/features/insights/pages/InsightsPage', 'InsightsPage'),
              },
              {
                // The return address providers are given (WEB_APP_URL/integrations/{provider}/callback).
                path: 'integrations/:provider/callback',
                lazy: page(
                  '@/features/integrations/pages/IntegrationCallbackPage',
                  'IntegrationCallbackPage',
                ),
              },
              // App-neutral deep links used in notifications and emails.
              {
                path: 'bills/:billId',
                element: <LegacyRedirect to={(p) => `/planning/bills/${p.billId ?? ''}`} />,
              },
              {
                path: 'recurring/:ruleId',
                element: <LegacyRedirect to={(p) => `/planning/recurring/${p.ruleId ?? ''}`} />,
              },
              { path: 'reports/:reportId', element: <LegacyRedirect to={() => '/reports'} /> },
              {
                path: 'me/moderation',
                element: <LegacyRedirect to={() => '/settings/moderation'} />,
              },
              { path: 'groups/invitations', element: <LegacyRedirect to={() => '/groups'} /> },
              {
                path: 'groups/:groupId/join-requests',
                element: <LegacyRedirect to={(p) => `/groups/${p.groupId ?? ''}/settings`} />,
              },
              {
                path: 'groups/:groupId/recurring-expenses/:ruleId',
                element: <LegacyRedirect to={(p) => `/groups/${p.groupId ?? ''}/recurring`} />,
              },
              {
                path: 'communities/:communityRef/members',
                element: (
                  <LegacyRedirect to={(p) => `/communities/${p.communityRef ?? ''}/settings`} />
                ),
              },
              {
                path: 'account',
                lazy: page('@/features/account/pages/AccountOverviewPage', 'AccountOverviewPage'),
              },
              {
                path: 'settings/profile',
                lazy: page('@/features/settings/pages/ProfileSettingsPage', 'ProfileSettingsPage'),
              },
              { path: 'settings', element: <LegacyRedirect to={() => '/settings/profile'} /> },
              {
                path: 'settings/security',
                lazy: page(
                  '@/features/settings/pages/SecuritySettingsPage',
                  'SecuritySettingsPage',
                ),
              },
            ],
          },
        ],
      },
    ],
  },
];
