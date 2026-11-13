import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/config/app_config.dart';

void main() {
  AppConfig resolve({
    String apiBaseUrl = '',
    TargetPlatform platform = TargetPlatform.android,
    bool releaseMode = false,
    String termsUrl = '',
  }) => AppConfig.resolve(
    apiBaseUrl: apiBaseUrl,
    platform: platform,
    releaseMode: releaseMode,
    clientVersion: '1.0.0+1',
    termsUrl: termsUrl,
  );

  test('development defaults reach the host machine', () {
    expect(resolve().apiRoot, 'http://10.0.2.2:8080/api/v1');
    expect(
      resolve(platform: TargetPlatform.iOS).apiRoot,
      'http://localhost:8080/api/v1',
    );
  });

  test('API_BASE_URL is used as given, with or without a trailing slash', () {
    expect(
      resolve(apiBaseUrl: 'https://api.example.com/').apiRoot,
      'https://api.example.com/api/v1',
    );
    expect(
      resolve(apiBaseUrl: 'http://192.168.1.20:8080').apiRoot,
      'http://192.168.1.20:8080/api/v1',
    );
  });

  test('client kind follows the platform', () {
    expect(resolve().clientKind, 'android');
    expect(resolve(platform: TargetPlatform.iOS).clientKind, 'ios');
    expect(resolve(platform: TargetPlatform.linux).clientKind, 'unknown');
  });

  test('release builds require an explicit https URL', () {
    expect(
      () => resolve(releaseMode: true),
      throwsA(isA<AppConfigException>()),
    );
    expect(
      () => resolve(apiBaseUrl: 'http://api.example.com', releaseMode: true),
      throwsA(isA<AppConfigException>()),
    );
    expect(
      resolve(apiBaseUrl: 'https://api.example.com', releaseMode: true).apiRoot,
      'https://api.example.com/api/v1',
    );
  });

  test('rejects URLs with credentials, queries or other schemes', () {
    for (final String bad in <String>[
      'ftp://api.example.com',
      'https://user:pw@api.example.com',
      'https://api.example.com?x=1',
      'not a url',
    ]) {
      expect(
        () => resolve(apiBaseUrl: bad),
        throwsA(isA<AppConfigException>()),
        reason: bad,
      );
    }
  });

  test('optional legal document URLs must be https in release', () {
    expect(resolve(termsUrl: 'https://example.com/terms').termsUrl, isNotNull);
    expect(resolve().termsUrl, isNull);
    expect(
      () => resolve(
        apiBaseUrl: 'https://api.example.com',
        releaseMode: true,
        termsUrl: 'http://example.com/terms',
      ),
      throwsA(isA<AppConfigException>()),
    );
  });

  test('the status page link is shown only for an https URL', () {
    AppConfig withStatus(String url) => AppConfig.resolve(
      apiBaseUrl: '',
      platform: TargetPlatform.android,
      releaseMode: false,
      clientVersion: '1.0.0+1',
      statusPageUrl: url,
    );
    expect(
      withStatus('https://status.example.com').statusPageUrl.toString(),
      'https://status.example.com',
    );
    expect(withStatus('').statusPageUrl, isNull);
    expect(withStatus('http://status.example.com').statusPageUrl, isNull);
    expect(withStatus('status page').statusPageUrl, isNull);
    expect(resolve().statusPageUrl, isNull);
  });

  test('terms and privacy versions match the backend', () {
    expect(AppConfig.termsVersion, '2026-11-01');
    expect(AppConfig.privacyVersion, '2026-11-01');
  });
}
