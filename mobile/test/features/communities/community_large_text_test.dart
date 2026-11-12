import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/challenges/data/challenges_api.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/invite_links.dart';
import 'package:montra_mobile/features/moderation/data/moderation_api.dart';

import '../../helpers/challenges_fakes.dart';
import '../../helpers/communities_fakes.dart';
import '../../helpers/moderation_fakes.dart';
import '../../helpers/router_app.dart';

/// Community, challenge and moderation screens at 200 % text in English and
/// Hindi must lay out without overflow.
void main() {
  late MockCommunitiesApi api;
  late MockChallengesApi challenges;
  late MockModerationApi moderation;

  setUpAll(() {
    registerCommunityFallbacks();
    registerChallengeFallbacks();
    registerModerationFallbacks();
  });

  setUp(() {
    api = MockCommunitiesApi();
    challenges = MockChallengesApi();
    moderation = MockModerationApi();
    final CommunityDto owned = community(
      name: 'A rather long community name for people who save together',
      myRole: 'owner',
      canModerate: true,
      restrictedUntil: null,
    );
    when(
      () => api.list(
        q: any(named: 'q'),
        topic: any(named: 'topic'),
      ),
    ).thenAnswer((_) async => <CommunityDto>[owned, community(id: 'com-2')]);
    when(() => api.list(mine: true))
        .thenAnswer((_) async => <CommunityDto>[owned]);
    when(() => api.myInvitations()).thenAnswer(
      (_) async => <CommunityInvitationDto>[invitation(kind: 'username')],
    );
    when(() => api.get(any())).thenAnswer((_) async => owned);
    when(
      () => api.posts(
        any(),
        sort: any(named: 'sort'),
        q: any(named: 'q'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => postsPage(<CommunityPostDto>[
        CommunityPostDto.fromJson(
          postJson(pinned: true, locked: true, status: 'hidden'),
        ),
        post(id: 'post-2'),
      ], next: 'c2'),
    );
    when(() => api.post(any())).thenAnswer(
      (_) async => postDetail(
        overrides: <String, Object?>{
          'kind': 'poll',
          'poll': pollJson(myVotes: <String>['opt-sheet']),
          'link_url': 'https://www.rbi.org.in/',
          'removed_reason': 'A long reason from the moderator for this',
        },
        comments: <Map<String, Object?>>[
          commentJson(id: 'c1'),
          commentJson(id: 'c2', parent: 'c1'),
          commentJson(id: 'c3', parent: 'c2'),
          commentJson(id: 'c4', parent: 'c3', status: 'hidden'),
          commentJson(id: 'c5', parent: 'c4', status: 'deleted', body: ''),
        ],
      ),
    );
    when(
      () => api.invitations(
        any(),
        includeInactive: any(named: 'includeInactive'),
      ),
    ).thenAnswer(
      (_) async => <CommunityInvitationDto>[
        invitation(),
        invitation(id: 'inv-2', kind: 'username', status: 'used'),
      ],
    );
    when(() => api.members(any(), status: any(named: 'status'))).thenAnswer(
      (_) async => <CommunityMemberDto>[
        member(id: meId, name: 'Asha', role: 'owner'),
        member(),
        member(id: 'u-3', name: 'Neha Verma', status: 'pending'),
      ],
    );
    when(() => api.moderationReports(any(), status: any(named: 'status')))
        .thenAnswer((_) async => <ModerationReportDto>[report()]);
    when(() => api.moderationAppeals(any()))
        .thenAnswer((_) async => <ModerationAppealDto>[appealDto()]);
    when(() => api.moderationLog(any())).thenAnswer(
      (_) async => <ModerationActionDto>[
        modAction(expiresAt: '2026-12-01T00:00:00Z'),
        modAction(id: 'act-2', reversedAt: '2026-11-06T00:00:00Z'),
      ],
    );
    when(() => api.previewInvitation(any())).thenAnswer((_) async => preview());
    when(
      () => challenges.list(
        scope: any(named: 'scope'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer(
      (_) async => challengesPage(<ChallengeDto>[
        challenge(me: participationJson()),
        challenge(id: 'ch-2', status: 'cancelled'),
      ], next: 'c2'),
    );
    when(() => challenges.get(any())).thenAnswer(
      (_) async => challenge(
        mine: true,
        me: participationJson(share: true, show: true, percent: 75),
      ),
    );
    when(() => challenges.leaderboard(any())).thenAnswer(
      (_) async => <ChallengeLeaderboardEntry>[
        leaderEntry(name: 'Somebody with a really long display name'),
        leaderEntry(rank: 2, name: 'Asha', me: true),
      ],
    );
    when(() => moderation.myModeration()).thenAnswer(
      (_) async => <ModerationActionDto>[
        modAction(appealUntil: '2099-01-01T00:00:00Z'),
        modAction(
          id: 'act-2',
          appealable: false,
          appeal: <String, Object?>{
            'id': 'apl-2',
            'status': 'upheld',
            'decision_note': 'It broke rule 2 of the community.',
            'decided_at': '2026-11-07T08:00:00Z',
            'created_at': '2026-11-06T08:00:00Z',
          },
        ),
      ],
    );
    when(() => moderation.myAppeals()).thenAnswer(
      (_) async => <ModerationAppealDto>[appealDto(status: 'overturned')],
    );
    when(() => moderation.myReports())
        .thenAnswer((_) async => <ModerationReportDto>[myReport()]);
  });

  List<Override> overrides() => <Override>[
    communitiesApiProvider.overrideWithValue(api),
    challengesApiProvider.overrideWithValue(challenges),
    moderationApiProvider.overrideWithValue(moderation),
    webAppOriginProvider.overrideWithValue(null),
  ];

  Future<void> walk(
    WidgetTester tester,
    Locale locale,
    List<String> locations,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ({Widget app, GoRouter router}) r = routedApp(
      locations.first,
      overrides: overrides(),
      locale: locale,
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: locations.first);
    for (final String location in locations.skip(1)) {
      unawaited(r.router.push<Object?>(location));
      await tester.pumpAndSettle();
      for (int i = 0; i < 10; i++) {
        await tester.dragFrom(const Offset(180, 560), const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: location);
      r.router.pop();
      await tester.pumpAndSettle();
    }
  }

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('community screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      await walk(tester, locale, <String>[
        '/communities',
        '/communities?tab=invitations',
        '/communities/new',
        '/communities/join#token=qA4fseFCgSEWsyznVadmfMt4JrZF03An',
        '/communities/com-1',
        '/communities/com-1/posts/new',
        '/posts/post-1',
        '/communities/com-1/settings',
        '/communities/com-1/members',
        '/communities/com-1/moderation',
      ]);
    });

    testWidgets('challenge and moderation screens fit at 200% text '
        '($locale)', (WidgetTester tester) async {
      await walk(tester, locale, <String>[
        '/challenges',
        '/challenges/new',
        '/challenges/ch-1',
        '/challenges/ch-1/edit',
        '/moderation',
        '/moderation?tab=appeals',
        '/moderation?tab=reports',
      ]);
    });
  }
}
