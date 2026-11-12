import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/insights/data/insights_api.dart';
import 'package:montra_mobile/features/notifications/application/unread_count.dart';
import 'package:montra_mobile/features/notifications/data/notifications_api.dart';
import 'package:montra_mobile/features/notifications/presentation/notification_bell.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/insights_feature_fakes.dart';
import '../../helpers/notifications_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/test_app.dart';

void main() {
  late MockNotificationsApi api;
  late MockPreferencesApi prefs;
  late MockInsightsApi insights;

  setUpAll(() {
    registerFinanceFallbacks();
    registerNotificationFallbacks();
  });

  setUp(() {
    api = MockNotificationsApi();
    prefs = MockPreferencesApi();
    insights = MockInsightsApi();
    when(() => api.unreadCount()).thenAnswer((_) async => 1);
    when(() => prefs.preferences()).thenAnswer((_) async => preferences());
    when(() => insights.mutes()).thenAnswer((_) async => <InsightMuteDto>[]);
  });

  void stubList(List<NotificationDto> items, {String? next}) {
    when(
      () => api.list(
        unread: any(named: 'unread'),
        archived: any(named: 'archived'),
        category: any(named: 'category'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => notificationPage(items, next: next));
  }

  List<Override> overrides() => <Override>[
    notificationsApiProvider.overrideWithValue(api),
    preferencesApiProvider.overrideWithValue(prefs),
    insightsApiProvider.overrideWithValue(insights),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  group('notification center', () {
    testWidgets('lists notifications; opening one marks it read and goes to '
        'its screen', (WidgetTester tester) async {
      final NotificationDto n = notification(
        title: 'Muted kinds changed',
        body: 'Plain <b>text</b> body',
        deepLink: '/insights/mutes',
        priority: 'high',
      );
      stubList(<NotificationDto>[n]);
      when(
        () => api.update('n-1', read: true),
      ).thenAnswer((_) async => notification(readAt: '2026-11-12T07:00:00Z'));
      final GoRouter router = await pump(tester, '/notifications');

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Muted kinds changed'), findsOneWidget);
      // User text is shown as plain text, never as markup.
      expect(find.text('Plain <b>text</b> body'), findsOneWidget);
      expect(find.text('Important'), findsOneWidget);
      expect(find.text('Unread'), findsWidgets);

      await tester.tap(find.text('Muted kinds changed'));
      await tester.pumpAndSettle();
      verify(() => api.update('n-1', read: true)).called(1);
      expect(locationOf(router), '/insights/mutes');
    });

    testWidgets('archive from the menu, then mark everything read', (
      WidgetTester tester,
    ) async {
      stubList(<NotificationDto>[notification(deepLink: null)]);
      when(() => api.update('n-1', archived: true)).thenAnswer(
        (_) async => notification(archivedAt: '2026-11-12T07:00:00Z'),
      );
      when(() => api.unreadCount()).thenAnswer((_) async => 2);
      when(() => api.readAll()).thenAnswer((_) async => 2);
      await pump(tester, '/notifications');

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive').last);
      await tester.pumpAndSettle();
      verify(() => api.update('n-1', archived: true)).called(1);
      expect(find.text('Archived.'), findsOneWidget);

      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();
      verify(() => api.readAll()).called(1);
      expect(find.text('2 notifications marked as read.'), findsOneWidget);
    });

    testWidgets('the unread view and a category ask the server', (
      WidgetTester tester,
    ) async {
      stubList(<NotificationDto>[notification()]);
      await pump(tester, '/notifications');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Unread'));
      await tester.pumpAndSettle();
      verify(
        () => api.list(
          unread: true,
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).called(1);

      await tester.tap(find.text('All topics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bills').last);
      await tester.pumpAndSettle();
      verify(
        () => api.list(
          unread: true,
          category: 'bill',
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });

    testWidgets('a notification with nothing to open only gets marked read', (
      WidgetTester tester,
    ) async {
      stubList(<NotificationDto>[
        notification(deepLink: null, entityType: null, entityId: null),
      ]);
      when(
        () => api.update('n-1', read: true),
      ).thenAnswer((_) async => notification(readAt: '2026-11-12T07:00:00Z'));
      await pump(tester, '/notifications');
      await tester.tap(find.text('New friend request'));
      await tester.pumpAndSettle();
      expect(
        find.text('This notification has nothing more to open.'),
        findsOneWidget,
      );
    });

    testWidgets('error with retry, then the empty state', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(
        () => api.list(
          unread: any(named: 'unread'),
          archived: any(named: 'archived'),
          category: any(named: 'category'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {
        if (calls++ == 0) {
          throw const ApiException(kind: ApiErrorKind.network);
        }
        return notificationPage(<NotificationDto>[]);
      });
      await pump(tester, '/notifications');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No notifications'), findsOneWidget);
    });

    testWidgets('more pages load on request', (WidgetTester tester) async {
      when(
        () => api.list(
          unread: any(named: 'unread'),
          archived: any(named: 'archived'),
          category: any(named: 'category'),
          cursor: null,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async =>
            notificationPage(<NotificationDto>[notification()], next: 'c2'),
      );
      when(
        () => api.list(
          unread: any(named: 'unread'),
          archived: any(named: 'archived'),
          category: any(named: 'category'),
          cursor: 'c2',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => notificationPage(<NotificationDto>[
          notification(id: 'n-2', title: 'Older one'),
        ]),
      );
      await pump(tester, '/notifications');
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Older one'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });
  });

  group('bell', () {
    testWidgets('shows the unread count, and zero when it cannot be read', (
      WidgetTester tester,
    ) async {
      when(() => api.unreadCount()).thenAnswer((_) async => 4);
      await tester.pumpWidget(
        testApp(
          Scaffold(appBar: AppBar(actions: const <Widget>[NotificationBell()])),
          overrides: <Override>[
            ...signedInOverrides(),
            notificationsApiProvider.overrideWithValue(api),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
      expect(
        find.byTooltip('Notifications, 4 unread notifications'),
        findsOneWidget,
      );
    });

    testWidgets('a failed read counts as zero', (WidgetTester tester) async {
      when(() => api.unreadCount())
          .thenThrow(const ApiException(kind: ApiErrorKind.network));
      await tester.pumpWidget(
        testApp(
          Scaffold(appBar: AppBar(actions: const <Widget>[NotificationBell()])),
          overrides: <Override>[
            ...signedInOverrides(),
            notificationsApiProvider.overrideWithValue(api),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(unreadCountRefreshInterval, const Duration(minutes: 2));
    });
  });

  group('notification settings', () {
    testWidgets('categories × channels: a switch sends only that change; '
        'security is always on; push is not set up', (
      WidgetTester tester,
    ) async {
      when(() => api.preferences()).thenAnswer((_) async => preferenceList());
      when(() => api.updatePreferences(any())).thenAnswer(
        (_) async => preferenceList(
          overrides: <String, ({bool enabled, String digest})>{
            'budget|email': (enabled: true, digest: 'immediate'),
          },
        ),
      );
      await pump(tester, '/notifications/settings');

      expect(find.text('Notification settings'), findsOneWidget);
      expect(find.text('Phone notifications are not set up'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Always on'), findsWidgets);
      final Finder securityEmail = find
          .widgetWithText(SwitchListTile, 'Email')
          .first;
      expect(tester.widget<SwitchListTile>(securityEmail).onChanged, isNull);

      await tester.scrollUntilVisible(
        find.text('Budgets'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final Finder budgetCard = find.ancestor(
        of: find.text('Budgets'),
        matching: find.byType(Card),
      );
      final Finder budgetEmail = find.descendant(
        of: budgetCard,
        matching: find.widgetWithText(SwitchListTile, 'Email'),
      );
      await tester.ensureVisible(budgetEmail);
      await tester.pumpAndSettle();
      await tester.tap(budgetEmail);
      await tester.pumpAndSettle();
      final List<PreferencePatch> sent =
          verify(() => api.updatePreferences(captureAny())).captured.single
              as List<PreferencePatch>;
      expect(sent.single.toJson(), <String, Object?>{
        'category': 'budget',
        'channel': 'email',
        'enabled': true,
      });
      expect(find.text('Saved.'), findsOneWidget);
    });

    testWidgets('the email timing of a category sends only the digest', (
      WidgetTester tester,
    ) async {
      final List<PreferenceDto> withBillEmail = preferenceList(
        overrides: <String, ({bool enabled, String digest})>{
          'bill|email': (enabled: true, digest: 'immediate'),
        },
      );
      when(() => api.preferences()).thenAnswer((_) async => withBillEmail);
      when(() => api.updatePreferences(any()))
          .thenAnswer((_) async => withBillEmail);
      await pump(tester, '/notifications/settings');
      await tester.scrollUntilVisible(
        find.text('Bills'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final Finder timing = find.descendant(
        of: find.ancestor(of: find.text('Bills'), matching: find.byType(Card)),
        matching: find.text('When emails arrive'),
      );
      await tester.ensureVisible(timing);
      await tester.pumpAndSettle();
      await tester.tap(timing);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly digest (Mondays)'));
      await tester.pumpAndSettle();
      final List<PreferencePatch> sent =
          verify(() => api.updatePreferences(captureAny())).captured.single
              as List<PreferencePatch>;
      expect(sent.single.toJson(), <String, Object?>{
        'category': 'bill',
        'channel': 'email',
        'digest': 'weekly',
      });
    });

    testWidgets('quiet hours are saved to the account preferences', (
      WidgetTester tester,
    ) async {
      when(() => api.preferences()).thenAnswer((_) async => preferenceList());
      when(() => prefs.updatePreferences(any())).thenAnswer(
        (_) async => PreferencesDto.fromJson(<String, Object?>{
          ...preferences().toJson(),
          'quiet_hours_enabled': true,
        }),
      );
      await pump(tester, '/notifications/settings');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Quiet hours'));
      await tester.pumpAndSettle();
      final PreferencesPatch sent =
          verify(() => prefs.updatePreferences(captureAny())).captured.single
              as PreferencesPatch;
      expect(sent.toJson(), <String, Object?>{'quiet_hours_enabled': true});
      expect(find.text('Starts at'), findsOneWidget);
      expect(find.text('10:00 PM'), findsOneWidget);
    });

    testWidgets('an error offers a retry', (WidgetTester tester) async {
      when(() => api.preferences())
          .thenThrow(const ApiException(kind: ApiErrorKind.network));
      await pump(tester, '/notifications/settings');
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
