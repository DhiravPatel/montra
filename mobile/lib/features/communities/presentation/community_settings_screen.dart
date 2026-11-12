import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/communities/domain/invite_links.dart';
import 'package:montra_mobile/features/communities/presentation/community_form_screen.dart';

/// Settings of a community, for its owner and moderators: details (only
/// what changed is sent, with the community's `version`), invitations
/// (links shown once, invitations by username, revoking), members and
/// approvals, ownership, archiving and restoring.
class CommunitySettingsScreen extends ConsumerWidget {
  /// Creates the screen for [communityRef].
  const CommunitySettingsScreen({required this.communityRef, super.key});

  /// The community's ID or URL name.
  final String communityRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CommunityDto> community = ref.watch(
      communityProvider(communityRef),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.communitySettingsTitle)),
      body: AsyncValueView<CommunityDto>(
        value: community,
        onRetry: () => ref.invalidate(communityProvider(communityRef)),
        data: (CommunityDto c) => c.canModerate
            ? _SettingsBody(community: c)
            : MessageStateView(
                icon: Icons.lock_outline,
                title: l10n.errorPermissionTitle,
                body: l10n.communitySettingsModeratorsOnly,
              ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.community});

  final CommunityDto community;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final CommunityDto c = community;
    final bool owner = c.myRole == CommunityDtoMyRole.owner;
    return ScrollableContent(
      children: <Widget>[
        if (c.status == CommunityDtoStatus.suspended) ...<Widget>[
          NoticeBanner(
            tone: NoticeTone.warning,
            message: l10n.communityErrorSuspended,
          ),
          const SizedBox(height: Insets.md),
        ],
        _DetailsForm(original: c),
        const Divider(height: Insets.xl),
        _InvitationsSection(community: c),
        const Divider(height: Insets.xl),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.people_outline),
          title: Text(l10n.communityMembersTitle),
          subtitle: Text(l10n.communityMembersSettingsHelp),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.communityMembers(c.id)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.shield_outlined),
          title: Text(l10n.communityModerationTitle),
          subtitle: Text(l10n.communityModerationSettingsHelp),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.communityModeration(c.id)),
        ),
        if (owner) ...<Widget>[
          const Divider(height: Insets.xl),
          _OwnerSection(community: c),
        ],
      ],
    );
  }
}

class _DetailsForm extends ConsumerStatefulWidget {
  const _DetailsForm({required this.original});

  final CommunityDto original;

