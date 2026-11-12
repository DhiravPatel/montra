import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_uploader.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';

ApiException _coded(
  ErrorObjectCode code,
  String detailCode, [
  Map<String, String>? params,
]) => ApiException(
  kind: ApiErrorKind.server,
  code: code,
  message: 'English server text',
  details: <Detail>[
    Detail(code: detailCode, message: 'English detail', params: params),
  ],
);

void main() {
  late AppLocalizations en;
  late AppLocalizations hi;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    hi = await AppLocalizations.delegate.load(const Locale('hi'));
  });

  test('invalid_status_transition names both statuses in the user '
      'language', () {
    final ApiException error = _coded(
      ErrorObjectCode.domainRuleViolation,
      'invalid_status_transition',
      <String, String>{'from': 'archived', 'to': 'paused'},
    );
    expect(
      describeError(en, error),
      "This can't change from archived to paused. Reload to see where it "
      'stands now.',
    );
    expect(describeError(hi, error), contains('संग्रहित'));
    expect(describeError(hi, error), contains('रुका हुआ'));
  });

  test('record_limit_reached is localized for all four resources', () {
    for (final (String resource, String text) in <(String, String)>[
      ('bills', 'You can keep up to 200 open bills.'),
      ('recurring_rules', 'You can keep up to 200 recurring payments.'),
      ('subscriptions', 'You can keep up to 200 subscriptions.'),
      ('goals', 'You can keep up to 200 goals.'),
      ('something_new', 'You can keep up to 200 of these.'),
    ]) {
      final String message = describeError(
        en,
        _coded(
          ErrorObjectCode.domainRuleViolation,
          'record_limit_reached',
          <String, String>{'resource': resource, 'limit': '200'},
        ),
      );
      expect(message, startsWith(text), reason: resource);
      expect(message, endsWith('no longer need.'));
    }
  });

  test('coded conflicts and duplicates are localized; unknown codes fall '
      'back to the server text', () {
    expect(
      describeError(
        en,
        _coded(ErrorObjectCode.conflict, 'name_taken', <String, String>{
          'name': 'Food',
        }),
      ),
      '“Food” is already used. Choose another name.',
    );
    expect(
      describeError(
        en,
        _coded(ErrorObjectCode.conflict, 'name_taken', <String, String>{
          'name': 'Amazon',
          'merchant_id': 'm-1',
        }),
      ),
      'Another merchant is already called “Amazon”. Merge them instead.',
    );
    expect(
      describeError(
        en,
        _coded(ErrorObjectCode.duplicate, 'payment_linked_elsewhere'),
      ),
      'This payment is already recorded for another subscription.',
    );
    expect(
      describeError(
        en,
        _coded(ErrorObjectCode.domainRuleViolation, 'brand_new_rule'),
      ),
      'English detail',
    );
  });

  test('receipt conflicts are localized', () {
    expect(
      describeError(en, _coded(ErrorObjectCode.conflict, 'receipt_discarded')),
      'This receipt was discarded. Restore it first.',
    );
    expect(
      describeError(
        en,
        _coded(ErrorObjectCode.conflict, 'file_in_use', <String, String>{
          'file_id': 'f-1',
          'receipt_id': 'r-2',
        }),
      ),
      'This page is already part of another receipt.',
    );
    expect(
      describeError(
        en,
        _coded(ErrorObjectCode.duplicate, 'transaction_has_receipt'),
      ),
      'That transaction already has a receipt.',
    );
    expect(
      describeError(
        hi,
        _coded(ErrorObjectCode.conflict, 'receipt_not_discarded'),
      ),
      'केवल हटाई गई रसीदें वापस लाई जा सकती हैं।',
    );
  });

  test('the cancellation confirmation detail is explained', () {
    expect(
      describeError(
        en,
        _coded(
          ErrorObjectCode.validationError,
          'cancellation_confirmation_required',
        ),
      ),
      'Confirm that you cancelled with the provider.',
    );
  });

  test('storage quota and file problems use readable sizes', () {
    expect(
      describeError(
        en,
        _coded(
          ErrorObjectCode.domainRuleViolation,
          'storage_quota_exceeded',
          <String, String>{'used_bytes': '1', 'quota_bytes': '1073741824'},
        ),
      ),
      contains('1024 MB storage allowance'),
    );
    expect(
      describeError(
        en,
        const FileRejected(FileProblem.tooLarge, UploadPurpose.receipt),
      ),
      'This file is larger than 15 MB. Choose a smaller file.',
    );
    expect(
      describeError(
        en,
        const FileRejected(
          FileProblem.unsupportedType,
          UploadPurpose.statementImport,
        ),
      ),
      "This file type isn't accepted here. Use CSV, XLSX, OFX.",
    );
  });

  test('every status word is translated', () {
    for (final String status in <String>[
      'active',
      'paused',
      'archived',
      'ended',
      'achieved',
      'cancelled',
      'cancellation_started',
      'trial',
      'voided',
      'pending',
      'posted',
    ]) {
      expect(statusWord(hi, status), isNot(statusWord(en, status)));
    }
    expect(statusWord(en, 'brand_new'), 'brand new');
  });
}
