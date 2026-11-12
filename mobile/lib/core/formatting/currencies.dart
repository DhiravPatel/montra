import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/currency_snapshot.dart';

/// Offline currency lookups backed by [currencySnapshot] (a generated copy of
/// `GET /currencies`).
///
/// Used where the app must work without a network round trip: minor-unit
/// exponents for formatting and the sign-up region suggestion. Pickers use
/// the live catalog (`currencyCatalogProvider`); the server validates every
/// code, and money values arrive with exact `amount` strings, so a stale
/// snapshot can only affect padding, never stored values.
abstract final class Currencies {
  static final Map<String, CurrencyDto> _byCode = <String, CurrencyDto>{
    for (final CurrencyDto c in currencySnapshot) c.code: c,
  };

  /// Every currency in the snapshot, sorted by code (including retired ones,
  /// which stay valid for historical records).
  static List<CurrencyDto> get all => currencySnapshot;

  /// Looks up [code] (case-sensitive ISO code).
  static CurrencyDto? byCode(String code) => _byCode[code];

  /// Minor-unit exponent of [code] (0, 2 or 3), or null when unknown.
  static int? exponentOf(String code) => _byCode[code]?.exponent;
}
