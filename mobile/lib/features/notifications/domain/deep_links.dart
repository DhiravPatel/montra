import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Where a notification opens in the app, or null when it has nothing to
/// open (the notification is still marked read).
///
/// `deep_link` values are the web portal's routes carrying IDs only
/// (`/planning/bills/{id}`, `/groups/{id}/expenses/{expenseId}`,
/// `/settings/privacy?export={id}`, …); they are translated to [AppRoutes].
/// When a link is unknown, `entity_type` / `entity_id` (with `group_id`
/// for group records) are used instead.
String? notificationRoute(NotificationDto notification) {
  final String? link = notification.deepLink;
  final String? fromLink = link == null ? null : appRouteForDeepLink(link);
  return fromLink ??
      routeForEntity(
        notification.entityType,
        notification.entityId,
        groupId: notification.groupId,
      );
}

/// The app route for a web deep link, or null for links the app has no
/// screen for. Query values and the fragment (invitation tokens) are kept
/// where the app route uses them. Only app paths are accepted: links with
/// a scheme or host are ignored.
String? appRouteForDeepLink(String link) {
  final Uri? uri = Uri.tryParse(link.trim());
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/')) {
    return null;
  }
  final List<String> s = <String>[
    for (final String part in uri.pathSegments)
      if (part.isNotEmpty) part,
  ];
  if (s.isEmpty) {
    return null;
  }
  final Map<String, String> q = uri.queryParameters;
  String? at(int index) => s.length > index ? s[index] : null;
  final String? first = at(1);
  switch (s.first) {
    case 'planning':
      final String? record = at(2);
      return switch ((first, record)) {
        ('bills', final String r) => AppRoutes.billDetail(r),
        ('bills', null) => AppRoutes.bills,
        ('recurring', final String r) => AppRoutes.recurringDetail(r),
        ('recurring', null) => AppRoutes.recurring,
        ('subscriptions', final String r) => AppRoutes.subscriptionDetail(r),
        ('subscriptions', null) => AppRoutes.subscriptions,
        ('goals', final String r) => AppRoutes.goalDetail(r),
        ('goals', null) => AppRoutes.goals,
        ('budgets', final String r) => AppRoutes.budgetDetail(r),
        ('budgets', null) => AppRoutes.budgets,
        ('calendar', _) => AppRoutes.calendar,
        _ => null,
      };
    case 'groups':
      if (first == null) {
        return AppRoutes.groups;
      }
      if (first == 'join') {
        return _withFragment(AppRoutes.joinGroup, uri);
      }
      if (first == 'new') {
        return AppRoutes.newGroup;
      }
      final String groupId = first;
      return switch ((at(2), at(3))) {
        (null, _) => AppRoutes.groupDetail(groupId),
        ('settings', _) => AppRoutes.groupSettings(groupId),
        ('activity', _) => AppRoutes.groupActivity(groupId),
        ('balances', _) => AppRoutes.groupBalances(groupId),
        ('reports', _) => AppRoutes.groupReports(groupId),
        ('expenses', null) => AppRoutes.groupExpenses(groupId),
        ('expenses', 'new') => AppRoutes.newGroupExpense(groupId),
        ('expenses', final String e) => AppRoutes.groupExpenseDetail(
          groupId,
          e,
        ),
        ('settlements', null) => AppRoutes.groupSettlements(groupId),
        ('settlements', final String st) => AppRoutes.groupSettlementDetail(
          groupId,
          st,
        ),
        ('recurring', null) => AppRoutes.groupRecurring(groupId),
        ('recurring', final String r) => AppRoutes.groupRecurringDetail(
          groupId,
          r,
        ),
        _ => AppRoutes.groupDetail(groupId),
      };
    case 'communities':
      if (first == null) {
        return AppRoutes.communities;
      }
      if (first == 'join') {
        return _withFragment(AppRoutes.joinCommunity, uri);
      }
      if (first == 'new') {
        return AppRoutes.newCommunity;
      }
      return switch (at(2)) {
        'settings' => AppRoutes.communitySettings(first),
        'moderation' => AppRoutes.communityModeration(first),
        'members' => AppRoutes.communityMembers(first),
        _ => AppRoutes.communityPage(first),
      };
    case 'posts':
      return first == null
          ? AppRoutes.communities
          : AppRoutes.postDetail(first);
    case 'challenges':
      return first == null
          ? AppRoutes.challenges
          : AppRoutes.challengeDetail(first);
    case 'settings':
      final String? export = q['export'];
      return switch (first) {
        'moderation' => AppRoutes.myModeration,
        'privacy' when export != null && export.isNotEmpty =>
          AppRoutes.privacyExport(export),
        'privacy' => AppRoutes.privacy,
        'notifications' => AppRoutes.notificationSettings,
        'integrations' => AppRoutes.integrations,
        'security' => AppRoutes.security,
        'limits' => AppRoutes.limits,
        'exchange-rates' => AppRoutes.exchangeRates,
        _ => AppRoutes.profile,
      };
    case 'help':
      final String? requestId = first == 'requests' ? at(2) : null;
      return requestId == null
          ? AppRoutes.help
          : AppRoutes.supportRequestDetail(requestId);
    case 'reports':
      return switch (first) {
        null => AppRoutes.reports,
        'schedules' => AppRoutes.reportSchedules,
        final String r => AppRoutes.reportDetail(r),
      };
    case 'insights':
      return switch (first) {
        null => AppRoutes.insights,
        'mutes' => AppRoutes.insightMutes,
        final String i => AppRoutes.insightDetail(i),
      };
    case 'friends':
      final String? tab = q['tab'];
      return tab == null || tab.isEmpty
          ? AppRoutes.friends
          : AppRoutes.friendsTab(tab);
    case 'budgets':
      return first == null ? AppRoutes.budgets : AppRoutes.budgetDetail(first);
    case 'goals':
      return first == null ? AppRoutes.goals : AppRoutes.goalDetail(first);
    case 'bills':
      return first == null ? AppRoutes.bills : AppRoutes.billDetail(first);
    case 'recurring':
      return first == null
          ? AppRoutes.recurring
          : AppRoutes.recurringDetail(first);
    case 'subscriptions':
      return first == null
          ? AppRoutes.subscriptions
          : AppRoutes.subscriptionDetail(first);
    case 'transactions':
      if (first == null) {
        return AppRoutes.transactions;
      }
      if (first == 'transfers') {
        final String? transferId = at(2);
        return transferId == null
            ? AppRoutes.transactions
            : AppRoutes.transferDetail(transferId);
      }
      return AppRoutes.transactionDetail(first);
    case 'accounts':
      return first == null
          ? AppRoutes.accounts
          : AppRoutes.accountDetail(first);
    case 'receipts':
      return first == null
          ? AppRoutes.receipts
          : AppRoutes.receiptDetail(first);
    case 'imports':
      return first == null ? AppRoutes.imports : AppRoutes.importDetail(first);
    case 'merchants':
      return first == null
          ? AppRoutes.merchants
          : AppRoutes.merchantDetail(first);
    case 'categories':
      return AppRoutes.categories;
    case 'notifications':
      return first == 'settings'
          ? AppRoutes.notificationSettings
          : AppRoutes.notifications;
    case 'integrations':
      return AppRoutes.integrations;
    case 'search':
      return AppRoutes.search;
    case 'home':
      return AppRoutes.home;
    default:
      return null;
  }
}

