import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/fx/data/fx_api.dart';

/// Rates for an optional base / quote filter.
typedef RateFilter = ({String? base, String? quote});

/// Exchange rates for [RateFilter]; re-read after finance writes (a manual
/// rate changes conversions).
final FutureProviderFamily<List<RateDto>, RateFilter> fxRatesProvider =
    FutureProvider.autoDispose.family<List<RateDto>, RateFilter>((
      Ref ref,
      RateFilter filter,
    ) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(fxApiProvider)
          .rates(base: filter.base, quote: filter.quote);
    });

/// Who a rate comes from.
String rateSourceLabel(AppLocalizations l10n, RateDtoSource source) =>
    switch (source) {
      RateDtoSource.manual => l10n.fxSourceManual,
      RateDtoSource.ecb => l10n.fxSourceEcb,
      RateDtoSource.provider => l10n.fxSourceProvider,
      RateDtoSource.unrecognized => l10n.fxSourceOther,
    };

/// Who the rate used in a conversion comes from.
String conversionSourceLabel(AppLocalizations l10n, RateSource source) =>
    switch (source) {
      RateSource.manual => l10n.fxSourceManual,
      RateSource.ecb => l10n.fxSourceEcb,
      RateSource.provider => l10n.fxSourceProvider,
      RateSource.unrecognized => l10n.fxSourceOther,
    };

final RegExp _ratePattern = RegExp(r'^\d{1,27}(\.\d{1,12})?$');

/// An exchange rate typed by the user as an exact decimal string ("83.12";
/// a comma is read as the decimal point), or null when it is not a positive
/// number with at most 12 decimal places (the server's rule).
String? parseRate(String text) {
  String v = text.trim().replaceAll(' ', '');
  if (!v.contains('.') && v.contains(',')) {
    v = v.replaceAll(',', '.');
  }
  if (!_ratePattern.hasMatch(v)) {
    return null;
  }
  if (!RegExp('[1-9]').hasMatch(v)) {
    return null;
  }
  return v;
}

/// A rate as the server wrote it, without trailing zeros: `GET /fx/rates`
/// sends twelve decimal places ("90.500000000000" → "90.5"). Text only; the
/// value is never converted to a number.
String displayRate(String rate) {
  if (!rate.contains('.')) {
    return rate;
  }
  String v = rate;
  while (v.endsWith('0')) {
    v = v.substring(0, v.length - 1);
  }
  return v.endsWith('.') ? v.substring(0, v.length - 1) : v;
}

/// Sorts rates: the user's own first, then by pair and source.
List<RateDto> sortRates(List<RateDto> rates) =>
    List<RateDto>.of(rates)..sort((RateDto a, RateDto b) {
      if (a.mine != b.mine) {
        return a.mine ? -1 : 1;
      }
      final int pair = '${a.baseValue}${a.quote}'.compareTo(
        '${b.baseValue}${b.quote}',
      );
      return pair != 0 ? pair : a.source.json.compareTo(b.source.json);
    });
