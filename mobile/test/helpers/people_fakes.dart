import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';

class MockPeopleApi extends Mock implements PeopleApi {}

/// A connection (`PublicProfile`) with the given [connection] state.
PublicProfile friend({
  String id = 'u-asha',
  String name = 'Asha Rao',
  String? username = 'asha',
  String connection = 'friend',
}) => PublicProfile.fromJson(<String, Object?>{
  'user_id': id,
  'display_name': name,
  'username': ?username,
  'connection': connection,
  'blocked_by_me': false,
  'muted': false,
});

Map<String, Object?> _groupJson(String id, String name, int members) =>
    <String, Object?>{
      'id': id,
      'name': name,
      'group_type': 'household',
      'base_currency': 'INR',
      'default_split_method': 'equal',
      'allow_member_invites': true,
      'require_join_approval': false,
      'simplify_debts': true,
      'member_count': members,
      'my_net': <String, Object?>{
        'amount_minor': 0,
        'amount': '0.00',
        'currency': 'INR',
      },
      'my_role': 'owner',
      'status': 'active',
      'timezone': 'Asia/Kolkata',
      'created_at': '2026-10-01T08:00:00Z',
      'version': 1,
    };

/// A `GroupDTO`.
GroupDto groupDto({
  String id = 'grp-home',
  String name = 'Home',
  int members = 3,
}) => GroupDto.fromJson(_groupJson(id, name, members));

/// A `GroupMemberDTO` as JSON.
Map<String, Object?> groupMemberJson({
  required String id,
  required String name,
  String status = 'active',
  String role = 'member',
}) => <String, Object?>{
  'user_id': id,
  'display_name': name,
  'role': role,
  'status': status,
  'notification_level': 'all',
  'joined_at': '2026-10-01T08:00:00Z',
};

/// A `GroupDetail` with [members] (JSON from [groupMemberJson]).
GroupDetail groupDetail({
  String id = 'grp-home',
  String name = 'Home',
  List<Map<String, Object?>> members = const <Map<String, Object?>>[],
}) => GroupDetail.fromJson(<String, Object?>{
  ..._groupJson(id, name, members.length),
  'members': members,
});

/// Stubs the people API with the given friends and groups.
void stubPeople(
  MockPeopleApi api, {
  List<PublicProfile>? friends,
  List<GroupDto>? groups,
}) {
  when(() => api.friends())
      .thenAnswer((_) async => friends ?? <PublicProfile>[friend()]);
  when(() => api.groups(includeArchived: any(named: 'includeArchived')))
      .thenAnswer((_) async => groups ?? <GroupDto>[groupDto()]);
}
