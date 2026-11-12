import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Exchange rates` tag: published and manual rates,
/// and conversions that disclose the rate used.
class FxApi {
  /// Creates the API over [client].
  FxApi(this._client);

  final ApiClient _client;

  /// `GET /fx/rates`: the latest rate per pair and source (published rates
  /// and the user's own), optionally for one [base] and/or [quote].
  Future<List<RateDto>> rates({String? base, String? quote}) => _client.send(
    ApiEndpoints.listFxRates,
    query: <String, Object?>{'base': base, 'quote': quote},
    decode: (Map<String, Object?> json) => decodeEnvelopeListRateDto(json).data,
  );

  /// `POST /fx/rates`: adds a manual rate (earlier ones are kept).
  Future<RateDto> setRate(ManualRateInput input) => _client.send(
    ApiEndpoints.setFxRate,
    body: input.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeRateDto(json).data,
  );

  /// `DELETE /fx/rates/{id}`: deletes one of the user's manual rates.
  Future<void> deleteRate(String id) => _client.send(
    ApiEndpoints.deleteFxRate,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );

  /// `GET /fx/convert`: converts [amount] (an exact decimal in [from]'s
  /// precision) with the latest rate, or with the rate on [date] when
  /// [historical] (`policy=historical`).
  Future<ConversionDto> convert({
    required String amount,
    required String from,
    required String to,
    bool historical = false,
    String? date,
  }) => _client.send(
    ApiEndpoints.convertFx,
    query: <String, Object?>{
      'amount': amount,
      'from': from,
      'to': to,
      'policy': historical ? 'historical' : 'current',
      if (historical) 'date': date,
    },
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeConversionDto(json).data,
  );
}

/// Exchange-rate endpoints. Overridden in tests.
final Provider<FxApi> fxApiProvider = Provider<FxApi>(
  (Ref ref) => FxApi(ref.watch(apiClientProvider)),
);
