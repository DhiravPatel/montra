import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';

import '../../helpers/fakes.dart';
import '../../helpers/social_fakes.dart';

/// The requests `SocialApi` sends, checked on the wire.
void main() {
  late FakeHttpAdapter adapter;
  late SocialApi api;
  Object? answer;
  int status = 200;
  Map<String, Object?> meta = const <String, Object?>{};

  setUp(() {
    answer = <String, Object?>{'ok': true};
    status = 200;
    meta = const <String, Object?>{};
    adapter = FakeHttpAdapter(
      (RequestOptions o) async => jsonResponse(status, <String, Object?>{
        'data': answer,
        'meta': <String, Object?>{
          'request_id': 'req-ok',
          'timestamp': '2026-11-05T10:00:00Z',
          ...meta,
        },
      }),
    );
    api = SocialApi(
      ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      ),
    );
  });

  RequestOptions sent() => adapter.requests.single;

  test('GET /connections decodes profiles with mute and block flags', () async {
    answer = <Object?>[profileJson(muted: true)];
    final List<PublicProfile> list = await api.connections();
    expect(sent().method, 'GET');
    expect(sent().uri.path, '/api/v1/connections');
    expect(list.single.muted, isTrue);
    expect(list.single.blockedByMe, isFalse);
  });

  test('GET /users/search sends the whole username without the @', () async {
    answer = <Object?>[profileJson(connection: 'none')];
    await api.searchUsername('  @Ben_Shah ');
    expect(sent().uri.path, '/api/v1/users/search');
    expect(sent().uri.queryParameters, <String, String>{'q': 'Ben_Shah'});
  });

  test('friend requests: list, send (201, maybe accepted), answer', () async {
    answer = <Object?>[friendRequest().toJson()];
    await api.friendRequests();
    expect(sent().uri.path, '/api/v1/friend-requests');

    status = 201;
    answer = friendRequest(status: 'accepted').toJson();
    final FriendRequestDto created = await api.sendFriendRequest(
      'u-ben',
      message: 'hi',
    );
    expect(adapter.requests.last.method, 'POST');
    expect(adapter.requests.last.data, <String, Object?>{
      'user_id': 'u-ben',
      'message': 'hi',
    });
    expect(created.status, FriendRequestDtoStatus.accepted);

    status = 200;
    answer = friendRequest().toJson();
    for (final (Future<FriendRequestDto> Function(String) call, String path)
        in <(Future<FriendRequestDto> Function(String), String)>[
          (api.acceptFriendRequest, 'accept'),
          (api.declineFriendRequest, 'decline'),
          (api.cancelFriendRequest, 'cancel'),
        ]) {
      await call('fr-1');
      expect(adapter.requests.last.method, 'POST');
      expect(
        adapter.requests.last.uri.path,
        '/api/v1/friend-requests/fr-1/$path',
      );
    }
  });

  test('remove, block, unblock, mute and unmute', () async {
    await api.removeFriend('u-ben');
    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.uri.path, '/api/v1/connections/u-ben');

    await api.block('u-cy');
    expect(adapter.requests.last.method, 'POST');
    expect(adapter.requests.last.uri.path, '/api/v1/users/u-cy/block');

    await api.unblock('u-cy');
    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.uri.path, '/api/v1/users/u-cy/block');

    await api.setMuted('u-cy', muted: true);
    expect(adapter.requests.last.method, 'POST');
    expect(adapter.requests.last.uri.path, '/api/v1/users/u-cy/mute');
    expect(adapter.requests.last.data, <String, Object?>{'muted': true});

    await api.setMuted('u-cy', muted: false);
    expect(adapter.requests.last.data, <String, Object?>{'muted': false});
  });

  test('GET /blocks and /mutes page with a cursor', () async {
    answer = <Object?>[blockDto().toJson()];
    meta = <String, Object?>{'next_cursor': 'c2', 'has_more': true};
    final CursorPage<BlockDto> blocks = await api.blocks(cursor: 'c1');
    expect(adapter.requests.last.uri.path, '/api/v1/blocks');
    expect(adapter.requests.last.uri.queryParameters, <String, String>{
      'cursor': 'c1',
      'limit': '50',
    });
    expect(blocks.nextCursor, 'c2');

    answer = <Object?>[muteDto().toJson()];
    meta = <String, Object?>{'next_cursor': 'zz', 'has_more': false};
    final CursorPage<MuteDto> mutes = await api.mutes();
    expect(adapter.requests.last.uri.path, '/api/v1/mutes');
    expect(mutes.hasMore, isFalse, reason: 'has_more false ends the list');
  });

  test('GET /me and PATCH /me send only the changed profile fields', () async {
    answer = meDto().toJson();
    final MeDto me = await api.me();
    expect(sent().uri.path, '/api/v1/me');
    expect(me.profile.discoverableByUsername, isFalse);

    answer = profileDtoJson(username: 'asha_r', discoverable: true);
    await api.updateProfile(
      const ProfilePatch(username: 'asha_r', discoverableByUsername: true),
    );
    expect(adapter.requests.last.method, 'PATCH');
    expect(adapter.requests.last.uri.path, '/api/v1/me');
    expect(adapter.requests.last.data, <String, Object?>{
      'username': 'asha_r',
      'discoverable_by_username': true,
    });
  });

  test('usernames are normalized like the server does', () {
    expect(normalizeUsername(' @asha '), 'asha');
    expect(normalizeUsername('asha'), 'asha');
  });
}
