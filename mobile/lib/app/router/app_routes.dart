import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';
import 'package:montra_mobile/core/help/help_guide.dart';

/// Route paths. Deep links use the same paths as the web portal so one
/// emailed URL works for both clients.
abstract final class AppRoutes {
  static const String root = '/';
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String checkEmail = '/check-email';
  static const String forgotPassword = '/forgot-password';
  static const String verifyEmail = '/verify-email';
  static const String resetPassword = '/reset-password';

  static const String profile = '/profile';
  static const String security = '/profile/security';
  static const String sessions = '/profile/security/sessions';
  static const String changePassword = '/profile/security/password';
  static const String twoStep = '/profile/security/two-step';

  /// Profile details and photo (`PATCH /me`).
  static const String editProfile = '/profile/edit';

  /// Preferences and accessibility (`PATCH /me/preferences`).
  static const String preferences = '/profile/preferences';

  /// Post-sign-up setup (every step can be skipped).
  static const String onboarding = '/onboarding';

  /// Home tab: the dashboard.
  static const String home = '/home';
  static const String dashboardWidgets = '/home/widgets';

  /// Transactions tab. Accepts the list filters as query parameters
  /// (`from`, `to`, `category_id`, `merchant_id`, `account_id`, …), so the
  /// server's dashboard `drill_down_path` links open directly.
  static const String transactions = '/transactions';
  static const String newTransaction = '/transactions/new';
  static const String newTransfer = '/transactions/transfer';

  /// Accounts and payment methods (opened from Profile and Home).
  static const String accounts = '/accounts';
  static const String newAccount = '/accounts/new';
  static const String paymentMethods = '/payment-methods';
  static const String newPaymentMethod = '/payment-methods/new';

  static String accountDetail(String id) => '/accounts/${_seg(id)}';
  static String editAccount(String id) => '/accounts/${_seg(id)}/edit';
  static String adjustAccount(String id) => '/accounts/${_seg(id)}/adjust';
  static String editPaymentMethod(String id) =>
      '/payment-methods/${_seg(id)}/edit';
  static String transactionDetail(String id) => '/transactions/${_seg(id)}';
  static String editTransaction(String id) => '/transactions/${_seg(id)}/edit';
  static String refundTransaction(String id, {bool reimbursement = false}) =>
      '/transactions/${_seg(id)}/refund'
      '${reimbursement ? '?type=reimbursement' : ''}';
  static String transferDetail(String id) =>
      '/transactions/transfers/${_seg(id)}';

  /// New expense or income, optionally preset to [accountId].
  static String newTransactionOf(String type, {String? accountId}) => Uri(
    path: newTransaction,
    queryParameters: <String, String>{'type': type, 'account_id': ?accountId},
  ).toString();

  // Round 2: organizing (categories, rules, tags, merchants).
  static const String categories = '/categories';
  static const String newCategory = '/categories/new';
  static String editCategory(String id) => '/categories/${_seg(id)}/edit';
  static const String categoryRules = '/category-rules';
  static const String newCategoryRule = '/category-rules/new';
  static String editCategoryRule(String id) =>
      '/category-rules/${_seg(id)}/edit';
  static const String tags = '/tags';
  static const String merchants = '/merchants';
  static String merchantDetail(String id) => '/merchants/${_seg(id)}';
  static String editMerchant(String id) => '/merchants/${_seg(id)}/edit';

  // Round 2: budgets.
  static const String budgets = '/budgets';
  static const String newBudget = '/budgets/new';
  static const String budgetAlerts = '/budget-alerts';
  static String budgetDetail(String id) => '/budgets/${_seg(id)}';
  static String editBudget(String id) => '/budgets/${_seg(id)}/edit';

  // Round 2: recurring rules, bills and the planning calendar.
  static const String recurring = '/recurring';
  static const String newRecurring = '/recurring/new';
  static String recurringDetail(String id) => '/recurring/${_seg(id)}';
  static String editRecurring(String id) => '/recurring/${_seg(id)}/edit';
  static const String bills = '/bills';
  static const String newBill = '/bills/new';
  static String billDetail(String id) => '/bills/${_seg(id)}';
  static String editBill(String id) => '/bills/${_seg(id)}/edit';
  static String payBill(String id) => '/bills/${_seg(id)}/pay';
  static const String calendar = '/calendar';

  // Round 2: subscriptions.
  static const String subscriptions = '/subscriptions';
  static const String newSubscription = '/subscriptions/new';
  static const String subscriptionDetections = '/subscriptions/detections';
  static String subscriptionDetail(String id) => '/subscriptions/${_seg(id)}';
  static String editSubscription(String id) =>
      '/subscriptions/${_seg(id)}/edit';

