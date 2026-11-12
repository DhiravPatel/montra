import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/idempotency.dart';

void main() {
  group('ApiClient.encodeQuery', () {
    test('drops empty values and joins lists with commas', () {
      expect(
        ApiClient.encodeQuery(<String, Object?>{
          'range': 'this_month',
          'from': null,
          'q': '',
          'type': <String>['expense', 'refund'],
          'tag_id': <String>[],
          'account_id': <String?>['a1', null, ''],
          'limit': 50,
          'include_archived': true,
          'include_shared': false,
        }),
        <String, String>{
          'range': 'this_month',
          'type': 'expense,refund',
          'account_id': 'a1',
          'limit': '50',
          'include_archived': 'true',
          'include_shared': 'false',
        },
      );
    });

    test('rejects unsupported values instead of sending them', () {
      expect(
        () => ApiClient.encodeQuery(<String, Object?>{'x': Object()}),
        throwsArgumentError,
      );
    });
  });

  group('Idempotency', () {
    test('keys are random, URL-safe and inside the contract bounds', () {
      final Set<String> keys = <String>{
        for (int i = 0; i < 200; i++) Idempotency.generateKey(),
      };
      expect(keys, hasLength(200));
      for (final String key in keys) {
        expect(
          key.length,
          inInclusiveRange(Idempotency.minLength, Idempotency.maxLength),
        );
        expect(key, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      }
      expect(
        Idempotency.generateKey(Random(1)),
        Idempotency.generateKey(Random(1)),
      );
    });

    test('the same request body keeps its key so retries are replays', () {
      int n = 0;
      final IdempotentSubmission submission = IdempotentSubmission(
        generate: () => 'key-${++n}',
      );
      final Map<String, Object?> body = <String, Object?>{
        'amount': '10.00',
        'account_id': 'a1',
      };
      expect(submission.keyFor(body), 'key-1');
      // Retry after a timeout: same body, same key.
      expect(
        submission.keyFor(<String, Object?>{
          'amount': '10.00',
          'account_id': 'a1',
        }),
        'key-1',
      );
      // The user changed the amount: a different request, a new key.
      expect(
        submission.keyFor(<String, Object?>{
          'amount': '12.00',
          'account_id': 'a1',
        }),
        'key-2',
      );
      submission.reset();
      expect(submission.keyFor(body), 'key-3');
    });
  });
}
