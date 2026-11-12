import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/l10n/generated/app_localizations_en.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/auth/domain/device_profile.dart';
import 'package:montra_mobile/features/auth/domain/password_policy.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();

  test('blocks only on length, like the server minimum of 10', () {
    expect(PasswordPolicy.validate(l10n, ''), l10n.validationPasswordRequired);
    expect(
      PasswordPolicy.validate(l10n, 'abcdefghi'),
      l10n.validationPasswordTooShort(10),
    );
    expect(PasswordPolicy.validate(l10n, 'abcdefghij'), isNull);
    expect(
      PasswordPolicy.validate(l10n, 'a' * 129),
      l10n.validationPasswordTooLong(128),
    );
  });

  test('the minimum comes from the contract and matches every password '
      'schema', () {
    expect(PasswordPolicy.minLength, 10);
    expect(ResetBody.newPasswordMinLength, PasswordPolicy.minLength);
    expect(ChangePasswordBody.newPasswordMinLength, PasswordPolicy.minLength);
    expect(PasswordPolicy.maxLength, 128);
  });

  test('counts code points as the server does', () {
    expect(PasswordPolicy.lengthOf('😀😀'), 2);
    expect(PasswordPolicy.meetsLength('😀' * 10), isTrue);
  });

  test('hints mirror the server rules', () {
    expect(
      PasswordPolicy.avoidsEmail('my-asha.k-secret', 'asha.k@example.com'),
      isFalse,
    );
    expect(
      PasswordPolicy.avoidsEmail('unrelated phrase', 'asha@example.com'),
      isTrue,
    );
    // Local parts shorter than 4 characters are not checked.
    expect(
      PasswordPolicy.avoidsEmail('abc-password', 'abc@example.com'),
      isTrue,
    );
    expect(PasswordPolicy.hasVariety('aaaaaaaaaaaa'), isFalse);
    expect(PasswordPolicy.hasVariety('abcdabcdabcd'), isTrue);
  });

  test('device locale tags use the form the backend accepts', () {
    expect(DeviceProfile.localeTagFor(const Locale('en', 'IN')), 'en-IN');
    expect(DeviceProfile.localeTagFor(const Locale('hi')), 'hi');
    expect(
      DeviceProfile.localeTagFor(
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'CN',
        ),
      ),
      'zh-CN',
    );
    expect(DeviceProfile.localeTagFor(const Locale('und')), 'und');
    expect(DeviceProfile.localeTagFor(const Locale('en', '419')), 'en');
  });

  test('the suggested currency follows the device region', () {
    expect(DeviceProfile.currencyFor(const Locale('en', 'IN')), 'INR');
    expect(DeviceProfile.currencyFor(const Locale('hi', 'IN')), 'INR');
    expect(DeviceProfile.currencyFor(const Locale('en', 'US')), 'USD');
    expect(DeviceProfile.currencyFor(const Locale('de', 'DE')), 'EUR');
    expect(DeviceProfile.currencyFor(const Locale('es', 'AR')), 'ARS');
    expect(DeviceProfile.currencyFor(const Locale('en', 'NG')), 'NGN');
    expect(DeviceProfile.currencyFor(const Locale('fr', 'CH')), 'CHF');
    expect(DeviceProfile.currencyFor(const Locale('en')), isNull);
    expect(DeviceProfile.currencyFor(const Locale('en', '419')), isNull);
  });
}
