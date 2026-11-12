import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/social/application/social_providers.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';
import 'package:montra_mobile/features/social/domain/social_display.dart';
import 'package:montra_mobile/features/social/presentation/person_widgets.dart';

/// The tabs of the friends screen, in order.
enum FriendsTab {
  /// The user's friends.
  friends,

  /// Requests received and sent.
  requests,

  /// Find someone by their exact username.
  find;

  /// The tab named by a `?tab=` value (notifications open `requests`).
  static FriendsTab parse(String? value) => FriendsTab.values.firstWhere(
    (FriendsTab t) => t.name == value,
    orElse: () => FriendsTab.friends,
  );
}

/// Friends: the people the user is connected with, friend requests, and
/// finding someone by their exact username. Blocked and muted people and
/// the privacy settings are one tap away.
class FriendsScreen extends ConsumerWidget {
  /// Creates the screen opened on [initialTab].
  const FriendsScreen({this.initialTab = FriendsTab.friends, super.key});

  /// The tab shown first.
  final FriendsTab initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? me = ref.watch(currentUserIdProvider);
    final int incoming = incomingRequests(
      ref.watch(friendRequestsProvider).value ?? const <FriendRequestDto>[],
      me,
    ).length;
    return DefaultTabController(
      length: FriendsTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.friendsTitle),
          actions: <Widget>[
            IconButton(
              tooltip: l10n.friendsBlockedAndMutedTitle,
              icon: const Icon(Icons.block),
              onPressed: () => context.push(AppRoutes.blockedAndMuted),
            ),
            IconButton(
              tooltip: l10n.socialSettingsTitle,
              icon: const Icon(Icons.manage_accounts_outlined),
              onPressed: () => context.push(AppRoutes.socialSettings),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: l10n.friendsTabFriends),
              Tab(
                text: incoming > 0
                    ? l10n.friendsTabRequestsCount(incoming)
                    : l10n.friendsTabRequests,
              ),
              Tab(text: l10n.friendsTabFind),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[_FriendsTab(), _RequestsTab(), _FindTab()],
        ),
      ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return AsyncValueView<List<PublicProfile>>(
      value: ref.watch(connectionsProvider),
      onRetry: () => ref.invalidate(connectionsProvider),
      isEmpty: (List<PublicProfile> list) => list.isEmpty,
      empty: MessageStateView(
        icon: Icons.people_outline,
        title: l10n.friendsEmptyTitle,
        body: l10n.friendsEmptyBody,
        action: OutlinedButton.icon(
          onPressed: () =>
              DefaultTabController.of(context).animateTo(FriendsTab.find.index),
          icon: const Icon(Icons.person_search_outlined),
          label: Text(l10n.friendsTabFind),
        ),
      ),
      data: (List<PublicProfile> friends) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(connectionsProvider);
          try {
            await ref.read(connectionsProvider.future);
          } on Object {
            // Shown by the list state.
          }
        },
        child: ListView(
          children: <Widget>[
            for (final PublicProfile p in friends)
              PersonTile(
                person: PersonView.ofProfile(p),
                onTap: () =>
                    showPersonActions(context, ref, PersonView.ofProfile(p)),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? me = ref.watch(currentUserIdProvider);
    return AsyncValueView<List<FriendRequestDto>>(
      value: ref.watch(friendRequestsProvider),
      onRetry: () => ref.invalidate(friendRequestsProvider),
      isEmpty: (List<FriendRequestDto> all) =>
          incomingRequests(all, me).isEmpty &&
          outgoingRequests(all, me).isEmpty,
      empty: MessageStateView(
        icon: Icons.mark_email_read_outlined,
        title: l10n.friendRequestsEmptyTitle,
        body: l10n.friendRequestsEmptyBody,
      ),
      data: (List<FriendRequestDto> all) {
        final List<FriendRequestDto> incoming = incomingRequests(all, me);
        final List<FriendRequestDto> outgoing = outgoingRequests(all, me);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(friendRequestsProvider);
            try {
              await ref.read(friendRequestsProvider.future);
            } on Object {
              // Shown by the list state.
            }
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: Insets.lg),
            children: <Widget>[
              if (incoming.isNotEmpty) ...<Widget>[
                _Heading(l10n.friendRequestsIncoming),
                for (final FriendRequestDto r in incoming)
                  _RequestTile(request: r, incoming: true),
              ],
              if (outgoing.isNotEmpty) ...<Widget>[
                _Heading(l10n.friendRequestsOutgoing),
                for (final FriendRequestDto r in outgoing)
                  _RequestTile(request: r, incoming: false),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.md, 0),
    child: SectionHeading(text),
  );
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.request, required this.incoming});

  final FriendRequestDto request;
  final bool incoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final PersonView person = PersonView.ofProfile(
      incoming ? request.from : request.to,
    );
    final String? message = request.message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PersonTile(
          person: person,
          subtitle: message == null || message.isEmpty
              ? null
              : l10n.friendRequestMessage(message),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            0,
            Insets.md,
            Insets.sm,
          ),
          child: Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            alignment: WrapAlignment.end,
            children: <Widget>[
              if (incoming) ...<Widget>[
                OutlinedButton(
                  onPressed: () => runSocialAction(
                    context,
                    ref,
                    action: (SocialApi api) async {
                      await api.declineFriendRequest(request.id);
                      return l10n.friendRequestDeclinedDone;
                    },
                  ),
                  child: Text(l10n.friendRequestDecline),
                ),
                FilledButton(
                  onPressed: () => runSocialAction(
                    context,
                    ref,
                    action: (SocialApi api) async {
                      await api.acceptFriendRequest(request.id);
                      return l10n.friendNowFriends(person.displayName);
                    },
                  ),
                  child: Text(l10n.friendRequestAccept),
                ),
              ] else
                OutlinedButton(
                  onPressed: () => runSocialAction(
                    context,
                    ref,
                    action: (SocialApi api) async {
                      await api.cancelFriendRequest(request.id);
                      return l10n.friendRequestCancelledDone;
                    },
                  ),
                  child: Text(l10n.friendRequestCancel),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FindTab extends ConsumerStatefulWidget {
  const _FindTab();

  @override
  ConsumerState<_FindTab> createState() => _FindTabState();
}

class _FindTabState extends ConsumerState<_FindTab> {
  final TextEditingController _query = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  /// The last search: null before searching, otherwise its result.
  List<PublicProfile>? _results;
  String? _searched;
  Object? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final String username = normalizeUsername(_query.text);
    setState(() => _error = null);
    try {
      final List<PublicProfile> found = await ref
          .read(socialApiProvider)
          .searchUsername(username);
      if (mounted) {
        setState(() {
          _results = found;
          _searched = username;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _results = null;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<PublicProfile>? results = _results;
    final Object? error = _error;
    return Form(
      key: _form,
      child: ScrollableContent(
        children: <Widget>[
          Text(l10n.friendFindIntro),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _query,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            maxLength: SendInput.usernameMaxLength,
            decoration: InputDecoration(
              labelText: l10n.friendFindLabel,
              prefixText: '@',
              helperText: l10n.friendFindHelp,
            ),
            validator: (String? v) => normalizeUsername(v ?? '').length < 3
                ? l10n.friendFindTooShort
                : null,
            onFieldSubmitted: (_) => _search(),
          ),
          const SizedBox(height: Insets.sm),
          SubmitButton(
            label: l10n.friendFindButton,
            icon: Icons.search,
            onPressed: _search,
          ),
          const SizedBox(height: Insets.md),
          if (error != null)
            NoticeBanner(
              tone: NoticeTone.error,
              message: describeError(l10n, error),
              requestId: requestIdOf(error),
            )
          else if (results != null && results.isEmpty)
            NoticeBanner(message: l10n.friendFindNobody(_searched ?? ''))
          else if (results != null)
            for (final PublicProfile p in results)
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PersonTile(
                      person: PersonView.ofProfile(p),
                      subtitle: connectionLabel(l10n, p.connection),
                      onTap: () => showPersonActions(
                        context,
                        ref,
                        PersonView.ofProfile(p),
                      ),
                    ),
                    if (p.connection == PublicProfileConnection.none ||
                        p.connection == PublicProfileConnection.requestReceived)
                      Padding(
                        padding: const EdgeInsets.all(Insets.sm),
                        child: SubmitButton(
                          label:
                              p.connection ==
                                  PublicProfileConnection.requestReceived
                              ? l10n.friendRequestAcceptTheirs
                              : l10n.friendRequestSend,
                          icon: Icons.person_add_alt_1_outlined,
                          onPressed: () async {
                            final bool ok = await sendFriendRequest(
                              context,
                              ref,
                              PersonView.ofProfile(p),
                            );
                            if (ok && mounted) {
                              await _search();
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
          const SizedBox(height: Insets.md),
          NoticeBanner(
            message: l10n.friendFindDiscoveryNote,
            action: TextButton(
              onPressed: () => context.push(AppRoutes.socialSettings),
              child: Text(l10n.socialSettingsTitle),
            ),
          ),
        ],
      ),
    );
  }
}
