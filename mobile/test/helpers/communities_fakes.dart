import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';

/// The signed-in test user (`userJson()`).
const String meId = '7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11';

class MockCommunitiesApi extends Mock implements CommunitiesApi {}

/// Registers fallback values for the community screens' `any()` matchers.
void registerCommunityFallbacks() {
  registerFallbackValue(const CommunityInput(name: 'x'));
  registerFallbackValue(const CommunityPostInput(title: 'x'));
  registerFallbackValue(const CommunityCommentInput(body: 'x'));
  registerFallbackValue(const CommunityInvitationInput());
  registerFallbackValue(
    const ModerationActionInput(
      action: ModerationActionInputAction.warn,
      targetId: 'x',
      targetType: ModerationActionInputTargetType.member,
    ),
  );
  registerFallbackValue(
    const AppealDecisionInput(decision: AppealDecisionInputDecision.upheld),
  );
  registerFallbackValue(
    const PostReportInput(reason: PostReportInputReason.spam),
  );
  registerFallbackValue(CommunityReactionInputKind.like);
  registerFallbackValue(CommunityMemberRoleInputRole.member);
  registerFallbackValue(<String, Object?>{});
  registerFallbackValue(<String>[]);
}

/// A `CommunityDTO` like the live server's.
CommunityDto community({
  String id = 'com-1',
  String name = 'Savers Circle',
  String visibility = 'public',
  String status = 'active',
  String myRole = 'member',
  String myStatus = 'active',
  bool canModerate = false,
  int members = 12,
  int version = 3,
  List<String> topics = const <String>['saving', 'budgeting'],
  String? description = 'Tips for saving a little every week.',
  String? rules = 'Be kind. No selling.',
  String? restrictedUntil,
}) => CommunityDto.fromJson(<String, Object?>{
  'id': id,
  'slug': 'savers-circle',
  'name': name,
  'description': ?description,
  'rules': ?rules,
  'topics': topics,
  'visibility': visibility,
  'status': status,
  'member_count': members,
  'my_role': myRole,
  'my_status': myStatus,
  'can_moderate': canModerate,
  'restricted_until': ?restrictedUntil,
  'version': version,
  'created_at': '2026-11-01T08:00:00Z',
});

Map<String, Object?> _reactions({int like = 0, int helpful = 0}) =>
    <String, Object?>{
      'like': like,
      'helpful': helpful,
      'insightful': 0,
      'support': 0,
    };

Map<String, Object?> authorJson({
  String id = 'u-ravi',
  String name = 'Ravi Kumar',
  String? username = 'ravi',
}) => <String, Object?>{
  'user_id': id,
  'display_name': name,
  'username': ?username,
};

/// A `CommunityPostDTO` as JSON.
Map<String, Object?> postJson({
  String id = 'post-1',
  String kind = 'question',
  String label = 'question',
  String title = 'How do you save on groceries?',
  String body = 'Tips welcome.',
  String status = 'published',
  bool mine = false,
  bool pinned = false,
  bool locked = false,
  int comments = 2,
  int helpful = 1,
  List<String> myReactions = const <String>[],
  String? linkUrl,
  Map<String, Object?>? poll,
  String? removedReason,
}) => <String, Object?>{
  'id': id,
  'community_id': 'com-1',
  'author': mine
      ? authorJson(id: meId, name: 'Asha', username: null)
      : authorJson(),
  'kind': kind,
  'label': label,
  'title': title,
  'body': body,
  'link_url': ?linkUrl,
  'poll': ?poll,
  'status': status,
  'removed_reason': ?removedReason,
  'pinned': pinned,
  'locked': locked,
  'comment_count': comments,
  'reactions': _reactions(helpful: helpful),
  'my_reactions': myReactions,
  'mine': mine,
  'created_at': '2026-11-04T09:00:00Z',
};

/// A `CommunityPostDTO`.
CommunityPostDto post({
  String id = 'post-1',
  String title = 'How do you save on groceries?',
  bool pinned = false,
}) => CommunityPostDto.fromJson(postJson(id: id, title: title, pinned: pinned));

/// A `CommunityPollDTO` as JSON.
Map<String, Object?> pollJson({
  List<String> myVotes = const <String>[],
  int notes = 0,
  int sheet = 1,
  bool closed = false,
  bool multiple = false,
}) => <String, Object?>{
  'id': 'poll-1',
  'question': 'Which app do you use?',
  'allow_multiple': multiple,
  'closed': closed,
  'options': <Object?>[
    <String, Object?>{'id': 'opt-notes', 'label': 'Notes', 'votes': notes},
    <String, Object?>{
      'id': 'opt-sheet',
      'label': 'Spreadsheet',
      'votes': sheet,
    },
  ],
  'total_votes': notes + sheet,
  'my_votes': myVotes,
};

/// A `CommunityCommentDTO` as JSON.
Map<String, Object?> commentJson({
  required String id,
  String? parent,
  String body = 'Buy in bulk.',
  String status = 'published',
  bool mine = false,
  String name = 'Meera Shah',
  String createdAt = '2026-11-04T10:00:00Z',
}) => <String, Object?>{
  'id': id,
  'post_id': 'post-1',
  'parent_comment_id': ?parent,
  'author': authorJson(id: 'u-$id', name: name, username: null),
  'body': body,
  'status': status,
  'reactions': _reactions(),
  'my_reactions': <String>[],
  'mine': mine,
  'created_at': createdAt,
};

