import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/app_shell.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/app/router/routes/budget_routes.dart';
import 'package:montra_mobile/app/router/routes/community_routes.dart';
import 'package:montra_mobile/app/router/routes/engagement_routes.dart';
import 'package:montra_mobile/app/router/routes/goal_routes.dart';
import 'package:montra_mobile/app/router/routes/group_money_routes.dart';
import 'package:montra_mobile/app/router/routes/import_routes.dart';
import 'package:montra_mobile/app/router/routes/insight_routes.dart';
import 'package:montra_mobile/app/router/routes/organize_routes.dart';
import 'package:montra_mobile/app/router/routes/planning_routes.dart';
import 'package:montra_mobile/app/router/routes/receipt_routes.dart';
import 'package:montra_mobile/app/router/routes/social_routes.dart';
import 'package:montra_mobile/app/router/routes/subscription_routes.dart';
import 'package:montra_mobile/app/router/routes/support_routes.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/features/accounts/presentation/account_detail_screen.dart';
import 'package:montra_mobile/features/accounts/presentation/account_form_screen.dart';
import 'package:montra_mobile/features/accounts/presentation/accounts_screen.dart';
import 'package:montra_mobile/features/accounts/presentation/adjust_balance_screen.dart';
import 'package:montra_mobile/features/auth/domain/auth_link.dart';
import 'package:montra_mobile/features/auth/presentation/check_email_screen.dart';
import 'package:montra_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:montra_mobile/features/auth/presentation/not_found_screen.dart';
import 'package:montra_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:montra_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:montra_mobile/features/auth/presentation/sign_up_screen.dart';
import 'package:montra_mobile/features/auth/presentation/splash_screen.dart';
import 'package:montra_mobile/features/auth/presentation/verify_email_screen.dart';
import 'package:montra_mobile/features/auth/presentation/welcome_screen.dart';
import 'package:montra_mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:montra_mobile/features/dashboard/presentation/widget_settings_screen.dart';
import 'package:montra_mobile/features/insights/presentation/insights_screen.dart';
import 'package:montra_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:montra_mobile/features/payment_methods/presentation/payment_method_form_screen.dart';
import 'package:montra_mobile/features/payment_methods/presentation/payment_methods_screen.dart';
import 'package:montra_mobile/features/settings/presentation/change_password_screen.dart';
import 'package:montra_mobile/features/settings/presentation/edit_profile_screen.dart';
import 'package:montra_mobile/features/settings/presentation/preferences_screen.dart';
import 'package:montra_mobile/features/settings/presentation/profile_screen.dart';
import 'package:montra_mobile/features/settings/presentation/security_screen.dart';
import 'package:montra_mobile/features/settings/presentation/sessions_screen.dart';
import 'package:montra_mobile/features/settings/presentation/two_step_screen.dart';
import 'package:montra_mobile/features/social/presentation/together_screen.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/refund_screen.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_form_screen.dart';
import 'package:montra_mobile/features/transactions/presentation/transactions_screen.dart';
import 'package:montra_mobile/features/transactions/presentation/transfer_detail_screen.dart';
import 'package:montra_mobile/features/transactions/presentation/transfer_form_screen.dart';

/// The app router. Redirects follow [authRedirect] and re-run whenever the
/// auth state changes.
///
/// Deep links (`/verify-email#token=...`, `/reset-password#token=...`) are
/// accepted in every auth state. `debugLogDiagnostics` stays off because
/// locations can carry tokens.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<AuthState> auth = ValueNotifier<AuthState>(
    ref.read(authControllerProvider),
  );
  ref.listen<AuthState>(
    authControllerProvider,
    (AuthState? previous, AuthState next) => auth.value = next,
  );
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.root,
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) =>
        authRedirect(auth.value, state.uri),
    errorPageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, const NotFoundScreen()),
    routes: buildAppRoutes(),
  );
  ref.onDispose(() {
    router.dispose();
    auth.dispose();
  });
  return router;
});

