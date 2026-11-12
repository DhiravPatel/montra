import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the signed-in user's profile, preferences and
/// onboarding progress.
class PreferencesApi {
  /// Creates the API over [client].
  PreferencesApi(this._client);

  final ApiClient _client;

  /// `GET /me` — account, profile and preferences.
  Future<MeDto> me() => _client.send(
    ApiEndpoints.getMe,
    decode: (Map<String, Object?> json) => decodeEnvelopeMeDto(json).data,
  );

  /// `GET /me/preferences`.
  Future<PreferencesDto> preferences() => _client.send(
    ApiEndpoints.getPreferences,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopePreferencesDto(json).data,
  );

  /// `PATCH /me/preferences` — only the members set in [patch] change.
  /// Changing the base currency or time zone never rewrites history.
  Future<PreferencesDto> updatePreferences(PreferencesPatch patch) =>
      _client.send(
        ApiEndpoints.updatePreferences,
        body: patch.toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopePreferencesDto(json).data,
      );

  /// `GET /me/onboarding` — saved progress, to resume setup.
  Future<OnboardingDto> onboarding() => _client.send(
    ApiEndpoints.getOnboarding,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeOnboardingDto(json).data,
  );

  /// `POST /me/onboarding` — merges the step lists with what is stored (a
  /// completed step wins over a skipped one); [complete] finishes
  /// onboarding (every step is optional).
  Future<OnboardingDto> recordOnboarding({
    required List<String> completed,
    required List<String> skipped,
    required bool complete,
  }) => _client.send(
    ApiEndpoints.recordOnboarding,
    body: OnboardingInput(
      completedSteps: completed,
      skippedSteps: skipped,
      complete: complete,
    ).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeOnboardingDto(json).data,
  );
}

/// Preferences endpoints. Overridden in tests.
final Provider<PreferencesApi> preferencesApiProvider =
    Provider<PreferencesApi>(
      (Ref ref) => PreferencesApi(ref.watch(apiClientProvider)),
    );