/// A `CommunityPostDetail` with [comments].
CommunityPostDetail postDetail({
  List<Map<String, Object?>> comments = const <Map<String, Object?>>[],
  Map<String, Object?> overrides = const <String, Object?>{},
}) => CommunityPostDetail.fromJson(<String, Object?>{
  ...postJson(comments: comments.length),
  ...overrides,
  'comments': comments,
});

/// `CommunityReactionsDTO`.
CommunityReactionsDto reactionsAnswer({
  int helpful = 2,
  List<String> mine = const <String>['helpful'],
}) => CommunityReactionsDto.fromJson(<String, Object?>{
  ..._reactions(helpful: helpful),
  'my_reactions': mine,
});

/// A `CommunityMemberDTO`.
CommunityMemberDto member({
  String id = 'u-ravi',
  String name = 'Ravi Kumar',
  String role = 'member',
  String status = 'active',
}) => CommunityMemberDto.fromJson(<String, Object?>{
  'user_id': id,
  'display_name': name,
  'role': role,
  'status': status,
  'joined_at': '2026-11-02T08:00:00Z',
});

/// A `CommunityInvitationDTO`.
CommunityInvitationDto invitation({
  String id = 'inv-1',
  String kind = 'link',
  String status = 'active',
  String? token,
}) => CommunityInvitationDto.fromJson(<String, Object?>{
  'id': id,
  'community_id': 'com-1',
  'community_name': 'Savers Circle',
  'kind': kind,
  'token': ?token,
  'invited_by': authorJson(id: 'u-asha', name: 'Asha Rao', username: null),
  if (kind == 'username')
    'invitee': authorJson(id: meId, name: 'Asha', username: null),
  'status': status,
  'expires_at': '2026-11-15T06:00:00Z',
  'created_at': '2026-11-08T06:00:00Z',
});

/// A `CommunityInvitationPreview`.
CommunityInvitationPreview preview({
  String status = 'active',
  bool alreadyMember = false,
}) => CommunityInvitationPreview.fromJson(<String, Object?>{
  'community_id': 'com-1',
  'community_name': 'Savers Circle',
  'slug': 'savers-circle',
  'member_count': 12,
  'invited_by': authorJson(id: 'u-asha', name: 'Asha Rao', username: null),
  'status': status,
  'expires_at': '2026-11-15T06:00:00Z',
  'already_member': alreadyMember,
  'requires_approval': false,
});

/// A `ModerationReportDTO` as moderators see it.
ModerationReportDto report({
  String id = 'rep-1',
  String targetType = 'comment',
  String status = 'open',
}) => ModerationReportDto.fromJson(<String, Object?>{
  'id': id,
  'target_type': targetType,
  'target_id': 'cmt-2',
  'post_id': 'post-1',
  'target_user_id': 'u-ravi',
  'community_id': 'com-1',
  'reason': 'harassment',
  'details': 'Rude reply',
  'status': status,
  'preview': 'You are <b>wrong</b>',
  'open_reports': 2,
  'created_at': '2026-11-05T08:00:00Z',
});

/// A `ModerationActionDTO`.
ModerationActionDto modAction({
  String id = 'act-1',
  String action = 'hide',
  String targetType = 'comment',
  bool appealable = true,
  String? appealUntil = '2026-12-05T08:00:00Z',
  Map<String, Object?>? appeal,
  String? reversedAt,
  String? expiresAt,
  String? reason = 'Off topic',
}) => ModerationActionDto.fromJson(<String, Object?>{
  'id': id,
  'community_id': 'com-1',
  'target_type': targetType,
  'target_id': 'cmt-1',
  'target_user_id': meId,
  'action': action,
  'reason': ?reason,
  'expires_at': ?expiresAt,
  'reversed_at': ?reversedAt,
  'appealable': appealable,
  'appeal_until': ?appealUntil,
  'appeal': ?appeal,
  'created_at': '2026-11-05T08:00:00Z',
});

/// A `ModerationAppealDTO`.
ModerationAppealDto appealDto({String status = 'open', String? note}) =>
    ModerationAppealDto.fromJson(<String, Object?>{
      'id': 'apl-1',
      'action_id': 'act-1',
      'action': <String, Object?>{
        'id': 'act-1',
        'action': 'hide',
        'target_type': 'comment',
        'target_id': 'cmt-1',
        'reason': 'Off topic',
        'created_at': '2026-11-05T08:00:00Z',
      },
      'community_id': 'com-1',
      'statement': 'It was on topic.',
      'status': status,
      'decision_note': ?note,
      'created_at': '2026-11-06T08:00:00Z',
    });

/// One page of posts.
CursorPage<CommunityPostDto> postsPage(
  List<CommunityPostDto> items, {
  String? next,
}) => CursorPage<CommunityPostDto>(items, next);

/// Stubs the community, its feed and its post for screen tests.
void stubCommunity(
  MockCommunitiesApi api, {
  CommunityDto? value,
  List<CommunityPostDto>? posts,
}) {
  final CommunityDto c = value ?? community();
  when(() => api.get(any())).thenAnswer((_) async => c);
  when(
    () => api.posts(
      any(),
      sort: any(named: 'sort'),
      q: any(named: 'q'),
      cursor: any(named: 'cursor'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => postsPage(posts ?? <CommunityPostDto>[post()]));
}
