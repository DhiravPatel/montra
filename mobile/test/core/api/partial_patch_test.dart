import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';

void main() {
  group('partialPatch', () {
    test('sends only changed fields plus the version', () {
      final Map<String, Object?> patch = partialPatch(
        before: <String, Object?>{
          'name': 'Rent',
          'expected_amount': '1000.00',
          'version': 3,
        },
        after: <String, Object?>{
          'name': 'Rent',
          'expected_amount': '1200.00',
          'version': 3,
        },
      );
      expect(patch, <String, Object?>{
        'expected_amount': '1200.00',
        'version': 3,
      });
      expect(patchHasChanges(patch), isTrue);
    });

    test('clears emptied fields: text with "", lists with [], references '
        'through clear', () {
      final Map<String, Object?> patch = partialPatch(
        before: <String, Object?>{
          'notes': 'Old note',
          'reminder_days_before': <int>[1, 3],
          'category_id': 'cat-1',
          'payment_account_id': 'acc-1',
          'max_occurrences': 12,
          'version': 2,
        },
        after: <String, Object?>{'version': 2},
        clearable: <String>{'category_id', 'max_occurrences'},
        textFields: <String>{'notes'},
      );
      expect(patch, <String, Object?>{
        'notes': '',
        'reminder_days_before': <Object?>[],
        'version': 2,
        'clear': unorderedEquals(<String>['category_id', 'max_occurrences']),
      });
    });

    test('never sends a value and a clear for the same field', () {
      final Map<String, Object?> patch = partialPatch(
        before: <String, Object?>{'category_id': 'a'},
        after: <String, Object?>{'category_id': 'b'},
        clearable: <String>{'category_id'},
      );
      expect(patch, <String, Object?>{'category_id': 'b'});
    });

    test('a changed group member sends the whole group', () {
      final Map<String, Object?> patch = partialPatch(
        before: <String, Object?>{
          'frequency': 'monthly',
          'by_month_day': 5,
          'interval_count': 1,
          'start_date': '2026-11-01',
        },
        after: <String, Object?>{
          'frequency': 'weekly',
          'interval_count': 1,
          'start_date': '2026-11-01',
        },
        clearable: <String>{'by_month_day'},
        together: <Set<String>>[
          <String>{'frequency', 'interval_count', 'by_month_day'},
        ],
      );
      expect(patch, <String, Object?>{
        'frequency': 'weekly',
        'interval_count': 1,
        'clear': <String>['by_month_day'],
      });
    });

    test('nothing changed means only the version', () {
      final Map<String, Object?> patch = partialPatch(
        before: <String, Object?>{
          'name': 'Gym',
          'tags': <String>['a'],
          'version': 1,
        },
        after: <String, Object?>{
          'name': 'Gym',
          'tags': <String>['a'],
          'version': 1,
        },
      );
      expect(patch, <String, Object?>{'version': 1});
      expect(patchHasChanges(patch), isFalse);
    });
  });
}
