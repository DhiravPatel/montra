import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';

import 'fakes.dart';
import 'finance_fakes.dart';
import 'people_fakes.dart';

class MockSocialApi extends Mock implements SocialApi {}

class MockGroupsApi extends Mock implements GroupsApi {}

/// The signed-in test user (`userJson()`).
const String meId = '7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11';

/// Registers fallback values for `any()` matchers.
void registerSocialFallbacks() {
  registerFallbackValue(const ProfilePatch());
  registerFallbackValue(
    const GroupInput(name: 'x', groupType: GroupInputGroupType.household),
  );
  registerFallbackValue(const AddMemberInput());
  registerFallbackValue(const GroupMemberUpdate());
  registerFallbackValue(
    const GroupInvitationInput(kind: GroupInvitationInputKind.link),
  );
  registerFallbackValue(<String, Object?>{});
}

/// A `PublicProfile` JSON object.
Map<String, Object?> profileJson({
  String id = 'u-ben',
  String name = 'Ben Shah',
  String? username = 'ben',
  String connection = 'friend',
  bool muted = false,
  bool blocked = false,
}) => <String, Object?>{
  'user_id': id,
  'display_name': name,
  'username': ?username,
  'connection': connection,
  'muted': muted,
  'blocked_by_me': blocked,
};

/// A `PublicProfile`.
PublicProfile profile({
  String id = 'u-ben',
  String name = 'Ben Shah',
  String? username = 'ben',
  String connection = 'friend',
  bool muted = false,
}) => PublicProfile.fromJson(
  profileJson(
    id: id,
    name: name,
    username: username,
    connection: connection,
    muted: muted,
  ),
);

/// A friend request from [fromId] to [toId].
FriendRequestDto friendRequest({
  String id = 'fr-1',
  String fromId = 'u-ben',
  String fromName = 'Ben Shah',
  String toId = meId,
  String toName = 'Asha',
  String status = 'pending',
  String? message,
}) => FriendRequestDto.fromJson(<String, Object?>{
  'id': id,
  'from': profileJson(id: fromId, name: fromName, connection: 'none'),
  'to': profileJson(id: toId, name: toName, connection: 'none'),
  'status': status,
  'message': ?message,
  'created_at': '2026-11-05T10:00:00Z',
});

/// A `BlockDTO`.
BlockDto blockDto({String id = 'u-cy', String name = 'Cy Rao'}) =>
    BlockDto.fromJson(<String, Object?>{
      ...profileJson(id: id, name: name, connection: 'none', blocked: true),
      'created_at': '2026-11-05T10:00:00Z',
    });

/// A `MuteDTO`.
MuteDto muteDto({String id = 'u-dev', String name = 'Dev Iyer'}) =>
    MuteDto.fromJson(<String, Object?>{
      ...profileJson(id: id, name: name, connection: 'friend', muted: true),
      'created_at': '2026-11-05T10:00:00Z',
    });

/// A `ProfileDTO` JSON object.
Map<String, Object?> profileDtoJson({
  String? username = 'asha',
  bool discoverable = false,
  String requests = 'everyone',
}) => <String, Object?>{
  'display_name': 'Asha',
  'username': ?username,
  'interests': <Object?>[],
  'profile_visibility': 'connections',
  'discoverable_by_username': discoverable,
  'show_achievements': false,
  'allow_friend_requests': requests,
  'updated_at': '2026-11-05T10:00:00Z',
};

/// `GET /me`.
MeDto meDto({String? username = 'asha', bool discoverable = false}) =>
    MeDto.fromJson(<String, Object?>{
      'account': userJson(),
      'profile': profileDtoJson(username: username, discoverable: discoverable),
      'preferences': preferences().toJson(),
    });

