import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';

/// `GET /limits`: the fair-use limits (the same for everyone; nothing is
/// paid) and the signed-in user's file storage use.
class LimitsApi {
  /// Creates the API over [client].
  LimitsApi(this._client);

  final ApiClient _client;

  /// The limits and current storage use.
  Future<Limits> get() => _client.send(
    ApiEndpoints.getLimits,
    decode: (Map<String, Object?> json) => decodeEnvelopeLimits(json).data,
  );
}

/// The [LimitsApi] over the shared client. Overridden in tests.
final Provider<LimitsApi> limitsApiProvider = Provider<LimitsApi>(
  (Ref ref) => LimitsApi(ref.watch(apiClientProvider)),
);

/// Limits and storage use; re-read after uploads and other writes.
final FutureProvider<Limits> limitsProvider =
    FutureProvider.autoDispose<Limits>((Ref ref) {
      ref
        ..watch(currentUserIdProvider)
        ..watch(financeRevisionProvider);
      return ref.read(limitsApiProvider).get();
    });
