import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/features/auth/domain/auth_link.dart';

void main() {
  const String token = 'Zq7Xp2Lk9Vb4Nm1Rt6Yw3Hs8Df5Gj0Ka2Ce4Ui6Ob8P';

  group('AuthLinks.parse', () {
    test('reads the token from the fragment of development links', () {
      expect(
        AuthLinks.parse('http://localhost:5173/verify-email#token=$token'),
        const AuthLink(AuthLinkKind.verifyEmail, token),
      );
      expect(
        AuthLinks.parse('http://localhost:5173/reset-password#token=$token'),
        const AuthLink(AuthLinkKind.resetPassword, token),
      );
    });

    test('accepts production links, trailing slashes and query fallback', () {
      expect(
        AuthLinks.parse(
          'https://app.montra.example/verify-email/#token=$token',
        ),
        const AuthLink(AuthLinkKind.verifyEmail, token),
      );
      expect(
        AuthLinks.parse(
          'https://app.montra.example/reset-password?token=$token',
        ),
        const AuthLink(AuthLinkKind.resetPassword, token),
      );
    });

    test('removes whitespace inserted by email clients', () {
      expect(
        AuthLinks.parse(
          '  http://localhost:5173/verify-email#token=Zq7Xp2Lk9Vb4Nm1Rt6Y\n'
          'w3Hs8Df5Gj0Ka2Ce4Ui6Ob8P  ',
        ),
        const AuthLink(AuthLinkKind.verifyEmail, token),
      );
    });

    test('rejects other links and malformed tokens', () {
      expect(AuthLinks.parse(''), isNull);
      expect(AuthLinks.parse('hello'), isNull);
      expect(AuthLinks.parse('https://example.com/other#token=$token'), isNull);
      expect(AuthLinks.parse('https://example.com/verify-email'), isNull);
      expect(
        AuthLinks.parse('https://example.com/verify-email#token=short'),
        isNull,
      );
      expect(
        AuthLinks.parse(
          'https://example.com/verify-email#token=bad<script>token',
        ),
        isNull,
      );
      expect(
        AuthLinks.parse('https://example.com/verify-email#token=${'a' * 129}'),
        isNull,
      );
    });
  });

  test('tokenFrom reads deep-link URIs delivered to the router', () {
    expect(AuthLinks.tokenFrom(Uri.parse('/verify-email#token=$token')), token);
    expect(AuthLinks.tokenFrom(Uri.parse('/verify-email')), isNull);
  });

  test('toString never contains the token', () {
    expect(
      const AuthLink(AuthLinkKind.verifyEmail, token).toString(),
      isNot(contains(token)),
    );
  });
}
