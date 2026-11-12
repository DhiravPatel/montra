import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/notifications/application/unread_count.dart';
import 'package:montra_mobile/features/privacy/data/privacy_api.dart';
import 'package:montra_mobile/features/settings/data/limits_api.dart';
import 'package:montra_mobile/features/support/data/support_api.dart';

import '../helpers/router_app.dart';
import '../helpers/support_fakes.dart';

/// Rounds 4–5 entry points: the Insights and Together tabs, the unread
/// badge on Profile, Profile's "You and your data" rows, and the contact
/// link for people who are signed out.
void main() {
  late MockSupportApi support;
  late MockPrivacyApi privacy;
  late MockLimitsApi limitsApi;

  setUpAll(registerSupportFallbacks);

  setUp(() {
    support = MockSupportApi();
    privacy = MockPrivacyApi();
    limitsApi = MockLimitsApi();
    when(() => support.list()).thenAnswer((_) async => <RequestDto>[]);
    when(() => privacy.legal()).thenAnswer((_) async => legalDto());
    when(() => privacy.consents()).thenAnswer((_) async => <ConsentDto>[]);
    when(() => privacy.exports()).thenAnswer((_) async => <ExportDto>[]);
    when(() => privacy.deletion()).thenAnswer((_) async => deletionDto());
    when(() => limitsApi.get()).thenAnswer((_) async => limitsDto());
  });

  List<Override> overrides({int unread = 0}) => <Override>[
    supportApiProvider.overrideWithValue(support),
    privacyApiProvider.overrideWithValue(privacy),
    limitsApiProvider.overrideWithValue(limitsApi),
    unreadNotificationCountProvider.overrideWith((Ref ref) async => unread),
  ];

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    int unread = 0,
  }) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(unread: unread),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  testWidgets('five tabs; unread notifications show on Profile', (
    WidgetTester tester,
  ) async {
    await pump(tester, '/profile', unread: 3);
    final NavigationBar bar = tester.widget(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(5));
    for (final String label in <String>[
      'Home',
      'Transactions',
      'Insights',
      'Together',
      'Profile',
    ]) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(find.byType(Badge), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp('3 unread notifications')),
      findsWidgets,
    );
  });

  testWidgets('at 200% text only the selected tab shows its label', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, '/profile');
    final NavigationBar bar = tester.widget(find.byType(NavigationBar));
    expect(
      bar.labelBehavior,
      NavigationDestinationLabelBehavior.onlyShowSelected,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no badge without unread notifications', (
    WidgetTester tester,
  ) async {
    await pump(tester, '/profile');
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets("Profile's You and your data rows open their screens", (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester, '/profile');
    expect(find.text('You and your data'), findsOneWidget);
    for (final String title in <String>[
      'Notifications',
      'Friends',
      'Connected services',
      'Moderation decisions',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    await tester.tap(find.text('Privacy & data'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/privacy');
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help & support'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/help');
  });

  testWidgets('signed-out people can contact support', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester, '/welcome');
    await tester.tap(find.text('Need help? Contact support'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/contact');
    expect(find.text('Contact support'), findsOneWidget);
  });
}
