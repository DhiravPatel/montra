import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/features/notifications/domain/deep_links.dart';

import '../../helpers/notifications_fakes.dart';

void main() {
  group('web deep links map to app routes', () {
    final Map<String, String?> cases = <String, String?>{
      '/planning/bills/b1': AppRoutes.billDetail('b1'),
      '/planning/recurring/r1': AppRoutes.recurringDetail('r1'),
      '/groups': AppRoutes.groups,
      '/groups/g1': AppRoutes.groupDetail('g1'),
      '/groups/g1/settings': AppRoutes.groupSettings('g1'),
      '/groups/g1/recurring': AppRoutes.groupRecurring('g1'),
      '/groups/g1/expenses/e1': AppRoutes.groupExpenseDetail('g1', 'e1'),
      '/groups/g1/settlements/s1': AppRoutes.groupSettlementDetail('g1', 's1'),
      '/communities/c1/settings': AppRoutes.communitySettings('c1'),
      '/communities/c1/moderation': AppRoutes.communityModeration('c1'),
      '/communities/c1': AppRoutes.communityPage('c1'),
      '/posts/p1': AppRoutes.postDetail('p1'),
      '/settings/moderation': AppRoutes.myModeration,
      '/settings/privacy?export=x1': AppRoutes.privacyExport('x1'),
      '/settings/privacy': AppRoutes.privacy,
      '/settings/integrations': AppRoutes.integrations,
      '/settings/security': AppRoutes.security,
      '/help/requests/h1': AppRoutes.supportRequestDetail('h1'),
      '/reports': AppRoutes.reports,
      '/insights/i1': AppRoutes.insightDetail('i1'),
      '/friends?tab=requests': AppRoutes.friendsTab('requests'),
      '/challenges/ch1': AppRoutes.challengeDetail('ch1'),
      '/budgets/bu1': AppRoutes.budgetDetail('bu1'),
      '/goals/go1': AppRoutes.goalDetail('go1'),
      '/transactions/t1': AppRoutes.transactionDetail('t1'),
      '/subscriptions/su1': AppRoutes.subscriptionDetail('su1'),
      '/receipts/re1': AppRoutes.receiptDetail('re1'),
      '/imports/im1': AppRoutes.importDetail('im1'),
      '/groups/join#token=abc': '${AppRoutes.joinGroup}#token=abc',
      '/unknown/place': null,
      'https://evil.example/groups/g1': null,
      '//evil.example/x': null,
      'groups/g1': null,
      '': null,
    };
    for (final MapEntry<String, String?> c in cases.entries) {
      test('${c.key.isEmpty ? '(empty)' : c.key} -> ${c.value}', () {
        expect(appRouteForDeepLink(c.key), c.value);
      });
    }
  });

  test('IDs are encoded and stay IDs', () {
    expect(
      appRouteForDeepLink('/planning/bills/a%2Fb'),
      AppRoutes.billDetail('a/b'),
    );
  });

  test('entity fields are the fallback for unknown links', () {
    expect(
      notificationRoute(
        notification(
          deepLink: '/somewhere/new',
          entityType: 'goal',
          entityId: 'g9',
        ),
      ),
      AppRoutes.goalDetail('g9'),
    );
    expect(
      notificationRoute(
        notification(
          deepLink: null,
          entityType: 'group_expense',
          entityId: 'e2',
          groupId: 'gr1',
        ),
      ),
      AppRoutes.groupExpenseDetail('gr1', 'e2'),
    );
    expect(
      notificationRoute(
        notification(deepLink: null, entityType: 'data_export', entityId: 'x2'),
      ),
      AppRoutes.privacyExport('x2'),
    );
    expect(
      notificationRoute(notification(deepLink: null, entityType: 'weird')),
      isNull,
    );
    expect(notificationRoute(notification()), AppRoutes.friendsTab('requests'));
  });
}
