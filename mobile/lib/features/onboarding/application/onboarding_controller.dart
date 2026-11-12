import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

/// Onboarding step IDs the server accepts (`POST /me/onboarding`).
abstract final class OnboardingSteps {
  static const String welcome = 'welcome';
  static const String privacy = 'privacy';
  static const String country = 'country';
  static const String currency = 'currency';
  static const String timezone = 'timezone';
  static const String income = 'income';
  static const String accounts = 'accounts';
  static const String categories = 'categories';

  /// The region page covers three server steps.
  static const List<String> region = <String>[country, currency, timezone];
}

/// Steps completed and skipped so far. The server merges what each call
/// sends with what it stored (a completed step wins over a skipped one).
@immutable
class OnboardingProgress {
  /// Creates the progress.
  const OnboardingProgress({
    this.completed = const <String>[],
    this.skipped = const <String>[],
  });

  /// Completed step IDs, in order.
  final List<String> completed;

  /// Skipped step IDs, in order.
  final List<String> skipped;

  /// Marks [steps] completed (a later answer replaces a skip).
  OnboardingProgress complete(Iterable<String> steps) => OnboardingProgress(
    completed: <String>[
      ...completed,
      for (final String s in steps)
        if (!completed.contains(s)) s,
    ],
    skipped: <String>[
      for (final String s in skipped)
        if (!steps.contains(s)) s,
    ],
  );

  /// Marks [steps] skipped unless they were completed.
  OnboardingProgress skip(Iterable<String> steps) => OnboardingProgress(
    completed: completed,
    skipped: <String>[
      ...skipped,
      for (final String s in steps)
        if (!skipped.contains(s) && !completed.contains(s)) s,
    ],
  );
}

/// Drives onboarding: saves preferences as the user answers and records
/// the completed/skipped steps when they finish (or skip the rest).
final NotifierProvider<OnboardingController, OnboardingProgress>
onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingProgress>(
      OnboardingController.new,
    );

/// See [onboardingControllerProvider].
class OnboardingController extends Notifier<OnboardingProgress> {
  PreferencesApi get _api => ref.read(preferencesApiProvider);

  @override
  OnboardingProgress build() => const OnboardingProgress();

  /// Starts from progress saved earlier (`GET /me/onboarding`).
  void resume(OnboardingDto saved) {
    state = const OnboardingProgress()
        .skip(saved.skippedSteps)
        .complete(saved.completedSteps);
  }

  /// Saves progress so setup can resume later. Best effort: finishing sends
  /// everything again, so a failure here is not shown.
  Future<void> saveProgress() async {
    final OnboardingProgress now = state;
    try {
      await _api.recordOnboarding(
        completed: now.completed,
        skipped: now.skipped,
        complete: false,
      );
    } on Object {
      // Kept for the final call.
    }
  }

  /// Records [steps] as completed.
  void complete(Iterable<String> steps) => state = state.complete(steps);

  /// Records [steps] as skipped.
  void skip(Iterable<String> steps) => state = state.skip(steps);

  /// Saves preference changes and mirrors base currency and time zone in
  /// the signed-in user's summary. Throws `ApiException`.
  Future<PreferencesDto> savePreferences(PreferencesPatch patch) async {
    final PreferencesDto saved = await _api.updatePreferences(patch);
    if (!ref.mounted) {
      return saved;
    }
    ref
        .read(authControllerProvider.notifier)
        .updateUser(
          (UserDto u) => UserDto.fromJson(<String, Object?>{
            ...u.toJson(),
            'base_currency': saved.baseCurrency,
            'timezone': saved.timezone,
            'locale': saved.locale,
          }),
        );
    return saved;
  }

  /// Finishes onboarding: every step not answered yet counts as skipped.
  /// Throws `ApiException`; on success routing moves to Home.
  Future<void> finish({Iterable<String> remaining = const <String>[]}) async {
    final OnboardingProgress last = state.skip(remaining);
    await _api.recordOnboarding(
      completed: last.completed,
      skipped: last.skipped,
      complete: true,
    );
    if (!ref.mounted) {
      return;
    }
    state = last;
    ref
        .read(authControllerProvider.notifier)
        .updateUser(
          (UserDto u) => UserDto.fromJson(<String, Object?>{
            ...u.toJson(),
            'onboarding_completed': true,
          }),
        );
  }
}
