import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/communities/domain/invite_links.dart';

/// Joining a community with an invitation link
/// (`/communities/join#token=…`), or with a link or code pasted by the
/// user. The link is previewed first (`POST /community-invitations/preview`)
/// so the user sees which community it is for, then accepted. The token is
/// only sent in request bodies, kept in memory, and the join location is
/// replaced by the community page once used.
class CommunityJoinScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [initialToken] comes from an opened link.
  const CommunityJoinScreen({this.initialToken, super.key});

  /// Token from the link's fragment.
  final String? initialToken;

  @override
  ConsumerState<CommunityJoinScreen> createState() =>
      _CommunityJoinScreenState();
}

class _CommunityJoinScreenState extends ConsumerState<CommunityJoinScreen> {
  final TextEditingController _link = TextEditingController();
  String? _token;
  CommunityInvitationPreview? _preview;
  Object? _error;
  String? _fieldError;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final String? token = widget.initialToken;
    if (token != null && isInviteToken(token)) {
      _token = token;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check(token));
    }
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text != null && mounted) {
      _link.text = text.trim();
      await _checkPasted();
    }
  }

  Future<void> _checkPasted() async {
    final AppLocalizations l10n = context.l10n;
    final String? token = inviteTokenFrom(_link.text);
    if (token == null) {
      setState(() => _fieldError = l10n.communityJoinLinkInvalid);
      return;
    }
    setState(() {
      _fieldError = null;
      _token = token;
    });
    await _check(token);
  }

  Future<void> _check(String token) async {
    setState(() {
      _checking = true;
      _error = null;
      _preview = null;
    });
    try {
      final CommunityInvitationPreview preview = await ref
          .read(communitiesApiProvider)
          .previewInvitation(token);
      if (mounted) {
        setState(() => _preview = preview);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _join() async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    final String? token = _token;
    final CommunityInvitationPreview? preview = _preview;
    if (token == null || preview == null) {
      return;
    }
    try {
      final CommunityDto community = await ref
          .read(communitiesApiProvider)
          .acceptInvitationLink(token);
      ref.read(communityRevisionProvider.notifier).bump();
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.communityJoinedDone(community.name));
      // Replacing the location drops the token from the navigation stack.
      unawaited(router.pushReplacement(AppRoutes.communityPage(community.id)));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final bool member =
          error.code == ErrorObjectCode.conflict &&
          error.details.any((Detail d) => d.code == 'already_member');
      if (member) {
        unawaited(
          router.pushReplacement(AppRoutes.communityPage(preview.communityId)),
        );
        showSnack(context, l10n.communityErrorAlreadyMember);
        return;
      }
      setState(() => _error = error);
    }
  }

  void _open(String communityId) =>
      GoRouter.of(context)
          .pushReplacement(AppRoutes.communityPage(communityId));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CommunityInvitationPreview? preview = _preview;
    final Object? error = _error;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityJoinTitle)),
      body: ScrollableContent(
        children: <Widget>[
          if (_token == null || (preview == null && !_checking)) ...<Widget>[
            Text(l10n.communityJoinIntro),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              onSubmitted: (_) => _checkPasted(),
              decoration: InputDecoration(
                labelText: l10n.communityJoinLinkLabel,
                errorText: _fieldError,
                suffixIcon: IconButton(
                  tooltip: l10n.pasteFromClipboard,
                  icon: const Icon(Icons.content_paste),
                  onPressed: _paste,
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            SubmitButton(
              label: l10n.communityJoinCheck,
              onPressed: _checkPasted,
            ),
            const SizedBox(height: Insets.md),
          ],
          if (_checking) const LoadingStateView(),
          if (error != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.error,
              title: l10n.communityJoinFailedTitle,
              message: _isGone(error)
                  ? l10n.communityJoinLinkGone
                  : describeError(l10n, error),
              requestId: requestIdOf(error),
            ),
            const SizedBox(height: Insets.md),
          ],
          if (preview != null)
            _PreviewCard(
              preview: preview,
              onJoin: _join,
              onOpen: () => _open(preview.communityId),
            ),
        ],
      ),
    );
  }

  static bool _isGone(Object error) =>
      error is ApiException && error.code == ErrorObjectCode.gone;
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.preview,
    required this.onJoin,
    required this.onOpen,
  });

  final CommunityInvitationPreview preview;
  final Future<void> Function() onJoin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final bool active =
        preview.status == CommunityInvitationPreviewStatus.active;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                preview.communityName,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(l10n.communityMemberCount(preview.memberCount)),
            if (preview.invitedBy case final CommunityPersonDto by)
              Text(l10n.communityInvitedBy(by.displayName)),
            Text(
              l10n.communityInvitationExpires(
                formatShortDate(preview.expiresAt, locale: locale),
              ),
            ),
            const SizedBox(height: Insets.md),
            if (preview.alreadyMember) ...<Widget>[
              NoticeBanner(message: l10n.communityErrorAlreadyMember),
              const SizedBox(height: Insets.md),
              SubmitButton(
                label: l10n.communityOpen,
                onPressed: () async => onOpen(),
              ),
            ] else if (!active)
              NoticeBanner(
                tone: NoticeTone.warning,
                message: l10n.communityJoinLinkNotActive(
                  invitationStatusLabel(l10n, preview.status.json),
                ),
              )
            else ...<Widget>[
              Text(l10n.communityJoinDirectly),
              const SizedBox(height: Insets.md),
              SubmitButton(label: l10n.communityJoin, onPressed: onJoin),
            ],
          ],
        ),
      ),
    );
  }
}
