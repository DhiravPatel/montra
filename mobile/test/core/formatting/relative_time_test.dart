import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/l10n/generated/app_localizations_en.dart';
import 'package:montra_mobile/app/l10n/generated/app_localizations_hi.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';

void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();

  test('waits read in seconds below a minute, then whole minutes', () {
    expect(formatWait(en, const Duration(seconds: 1)), '1 second');
    expect(formatWait(en, const Duration(seconds: 30)), '30 seconds');
    expect(formatWait(en, const Duration(milliseconds: 200)), '1 second');
    expect(formatWait(en, const Duration(seconds: 60)), '1 minute');
    expect(formatWait(en, const Duration(seconds: 61)), '2 minutes');
    expect(formatWait(en, const Duration(minutes: 15)), '15 minutes');
  });

  test('short waits for button labels', () {
    expect(formatWaitShort(en, 29), '29s');
    expect(formatWaitShort(en, 0), '1s');
    expect(formatWaitShort(en, 900), '15 min');
    expect(formatWaitShort(AppLocalizationsHi(), 900), '15 मिनट');
  });

  test('relative times', () {
    final DateTime now = DateTime.utc(2026, 11, 4, 10);
    expect(formatRelativeTime(en, now, now: now, locale: 'en'), 'just now');
    expect(
      formatRelativeTime(
        en,
        now.subtract(const Duration(minutes: 5)),
        now: now,
        locale: 'en',
      ),
      '5 minutes ago',
    );
    expect(
      formatRelativeTime(
        en,
        now.subtract(const Duration(days: 1, hours: 2)),
        now: now,
        locale: 'en',
      ),
      'yesterday',
    );
  });
}
