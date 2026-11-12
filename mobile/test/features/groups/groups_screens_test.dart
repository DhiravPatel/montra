import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';
import 'package:montra_mobile/features/social/presentation/person_widgets.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/social_fakes.dart';

const String token = 'tok_abcdefghijklmnop';

void main() {
  late MockSocialApi social;
  late MockGroupsApi groups;
  late MockPeopleApi people;
  late List<String> shared;

  setUpAll(registerSocialFallbacks);

  setUp(() {
    social = MockSocialApi();
    groups = MockGroupsApi();
    people = MockPeopleApi();
    shared = <String>[];
    stubSocialReads(social);
    stubGroupReads(groups);
    stubPeople(people);
    when(() => people.group('grp-home'))
        .thenAnswer((_) async => groupDetailOf());
  });

  List<Override> overrides() => <Override>[
    socialApiProvider.overrideWithValue(social),
    groupsApiProvider.overrideWithValue(groups),
    peopleApiProvider.overrideWithValue(people),
    textSharerProvider.overrideWithValue(
      (String text) async => shared.add(text),
    ),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    // A phone-width screen tall enough to build the whole settings page.
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
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
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Detail coded(String code, [Map<String, String>? params]) =>
      Detail(message: 'English', code: code, params: params);

  group('groups list', () {
    testWidgets('balances in words; archived on request; invitations for '
        'the user can be accepted', (WidgetTester tester) async {
      stubGroupReads(
        groups,
        list: <GroupDto>[
          groupDtoOf(net: '250.00'),
          groupDtoOf(
            id: 'grp-trip',
            name: 'Goa trip',
            net: '-80.50',
            type: 'trip',
          ),
          groupDtoOf(id: 'grp-old', name: 'Old flat', status: 'archived'),
        ],
        mine: <GroupInvitationDto>[invitation(id: 'inv-9', kind: 'username')],
      );
      when(() => groups.acceptInvitation('inv-9'))
          .thenAnswer((_) async => groupDetailOf());
      final GoRouter router = await pump(tester, '/groups');
      expect(find.text('You are owed ₹250.00'), findsOneWidget);
      expect(find.text('You owe ₹80.50'), findsOneWidget);
      expect(find.text('Trip · 3 members'), findsOneWidget);
      expect(find.text('Old flat'), findsNothing);
      await tapText(tester, 'Show archived groups');
      expect(find.text('Old flat'), findsOneWidget);
      expect(find.text('Settled up'), findsOneWidget);

      expect(find.text('Invitations for you'), findsOneWidget);
      expect(find.text('Invited by Asha'), findsOneWidget);
      await tapText(tester, 'Join');
      verify(() => groups.acceptInvitation('inv-9')).called(1);
      expect(locationOf(router), '/groups/grp-home');
    });

    testWidgets('empty and error states', (WidgetTester tester) async {
      int calls = 0;
      when(() => groups.list(includeArchived: any(named: 'includeArchived')))
          .thenAnswer((_) async {
            calls++;
            if (calls == 1) {
              throw offline;
            }
            return <GroupDto>[];
          });
      await pump(tester, '/groups');
      expect(find.text("You're offline"), findsOneWidget);
      await tapText(tester, 'Try again');
      expect(find.text('No groups yet'), findsOneWidget);
    });
  });

  group('create', () {
    testWidgets('a trip gets dates; the group opens after creating', (
      WidgetTester tester,
    ) async {
      when(() => groups.create(any())).thenAnswer((_) async => groupDetailOf());
      final GoRouter router = await pump(tester, '/groups/new');
      expect(
        find.textContaining('Off by default. When on, opening an invitation'),
        findsOneWidget,
      );
      await tapText(tester, 'Create group');
      expect(find.text('Enter a name for the group.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Group name'),
        'Goa trip',
      );
      await tapText(tester, 'Household');
      await tapText(tester, 'Trip');
      expect(find.text('Trip details'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Destination'),
        'Goa',
      );
      await tapText(tester, 'Create group');
      final GroupInput input =
          verify(() => groups.create(captureAny())).captured.single
              as GroupInput;
      expect(input.toJson(), <String, Object?>{
        'name': 'Goa trip',
        'group_type': 'trip',
        'base_currency': 'INR',
        'default_split_method': 'equal',
        'destination': 'Goa',
        'simplify_debts': true,
        'allow_member_invites': true,
        'require_join_approval': false,
      });
      expect(locationOf(router), '/groups/grp-home');
    });
  });

  group('join by link', () {
    testWidgets('the token comes from the fragment; joining opens the group', (
      WidgetTester tester,
    ) async {
      when(() => groups.previewInvitation(token))
          .thenAnswer((_) async => invitationPreview());
      when(() => groups.acceptInvitationLink(token))
          .thenAnswer((_) async => Joined(groupDetailOf()));
      final GoRouter router = await pump(tester, '/groups/join#token=$token');
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('4 members'), findsOneWidget);
      expect(find.text('Ben Shah (@ben)'), findsOneWidget);
      expect(find.textContaining('You’ll join right away'), findsOneWidget);
      await tapText(tester, 'Join group');
      verify(() => groups.acceptInvitationLink(token)).called(1);
      expect(locationOf(router), '/groups/grp-home');
    });

    testWidgets('a group that needs approval leaves a pending request', (
      WidgetTester tester,
    ) async {
      when(() => groups.previewInvitation(token))
          .thenAnswer((_) async => invitationPreview(requiresApproval: true));
      when(() => groups.acceptInvitationLink(token))
          .thenAnswer((_) async => JoinPending(joinRequest()));
      await pump(tester, '/groups/join#token=$token');
      expect(
        find.textContaining('An admin approves new members'),
        findsOneWidget,
      );
      await tapText(tester, 'Ask to join');
      expect(find.text('Request sent'), findsOneWidget);
      expect(
        find.textContaining('The admins of Goa trip will review your request'),
        findsOneWidget,
      );
    });

    testWidgets('a pasted link is checked; a gone link is explained', (
      WidgetTester tester,
    ) async {
      when(() => groups.previewInvitation(token))
          .thenThrow(serverError(ErrorObjectCode.gone, status: 410));
      await pump(tester, '/groups/join');
      await tester.enterText(find.byType(TextFormField), 'not a link');
      await tapText(tester, 'Check the link');
      expect(
        find.text('This doesn’t look like a Montra invitation link.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextFormField),
        'https://app.example/groups/join#token=$token',
      );
      await tapText(tester, 'Check the link');
      verify(() => groups.previewInvitation(token)).called(1);
      expect(find.textContaining('This link can’t be used'), findsOneWidget);
    });

    testWidgets('already a member and a used link', (
      WidgetTester tester,
    ) async {
      when(() => groups.previewInvitation(token))
          .thenAnswer((_) async => invitationPreview(alreadyMember: true));
      await pump(tester, '/groups/join#token=$token');
      expect(
        find.text('You are already a member of this group.'),
        findsOneWidget,
      );
      expect(find.text('Open the group'), findsOneWidget);
    });
  });

  group('overview', () {
    testWidgets('balances, money screens, members and activity in words', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pump(tester, '/groups/grp-home');
      expect(find.text('Household · 3 members'), findsOneWidget);
      expect(find.text('You are owed ₹250.00'), findsOneWidget);
      expect(find.text('owes ₹100.00'), findsOneWidget);
      expect(find.text('Asha (you)'), findsOneWidget);
      expect(find.text('Removed'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Cy Rao joined the group.'),
        200,
      );
      expect(find.text('Asha created this Household group.'), findsOneWidget);

      await tapText(tester, 'Settle up');
      expect(locationOf(router), '/groups/grp-home/balances');
    });

    testWidgets('a trip shows its details; balance errors are calm', (
      WidgetTester tester,
    ) async {
      when(() => people.group('grp-home')).thenAnswer(
        (_) async => groupDetailOf(
          type: 'trip',
          destination: 'Goa',
          startDate: '2026-12-01',
          endDate: '2026-12-05',
          description: 'Beach week',
        ),
      );
      when(() => groups.balances(any())).thenThrow(offline);
      await pump(tester, '/groups/grp-home');
      expect(find.text('Trip details'), findsOneWidget);
      expect(find.text('Goa'), findsOneWidget);
      expect(find.text('Beach week'), findsOneWidget);
      expect(
        find.text('Balances couldn’t be loaded. Pull down to try again.'),
        findsOneWidget,
      );
      // The list's my_net still shows the user's own balance.
      expect(find.text('Settled up'), findsOneWidget);
    });

    testWidgets('error with retry', (WidgetTester tester) async {
      when(() => people.group('grp-home')).thenThrow(offline);
      await pump(tester, '/groups/grp-home');
      expect(find.text("You're offline"), findsOneWidget);
    });

    testWidgets('activity loads more pages', (WidgetTester tester) async {
      when(() => groups.activity('grp-home', before: null)).thenAnswer(
        (_) async => activityPage(<GroupActivityDto>[
          activityEvent(kind: 'member_left', actor: 'u-cy', entity: 'u-cy'),
        ], nextBefore: 5),
      );
      when(() => groups.activity('grp-home', before: 5)).thenAnswer(
        (_) async => activityPage(<GroupActivityDto>[
          activityEvent(
            id: 4,
            kind: 'member_role_changed',
            actor: meId,
            entity: 'u-ben',
            summary: <String, Object?>{'role': 'admin'},
          ),
        ]),
      );
      await pump(tester, '/groups/grp-home/activity');
      expect(find.text('Cy Rao left the group.'), findsOneWidget);
      await tapText(tester, 'Load more');
      expect(find.text('Asha made Ben Shah Admin.'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('removing a member explains the open-balance policy', (
      WidgetTester tester,
    ) async {
      when(() => groups.removeMember('grp-home', 'u-cy'))
          .thenAnswer((_) async {});
      await pump(tester, '/groups/grp-home/settings');
      await tapText(tester, 'Cy Rao');
      await tapText(tester, 'Remove from group');
      expect(find.text('Remove Cy Rao from the group?'), findsOneWidget);
      expect(
        find.textContaining('that balance keeps counting in balances'),
        findsOneWidget,
      );
      expect(
        find.textContaining('an admin can confirm a payment to them'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Remove from group'));
      await tester.pumpAndSettle();
      verify(() => groups.removeMember('grp-home', 'u-cy')).called(1);
      expect(find.text('Cy Rao was removed from the group.'), findsOneWidget);
    });

    testWidgets('an invitation link is shown once with copy and share', (
      WidgetTester tester,
    ) async {
      when(() => groups.createInvitation('grp-home', any()))
          .thenAnswer((_) async => invitation(token: token));
      await pump(tester, '/groups/grp-home/settings');
      await tapText(tester, 'Create an invitation link');
      await tapText(tester, '30 days');
      await tapText(tester, 'Once');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create an invitation link'),
      );
      await tester.pumpAndSettle();
      final GroupInvitationInput input =
          verify(() => groups.createInvitation('grp-home', captureAny()))
                  .captured
                  .single
              as GroupInvitationInput;
      expect(input.toJson(), <String, Object?>{
        'kind': 'link',
        'expires_in_days': 30,
        'max_uses': 1,
      });
      expect(
        find.textContaining('This link is shown only now'),
        findsOneWidget,
      );
      expect(
        find.text('http://localhost:8080/groups/join#token=$token'),
        findsOneWidget,
      );
      await tapText(tester, 'Share');
      expect(
        shared.single,
        'Join Home on Montra: http://localhost:8080/groups/join#token=$token',
      );
      await tapText(tester, 'Done');
      expect(find.textContaining('#token='), findsNothing);
    });

    testWidgets("the server's share_url is shared when it sends one", (
      WidgetTester tester,
    ) async {
      const String shareUrl = 'https://app.example/groups/join#token=$token';
      when(
        () => groups.createInvitation('grp-home', any()),
      ).thenAnswer((_) async => invitation(token: token, shareUrl: shareUrl));
      await pump(tester, '/groups/grp-home/settings');
      await tapText(tester, 'Create an invitation link');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create an invitation link'),
      );
      await tester.pumpAndSettle();
      expect(find.text(shareUrl), findsOneWidget);
      expect(find.textContaining('localhost:8080'), findsNothing);
      await tapText(tester, 'Share');
      expect(shared.single, 'Join Home on Montra: $shareUrl');
    });

    testWidgets('admins add people from friends; join requests are approved', (
      WidgetTester tester,
    ) async {
      stubGroupReads(
        groups,
        requests: <GroupJoinRequestDto>[joinRequest(message: 'Hi all')],
        invitations: <GroupInvitationDto>[
          invitation(kind: 'username'),
          invitation(id: 'inv-2', status: 'expired', uses: 2),
        ],
      );
      when(() => people.group('grp-home'))
          .thenAnswer((_) async => groupDetailOf(requireApproval: true));
      when(() => groups.addMember('grp-home', any()))
          .thenAnswer((_) async => invitation(kind: 'username'));
      when(() => groups.approveJoinRequest('grp-home', 'jr-1'))
          .thenAnswer((_) async => groupDetailOf());
      await pump(tester, '/groups/grp-home/settings');
      expect(find.text('Invitation for Dev Iyer'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('“Hi all”'), findsOneWidget);
      await tapText(tester, 'Approve');
      verify(() => groups.approveJoinRequest('grp-home', 'jr-1')).called(1);
      expect(find.text('Dev Iyer joined the group.'), findsOneWidget);

      await tester.tap(find.byTooltip('Add a member'));
      await tester.pumpAndSettle();
      await tapText(tester, 'From your friends');
      await tapText(tester, 'Asha Rao');
      final AddMemberInput input =
          verify(() => groups.addMember('grp-home', captureAny()))
                  .captured
                  .single
              as AddMemberInput;
      expect(input.toJson(), <String, Object?>{'user_id': 'u-asha'});
    });

    testWidgets('a member leaving with an open balance is told to settle', (
      WidgetTester tester,
    ) async {
      when(() => people.group('grp-home'))
          .thenAnswer((_) async => groupDetailOf(role: 'member'));
      when(() => groups.removeMember('grp-home', meId)).thenThrow(
        serverError(
          ErrorObjectCode.domainRuleViolation,
          details: <Detail>[coded('balance_open')],
        ),
      );
      await pump(tester, '/groups/grp-home/settings');
      expect(find.text('Delete group'), findsNothing);
      expect(find.text('Create an invitation link'), findsOneWidget);
      await tapText(tester, 'Leave group');
      await tester.tap(find.widgetWithText(FilledButton, 'Leave group'));
      await tester.pumpAndSettle();
      expect(
        find.text('Settle your balance in the group before you leave.'),
        findsOneWidget,
      );
    });

    testWidgets('the owner archives; coded conflicts are localized', (
      WidgetTester tester,
    ) async {
      when(() => groups.archive('grp-home')).thenThrow(
        serverError(
          ErrorObjectCode.conflict,
          status: 409,
          details: <Detail>[coded('group_archived')],
        ),
      );
      await pump(tester, '/groups/grp-home/settings');
      expect(
        find.textContaining('make someone else the owner'),
        findsOneWidget,
      );
      await tapText(tester, 'Archive group');
      await tester.tap(find.widgetWithText(FilledButton, 'Archive group'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This group is archived. The owner can restore it to make changes.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('deleting needs settled balances', (WidgetTester tester) async {
      when(() => groups.delete('grp-home')).thenThrow(
        serverError(
          ErrorObjectCode.domainRuleViolation,
          details: <Detail>[coded('balances_open')],
        ),
      );
      await pump(tester, '/groups/grp-home/settings');
      await tapText(tester, 'Delete group');
      expect(find.text('Delete Home?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete group'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Everyone’s balances must be settled before the group can be deleted.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('notifications are each member’s own choice', (
      WidgetTester tester,
    ) async {
      when(() => groups.updateMember('grp-home', meId, any()))
          .thenAnswer((_) async => groupDetailOf());
      await pump(tester, '/groups/grp-home/settings');
      await tapText(tester, 'Only important things');
      final GroupMemberUpdate update =
          verify(() => groups.updateMember('grp-home', meId, captureAny()))
                  .captured
                  .single
              as GroupMemberUpdate;
      expect(update.toJson(), <String, Object?>{
        'notification_level': 'important',
      });
    });
  });

  group('edit details', () {
    testWidgets('sends only changes; a conflict reloads the form', (
      WidgetTester tester,
    ) async {
      int reads = 0;
      when(() => people.group('grp-home')).thenAnswer((_) async {
        reads++;
        return reads == 1
            ? groupDetailOf(description: 'Our flat')
            : groupDetailOf(name: 'Home sweet home', version: 4);
      });
      when(() => groups.update('grp-home', any()))
          .thenThrow(serverError(ErrorObjectCode.versionConflict, status: 409));
      await pump(tester, '/groups/grp-home/edit');
      await tapText(tester, 'Save');
      expect(
        find.text('Nothing changed, so there was nothing to save.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description (optional)'),
        '',
      );
      await tapText(tester, 'Save');
      final Map<String, Object?> patch =
          verify(() => groups.update('grp-home', captureAny())).captured.single
              as Map<String, Object?>;
      expect(patch, <String, Object?>{'description': '', 'version': 3});
      expect(
        find.textContaining('This was changed somewhere else'),
        findsOneWidget,
      );
      expect(find.text('Home sweet home'), findsOneWidget);
    });
  });
}
