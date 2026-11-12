import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';
import 'package:montra_mobile/features/social/domain/social_display.dart';

import '../../helpers/fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/social_fakes.dart';

const String token = 'tok_abcdefghijklmnop';

void main() {
  late MockSocialApi social;
  late MockGroupsApi groups;
  late MockPeopleApi people;

  setUpAll(registerSocialFallbacks);

  setUp(() {
    social = MockSocialApi();
    groups = MockGroupsApi();
    people = MockPeopleApi();
    stubSocialReads(
      social,
      connections: <PublicProfile>[
        profile(name: 'A friend with a rather long display name', muted: true),
      ],
      requests: <FriendRequestDto>[
        friendRequest(message: 'A fairly long message to see it wrap nicely'),
      ],
    );
    stubGroupReads(
      groups,
      mine: <GroupInvitationDto>[invitation(kind: 'username')],
      requests: <GroupJoinRequestDto>[joinRequest(message: 'Hello')],
      invitations: <GroupInvitationDto>[
        invitation(),
        invitation(kind: 'username'),
      ],
    );
    stubPeople(people);
    when(() => people.group('grp-home')).thenAnswer(
      (_) async => groupDetailOf(
        type: 'trip',
        destination: 'Goa',
        startDate: '2026-12-01',
        endDate: '2026-12-05',
        description: 'A long description of the trip for the whole family',
      ),
    );
    when(() => groups.previewInvitation(token))
        .thenAnswer((_) async => invitationPreview(requiresApproval: true));
  });

  List<Override> overrides() => <Override>[
    socialApiProvider.overrideWithValue(social),
    groupsApiProvider.overrideWithValue(groups),
    peopleApiProvider.overrideWithValue(people),
  ];

  group('Together hub', () {
    testWidgets('shows counts and opens every area', (
      WidgetTester tester,
    ) async {
      final ({Widget app, GoRouter router}) r = routedApp(
        '/together',
        overrides: overrides(),
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(find.text('1 friend request is waiting'), findsOneWidget);
      expect(find.text('1 group invitation for you'), findsOneWidget);
      expect(find.text('Communities'), findsOneWidget);
      expect(find.text('Challenges'), findsOneWidget);
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(locationOf(r.router), '/friends?tab=requests');
    });

    testWidgets('works when nothing can be loaded', (
      WidgetTester tester,
    ) async {
      when(() => social.friendRequests()).thenThrow(offline);
      when(() => groups.list(includeArchived: any(named: 'includeArchived')))
          .thenThrow(offline);
      when(() => groups.myInvitations()).thenThrow(offline);
      final ({Widget app, GoRouter router}) r = routedApp(
        '/together',
        overrides: overrides(),
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(
        find.text('Find people by username and manage requests'),
        findsOneWidget,
      );
      expect(
        find.text('Split expenses with a household, trip or friends'),
        findsOneWidget,
      );
      await tester.tap(find.text('Join a group with a link'));
      await tester.pumpAndSettle();
      expect(locationOf(r.router), '/groups/join');
    });
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('friends and group screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final ({Widget app, GoRouter router}) r = routedApp(
        '/together',
        overrides: overrides(),
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final String location in <String>[
        '/friends',
        '/friends?tab=requests',
        '/friends?tab=find',
        '/friends/blocked',
        '/friends/settings',
        '/groups',
        '/groups/new',
        '/groups/join',
        '/groups/join#token=$token',
        '/groups/grp-home',
        '/groups/grp-home/settings',
        '/groups/grp-home/activity',
        '/groups/grp-home/edit',
      ]) {
        r.router.go(location);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
      }
    });
  }

  group('display', () {
    test(
      'every activity kind has a sentence without English server text',
      () async {
        for (final Locale locale in AppLocalizations.supportedLocales) {
          final AppLocalizations l10n = await AppLocalizations.delegate.load(
            locale,
          );
          for (final GroupActivityDtoKind kind in GroupActivityDtoKind.values) {
            final String text = activitySentence(
              l10n,
              activityEvent(kind: kind.json.isEmpty ? 'x' : kind.json),
              actor: 'Asha',
              target: 'Ben',
            );
            expect(text, isNotEmpty, reason: '$locale ${kind.json}');
            expect(
              text.contains('Asha') || text.contains('Ben'),
              isTrue,
              reason: '$locale ${kind.json}',
            );
          }
        }
      },
    );

    test('disputes name a payment or an expense by target_type', () async {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      String sentence(Map<String, Object?> summary) => activitySentence(
        l10n,
        activityEvent(kind: 'dispute_resolved', summary: summary),
        actor: 'Asha',
        target: 'Ben',
      );
      expect(
        sentence(<String, Object?>{'target_type': 'settlement'}),
        'Asha resolved the question about a payment.',
      );
      expect(
        sentence(<String, Object?>{
          'target_type': 'expense',
          'description': 'Groceries',
        }),
        'Asha resolved the question about “Groceries”.',
      );
      expect(
        sentence(<String, Object?>{'description': 'Groceries'}),
        'Asha resolved the question about “Groceries”.',
        reason: 'older events without target_type are about expenses',
      );
    });

    test('coded answers of this area are localized', () async {
      final AppLocalizations hi = await AppLocalizations.delegate.load(
        const Locale('hi'),
      );
      for (final String code in <String>[
        'already_friends',
        'request_pending',
        'requests_closed',
        'already_member',
        'join_request_pending',
        'invitation_used',
        'invitation_inactive',
        'group_archived',
        'group_not_archived',
        'balance_open',
        'balances_open',
        'transfer_ownership_first',
        'currency_locked',
      ]) {
        final String text = detailMessage(
          hi,
          Detail(
            message: 'English',
            code: code,
            params: const <String, String>{'status': 'declined'},
          ),
        );
        expect(text, isNot('English'), reason: code);
      }
      expect(
        detailMessage(
          hi,
          const Detail(
            message: 'x',
            code: 'invitation_used',
            params: <String, String>{'status': 'declined'},
          ),
        ),
        contains(hi.groupInvitationStatusDeclined),
      );
    });

    test('invitation links and usernames', () {
      expect(
        InviteLinks.tokenFrom('https://a.example/groups/join#token=$token'),
        token,
      );
      expect(InviteLinks.tokenFrom('  $token  '), token);
      expect(InviteLinks.tokenFrom('https://a.example/x?token=$token'), token);
      expect(InviteLinks.tokenFrom('hello'), isNull);
      expect(
        InviteLinks.groupJoinLink(testConfig, token).toString(),
        'http://localhost:8080/groups/join#token=$token',
      );
    });

    test(
      "the server's share_url is preferred when it is a group join link",
      () {
        const String good = 'https://app.example/groups/join#token=$token';
        expect(InviteLinks.groupShareUrl(good), good);
        expect(InviteLinks.groupShareUrl(null), isNull);
        expect(
          InviteLinks.groupShareUrl(
            'ftp://app.example/groups/join#token=$token',
          ),
          isNull,
        );
        expect(
          InviteLinks.groupShareUrl(
            'https://app.example/communities/join#token=$token',
          ),
          isNull,
        );
        expect(
          InviteLinks.groupShareUrl('https://app.example/groups/join'),
          isNull,
        );
        expect(InviteLinks.groupShareUrl('/groups/join#token=$token'), isNull);
      },
    );
  });
}
