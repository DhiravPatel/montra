import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/moderation/data/moderation_api.dart';

class MockModerationApi extends Mock implements ModerationApi {}

/// Registers fallback values for the moderation screens' `any()` matchers.
void registerModerationFallbacks() {
  registerFallbackValue(
    const ModerationReportInput(
      reason: ModerationReportInputReason.spam,
      targetId: 'x',
      targetType: ModerationReportInputTargetType.comment,
    ),
  );
}

/// A report the user filed (their own view: no preview or post).
ModerationReportDto myReport({String status = 'dismissed'}) =>
    ModerationReportDto.fromJson(<String, Object?>{
      'id': 'rep-9',
      'target_type': 'post',
      'target_id': 'post-9',
      'community_id': 'com-1',
      'reason': 'spam',
      'status': status,
      'open_reports': 0,
      'created_at': '2026-11-05T08:00:00Z',
    });
