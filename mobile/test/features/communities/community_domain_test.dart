import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/communities/domain/invite_links.dart';

import '../../helpers/communities_fakes.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations hi;

  setUpAll(() async {
    await initializeDateFormatting();
    en = await AppLocalizations.delegate.load(const Locale('en'));
    hi = await AppLocalizations.delegate.load(const Locale('hi'));
  });

  test('comments are threaded depth-first, oldest first; orphans and cycles '
      'still show', () {
    final List<CommunityCommentDto> comments = <CommunityCommentDto>[
      for (final Map<String, Object?> j in <Map<String, Object?>>[
        commentJson(id: 'c3', parent: 'c1', createdAt: '2026-11-04T10:03:00Z'),
        commentJson(id: 'c1', createdAt: '2026-11-04T10:01:00Z'),
        commentJson(id: 'c2', createdAt: '2026-11-04T10:02:00Z'),
        commentJson(id: 'c4', parent: 'c3', createdAt: '2026-11-04T10:04:00Z'),
        commentJson(
          id: 'c5',
          parent: 'gone',
          createdAt: '2026-11-04T10:00:00Z',
        ),
        commentJson(id: 'c6', parent: 'c6', createdAt: '2026-11-04T10:05:00Z'),
      ])
        CommunityCommentDto.fromJson(j),
    ];
    final List<({CommunityCommentDto comment, int depth})> t = threadComments(
      comments,
    );
    expect(
      <String>[
        for (final ({CommunityCommentDto comment, int depth}) e in t)
          '${e.comment.id}:${e.depth}',
      ],
      <String>['c5:0', 'c1:0', 'c3:1', 'c4:2', 'c2:0', 'c6:0'],
    );
  });

  test('invitation tokens come from join links (fragment or query) or bare '
      'codes, nothing else', () {
    const String token = 'qA4fseFCgSEWsyznVadmfMt4JrZF03An';
    expect(
      inviteTokenFrom('https://app.example/communities/join#token=$token'),
      token,
    );
    expect(
      inviteTokenFrom('  http://localhost:5173/communities/join?token=$token '),
      token,
    );
    expect(
      inviteTokenFrom('https://app.example/communities/join#to\nken=$token'),
      token,
    );
    expect(inviteTokenFrom(token), token);
    expect(
      inviteTokenFrom('https://app.example/groups/join#token=$token'),
      isNull,
    );
    expect(inviteTokenFrom('short'), isNull);
    expect(inviteTokenFrom(''), isNull);
    expect(
      inviteTokenOfUri(Uri.parse('/communities/join#token=$token')),
      token,
    );
  });

  test('share links use the web origin when configured, the token in the '
      'fragment', () {
    expect(
      webOriginFrom('https://app.example.com/'),
      'https://app.example.com',
    );
    expect(webOriginFrom('ftp://x'), isNull);
    expect(webOriginFrom(''), isNull);
    expect(
      communityJoinLink('https://app.example.com', 'tok'),
      'https://app.example.com/communities/join#token=tok',
    );
    expect(communityJoinLink(null, 'tok'), isNull);
  });

  test('only http(s) links with a host are opened', () {
    expect(safeLink('https://www.rbi.org.in/'), isNotNull);
    expect(safeLink('http://example.com'), isNotNull);
    expect(safeLink('javascript:alert(1)'), isNull);
    expect(safeLink('file:///etc/passwd'), isNull);
    expect(safeLink('intent://x'), isNull);
    expect(safeLink('mailto:a@b.c'), isNull);
    expect(safeLink('https://bank.example@evil.example/'), isNull);
    expect(safeLink('https://user:pass@example.com/'), isNull);
    expect(safeLink(null), isNull);
  });

  test('topics are trimmed, de-duplicated and kept in order', () {
    expect(parseTopics(' saving, Budgeting ,, saving ,budgeting'), <String>[
      'saving',
      'Budgeting',
    ]);
  });

  test('coded community, challenge and moderation answers are localized '
      'in English and Hindi; unknown codes keep the server message', () {
    for (final AppLocalizations l10n in <AppLocalizations>[en, hi]) {
      for (final String code in <String>[
        'account_restricted',
        'comment_locked',
        'comments_closed',
        'invitation_only',
        'new_account_links',
        'not_accepting_posts',
        'own_content',
        'poll_closed',
        'post_locked',
        'posting_restricted',
        'already_member',
        'invitation_used',
        'invitation_inactive',
        'leaderboard_opt_in_required',
        'no_leaderboard',
        'join_challenge_first',
        'challenge_not_open',
        'appeal_needs_other_moderator',
        'appeal_window_passed',
        'not_appealable',
        'slug_taken',
        'insecure_link',
        'duplicate_option',
        'contains_secret',
      ]) {
        final String text = detailMessage(
          l10n,
          Detail(code: code, message: 'English fallback'),
        );
        expect(text, isNot('English fallback'), reason: code);
      }
      expect(
        detailMessage(l10n, const Detail(code: 'brand_new', message: 'Hi')),
        'Hi',
      );
    }
    expect(
      detailMessage(
        en,
        const Detail(
          code: 'posting_restricted',
          message: 'x',
          params: <String, String>{'until': '2026-11-13T06:04:47Z'},
        ),
      ),
      allOf(
        startsWith('A moderator paused your posting here until '),
        contains('2026'),
      ),
    );
    const ApiException gone = ApiException(
      kind: ApiErrorKind.server,
      code: ErrorObjectCode.domainRuleViolation,
      details: <Detail>[
        Detail(code: 'leaderboard_opt_in_required', message: 'x'),
      ],
    );
    expect(describeError(en, gone), en.challengeErrorLeaderboardOptIn);
  });
}
