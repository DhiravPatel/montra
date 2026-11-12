import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/social/application/social_providers.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';
import 'package:montra_mobile/features/social/domain/social_display.dart';

/// Who can find and add the user: the username, whether people can find
/// them by it (off until they turn it on) and who may send friend
/// requests. Only what changed is sent (`PATCH /me`).
class SocialSettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SocialSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<MeDto> me = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.socialSettingsTitle)),
      body: AsyncValueView<MeDto>(
        value: me,
        onRetry: () => ref.invalidate(myProfileProvider),
        data: (MeDto data) => _SettingsForm(
          key: ValueKey<DateTime>(data.profile.updatedAt),
          profile: data.profile,
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.profile, super.key});

  final ProfileDto profile;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _username = TextEditingController(
    text: widget.profile.username ?? '',
  );
  late bool _discoverable = widget.profile.discoverableByUsername;
  late ProfileDtoAllowFriendRequests _requests =
      widget.profile.allowFriendRequests;
  ServerFormErrors _errors = ServerFormErrors.none;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _pickRequests() async {
    final ProfileDtoAllowFriendRequests? picked =
        await showOptionSheet<ProfileDtoAllowFriendRequests>(
          context,
          title: context.l10n.socialRequestsLabel,
          selected: _requests,
          options: <SheetOption<ProfileDtoAllowFriendRequests>>[
            for (final ProfileDtoAllowFriendRequests v
                in <ProfileDtoAllowFriendRequests>[
                  ProfileDtoAllowFriendRequests.everyone,
                  ProfileDtoAllowFriendRequests.friendsOfFriends,
                  ProfileDtoAllowFriendRequests.nobody,
                ])
              SheetOption<ProfileDtoAllowFriendRequests>(
                value: v,
                label: friendRequestPolicyLabel(context.l10n, v),
              ),
          ],
        );
    if (picked != null && mounted) {
      setState(() => _requests = picked);
    }
  }

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final ProfileDto p = widget.profile;
    final String username = normalizeUsername(_username.text).toLowerCase();
    final bool usernameChanged = username != (p.username ?? '');
    final ProfilePatch patch = ProfilePatch(
      username: usernameChanged ? username : null,
      discoverableByUsername: _discoverable == p.discoverableByUsername
          ? null
          : _discoverable,
      allowFriendRequests: _requests == p.allowFriendRequests
          ? null
          : ProfilePatchAllowFriendRequests.fromJson(_requests.json),
    );
    if (patch.toJson().isEmpty) {
      showSnack(context, l10n.socialNothingChanged);
      return;
    }
    try {
      await ref.read(socialApiProvider).updateProfile(patch);
      ref.invalidate(myProfileProvider);
      if (mounted) {
        showSnack(context, l10n.socialSettingsSaved);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _errors =
            error.code == ErrorObjectCode.conflict &&
                error.details.every((Detail d) => d.code == null)
            // A taken username: 409 on body.username without a code.
            ? ServerFormErrors(
                fields: <String, String>{'username': l10n.usernameTaken},
              )
            : ServerFormErrors.from(
                l10n,
                error,
                fieldMap: const <String, String>{
                  'username': 'username',
                  'discoverable_by_username': 'discoverable',
                  'allow_friend_requests': 'requests',
                },
              ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? general = _errors.general;
    return Form(
      key: _form,
      child: ScrollableContent(
        children: <Widget>[
          if (general != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.error,
              message: general,
              requestId: _errors.requestId,
            ),
            const SizedBox(height: Insets.md),
          ],
          FormSectionHeader(l10n.usernameSection),
          TextFormField(
            controller: _username,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: l10n.usernameLabel,
              prefixText: '@',
              helperText: l10n.usernameRules,
              helperMaxLines: 4,
              errorText: _errors['username'],
            ),
            validator: (String? v) => usernameProblem(l10n, v ?? ''),
          ),
          FormSectionHeader(l10n.socialDiscoverySection),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.socialDiscoverableLabel),
            subtitle: Text(l10n.socialDiscoverableHelp),
            value: _discoverable,
            onChanged: (bool v) => setState(() => _discoverable = v),
          ),
          if (!_discoverable)
            NoticeBanner(message: l10n.socialDiscoverableOffNote),
          const SizedBox(height: Insets.md),
          SelectorField(
            label: l10n.socialRequestsLabel,
            value: friendRequestPolicyLabel(l10n, _requests),
            helperText: l10n.socialRequestsHelp,
            errorText: _errors['requests'],
            onTap: _pickRequests,
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(label: l10n.actionSave, onPressed: _save),
        ],
      ),
    );
  }
}
