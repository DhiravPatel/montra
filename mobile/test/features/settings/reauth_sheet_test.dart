import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_api.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/features/settings/presentation/reauth_sheet.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

class MockAuthApi extends Mock implements AuthApi {}

class _SignedInController extends AuthController {
  _SignedInController({required this.mfaEnabled});

  final bool mfaEnabled;

  @override
  AuthState build() =>
      SignedIn(user: UserDto.fromJson(userJson(mfaEnabled: mfaEnabled)));
}

ApiException server(ErrorObjectCode code) =>
    ApiException(kind: ApiErrorKind.server, code: code, statusCode: 401);

void main() {
  late MockAuthApi api;
  bool? result;

  setUp(() {
    api = MockAuthApi();
    result = null;
  });

  void stubReauth(Future<void> Function() answer) => when(
    () => api.reauthenticate(
      password: any(named: 'password'),
      code: any(named: 'code'),
      recoveryCode: any(named: 'recoveryCode'),
    ),
  ).thenAnswer((Invocation _) => answer());

  Future<void> openSheet(WidgetTester tester, {required bool mfa}) async {
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => result = await ReauthSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: [
          authApiProvider.overrideWithValue(api),
          authControllerProvider.overrideWith(
            () => _SignedInController(mfaEnabled: mfa),
          ),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('two-step users can confirm with a single-use recovery code', (
    WidgetTester tester,
  ) async {
    stubReauth(() async {});
    await openSheet(tester, mfa: true);

    expect(find.byKey(ReauthSheet.codeKey), findsOneWidget);
    await tester.tap(find.text('Use a recovery code instead'));
    await tester.pumpAndSettle();
    expect(find.byKey(ReauthSheet.codeKey), findsNothing);
    expect(
      find.text(
        'For your security, enter your password and one of your unused '
        'recovery codes to continue.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(ReauthSheet.passwordKey), 'my password');
    await tester.enterText(
      find.byKey(ReauthSheet.recoveryCodeKey),
      'abcde-fghjk',
    );
    await tester.tap(find.byKey(ReauthSheet.submitKey));
    await tester.pumpAndSettle();

    verify(
      () => api.reauthenticate(
        password: 'my password',
        recoveryCode: 'abcde-fghjk',
      ),
    ).called(1);
    expect(result, isTrue);
    expect(find.byType(ReauthSheet), findsNothing);
  });

  testWidgets('a rejected recovery code is reported on that field', (
    WidgetTester tester,
  ) async {
    stubReauth(() async => throw server(ErrorObjectCode.mfaRequired));
    await openSheet(tester, mfa: true);
    await tester.tap(find.text('Use a recovery code instead'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ReauthSheet.passwordKey), 'my password');
    await tester.enterText(
      find.byKey(ReauthSheet.recoveryCodeKey),
      'used-code',
    );
    await tester.tap(find.byKey(ReauthSheet.submitKey));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(ReauthSheet.recoveryCodeKey),
        matching: find.text('Enter an unused recovery code.'),
      ),
      findsOneWidget,
    );
    expect(result, isNull, reason: 'sheet stays open');
  });

  testWidgets('a wrong password is reported on the password field', (
    WidgetTester tester,
  ) async {
    stubReauth(() async => throw server(ErrorObjectCode.reauthRequired));
    await openSheet(tester, mfa: false);
    expect(find.byKey(ReauthSheet.codeKey), findsNothing);
    await tester.enterText(find.byKey(ReauthSheet.passwordKey), 'nope');
    await tester.tap(find.byKey(ReauthSheet.submitKey));
    await tester.pumpAndSettle();

    expect(find.text('The password is incorrect.'), findsOneWidget);
    verify(() => api.reauthenticate(password: 'nope')).called(1);
  });

  testWidgets('asks for a code when the server says two-step is on', (
    WidgetTester tester,
  ) async {
    stubReauth(() async => throw server(ErrorObjectCode.mfaRequired));
    await openSheet(tester, mfa: false);
    await tester.enterText(find.byKey(ReauthSheet.passwordKey), 'my password');
    await tester.tap(find.byKey(ReauthSheet.submitKey));
    await tester.pumpAndSettle();

    expect(find.byKey(ReauthSheet.codeKey), findsOneWidget);
    expect(
      find.text('Enter a valid code from your authenticator app.'),
      findsOneWidget,
    );
    expect(find.text('Use a recovery code instead'), findsOneWidget);
  });
}
