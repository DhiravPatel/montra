import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/challenges/data/challenges_api.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/moderation/data/moderation_api.dart';

import '../../helpers/challenges_fakes.dart';
import '../../helpers/communities_fakes.dart';
import '../../helpers/fakes.dart';

/// Request shapes of every community, challenge and moderation operation
/// (method, path, query and body), answered with live-shaped JSON that the
/// generated models decode.
void main() {
  late FakeHttpAdapter adapter;
  late ApiClient client;

  Map<String, Object?> page(List<Object?> data, {String? next}) =>
      <String, Object?>{
        'data': data,
        'meta': <String, Object?>{
          'request_id': 'req-ok',
          'timestamp': '2026-11-04T10:00:00Z',
          'has_more': next != null,
          'next_cursor': ?next,
        },
      };

  Object? answer(RequestOptions o) {
    final String m = o.method;
    final String p = o.uri.path.replaceFirst('/api/v1', '');
    bool is_(String method, String pattern) =>
        m == method && RegExp('^$pattern\$').hasMatch(p);
    if (is_('GET', '/communities')) {
      return envelope(<Object?>[community().toJson()]);
    }
    if (is_('GET', '/communities/[^/]+/posts')) {
      return page(<Object?>[postJson()], next: 'c2');
    }
    if (is_('POST', '/communities/[^/]+/posts') ||
        is_('PATCH', '/posts/[^/]+')) {
      return envelope(postJson());
    }
    if (is_('GET', '/posts/[^/]+')) {
      return envelope(postDetail().toJson());
    }
    if (p.contains('/reactions')) {
      return envelope(reactionsAnswer().toJson());
    }
    if (p.endsWith('/poll/votes')) {
      return envelope(pollJson(myVotes: <String>['opt-sheet']));
    }
    if (p.endsWith('/comments') || is_('PATCH', '/comments/[^/]+')) {
      return envelope(commentJson(id: 'cmt-1'));
    }
    if (p.endsWith('/reports') && m == 'POST' ||
        is_('POST', '/content-reports')) {
      return envelope(report().toJson());
    }
    if (is_('GET', '/content-reports') ||
        is_('GET', '/communities/[^/]+/moderation/reports')) {
      return envelope(<Object?>[report().toJson()]);
    }
    if (is_('GET', '/communities/[^/]+/members')) {
      return envelope(<Object?>[member().toJson()]);
    }
    if (is_('GET', '/communities/[^/]+/invitations') ||
        is_('GET', '/community-invitations')) {
      return envelope(<Object?>[invitation().toJson()]);
    }
    if (is_('POST', '/communities/[^/]+/invitations')) {
      return envelope(invitation(token: 'tok-abcdefghijklmnop').toJson());
    }
    if (is_('POST', '/community-invitations/preview')) {
      return envelope(preview().toJson());
    }
    if (is_('GET', '/communities/[^/]+/moderation/appeals') ||
        is_('GET', '/me/moderation/appeals')) {
      return envelope(<Object?>[appealDto().toJson()]);
    }
    if (is_('POST', '/moderation/appeals/[^/]+/decide') ||
        is_('POST', '/moderation/actions/[^/]+/appeals')) {
      return envelope(appealDto(status: 'overturned').toJson());
    }
    if (is_('GET', '/communities/[^/]+/moderation/actions') ||
        is_('GET', '/me/moderation')) {
      return envelope(<Object?>[modAction().toJson()]);
    }
    if (is_('POST', '/communities/[^/]+/moderation/actions') ||
        is_('POST', '/moderation/actions/[^/]+/reverse')) {
      return envelope(modAction().toJson());
    }
    if (is_('GET', '/challenges')) {
      return page(<Object?>[challenge().toJson()], next: 'c2');
    }
    if (is_('GET', '/challenges/[^/]+/leaderboard')) {
      return envelope(<Object?>[leaderEntry().toJson()]);
    }
    if (p.startsWith('/challenges') && !p.endsWith('/leave')) {
      return envelope(challenge(me: participationJson()).toJson());
    }
    if (m == 'DELETE' ||
        p.endsWith('/leave') ||
        p.endsWith('/approve') ||
        p.endsWith('/reject') ||
        p.endsWith('/decline') ||
        is_('PATCH', '/communities/[^/]+/members/[^/]+')) {
      return envelope(<String, Object?>{'ok': true});
    }
    return envelope(community().toJson());
  }

  setUp(() {
    adapter = FakeHttpAdapter(
      (RequestOptions o) async =>
          jsonResponse(o.method == 'POST' ? 201 : 200, answer(o)),
    );
    client = ApiClient(
      createApiDio(testConfig, adapter: adapter, enableLogging: false),
    );
  });

  ({String method, String path, Map<String, String> query, Object? body}) sent(
    int i,
  ) {
    final RequestOptions o = adapter.requests[i];
    final Object? data = o.data;
    return (
      method: o.method,
      path: o.uri.path.replaceFirst('/api/v1', ''),
      query: o.uri.queryParameters,
      body: data is String ? jsonDecode(data) : data,
    );
  }

  test('communities: list, search, create, get, patch, lifecycle', () async {
    final CommunitiesApi api = CommunitiesApi(client);
    await api.list(q: 'save', topic: 'budgeting');
    await api.list(mine: true);
    await api.create(
      const CommunityInput(
        name: 'Savers Circle',
        slug: 'savers-circle',
        visibility: CommunityInputVisibility.private,
        topics: <String>['saving'],
      ),
    );
    await api.get('savers-circle');
    await api.update('com-1', <String, Object?>{'rules': '', 'version': 3});
    await api.archive('com-1');
    await api.restore('com-1');
    await api.transferOwnership('com-1', 'u-ravi');
    await api.join('com-1');
    await api.leave('com-1');
    expect(sent(0).query, <String, String>{'q': 'save', 'topic': 'budgeting'});
    expect(sent(1).query, <String, String>{'mine': 'true'});
    expect(sent(2).method, 'POST');
    expect(sent(2).body, <String, Object?>{
      'name': 'Savers Circle',
      'slug': 'savers-circle',
      'topics': <Object?>['saving'],
      'visibility': 'private',
    });
    expect(sent(3).path, '/communities/savers-circle');
    expect(sent(4).method, 'PATCH');
    expect(sent(4).body, <String, Object?>{'rules': '', 'version': 3});
    expect(
      <String>[
        for (int i = 5; i < 10; i++) '${sent(i).method} ${sent(i).path}',
      ],
      <String>[
        'POST /communities/com-1/archive',
        'POST /communities/com-1/restore',
        'POST /communities/com-1/transfer-ownership',
        'POST /communities/com-1/join',
        'POST /communities/com-1/leave',
      ],
    );
    expect(sent(7).body, <String, Object?>{'user_id': 'u-ravi'});
  });

  test('members, invitations and link tokens in bodies only', () async {
    final CommunitiesApi api = CommunitiesApi(client);
    await api.members('com-1', status: 'pending');
    await api.setMemberRole(
      'com-1',
      'u-ravi',
      CommunityMemberRoleInputRole.moderator,
    );
    await api.approveMember('com-1', 'u-ravi');
    await api.rejectMember('com-1', 'u-meera');
    await api.invitations('com-1', includeInactive: true);
    final CommunityInvitationDto created = await api.createInvitation(
      'com-1',
      const CommunityInvitationInput(expiresInDays: 3),
    );
    await api.revokeInvitation('com-1', 'inv-1');
    await api.myInvitations();
    await api.previewInvitation('tok-abcdefghijklmnop');
    await api.acceptInvitationLink('tok-abcdefghijklmnop');
    await api.acceptInvitation('inv-2');
    await api.declineInvitation('inv-3');
    expect(sent(0).query, <String, String>{'status': 'pending'});
    expect(sent(1).body, <String, Object?>{'role': 'moderator'});
    expect(sent(2).path, '/communities/com-1/members/u-ravi/approve');
    expect(sent(3).path, '/communities/com-1/members/u-meera/reject');
    expect(sent(4).query, <String, String>{'include_inactive': 'true'});
    expect(sent(5).body, <String, Object?>{'expires_in_days': 3});
    expect(created.token, 'tok-abcdefghijklmnop');
    expect(sent(6).method, 'DELETE');
    expect(sent(6).path, '/communities/com-1/invitations/inv-1');
    expect(sent(7).path, '/community-invitations');
    for (final int i in <int>[8, 9]) {
      expect(sent(i).body, <String, Object?>{'token': 'tok-abcdefghijklmnop'});
      expect(adapter.requests[i].uri.toString(), isNot(contains('tok-')));
    }
    expect(sent(8).path, '/community-invitations/preview');
    expect(sent(9).path, '/community-invitations/accept');
    expect(sent(10).path, '/community-invitations/inv-2/accept');
    expect(sent(11).path, '/community-invitations/inv-3/decline');
  });

  test('feed pages with a cursor (never offset); posts, comments, polls, '
      'reactions and reports', () async {
    final CommunitiesApi api = CommunitiesApi(client);
    final CursorPage<CommunityPostDto> first = await api.posts(
      'com-1',
      sort: 'top',
      q: 'groceries',
    );
    await api.posts('com-1', cursor: first.nextCursor);
    await api.createPost(
      'com-1',
      const CommunityPostInput(
        title: 'Which app?',
        kind: CommunityPostInputKind.poll,
        poll: CommunityPollInput(
          question: 'Pick one',
          options: <String>['Notes', 'Spreadsheet'],
        ),
      ),
    );
    final CommunityPostDetail detail = await api.post('post-1');
    await api.updatePost('post-1', const CommunityPostInput(title: 'Edited'));
    await api.deletePost('post-1');
    await api.comment(
      'post-1',
      const CommunityCommentInput(body: 'Thanks!', parentCommentId: 'cmt-1'),
    );
    await api.updateComment('cmt-1', const CommunityCommentInput(body: 'x'));
    await api.deleteComment('cmt-1');
    final CommunityPollDto poll = await api.vote('post-1', <String>[
      'opt-sheet',
    ]);
    final CommunityReactionsDto r = await api.reactToPost(
      'post-1',
      CommunityReactionInputKind.helpful,
    );
    await api.unreactPost('post-1', CommunityReactionInputKind.like);
    await api.reactToComment('cmt-1', CommunityReactionInputKind.support);
    await api.unreactComment('cmt-1', CommunityReactionInputKind.support);
    await api.reportPost(
      'post-1',
      const PostReportInput(reason: PostReportInputReason.spam, details: 'x'),
    );
    expect(sent(0).query, <String, String>{
      'sort': 'top',
      'q': 'groceries',
      'limit': '20',
    });
    expect(first.nextCursor, 'c2');
    expect(sent(1).query, <String, String>{
      'sort': 'new',
      'cursor': 'c2',
      'limit': '20',
    });
    expect(sent(1).query.containsKey('offset'), isFalse);
    expect(sent(2).body, <String, Object?>{
      'kind': 'poll',
      'poll': <String, Object?>{
        'options': <Object?>['Notes', 'Spreadsheet'],
        'question': 'Pick one',
      },
      'title': 'Which app?',
    });
    expect(detail.comments, isEmpty);
    expect(sent(4).method, 'PATCH');
    expect(sent(5).method, 'DELETE');
    expect(sent(6).body, <String, Object?>{
      'body': 'Thanks!',
      'parent_comment_id': 'cmt-1',
    });
    expect(sent(6).path, '/posts/post-1/comments');
    expect(sent(7).path, '/comments/cmt-1');
    expect(sent(8).method, 'DELETE');
    expect(sent(9).body, <String, Object?>{
      'option_ids': <Object?>['opt-sheet'],
    });
    expect(poll.myVotes, <String>['opt-sheet']);
    expect(sent(10).body, <String, Object?>{'kind': 'helpful'});
    expect(r.myReactions, <String>['helpful']);
    expect(sent(11).path, '/posts/post-1/reactions/like');
    expect(sent(11).method, 'DELETE');
    expect(sent(12).path, '/comments/cmt-1/reactions');
    expect(sent(13).path, '/comments/cmt-1/reactions/support');
    expect(sent(14).path, '/posts/post-1/reports');
    expect(sent(14).body, <String, Object?>{'details': 'x', 'reason': 'spam'});
  });

  test('community moderation: queue, act, appeals, log, reverse', () async {
    final CommunitiesApi api = CommunitiesApi(client);
    await api.moderationReports('com-1', status: 'open');
    await api.moderate(
      'com-1',
      const ModerationActionInput(
        action: ModerationActionInputAction.restrict,
        targetType: ModerationActionInputTargetType.member,
        targetId: 'u-ravi',
        reason: 'Cool down',
        durationHours: 24,
        reportId: 'rep-1',
      ),
    );
    await api.moderationAppeals('com-1');
    await api.moderationLog('com-1');
    await api.reverseAction('act-1', note: 'Mistake');
    await api.decideAppeal(
      'apl-1',
      const AppealDecisionInput(
        decision: AppealDecisionInputDecision.overturned,
        note: 'Fair',
      ),
    );
    expect(sent(0).path, '/communities/com-1/moderation/reports');
    expect(sent(0).query, <String, String>{'status': 'open'});
    expect(sent(1).body, <String, Object?>{
      'action': 'restrict',
      'duration_hours': 24,
      'reason': 'Cool down',
      'report_id': 'rep-1',
      'target_id': 'u-ravi',
      'target_type': 'member',
    });
    expect(sent(2).path, '/communities/com-1/moderation/appeals');
    expect(sent(3).path, '/communities/com-1/moderation/actions');
    expect(sent(4).path, '/moderation/actions/act-1/reverse');
    expect(sent(4).body, <String, Object?>{'note': 'Mistake'});
    expect(sent(5).path, '/moderation/appeals/apl-1/decide');
    expect(sent(5).body, <String, Object?>{
      'decision': 'overturned',
      'note': 'Fair',
    });
  });

  test('moderation about me: decisions, appeals, reports', () async {
    final ModerationApi api = ModerationApi(client);
    final List<ModerationActionDto> mine = await api.myModeration();
    await api.myAppeals();
    await api.appeal('act-1', 'It was on topic.');
    await api.myReports();
    await api.report(
      const ModerationReportInput(
        reason: ModerationReportInputReason.harassment,
        targetType: ModerationReportInputTargetType.comment,
        targetId: 'cmt-2',
      ),
    );
    expect(mine.single.appealable, isTrue);
    expect(sent(0).path, '/me/moderation');
    expect(sent(1).path, '/me/moderation/appeals');
    expect(sent(2).path, '/moderation/actions/act-1/appeals');
    expect(sent(2).body, <String, Object?>{'statement': 'It was on topic.'});
    expect(sent(3).path, '/content-reports');
    expect(sent(4).method, 'POST');
    expect(sent(4).body, <String, Object?>{
      'reason': 'harassment',
      'target_id': 'cmt-2',
      'target_type': 'comment',
    });
  });

  test('challenges: pages, create, patch, join, sharing, progress, '
      'leaderboard, leave, cancel', () async {
    final ChallengesApi api = ChallengesApi(client);
    final CursorPage<ChallengeDto> first = await api.list(scope: 'mine');
    await api.list(scope: 'discover', cursor: first.nextCursor);
    await api.create(
      const ChallengeInput(
        title: 'No-spend week',
        challengeType: ChallengeInputChallengeType.noSpend,
        metric: ChallengeInputMetric.days,
        targetValue: 5,
        startsOn: '2026-11-01',
        endsOn: '2026-11-30',
        visibility: ChallengeInputVisibility.community,
        communityId: 'com-1',
        leaderboardEnabled: true,
      ),
    );
    await api.get('ch-1');
    await api.update('ch-1', <String, Object?>{
      'description': '',
      'version': 2,
    });
    await api.join(
      'ch-1',
      const ChallengeJoinInput(shareProgress: true, showOnLeaderboard: true),
    );
    await api.updateParticipation(
      'ch-1',
      const ChallengeJoinInput(shareProgress: false, showOnLeaderboard: false),
    );
    await api.recordProgress(
      'ch-1',
      const ChallengeProgressInput(date: '2026-11-04', value: 1, note: 'Done'),
    );
    await api.leaderboard('ch-1');
    await api.leave('ch-1');
    await api.cancel('ch-1');
    expect(sent(0).query, <String, String>{'scope': 'mine', 'limit': '50'});
    expect(sent(1).query, <String, String>{
      'scope': 'discover',
      'cursor': 'c2',
      'limit': '50',
    });
    expect(sent(2).body, <String, Object?>{
      'challenge_type': 'no_spend',
      'community_id': 'com-1',
      'ends_on': '2026-11-30',
      'leaderboard_enabled': true,
      'metric': 'days',
      'starts_on': '2026-11-01',
      'target_value': 5,
      'title': 'No-spend week',
      'visibility': 'community',
    });
    expect(sent(4).method, 'PATCH');
    expect(sent(4).body, <String, Object?>{'description': '', 'version': 2});
    expect(sent(5).path, '/challenges/ch-1/join');
    expect(sent(6).method, 'PATCH');
    expect(sent(6).path, '/challenges/ch-1/participation');
    expect(sent(7).body, <String, Object?>{
      'date': '2026-11-04',
      'note': 'Done',
      'value': 1,
    });
    expect(sent(8).path, '/challenges/ch-1/leaderboard');
    expect(sent(9).path, '/challenges/ch-1/leave');
    expect(sent(10).path, '/challenges/ch-1/cancel');
  });

  test('every endpoint used here is in ApiEndpoints.all', () {
    for (final ApiEndpoint e in <ApiEndpoint>[
      ApiEndpoints.listCommunities,
      ApiEndpoints.previewCommunityInvitation,
      ApiEndpoints.acceptCommunityInvitationLink,
      ApiEndpoints.listCommunityPosts,
      ApiEndpoints.votePoll,
      ApiEndpoints.communityModerationAct,
      ApiEndpoints.decideModerationAppeal,
      ApiEndpoints.reverseModerationAction,
      ApiEndpoints.myModeration,
      ApiEndpoints.appealModerationAction,
      ApiEndpoints.challengeLeaderboard,
      ApiEndpoints.updateChallenge,
    ]) {
      expect(ApiEndpoints.all, contains(e));
    }
  });
}
