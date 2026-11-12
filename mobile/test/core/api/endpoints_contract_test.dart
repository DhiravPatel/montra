import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/config/app_config.dart';

import '../../../tool/gen_api.dart' as gen;
import '../../helpers/fakes.dart';

/// Checks the app's requests and assumptions against the OpenAPI contract:
/// every endpoint exists with the same method and auth requirement, sends
/// the declared client headers, and documents the error statuses the app
/// handles specifically.
void main() {
  final Map<String, Object?> spec = jsonDecode(
    File(gen.contractPath).readAsStringSync(),
  ) as Map<String, Object?>;
  final Map<String, Object?> paths = spec['paths']! as Map<String, Object?>;
  final Map<String, Object?> components =
      spec['components']! as Map<String, Object?>;

  Map<String, Object?> operationOf(ApiEndpoint endpoint) {
    final Map<String, Object?> item =
        paths[endpoint.path]! as Map<String, Object?>;
    return item[endpoint.method.toLowerCase()]! as Map<String, Object?>;
  }

  Set<String> parameterRefs(Map<String, Object?> operation) => <String>{
    for (final Object? p in (operation['parameters'] as List<Object?>?) ?? [])
      if (p is Map<String, Object?> && p[r'$ref'] is String)
        p[r'$ref']! as String,
  };

  Map<String, Object?> responsesOf(ApiEndpoint endpoint) =>
      operationOf(endpoint)['responses']! as Map<String, Object?>;

  test('the contract is served under /api/v1', () {
    final List<Object?> servers = spec['servers']! as List<Object?>;
    expect((servers.first! as Map<String, Object?>)['url'], '/api/v1');
  });

  for (final ApiEndpoint endpoint in ApiEndpoints.all) {
    test('$endpoint exists in the contract', () {
      final Object? item = paths[endpoint.path];
      expect(item, isA<Map<String, Object?>>(), reason: 'path not found');
      final Object? operation =
          (item! as Map<String, Object?>)[endpoint.method.toLowerCase()];
      expect(
        operation,
        isA<Map<String, Object?>>(),
        reason: 'method not found',
      );
      final Object? security = (operation! as Map<String, Object?>)['security'];
      final bool protected = security is List<Object?> && security.isNotEmpty;
      expect(protected, endpoint.requiresAuth, reason: 'auth requirement');
    });
  }

  test('endpoint list has no duplicates', () {
    expect(ApiEndpoints.all.toSet(), hasLength(ApiEndpoints.all.length));
  });

  group('idempotency', () {
    bool requiresIdempotencyKey(Map<String, Object?> operation) {
      for (final Object? p
          in (operation['parameters'] as List<Object?>?) ?? []) {
        if (p is Map<String, Object?> &&
            p['in'] == 'header' &&
            p['name'] == 'Idempotency-Key') {
          return p['required'] == true;
        }
      }
      return false;
    }

    for (final ApiEndpoint endpoint in ApiEndpoints.all) {
      test('$endpoint idempotent flag matches the contract', () {
        expect(
          endpoint.idempotent,
          requiresIdempotencyKey(operationOf(endpoint)),
          reason: 'Idempotency-Key requirement',
        );
      });
    }

    test('the client sends Idempotency-Key and comma-joins array queries '
        '(explode: false)', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (RequestOptions o) async => jsonResponse(200, envelope(<Object?>[])),
      );
      final ApiClient client = ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      );
      await client.send(
        ApiEndpoints.listTransactions,
        query: <String, Object?>{
          'type': <String>['expense', 'refund'],
          'q': '',
          'cursor': null,
          'limit': 50,
          'include_shared': false,
        },
        headers: const <String, String>{'Idempotency-Key': 'key-12345678'},
        decode: (_) => null,
      );
      final RequestOptions sent = adapter.requests.single;
      expect(sent.uri.queryParameters, <String, String>{
        'type': 'expense,refund',
        'limit': '50',
        'include_shared': 'false',
      });
      expect(sent.headers['Idempotency-Key'], 'key-12345678');
    });

    test('array query parameters are declared with explode: false', () {
      final Map<String, Object?> op = operationOf(
        ApiEndpoints.listTransactions,
      );
      for (final Object? p in op['parameters']! as List<Object?>) {
        if (p is Map<String, Object?> &&
            (p['schema'] as Map<String, Object?>?)?['items'] != null) {
          expect(p['explode'], isFalse, reason: '${p['name']}');
        }
      }
    });
  });

  group('client headers', () {
    test('every called operation declares X-Montra-Client and '
        'X-Client-Version', () {
      for (final ApiEndpoint endpoint in ApiEndpoints.all) {
        expect(
          parameterRefs(operationOf(endpoint)),
          containsAll(<String>[
            '#/components/parameters/MontraClient',
            '#/components/parameters/ClientVersion',
          ]),
          reason: '$endpoint',
        );
      }
    });

    test('the values the app sends are allowed by the contract', () {
      final Map<String, Object?> parameters =
          components['parameters']! as Map<String, Object?>;
      final Map<String, Object?> client =
          parameters['MontraClient']! as Map<String, Object?>;
      expect(client['name'], 'X-Montra-Client');
      final List<Object?> allowed =
          (client['schema']! as Map<String, Object?>)['enum']! as List<Object?>;
      expect(allowed, containsAll(AppConfig.declaredClientKinds));
      expect(
        (parameters['ClientVersion']! as Map<String, Object?>)['name'],
        'X-Client-Version',
      );
    });

    test('X-CSRF-Token is optional (cookie sessions only; the app uses '
        'bearer tokens)', () {
      final Map<String, Object?> csrf =
          (components['parameters']! as Map<String, Object?>)['CSRFToken']!
              as Map<String, Object?>;
      expect(csrf['name'], 'X-CSRF-Token');
      expect(csrf['required'], isNot(true));
    });

    test('the Dio client sends the declared headers, and omits the client '
        'kind on platforms the contract does not list', () async {
      Future<RequestOptions> sentWith(AppConfig config) async {
        final FakeHttpAdapter adapter = FakeHttpAdapter(
          (RequestOptions o) async => jsonResponse(200, envelope(<Object?>[])),
        );
        await ApiClient(
          createApiDio(config, adapter: adapter, enableLogging: false),
        ).send(ApiEndpoints.listCurrencies, decode: (_) => null);
        return adapter.requests.single;
      }

      final RequestOptions android = await sentWith(testConfig);
      expect(android.headers['X-Montra-Client'], 'android');
      expect(android.headers['X-Client-Version'], '1.0.0+1');

      final RequestOptions desktop = await sentWith(
        AppConfig.resolve(
          apiBaseUrl: 'http://localhost:8080',
          platform: TargetPlatform.linux,
          releaseMode: false,
          clientVersion: '1.0.0+1',
        ),
      );
      expect(desktop.headers.containsKey('X-Montra-Client'), isFalse);
      expect(desktop.headers['X-Client-Version'], '1.0.0+1');
    });
  });

  group('responses', () {
    // Statuses the app branches on; if the contract stops declaring one, the
    // matching UI path needs a second look.
    final Map<ApiEndpoint, Set<String>> handled = <ApiEndpoint, Set<String>>{
      ApiEndpoints.login: <String>{'200', '401', '403', '422', '429'},
      ApiEndpoints.verifyMfa: <String>{'200', '401', '429'},
      ApiEndpoints.register: <String>{'202', '403', '422', '429'},
      ApiEndpoints.verifyEmail: <String>{'200', '410', '422'},
      ApiEndpoints.resetPassword: <String>{'200', '410', '422'},
      ApiEndpoints.forgotPassword: <String>{'202', '422', '429'},
      ApiEndpoints.resendVerification: <String>{'202', '429'},
      ApiEndpoints.refresh: <String>{'200', '401', '429'},
      ApiEndpoints.reauthenticate: <String>{'200', '401', '429'},
      ApiEndpoints.listSessions: <String>{'200', '401', '403'},
      ApiEndpoints.revokeSession: <String>{'200', '404'},
      ApiEndpoints.changePassword: <String>{'200', '422'},
      ApiEndpoints.totpSetup: <String>{'200', '401', '409'},
      ApiEndpoints.totpActivate: <String>{'200', '409', '422'},
      ApiEndpoints.totpDisable: <String>{'200', '401'},
      ApiEndpoints.regenerateRecoveryCodes: <String>{'200', '401', '409'},
      ApiEndpoints.listCurrencies: <String>{'200'},
      ApiEndpoints.getPreferences: <String>{'200', '401'},
      ApiEndpoints.updatePreferences: <String>{'200', '422'},
      ApiEndpoints.recordOnboarding: <String>{'200', '422'},
      ApiEndpoints.dashboardSummary: <String>{'200', '422'},
      ApiEndpoints.dashboardWidgets: <String>{'200'},
      ApiEndpoints.updateDashboardWidgets: <String>{'200', '422'},
      ApiEndpoints.listAccounts: <String>{'200', '401', '403'},
      ApiEndpoints.createAccount: <String>{'201', '409', '422', '429'},
      ApiEndpoints.getAccount: <String>{'200', '404'},
      ApiEndpoints.updateAccount: <String>{'200', '404', '409', '422'},
      ApiEndpoints.adjustAccount: <String>{'201', '409', '422'},
      ApiEndpoints.archiveAccount: <String>{'200', '409'},
      ApiEndpoints.restoreAccount: <String>{'200', '409'},
      ApiEndpoints.closeAccount: <String>{'200', '409', '422'},
      ApiEndpoints.accountBalance: <String>{'200', '422'},
      ApiEndpoints.accountTransactions: <String>{'200', '404'},
      ApiEndpoints.listPaymentMethods: <String>{'200'},
      ApiEndpoints.createPaymentMethod: <String>{'201', '422'},
      ApiEndpoints.updatePaymentMethod: <String>{'200', '404', '422'},
      ApiEndpoints.deletePaymentMethod: <String>{'200', '404'},
      ApiEndpoints.listCategories: <String>{'200'},
      ApiEndpoints.listTags: <String>{'200'},
      ApiEndpoints.listMerchants: <String>{'200'},
      ApiEndpoints.listTransactions: <String>{'200', '422'},
      ApiEndpoints.searchTransactions: <String>{'200', '422'},
      ApiEndpoints.createTransaction: <String>{'201', '409', '422'},
      ApiEndpoints.getTransaction: <String>{'200', '404'},
      ApiEndpoints.updateTransaction: <String>{'200', '404', '409', '422'},
      ApiEndpoints.deleteTransaction: <String>{'200', '404', '422'},
      ApiEndpoints.restoreTransaction: <String>{'200', '409', '422'},
      ApiEndpoints.duplicateTransaction: <String>{'201', '409', '422'},
      ApiEndpoints.refundTransaction: <String>{'201', '409', '422'},
      ApiEndpoints.transactionAudit: <String>{'200', '404'},
      ApiEndpoints.transactionAttachments: <String>{'200', '404'},
      ApiEndpoints.detachAttachment: <String>{'200', '404'},
      ApiEndpoints.bulkUpdateTransactions: <String>{'200', '422'},
      ApiEndpoints.bulkDeleteTransactions: <String>{'200', '422'},
      ApiEndpoints.createTransfer: <String>{'201', '409', '422'},
      ApiEndpoints.getTransfer: <String>{'200', '404'},
      // Round 3.
      ApiEndpoints.pauseBill: <String>{'200', '409', '422'},
      ApiEndpoints.resumeBill: <String>{'200', '409', '422'},
      ApiEndpoints.archiveBill: <String>{'200', '409', '422'},
      ApiEndpoints.restoreBill: <String>{'200', '409', '422'},
      ApiEndpoints.restoreBudget: <String>{'200', '409', '422'},
      ApiEndpoints.getCategory: <String>{'200', '404'},
      ApiEndpoints.applySavedCategoryRule: <String>{'200', '404', '422'},
      ApiEndpoints.removeMerchantAlias: <String>{'200', '404', '422'},
      ApiEndpoints.previewMerchantMerge: <String>{'200', '404', '422'},
      ApiEndpoints.subscriptionPaymentCandidates: <String>{'200', '404'},
      ApiEndpoints.unlinkSubscriptionPayment: <String>{'200', '404'},
      ApiEndpoints.updateSubscriptionChecklistItem: <String>{
        '200',
        '404',
        '409',
        '422',
      },
      ApiEndpoints.recordGoalContribution: <String>{'200', '409', '422'},
      ApiEndpoints.getLimits: <String>{'200'},
      ApiEndpoints.createUploadIntent: <String>{'201', '422', '503'},
      ApiEndpoints.uploadFileContent: <String>{'200', '409', '422'},
      ApiEndpoints.completeFileUpload: <String>{'200', '409'},
      ApiEndpoints.getFile: <String>{'200', '404'},
      ApiEndpoints.fileAccess: <String>{'200', '404'},
      ApiEndpoints.downloadFile: <String>{'200'},
      ApiEndpoints.deleteFile: <String>{'200', '404'},
      ApiEndpoints.addAttachment: <String>{'200', '404', '422'},
      ApiEndpoints.listReceipts: <String>{'200'},
      ApiEndpoints.createReceipt: <String>{'201', '422'},
      ApiEndpoints.getReceipt: <String>{'200', '404'},
      ApiEndpoints.reviewReceipt: <String>{'200', '409', '422'},
      ApiEndpoints.receiptMatchCandidates: <String>{'200', '404'},
      ApiEndpoints.matchReceipt: <String>{'200', '409', '422'},
      ApiEndpoints.receiptCreateTransaction: <String>{'201', '409', '422'},
      ApiEndpoints.unlinkReceipt: <String>{'200', '409'},
      ApiEndpoints.discardReceipt: <String>{'200', '409'},
      ApiEndpoints.listImports: <String>{'200'},
      ApiEndpoints.createImport: <String>{'201', '409', '422'},
      ApiEndpoints.getImport: <String>{'200', '404'},
      ApiEndpoints.updateImportMapping: <String>{'200', '409', '422'},
      ApiEndpoints.importRows: <String>{'200', '404'},
      ApiEndpoints.updateImportRow: <String>{'200', '409', '422'},
      ApiEndpoints.confirmImport: <String>{'202', '409', '422'},
      ApiEndpoints.cancelImport: <String>{'200', '409'},
      ApiEndpoints.retryFailedImport: <String>{'200', '409'},
      ApiEndpoints.rollbackImport: <String>{'200', '409'},
      ApiEndpoints.listReconciliations: <String>{'200', '404'},
      ApiEndpoints.createReconciliation: <String>{'201', '404', '422'},
      ApiEndpoints.reconciliationCandidates: <String>{'200', '404'},
      ApiEndpoints.listReconciliationMatches: <String>{'200', '404'},
      ApiEndpoints.createReconciliationMatch: <String>{'201', '409', '422'},
      ApiEndpoints.deleteReconciliationMatch: <String>{'200', '404', '409'},
      ApiEndpoints.analyticsCashFlow: <String>{'200', '422'},
      ApiEndpoints.analyticsCategories: <String>{'200', '422'},
      ApiEndpoints.analyticsExpenses: <String>{'200', '422'},
      ApiEndpoints.analyticsIncome: <String>{'200', '422'},
      ApiEndpoints.analyticsMerchants: <String>{'200', '422'},
      ApiEndpoints.analyticsBudgets: <String>{'200'},
      ApiEndpoints.analyticsGoals: <String>{'200'},
      ApiEndpoints.analyticsSubscriptions: <String>{'200'},
      ApiEndpoints.analyticsRecurring: <String>{'200'},
      ApiEndpoints.analyticsCompare: <String>{'200', '422'},
      ApiEndpoints.listReports: <String>{'200'},
      ApiEndpoints.createReport: <String>{'202', '422', '429'},
      ApiEndpoints.getReport: <String>{'200', '404'},
      ApiEndpoints.downloadReport: <String>{'200', '404', '410'},
      ApiEndpoints.listReportSchedules: <String>{'200'},
      ApiEndpoints.createReportSchedule: <String>{'201', '422'},
      ApiEndpoints.deleteReportSchedule: <String>{'200', '404'},
      ApiEndpoints.listFxRates: <String>{'200', '422'},
      ApiEndpoints.setFxRate: <String>{'201', '422'},
      ApiEndpoints.deleteFxRate: <String>{'200', '404'},
      ApiEndpoints.convertFx: <String>{'200', '404', '422'},
      // Round 4 (adoption).
      ApiEndpoints.restoreReceipt: <String>{'200', '409'},
      ApiEndpoints.deleteReport: <String>{'200', '404'},
      ApiEndpoints.updateReportSchedule: <String>{'200', '404', '409', '422'},
      ApiEndpoints.accountStatementLines: <String>{'200', '404', '422'},
      ApiEndpoints.getTag: <String>{'200', '404'},
      ApiEndpoints.getCategoryRule: <String>{'200', '404'},
      ApiEndpoints.listBudgetAlerts: <String>{'200'},
      // Rounds 4–5: friends, groups, communities, challenges, moderation.
      ApiEndpoints.sendFriendRequest: <String>{'201', '409', '422'},
      ApiEndpoints.acceptFriendRequest: <String>{'200', '409', '422'},
      ApiEndpoints.declineFriendRequest: <String>{'200', '409', '422'},
      ApiEndpoints.cancelFriendRequest: <String>{'200', '409', '422'},
      ApiEndpoints.removeFriend: <String>{'200', '404'},
      ApiEndpoints.blockUser: <String>{'200', '404'},
      ApiEndpoints.unblockUser: <String>{'200', '404'},
      ApiEndpoints.muteUser: <String>{'200', '404'},
      ApiEndpoints.searchUsers: <String>{'200', '422'},
      ApiEndpoints.listBlocks: <String>{'200'},
      ApiEndpoints.listMutes: <String>{'200'},
      ApiEndpoints.updateProfile: <String>{'200', '409', '422'},
      ApiEndpoints.previewGroupInvitation: <String>{'200', '409', '410'},
      ApiEndpoints.acceptGroupInvitationLink: <String>{
        '200',
        '202',
        '409',
        '410',
      },
      ApiEndpoints.acceptGroupInvitation: <String>{'409', '410'},
      ApiEndpoints.declineGroupInvitation: <String>{'409', '410'},
      ApiEndpoints.updateGroup: <String>{'200', '409', '422'},
      ApiEndpoints.archiveGroup: <String>{'200', '409'},
      ApiEndpoints.restoreGroup: <String>{'200', '409'},
      ApiEndpoints.deleteGroup: <String>{'200', '422'},
      ApiEndpoints.removeGroupMember: <String>{'200', '422'},
      ApiEndpoints.addGroupMember: <String>{'409', '422'},
      ApiEndpoints.createGroupJoinRequest: <String>{'409'},
      ApiEndpoints.previewCommunityInvitation: <String>{'200', '409', '410'},
      ApiEndpoints.acceptCommunityInvitationLink: <String>{'200', '409', '410'},
      ApiEndpoints.declineCommunityInvitation: <String>{'200', '409'},
      ApiEndpoints.revokeCommunityInvitation: <String>{'200', '409'},
      ApiEndpoints.updateCommunity: <String>{'200', '409', '422'},
      ApiEndpoints.createCommunity: <String>{'201', '409', '422', '429'},
      ApiEndpoints.createCommunityPost: <String>{'201', '422', '429'},
      ApiEndpoints.votePoll: <String>{'200', '422'},
      ApiEndpoints.communityModerationAct: <String>{'200', '422'},
      ApiEndpoints.decideModerationAppeal: <String>{'200', '422'},
      ApiEndpoints.challengeLeaderboard: <String>{'200', '422'},
      ApiEndpoints.recordChallengeProgress: <String>{'200', '422'},
      ApiEndpoints.joinChallenge: <String>{'200', '422'},
      ApiEndpoints.joinCommunity: <String>{'200', '422'},
      ApiEndpoints.appealModerationAction: <String>{'201', '409', '422'},
      ApiEndpoints.updateChallenge: <String>{'200', '409', '422'},
      ApiEndpoints.createChallenge: <String>{'201', '422', '429'},
      ApiEndpoints.getCommunity: <String>{'200', '404'},
      ApiEndpoints.reportPost: <String>{'201', '409', '429'},
      // Round 4: group money.
      ApiEndpoints.listGroupExpenses: <String>{'200', '422'},
      ApiEndpoints.createGroupExpense: <String>{'201', '409', '422'},
      ApiEndpoints.updateGroupExpense: <String>{'200', '409', '422'},
      ApiEndpoints.deleteGroupExpense: <String>{'200', '403', '409'},
      ApiEndpoints.getGroupExpense: <String>{'200', '404'},
      ApiEndpoints.commentGroupExpense: <String>{'201', '422'},
      ApiEndpoints.disputeGroupExpense: <String>{'201', '422'},
      ApiEndpoints.resolveGroupDispute: <String>{'200', '403', '422'},
      ApiEndpoints.recordGroupExpense: <String>{'200', '409', '422'},
      ApiEndpoints.groupBalances: <String>{'200', '404'},
      ApiEndpoints.groupSettlementSuggestions: <String>{'200'},
      ApiEndpoints.listGroupSettlements: <String>{'200'},
      ApiEndpoints.getGroupSettlement: <String>{'200', '404'},
      ApiEndpoints.createGroupSettlement: <String>{'201', '422'},
      ApiEndpoints.correctGroupSettlement: <String>{'201', '409', '422'},
      ApiEndpoints.confirmGroupSettlement: <String>{'200', '403', '409', '422'},
      ApiEndpoints.disputeGroupSettlement: <String>{'200', '403', '409', '422'},
      ApiEndpoints.markGroupSettlementPaid: <String>{
        '200',
        '403',
        '409',
        '422',
      },
      ApiEndpoints.recordGroupSettlement: <String>{'200', '403', '409', '422'},
      ApiEndpoints.unlinkGroupSettlement: <String>{'200', '403', '409', '422'},
      ApiEndpoints.voidGroupSettlement: <String>{'200', '403', '409', '422'},
      ApiEndpoints.listGroupRecurring: <String>{'200'},
      ApiEndpoints.getGroupRecurring: <String>{'200', '404'},
      ApiEndpoints.createGroupRecurring: <String>{'201', '422'},
      ApiEndpoints.updateGroupRecurring: <String>{'200', '409', '422'},
      ApiEndpoints.pauseGroupRecurring: <String>{'200', '403', '409'},
      ApiEndpoints.resumeGroupRecurring: <String>{'200', '403', '409'},
      ApiEndpoints.stopGroupRecurring: <String>{'200', '403', '409'},
      ApiEndpoints.addGroupRecurringOccurrence: <String>{'201', '409', '422'},
      ApiEndpoints.skipGroupRecurringOccurrence: <String>{'200', '403', '409'},
      ApiEndpoints.groupReports: <String>{'200', '422'},
      ApiEndpoints.exportGroup: <String>{'200', '404'},
      // Rounds 4–5: help, support, privacy and data.
      ApiEndpoints.listSupportRequests: <String>{'200'},
      ApiEndpoints.createSupportRequest: <String>{'201', '422', '429'},
      ApiEndpoints.getSupportRequest: <String>{'200', '404'},
      ApiEndpoints.supportRequestMessages: <String>{'200', '404'},
      ApiEndpoints.createSupportRequestMessage: <String>{
        '201',
        '404',
        '422',
        '429',
      },
      ApiEndpoints.contactSupport: <String>{'202', '422', '429'},
      ApiEndpoints.legal: <String>{'200'},
      ApiEndpoints.listConsents: <String>{'200'},
      ApiEndpoints.grantConsent: <String>{'201', '422'},
      ApiEndpoints.revokeConsent: <String>{'200', '422'},
      ApiEndpoints.requestExport: <String>{'202', '401', '429'},
      ApiEndpoints.listExports: <String>{'200'},
      ApiEndpoints.getExport: <String>{'200', '404'},
      ApiEndpoints.deactivateAccount: <String>{'200', '401'},
      ApiEndpoints.deletionStatus: <String>{'200'},
      ApiEndpoints.requestDeletion: <String>{'200', '401', '409', '422'},
      ApiEndpoints.cancelDeletion: <String>{'200', '409'},
      // Rounds 4–5: notifications, integrations, search and insights.
      ApiEndpoints.listNotifications: <String>{'200'},
      ApiEndpoints.updateNotification: <String>{'200', '404'},
      ApiEndpoints.readAllNotifications: <String>{'200'},
      ApiEndpoints.unreadNotificationCount: <String>{'200'},
      ApiEndpoints.notificationPreferences: <String>{'200'},
      ApiEndpoints.updateNotificationPreferences: <String>{'200', '422'},
      ApiEndpoints.listIntegrations: <String>{'200'},
      ApiEndpoints.connectIntegration: <String>{'201', '422', '503'},
      ApiEndpoints.integrationStatus: <String>{'200', '404'},
      ApiEndpoints.syncIntegration: <String>{'202', '409', '422'},
      ApiEndpoints.disconnectIntegration: <String>{'200', '404', '422'},
      ApiEndpoints.search: <String>{'200', '422'},
      ApiEndpoints.recentSearches: <String>{'200'},
      ApiEndpoints.clearRecentSearches: <String>{'200'},
      ApiEndpoints.listInsights: <String>{'200'},
      ApiEndpoints.actOnInsight: <String>{'200', '404'},
      ApiEndpoints.insightFeedback: <String>{'200', '404'},
      ApiEndpoints.listInsightMutes: <String>{'200'},
      ApiEndpoints.unmuteInsights: <String>{'200', '404', '422'},
    };

    for (final MapEntry<ApiEndpoint, Set<String>> entry in handled.entries) {
      test('${entry.key} documents ${entry.value.join(', ')}', () {
        expect(responsesOf(entry.key).keys, containsAll(entry.value));
      });
    }

    test('errors use the standard envelope, 429s declare Retry-After and '
        'every response declares X-Request-ID', () {
      for (final ApiEndpoint endpoint in ApiEndpoints.all) {
        for (final MapEntry<String, Object?> response in responsesOf(
          endpoint,
        ).entries) {
          final Map<String, Object?> body =
              response.value! as Map<String, Object?>;
          final Map<String, Object?> headers =
              (body['headers'] as Map<String, Object?>?) ?? <String, Object?>{};
          expect(
            headers.keys,
            contains('X-Request-ID'),
            reason: '$endpoint ${response.key}',
          );
          if (response.key == '429') {
            expect(headers.keys, contains('Retry-After'), reason: '$endpoint');
          }
          if (int.parse(response.key) >= 400) {
            final Object? schema =
                ((body['content']! as Map<String, Object?>)['application/json']!
                    as Map<String, Object?>)['schema'];
            expect(schema, <String, Object?>{
              r'$ref': '#/components/schemas/ErrorResponse',
            }, reason: '$endpoint ${response.key}');
          }
        }
      }
    });
  });
}
