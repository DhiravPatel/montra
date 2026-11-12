import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/insights/data/insights_api.dart';

class MockInsightsApi extends Mock implements InsightsApi {}

/// Registers fallback values for `any()` on [MockInsightsApi].
void registerInsightFeatureFallbacks() {
  registerFallbackValue(ActionInputAction.dismiss);
  registerFallbackValue(FeedbackInputFeedback.helpful);
}

Map<String, Object?> _money(String amount, int minor) => <String, Object?>{
  'amount_minor': minor,
  'amount': amount,
  'currency': 'INR',
};

/// An `InsightDTO` JSON object shaped like the server's `unusual_amount`
/// rule (`backend/internal/insights/insights.go`).
Map<String, Object?> insightJson({
  String id = 'ins-1',
  String status = 'active',
  String severity = 'notice',
  String? messageCode = 'unusual_amount',
  Map<String, Object?>? params,
  Map<String, Object?>? feedback,
  String? snoozedUntil,
}) => <String, Object?>{
  'id': id,
  'kind': 'anomaly',
  'subtype': 'unusual_amount',
  'title': 'Unusually large Groceries expense',
  'body': 'English body from the server.',
  'severity': severity,
  'confidence': 0.6,
  'evidence': <String, Object?>{
    'transaction_id': 'tx-1',
    'amount': '4500.00 INR',
    'rule': 'amount ≥ 3× median and above the 95th percentile',
    'amounts': <String, Object?>{
      'amount': _money('4500.00', 450000),
      'baseline_median': _money('1200.00', 120000),
    },
  },
  'source': 'rules',
  'status': status,
  'rule_code': 'amount_3x_median_above_p95',
  'message_code': ?messageCode,
  'message_params':
      params ??
      <String, Object?>{
        'transaction_id': 'tx-1',
        'label': 'Fresh Mart',
        'category_id': 'cat-1',
        'category_name': 'Groceries',
        'local_date': '2026-11-03',
        'amount': _money('4500.00', 450000),
        'baseline_median': _money('1200.00', 120000),
        'ratio': '3.8',
        'history_count': 12,
        'window_months': 6,
      },
  'my_feedback': ?feedback,
  'snoozed_until': ?snoozedUntil,
  'period_start': '2026-11-03',
  'period_end': '2026-11-03',
  'created_at': '2026-11-04T10:00:00Z',
};

/// An `InsightDTO`.
InsightDto insight({
  String id = 'ins-1',
  String status = 'active',
  String severity = 'notice',
  String? messageCode = 'unusual_amount',
  Map<String, Object?>? params,
  Map<String, Object?>? feedback,
}) => InsightDto.fromJson(
  insightJson(
    id: id,
    status: status,
    severity: severity,
    messageCode: messageCode,
    params: params,
    feedback: feedback,
  ),
);

/// One page of insights.
CursorPage<InsightDto> insightPage(List<InsightDto> items, {String? next}) =>
    CursorPage<InsightDto>(items, next);

/// An `InsightMuteDTO`.
InsightMuteDto insightMute({
  String subtype = 'unusual_amount',
  String scope = '*',
}) => InsightMuteDto.fromJson(<String, Object?>{
  'subtype': subtype,
  'scope': scope,
  'created_at': '2026-11-05T10:00:00Z',
});
