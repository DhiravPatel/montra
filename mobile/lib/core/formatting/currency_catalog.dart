import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// The supported currencies as served by `GET /currencies` (public, so it
/// works before sign-in). This is the source of truth for pickers.
@immutable
class CurrencyCatalog {
  /// Creates a catalog from [currencies] (any order).
  CurrencyCatalog(List<CurrencyDto> currencies)
    : currencies = List<CurrencyDto>.unmodifiable(
        List<CurrencyDto>.of(currencies)
          ..sort((CurrencyDto a, CurrencyDto b) => a.code.compareTo(b.code)),
      ),
      _byCode = <String, CurrencyDto>{
        for (final CurrencyDto c in currencies) c.code: c,
      };

  /// Every currency, sorted by code. Retired currencies stay listed because
  /// they remain valid for history.
  final List<CurrencyDto> currencies;

  final Map<String, CurrencyDto> _byCode;

  /// Currencies that may be chosen for new accounts and preferences
  /// (`selectable: true`); retired ones such as BGN are left out.
  List<CurrencyDto> get selectable => <CurrencyDto>[
    for (final CurrencyDto c in currencies)
      if (c.selectable) c,
  ];

  /// Looks up [code].
  CurrencyDto? byCode(String code) => _byCode[code];

  /// A selectable code for a suggestion: [code] itself, its `replaced_by`
  /// currency when it was retired (BGN → EUR), or null.
  String? selectableFor(String? code) {
    if (code == null) {
      return null;
    }
    final CurrencyDto? currency = _byCode[code];
    if (currency == null) {
      return null;
    }
    if (currency.selectable) {
      return currency.code;
    }
    final String? replacement = currency.replacedBy;
    final CurrencyDto? next = replacement == null ? null : _byCode[replacement];
    return next != null && next.selectable ? next.code : null;
  }
}

/// Loads the live catalog once per app run; invalidate it to retry after an
/// error.
final FutureProvider<CurrencyCatalog> currencyCatalogProvider =
    FutureProvider<CurrencyCatalog>((Ref ref) async {
      final List<CurrencyDto> currencies = await ref
          .read(apiClientProvider)
          .send(
            ApiEndpoints.listCurrencies,
            decode: (Map<String, Object?> json) =>
                decodeEnvelopeListCurrencyDto(json).data,
          );
      return CurrencyCatalog(currencies);
    });
