import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/integrations/data/integrations_api.dart';

class MockIntegrationsApi extends Mock implements IntegrationsApi {}

/// A `ProviderInfo` JSON object (live shape).
Map<String, Object?> providerJson({
  String id = 'account_aggregator_in',
  String name = 'Account Aggregator (India)',
  String kind = 'account_aggregator',
  String status = 'unavailable',
  String? statusReason =
      'Needs an approved Account Aggregator partner, FIU registration and '
      'legal review before launch.',
}) => <String, Object?>{
  'id': id,
  'name': name,
  'kind': kind,
  'countries': <String>['IN'],
  'capabilities': <String>['transactions', 'balances'],
  'status': status,
  'status_reason': ?statusReason,
  'consent_purpose':
      'Read your bank transactions and balances to keep Montra up to date',
  'consent_scope': <String>['transactions', 'balances'],
  'consent_days': 365,
};

/// A `ConnectionDTO` JSON object.
Map<String, Object?> connectionJson({
  String id = 'conn-1',
  String provider = 'demo_bank',
  String status = 'connected',
  String? lastSyncAt = '2026-11-10T08:00:00Z',
  String? lastErrorCode,
}) => <String, Object?>{
  'id': id,
  'provider': provider,
  'status': status,
  'consent_scope': <String>['transactions'],
  'consent_purpose': 'Read transactions',
  'consent_granted_at': '2026-11-01T08:00:00Z',
  'consent_expires_at': '2027-11-01T08:00:00Z',
  'linked_account_id': 'acc-1',
  'last_sync_at': ?lastSyncAt,
  'last_sync_status': 'succeeded',
  'last_error_code': ?lastErrorCode,
  'created_at': '2026-11-01T08:00:00Z',
};

/// An `Overview`.
Overview overview({
  List<Map<String, Object?>>? providers,
  List<Map<String, Object?>> connections = const <Map<String, Object?>>[],
}) => Overview.fromJson(<String, Object?>{
  'providers': providers ?? <Object?>[providerJson()],
  'connections': connections,
  'note':
      'Montra works fully without connections: add transactions manually '
      'or import statements.',
});

/// A `ConnectionStatus` with one sync run.
ConnectionStatus connectionStatus({String status = 'connected'}) =>
    ConnectionStatus.fromJson(<String, Object?>{
      ...connectionJson(status: status),
      'runs': <Object?>[
        <String, Object?>{
          'id': 'run-1',
          'status': 'partial',
          'trigger': 'manual',
          'items_fetched': 12,
          'items_created': 10,
          'items_updated': 1,
          'items_skipped': 1,
          'error_code': 'provider_unavailable',
          'created_at': '2026-11-10T08:00:00Z',
        },
      ],
    });
