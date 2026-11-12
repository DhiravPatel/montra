import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/insights/data/insights_api.dart';
import 'package:montra_mobile/features/integrations/data/integrations_api.dart';
import 'package:montra_mobile/features/notifications/data/notifications_api.dart';
import 'package:montra_mobile/features/search/data/search_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/insights_feature_fakes.dart';
import '../../helpers/integrations_fakes.dart';
import '../../helpers/notifications_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/search_fakes.dart';

/// Notification, integration, search and insight screens at 200 % text in
/// English and Hindi must lay out without overflow.
void main() {
  late MockNotificationsApi notifications;
  late MockPreferencesApi prefs;
  late MockIntegrationsApi integrations;
  late MockAccountsApi accounts;
  late MockSearchApi search;
  late MockInsightsApi insights;

  setUpAll(() {
    registerFinanceFallbacks();
    registerNotificationFallbacks();
    registerInsightFeatureFallbacks();
  });

  setUp(() {
    notifications = MockNotificationsApi();
    prefs = MockPreferencesApi();
    integrations = MockIntegrationsApi();
    accounts = MockAccountsApi();
    search = MockSearchApi();
    insights = MockInsightsApi();
    when(() => notifications.unreadCount()).thenAnswer((_) async => 12);
    when(
      () => notifications.list(
        unread: any(named: 'unread'),
        archived: any(named: 'archived'),
        category: any(named: 'category'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => notificationPage(<NotificationDto>[
        notification(
          title:
              'A rather long notification title about a settlement in a group',
          body: 'A long plain text body that wraps over several lines at large text sizes.',
          category: 'settlement',
          priority: 'critical',
        ),
        notification(id: 'n-2', readAt: '2026-11-12T07:00:00Z'),
      ], next: 'more'),
    );
    when(() => notifications.preferences()).thenAnswer(
      (_) async => preferenceList(
        overrides: <String, ({bool enabled, String digest})>{
          'bill|email': (enabled: true, digest: 'weekly'),
        },
        groupRows: <Map<String, Object?>>[
          <String, Object?>{
            'category': 'group',
            'channel': 'email',
            'enabled': false,
            'digest': 'immediate',
            'locked': false,
            'group_id': 'grp-x',
          },
        ],
      ),
    );
    when(() => prefs.preferences()).thenAnswer(
      (_) async => PreferencesDto.fromJson(<String, Object?>{
        ...preferences().toJson(),
        'quiet_hours_enabled': true,
      }),
    );
    when(() => integrations.overview()).thenAnswer(
      (_) async => overview(
        providers: <Map<String, Object?>>[
          providerJson(),
          providerJson(
            id: 'demo_bank',
            name: 'Demo Bank with a long provider name',
            status: 'available',
            statusReason: null,
          ),
        ],
        connections: <Map<String, Object?>>[
          connectionJson(lastErrorCode: 'consent_expired'),
        ],
      ),
    );
    when(() => integrations.status('conn-1'))
        .thenAnswer((_) async => connectionStatus(status: 'consent_expired'));
    when(() => search.recent()).thenAnswer(
      (_) async => <RecentDto>[recentSearch(query: 'a long recent query text')],
    );
    when(
      () => search.search(
        any(),
        scope: any(named: 'scope'),
        sort: any(named: 'sort'),
        limit: any(named: 'limit'),
        save: any(named: 'save'),
      ),
    ).thenAnswer(
      (_) async => searchResults(
        transactions: <Map<String, Object?>>[transactionHitJson()],
        categories: <Map<String, Object?>>[
          <String, Object?>{
            'id': 'c1',
            'name': 'Entertainment',
            'kind': 'expense',
          },
        ],
        bills: <Map<String, Object?>>[
          <String, Object?>{
            'id': 'b1',
            'name': 'Electricity',
            'kind': 'active',
          },
        ],
        groups: <Map<String, Object?>>[
          <String, Object?>{'id': 'g1', 'name': 'Flat 4B', 'kind': 'roommates'},
        ],
        posts: <Map<String, Object?>>[
          <String, Object?>{
            'id': 'p1',
            'title': 'How do you plan a monthly grocery budget for a family?',
            'community_id': 'cm1',
            'community_name': 'Budgeting together',
            'created_at': '2026-11-01T08:00:00Z',
          },
        ],
        users: <Map<String, Object?>>[
          <String, Object?>{
            'user_id': 'u1',
            'display_name': 'Asha',
            'username': 'asha',
          },
        ],
      ),
    );
    when(
      () => insights.list(
        all: any(named: 'all'),
        kind: any(named: 'kind'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => insightPage(<InsightDto>[
        insight(
          feedback: <String, Object?>{
            'feedback': 'not_helpful',
            'note': 'A note',
            'updated_at': '2026-11-12T07:00:00Z',
          },
        ),
        insight(id: 'ins-2', status: 'snoozed', severity: 'warning'),
      ], next: 'more'),
    );
    when(() => insights.mutes()).thenAnswer(
      (_) async => <InsightMuteDto>[
        insightMute(subtype: 'subscription_price_increase', scope: 'sub-1'),
      ],
    );
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
  });

  List<Override> overrides() => <Override>[
    notificationsApiProvider.overrideWithValue(notifications),
    preferencesApiProvider.overrideWithValue(prefs),
    integrationsApiProvider.overrideWithValue(integrations),
    accountsApiProvider.overrideWithValue(accounts),
    searchApiProvider.overrideWithValue(search),
    insightsApiProvider.overrideWithValue(insights),
  ];

  Future<void> scrollThrough(WidgetTester tester) async {
    for (int i = 0; i < 25; i++) {
      final Finder scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isEmpty) {
        return;
      }
      await tester.drag(scrollables.last, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
  }

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('engage screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final ({Widget app, GoRouter router}) r = routedApp(
        '/notifications',
        overrides: overrides(),
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await scrollThrough(tester);
      expect(tester.takeException(), isNull);

      for (final String location in <String>[
        '/notifications/settings',
        '/integrations',
        '/integrations/connections/conn-1',
        '/insights',
        '/insights/ins-1',
        '/insights/mutes',
        '/search',
      ]) {
        r.router.go(location);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
        await scrollThrough(tester);
        expect(tester.takeException(), isNull, reason: location);
      }

      // Search results.
      await tester.enterText(find.byType(TextField), 'electricity');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await scrollThrough(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
