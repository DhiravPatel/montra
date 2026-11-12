import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/moderation/data/moderation_api.dart';

/// Decisions about the user (warnings, removals, restrictions, bans) with
/// the state of their appeal.
final FutureProvider<List<ModerationActionDto>> myModerationProvider =
    FutureProvider.autoDispose<List<ModerationActionDto>>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(moderationApiProvider).myModeration();
    });

/// The user's appeals, newest first.
final FutureProvider<List<ModerationAppealDto>> myAppealsProvider =
    FutureProvider.autoDispose<List<ModerationAppealDto>>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(moderationApiProvider).myAppeals();
    });

/// Reports the user filed.
final FutureProvider<List<ModerationReportDto>> myReportsProvider =
    FutureProvider.autoDispose<List<ModerationReportDto>>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(moderationApiProvider).myReports();
    });
