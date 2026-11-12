import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/app/app.dart';
import 'package:montra_mobile/app/router/app_router.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/connectivity.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_api.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/credential_store.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/storage/secure_store.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

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
}
