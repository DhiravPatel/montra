import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';

import '../helpers/fakes.dart';

void main() {
  final SignedIn signedIn = SignedIn(user: UserDto.fromJson(userJson()));
  String? go(AuthState state, String location) =>
      authRedirect(state, Uri.parse(location));

  group('while restoring', () {
    test('everything waits on the splash screen', () {
      expect(go(const AuthRestoring(), '/'), AppRoutes.splash);
      expect(go(const AuthRestoring(), '/profile'), AppRoutes.splash);
      expect(go(const AuthRestoring(), '/splash'), isNull);
      expect(
        go(
          const AuthRestoreFailed(ApiException(kind: ApiErrorKind.network)),
          '/sign-in',
        ),
        AppRoutes.splash,
      );
    });
  });

  group('signed out', () {
    test('protected routes go to the welcome screen', () {
      expect(go(const SignedOut(), '/profile/security'), AppRoutes.welcome);
      expect(go(const SignedOut(), '/'), AppRoutes.welcome);
      expect(go(const SignedOut(), '/splash'), AppRoutes.welcome);
    });

    test('an ended session goes to sign-in, which explains why', () {
      expect(
        go(const SignedOut(reason: SessionEndReason.expired), '/profile'),
        AppRoutes.signIn,
      );
      expect(
        go(
          const SignedOut(reason: SessionEndReason.signedOutEverywhere),
          '/profile',
        ),
        AppRoutes.signIn,
      );
      expect(
        go(const SignedOut(reason: SessionEndReason.signedOut), '/profile'),
        AppRoutes.welcome,
      );
    });

    test('signed-out screens are reachable', () {
      for (final String path in AppRoutes.signedOutOnly) {
        expect(go(const SignedOut(), path), isNull, reason: path);
      }
    });
  });

  group('signed in', () {
    test('signed-out screens and the splash go to the landing page', () {
      expect(go(signedIn, '/sign-in'), AppRoutes.signedInHome);
      expect(go(signedIn, '/welcome'), AppRoutes.signedInHome);
      expect(go(signedIn, '/splash'), AppRoutes.signedInHome);
      expect(go(signedIn, '/'), AppRoutes.signedInHome);
    });

    test('app routes stay put', () {
      expect(go(signedIn, '/profile/security/sessions'), isNull);
      expect(go(signedIn, '/profile/'), isNull);
      expect(go(signedIn, '/home'), isNull);
      expect(go(signedIn, '/transactions?category_id=c1'), isNull);
      expect(go(signedIn, '/accounts/a1'), isNull);
    });

    test('a new account lands on onboarding, which stays skippable', () {
      final SignedIn fresh = SignedIn(
        user: UserDto.fromJson(userJson(onboardingCompleted: false)),
      );
      expect(go(fresh, '/sign-in'), AppRoutes.onboarding);
      expect(go(fresh, '/splash'), AppRoutes.onboarding);
      expect(go(fresh, '/'), AppRoutes.onboarding);
      expect(go(fresh, '/onboarding'), isNull);
      // Deep links into the app still work before onboarding is finished.
      expect(go(fresh, '/transactions'), isNull);
    });

    test('onboarding is not offered again once completed', () {
      expect(go(signedIn, '/onboarding'), AppRoutes.home);
    });
  });

  group('round 4 and 5 routes', () {
    test('the signed-out contact form is public', () {
      expect(go(const SignedOut(), AppRoutes.contact), isNull);
      expect(go(signedIn, AppRoutes.contact), isNull);
      expect(go(const AuthRestoring(), AppRoutes.contact), isNull);
    });

    test('an invitation link waits for sign-in and is opened afterwards', () {
      const String link = '/groups/join#token=secret-token';
      expect(
        go(const SignedOut(), link),
        '/sign-in?next=%2Fgroups%2Fjoin%23token%3Dsecret-token',
      );
      expect(
        go(const SignedOut(), '/communities/join#token=t'),
        startsWith('/sign-in?next='),
      );
      // After signing in, the sign-in route carries the link as `next`.
      expect(
        go(signedIn, '/sign-in?next=%2Fgroups%2Fjoin%23token%3Dsecret-token'),
        link,
      );
      // A new account still goes through the (skippable) setup first.
      final SignedIn fresh = SignedIn(
        user: UserDto.fromJson(userJson(onboardingCompleted: false)),
      );
      expect(go(fresh, '/sign-in?next=%2Fgroups%2Fjoin'), AppRoutes.onboarding);
    });

    test('next never leaves the app', () {
      expect(AppRoutes.safeNext('https://evil.example/x'), isNull);
      expect(AppRoutes.safeNext('//evil.example/x'), isNull);
      expect(AppRoutes.safeNext('groups/join'), isNull);
      expect(AppRoutes.safeNext(null), isNull);
      expect(
        AppRoutes.safeNext('/groups/join#token=t'),
        '/groups/join#token=t',
      );
      expect(
        go(signedIn, '/sign-in?next=https%3A%2F%2Fevil.example'),
        AppRoutes.signedInHome,
      );
    });

    test('the new tabs and screens stay put when signed in', () {
      for (final String path in <String>[
        AppRoutes.insights,
        AppRoutes.together,
        AppRoutes.friends,
        AppRoutes.groups,
        AppRoutes.groupDetail('g1'),
        AppRoutes.groupExpenseDetail('g1', 'e1'),
        AppRoutes.communities,
        AppRoutes.postDetail('p1'),
        AppRoutes.challenges,
        AppRoutes.notifications,
        AppRoutes.search,
        AppRoutes.help,
        AppRoutes.privacy,
        AppRoutes.limits,
        AppRoutes.myModeration,
        AppRoutes.integrations,
      ]) {
        expect(go(signedIn, path), isNull, reason: path);
        expect(go(const SignedOut(), path), AppRoutes.welcome, reason: path);
      }
    });
  });

  test('emailed links work in every state, including full URLs', () {
    const String verify = 'https://montra.example/verify-email#token=abc';
    const String reset = 'http://localhost:5173/reset-password#token=abc';
    for (final AuthState state in <AuthState>[
      const AuthRestoring(),
      const SignedOut(),
      signedIn,
    ]) {
      expect(go(state, verify), isNull);
      expect(go(state, reset), isNull);
    }
  });
}
