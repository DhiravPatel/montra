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
      // A protected deep link opened at cold start is kept for later.
      expect(go(const AuthRestoring(), '/profile'), '/splash?next=%2Fprofile');
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
    test('protected routes go to the welcome screen and are kept as next', () {
      expect(
        go(const SignedOut(), '/profile/security'),
        '/welcome?next=%2Fprofile%2Fsecurity',
      );
      expect(
        go(const SignedOut(), '/transactions?category_id=c1'),
        '/welcome?next=%2Ftransactions%3Fcategory_id%3Dc1',
      );
      expect(go(const SignedOut(), '/'), AppRoutes.welcome);
      expect(go(const SignedOut(), '/splash'), AppRoutes.welcome);
      // A deep link that waited on the splash screen moves on with it.
      expect(
        go(const SignedOut(), '/splash?next=%2Fbudgets%2Fb1'),
        '/welcome?next=%2Fbudgets%2Fb1',
      );
    });

    test('an ended session goes to sign-in, which explains why', () {
      expect(
        go(const SignedOut(reason: SessionEndReason.expired), '/profile'),
        '/sign-in?next=%2Fprofile',
      );
      expect(
        go(
          const SignedOut(reason: SessionEndReason.signedOutEverywhere),
          '/profile',
        ),
        '/sign-in?next=%2Fprofile',
      );
    });

    test('a voluntary sign-out starts over without next', () {
      expect(
        go(const SignedOut(reason: SessionEndReason.signedOut), '/profile'),
        AppRoutes.welcome,
      );
    });

    test('the welcome and sign-in screens keep their next', () {
      expect(go(const SignedOut(), '/welcome?next=%2Fprofile'), isNull);
      expect(go(const SignedOut(), '/sign-in?next=%2Fprofile'), isNull);
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
      expect(go(fresh, '/onboarding?next=%2Fprofile'), isNull);
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
      expect(
        go(fresh, '/sign-in?next=%2Fgroups%2Fjoin'),
        '/onboarding?next=%2Fgroups%2Fjoin',
      );
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

    test('next is never an auth screen, so it cannot loop', () {
      for (final String path in <String>[
        '/sign-in',
        '/welcome?next=%2Fprofile',
        '/sign-up',
        '/check-email',
        '/forgot-password',
        '/splash',
        '/',
        '/onboarding',
        '/verify-email#token=t',
        '/reset-password#token=t',
      ]) {
        expect(AppRoutes.safeNext(path), isNull, reason: path);
      }
      expect(AppRoutes.withNext(AppRoutes.signIn, '/sign-up'), '/sign-in');
      expect(
        AppRoutes.withNext(AppRoutes.signIn, '/budgets'),
        '/sign-in?next=%2Fbudgets',
      );
      expect(go(signedIn, '/sign-in?next=%2Fsign-up'), AppRoutes.signedInHome);
      expect(go(const SignedOut(), '/sign-in?next=%2F%2Fevil.example'), isNull);
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
        expect(
          go(const SignedOut(), path),
          AppRoutes.withNext(AppRoutes.welcome, path),
          reason: path,
        );
      }
    });
  });

  group('returning after sign-in', () {
    test('a protected deep link opens after signing in', () {
      // Signed out: the link waits on the welcome screen…
      final String? welcome = go(const SignedOut(), '/budgets/b1?tab=2');
      expect(welcome, '/welcome?next=%2Fbudgets%2Fb1%3Ftab%3D2');
      // …goes along to sign-in…
      final String signIn = AppRoutes.withNext(
        AppRoutes.signIn,
        AppRoutes.nextOf(Uri.parse(welcome!)),
      );
      expect(signIn, '/sign-in?next=%2Fbudgets%2Fb1%3Ftab%3D2');
      // …and opens once the session starts.
      expect(go(signedIn, signIn), '/budgets/b1?tab=2');
    });

    test('a cold-start deep link opens once the session is restored', () {
      final String? splash = go(const AuthRestoring(), '/goals/g1');
      expect(splash, '/splash?next=%2Fgoals%2Fg1');
      expect(go(signedIn, splash!), '/goals/g1');
      expect(go(const SignedOut(), splash), '/welcome?next=%2Fgoals%2Fg1');
    });

    test('a new account sees the setup first, then the link', () {
      final SignedIn fresh = SignedIn(
        user: UserDto.fromJson(userJson(onboardingCompleted: false)),
      );
      expect(
        go(fresh, '/sign-in?next=%2Fbudgets%2Fb1'),
        '/onboarding?next=%2Fbudgets%2Fb1',
      );
      // Finishing setup marks onboarding completed; the guard moves on.
      expect(go(signedIn, '/onboarding?next=%2Fbudgets%2Fb1'), '/budgets/b1');
      expect(
        go(signedIn, '/onboarding?next=https%3A%2F%2Fevil.example'),
        AppRoutes.home,
      );
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
