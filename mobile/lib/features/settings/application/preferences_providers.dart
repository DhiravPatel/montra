import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

/// The signed-in user's preferences (scoped to the user; re-read when the
/// account changes).
final FutureProvider<PreferencesDto> preferencesProvider =
    FutureProvider.autoDispose<PreferencesDto>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(preferencesApiProvider).preferences();
    });

/// Saved onboarding progress (to resume setup where the user left off).
final FutureProvider<OnboardingDto> onboardingProgressProvider =
    FutureProvider.autoDispose<OnboardingDto>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(preferencesApiProvider).onboarding();
    });