  @override
  ConsumerState<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends ConsumerState<_DetailsForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _description = TextEditingController();
  late final TextEditingController _rules = TextEditingController();
  late final TextEditingController _topics = TextEditingController();
  late String _visibility;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;
  String? _message;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'description': 'description',
    'rules': 'rules',
    'topics': 'topics',
    'visibility': 'visibility',
  };

  @override
  void initState() {
    super.initState();
    _load(widget.original);
  }

  @override
  void didUpdateWidget(covariant _DetailsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.original.version != oldWidget.original.version) {
      // A newer version arrived (after a save or a conflict): show it.
      _load(widget.original);
    }
  }

  void _load(CommunityDto c) {
    _name.text = c.name;
    _description.text = c.description ?? '';
    _rules.text = c.rules ?? '';
    _topics.text = c.topics.join(', ');
    _visibility = c.visibility.json;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rules.dispose();
    _topics.dispose();
    super.dispose();
  }

  Map<String, Object?> _json(
    String name,
    String description,
    String rules,
    List<String> topics,
    String visibility,
  ) => <String, Object?>{
    'name': name,
    if (description.isNotEmpty) 'description': description,
    if (rules.isNotEmpty) 'rules': rules,
    'topics': topics,
    'visibility': visibility,
  };

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
      _message = null;
    });
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final CommunityDto o = widget.original;
    final bool owner = o.myRole == CommunityDtoMyRole.owner;
    final Map<String, Object?> patch = partialPatch(
      before: _json(
        o.name,
        o.description ?? '',
        o.rules ?? '',
        o.topics,
        o.visibility.json,
      ),
      after: <String, Object?>{
        ..._json(
          _name.text.trim(),
          _description.text.trim(),
          _rules.text.trim(),
          parseTopics(_topics.text),
          owner ? _visibility : o.visibility.json,
        ),
        'version': o.version,
      },
      textFields: const <String>{'description', 'rules'},
    );
    if (!patchHasChanges(patch)) {
      setState(() => _message = l10n.communityNothingChanged);
      return;
    }
    try {
      await ref.read(communitiesApiProvider).update(o.id, patch);
      ref.read(communityRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.communitySaved);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict) {
        ref.invalidate(communityProvider(o.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool owner = widget.original.myRole == CommunityDtoMyRole.owner;
    final String? general = _errors.general;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeading(l10n.communityDetailsTitle),
          const SizedBox(height: Insets.sm),
          if (_conflictReloaded) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.warning,
              message: l10n.versionConflictReloaded,
            ),
            const SizedBox(height: Insets.md),
          ],
          if (_message case final String m) ...<Widget>[
            NoticeBanner(message: m),
            const SizedBox(height: Insets.md),
          ],
          if (general != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.error,
              message: general,
              requestId: _errors.requestId,
            ),
            const SizedBox(height: Insets.md),
          ],
          TextFormField(
            controller: _name,
            maxLength: CommunityInput.nameMaxLength,
            decoration: InputDecoration(
              labelText: l10n.communityNameLabel,
              errorText: _errors['name'],
            ),
            validator: (String? v) =>
                (v ?? '').trim().length < CommunityInput.nameMinLength
                ? l10n.fieldTooShort('${CommunityInput.nameMinLength}')
                : null,
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _description,
            maxLength: CommunityInput.descriptionMaxLength,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l10n.communityDescriptionLabel,
              errorText: _errors['description'],
            ),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _rules,
            maxLength: CommunityInput.rulesMaxLength,
            minLines: 2,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: l10n.communityRulesLabel,
              errorText: _errors['rules'],
            ),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _topics,
            decoration: InputDecoration(
              labelText: l10n.communityTopicsLabel,
              helperText: l10n.communityTopicsHelp,
              helperMaxLines: 2,
              errorText: _errors['topics'],
            ),
          ),
          const SizedBox(height: Insets.md),
          VisibilityChooser(
            value: _visibility,
            enabled: owner,
            errorText: _errors['visibility'],
            onChanged: (String v) => setState(() => _visibility = v),
          ),
          if (!owner)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Text(l10n.communityVisibilityOwnerOnly),
            ),
          const SizedBox(height: Insets.md),
          SubmitButton(label: l10n.actionSave, onPressed: _save),
        ],
      ),
    );
  }
}

class _InvitationsSection extends ConsumerStatefulWidget {
  const _InvitationsSection({required this.community});

  final CommunityDto community;

  @override
  ConsumerState<_InvitationsSection> createState() =>
      _InvitationsSectionState();
}

class _InvitationsSectionState extends ConsumerState<_InvitationsSection> {
  bool _includeInactive = false;
  final TextEditingController _username = TextEditingController();
  String? _usernameError;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  InvitationsQuery get _query =>
      (communityId: widget.community.id, includeInactive: _includeInactive);

