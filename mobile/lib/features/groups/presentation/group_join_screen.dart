import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/groups/application/groups_providers.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart';
import 'package:montra_mobile/features/social/domain/social_display.dart';

/// Joins a group with an invitation link (`/groups/join#token=…`, opened
/// from a link or pasted). The link is previewed first
/// (`POST /group-invitations/preview`): the group, who invited and whether
/// the admins approve new members. Accepting joins directly (`200`) or
/// leaves a join request for the admins (`202`). The token is sent in
/// request bodies only, is never stored or logged, and leaves the
/// navigation stack when the screen is replaced by the group.
class GroupJoinScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [initialToken] comes from the link's fragment.
  const GroupJoinScreen({this.initialToken, super.key});

  /// Token read from the opened link, if any.
  final String? initialToken;

  @override
  ConsumerState<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends ConsumerState<GroupJoinScreen> {
  final TextEditingController _link = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  String? _token;
  GroupInvitationPreview? _preview;
  GroupJoinRequestDto? _pending;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final String? token = widget.initialToken;
    if (token != null) {
      _token = token;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
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
      _link.text = text;
      await _usePasted();
    }
  }

  Future<void> _usePasted() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    _token = InviteLinks.tokenFrom(_link.text);
    await _loadPreview();
  }

  Future<void> _loadPreview() async {
    final String? token = _token;
    if (token == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final GroupInvitationPreview preview = await ref
          .read(groupsApiProvider)
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
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _accept() async {
    final AppLocalizations l10n = context.l10n;
    final String? token = _token;
    if (token == null) {
      return;
    }
    setState(() => _error = null);
    try {
      final JoinOutcome outcome = await ref
          .read(groupsApiProvider)
          .acceptInvitationLink(token);
      refreshGroupLists(ref);
      if (!mounted) {
        return;
      }
      switch (outcome) {
        case Joined(:final GroupDetail group):
          showSnack(context, l10n.groupJoinedDone(group.name));
          // Replacing this screen drops the link (and its token) from the
          // navigation stack.
          context.pushReplacement(AppRoutes.groupDetail(group.id));
        case JoinPending(:final GroupJoinRequestDto request):
          _token = null;
          setState(() => _pending = request);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  String _errorText(AppLocalizations l10n, Object error) =>
      error is ApiException && error.code == ErrorObjectCode.gone
      ? l10n.groupJoinLinkGone
      : describeError(l10n, error);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final GroupInvitationPreview? preview = _preview;
    final GroupJoinRequestDto? pending = _pending;
    final Object? error = _error;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupJoinTitle)),
      body: ScrollableContent(
        children: <Widget>[
          if (pending != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.success,
              title: l10n.groupJoinPendingTitle,
              message: l10n.groupJoinPendingBody(
                preview?.groupName ?? l10n.groupsTitle,
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: l10n.groupJoinBackToGroups,
              onPressed: () async => context.go(AppRoutes.groups),
            ),
          ] else ...<Widget>[
            if (preview == null && !_loading)
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(l10n.groupJoinIntro),
                    const SizedBox(height: Insets.md),
                    TextFormField(
                      controller: _link,
                      autocorrect: false,
                      enableSuggestions: false,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.groupJoinLinkLabel,
                        suffixIcon: IconButton(
                          tooltip: l10n.pasteFromClipboard,
                          icon: const Icon(Icons.content_paste),
                          onPressed: _paste,
                        ),
                      ),
                      validator: (String? v) =>
                          InviteLinks.tokenFrom(v ?? '') == null
                          ? l10n.groupJoinLinkInvalid
                          : null,
                      onFieldSubmitted: (_) => _usePasted(),
                    ),
                    const SizedBox(height: Insets.md),
                    SubmitButton(
                      label: l10n.groupJoinCheckLink,
                      onPressed: _usePasted,
                    ),
                  ],
                ),
              ),
            if (_loading)
              Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Center(
                  child: Semantics(
                    label: l10n.loadingLabel,
                    child: const CircularProgressIndicator(),
                  ),
                ),
              ),
            if (error != null) ...<Widget>[
              const SizedBox(height: Insets.md),
              NoticeBanner(
                tone: NoticeTone.error,
                message: _errorText(l10n, error),
                requestId: requestIdOf(error),
              ),
            ],
            if (preview != null) _PreviewCard(preview: preview),
            if (preview != null) ...<Widget>[
              const SizedBox(height: Insets.lg),
              if (preview.alreadyMember)
                SubmitButton(
                  label: l10n.groupOpen,
                  onPressed: () async => context.pushReplacement(
                    AppRoutes.groupDetail(preview.groupId),
                  ),
                )
              else if (preview.status == GroupInvitationPreviewStatus.active)
                SubmitButton(
                  label: preview.requiresApproval
                      ? l10n.groupJoinAskToJoin
                      : l10n.groupJoinButton,
                  onPressed: _accept,
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final GroupInvitationPreview preview;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final InviterName? inviter = preview.invitedBy;
    final bool active = preview.status == GroupInvitationPreviewStatus.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: preview.groupName,
          children: <Widget>[
            DetailRow(
              label: l10n.groupTypeLabel,
              value: groupTypeLabel(l10n, preview.groupType.json),
            ),
            DetailRow(
              label: l10n.groupMembersLabel,
              value: l10n.groupMemberCount(preview.memberCount),
            ),
            if (inviter != null)
              DetailRow(
                label: l10n.groupInvitedByLabel,
                value: inviter.username == null
                    ? inviter.displayName
                    : '${inviter.displayName} (@${inviter.username})',
              ),
            DetailRow(
              label: l10n.groupInvitationExpiresLabel,
              value: formatDateTime(preview.expiresAt, locale: locale),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        if (preview.alreadyMember)
          NoticeBanner(message: l10n.groupJoinAlreadyMember)
        else if (!active)
          NoticeBanner(
            tone: NoticeTone.warning,
            message: l10n.groupJoinLinkNotActive(
              invitationStatusWord(l10n, preview.status.json),
            ),
          )
        else if (preview.requiresApproval)
          NoticeBanner(message: l10n.groupJoinNeedsApproval)
        else
          NoticeBanner(message: l10n.groupJoinDirect),
      ],
    );
  }
}