  // Round 2: goals.
  static const String goals = '/goals';
  static const String newGoal = '/goals/new';
  static String goalDetail(String id) => '/goals/${_seg(id)}';
  static String editGoal(String id) => '/goals/${_seg(id)}/edit';

  // Round 3: receipts (reviewed by hand; nothing is read automatically).
  static const String receipts = '/receipts';

  /// Add receipts from photos and files (several pages or receipts).
  static const String newReceipt = '/receipts/new';
  static String receiptDetail(String id) => '/receipts/${_seg(id)}';
  static String reviewReceipt(String id) => '/receipts/${_seg(id)}/review';
  static String matchReceipt(String id) => '/receipts/${_seg(id)}/match';
  static String recordReceipt(String id) => '/receipts/${_seg(id)}/record';

  // Round 3: statement imports.
  static const String imports = '/imports';
  static const String newImport = '/imports/new';

  /// Import history, optionally for one account.
  static String importsOf({String? accountId}) => Uri(
    path: imports,
    queryParameters: _query(<String, String>{'account_id': ?accountId}),
  ).toString();

  /// The import wizard, optionally starting with [accountId] chosen.
  static String newImportFor({String? accountId}) => Uri(
    path: newImport,
    queryParameters: _query(<String, String>{'account_id': ?accountId}),
  ).toString();
  static String importDetail(String id) => '/imports/${_seg(id)}';
  static String importMapping(String id) => '/imports/${_seg(id)}/mapping';

  /// An import's rows, optionally only those with [status].
  static String importRows(String id, {String? status}) => Uri(
    path: '/imports/${_seg(id)}/rows',
    queryParameters: _query(<String, String>{'status': ?status}),
  ).toString();

  // Round 3: reconciliation (from the account detail screen).
  static String reconcileAccount(String accountId) =>
      '/accounts/${_seg(accountId)}/reconcile';

  /// A new statement balance check, optionally for an import's statement.
  static String newReconciliation(String accountId, {String? importBatchId}) =>
      Uri(
        path: '/accounts/${_seg(accountId)}/reconcile/new',
        queryParameters: _query(<String, String>{
          'import_batch_id': ?importBatchId,
        }),
      ).toString();

  // Round 3: analytics and reports.
  static const String analytics = '/analytics';
  static const String analyticsCompare = '/analytics/compare';