  Future<void> _createLink() async {
    final AppLocalizations l10n = context.l10n;
    final int? days = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: Text(l10n.communityInviteLinkExpiresTitle),
        children: <Widget>[
          for (final int d in const <int>[1, 3, 7, 14, 30])
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(d),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l10n.communityInviteLinkDays(d)),
                ),
              ),
            ),
        ],
      ),
    );
    if (days == null || !mounted) {
      return;
    }
    try {
      final CommunityInvitationDto invitation = await ref
          .read(communitiesApiProvider)
          .createInvitation(
            widget.community.id,
            CommunityInvitationInput(expiresInDays: days),
          );
      ref.read(communityRevisionProvider.notifier).bump();
      final String? token = invitation.token;
      if (!mounted || token == null) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => InviteLinkDialog(
          token: token,
          expiresAt: invitation.expiresAt,
          shareUrl: invitation.shareUrl,
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  Future<void> _inviteUsername() async {
    final AppLocalizations l10n = context.l10n;
    final String username = _username.text.trim().replaceFirst(
      RegExp('^@'),
      '',
    );
    if (username.length < 3) {
      setState(() => _usernameError = l10n.fieldTooShort('3'));
      return;
    }
    setState(() => _usernameError = null);
    try {
      await ref
          .read(communitiesApiProvider)
          .createInvitation(
            widget.community.id,
            CommunityInvitationInput(username: username),
          );
      ref.read(communityRevisionProvider.notifier).bump();
      if (mounted) {
        _username.clear();
        showSnack(context, l10n.communityInviteSent(username));
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _usernameError = error.code == ErrorObjectCode.notFound
            ? l10n.communityInviteUserNotFound
            : describeError(l10n, error),
      );
    }
  }

  Future<void> _revoke(CommunityInvitationDto invitation) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.communityInviteRevokeTitle,
      body: l10n.communityInviteRevokeBody,
      confirmLabel: l10n.communityInviteRevoke,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref
          .read(communitiesApiProvider)
          .revokeInvitation(widget.community.id, invitation.id);
      ref.read(communityRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.communityInviteRevoked);
      }
    } on ApiException catch (error) {
      ref.invalidate(communityInvitationsProvider(_query));
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<List<CommunityInvitationDto>> list = ref.watch(
      communityInvitationsProvider(_query),
    );
    final bool active = widget.community.status == CommunityDtoStatus.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeading(l10n.communityInvitationsTitle),
        const SizedBox(height: Insets.xs),
        Text(l10n.communityInvitationsHelp),
        const SizedBox(height: Insets.sm),
        if (active) ...<Widget>[
          OutlinedButton.icon(
            onPressed: _createLink,
            icon: const Icon(Icons.link),
            label: Text(l10n.communityInviteCreateLink),
          ),
          const SizedBox(height: Insets.sm),
          TextField(
            controller: _username,
            autocorrect: false,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _inviteUsername(),
            decoration: InputDecoration(
              labelText: l10n.communityInviteUsernameLabel,
              helperText: l10n.communityInviteUsernameHelp,
              helperMaxLines: 2,
              errorText: _usernameError,
              errorMaxLines: 3,
              prefixText: '@',
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _inviteUsername,
              child: Text(l10n.communityInviteSend),
            ),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _includeInactive,
          onChanged: (bool v) => setState(() => _includeInactive = v),
          title: Text(l10n.communityInvitationsShowInactive),
        ),
        AsyncValueView<List<CommunityInvitationDto>>(
          value: list,
          onRetry: () => ref.invalidate(communityInvitationsProvider(_query)),
          isEmpty: (List<CommunityInvitationDto> data) => data.isEmpty,
          empty: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            child: Text(l10n.communityInvitationsNone),
          ),
          data: (List<CommunityInvitationDto> data) => Column(
            children: <Widget>[
              for (final CommunityInvitationDto inv in data)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    inv.kind == CommunityInvitationDtoKind.link
                        ? Icons.link
                        : Icons.person_outline,
                  ),
                  title: Text(
                    inv.kind == CommunityInvitationDtoKind.link
                        ? l10n.communityInviteKindLink
                        : l10n.communityInviteKindPerson(
                            inv.invitee?.displayName ?? l10n.communityUnnamed,
                          ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.communityInvitationExpires(
                          formatShortDate(inv.expiresAt, locale: locale),
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      StatusLabel(
                        text: invitationStatusLabel(l10n, inv.status.json),
                        tone: inv.status == CommunityInvitationDtoStatus.active
                            ? StatusTone.positive
                            : StatusTone.neutral,
                      ),
                    ],
                  ),
                  trailing: inv.status == CommunityInvitationDtoStatus.active
                      ? IconButton(
                          tooltip: l10n.communityInviteRevoke,
                          icon: const Icon(Icons.block),
                          onPressed: () => _revoke(inv),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows a new invitation once: the shareable link (or, without a
/// configured web address, the invitation code), with Copy and Share. The
/// token is not kept anywhere after the dialog closes.
class InviteLinkDialog extends ConsumerWidget {
  /// Creates the dialog.
  const InviteLinkDialog({
    required this.token,
    required this.expiresAt,
    this.shareUrl,
    super.key,
  });

  /// The invitation token.
  final String token;

  /// When the link stops working.
  final DateTime expiresAt;

  /// The server's join link (`share_url`), preferred when it is a valid
  /// `/communities/join` link.
  final String? shareUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String? link =
        communityShareUrl(shareUrl) ??
        communityJoinLink(ref.watch(webAppOriginProvider), token);
    final String shown = link ?? token;
    return AlertDialog(
      title: Text(l10n.communityInviteLinkTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              link == null
                  ? l10n.communityInviteCodeIntro
                  : l10n.communityInviteLinkIntro,
            ),
            const SizedBox(height: Insets.sm),
            SelectableText(shown),
            const SizedBox(height: Insets.sm),
            Text(
              l10n.communityInvitationExpires(
                formatShortDate(expiresAt, locale: locale),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: shown));
            if (context.mounted) {
              showSnack(context, l10n.copiedToClipboard);
            }
          },
          child: Text(l10n.actionCopy),
        ),
        TextButton(
          onPressed: () => ref.read(shareTextProvider)(
            link == null ? l10n.communityInviteShareCode(shown) : shown,
          ),
          child: Text(l10n.communityInviteShare),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionDone),
        ),
      ],
    );
  }
}

class _OwnerSection extends ConsumerWidget {
  const _OwnerSection({required this.community});

  final CommunityDto community;

  Future<void> _transfer(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final String? me = ref.read(currentUserIdProvider);
    List<CommunityMemberDto> members;
    try {
      members = await ref
          .read(communitiesApiProvider)
          .members(community.id, status: 'active');
    } on ApiException catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final List<CommunityMemberDto> others = members
        .where((CommunityMemberDto m) => m.userId != me)
        .toList();
    if (others.isEmpty) {
      showSnack(context, l10n.communityTransferNobody);
      return;
    }
    final CommunityMemberDto? to = await showDialog<CommunityMemberDto>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: Text(l10n.communityTransferChoose),
        children: <Widget>[
          for (final CommunityMemberDto m in others)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(m),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${m.displayName} · ${communityRoleLabel(l10n, m.role.json)}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (to == null || !context.mounted) {
      return;
    }
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.communityTransferTitle(to.displayName),
      body: l10n.communityTransferBody(to.displayName),
      confirmLabel: l10n.communityTransfer,
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(communitiesApiProvider)
          .transferOwnership(community.id, to.userId);
      ref.read(communityRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, l10n.communityTransferredDone(to.displayName));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  Future<void> _archiveOrRestore(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool archived = community.status == CommunityDtoStatus.archived;
    final bool confirmed = await showConfirmDialog(
      context,
      title: archived ? l10n.communityRestoreTitle : l10n.communityArchiveTitle,
      body: archived ? l10n.communityRestoreBody : l10n.communityArchiveBody,
      confirmLabel: archived ? l10n.actionRestore : l10n.communityArchive,
      destructive: !archived,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      final CommunitiesApi api = ref.read(communitiesApiProvider);
      if (archived) {
        await api.restore(community.id);
      } else {
        await api.archive(community.id);
      }
      ref.read(communityRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(
          context,
          archived ? l10n.communityRestoredDone : l10n.communityArchivedDone,
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool suspended = community.status == CommunityDtoStatus.suspended;
    final bool archived = community.status == CommunityDtoStatus.archived;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeading(l10n.communityOwnerSectionTitle),
        const SizedBox(height: Insets.sm),
        SubmitButton(
          kind: SubmitButtonKind.outlined,
          icon: Icons.swap_horiz,
          label: l10n.communityTransfer,
          onPressed: () => _transfer(context, ref),
        ),
        const SizedBox(height: Insets.sm),
        if (!suspended)
          SubmitButton(
            kind: archived
                ? SubmitButtonKind.outlined
                : SubmitButtonKind.destructive,
            icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: archived ? l10n.actionRestore : l10n.communityArchive,
            onPressed: () => _archiveOrRestore(context, ref),
          ),
        const SizedBox(height: Insets.xs),
        Text(archived ? l10n.communityRestoreHelp : l10n.communityArchiveHelp),
      ],
    );
  }
}
