import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/currencies.dart';

/// Regional settings read from the device for sign-up. They are shown to the
/// user before submission (nothing is collected silently) and the server
/// validates them.
@immutable
class DeviceProfile {
  /// Creates the profile.
  const DeviceProfile({this.localeTag, this.timezone, this.suggestedCurrency});

  /// BCP 47 tag the backend accepts (`en-IN`, `hi`), or null.
  final String? localeTag;

  /// IANA time zone (`Asia/Kolkata`), or null when unavailable.
  final String? timezone;

  /// Currency suggested by the device region, when Montra supports it.
  final String? suggestedCurrency;

  /// Converts a [Locale] to the `ll` / `ll-RR` form the backend accepts
  /// (script subtags are dropped).
  static String? localeTagFor(Locale locale) {
    final String language = locale.languageCode.toLowerCase();
    if (!RegExp(r'^[a-z]{2,3}$').hasMatch(language)) {
      return null;
    }
    final String? region = locale.countryCode?.toUpperCase();
    if (region != null && RegExp(r'^[A-Z]{2}$').hasMatch(region)) {
      return '$language-$region';
    }
    return language;
  }

  /// The currency of [locale]'s region, if Montra supports it.
  ///
  /// Uses the ISO 4217 convention that a national currency code starts with
  /// the ISO 3166 country code (`IN` -> `INR`, `NG` -> `NGN`), plus the euro
  /// area. Regions without exactly one selectable match get no suggestion
  /// and the user picks a currency. Only a suggestion: the user sees and can
  /// change it, and sign-up re-checks it against the live catalog.
  static String? currencyFor(Locale locale) {
    final String? region = locale.countryCode?.toUpperCase();
    if (region == null || !RegExp(r'^[A-Z]{2}$').hasMatch(region)) {
      return null;
    }
    if (_euroRegions.contains(region)) {
      return 'EUR';
    }
    // Retired currencies (e.g. BGN) can never be suggested.
    final List<CurrencyDto> matches = Currencies.all
        .where((CurrencyDto c) => c.selectable && c.code.startsWith(region))
        .toList();
    return matches.length == 1 ? matches.single.code : null;
  }

  /// Regions whose currency is the euro (euro area and euro-using states).
  static const Set<String> _euroRegions = <String>{
    'AD',
    'AT',
    'BE',
    'BG',
    'CY',
    'DE',
    'EE',
    'ES',
    'FI',
    'FR',
    'GR',
    'HR',
    'IE',
    'IT',
    'LT',
    'LU',
    'LV',
    'MC',
    'ME',
    'MT',
    'NL',
    'PT',
    'SI',
    'SK',
    'SM',
    'VA',
    'XK',
  };
}

/// Reads the device profile once (time zone lookup is asynchronous).
final FutureProvider<DeviceProfile> deviceProfileProvider =
    FutureProvider<DeviceProfile>((Ref ref) async {
      final Locale locale = PlatformDispatcher.instance.locale;
      String? timezone;
      try {
        final String id = (await FlutterTimezone.getLocalTimezone()).identifier;
        timezone = id.isEmpty ? null : id;
      } on Exception {
        timezone = null;
      }
      return DeviceProfile(
        localeTag: DeviceProfile.localeTagFor(locale),
        timezone: timezone,
        suggestedCurrency: DeviceProfile.currencyFor(locale),
      );
    });
