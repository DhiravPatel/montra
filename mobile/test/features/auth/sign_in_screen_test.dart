import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_api.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/auth/credential_store.dart';
import 'package:montra_mobile/features/auth/presentation/sign_in_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

class MockAuthApi extends Mock implements AuthApi {}

ApiException serverError(
  ErrorObjectCode code, {
  int status = 400,
  List<Detail> details = const <Detail>[],
  Duration? retryAfter,
}) => ApiException(
  kind: ApiErrorKind.server,
  code: code,
  statusCode: status,
  message: 'Server message',
  details: details,
  requestId: 'req-1',
  retryAfter: retryAfter,
);

void main() {
  late MockAuthApi api;
  late MemorySecureStore secure;

  setUpAll(() {
    registerFallbackValue(const LoginBody(email: '', password: ''));
    registerFallbackValue(const MfaVerifyBody(mfaToken: ''));
  });

  setUp(() {
    api = MockAuthApi();
    secure = MemorySecureStore();
  });

  Future<void> pumpSignIn(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        const SignInScreen(),
        secureStore: secure,
        overrides: [authApiProvider.overrideWithValue(api)],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterCredentials(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(SignInScreen.emailKey),
      'asha@example.com',
    );
    await tester.enterText(
      find.byKey(SignInScreen.passwordKey),
      'correct horse battery',
    );
  }

  AuthState authState(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SignInScreen)))
          .read(authControllerProvider);

  testWidgets('validates required fields before calling the API', (
    WidgetTester tester,
  ) async {
    await pumpSignIn(tester);
    await tester.tap(find.byKey(SignInScreen.submitKey));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    verifyNever(() => api.login(any()));
  });

  testWidgets('shows server field errors next to the matching field', (
    WidgetTester tester,
  ) async {
    when(() => api.login(any())).thenThrow(
      serverError(
        ErrorObjectCode.validationError,
        status: 422,
        details: const <Detail>[
          Detail(field: 'body.email', message: 'Enter a valid email address.'),
        ],
      ),
    );
    await pumpSignIn(tester);
    await enterCredentials(tester);
    await tester.tap(find.byKey(SignInScreen.submitKey));
    await tester.pumpAndSettle();

    final Finder emailError = find.descendant(
      of: find.byKey(SignInScreen.emailKey),
      matching: find.text('Enter a valid email address.'),
    );
    expect(emailError, findsOneWidget);
  });

  testWidgets('shows a generic message for wrong credentials', (
    WidgetTester tester,
  ) async {
    when(() => api.login(any()))
        .thenThrow(serverError(ErrorObjectCode.unauthenticated, status: 401));
    await pumpSignIn(tester);
    await enterCredentials(tester);
    await tester.tap(find.byKey(SignInScreen.submitKey));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(authState(tester), isA<AuthRestoring>());
  });

  testWidgets('completes sign-in through the two-step verification step', (
    WidgetTester tester,
  ) async {
    when(() => api.login(any())).thenAnswer(
      (Invocation _) async => const AuthResult(
        status: AuthResultStatus.mfaRequired,
        mfaToken: 'mfa-token-123',
      ),
    );
    when(() => api.verifyMfa(any())).thenAnswer(
      (Invocation _) async => AuthResult.fromJson(
        authResultJson(access: 'access-mfa', refresh: 'refresh-mfa'),
      ),
    );
    await pumpSignIn(tester);
    await enterCredentials(tester);
    await tester.tap(find.byKey(SignInScreen.submitKey));
    await tester.pumpAndSettle();

    // Second step is visible and the password left the form.
    expect(
      find.text('Enter the 6-digit code from your authenticator app.'),
      findsOneWidget,
    );
    expect(find.byKey(SignInScreen.codeKey), findsOneWidget);
    expect(find.byKey(SignInScreen.passwordKey), findsNothing);

    // Client-side validation of the code.
    await tester.enterText(find.byKey(SignInScreen.codeKey), '12');
    await tester.tap(find.byKey(SignInScreen.verifyKey));
    await tester.pumpAndSettle();
    expect(find.text('The code is 6 digits.'), findsOneWidget);
    verifyNever(() => api.verifyMfa(any()));

    await tester.enterText(find.byKey(SignInScreen.codeKey), '123456');
    await tester.tap(find.byKey(SignInScreen.verifyKey));
    await tester.pumpAndSettle();

    final MfaVerifyBody sent =
        verify(() => api.verifyMfa(captureAny())).captured.single
            as MfaVerifyBody;
    expect(sent.mfaToken, 'mfa-token-123');
    expect(sent.code, '123456');
    expect(sent.recoveryCode, isNull);
    expect(sent.deviceName, 'Google Pixel 8');

    final AuthState state = authState(tester);
    expect(state, isA<SignedIn>());
    expect((state as SignedIn).user.displayName, 'Asha');
    // Only the refresh token was persisted.
    expect(secure.values, <String, String>{
      CredentialStore.refreshTokenKey: 'refresh-mfa',
    });
  });

  Future<void> reachMfaStep(WidgetTester tester) async {
    when(() => api.login(any())).thenAnswer(
      (Invocation _) async => const AuthResult(
        status: AuthResultStatus.mfaRequired,
        mfaToken: 'mfa-token-123',
      ),
    );
    await pumpSignIn(tester);
    await enterCredentials(tester);
    await tester.tap(find.byKey(SignInScreen.submitKey));
    await tester.pumpAndSettle();
  }

  testWidgets('MFA_CODE_INVALID lets the user retry the same challenge', (
    WidgetTester tester,
  ) async {
    int attempts = 0;
    when(() => api.verifyMfa(any())).thenAnswer((Invocation _) async {
      attempts++;
      if (attempts == 1) {
        throw serverError(ErrorObjectCode.mfaCodeInvalid, status: 401);
      }
      return AuthResult.fromJson(authResultJson());
    });
    await reachMfaStep(tester);
    await tester.enterText(find.byKey(SignInScreen.codeKey), '000000');
    await tester.tap(find.byKey(SignInScreen.verifyKey));
    await tester.pumpAndSettle();

    // A field error on the code; still on the second step.
    expect(
      find.descendant(
        of: find.byKey(SignInScreen.codeKey),
        matching: find.text(
          "That code didn't work. Check your authenticator app and try again.",
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(SignInScreen.passwordKey), findsNothing);

    await tester.enterText(find.byKey(SignInScreen.codeKey), '123456');
    await tester.tap(find.byKey(SignInScreen.verifyKey));
    await tester.pumpAndSettle();

    final List<Object?> sent = verify(() => api.verifyMfa(captureAny()))
        .captured;
    expect(sent, hasLength(2));
    expect(
      sent.map((Object? b) => (b! as MfaVerifyBody).mfaToken).toSet(),
      <String>{'mfa-token-123'},
    );
    expect(authState(tester), isA<SignedIn>());
  });

  testWidgets('MFA_CHALLENGE_EXPIRED returns to the password step', (
    WidgetTester tester,
  ) async {
    when(
      () => api.verifyMfa(any()),
    ).thenThrow(serverError(ErrorObjectCode.mfaChallengeExpired, status: 401));
    await reachMfaStep(tester);
    await tester.enterText(find.byKey(SignInScreen.codeKey), '123456');
    await tester.tap(find.byKey(SignInScreen.verifyKey));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This sign-in attempt expired. Enter your password to start again.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(SignInScreen.codeKey), findsNothing);
    expect(find.byKey(SignInScreen.passwordKey), findsOneWidget);
    // The email is kept; the password has to be entered again.
    expect(find.text('asha@example.com'), findsOneWidget);
    expect(find.text('correct horse battery'), findsNothing);
    verify(() => api.verifyMfa(any())).called(1);
  });

  testWidgets('offers to resend the verification email', (
    WidgetTester tester,
  ) async {
    when(() => api.login(any()))
        .thenThrow(serverError(ErrorObjectCode.emailNotVerified, status: 403));
    when(() => api.resendVerification(any())).thenAnswer(
      (Invocation _) async => const AcceptedMessage(
        status: AcceptedMessageStatus.accepted,
        message: 'ok',
      ),
    );
    await pumpSignIn(tester);
    await enterCredentials(tester);
    await tester.tap(find.byKey(SignInScreen.submitKey));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email to sign in'), findsOneWidget);
    await tester.tap(find.text('Resend email'));
    await tester.pump();
    verify(() => api.resendVerification('asha@example.com')).called(1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Resend in'), findsOneWidget);
    // Let the cooldown finish so no timer outlives the test.
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('honors Retry-After when sign-in is throttled', (
    WidgetTester tester,
  ) async {
    when(() => api.login(any())).thenThrow(
      serverError(
        ErrorObjectCode.rateLimited,
        status: 429,
        retryAfter: const Duration(seconds: 30),
      ),
    );
    await pumpSignIn(tester);
    await enterCredentials(tester);
    await tester.tap(find.byKey(SignInScreen.submitKey));
    await tester.pump();

    expect(find.text('Try again in 30s'), findsOneWidget);
    expect(
      find.text('Too many attempts. Try again in 30 seconds.'),
      findsOneWidget,
    );
    final FilledButton button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(SignInScreen.submitKey),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('LOGIN_THROTTLED waits for its Retry-After window', (
    WidgetTester tester,
  ) async {
    when(() => api.login(any())).thenThrow(
      serverError(
        ErrorObjectCode.loginThrottled,
        status: 429,
        retryAfter: const Duration(minutes: 15),
      ),
    );
    await pumpSignIn(tester);
    await enterCredentials(tester);
    await tester.tap(find.byKey(SignInScreen.submitKey));
    await tester.pump();

    expect(
      find.text(
        'Too many failed sign-in attempts. Try again in 15 minutes, '
        'or reset your password.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again in 15 min'), findsOneWidget);
    // 15 min - 14 min = 60 s left: still shown in minutes.
    await tester.pump(const Duration(minutes: 14));
    expect(find.text('Try again in 1 min'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Try again in 29s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Sign in'), findsWidgets);
  });
}
