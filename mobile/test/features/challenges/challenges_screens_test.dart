import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/challenges/data/challenges_api.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';

import '../../helpers/challenges_fakes.dart';
import '../../helpers/communities_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockChallengesApi api;
  late MockCommunitiesApi communities;

  setUpAll(() {
    registerChallengeFallbacks();
    registerCommunityFallbacks();
  });

  setUp(() {
    api = MockChallengesApi();
    communities = MockCommunitiesApi();
    when(() => communities.get(any())).thenAnswer((_) async => community());
    when(() => communities.list(mine: true))
        .thenAnswer((_) async => <CommunityDto>[community()]);
  });

  List<Override> overrides() => <Override>[
    challengesApiProvider.overrideWithValue(api),
    communitiesApiProvider.overrideWithValue(communities),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  void stubList({
    List<ChallengeDto>? mine,
    List<ChallengeDto>? discover,
    String? next,
  }) {
    when(() => api.list(scope: 'mine', cursor: null)).thenAnswer(
      (_) async => challengesPage(
        mine ?? <ChallengeDto>[challenge(me: participationJson(percent: 40))],
        next: next,
      ),
    );
    when(() => api.list(scope: 'discover', cursor: null))
        .thenAnswer((_) async => challengesPage(discover ?? <ChallengeDto>[]));
  }

  group('list', () {
    testWidgets('shows challenges with progress and loads more', (
      WidgetTester tester,
    ) async {
      stubList(next: 'c2');
      when(() => api.list(scope: 'mine', cursor: 'c2')).thenAnswer(
        (_) async => challengesPage(<ChallengeDto>[
          challenge(id: 'ch-2', title: 'Grocery month', status: 'completed'),
        ]),
      );
      await pump(tester, '/challenges');
      expect(find.text('No-spend week'), findsOneWidget);
      expect(find.text('40 % done'), findsOneWidget);
      expect(find.text('Savers Circle · 3 taking part'), findsOneWidget);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Grocery month'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('empty and failed states', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.list(scope: 'mine', cursor: null)).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return challengesPage(<ChallengeDto>[]);
      });
      when(() => api.list(scope: 'discover', cursor: null))
          .thenAnswer((_) async => challengesPage(<ChallengeDto>[]));
      await pump(tester, '/challenges');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No challenges yet'), findsOneWidget);
      await tester.tap(find.text('Join one'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to join right now'), findsOneWidget);
    });
  });

  group('create and edit', () {
    testWidgets('creates a community challenge from the community preset', (
      WidgetTester tester,
    ) async {
      final List<ChallengeInput> sent = <ChallengeInput>[];
      when(() => api.create(any())).thenAnswer((Invocation i) async {
        sent.add(i.positionalArguments.first as ChallengeInput);
        return challenge(id: 'ch-new');
      });
      when(() => api.get('ch-new')).thenAnswer((_) async => challenge());
      final GoRouter router = await pump(
        tester,
        '/challenges/new?community_id=com-1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'No-spend week',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Target'), '5');
      await scrollTo(tester, find.text('Savers Circle'));
      expect(find.text('Savers Circle'), findsOneWidget);
      await scrollTo(tester, find.text('Leaderboard'));
      await tester.tap(find.text('Leaderboard'));
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.widgetWithText(FilledButton, 'Start a challenge'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Start a challenge'));
      await tester.pumpAndSettle();
      final Map<String, Object?> body = sent.single.toJson();
      expect(body['title'], 'No-spend week');
      expect(body['challenge_type'], 'no_spend');
      expect(body['metric'], 'days');
      expect(body['target_value'], 5);
      expect(body['visibility'], 'community');
      expect(body['community_id'], 'com-1');
      expect(body['leaderboard_enabled'], isTrue);
      expect(router.state.uri.toString(), '/challenges/ch-new');
    });

    testWidgets('a percent target above 100 is refused before sending', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/challenges/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Save',
      );
      await scrollTo(tester, find.text('Your own percentage'));
      await tester.tap(find.text('Your own percentage'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target'),
        '150',
      );
      await scrollTo(
        tester,
        find.widgetWithText(FilledButton, 'Start a challenge'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Start a challenge'));
      await tester.pumpAndSettle();
      verifyNever(() => api.create(any()));
    });

    testWidgets('editing sends only what changed with the version; a '
        'conflict reloads', (WidgetTester tester) async {
      int gets = 0;
      when(() => api.get('ch-1')).thenAnswer((_) async {
        gets++;
        return challenge(mine: true, version: gets == 1 ? 2 : 3);
      });
      final List<Map<String, Object?>> patches = <Map<String, Object?>>[];
      when(() => api.update('ch-1', any())).thenAnswer((Invocation i) async {
        patches.add(i.positionalArguments[1] as Map<String, Object?>);
        if (patches.length == 1) {
          throw serverError(ErrorObjectCode.versionConflict, status: 409);
        }
        return challenge(mine: true, version: 4);
      });
      await pump(tester, '/challenges/ch-1/edit');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'No-spend fortnight',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description (optional)'),
        '',
      );
      await scrollTo(tester, find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(patches.first, <String, Object?>{
        'title': 'No-spend fortnight',
        'description': '',
        'version': 2,
      });
      await tester.scrollUntilVisible(
        find.textContaining('This was changed somewhere else'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('This was changed somewhere else'),
        findsOneWidget,
      );
    });
  });

  group('detail', () {
    testWidgets('joining keeps progress private unless shared', (
      WidgetTester tester,
    ) async {
      final List<ChallengeJoinInput> joins = <ChallengeJoinInput>[];
      when(() => api.get('ch-1')).thenAnswer((_) async => challenge());
      when(() => api.join('ch-1', any())).thenAnswer((Invocation i) async {
        joins.add(i.positionalArguments[1] as ChallengeJoinInput);
        return challenge(me: participationJson());
      });
      await pump(tester, '/challenges/ch-1');
      expect(find.text('Savers Circle'), findsOneWidget);
      final Finder optIn = find.textContaining(
        'The leaderboard is shared both ways',
      );
      await scrollTo(tester, optIn);
      expect(optIn, findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Join'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();
      expect(joins.single.toJson(), <String, Object?>{
        'share_progress': false,
        'show_on_leaderboard': false,
      });
      verifyNever(() => api.leaderboard(any()));
    });

    testWidgets('participants check in, see milestones, and see the '
        'leaderboard once they appear on it', (WidgetTester tester) async {
      when(() => api.get('ch-1')).thenAnswer(
        (_) async => challenge(
          me: participationJson(share: true, show: true, percent: 60),
        ),
      );
      when(() => api.leaderboard('ch-1')).thenAnswer(
        (_) async => <ChallengeLeaderboardEntry>[
          leaderEntry(),
          leaderEntry(rank: 2, name: 'Asha', me: true),
        ],
      );
      final List<ChallengeProgressInput> checkIns = <ChallengeProgressInput>[];
      when(() => api.recordProgress('ch-1', any()))
          .thenAnswer((Invocation i) async {
            checkIns.add(i.positionalArguments[1] as ChallengeProgressInput);
            return challenge(me: participationJson(share: true, show: true));
          });
      await pump(tester, '/challenges/ch-1');
      expect(find.text('60 % done'), findsWidgets);
      expect(find.text('Halfway there'), findsOneWidget);
      await scrollTo(tester, find.widgetWithText(ChoiceChip, 'Missed'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Missed'));
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.widgetWithText(FilledButton, 'Save check-in'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save check-in'));
      await tester.pumpAndSettle();
      expect(checkIns.single.value, 0);
      expect(checkIns.single.date, isNotNull);
      await scrollTo(tester, find.text('Asha (you)'));
      expect(find.text('Ravi Kumar'), findsOneWidget);
    });

    testWidgets('the creator cancels after confirming; a challenge without a '
        'leaderboard says so', (WidgetTester tester) async {
      when(() => api.get('ch-1')).thenAnswer(
        (_) async =>
            challenge(mine: true, leaderboard: false, visibility: 'private'),
      );
      when(() => api.cancel('ch-1'))
          .thenAnswer((_) async => challenge(status: 'cancelled'));
      await pump(tester, '/challenges/ch-1');
      await scrollTo(tester, find.text('This challenge has no leaderboard.'));
      expect(find.text('This challenge has no leaderboard.'), findsOneWidget);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel challenge'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel challenge'));
      await tester.pumpAndSettle();
      verify(() => api.cancel('ch-1')).called(1);
    });

    testWidgets('a failed load offers a retry', (WidgetTester tester) async {
      when(() => api.get('ch-1'))
          .thenThrow(serverError(ErrorObjectCode.notFound, status: 404));
      await pump(tester, '/challenges/ch-1');
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
