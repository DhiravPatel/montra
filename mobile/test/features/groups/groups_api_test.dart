import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart';
import 'package:montra_mobile/features/groups/presentation/group_form_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/social_fakes.dart';

/// The requests `GroupsApi` sends, checked on the wire.
void main() {
  late FakeHttpAdapter adapter;
  late GroupsApi api;
  Object? answer;
  int status = 200;

  setUp(() {
    answer = <String, Object?>{'ok': true};
    status = 200;
    adapter = FakeHttpAdapter(
      (RequestOptions o) async => jsonResponse(status, envelope(answer)),
    );
    api = GroupsApi(
      ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      ),
    );
  });

  RequestOptions last() => adapter.requests.last;

  test('lists (with archived), reads, creates, deletes with confirm', () async {
    answer = <Object?>[groupJson(net: '-50.00')];
    final List<GroupDto> list = await api.list(includeArchived: true);
    expect(last().uri.path, '/api/v1/groups');
    expect(last().uri.queryParameters, <String, String>{
      'include_archived': 'true',
    });
    expect(list.single.myNet.amount, '-50.00');
    await api.list();
    expect(last().uri.queryParameters, isEmpty);

    answer = groupDetailOf().toJson();
    await api.get('grp-home');
    expect(last().uri.path, '/api/v1/groups/grp-home');

    status = 201;
    await api.create(
      const GroupInput(name: 'Flat', groupType: GroupInputGroupType.roommates),
    );
    expect(last().method, 'POST');
    expect(last().data, <String, Object?>{
      'name': 'Flat',
      'group_type': 'roommates',
    });

    status = 200;
    answer = groupJson();
    await api.delete('grp-home');
    expect(last().method, 'DELETE');
    expect(last().uri.queryParameters, <String, String>{'confirm': 'true'});
  });

  test('PATCH /groups/{id} sends only the changes with the version', () async {
    final GroupDetail original = groupDetailOf(
      description: 'Our flat',
      version: 7,
    );
    final Map<String, Object?> after = <String, Object?>{
      ...groupValues(original),
      'name': 'New name',
      'require_join_approval': true,
    }..remove('description');
    answer = groupDetailOf().toJson();
    await api.update('grp-home', groupPatchFor(original, after));
    expect(last().method, 'PATCH');
    expect(last().uri.path, '/api/v1/groups/grp-home');
    expect(last().data, <String, Object?>{
      'name': 'New name',
      'require_join_approval': true,
      'description': '',
      'version': 7,
    });
  });

  test('archive, restore, transfer ownership, activity, balances', () async {
    answer = groupJson();
    await api.archive('grp-home');
    expect(last().uri.path, '/api/v1/groups/grp-home/archive');
    await api.restore('grp-home');
    expect(last().uri.path, '/api/v1/groups/grp-home/restore');

    answer = groupDetailOf().toJson();
    await api.transferOwnership('grp-home', 'u-ben');
    expect(last().uri.path, '/api/v1/groups/grp-home/transfer-ownership');
    expect(last().data, <String, Object?>{'user_id': 'u-ben'});

    answer = activityPage(<GroupActivityDto>[
      activityEvent(),
    ], nextBefore: 9).toJson();
    final GroupActivityPage page = await api.activity('grp-home', before: 20);
    expect(last().uri.path, '/api/v1/groups/grp-home/activity');
    expect(last().uri.queryParameters, <String, String>{'before': '20'});
    expect(page.nextBefore, 9);

    answer = balancesDto().toJson();
    await api.balances('grp-home');
    expect(last().uri.path, '/api/v1/groups/grp-home/balances');
  });

  test('members: add by username or friend, role, leave/remove', () async {
    status = 201;
    answer = invitation(kind: 'username').toJson();
    await api.addMember('grp-home', const AddMemberInput(username: 'dev'));
    expect(last().uri.path, '/api/v1/groups/grp-home/members');
    expect(last().data, <String, Object?>{'username': 'dev'});
    await api.addMember('grp-home', const AddMemberInput(userId: 'u-dev'));
    expect(last().data, <String, Object?>{'user_id': 'u-dev'});

    status = 200;
    answer = groupDetailOf().toJson();
    await api.updateMember(
      'grp-home',
      'u-cy',
      const GroupMemberUpdate(role: GroupMemberUpdateRole.admin),
    );
    expect(last().method, 'PATCH');
    expect(last().uri.path, '/api/v1/groups/grp-home/members/u-cy');
    expect(last().data, <String, Object?>{'role': 'admin'});

    answer = <String, Object?>{'ok': true};
    await api.removeMember('grp-home', 'u-cy');
    expect(last().method, 'DELETE');
    expect(last().uri.path, '/api/v1/groups/grp-home/members/u-cy');
  });

  test(
    'invitations: list, create link, revoke, mine, accept, decline',
    () async {
      answer = <Object?>[invitation().toJson()];
      await api.invitations('grp-home', includeInactive: true);
      expect(last().uri.path, '/api/v1/groups/grp-home/invitations');
      expect(last().uri.queryParameters, <String, String>{
        'include_inactive': 'true',
      });

      status = 201;
      answer = invitation(token: 'tok_abcdefghijklmnop').toJson();
      final GroupInvitationDto link = await api.createInvitation(
        'grp-home',
        const GroupInvitationInput(
          kind: GroupInvitationInputKind.link,
          expiresInDays: 7,
          maxUses: 5,
        ),
      );
      expect(last().data, <String, Object?>{
        'kind': 'link',
        'expires_in_days': 7,
        'max_uses': 5,
      });
      expect(link.token, 'tok_abcdefghijklmnop');

      status = 200;

      answer = <String, Object?>{'ok': true};
      await api.revokeInvitation('grp-home', 'inv-1');
      expect(last().method, 'DELETE');
      expect(last().uri.path, '/api/v1/groups/grp-home/invitations/inv-1');

      answer = <Object?>[invitation(kind: 'username').toJson()];
      await api.myInvitations();
      expect(last().uri.path, '/api/v1/group-invitations');

      answer = groupDetailOf().toJson();
      await api.acceptInvitation('inv-1');
      expect(last().uri.path, '/api/v1/group-invitations/inv-1/accept');
      answer = <String, Object?>{'ok': true};
      await api.declineInvitation('inv-1');
      expect(last().uri.path, '/api/v1/group-invitations/inv-1/decline');
    },
  );

  test('a link is previewed and accepted with the token in the body; 200 '
      'joins and 202 waits for approval', () async {
    const String token = 'tok_abcdefghijklmnop';
    answer = invitationPreview(requiresApproval: true).toJson();
    final GroupInvitationPreview preview = await api.previewInvitation(token);
    expect(last().method, 'POST');
    expect(last().uri.path, '/api/v1/group-invitations/preview');
    expect(last().uri.query, isEmpty, reason: 'never in the URL');
    expect(last().data, <String, Object?>{'token': token});
    expect(preview.requiresApproval, isTrue);

    answer = groupDetailOf().toJson();
    final JoinOutcome joined = await api.acceptInvitationLink(token);
    expect(last().uri.path, '/api/v1/group-invitations/accept');
    expect(last().data, <String, Object?>{'token': token});
    expect(joined, isA<Joined>());

    status = 202;
    answer = joinRequest().toJson();
    final JoinOutcome pending = await api.acceptInvitationLink(token);
    expect(pending, isA<JoinPending>());
    expect((pending as JoinPending).request.invitationId, 'inv-1');
  });

  test('join requests: list, ask, approve, decline', () async {
    answer = <Object?>[joinRequest().toJson()];
    await api.joinRequests('grp-home');
    expect(last().uri.path, '/api/v1/groups/grp-home/join-requests');

    status = 201;
    answer = joinRequest().toJson();
    await api.createJoinRequest('grp-home', message: 'Hi');
    expect(last().method, 'POST');
    expect(last().data, <String, Object?>{'message': 'Hi'});

    status = 200;
    answer = groupDetailOf().toJson();
    await api.approveJoinRequest('grp-home', 'jr-1');
    expect(
      last().uri.path,
      '/api/v1/groups/grp-home/join-requests/jr-1/approve',
    );
    await api.declineJoinRequest('grp-home', 'jr-1');
    expect(
      last().uri.path,
      '/api/v1/groups/grp-home/join-requests/jr-1/decline',
    );
  });

  test('roles and dated types', () {
    expect(roleCanManage('owner'), isTrue);
    expect(roleCanManage('admin'), isTrue);
    expect(roleCanManage('member'), isFalse);
    expect(groupTypeHasDates('trip'), isTrue);
    expect(groupTypeHasDates('household'), isFalse);
  });
}
