import type { RouteObject } from 'react-router';
import { LandingPage } from '@/features/marketing/pages/LandingPage';
import { NotFoundPage } from '@/features/marketing/pages/NotFoundPage';
import { PrivacyPage } from '@/features/marketing/pages/PrivacyPage';
import { SecurityInfoPage } from '@/features/marketing/pages/SecurityInfoPage';
import { TermsPage } from '@/features/marketing/pages/TermsPage';
import { RouteErrorBoundary } from '../error-boundaries/RouteErrorBoundary';
import { PublicOnlyRoute } from '../guards/PublicOnlyRoute';
import { RequireAuth } from '../guards/RequireAuth';
import { PublicLayout } from '../layouts/PublicLayout';
import { RootLayout } from '../layouts/RootLayout';
import { LegacyRedirect } from './LegacyRedirect';
import { RouteLoading } from './RouteLoading';

/** Data-dense screens use the wider content column (see AppShell). */
const wide = { wide: true } as const;

/**
 * Route tree. Public information pages load eagerly (first-visit entry);
 * forms and the signed-in area are code-split so their dependencies (form
 * validation, dialogs, QR codes) only load when needed.
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
          { path: 'privacy', element: <PrivacyPage /> },
          { path: 'security', element: <SecurityInfoPage /> },
          { path: 'terms', element: <TermsPage /> },
          {
            path: 'verify-email',
            lazy: async () => ({
              Component: (await import('@/features/auth/pages/VerifyEmailPage')).VerifyEmailPage,
            }),
          },
          {
            path: 'forgot-password',
            lazy: async () => ({
              Component: (await import('@/features/auth/pages/ForgotPasswordPage'))
                .ForgotPasswordPage,
            }),
          },
          {
            path: 'unsubscribe',
            lazy: async () => ({
              Component: (await import('@/features/notifications/pages/UnsubscribePage'))
                .UnsubscribePage,
            }),
          },
          {
            path: 'contact',
            lazy: async () => ({
              Component: (await import('@/features/support/pages/ContactPage')).ContactPage,
            }),
          },
          {
            path: 'reset-password',
            lazy: async () => ({
              Component: (await import('@/features/auth/pages/ResetPasswordPage'))
                .ResetPasswordPage,
            }),
          },
          {
            element: <PublicOnlyRoute />,
            children: [
              {
                path: 'sign-in',
                lazy: async () => ({
                  Component: (await import('@/features/auth/pages/SignInPage')).SignInPage,
                }),
              },
              {
                path: 'sign-up',
                lazy: async () => ({
                  Component: (await import('@/features/auth/pages/SignUpPage')).SignUpPage,
                }),
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
            lazy: async () => ({ Component: (await import('../layouts/FocusLayout')).FocusLayout }),
            children: [
              {
                path: 'onboarding',
                lazy: async () => ({
                  Component: (await import('@/features/onboarding/pages/OnboardingPage'))
                    .OnboardingPage,
                }),
              },
            ],
          },
          {
            lazy: async () => ({ Component: (await import('../layouts/AppShell')).AppShell }),
            children: [
              {
                path: 'dashboard',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/dashboard/pages/DashboardPage'))
                    .DashboardPage,
                }),
              },
              {
                path: 'transactions',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/transactions/pages/TransactionsPage'))
                    .TransactionsPage,
                }),
              },
              {
                path: 'transactions/new',
                lazy: async () => ({
                  Component: (await import('@/features/transactions/pages/TransactionCreatePage'))
                    .TransactionCreatePage,
                }),
              },
              {
                path: 'transactions/:transactionId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/transactions/pages/TransactionDetailPage'))
                    .TransactionDetailPage,
                }),
              },
              {
                path: 'transactions/:transactionId/edit',
                lazy: async () => ({
                  Component: (await import('@/features/transactions/pages/TransactionEditPage'))
                    .TransactionEditPage,
                }),
              },
              {
                path: 'transfers/new',
                lazy: async () => ({
                  Component: (await import('@/features/transactions/pages/TransferCreatePage'))
                    .TransferCreatePage,
                }),
              },
              {
                path: 'accounts',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/accounts/pages/AccountsPage')).AccountsPage,
                }),
              },
              {
                path: 'accounts/new',
                lazy: async () => ({
                  Component: (await import('@/features/accounts/pages/AccountCreatePage'))
                    .AccountCreatePage,
                }),
              },
              {
                path: 'accounts/payment-methods',
                lazy: async () => ({
                  Component: (await import('@/features/payment-methods/pages/PaymentMethodsPage'))
                    .PaymentMethodsPage,
                }),
              },
              {
                path: 'accounts/:accountId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/accounts/pages/AccountDetailPage'))
                    .AccountDetailPage,
                }),
              },
              {
                path: 'accounts/:accountId/edit',
                lazy: async () => ({
                  Component: (await import('@/features/accounts/pages/AccountEditPage'))
                    .AccountEditPage,
                }),
              },
              {
                path: 'categories',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/categories/pages/CategoriesPage'))
                    .CategoriesPage,
                }),
              },
              {
                path: 'categories/rules',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/categories/pages/CategoryRulesPage'))
                    .CategoryRulesPage,
                }),
              },
              {
                path: 'categories/tags',
                lazy: async () => ({
                  Component: (await import('@/features/categories/pages/TagsPage')).TagsPage,
                }),
              },
              {
                path: 'categories/merchants',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/categories/pages/MerchantsPage'))
                    .MerchantsPage,
                }),
              },
              {
                path: 'categories/merchants/:merchantId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/categories/pages/MerchantDetailPage'))
                    .MerchantDetailPage,
                }),
              },
              {
                path: 'budgets',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/budgets/pages/BudgetsPage')).BudgetsPage,
                }),
              },
              {
                path: 'budgets/new',
                lazy: async () => ({
                  Component: (await import('@/features/budgets/pages/BudgetCreatePage'))
                    .BudgetCreatePage,
                }),
              },
              {
                path: 'budgets/:budgetId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/budgets/pages/BudgetDetailPage'))
                    .BudgetDetailPage,
                }),
              },
              {
                path: 'budgets/:budgetId/edit',
                lazy: async () => ({
                  Component: (await import('@/features/budgets/pages/BudgetEditPage'))
                    .BudgetEditPage,
                }),
              },
              {
                path: 'planning',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/planning/pages/PlanningCalendarPage'))
                    .PlanningCalendarPage,
                }),
              },
              {
                path: 'planning/bills',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/planning/pages/BillsPage')).BillsPage,
                }),
              },
              {
                path: 'planning/bills/new',
                lazy: async () => ({
                  Component: (await import('@/features/planning/pages/BillCreatePage'))
                    .BillCreatePage,
                }),
              },
              {
                path: 'planning/bills/:billId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/planning/pages/BillDetailPage'))
                    .BillDetailPage,
                }),
              },
              {
                path: 'planning/bills/:billId/edit',
                lazy: async () => ({
                  Component: (await import('@/features/planning/pages/BillEditPage')).BillEditPage,
                }),
              },
              {
                path: 'planning/recurring',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/planning/pages/RecurringRulesPage'))
                    .RecurringRulesPage,
                }),
              },
              {
                path: 'planning/recurring/new',
                lazy: async () => ({
                  Component: (await import('@/features/planning/pages/RecurringRuleCreatePage'))
                    .RecurringRuleCreatePage,
                }),
              },
              {
                path: 'planning/recurring/:ruleId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/planning/pages/RecurringRuleDetailPage'))
                    .RecurringRuleDetailPage,
                }),
              },
              {
                path: 'planning/recurring/:ruleId/edit',
                lazy: async () => ({
                  Component: (await import('@/features/planning/pages/RecurringRuleEditPage'))
                    .RecurringRuleEditPage,
                }),
              },
              {
                path: 'subscriptions',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/subscriptions/pages/SubscriptionsPage'))
                    .SubscriptionsPage,
                }),
              },
              {
                path: 'subscriptions/new',
                lazy: async () => ({
                  Component: (await import('@/features/subscriptions/pages/SubscriptionCreatePage'))
                    .SubscriptionCreatePage,
                }),
              },
              {
                path: 'subscriptions/review',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/subscriptions/pages/SubscriptionReviewPage'))
                    .SubscriptionReviewPage,
                }),
              },
              {
                path: 'subscriptions/:subscriptionId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/subscriptions/pages/SubscriptionDetailPage'))
                    .SubscriptionDetailPage,
                }),
              },
              {
                path: 'subscriptions/:subscriptionId/edit',
                lazy: async () => ({
                  Component: (await import('@/features/subscriptions/pages/SubscriptionEditPage'))
                    .SubscriptionEditPage,
                }),
              },
              {
                path: 'goals',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/goals/pages/GoalsPage')).GoalsPage,
                }),
              },
              {
                path: 'goals/new',
                lazy: async () => ({
                  Component: (await import('@/features/goals/pages/GoalCreatePage')).GoalCreatePage,
                }),
              },
              {
                path: 'goals/:goalId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/goals/pages/GoalDetailPage')).GoalDetailPage,
                }),
              },
              {
                path: 'goals/:goalId/edit',
                lazy: async () => ({
                  Component: (await import('@/features/goals/pages/GoalEditPage')).GoalEditPage,
                }),
              },
              {
                path: 'receipts',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/receipts/pages/ReceiptsPage')).ReceiptsPage,
                }),
              },
              {
                path: 'receipts/:receiptId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/receipts/pages/ReceiptDetailPage'))
                    .ReceiptDetailPage,
                }),
              },
              {
                path: 'imports',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/imports/pages/ImportsPage')).ImportsPage,
                }),
              },
              {
                path: 'imports/new',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/imports/pages/ImportCreatePage'))
                    .ImportCreatePage,
                }),
              },
              {
                path: 'imports/:importId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/imports/pages/ImportDetailPage'))
                    .ImportDetailPage,
                }),
              },
              {
                path: 'accounts/:accountId/reconcile',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/reconciliation/pages/ReconciliationPage'))
                    .ReconciliationPage,
                }),
              },
              {
                path: 'analytics',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/analytics/pages/AnalyticsPage'))
                    .AnalyticsPage,
                }),
              },
              {
                path: 'reports',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/reports/pages/ReportsPage')).ReportsPage,
                }),
              },
              {
                path: 'settings/exchange-rates',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/fx/pages/ExchangeRatesPage'))
                    .ExchangeRatesPage,
                }),
              },
              {
                path: 'friends',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/social/pages/FriendsPage')).FriendsPage,
                }),
              },
              {
                path: 'groups',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/groups/pages/GroupsPage')).GroupsPage,
                }),
              },
              {
                path: 'groups/new',
                lazy: async () => ({
                  Component: (await import('@/features/groups/pages/GroupCreatePage'))
                    .GroupCreatePage,
                }),
              },
              {
                path: 'groups/join',
                lazy: async () => ({
                  Component: (await import('@/features/groups/pages/GroupJoinPage')).GroupJoinPage,
                }),
              },
              {
                path: 'groups/:groupId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/groups/pages/GroupDetailPage'))
                    .GroupDetailPage,
                }),
              },
              {
                path: 'groups/:groupId/settings',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/groups/pages/GroupSettingsPage'))
                    .GroupSettingsPage,
                }),
              },
              {
                path: 'groups/:groupId/expenses',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/group-money/pages/GroupExpensesPage'))
                    .GroupExpensesPage,
                }),
              },
              {
                path: 'groups/:groupId/expenses/new',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/group-money/pages/GroupExpenseCreatePage'))
                    .GroupExpenseCreatePage,
                }),
              },
              {
                path: 'groups/:groupId/expenses/:expenseId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/group-money/pages/GroupExpenseDetailPage'))
                    .GroupExpenseDetailPage,
                }),
              },
              {
                path: 'groups/:groupId/expenses/:expenseId/edit',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/group-money/pages/GroupExpenseEditPage'))
                    .GroupExpenseEditPage,
                }),
              },
              {
                path: 'groups/:groupId/balances',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/group-money/pages/GroupBalancesPage'))
                    .GroupBalancesPage,
                }),
              },
              {
                path: 'groups/:groupId/settlements/:settlementId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/group-money/pages/SettlementDetailPage'))
                    .SettlementDetailPage,
                }),
              },
              {
                path: 'groups/:groupId/recurring',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/group-money/pages/GroupRecurringPage'))
                    .GroupRecurringPage,
                }),
              },
              {
                path: 'groups/:groupId/reports',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/group-money/pages/GroupReportsPage'))
                    .GroupReportsPage,
                }),
              },
              {
                path: 'communities',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/communities/pages/CommunitiesPage'))
                    .CommunitiesPage,
                }),
              },
              {
                path: 'communities/new',
                lazy: async () => ({
                  Component: (await import('@/features/communities/pages/CommunityCreatePage'))
                    .CommunityCreatePage,
                }),
              },
              {
                path: 'communities/join',
                lazy: async () => ({
                  Component: (await import('@/features/communities/pages/CommunityJoinPage'))
                    .CommunityJoinPage,
                }),
              },
              {
                path: 'communities/:communityRef',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/communities/pages/CommunityPage'))
                    .CommunityPage,
                }),
              },
              {
                path: 'communities/:communityRef/settings',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/communities/pages/CommunitySettingsPage'))
                    .CommunitySettingsPage,
                }),
              },
              {
                path: 'communities/:communityRef/moderation',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/communities/pages/CommunityModerationPage'))
                    .CommunityModerationPage,
                }),
              },
              {
                path: 'posts/:postId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/communities/pages/PostPage')).PostPage,
                }),
              },
              {
                path: 'challenges',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/challenges/pages/ChallengesPage'))
                    .ChallengesPage,
                }),
              },
              {
                path: 'challenges/new',
                lazy: async () => ({
                  Component: (await import('@/features/challenges/pages/ChallengeCreatePage'))
                    .ChallengeCreatePage,
                }),
              },
              {
                path: 'challenges/:challengeId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/challenges/pages/ChallengeDetailPage'))
                    .ChallengeDetailPage,
                }),
              },
              {
                path: 'settings/moderation',
                lazy: async () => ({
                  Component: (await import('@/features/moderation/pages/MyModerationPage'))
                    .MyModerationPage,
                }),
              },
              {
                path: 'staff/moderation',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/moderation/pages/PlatformModerationPage'))
                    .PlatformModerationPage,
                }),
              },
              {
                path: 'notifications',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/notifications/pages/NotificationsPage'))
                    .NotificationsPage,
                }),
              },
              {
                path: 'settings/notifications',
                lazy: async () => ({
                  Component: (
                    await import('@/features/notifications/pages/NotificationSettingsPage')
                  ).NotificationSettingsPage,
                }),
              },
              {
                path: 'settings/integrations',
                lazy: async () => ({
                  Component: (await import('@/features/integrations/pages/IntegrationsPage'))
                    .IntegrationsPage,
                }),
              },
              {
                path: 'settings/integrations/:provider/callback',
                lazy: async () => ({
                  Component: (await import('@/features/integrations/pages/IntegrationCallbackPage'))
                    .IntegrationCallbackPage,
                }),
              },
              {
                path: 'search',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/search/pages/SearchPage')).SearchPage,
                }),
              },
              {
                path: 'insights',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/insights/pages/InsightsPage')).InsightsPage,
                }),
              },
              {
                path: 'help',
                lazy: async () => ({
                  Component: (await import('@/features/support/pages/HelpPage')).HelpPage,
                }),
              },
              {
                path: 'help/requests/:requestId',
                lazy: async () => ({
                  Component: (await import('@/features/support/pages/SupportRequestPage'))
                    .SupportRequestPage,
                }),
              },
              {
                path: 'staff/support',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/support/pages/SupportQueuePage'))
                    .SupportQueuePage,
                }),
              },
              {
                path: 'staff/usage',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/admin/pages/AdminUsagePage')).AdminUsagePage,
                }),
              },
              {
                path: 'settings/privacy',
                lazy: async () => ({
                  Component: (await import('@/features/privacy/pages/PrivacySettingsPage'))
                    .PrivacySettingsPage,
                }),
              },
              {
                path: 'settings/limits',
                lazy: async () => ({
                  Component: (await import('@/features/privacy/pages/LimitsPage')).LimitsPage,
                }),
              },
              {
                path: 'insights/:insightId',
                handle: wide,
                lazy: async () => ({
                  Component: (await import('@/features/insights/pages/InsightsPage')).InsightsPage,
                }),
              },
              {
                // The return address providers are given (WEB_APP_URL/integrations/{provider}/callback).
                path: 'integrations/:provider/callback',
                lazy: async () => ({
                  Component: (await import('@/features/integrations/pages/IntegrationCallbackPage'))
                    .IntegrationCallbackPage,
                }),
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
                lazy: async () => ({
                  Component: (await import('@/features/account/pages/AccountOverviewPage'))
                    .AccountOverviewPage,
                }),
              },
              {
                path: 'settings/security',
                lazy: async () => ({
                  Component: (await import('@/features/settings/pages/SecuritySettingsPage'))
                    .SecuritySettingsPage,
                }),
              },
            ],
          },
        ],
      },
    ],
  },
];
