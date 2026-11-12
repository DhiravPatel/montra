import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/privacy/data/privacy_api.dart';
import 'package:montra_mobile/features/settings/data/limits_api.dart';
import 'package:montra_mobile/features/support/data/support_api.dart';

class MockSupportApi extends Mock implements SupportApi {}

class MockPrivacyApi extends Mock implements PrivacyApi {}

class MockLimitsApi extends Mock implements LimitsApi {}

/// Registers fallback values for `any()` on the support and privacy APIs.
void registerSupportFallbacks() {
  registerFallbackValue(
    const RequestInput(kind: RequestInputKind.support, subject: 'x', body: 'x'),
  );
  registerFallbackValue(
    const ContactInput(
      kind: ContactInputKind.support,
      subject: 'x',
      body: 'x',
      contactEmail: 'a@b.c',
    ),
  );
  registerFallbackValue(MeConsentsGrantRequestConsentType.location);
}

/// A `RequestDTO` as JSON (live shape).
Map<String, Object?> requestJson({
  String id = 'req-1',
  String status = 'open',
  String subject = 'Help with budgets',
  int messages = 0,
}) => <String, Object?>{
  'id': id,
  'reference': 'AD0B4A0D',
  'kind': 'support',
  'subject': subject,
  'body': 'How do I share a budget?',
  'status': status,
  'message_count': messages,
  if (messages > 0) 'last_message_at': '2026-11-12T07:00:00Z',
  'created_at': '2026-11-12T05:59:29Z',
  'updated_at': '2026-11-12T05:59:29Z',
};

/// A `RequestDTO`.
RequestDto supportRequest({
  String id = 'req-1',
  String status = 'open',
  String subject = 'Help with budgets',
  int messages = 0,
}) => RequestDto.fromJson(
  requestJson(id: id, status: status, subject: subject, messages: messages),
);

/// A `MessageDTO`.
MessageDto supportMessage({
  String id = 'msg-1',
  bool staff = false,
  String body = 'Here is more detail.',
}) => MessageDto.fromJson(<String, Object?>{
  'id': id,
  'request_id': 'req-1',
  'author_role': staff ? 'staff' : 'requester',
  'mine': !staff,
  'body': body,
  'created_at': '2026-11-12T07:00:00Z',
});

/// `GET /legal` (live shape).
LegalDto legalDto() => LegalDto.fromJson(<String, Object?>{
  'terms_version': '2026-11-01',
  'privacy_version': '2026-11-01',
  'consents': <Object?>[
    for (final String type in <String>[
      'terms',
      'privacy_policy',
      'ai_processing',
      'ai_receipt_processing',
      'marketing_email',
      'product_analytics',
      'location',
      'contacts_discovery',
      'push_notifications',
    ])
      <String, Object?>{
        'type': type,
        'version': '2026-11-01',
        'required': type == 'terms' || type == 'privacy_policy',
      },
  ],
});

/// A `ConsentDTO`.
ConsentDto consentDto(String type, {String id = 'con-1'}) =>
    ConsentDto.fromJson(<String, Object?>{
      'id': '$id-$type',
      'consent_type': type,
      'version': '2026-11-01',
      'granted_at': '2026-11-12T05:59:28Z',
    });

/// An `ExportDTO`.
ExportDto exportDto({String id = 'exp-1', String status = 'completed'}) =>
    ExportDto.fromJson(<String, Object?>{
      'id': id,
      'status': status,
      'format': 'json_zip',
      'requested_at': '2026-11-12T05:59:29Z',
      if (status == 'completed') ...<String, Object?>{
        'file_id': 'file-exp',
        'completed_at': '2026-11-12T05:59:30Z',
        'expires_at': '2026-11-19T05:59:30Z',
      },
      if (status == 'failed') 'error_code': 'export_failed',
    });

/// A `DeletionDTO` (live shape).
DeletionDto deletionDto({String status = 'none', bool groups = true}) =>
    DeletionDto.fromJson(<String, Object?>{
      'status': status,
      if (status == 'scheduled') ...<String, Object?>{
        'id': 'del-1',
        'requested_at': '2026-11-12T06:00:00Z',
        'scheduled_for': '2026-11-19T06:00:00Z',
      },
      'consequences': <String>[
        'You will be signed out of every device.',
        'Your records will be permanently deleted.',
        'This cannot be undone after the scheduled date.',
      ],
      'consequence_codes': <String>[
        'signed_out_and_integrations_revoked',
        'personal_records_deleted',
        'irreversible_after_date',
      ],
      'retained': <String>['Shared group expense shares stay.', 'New rule'],
      'retained_codes': <String>['shared_group_records_anonymized', 'other'],
      'group_impact': <String>[if (groups) '"Flat 4B" ownership transfers.'],
      'group_impact_details': <Object?>[
        if (groups)
          <String, Object?>{
            'code': 'ownership_transfer',
            'params': <String, String>{
              'group_id': 'g-1',
              'group_name': 'Flat 4B',
              'outcome': 'ownership_transfer',
            },
            'text': '"Flat 4B" ownership transfers.',
          },
      ],
    });

/// `GET /limits` (live shape).
Limits limitsDto({int used = 536870912}) => Limits.fromJson(<String, Object?>{
  'storage_quota_bytes': 2147483648,
  'storage_used_bytes': used,
  'max_upload_bytes': 20971520,
  'import_max_rows': 20000,
  'max_open_recurring_rules': 500,
  'max_open_bills': 200,
  'max_open_subscriptions': 500,
  'max_open_goals': 200,
  'support_requests_per_day': 10,
  'rate_limits': <Object?>[
    <String, Object?>{'policy': 'default', 'per_minute': 600, 'burst': 60},
    <String, Object?>{'policy': 'write', 'per_minute': 240, 'burst': 40},
    <String, Object?>{'policy': 'social', 'per_minute': 30, 'burst': 15},
    <String, Object?>{'policy': 'ai', 'per_minute': 5, 'burst': 5},
  ],
  'deletion_grace_days': 7,
  'export_download_days': 7,
  'ai_requests_per_day': 0,
  'note': 'Every feature is free for everyone.',
  'note_code': 'fair_use_same_for_everyone',
});
