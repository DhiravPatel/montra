import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart';

GroupActivityDto event(
  String kind,
  String entityType, {
  String? entityId = 'ent-1',
  Map<String, Object?> summary = const <String, Object?>{},
}) => GroupActivityDto.fromJson(<String, Object?>{
  'id': 1,
  'kind': kind,
  'entity_type': entityType,
  'entity_id': ?entityId,
  'summary': summary,
  'created_at': '2026-11-12T06:00:00Z',
});

void main() {
  test('activity lines open the record they are about', () {
    expect(
      activityLink('g1', event('expense_added', 'group_expense')),
      '/groups/g1/expenses/ent-1',
    );
    expect(
      activityLink('g1', event('settlement_confirmed', 'settlement')),
      '/groups/g1/settlements/ent-1',
    );
    expect(
      activityLink(
        'g1',
        event('recurring_expense_paused', 'group_recurring_expense'),
      ),
      '/groups/g1/recurring/ent-1',
    );
    expect(activityLink('g1', event('expense_deleted', 'group_expense')), null);
    expect(activityLink('g1', event('member_joined', 'group_member')), null);
  });

  test('resolved disputes open their target; older events are expenses', () {
    expect(
      activityLink(
        'g1',
        event(
          'dispute_resolved',
          'group_dispute',
          summary: <String, Object?>{
            'target': 'set-9',
            'target_type': 'settlement',
          },
        ),
      ),
      '/groups/g1/settlements/set-9',
    );
    expect(
      activityLink(
        'g1',
        event(
          'dispute_withdrawn',
          'group_dispute',
          summary: <String, Object?>{'target': 'exp-9'},
        ),
      ),
      '/groups/g1/expenses/exp-9',
    );
    expect(
      activityLink('g1', event('dispute_resolved', 'group_dispute')),
      null,
    );
  });
}
