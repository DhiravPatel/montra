import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/social_fakes.dart';

void main() {
  late MockSocialApi social;
  late MockGroupsApi groups;
  late MockPeopleApi people;

  setUpAll(registerSocialFallbacks);

  setUp(() {
    social = MockSocialApi();
    groups = MockGroupsApi();
    people = MockPeopleApi();
    stubSocialReads(social);
    stubGroupReads(groups);
    stubPeople(people);
  });

  List<Override> overrides() => <Override>[
    socialApiProvider.overrideWithValue(social),
    groupsApiProvider.overrideWithValue(groups),
    peopleApiProvider.overrideWithValue(people),
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

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  ApiException conflict(String code) => serverError(
    ErrorObjectCode.conflict,
    status: 409,
    details: <Detail>[Detail(message: 'English', code: code)],
  );

  group('friends tab', () {
    testWidgets('lists friends; blocking is confirmed and explained', (
      WidgetTester tester,
    ) async {
      when(() => social.block('u-ben')).thenAnswer((_) async {});
      await pump(tester, '/friends');
      expect(find.text('Friends'), findsWidgets);
      expect(find.text('Ben Shah'), findsOneWidget);
      expect(find.text('@ben'), findsOneWidget);

      await tapText(tester, 'Ben Shah');
      expect(find.text('Remove friend'), findsOneWidget);
      await tapText(tester, 'Block');
      expect(find.text('Block Ben Shah?'), findsOneWidget);
      expect(find.textContaining("They aren't told."), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();
      verify(() => social.block('u-ben')).called(1);
      expect(find.text('Ben Shah is blocked.'), findsOneWidget);
    });

    testWidgets('mute and remove a friend', (WidgetTester tester) async {
      when(() => social.setMuted('u-ben', muted: true))
          .thenAnswer((_) async {});
      when(() => social.removeFriend('u-ben')).thenAnswer((_) async {});
      await pump(tester, '/friends');
      await tapText(tester, 'Ben Shah');
      await tapText(tester, 'Mute');
      verify(() => social.setMuted('u-ben', muted: true)).called(1);
      expect(find.text('Ben Shah is muted.'), findsOneWidget);

      await tapText(tester, 'Ben Shah');
      await tapText(tester, 'Remove friend');
      expect(find.text('Remove Ben Shah as a friend?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove friend'));
      await tester.pumpAndSettle();
      verify(() => social.removeFriend('u-ben')).called(1);
    });

    testWidgets('empty and error states', (WidgetTester tester) async {
      int calls = 0;
      when(() => social.connections()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <PublicProfile>[];
      });
      await pump(tester, '/friends');
      expect(find.text("You're offline"), findsOneWidget);
      await tapText(tester, 'Try again');
      expect(find.text('No friends yet'), findsOneWidget);
    });
  });

  group('requests tab', () {
    testWidgets('opens from ?tab=requests; accept, decline and cancel', (
      WidgetTester tester,
    ) async {
      stubSocialReads(
        social,
        requests: <FriendRequestDto>[
          friendRequest(message: 'From the office'),
          friendRequest(
            id: 'fr-2',
            fromId: meId,
            fromName: 'Asha',
            toId: 'u-cy',
            toName: 'Cy Rao',
          ),
        ],
      );
      when(() => social.acceptFriendRequest('fr-1'))
          .thenAnswer((_) async => friendRequest(status: 'accepted'));
      when(() => social.cancelFriendRequest('fr-2'))
          .thenAnswer((_) async => friendRequest(status: 'cancelled'));
      await pump(tester, '/friends?tab=requests');
      expect(find.text('Requests (1)'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('“From the office”'), findsOneWidget);
      expect(find.text('Sent by you'), findsOneWidget);
      expect(find.text('Cy Rao'), findsOneWidget);

      await tapText(tester, 'Accept');
      verify(() => social.acceptFriendRequest('fr-1')).called(1);
      expect(find.text('You and Ben Shah are now friends.'), findsOneWidget);

      await tapText(tester, 'Cancel request');
      verify(() => social.cancelFriendRequest('fr-2')).called(1);
    });

    testWidgets('nothing waiting', (WidgetTester tester) async {
      await pump(tester, '/friends?tab=requests');
      expect(find.text('No requests waiting'), findsOneWidget);
    });
  });

  group('find', () {
    testWidgets('exact username only; nobody found is explained', (
      WidgetTester tester,
    ) async {
      when(() => social.searchUsername(any()))
          .thenAnswer((_) async => <PublicProfile>[]);
      await pump(tester, '/friends?tab=find');
      expect(find.textContaining('Partial names find nobody'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'ab');
      await tapText(tester, 'Find');
      expect(
        find.text('Enter the full username (at least 3 characters).'),
        findsOneWidget,
      );
      verifyNever(() => social.searchUsername(any()));

      await tester.enterText(find.byType(TextFormField), '@Ravi_K');
      await tapText(tester, 'Find');
      verify(() => social.searchUsername('Ravi_K')).called(1);
      expect(
        find.textContaining('No one found with the username @Ravi_K'),
        findsOneWidget,
      );
    });

    testWidgets('sends a request; their earlier request makes you friends; '
        'coded conflicts are localized', (WidgetTester tester) async {
      when(() => social.searchUsername('ravi')).thenAnswer(
        (_) async => <PublicProfile>[
          profile(
            id: 'u-ravi',
            name: 'Ravi K',
            username: 'ravi',
            connection: 'none',
          ),
        ],
      );
      int sends = 0;
      when(() => social.sendFriendRequest('u-ravi')).thenAnswer((_) async {
        sends++;
        if (sends == 2) {
          throw conflict('request_pending');
        }
        return friendRequest(status: 'accepted');
      });
      await pump(tester, '/friends?tab=find');
      await tester.enterText(find.byType(TextFormField), 'ravi');
      await tapText(tester, 'Find');
      expect(find.text('Ravi K'), findsOneWidget);

      await tapText(tester, 'Send friend request');
      expect(find.text('You and Ravi K are now friends.'), findsOneWidget);

      await tapText(tester, 'Send friend request');
      expect(
        find.text('You already sent this person a friend request.'),
        findsOneWidget,
      );
    });

    testWidgets('closed requests are explained', (WidgetTester tester) async {
      when(() => social.searchUsername('ravi')).thenAnswer(
        (_) async => <PublicProfile>[
          profile(id: 'u-ravi', name: 'Ravi K', connection: 'none'),
        ],
      );
      when(() => social.sendFriendRequest('u-ravi')).thenThrow(
        serverError(
          ErrorObjectCode.domainRuleViolation,
          details: const <Detail>[
            Detail(message: 'English', code: 'requests_closed'),
          ],
        ),
      );
      await pump(tester, '/friends?tab=find');
      await tester.enterText(find.byType(TextFormField), 'ravi');
      await tapText(tester, 'Find');
      await tapText(tester, 'Send friend request');
      expect(
        find.text('This person is not accepting friend requests.'),
        findsOneWidget,
      );
    });
  });

  group('blocked and muted', () {
    testWidgets('unblock and unmute; more pages on request', (
      WidgetTester tester,
    ) async {
      when(() => social.blocks(cursor: null)).thenAnswer(
        (_) async => CursorPage<BlockDto>(<BlockDto>[blockDto()], 'c2'),
      );
      when(() => social.blocks(cursor: 'c2')).thenAnswer(
        (_) async => CursorPage<BlockDto>(<BlockDto>[
          blockDto(id: 'u-zed', name: 'Zed'),
        ], null),
      );
      when(() => social.unblock('u-cy')).thenAnswer((_) async {});
      when(() => social.setMuted('u-dev', muted: false))
          .thenAnswer((_) async {});
      await pump(tester, '/friends/blocked');
      expect(find.text('Cy Rao'), findsOneWidget);
      await tapText(tester, 'Load more');
      expect(find.text('Zed'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Unblock').first);
      await tester.pumpAndSettle();
      verify(() => social.unblock('u-cy')).called(1);
      expect(find.text('Cy Rao is unblocked.'), findsOneWidget);

      await tapText(tester, 'Muted');
      expect(find.text('Dev Iyer'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Unmute'));
      await tester.pumpAndSettle();
      verify(() => social.setMuted('u-dev', muted: false)).called(1);
    });

    testWidgets('empty lists', (WidgetTester tester) async {
      when(
        () => social.blocks(cursor: any(named: 'cursor')),
      ).thenAnswer((_) async => const CursorPage<BlockDto>(<BlockDto>[], null));
      await pump(tester, '/friends/blocked');
      expect(find.text("You haven't blocked anyone"), findsOneWidget);
    });
  });

  group('privacy settings', () {
    testWidgets('discovery is explained as off; only changes are sent; a '
        'taken username is shown on the field', (WidgetTester tester) async {
      final List<ProfilePatch> sent = <ProfilePatch>[];
      when(() => social.updateProfile(any())).thenAnswer((Invocation i) async {
        sent.add(i.positionalArguments.single as ProfilePatch);
        if (sent.length == 1) {
          throw serverError(
            ErrorObjectCode.conflict,
            status: 409,
            details: const <Detail>[
              Detail(
                message: 'That username is taken.',
                field: 'body.username',
              ),
            ],
          );
        }
        return ProfileDto.fromJson(profileDtoJson(username: 'asha.r'));
      });
      await pump(tester, '/friends/settings');
      expect(find.text('Let people find me by username'), findsOneWidget);
      expect(
        find.textContaining('This is off until you turn it on'),
        findsOneWidget,
      );

      await tapText(tester, 'Save');
      expect(
        find.text('Nothing changed, so there was nothing to save.'),
        findsOneWidget,
      );
      expect(sent, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '@Asha.R');
      await tapText(tester, 'Let people find me by username');
      expect(
        find.textContaining('This is off until you turn it on'),
        findsNothing,
      );
      await tapText(tester, 'Save');
      expect(sent.single.toJson(), <String, Object?>{
        'username': 'asha.r',
        'discoverable_by_username': true,
      });
      expect(
        find.text('That username is taken. Try another one.'),
        findsOneWidget,
      );

      await tapText(tester, 'Save');
      expect(find.text('Privacy settings saved.'), findsOneWidget);
    });

    testWidgets('coded username answers are shown on the field', (
      WidgetTester tester,
    ) async {
      final List<(ErrorObjectCode, int, String)> answers =
          <(ErrorObjectCode, int, String)>[
            (ErrorObjectCode.conflict, 409, 'username_taken'),
            (ErrorObjectCode.validationError, 422, 'username_reserved'),
            (ErrorObjectCode.validationError, 422, 'username_invalid'),
          ];
      int call = 0;
      when(() => social.updateProfile(any())).thenAnswer((_) async {
        final (ErrorObjectCode code, int status, String detail) =
            answers[call++];
        throw serverError(
          code,
          status: status,
          details: <Detail>[
            Detail(
              message: 'English text',
              field: 'body.username',
              code: detail,
            ),
          ],
        );
      });
      await pump(tester, '/friends/settings');
      await tester.enterText(find.byType(TextFormField), 'montra.team');
      for (final String text in <String>[
        'That username is taken. Try another one.',
        'This username is reserved. Choose another one.',
        'Use 3 to 30 lowercase letters, digits, “_” or “.”.',
      ]) {
        await tapText(tester, 'Save');
        expect(find.text(text), findsOneWidget);
        expect(find.text('English text'), findsNothing);
      }
    });

    testWidgets('the username rules are checked first', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/friends/settings');
      await tester.enterText(find.byType(TextFormField), 'no spaces');
      await tapText(tester, 'Save');
      expect(
        find.text('Use only letters, digits, “_” and “.”.'),
        findsOneWidget,
      );
      verifyNever(() => social.updateProfile(any()));
    });

    testWidgets('who may send requests', (WidgetTester tester) async {
      when(() => social.updateProfile(any())).thenAnswer(
        (_) async => ProfileDto.fromJson(profileDtoJson(requests: 'nobody')),
      );
      await pump(tester, '/friends/settings');
      await tapText(tester, 'Anyone');
      await tapText(tester, 'Nobody');
      await tapText(tester, 'Save');
      final ProfilePatch patch =
          verify(() => social.updateProfile(captureAny())).captured.single
              as ProfilePatch;
      expect(patch.toJson(), <String, Object?>{
        'allow_friend_requests': 'nobody',
      });
    });

    testWidgets('error loading the profile', (WidgetTester tester) async {
      when(() => social.me()).thenThrow(offline);
      await pump(tester, '/friends/settings');
      expect(find.text("You're offline"), findsOneWidget);
    });
  });
}
