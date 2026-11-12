import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/insights/data/insights_api.dart';
import 'package:montra_mobile/features/integrations/data/integrations_api.dart';
import 'package:montra_mobile/features/notifications/data/notifications_api.dart';
import 'package:montra_mobile/features/search/data/search_api.dart';

import '../../helpers/fakes.dart';
import '../../helpers/insights_feature_fakes.dart';
import '../../helpers/integrations_fakes.dart';
import '../../helpers/notifications_fakes.dart';
import '../../helpers/search_fakes.dart';

/// Request shapes of the notification, integration, search and insight
/// calls (method, path, query, body), answered with live-shaped JSON.
void main() {
  late FakeHttpAdapter adapter;
  late ApiClient client;

  Map<String, Object?> page(List<Object?> data, {String? next}) =>
      <String, Object?>{
        'data': data,
        'meta': <String, Object?>{
          'request_id': 'req-ok',
          'timestamp': '2026-11-12T06:00:00Z',
          'has_more': next != null,
          'next_cursor': ?next,
        },
      };

  Object? bodyOf(RequestOptions o) =>
      o.data == null ? null : jsonDecode(jsonEncode(o.data));

  setUp(() {
    adapter = FakeHttpAdapter((RequestOptions o) async {
      final String path = o.uri.path;
      final String m = o.method;
      if (path.endsWith('/notifications/unread-count')) {
        return jsonResponse(200, envelope(<String, Object?>{'unread': 3}));
      }
      if (path.endsWith('/notifications/read-all')) {
        return jsonResponse(200, envelope(<String, Object?>{'updated': 2}));
      }
      if (path.endsWith('/notifications/preferences')) {
        return jsonResponse(
          200,
          envelope(<Object?>[
            for (final PreferenceDto p in preferenceList()) p.toJson(),
          ]),
        );
      }
      if (path.endsWith('/notifications') && m == 'GET') {
        return jsonResponse(
          200,
          page(<Object?>[notificationJson()], next: 'n-cursor'),
        );
      }
      if (path.contains('/notifications/')) {
        return jsonResponse(
          200,
          envelope(notificationJson(readAt: '2026-11-12T07:00:00Z')),
        );
      }
      if (path.endsWith('/integrations')) {
        return jsonResponse(200, envelope(overview().toJson()));
      }
      if (path.endsWith('/connect')) {
        return jsonResponse(
          201,
          envelope(<String, Object?>{
            'connection_id': 'conn-1',
            'authorize_url': 'https://provider.example/authorize?state=s',
          }),
        );
      }
      if (path.endsWith('/status')) {
        return jsonResponse(200, envelope(connectionStatus().toJson()));
      }
      if (path.endsWith('/sync')) {
        return jsonResponse(
          202,
          envelope(<String, Object?>{
            'id': 'run-2',
            'status': 'queued',
            'trigger': 'manual',
            'items_fetched': 0,
            'items_created': 0,
            'items_updated': 0,
            'items_skipped': 0,
            'created_at': '2026-11-12T06:00:00Z',
          }),
        );
      }
      if (path.contains('/integrations/') && m == 'DELETE') {
        return jsonResponse(
          200,
          envelope(<String, Object?>{
            'status': 'revoked',
            'deleted_records': 4,
          }),
        );
      }
      if (path.endsWith('/search/recent') && m == 'GET') {
        return jsonResponse(200, envelope(<Object?>[recentSearch().toJson()]));
      }
      if (path.endsWith('/search/recent')) {
        return jsonResponse(200, envelope(<String, Object?>{'deleted': 1}));
      }
      if (path.endsWith('/search')) {
        return jsonResponse(
          200,
          envelope(
            searchResults(
              transactions: <Map<String, Object?>>[transactionHitJson()],
            ).toJson(),
          ),
        );
      }
      if (path.endsWith('/insights/mutes') && m == 'GET') {
        return jsonResponse(200, envelope(<Object?>[insightMute().toJson()]));
      }
      if (path.endsWith('/insights/mutes')) {
        return jsonResponse(
          200,
          envelope(<String, Object?>{
            'subtype': 'unusual_amount',
            'scope': '*',
            'reopened': 2,
            'insights': <Object?>[insightJson()],
          }),
        );
      }
      if (path.endsWith('/insights')) {
        return jsonResponse(200, page(<Object?>[insightJson()], next: 'i-2'));
      }
      return jsonResponse(200, envelope(insightJson(status: 'dismissed')));
    });
    client = ApiClient(
      createApiDio(testConfig, adapter: adapter, enableLogging: false),
    );
  });

  test('every engage endpoint exists in the endpoint list', () {
    for (final ApiEndpoint e in <ApiEndpoint>[
      ApiEndpoints.listNotifications,
      ApiEndpoints.updateNotification,
      ApiEndpoints.readAllNotifications,
      ApiEndpoints.unreadNotificationCount,
      ApiEndpoints.notificationPreferences,
      ApiEndpoints.updateNotificationPreferences,
      ApiEndpoints.listIntegrations,
      ApiEndpoints.connectIntegration,
      ApiEndpoints.integrationStatus,
      ApiEndpoints.syncIntegration,
      ApiEndpoints.disconnectIntegration,
      ApiEndpoints.search,
      ApiEndpoints.recentSearches,
      ApiEndpoints.clearRecentSearches,
      ApiEndpoints.listInsights,
      ApiEndpoints.getInsight,
      ApiEndpoints.actOnInsight,
      ApiEndpoints.insightFeedback,
      ApiEndpoints.listInsightMutes,
      ApiEndpoints.unmuteInsights,
    ]) {
      expect(ApiEndpoints.all, contains(e));
      expect(e.path.startsWith('/ai/'), isFalse);
    }
  });

  group('notifications', () {
    test(
      'list pages with the filters, update, read-all and unread count',
      () async {
        final NotificationsApi api = NotificationsApi(client);
        final CursorPage<NotificationDto> first = await api.list(
          unread: true,
          category: 'social',
        );
        expect(first.items.single.deepLink, '/friends?tab=requests');
        expect(first.nextCursor, 'n-cursor');
        await api.list(archived: true, cursor: first.nextCursor);
        final NotificationDto read = await api.update('n-1', read: true);
        expect(read.readAt, isNotNull);
        await api.update('n-1', archived: false);
        expect(await api.readAll(), 2);
        expect(await api.unreadCount(), 3);

        final List<RequestOptions> r = adapter.requests;
        expect(r[0].method, 'GET');
        expect(r[0].uri.path, '/api/v1/notifications');
        expect(r[0].uri.queryParameters, <String, String>{
          'unread': 'true',
          'category': 'social',
          'limit': '30',
        });
        expect(r[1].uri.queryParameters, <String, String>{
          'archived': 'true',
          'cursor': 'n-cursor',
          'limit': '30',
        });
        expect(r[2].method, 'PATCH');
        expect(r[2].uri.path, '/api/v1/notifications/n-1');
        expect(bodyOf(r[2]), <String, Object?>{'read': true});
        expect(bodyOf(r[3]), <String, Object?>{'archived': false});
        expect(r[4].method, 'POST');
        expect(r[4].uri.path, '/api/v1/notifications/read-all');
        expect(r[5].uri.path, '/api/v1/notifications/unread-count');
      },
    );

    test('preferences: a change sends only the field that changed', () async {
      final NotificationsApi api = NotificationsApi(client);
      final List<PreferenceDto> all = await api.preferences();
      expect(all, hasLength(72));
      await api.updatePreferences(<PreferencePatch>[
        const PreferencePatch(
          category: 'budget',
          channel: PreferencePatchChannel.email,
          enabled: true,
        ),
      ]);
      await api.updatePreferences(<PreferencePatch>[
        const PreferencePatch(
          category: 'bill',
          channel: PreferencePatchChannel.email,
          digest: PreferencePatchDigest.weekly,
        ),
      ]);
      final List<RequestOptions> patches = adapter.requests
          .where((RequestOptions o) => o.method == 'PATCH')
          .toList();
      expect(bodyOf(patches[0]), <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'category': 'budget',
            'channel': 'email',
            'enabled': true,
          },
        ],
      });
      expect(bodyOf(patches[1]), <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'category': 'bill',
            'channel': 'email',
            'digest': 'weekly',
          },
        ],
      });
    });
  });

  group('integrations', () {
    test(
      'overview, connect with consent, status, sync and disconnect',
      () async {
        final IntegrationsApi api = IntegrationsApi(client);
        final Overview o = await api.overview();
        expect(o.providers.single.status, ProviderInfoStatus.unavailable);
        final ConnectResult c = await api.connect('demo_bank', 'acc-1');
        expect(c.authorizeUrl, startsWith('https://'));
        final ConnectionStatus s = await api.status('conn-1');
        expect(s.runs.single.itemsCreated, 10);
        final SyncRunDto run = await api.sync('conn-1');
        expect(run.status, SyncRunDtoStatus.queued);
        final DisconnectResult d = await api.disconnect(
          'conn-1',
          deleteData: true,
        );
        expect(d.deletedRecords, 4);
        await api.disconnect('conn-1', deleteData: false);

        final List<RequestOptions> r = adapter.requests;
        expect(r[0].uri.path, '/api/v1/integrations');
        expect(r[1].method, 'POST');
        expect(r[1].uri.path, '/api/v1/integrations/demo_bank/connect');
        expect(bodyOf(r[1]), <String, Object?>{
          'account_id': 'acc-1',
          'consent_confirm': true,
        });
        expect(r[2].uri.path, '/api/v1/integrations/conn-1/status');
        expect(r[3].method, 'POST');
        expect(r[3].uri.path, '/api/v1/integrations/conn-1/sync');
        expect(r[4].method, 'DELETE');
        expect(r[4].uri.queryParameters, <String, String>{
          'confirm': 'true',
          'delete_data': 'true',
        });
        expect(r[5].uri.queryParameters, <String, String>{'confirm': 'true'});
      },
    );
  });

  group('search', () {
    test('save is false unless asked; recent and clear', () async {
      final SearchApi api = SearchApi(client);
      final Results typing = await api.search('100%');
      expect(typing.transactions.single.amount.amount, '250.00');
      await api.search(
        'engage',
        scope: 'transactions',
        sort: 'recent',
        save: true,
      );
      final List<RecentDto> recent = await api.recent();
      expect(recent.single.query, 'engage');
      expect(await api.clearRecent(), 1);

      final List<RequestOptions> r = adapter.requests;
      expect(r[0].uri.path, '/api/v1/search');
      expect(r[0].uri.queryParameters, <String, String>{
        'q': '100%',
        'scope': 'all',
        'sort': 'relevance',
        'save': 'false',
      });
      expect(r[1].uri.queryParameters, <String, String>{
        'q': 'engage',
        'scope': 'transactions',
        'sort': 'recent',
        'save': 'true',
      });
      expect(r[2].method, 'GET');
      expect(r[2].uri.path, '/api/v1/search/recent');
      expect(r[3].method, 'DELETE');
      expect(r[3].uri.path, '/api/v1/search/recent');
    });
  });

  group('insights', () {
    test('one insight is read by its ID', () async {
      final InsightDto one = await InsightsApi(client).get('ins-1');
      expect(one.id, 'ins-1');
      final RequestOptions sent = adapter.requests.single;
      expect(sent.method, 'GET');
      expect(sent.uri.path, '/api/v1/insights/ins-1');
      expect(sent.uri.queryParameters, isEmpty);
    });

    test('list, actions, feedback, mutes and unmute', () async {
      final InsightsApi api = InsightsApi(client);
      final CursorPage<InsightDto> p = await api.list(
        all: true,
        kind: 'anomaly',
      );
      expect(p.items.single.messageCode, 'unusual_amount');
      expect(p.nextCursor, 'i-2');
      await api.list(cursor: 'i-2');
      final InsightDto acted = await api.act(
        'ins-1',
        ActionInputAction.snooze,
        snoozeDays: 7,
      );
      expect(acted.status, InsightDtoStatus.dismissed);
      await api.feedback('ins-1', FeedbackInputFeedback.notHelpful, note: '');
      expect((await api.mutes()).single.scope, '*');
      final UnmuteResult u = await api.unmute('unusual_amount', scope: '*');
      expect(u.reopened, 2);

      final List<RequestOptions> r = adapter.requests;
      expect(r[0].uri.queryParameters, <String, String>{
        'all': 'true',
        'kind': 'anomaly',
        'limit': '50',
      });
      expect(r[1].uri.queryParameters, <String, String>{
        'cursor': 'i-2',
        'limit': '50',
      });
      expect(r[2].method, 'POST');
      expect(r[2].uri.path, '/api/v1/insights/ins-1/actions');
      expect(bodyOf(r[2]), <String, Object?>{
        'action': 'snooze',
        'snooze_days': 7,
      });
      expect(r[3].uri.path, '/api/v1/insights/ins-1/feedback');
      expect(bodyOf(r[3]), <String, Object?>{
        'feedback': 'not_helpful',
        'note': '',
      });
      expect(r[4].uri.path, '/api/v1/insights/mutes');
      expect(r[5].method, 'DELETE');
      expect(r[5].uri.queryParameters, <String, String>{
        'subtype': 'unusual_amount',
        'scope': '*',
      });
      expect(
        adapter.requests.any((RequestOptions o) => o.uri.path.contains('/ai/')),
        isFalse,
      );
    });
  });
}
