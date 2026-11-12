import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/subscriptions/application/subscriptions_providers.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';
import 'package:montra_mobile/features/subscriptions/domain/subscription_display.dart';
import 'package:montra_mobile/features/subscriptions/presentation/subscription_widgets.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/subscriptions_fakes.dart';

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations hi = lookupAppLocalizations(const Locale('hi'));

  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  test('actions follow the server lifecycle rules', () {
    expect(subscriptionActionsFor('active'), <SubscriptionAction>[
      SubscriptionAction.verify,
      SubscriptionAction.pause,
      SubscriptionAction.cancellationStarted,
      SubscriptionAction.cancelled,
    ]);
    expect(subscriptionActionsFor('paused'), <SubscriptionAction>[
      SubscriptionAction.verify,
      SubscriptionAction.resume,
      SubscriptionAction.cancellationStarted,
      SubscriptionAction.cancelled,
    ]);
    expect(subscriptionActionsFor('cancellation_pending'), <SubscriptionAction>[
      SubscriptionAction.verify,
      SubscriptionAction.cancelled,
      SubscriptionAction.reactivate,
    ]);
    expect(subscriptionActionsFor('cancelled'), <SubscriptionAction>[
      SubscriptionAction.verify,
      SubscriptionAction.reactivate,
    ]);
    expect(subscriptionActionsFor('something_new'), isEmpty);
  });

  test('confidence reads as a plain strength with a percentage', () {
    expect(detectionConfidence(9200).strength, DetectionStrength.strong);
    expect(detectionConfidence(9200).percent, 92);
    expect(detectionConfidence(7050).strength, DetectionStrength.likely);
    expect(detectionConfidence(6000).strength, DetectionStrength.possible);
    expect(detectionConfidence(14000).percent, 100);
    expect(detectionConfidence(-5).percent, 0);
    expect(
      detectionStrengthText(hi, DetectionStrength.strong, 92),
      'पक्का मेल (92%)',
    );
  });

  test('evidence is explained from its reason codes', () {
    final DetectionCandidateDto c = detectionCandidate(
      reasonCodes: <String>[
        'charge_cadence',
        'intervals_fit_cadence',
        'amounts_within_tolerance',
        'brand_new',
      ],
    );
    expect(detectionEvidenceLines(en, c.evidence), <String>[
      '6 charges, usually 30 days apart',
      '5 of 5 gaps between charges fit this pattern',
      '6 of 6 amounts are within 5% of the usual amount',
      'English evidence brand_new',
    ]);
    expect(detectionEvidenceLines(hi, c.evidence)[1], contains('अंतरालों'));
  });

  group('partial update', () {
    final SubscriptionDetail d = subscriptionDetail(
      json: subscriptionJson(
        frequency: 'custom',
        intervalCount: 10,
        intervalUnit: 'day',
        invoiceFileId: 'file-1',
        groupId: 'grp-home',
        categoryId: 'cat-1',
        trialEndsOn: '2026-11-12',
        notes: 'Family plan',
        checklist: <Map<String, Object?>>[
          <String, Object?>{'item': 'Export', 'done': false},
        ],
        events: <Map<String, Object?>>[],
      ),
    );

    test('an unchanged form sends only the version', () {
      expect(
        subscriptionPatchFor(d, subscriptionFormJson(d)).toJson(),
        <String, Object?>{'version': 3},
      );
    });

    test('changes are sent; emptied text is "" and removed links are '
        'cleared; the invoice is never touched', () {
      final Map<String, Object?> edited =
          <String, Object?>{
            ...subscriptionFormJson(d),
            'name': 'Streamly Plus',
            'cancellation_checklist': <Map<String, Object?>>[
              <String, Object?>{'item': 'Export', 'done': true},
            ],
          }..removeWhere(
            (String k, Object? v) =>
                k == 'notes' || k == 'group_id' || k == 'category_id',
          );
      final Map<String, Object?> body = subscriptionPatchFor(
        d,
        edited,
      ).toJson();
      expect(body['name'], 'Streamly Plus');
      expect(body['notes'], '');
      expect(
        body['clear'],
        unorderedEquals(<String>['category_id', 'group_id']),
      );
      expect(body['cancellation_checklist'], <Object?>[
        <String, Object?>{'done': true, 'item': 'Export'},
      ]);
      expect(body['version'], 3);
      expect(body.containsKey('invoice_file_id'), isFalse);
      expect(body.containsKey('amount'), isFalse);
    });

    test('a new cycle sends the whole cycle; a new currency sends the '
        'price', () {
      final Map<String, Object?> body = subscriptionPatchFor(
        d,
        <String, Object?>{
          ...subscriptionFormJson(d),
          'billing_frequency': 'monthly',
          'currency': 'USD',
        }..removeWhere(
          (String k, Object? v) =>
              k == 'interval_count' || k == 'interval_unit',
        ),
      ).toJson();
      expect(body['billing_frequency'], 'monthly');
      expect(body['currency'], 'USD');
      expect(body['amount'], '499.00');
      expect(body.containsKey('interval_count'), isFalse);
    });

    test('a cancelled subscription can correct its cancellation date', () {
      final SubscriptionDetail cancelled = subscriptionDetail(
        json: subscriptionJson(status: 'cancelled', cancelledOn: '2026-11-01'),
      );
      expect(subscriptionFormJson(cancelled)['cancelled_on'], '2026-11-01');
      expect(
        subscriptionPatchFor(cancelled, <String, Object?>{
          ...subscriptionFormJson(cancelled),
          'cancelled_on': '2026-10-30',
        }).toJson(),
        <String, Object?>{'cancelled_on': '2026-10-30', 'version': 3},
      );
      expect(subscriptionFormJson(d).containsKey('cancelled_on'), isFalse);
    });
  });

  test('payment suggestions and linked payments', () {
    expect(subscriptionCandidateReasons(en, subscriptionCandidate()), <String>[
      'Same merchant',
      'Same amount',
      '1 day before the renewal date',
    ]);
    expect(
      subscriptionCandidateReasons(
        en,
        subscriptionCandidate(
          reasonCodes: <String>['matches_name', 'near_renewal_date', 'x'],
          daysFromRenewal: 3,
        ),
      ),
      <String>[
        'Matches the name',
        '3 days after the renewal date',
        'English x',
      ],
    );
    // Linked payments come from the server (`SubscriptionDetail.payments`).
    final SubscriptionDetail detail = subscriptionDetail(
      json: <String, Object?>{
        'payments': <Object?>[
          <String, Object?>{
            'transaction_id': 'tx-3',
            'amount': <String, Object?>{
              'amount_minor': 64900,
              'amount': '649.00',
              'currency': 'INR',
            },
            'local_date': '2026-11-01',
            'account_name': 'HDFC Savings',
            'linked_at': '2026-11-01T10:00:00Z',
          },
        ],
      },
    );
    expect(detail.payments.single.transactionId, 'tx-3');
    expect(detail.payments.single.accountName, 'HDFC Savings');
  });

  test('labels are localized with safe fallbacks', () {
    expect(
      subscriptionEventText(en, SubscriptionEventKind.priceChanged),
      'Price changed',
    );
    expect(
      subscriptionEventText(en, SubscriptionEventKind.paymentUnlinked),
      'Payment unlinked',
    );
    expect(
      subscriptionEventText(en, SubscriptionEventKind.unrecognized),
      'Updated',
    );
    expect(
      subscriptionEventNote(
        hi,
        SubscriptionEvent.fromJson(
          subscriptionEventJson(
            id: 'e',
            kind: 'payment_recorded',
            note: 'Matched by detection',
            noteCode: 'matched_by_detection',
          ),
        ),
      ),
      hi.subscriptionNoteMatchedByDetection,
    );
    expect(subscriptionStatusText(hi, 'trial'), 'मुफ़्त ट्रायल');
    expect(subscriptionFilterLabel(en, ''), 'Current');
    expect(
      subscriptionFilterLabel(en, 'cancellation_pending'),
      'Being cancelled',
    );
    expect(
      duplicateWarningReason(
        hi,
        DuplicateWarning.fromJson(
          duplicateWarningJson(reasonCode: 'same_name', reason: 'Same name'),
        ),
      ),
      'वही नाम',
    );
    expect(
      duplicateWarningReason(
        en,
        DuplicateWarning.fromJson(
          duplicateWarningJson(
            reasonCode: 'similar_logo',
            reason: 'Similar logo',
          ),
        ),
      ),
      'Similar logo',
    );
    expect(billingCycleText(en, 'custom', 2, 'week'), 'Every 2 weeks');
    expect(billingCycleText(hi, 'yearly', 1, null), 'हर साल');
    expect(
      subscriptionWhenText(
        en,
        status: 'cancelled',
        nextRenewalDate: '2026-11-10',
        trialEndsOn: null,
        locale: 'en',
      ),
      isNull,
    );
    for (final String f in subscriptionListFilters) {
      expect(subscriptionFilterLabel(hi, f), isNotEmpty);
    }
    for (final SubscriptionAction a in SubscriptionAction.values) {
      expect(subscriptionActionText(hi, a), isNotEmpty);
      expect(subscriptionActionDone(hi, a), isNotEmpty);
    }
  });

  test('subscription errors get their own wording', () {
    expect(
      subscriptionErrorText(
        en,
        serverError(
          ErrorObjectCode.domainRuleViolation,
          details: const <Detail>[
            Detail(message: 'x', code: 'subscription_inactive'),
          ],
        ),
      ),
      'Reactivate the subscription before recording new payments.',
    );
    expect(
      subscriptionErrorText(
        en,
        serverError(
          ErrorObjectCode.duplicate,
          status: 409,
          details: const <Detail>[
            Detail(message: 'x', code: 'payment_linked_elsewhere'),
          ],
        ),
      ),
      'This payment is already recorded for another subscription.',
    );
    expect(
      subscriptionErrorText(
        en,
        serverError(ErrorObjectCode.duplicate, status: 409),
      ),
      'This payment is already linked to a subscription.',
    );
    expect(
      subscriptionErrorText(
        en,
        serverError(
          ErrorObjectCode.validationError,
          details: const <Detail>[
            Detail(
              field: 'body.transaction_id',
              message: 'Choose one of your expenses.',
            ),
          ],
        ),
      ),
      'Choose one of your expenses.',
    );
    expect(
      subscriptionErrorText(en, const ApiException(kind: ApiErrorKind.network)),
      en.errorOfflineBody,
    );
  });
}