/// The app route for a notification's record when its link is unknown.
String? routeForEntity(
  String? entityType,
  String? entityId, {
  String? groupId,
}) {
  if (entityType == null) {
    return null;
  }
  final String? id = entityId == null || entityId.isEmpty ? null : entityId;
  return switch (entityType) {
    'bill' when id != null => AppRoutes.billDetail(id),
    'recurring_rule' when id != null => AppRoutes.recurringDetail(id),
    'subscription' when id != null => AppRoutes.subscriptionDetail(id),
    'subscription_detection' => AppRoutes.subscriptionDetections,
    'goal' when id != null => AppRoutes.goalDetail(id),
    'goal_contribution' => AppRoutes.goals,
    'budget' when id != null => AppRoutes.budgetDetail(id),
    'transaction' when id != null => AppRoutes.transactionDetail(id),
    'transfer' when id != null => AppRoutes.transferDetail(id),
    'account' when id != null => AppRoutes.accountDetail(id),
    'receipt' when id != null => AppRoutes.receiptDetail(id),
    'import_batch' when id != null => AppRoutes.importDetail(id),
    'merchant' when id != null => AppRoutes.merchantDetail(id),
    'category' => AppRoutes.categories,
    'group' when id != null => AppRoutes.groupDetail(id),
    'group_member' || 'group_invitation' || 'group_join_request'
        when groupId != null =>
      AppRoutes.groupSettings(groupId),
    'group_expense' when groupId != null && id != null =>
      AppRoutes.groupExpenseDetail(groupId, id),
    'settlement' when groupId != null && id != null =>
      AppRoutes.groupSettlementDetail(groupId, id),
    'group_recurring_expense' when groupId != null && id != null =>
      AppRoutes.groupRecurringDetail(groupId, id),
    'community' when id != null => AppRoutes.communityPage(id),
    'community_post' when id != null => AppRoutes.postDetail(id),
    'community_member' ||
    'community_invitation' ||
    'community_report' => AppRoutes.communities,
    'challenge' when id != null => AppRoutes.challengeDetail(id),
    'moderation_action' || 'moderation_appeal' => AppRoutes.myModeration,
    'friend_request' => AppRoutes.friendsTab('requests'),
    'connection' || 'user_block' => AppRoutes.friends,
    'support_request' when id != null => AppRoutes.supportRequestDetail(id),
    'data_export' when id != null => AppRoutes.privacyExport(id),
    'data_export' => AppRoutes.privacy,
    'consent' || 'profile' || 'preferences' => AppRoutes.profile,
    'report' when id != null => AppRoutes.reportDetail(id),
    'report' || 'scheduled_report' => AppRoutes.reports,
    'insight' when id != null => AppRoutes.insightDetail(id),
    'integration_connection' => AppRoutes.integrations,
    'fx_rate' => AppRoutes.exchangeRates,
    'account_reconciliation' || 'reconciliation_match' => AppRoutes.accounts,
    _ => null,
  };
}

String _withFragment(String route, Uri uri) =>
    uri.hasFragment && uri.fragment.isNotEmpty
    ? '$route#${uri.fragment}'
    : route;