/// A group JSON object (`GroupDTO`; `GroupDetail` with members).
Map<String, Object?> groupJson({
  String id = 'grp-home',
  String name = 'Home',
  String type = 'household',
  String role = 'owner',
  String status = 'active',
  String net = '0.00',
  int version = 3,
  bool requireApproval = false,
  bool allowInvites = true,
  String? description,
  String? destination,
  String? startDate,
  String? endDate,
  int members = 3,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'group_type': type,
  'base_currency': 'INR',
  'default_split_method': 'equal',
  'allow_member_invites': allowInvites,
  'require_join_approval': requireApproval,
  'simplify_debts': true,
  'member_count': members,
  'my_net': moneyJson(net),
  'my_role': role,
  'status': status,
  'timezone': 'Asia/Kolkata',
  'description': ?description,
  'destination': ?destination,
  'start_date': ?startDate,
  'end_date': ?endDate,
  'created_at': '2026-10-01T08:00:00Z',
  'version': version,
};

/// A `GroupDTO`.
GroupDto groupDtoOf({
  String id = 'grp-home',
  String name = 'Home',
  String net = '0.00',
  String status = 'active',
  String type = 'household',
}) => GroupDto.fromJson(
  groupJson(id: id, name: name, net: net, status: status, type: type),
);

/// The members of the test group: the user (owner), Ben (admin), Cy.
List<Map<String, Object?>> homeMembers({String myRole = 'owner'}) =>
    <Map<String, Object?>>[
      groupMemberJson(id: meId, name: 'Asha', role: myRole),
      groupMemberJson(id: 'u-ben', name: 'Ben Shah', role: 'admin'),
      groupMemberJson(id: 'u-cy', name: 'Cy Rao'),
      groupMemberJson(id: 'u-old', name: 'Old Friend', status: 'removed'),
    ];

/// A `GroupDetail`.
GroupDetail groupDetailOf({
  String id = 'grp-home',
  String role = 'owner',
  String status = 'active',
  int version = 3,
  bool requireApproval = false,
  String type = 'household',
  String? description,
  String? destination,
  String? startDate,
  String? endDate,
  String name = 'Home',
}) => GroupDetail.fromJson(<String, Object?>{
  ...groupJson(
    id: id,
    name: name,
    role: role,
    status: status,
    version: version,
    requireApproval: requireApproval,
    type: type,
    description: description,
    destination: destination,
    startDate: startDate,
    endDate: endDate,
  ),
  'members': homeMembers(myRole: role),
});

/// A group invitation.
GroupInvitationDto invitation({
  String id = 'inv-1',
  String kind = 'link',
  String status = 'active',
  String? token,
  int uses = 0,
}) => GroupInvitationDto.fromJson(<String, Object?>{
  'id': id,
  'group_id': 'grp-home',
  'group_name': 'Home',
  'kind': kind,
  'token': ?token,
  'invited_by': <String, Object?>{'user_id': meId, 'display_name': 'Asha'},
  if (kind == 'username')
    'invitee': <String, Object?>{
      'user_id': 'u-dev',
      'display_name': 'Dev Iyer',
    },
  'status': status,
  'use_count': uses,
  'expires_at': '2026-11-12T10:00:00Z',
  'created_at': '2026-11-05T10:00:00Z',
});

/// `POST /group-invitations/preview`.
GroupInvitationPreview invitationPreview({
  bool requiresApproval = false,
  bool alreadyMember = false,
  String status = 'active',
}) => GroupInvitationPreview.fromJson(<String, Object?>{
  'group_id': 'grp-trip',
  'group_name': 'Goa trip',
  'group_type': 'trip',
  'member_count': 4,
  'invited_by': <String, Object?>{
    'display_name': 'Ben Shah',
    'username': 'ben',
  },
  'already_member': alreadyMember,
  'requires_approval': requiresApproval,
  'status': status,
  'expires_at': '2026-11-12T10:00:00Z',
});

/// A pending join request.
GroupJoinRequestDto joinRequest({
  String id = 'jr-1',
  String name = 'Dev Iyer',
  String? message,
}) => GroupJoinRequestDto.fromJson(<String, Object?>{
  'id': id,
  'group_id': 'grp-home',
  'user_id': 'u-dev',
  'display_name': name,
  'invitation_id': 'inv-1',
  'message': ?message,
  'status': 'pending',
  'created_at': '2026-11-05T10:00:00Z',
});

/// An activity event.
GroupActivityDto activityEvent({
  int id = 1,
  String kind = 'member_joined',
  String? actor = 'u-ben',
  String? entity = 'u-cy',
  String entityType = 'group_member',
  Map<String, Object?> summary = const <String, Object?>{},
}) => GroupActivityDto.fromJson(<String, Object?>{
  'id': id,
  'actor_id': ?actor,
  'kind': kind,
  'entity_type': entityType,
  'entity_id': ?entity,
  'summary': summary,
  'created_at': '2026-11-05T10:00:00Z',
});

/// A page of activity.
GroupActivityPage activityPage(
  List<GroupActivityDto> events, {
  int? nextBefore,
}) => GroupActivityPage.fromJson(<String, Object?>{
  'events': <Object?>[for (final GroupActivityDto e in events) e.toJson()],
  'next_before': ?nextBefore,
});

Map<String, Object?> _memberBalance(String id, String name, String net) =>
    <String, Object?>{
      'user_id': id,
      'display_name': name,
      'member_status': id == 'u-old' ? 'removed' : 'active',
      'paid': moneyJson('0.00'),
      'share': moneyJson('0.00'),
      'settlements_sent': moneyJson('0.00'),
      'settlements_received': moneyJson('0.00'),
      'net': moneyJson(net),
      'pending_in': moneyJson('0.00'),
      'pending_out': moneyJson('0.00'),
    };

/// `GET /groups/{id}/balances`: the user is owed 250, Ben owes 100, Cy
/// owes 150.
GroupBalancesDto balancesDto({String myNet = '250.00'}) =>
    GroupBalancesDto.fromJson(<String, Object?>{
      'group_id': 'grp-home',
      'currency': 'INR',
      'balances': <Object?>[
        _memberBalance(meId, 'Asha', myNet),
        _memberBalance('u-ben', 'Ben Shah', '-100.00'),
        _memberBalance('u-cy', 'Cy Rao', '-150.00'),
      ],
      'my_net': moneyJson(myNet),
      'original_debts': <Object?>[],
      'simplified': <Object?>[],
      'simplify_enabled': true,
      'disputed_expenses': 0,
      'computed_at': '2026-11-05T10:00:00Z',
    });

/// Stubs every group read for `grp-home` (owner by default).
void stubGroupReads(
  MockGroupsApi groups, {
  List<GroupDto>? list,
  List<GroupInvitationDto> mine = const <GroupInvitationDto>[],
  List<GroupInvitationDto> invitations = const <GroupInvitationDto>[],
  List<GroupJoinRequestDto> requests = const <GroupJoinRequestDto>[],
  List<GroupActivityDto>? activity,
}) {
  when(() => groups.list(includeArchived: any(named: 'includeArchived')))
      .thenAnswer((_) async => list ?? <GroupDto>[groupDtoOf(net: '250.00')]);
  when(() => groups.myInvitations()).thenAnswer((_) async => mine);
  when(() => groups.balances(any())).thenAnswer((_) async => balancesDto());
  when(
    () => groups.invitations(
      any(),
      includeInactive: any(named: 'includeInactive'),
    ),
  ).thenAnswer((_) async => invitations);
  when(() => groups.joinRequests(any())).thenAnswer((_) async => requests);
  when(() => groups.activity(any(), before: any(named: 'before'))).thenAnswer(
    (_) async => activityPage(
      activity ??
          <GroupActivityDto>[
            activityEvent(),
            activityEvent(
              id: 2,
              kind: 'group_created',
              actor: meId,
              entity: 'grp-home',
              entityType: 'group',
              summary: <String, Object?>{'type': 'household'},
            ),
          ],
    ),
  );
}

/// Stubs the social reads.
void stubSocialReads(
  MockSocialApi social, {
  List<PublicProfile>? connections,
  List<FriendRequestDto> requests = const <FriendRequestDto>[],
}) {
  when(() => social.connections())
      .thenAnswer((_) async => connections ?? <PublicProfile>[profile()]);
  when(() => social.friendRequests()).thenAnswer((_) async => requests);
  when(() => social.me()).thenAnswer((_) async => meDto());
  when(
    () => social.blocks(cursor: any(named: 'cursor')),
  ).thenAnswer((_) async => CursorPage<BlockDto>(<BlockDto>[blockDto()], null));
  when(() => social.mutes(cursor: any(named: 'cursor')))
      .thenAnswer((_) async => CursorPage<MuteDto>(<MuteDto>[muteDto()], null));
}