  /// One analytics report (`cash-flow`, `categories`, `expenses`, `income`,
  /// `merchants`, `accounts`, `budgets`, `goals`, `subscriptions`,
  /// `recurring`), with the period and currency in [query].
  static String analyticsReport(
    String report, {
    Map<String, String> query = const <String, String>{},
  }) => Uri(
    path: '/analytics/${_seg(report)}',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
  static const String reports = '/reports';
  static const String newReport = '/reports/new';
  static const String reportSchedules = '/reports/schedules';
  static const String newReportSchedule = '/reports/schedules/new';
  static String reportDetail(String id) => '/reports/${_seg(id)}';

  // Round 3: exchange rates (opened from Profile).
  static const String exchangeRates = '/exchange-rates';
  static const String newExchangeRate = '/exchange-rates/new';
  static const String currencyConverter = '/exchange-rates/convert';

  // Round 4: friends (exact-username search; privacy settings).
  static const String friends = '/friends';
  static const String blockedAndMuted = '/friends/blocked';
  static const String socialSettings = '/friends/settings';

  /// The friends screen opened on one tab (`friends`, `requests`, `find`).
  static String friendsTab(String tab) => Uri(
    path: friends,
    queryParameters: <String, String>{'tab': tab},
  ).toString();

  // Round 4: groups.
  static const String groups = '/groups';
  static const String newGroup = '/groups/new';

  /// Join by link: the invitation token travels in the URL fragment
  /// (`/groups/join#token=…`), never in the path or query.
  static const String joinGroup = '/groups/join';
  static String groupDetail(String id) => '/groups/${_seg(id)}';
  static String groupSettings(String id) => '/groups/${_seg(id)}/settings';
  static String groupActivity(String id) => '/groups/${_seg(id)}/activity';

  // Round 4: group money.
  static String groupExpenses(String id) => '/groups/${_seg(id)}/expenses';
  static String newGroupExpense(String id) =>
      '/groups/${_seg(id)}/expenses/new';
  static String groupExpenseDetail(String id, String expenseId) =>
      '/groups/${_seg(id)}/expenses/${_seg(expenseId)}';
  static String editGroupExpense(String id, String expenseId) =>
      '/groups/${_seg(id)}/expenses/${_seg(expenseId)}/edit';
  static String groupBalances(String id) => '/groups/${_seg(id)}/balances';
  static String groupSettlements(String id) =>
      '/groups/${_seg(id)}/settlements';

  /// Record a settlement, optionally preset from a suggestion.
  static String newGroupSettlement(
    String id, {
    String? payerId,
    String? payeeId,
    String? amount,
  }) => Uri(
    path: '/groups/${_seg(id)}/settlements/new',
    queryParameters: _query(<String, String>{
      'payer': ?payerId,
      'payee': ?payeeId,
      'amount': ?amount,
    }),
  ).toString();
  static String groupSettlementDetail(String id, String settlementId) =>
      '/groups/${_seg(id)}/settlements/${_seg(settlementId)}';
  static String groupRecurring(String id) => '/groups/${_seg(id)}/recurring';
  static String newGroupRecurring(String id) =>
      '/groups/${_seg(id)}/recurring/new';
  static String groupRecurringDetail(String id, String ruleId) =>
      '/groups/${_seg(id)}/recurring/${_seg(ruleId)}';
  static String groupReports(String id) => '/groups/${_seg(id)}/reports';

  // Round 5: communities, posts and challenges.
  static const String communities = '/communities';
  static const String newCommunity = '/communities/new';

  /// Join by link (`/communities/join#token=…`).
  static const String joinCommunity = '/communities/join';

  /// A community by ID or URL name (slug).
  static String communityPage(String ref) => '/communities/${_seg(ref)}';
  static String communitySettings(String ref) =>
      '/communities/${_seg(ref)}/settings';
  static String communityModeration(String ref) =>
      '/communities/${_seg(ref)}/moderation';
  static String communityMembers(String ref) =>
      '/communities/${_seg(ref)}/members';
  static String postDetail(String id) => '/posts/${_seg(id)}';
  static const String challenges = '/challenges';
  static const String newChallenge = '/challenges/new';
  static String challengeDetail(String id) => '/challenges/${_seg(id)}';

  /// A new challenge for group [groupId].
  static String newGroupChallenge(String groupId) => Uri(
    path: newChallenge,
    queryParameters: <String, String>{'group_id': groupId},
  ).toString();
  static String editChallenge(String id) => '/challenges/${_seg(id)}/edit';

  /// Moderation decisions about the signed-in user, their appeals and the
  /// reports they filed.
  static const String myModeration = '/moderation';

  // Round 5: notifications, search, insights and integrations.
  static const String notifications = '/notifications';
  static const String notificationSettings = '/notifications/settings';
  static const String search = '/search';

  /// Insights tab.
  static const String insights = '/insights';
  static const String insightMutes = '/insights/mutes';
  static String insightDetail(String id) => '/insights/${_seg(id)}';
  static const String integrations = '/integrations';

  /// Connected services, offering to connect [accountId].
  static String integrationsFor(String accountId) => Uri(
    path: integrations,
    queryParameters: <String, String>{'account_id': accountId},
  ).toString();

  /// Together tab: friends, groups, communities and challenges.
  static const String together = '/together';

  // Round 5: help, privacy and data.
  static const String help = '/help';
  static const String newSupportRequest = '/help/new';
  static String supportRequestDetail(String id) => '/help/requests/${_seg(id)}';

  /// Help guides, optionally only one topic's (`?topic=`).
  static const String helpGuides = HelpGuide.listPath;
  static String helpGuidesTopic(String topic) => Uri(
    path: helpGuides,
    queryParameters: <String, String>{'topic': topic},
  ).toString();

  /// One help guide.
  static String helpGuide(HelpGuide guide) => guide.path;

  /// Contact form for people who are signed out (public).
  static const String contact = '/contact';
  static const String privacy = '/privacy';

  /// Privacy screen scrolled to a data export (`/settings/privacy?export=`
  /// on the web).
  static String privacyExport(String exportId) => Uri(
    path: privacy,
    queryParameters: <String, String>{'export': exportId},
  ).toString();
  static const String deactivateAccount = '/privacy/deactivate';
  static const String deleteAccount = '/privacy/delete';
  static const String limits = '/limits';

  static String _seg(String id) => Uri.encodeComponent(id);

  /// `Uri(queryParameters: {})` adds a trailing `?`; leave the query out
  /// when every optional value is null.
  static Map<String, String>? _query(Map<String, String> q) =>
      q.isEmpty ? null : q;

  /// Where signed-in users land.
  static const String signedInHome = home;

  /// Only meaningful while signed out.
  static const Set<String> signedOutOnly = <String>{
    welcome,
    signIn,
    signUp,
    checkEmail,
    forgotPassword,
  };

  /// Emailed-link routes, reachable in every auth state.
  static const Set<String> linkRoutes = <String>{verifyEmail, resetPassword};

  /// Public screens, reachable signed in or out (the signed-out contact
  /// form; signed-in users have Help & support).
  static const Set<String> publicRoutes = <String>{contact};

  /// Invitation links that need a signed-in user: a signed-out user is sent
  /// to sign-in with the link as `next`, and lands on it afterwards.
  static const Set<String> joinRoutes = <String>{joinGroup, joinCommunity};

  /// Query parameter carrying where to go after signing in.
  static const String nextParam = 'next';

  /// A safe in-app location from a `next` value: an absolute app path (no
  /// scheme or host, not `//…`) that is not an auth screen (sign-in,
  /// welcome, splash, onboarding, emailed-link screens, …), so following it
  /// can never leave the app or loop back to authentication. Otherwise null.
  static String? safeNext(String? value) {
    if (value == null || !value.startsWith('/') || value.startsWith('//')) {
      return null;
    }
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.hasScheme || uri.hasAuthority) {
      return null;
    }
    if (_notANextTarget.contains(_normalizePath(uri.path))) {
      return null;
    }
    return value;
  }

