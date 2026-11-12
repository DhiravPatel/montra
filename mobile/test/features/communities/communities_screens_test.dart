import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/invite_links.dart';
import 'package:montra_mobile/features/moderation/data/moderation_api.dart';

import '../../helpers/communities_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/moderation_fakes.dart';
import '../../helpers/router_app.dart';

const String token = 'qA4fseFCgSEWsyznVadmfMt4JrZF03An';

void main() {
  late MockCommunitiesApi api;
  late MockModerationApi moderation;
  late List<String> shared;
  String? origin;

  setUpAll(() {
    registerCommunityFallbacks();
    registerModerationFallbacks();
  });

  setUp(() {
    api = MockCommunitiesApi();
    moderation = MockModerationApi();
    shared = <String>[];
    origin = null;
  });

  List<Override> overrides() => <Override>[
    communitiesApiProvider.overrideWithValue(api),
    moderationApiProvider.overrideWithValue(moderation),
    webAppOriginProvider.overrideWithValue(origin),
    shareTextProvider.overrideWithValue(
      (String text) async => shared.add(text),
    ),
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

  group('communities list', () {
    testWidgets('discover lists communities and searches; yours and '
        'invitations tabs', (WidgetTester tester) async {
      when(
        () => api.list(
          q: any(named: 'q'),
          topic: any(named: 'topic'),
        ),
      ).thenAnswer(
        (_) async => <CommunityDto>[
          community(myStatus: 'none', myRole: 'none'),
          community(
            id: 'com-2',
            name: 'Home Cooks',
            visibility: 'private',
            myStatus: 'pending',
            myRole: 'none',
          ),
        ],
      );
      when(() => api.list(mine: true))
          .thenAnswer((_) async => <CommunityDto>[community(myRole: 'owner')]);
      when(() => api.myInvitations()).thenAnswer(
        (_) async => <CommunityInvitationDto>[
          invitation(id: 'inv-9', kind: 'username'),
        ],
      );
      when(() => api.acceptInvitation('inv-9'))
          .thenAnswer((_) async => community());
      stubCommunity(api);
      final GoRouter router = await pump(tester, '/communities');

      expect(find.text('Communities'), findsOneWidget);
      expect(find.text('Savers Circle'), findsOneWidget);
      expect(find.text('Public · 12 members'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'cook');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      verify(() => api.list(q: 'cook')).called(1);

      await tester.tap(find.text('Yours'));
      await tester.pumpAndSettle();
      expect(find.text('Owner'), findsOneWidget);

      await tester.tap(find.text('Invitations'));
      await tester.pumpAndSettle();
      expect(find.text('Invited by Asha Rao'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();
      verify(() => api.acceptInvitation('inv-9')).called(1);
      expect(router.state.uri.toString(), '/communities/com-1');
    });

    testWidgets('error with retry, then the empty states', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(
        () => api.list(
          q: any(named: 'q'),
          topic: any(named: 'topic'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <CommunityDto>[];
      });
      when(() => api.list(mine: true))
          .thenAnswer((_) async => <CommunityDto>[]);
      when(() => api.myInvitations())
          .thenAnswer((_) async => <CommunityInvitationDto>[]);
      await pump(tester, '/communities');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No communities to show yet'), findsOneWidget);
      await tester.tap(find.text('Yours'));
      await tester.pumpAndSettle();
      expect(find.text("You haven't joined a community yet"), findsOneWidget);
      await tester.tap(find.text('Invitations'));
      await tester.pumpAndSettle();
      expect(find.text('No invitations'), findsOneWidget);
    });

    testWidgets('declining an invitation asks first; a used invitation is '
        'explained', (WidgetTester tester) async {
      when(
        () => api.list(
          q: any(named: 'q'),
          topic: any(named: 'topic'),
        ),
      ).thenAnswer((_) async => <CommunityDto>[]);
      when(() => api.myInvitations()).thenAnswer(
        (_) async => <CommunityInvitationDto>[
          invitation(id: 'inv-9', kind: 'username'),
        ],
      );
      when(() => api.declineInvitation('inv-9')).thenThrow(
        serverError(
          ErrorObjectCode.conflict,
          status: 409,
          details: const <Detail>[
            Detail(code: 'invitation_used', message: 'already'),
          ],
        ),
      );
      await pump(tester, '/communities?tab=invitations');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Decline this invitation?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Decline'));
      await tester.pumpAndSettle();
      expect(
        find.text('This invitation was already answered.'),
        findsOneWidget,
      );
    });
  });

  group('create', () {
    testWidgets('sends the community and explains a taken URL name', (
      WidgetTester tester,
    ) async {
      final List<CommunityInput> sent = <CommunityInput>[];
      when(() => api.create(any())).thenAnswer((Invocation i) async {
        sent.add(i.positionalArguments.first as CommunityInput);
        throw serverError(
          ErrorObjectCode.conflict,
          status: 409,
          details: const <Detail>[
            Detail(field: 'body.slug', code: 'slug_taken', message: 'taken'),
          ],
        );
      });
      await pump(tester, '/communities/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Savers Circle',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'URL name (optional)'),
        'Savers-Circle',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Topics (optional)'),
        'saving, budgeting',
      );
      await scrollTo(tester, find.text('Private'));
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.widgetWithText(FilledButton, 'Start a community'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Start a community'));
      await tester.pumpAndSettle();
      expect(sent.single.toJson(), <String, Object?>{
        'name': 'Savers Circle',
        'slug': 'savers-circle',
        'topics': <String>['saving', 'budgeting'],
        'visibility': 'private',
      });
      await scrollTo(
        tester,
        find.text('That URL name is taken. Choose another.'),
      );
      expect(
        find.text('That URL name is taken. Choose another.'),
        findsOneWidget,
      );
    });
  });

  group('join by link', () {
    testWidgets('previews the link from the fragment and joins', (
      WidgetTester tester,
    ) async {
      when(() => api.previewInvitation(token))
          .thenAnswer((_) async => preview());
      when(() => api.acceptInvitationLink(token))
          .thenAnswer((_) async => community());
      stubCommunity(api);
      final GoRouter router = await pump(
        tester,
        '/communities/join#token=$token',
      );
      expect(find.text('Savers Circle'), findsOneWidget);
      expect(find.text('Invited by Asha Rao'), findsOneWidget);
      expect(
        find.text('This invitation lets you join directly.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();
      verify(() => api.acceptInvitationLink(token)).called(1);
      expect(router.state.uri.toString(), '/communities/com-1');
      expect(router.state.uri.toString(), isNot(contains(token)));
    });

    testWidgets('a dead link (410) is explained; a pasted link is checked', (
      WidgetTester tester,
    ) async {
      when(() => api.previewInvitation(token))
          .thenThrow(serverError(ErrorObjectCode.gone, status: 410));
      await pump(tester, '/communities/join');
      await tester.enterText(find.byType(TextField), 'not a link');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Check the invitation'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text("This isn't a community invitation link or code."),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextField),
        'https://app.example/communities/join#token=$token',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Check the invitation'),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This invitation no longer works'),
        findsOneWidget,
      );
    });

    testWidgets('already a member (409) opens the community', (
      WidgetTester tester,
    ) async {
      when(() => api.previewInvitation(token))
          .thenAnswer((_) async => preview());
      when(() => api.acceptInvitationLink(token)).thenThrow(
        serverError(
          ErrorObjectCode.conflict,
          status: 409,
          details: const <Detail>[Detail(code: 'already_member', message: 'x')],
        ),
      );
      stubCommunity(api);
      final GoRouter router = await pump(
        tester,
        '/communities/join#token=$token',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/communities/com-1');
    });
  });

  group('community page', () {
    testWidgets('a public community offers Join; the feed sorts and loads '
        'more', (WidgetTester tester) async {
      stubCommunity(
        api,
        value: community(myStatus: 'none', myRole: 'none'),
      );
      when(
        () => api.posts(
          'com-1',
          sort: 'new',
          q: any(named: 'q'),
          cursor: null,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async =>
            postsPage(<CommunityPostDto>[post(pinned: true)], next: 'c2'),
      );
      when(
        () => api.posts(
          'com-1',
          sort: 'new',
          q: any(named: 'q'),
          cursor: 'c2',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => postsPage(<CommunityPostDto>[
          post(id: 'post-2', title: 'Second page post'),
        ]),
      );
      when(() => api.join('com-1')).thenAnswer((_) async => community());
      await pump(tester, '/communities/com-1');
      expect(find.text('Savers Circle'), findsWidgets);
      expect(find.text('Community rules'), findsOneWidget);
      expect(find.text('How do you save on groceries?'), findsOneWidget);
      expect(find.text('Pinned'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();
      verify(() => api.join('com-1')).called(1);
      expect(find.text('You joined Savers Circle.'), findsOneWidget);
      await scrollTo(tester, find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Second page post'), findsOneWidget);
      await scrollTo(tester, find.widgetWithText(ChoiceChip, 'Top'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Top'));
      await tester.pumpAndSettle();
      verify(
        () => api.posts(
          'com-1',
          sort: 'top',
          q: any(named: 'q'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).called(1);
    });

    testWidgets('a private community hides the feed from non-members and a '
        'pending request is explained', (WidgetTester tester) async {
      stubCommunity(
        api,
        value: community(
          visibility: 'private',
          myStatus: 'pending',
          myRole: 'none',
        ),
      );
      await pump(tester, '/communities/com-1');
      expect(
        find.text('Your request to join is waiting for a moderator.'),
        findsOneWidget,
      );
      expect(
        find.text('Only members see the posts in this community.'),
        findsOneWidget,
      );
      verifyNever(
        () => api.posts(
          any(),
          sort: any(named: 'sort'),
          q: any(named: 'q'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      );
    });

    testWidgets('an empty feed and a failed community load', (
      WidgetTester tester,
    ) async {
      stubCommunity(api, posts: <CommunityPostDto>[]);
      await pump(tester, '/communities/com-1');
      expect(find.text('No posts yet'), findsOneWidget);
      expect(find.text('New post'), findsOneWidget);

      when(() => api.get('com-x'))
          .thenThrow(serverError(ErrorObjectCode.notFound, status: 404));
      await pump(tester, '/communities/com-x');
      expect(
        find.text("We couldn't find that. It may have been removed."),
        findsOneWidget,
      );
    });
  });

  group('composer', () {
    testWidgets('a poll sends its question and options; resource links must '
        'be https', (WidgetTester tester) async {
      stubCommunity(api);
      final List<CommunityPostInput> sent = <CommunityPostInput>[];
      when(() => api.createPost('com-1', any()))
          .thenAnswer((Invocation i) async {
            sent.add(i.positionalArguments[1] as CommunityPostInput);
            return post(id: 'post-new');
          });
      when(() => api.post('post-new')).thenAnswer((_) async => postDetail());
      final GoRouter router = await pump(
        tester,
        '/communities/com-1/posts/new',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Resource link'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Useful',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Link'),
        'http://insecure.example.com',
      );
      await scrollTo(tester, find.widgetWithText(FilledButton, 'Publish'));
      await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Links must start with https://.'));
      expect(find.text('Links must start with https://.'), findsOneWidget);
      expect(sent, isEmpty);

      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Poll'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Poll'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Which app do you use?',
      );
      await scrollTo(tester, find.widgetWithText(TextFormField, 'Question'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question'),
        'Pick one',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Option 1'),
        'Notes',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Option 2'),
        'Spreadsheet',
      );
      await scrollTo(tester, find.widgetWithText(FilledButton, 'Publish'));
      await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
      await tester.pumpAndSettle();
      expect(sent.single.toJson(), <String, Object?>{
        'kind': 'poll',
        'label': 'personal_experience',
        'poll': <String, Object?>{
          'options': <String>['Notes', 'Spreadsheet'],
          'question': 'Pick one',
        },
        'title': 'Which app do you use?',
      });
      expect(router.state.uri.toString(), '/posts/post-new');
    });

    testWidgets('a daily cap is explained with the wait', (
      WidgetTester tester,
    ) async {
      stubCommunity(api);
      when(() => api.createPost('com-1', any())).thenThrow(
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.rateLimited,
          statusCode: 429,
          retryAfter: Duration(minutes: 30),
          details: <Detail>[
            Detail(
              code: 'daily_cap',
              message: 'cap',
              params: <String, String>{'limit': '20', 'resource': 'posts'},
            ),
          ],
        ),
      );
      await pump(tester, '/communities/com-1/posts/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Another post',
      );
      await scrollTo(tester, find.widgetWithText(FilledButton, 'Publish'));
      await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining("You've reached today's limit (20 a day)"),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          "You've reached today's limit (20 a day). Try again in 30 minutes.",
        ),
        findsOneWidget,
      );
    });
  });

  group('post page', () {
    testWidgets('threads comments, replies with the parent, shows reactions '
        'from the answer and votes', (WidgetTester tester) async {
      stubCommunity(api);
      when(() => api.post('post-1')).thenAnswer(
        (_) async => postDetail(
          overrides: <String, Object?>{
            'kind': 'poll',
            'poll': pollJson(),
            'body': 'Plain <b>text</b> only',
          },
          comments: <Map<String, Object?>>[
            commentJson(
              id: 'c2',
              parent: 'c1',
              body: 'Thanks!',
              name: 'Ravi',
              createdAt: '2026-11-04T10:05:00Z',
            ),
            commentJson(id: 'c1', body: 'Buy in bulk.'),
            commentJson(id: 'c3', status: 'removed', body: ''),
          ],
        ),
      );
      final List<CommunityCommentInput> comments = <CommunityCommentInput>[];
      when(() => api.comment('post-1', any())).thenAnswer((Invocation i) async {
        comments.add(i.positionalArguments[1] as CommunityCommentInput);
        return CommunityCommentDto.fromJson(commentJson(id: 'c9'));
      });
      when(() => api.reactToPost('post-1', CommunityReactionInputKind.helpful))
          .thenAnswer((_) async => reactionsAnswer(helpful: 7));
      when(() => api.vote('post-1', <String>['opt-notes'])).thenAnswer(
        (_) async => CommunityPollDto.fromJson(
          pollJson(myVotes: <String>['opt-notes'], notes: 4),
        ),
      );
      await pump(tester, '/posts/post-1');
      expect(find.text('Plain <b>text</b> only'), findsOneWidget);
      // Reactions: the count shown is the server's answer, not local math.
      await tester.tap(find.widgetWithText(FilterChip, 'Helpful 1').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Helpful 7'), findsOneWidget);
      // Poll vote replaces the earlier one and shows the new totals.
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Vote'));
      await tester.pumpAndSettle();
      expect(find.text('Notes (your vote)'), findsOneWidget);
      expect(find.text('4 votes · 80 %'), findsOneWidget);
      // Threaded: the reply comes after its parent and is indented.
      await scrollTo(tester, find.text('Thanks!'));
      final double parentX = tester.getTopLeft(find.text('Buy in bulk.')).dx;
      final double replyX = tester.getTopLeft(find.text('Thanks!')).dx;
      expect(replyX, greaterThan(parentX));
      expect(
        tester.getTopLeft(find.text('Thanks!')).dy,
        greaterThan(tester.getTopLeft(find.text('Buy in bulk.')).dy),
      );
      expect(
        find.text('This comment was removed by a moderator.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Reply').first);
      await tester.pumpAndSettle();
      expect(find.text('Replying to Meera Shah'), findsOneWidget);
      await scrollTo(tester, find.widgetWithText(TextField, 'Your reply'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Your reply'),
        'Agreed',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pumpAndSettle();
      expect(comments.single.toJson(), <String, Object?>{
        'body': 'Agreed',
        'parent_comment_id': 'c1',
      });
    });

    testWidgets('the author deletes their post after confirming; others can '
        'report it', (WidgetTester tester) async {
      stubCommunity(api);
      when(() => api.post('post-1')).thenAnswer(
        (_) async => postDetail(overrides: <String, Object?>{'mine': true}),
      );
      when(() => api.deletePost('post-1')).thenAnswer((_) async {});
      await pump(tester, '/communities/com-1');
      await tester.tap(find.text('How do you save on groceries?'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this post?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      verify(() => api.deletePost('post-1')).called(1);
      expect(find.text('Post deleted.'), findsOneWidget);
    });

    testWidgets('reporting a post sends the reason', (
      WidgetTester tester,
    ) async {
      stubCommunity(api);
      when(() => api.post('post-1')).thenAnswer((_) async => postDetail());
      final List<PostReportInput> reports = <PostReportInput>[];
      when(() => api.reportPost('post-1', any()))
          .thenAnswer((Invocation i) async {
            reports.add(i.positionalArguments[1] as PostReportInput);
            return report(targetType: 'post');
          });
      await pump(tester, '/posts/post-1');
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scam or fraud'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Send report'));
      await tester.pumpAndSettle();
      expect(reports.single.reason, PostReportInputReason.scam);
      expect(
        find.text('Thank you. Moderators will review your report.'),
        findsOneWidget,
      );
    });
  });

  group('settings', () {
    testWidgets('saves only what changed with the version; a conflict '
        'reloads', (WidgetTester tester) async {
      int gets = 0;
      when(() => api.get('com-1')).thenAnswer((_) async {
        gets++;
        return community(
          myRole: 'owner',
          canModerate: true,
          version: gets == 1 ? 3 : 4,
        );
      });
      when(
        () => api.invitations(
          'com-1',
          includeInactive: any(named: 'includeInactive'),
        ),
      ).thenAnswer((_) async => <CommunityInvitationDto>[invitation()]);
      final List<Map<String, Object?>> patches = <Map<String, Object?>>[];
      when(() => api.update('com-1', any())).thenAnswer((Invocation i) async {
        patches.add(i.positionalArguments[1] as Map<String, Object?>);
        if (patches.length == 1) {
          throw serverError(ErrorObjectCode.versionConflict, status: 409);
        }
        return community(myRole: 'owner', canModerate: true, version: 5);
      });
      await pump(tester, '/communities/com-1/settings');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Community rules (optional)'),
        '',
      );
      await scrollTo(tester, find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(patches.first, <String, Object?>{'rules': '', 'version': 3});
      await tester.scrollUntilVisible(
        find.textContaining('This was changed somewhere else'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('This was changed somewhere else'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Community rules (optional)'),
        '',
      );
      await scrollTo(tester, find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(patches.last, <String, Object?>{'rules': '', 'version': 4});
    });

    testWidgets('a new link is shown once as a code without a web address, '
        'or as a link, with share', (WidgetTester tester) async {
      when(() => api.get('com-1')).thenAnswer(
        (_) async => community(myRole: 'moderator', canModerate: true),
      );
      when(
        () => api.invitations(
          'com-1',
          includeInactive: any(named: 'includeInactive'),
        ),
      ).thenAnswer((_) async => <CommunityInvitationDto>[]);
      when(() => api.createInvitation('com-1', any()))
          .thenAnswer((_) async => invitation(token: token));
      origin = 'https://app.example';
      await pump(tester, '/communities/com-1/settings');
      await scrollTo(tester, find.text('Create an invitation link'));
      await tester.tap(find.text('Create an invitation link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      verify(
        () => api.createInvitation(
          'com-1',
          const CommunityInvitationInput(expiresInDays: 7),
        ),
      ).called(1);
      expect(
        find.text('https://app.example/communities/join#token=$token'),
        findsOneWidget,
      );
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(
        shared.single,
        'https://app.example/communities/join#token=$token',
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // Moderators can't change who can join.
      await tester.scrollUntilVisible(
        find.text('Only the owner can change who can join.'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Only the owner can change who can join.'),
        findsOneWidget,
      );
    });
  });

  group('members and moderation', () {
    testWidgets('moderators approve requests', (WidgetTester tester) async {
      when(
        () => api.get('com-1'),
      ).thenAnswer((_) async => community(myRole: 'owner', canModerate: true));
      when(() => api.members('com-1', status: 'active')).thenAnswer(
        (_) async => <CommunityMemberDto>[
          member(id: meId, name: 'Asha', role: 'owner'),
          member(),
        ],
      );
      when(() => api.members('com-1', status: 'pending')).thenAnswer(
        (_) async => <CommunityMemberDto>[
          member(id: 'u-new', name: 'Neha', status: 'pending'),
        ],
      );
      when(() => api.approveMember('com-1', 'u-new')).thenAnswer((_) async {});
      await pump(tester, '/communities/com-1/members');
      expect(find.text('Asha (you)'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Waiting for approval'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();
      verify(() => api.approveMember('com-1', 'u-new')).called(1);
      expect(find.text('Neha is now a member.'), findsOneWidget);
    });

    testWidgets('the report queue acts on reported content with a reason', (
      WidgetTester tester,
    ) async {
      when(() => api.get('com-1')).thenAnswer(
        (_) async => community(myRole: 'moderator', canModerate: true),
      );
      when(() => api.moderationReports('com-1', status: 'open'))
          .thenAnswer((_) async => <ModerationReportDto>[report()]);
      final List<ModerationActionInput> acts = <ModerationActionInput>[];
      when(() => api.moderate('com-1', any())).thenAnswer((Invocation i) async {
        acts.add(i.positionalArguments[1] as ModerationActionInput);
        return modAction();
      });
      await pump(tester, '/communities/com-1/moderation');
      expect(find.text('Comment · Harassment'), findsOneWidget);
      expect(find.text('Reported text: You are <b>wrong</b>'), findsOneWidget);
      expect(find.text('2 open reports on this'), findsOneWidget);
      await tester.tap(find.text('Act on the content'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      final Finder confirm = find.widgetWithText(FilledButton, 'Hide');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Unkind');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(acts.single.toJson(), <String, Object?>{
        'action': 'hide',
        'reason': 'Unkind',
        'report_id': 'rep-1',
        'target_id': 'cmt-2',
        'target_type': 'comment',
      });
    });

    testWidgets('non-moderators see no moderation tools', (
      WidgetTester tester,
    ) async {
      when(() => api.get('com-1')).thenAnswer((_) async => community());
      await pump(tester, '/communities/com-1/moderation');
      expect(find.text("You don't have access"), findsOneWidget);
    });
  });
}