Page<void> _page(GoRouterState state, Widget child) => routePage(state, child);

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Route table (exposed for tests).
List<RouteBase> buildAppRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.root,
    redirect: (BuildContext context, GoRouterState state) => AppRoutes.splash,
  ),
  GoRoute(
    path: AppRoutes.splash,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, const SplashScreen()),
  ),
  GoRoute(
    path: AppRoutes.welcome,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, WelcomeScreen(next: AppRoutes.nextOf(state.uri))),
  ),
  GoRoute(
    path: AppRoutes.signIn,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, SignInScreen(next: AppRoutes.nextOf(state.uri))),
  ),
  GoRoute(
    path: AppRoutes.signUp,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, SignUpScreen(next: AppRoutes.nextOf(state.uri))),
  ),
  GoRoute(
    path: AppRoutes.checkEmail,
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      CheckEmailScreen(
        email: state.extra is String ? state.extra! as String : null,
        next: AppRoutes.nextOf(state.uri),
      ),
    ),
  ),
  GoRoute(
    path: AppRoutes.forgotPassword,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, const ForgotPasswordScreen()),
  ),
  GoRoute(
    path: AppRoutes.verifyEmail,
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      VerifyEmailScreen(initialToken: AuthLinks.tokenFrom(state.uri)),
    ),
  ),
  GoRoute(
    path: AppRoutes.resetPassword,
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      ResetPasswordScreen(initialToken: AuthLinks.tokenFrom(state.uri)),
    ),
  ),
  GoRoute(
    path: AppRoutes.onboarding,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, OnboardingScreen(next: AppRoutes.nextOf(state.uri))),
  ),
  // Detail and form screens open above the tab bar from any tab. They are
  // declared before the shell so `/transactions/<id>` never reaches the
  // Transactions tab route.
  // Profile forms open above the tab bar (their sheets need the room).
  GoRoute(
    path: AppRoutes.editProfile,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, const EditProfileScreen()),
  ),
  GoRoute(
    path: AppRoutes.preferences,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, const PreferencesScreen()),
  ),
  GoRoute(
    path: AppRoutes.dashboardWidgets,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, const WidgetSettingsScreen()),
  ),
  GoRoute(
    path: AppRoutes.newTransaction,
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      TransactionFormScreen(
        type: state.uri.queryParameters['type'],
        accountId: _nonEmpty(state.uri.queryParameters['account_id']),
      ),
    ),
  ),
  GoRoute(
    path: AppRoutes.newTransfer,
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      TransferFormScreen(
        fromAccountId: _nonEmpty(state.uri.queryParameters['from']),
      ),
    ),
  ),
  GoRoute(
    path: '/transactions/transfers/:transferId',
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      TransferDetailScreen(transferId: state.pathParameters['transferId']!),
    ),
  ),
  GoRoute(
    path: '/transactions/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      TransactionDetailScreen(transactionId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/transactions/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      TransactionFormScreen(transactionId: state.pathParameters['id']),
    ),
  ),
  GoRoute(
    path: '/transactions/:id/refund',
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      RefundScreen(
        transactionId: state.pathParameters['id']!,
        reimbursement: state.uri.queryParameters['type'] == 'reimbursement',
      ),
    ),
  ),
  GoRoute(
    path: AppRoutes.accounts,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, const AccountsScreen()),
  ),
  GoRoute(
    path: AppRoutes.newAccount,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, const AccountFormScreen()),
  ),
  GoRoute(
    path: '/accounts/:accountId',
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      AccountDetailScreen(accountId: state.pathParameters['accountId']!),
    ),
  ),
  GoRoute(
    path: '/accounts/:accountId/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      AccountFormScreen(accountId: state.pathParameters['accountId']),
    ),
  ),
  GoRoute(
    path: '/accounts/:accountId/adjust',
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      AdjustBalanceScreen(accountId: state.pathParameters['accountId']!),
    ),
  ),
  GoRoute(
    path: AppRoutes.paymentMethods,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, const PaymentMethodsScreen()),
  ),
  GoRoute(
    path: AppRoutes.newPaymentMethod,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        _page(state, const PaymentMethodFormScreen()),
  ),
  GoRoute(
    path: '/payment-methods/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => _page(
      state,
      PaymentMethodFormScreen(methodId: state.pathParameters['id']),
    ),
  ),
  ...organizeRoutes(),
  ...budgetRoutes(),
  ...planningRoutes(),
  ...subscriptionRoutes(),
  ...goalRoutes(),
  ...receiptRoutes(),
  ...importRoutes(),
  ...insightRoutes(),
  ...socialRoutes(),
  ...groupMoneyRoutes(),
  ...communityRoutes(),
  ...engagementRoutes(),
  ...supportRoutes(),
  StatefulShellRoute.indexedStack(
    pageBuilder:
        (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => _page(
          state,
          AppShell(
            navigationShell: navigationShell,
            destinations: appDestinations,
          ),
        ),
    // One branch per entry in `appDestinations`, in the same order.
    branches: <StatefulShellBranch>[
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _page(state, const DashboardScreen()),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.transactions,
            pageBuilder: (BuildContext context, GoRouterState state) => _page(
              state,
              TransactionsScreen(
                filter: TransactionFilter.fromQuery(state.uri.queryParameters),
              ),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.insights,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _page(state, const InsightsScreen()),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.together,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _page(state, const TogetherScreen()),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _page(state, const ProfileScreen()),
            routes: <RouteBase>[
              GoRoute(
                path: 'security',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    _page(state, const SecurityScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'sessions',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _page(state, const SessionsScreen()),
                  ),
                  GoRoute(
                    path: 'password',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _page(state, const ChangePasswordScreen()),
                  ),
                  GoRoute(
                    path: 'two-step',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _page(state, const TwoStepScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