  /// Screens that are never a `next` destination.
  static const Set<String> _notANextTarget = <String>{
    ...signedOutOnly,
    ...linkRoutes,
    root,
    splash,
    onboarding,
  };

  /// Whether [path] is a screen that needs a signed-in user and is worth
  /// returning to after signing in.
  static bool isProtected(String path) {
    final String p = _normalizePath(path);
    return !_notANextTarget.contains(p) && !publicRoutes.contains(p);
  }

  /// [path] with `next` in its query when [next] is a safe destination
  /// (otherwise [path] unchanged).
  static String withNext(String path, String? next) {
    final String? safe = safeNext(next);
    if (safe == null) {
      return path;
    }
    return Uri(
      path: path,
      queryParameters: <String, String>{nextParam: safe},
    ).toString();
  }

  /// The safe `next` carried by [location], if any.
  static String? nextOf(Uri location) =>
      safeNext(location.queryParameters[nextParam]);

  static String _normalizePath(String path) {
    if (path.isEmpty) {
      return root;
    }
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }
}

/// The auth guard used by the router's top-level `redirect`.
///
/// Returns the location to redirect to, or null to stay on [location].
///
/// A protected location opened while signed out (or while the session is
/// being restored) is kept as `next` and opened after signing in, or after
/// the (skippable) setup for a new account. `next` is always an in-app path
/// and never an auth screen ([AppRoutes.safeNext]).
String? authRedirect(AuthState auth, Uri location) {
  final String path = _normalize(location.path);
  if (AppRoutes.linkRoutes.contains(path) ||
      AppRoutes.publicRoutes.contains(path)) {
    return null;
  }
  // Where to return to: this location when it is a protected screen,
  // otherwise the `next` it already carries (sign-in, splash, …).
  final String? next = AppRoutes.isProtected(path)
      ? AppRoutes.safeNext(_inApp(location))
      : AppRoutes.nextOf(location);
  switch (auth) {
    case AuthRestoring() || AuthRestoreFailed():
      if (path == AppRoutes.splash) {
        return null;
      }
      return AppRoutes.withNext(AppRoutes.splash, next);
    case SignedOut(:final SessionEndReason? reason):
      if (AppRoutes.signedOutOnly.contains(path)) {
        return null;
      }
      // An invitation link needs an account: sign in (or up) first and
      // come back to it. The token stays in the fragment of `next`.
      if (AppRoutes.joinRoutes.contains(path)) {
        return AppRoutes.withNext(AppRoutes.signIn, next);
      }
      // A voluntary sign-out starts over; nothing to return to.
      if (reason == SessionEndReason.signedOut) {
        return AppRoutes.welcome;
      }
      // After an involuntary or account-wide sign-out, go straight to the
      // sign-in form (which explains what happened).
      return AppRoutes.withNext(
        reason != null ? AppRoutes.signIn : AppRoutes.welcome,
        next,
      );
    case SignedIn(:final UserDto user):
      if (AppRoutes.signedOutOnly.contains(path) ||
          path == AppRoutes.splash ||
          path == AppRoutes.root) {
        // New accounts start with the (skippable) setup and continue to
        // the waiting link afterwards.
        if (!user.onboardingCompleted) {
          return AppRoutes.withNext(AppRoutes.onboarding, next);
        }
        return next ?? AppRoutes.signedInHome;
      }
      if (path == AppRoutes.onboarding && user.onboardingCompleted) {
        return next ?? AppRoutes.signedInHome;
      }
      return null;
  }
}

/// [location] as an in-app path with its query and fragment (a full URL
/// opened through an App Link keeps only those parts).
String _inApp(Uri location) => Uri(
  path: location.path.isEmpty ? AppRoutes.root : location.path,
  query: location.hasQuery ? location.query : null,
  fragment: location.hasFragment ? location.fragment : null,
).toString();

String _normalize(String path) {
  if (path.isEmpty) {
    return AppRoutes.root;
  }
  if (path.length > 1 && path.endsWith('/')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}
