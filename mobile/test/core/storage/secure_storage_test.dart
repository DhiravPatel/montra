import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/credential_store.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';
import 'package:montra_mobile/core/storage/secure_store.dart';

import '../../helpers/fakes.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockSecureStore extends Mock implements SecureStore {}

void main() {
  group('FlutterSecureStore (platform wrapper)', () {
    late MockFlutterSecureStorage storage;
    late FlutterSecureStore store;

    setUp(() {
      storage = MockFlutterSecureStorage();
      store = FlutterSecureStore(storage);
    });

    test('forwards reads, writes and deletes', () async {
      when(() => storage.read(key: 'k'))
          .thenAnswer((Invocation _) async => 'v');
      when(() => storage.write(key: 'k', value: 'v'))
          .thenAnswer((Invocation _) async {});
      when(() => storage.delete(key: 'k')).thenAnswer((Invocation _) async {});

      expect(await store.read('k'), 'v');
      await store.write('k', 'v');
      await store.delete('k');

      verify(() => storage.write(key: 'k', value: 'v')).called(1);
      verify(() => storage.delete(key: 'k')).called(1);
    });

    test('treats unreadable items as absent instead of crashing', () async {
      when(() => storage.read(key: 'k'))
          .thenThrow(PlatformException(code: 'keystore'));
      expect(await store.read('k'), isNull);
    });

    test('swallows platform errors on delete', () async {
      when(() => storage.delete(key: 'k'))
          .thenThrow(PlatformException(code: 'keystore'));
      await expectLater(store.delete('k'), completes);
    });

    test('Keychain items stay on this device and survive background use', () {
      expect(
        FlutterSecureStore.defaultStorage.iOptions.accessibility,
        KeychainAccessibility.first_unlock_this_device,
      );
      expect(
        FlutterSecureStore.defaultStorage.iOptions.synchronizable,
        isFalse,
      );
    });
  });

  group('CredentialStore', () {
    late MockSecureStore secure;
    late CredentialStore credentials;

    setUp(() {
      secure = MockSecureStore();
      credentials = CredentialStore(secure);
      when(() => secure.write(any(), any()))
          .thenAnswer((Invocation _) async {});
      when(() => secure.delete(any())).thenAnswer((Invocation _) async {});
    });

    test('keeps the access token in memory only', () {
      credentials.setAccessToken('access-token', DateTime.utc(2099));
      expect(credentials.accessToken, 'access-token');
      verifyNever(() => secure.write(any(), any()));
    });

    test('persists only the refresh token, under its key', () async {
      expect(await credentials.writeRefreshToken('refresh-token'), isTrue);
      verify(
        () => secure.write(CredentialStore.refreshTokenKey, 'refresh-token'),
      ).called(1);
    });

    test('reports a failed secure write instead of throwing', () async {
      when(() => secure.write(any(), any()))
          .thenThrow(PlatformException(code: 'keystore'));
      expect(await credentials.writeRefreshToken('refresh-token'), isFalse);
    });

    test('clear removes both tokens', () async {
      credentials.setAccessToken('access-token', null);
      await credentials.clear();
      expect(credentials.accessToken, isNull);
      verify(() => secure.delete(CredentialStore.refreshTokenKey)).called(1);
    });
  });

  group('SessionTokenManager.adopt', () {
    test('writes nothing but the refresh token to secure storage', () async {
      final MemorySecureStore secure = MemorySecureStore();
      final CredentialStore credentials = CredentialStore(secure);
      final SessionTokenManager tokens = SessionTokenManager(
        store: credentials,
        refresh: (String _) async => throw UnimplementedError(),
      );
      await tokens.adopt(
        AuthResult.fromJson(
          authResultJson(access: 'access-9', refresh: 'refresh-9'),
        ),
      );
      expect(secure.values, <String, String>{
        CredentialStore.refreshTokenKey: 'refresh-9',
      });
      expect(tokens.currentAccessToken, 'access-9');
    });

    test(
      'rejects responses without body tokens (e.g. a web response)',
      () async {
        final SessionTokenManager tokens = SessionTokenManager(
          store: CredentialStore(MemorySecureStore()),
          refresh: (String _) async => throw UnimplementedError(),
        );
        await expectLater(
          tokens.adopt(
            const AuthResult(status: AuthResultStatus.authenticated),
          ),
          throwsA(anything),
        );
      },
    );
  });
}
