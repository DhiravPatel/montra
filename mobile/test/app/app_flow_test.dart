import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/app/app.dart';
import 'package:montra_mobile/app/router/app_router.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/connectivity.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_api.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/credential_store.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/settings/app_preferences.dart';
import 'package:montra_mobile/core/storage/secure_store.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

import '../helpers/dashboard_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/finance_fakes.dart';

class MockAuthApi extends Mock implements AuthApi {}

/// Boots the real app (router, shell, redirects, theme, l10n) with fakes at
/// the network boundary.
void main() {
  late MockAuthApi api;
  late MemorySecureStore secure;
  late FakeConnectivityMonitor connectivity;
  late Future<AuthResult> Function(String refreshToken) refresh;
  late MockDashboardApi dashboard;
  late MockPreferencesApi preferencesApi;
  late MockLabelsApi labels;

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    dashboard = MockDashboardApi();
    preferencesApi = MockPreferencesApi();
    labels = MockLabelsApi();
    when(() => dashboard.summary(any())).thenAnswer((_) async => summary());
    when(() => dashboard.widgets()).thenAnswer((_) async => widgetLayout());
    when(() => dashboard.planning())
        .thenAnswer((_) async => dashboardPlanning(empty: true));
    when(() => preferencesApi.preferences())
        .thenAnswer((_) async => preferences());
    when(() => preferencesApi.onboarding()).thenAnswer(
      (_) async => const OnboardingDto(
        completedSteps: <String>[],
        skippedSteps: <String>[],
      ),
    );
    stubLabels(labels);
    api = MockAuthApi();
    secure = MemorySecureStore();
    connectivity = FakeConnectivityMonitor();
    refresh = (String _) async => throw const ApiException(
      kind: ApiErrorKind.server,
      code: ErrorObjectCode.unauthenticated,
      statusCode: 401,
    );
  });

  tearDown(() => connectivity.dispose());

  Future<ProviderContainer> boot(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [
        appConfigProvider.overrideWithValue(testConfig),
        secureStoreProvider.overrideWithValue(secure),
        connectivityMonitorProvider.overrideWithValue(connectivity),
        authApiProvider.overrideWithValue(api),
        dashboardApiProvider.overrideWithValue(dashboard),
        preferencesApiProvider.overrideWithValue(preferencesApi),
        labelsApiProvider.overrideWithValue(labels),
        sessionTokenManagerProvider.overrideWith(
          (Ref ref) => SessionTokenManager(
            store: ref.watch(credentialStoreProvider),
            refresh: (String token) => refresh(token),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MontraApp()),
    );
    await container.read(authControllerProvider.notifier).restore();
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('without a stored session the welcome screen is shown', (
    WidgetTester tester,
  ) async {
    await boot(tester);
    expect(find.text('Free for everyone'), findsOneWidget);
    expect(find.text('No bank linking needed'), findsOneWidget);

    await tester.ensureVisible(find.text('I already have an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('a new account is restored into the skippable onboarding', (
    WidgetTester tester,
  ) async {
    secure.values[CredentialStore.refreshTokenKey] = 'refresh-1';
    refresh = (String token) async => AuthResult.fromJson(
      authResultJson(access: 'a2', refresh: 'r2', onboardingCompleted: false),
    );
    when(() => api.currentSession()).thenAnswer(
      (Invocation _) async =>
          AuthResult.fromJson(authResultJson(onboardingCompleted: false)),
    );

    await boot(tester);

    expect(find.text('Set up Montra'), findsOneWidget);
    expect(find.text('Skip setup'), findsOneWidget);
    expect(find.text('Step 1 of 6'), findsOneWidget);
  });

  testWidgets('a stored session is restored and lands on Home', (
    WidgetTester tester,
  ) async {
    secure.values[CredentialStore.refreshTokenKey] = 'refresh-1';
    refresh = (String token) async =>
        AuthResult.fromJson(authResultJson(access: 'a2', refresh: 'r2'));
    when(
      () => api.currentSession(),
    ).thenAnswer((Invocation _) async => AuthResult.fromJson(authResultJson()));

    await boot(tester);

    // Home (dashboard) with the bottom navigation.
    expect(find.text('Balances'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Signed in as Asha'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Security'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Security'), findsOneWidget);
    expect(secure.values[CredentialStore.refreshTokenKey], 'r2');

    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    expect(find.text('Devices and sessions'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Two-step verification: Off')),
      findsOneWidget,
    );
  });

  testWidgets('an offline restore keeps credentials and offers a retry', (
    WidgetTester tester,
  ) async {
    secure.values[CredentialStore.refreshTokenKey] = 'refresh-1';
    refresh = (String _) async =>
        throw const ApiException(kind: ApiErrorKind.network);
    await boot(tester);

    expect(find.text("We couldn't reach Montra"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(secure.values[CredentialStore.refreshTokenKey], 'refresh-1');
  });

  testWidgets('an emailed verification link opens and verifies', (
    WidgetTester tester,
  ) async {
    when(() => api.verifyEmail(any())).thenAnswer((Invocation _) async {});
    final ProviderContainer container = await boot(tester);

    container
        .read(routerProvider)
        .go(
          'http://localhost:5173/verify-email#token=Zq7Xp2Lk9Vb4Nm1Rt6Yw3Hs8Df5Gj0Ka2Ce4Ui6Ob8P',
        );
    await tester.pumpAndSettle();

    verify(() => api.verifyEmail('Zq7Xp2Lk9Vb4Nm1Rt6Yw3Hs8Df5Gj0Ka2Ce4Ui6Ob8P'))
        .called(1);
    expect(find.text('Email verified'), findsOneWidget);
  });

  testWidgets('shows an offline banner while disconnected', (
    WidgetTester tester,
  ) async {
    await boot(tester);
    connectivity.set(false);
    await tester.pumpAndSettle();
    expect(
      find.text("You're offline. Changes can't be saved until you reconnect."),
      findsOneWidget,
    );
    connectivity.set(true);
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsNothing);
  });

  testWidgets('signed-out unknown links go to Welcome; signed-in show 404', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await boot(tester);
    final GoRouter router = container.read(routerProvider);
    router.go('/nowhere');
    await tester.pumpAndSettle();
    expect(find.text('Free for everyone'), findsOneWidget);

    secure.values[CredentialStore.refreshTokenKey] = 'refresh-1';
    refresh = (String token) async =>
        AuthResult.fromJson(authResultJson(access: 'a2', refresh: 'r2'));
    when(
      () => api.currentSession(),
    ).thenAnswer((Invocation _) async => AuthResult.fromJson(authResultJson()));
    await container.read(authControllerProvider.notifier).restore();
    await tester.pumpAndSettle();
    router.go('/nowhere');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('a signed-out link to a protected screen opens after sign-in', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await boot(tester);
    final GoRouter router = container.read(routerProvider);
    router.go('/profile/security');
    await tester.pumpAndSettle();
    expect(find.text('Free for everyone'), findsOneWidget);
    expect(router.state.uri.toString(), '/welcome?next=%2Fprofile%2Fsecurity');

    await tester.ensureVisible(find.text('I already have an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(router.state.uri.toString(), '/sign-in?next=%2Fprofile%2Fsecurity');

    // The session starts (as after a successful sign-in): the screen the
    // link pointed at opens instead of Home.
    secure.values[CredentialStore.refreshTokenKey] = 'refresh-1';
    refresh = (String token) async =>
        AuthResult.fromJson(authResultJson(access: 'a2', refresh: 'r2'));
    when(
      () => api.currentSession(),
    ).thenAnswer((Invocation _) async => AuthResult.fromJson(authResultJson()));
    await container.read(authControllerProvider.notifier).restore();
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/profile/security');
  });

  group("the account's preferences apply app wide", () {
    void signedInWith(Map<String, Object?> changes) {
      secure.values[CredentialStore.refreshTokenKey] = 'refresh-1';
      refresh = (String token) async =>
          AuthResult.fromJson(authResultJson(access: 'a2', refresh: 'r2'));
      when(() => api.currentSession()).thenAnswer(
        (Invocation _) async => AuthResult.fromJson(authResultJson()),
      );
      when(() => preferencesApi.preferences()).thenAnswer(
        (_) async => PreferencesDto.fromJson(<String, Object?>{
          ...preferences().toJson(),
          ...changes,
        }),
      );
    }

    testWidgets('reduced motion, high contrast and text size take effect on '
        'top of the device settings', (WidgetTester tester) async {
      signedInWith(<String, Object?>{
        'reduced_motion': true,
        'high_contrast': true,
        'text_scale_percent': 150,
      });
      tester.platformDispatcher.textScaleFactorTestValue = 1.2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final ProviderContainer container = await boot(tester);

      expect(
        container.read(accessibilitySettingsProvider),
        const AccessibilitySettings(
          reducedMotion: true,
          highContrast: true,
          textScalePercent: 150,
        ),
      );
      final BuildContext home = tester.element(find.byType(NavigationBar));
      final MediaQueryData media = MediaQuery.of(home);
      expect(media.disableAnimations, isTrue);
      expect(media.highContrast, isTrue);
      expect(media.textScaler.scale(10), closeTo(10 * 1.2 * 1.5, 0.001));
      expect(
        Theme.of(home).colorScheme.primary,
        AppTheme.light(highContrast: true).colorScheme.primary,
      );
      expect(
        Theme.of(home).colorScheme.primary,
        isNot(AppTheme.light().colorScheme.primary),
      );

      // With reduced motion a new screen is shown without a transition:
      // its first frame already has it fully in place.
      await tester.tap(find.byTooltip('Customize Home'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Customize Home'), findsWidgets);
      final Offset start = tester.getTopLeft(find.text('Customize Home').last);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Customize Home').last), start);
    });

    testWidgets('without them the device settings are kept', (
      WidgetTester tester,
    ) async {
      signedInWith(const <String, Object?>{});
      final ProviderContainer container = await boot(tester);
      expect(
        container.read(accessibilitySettingsProvider),
        const AccessibilitySettings(),
      );
      final MediaQueryData media = MediaQuery.of(
        tester.element(find.byType(NavigationBar)),
      );
      expect(media.disableAnimations, isFalse);
      expect(media.highContrast, isFalse);
      expect(media.textScaler.scale(10), 10);
    });

    testWidgets('a Hindi account locale shows the app in Hindi', (
      WidgetTester tester,
    ) async {
      signedInWith(<String, Object?>{'locale': 'hi-IN'});
      await boot(tester);
      expect(
        Localizations.localeOf(tester.element(find.byType(NavigationBar))),
        const Locale('hi'),
      );
      expect(find.text('प्रोफ़ाइल'), findsOneWidget);
    });
  });
}
