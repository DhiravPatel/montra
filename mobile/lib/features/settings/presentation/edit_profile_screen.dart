import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_widgets.dart';
import 'package:montra_mobile/core/formatting/file_size.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/receipts/application/receipts_providers.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';
import 'package:montra_mobile/features/social/application/social_providers.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';
import 'package:montra_mobile/features/social/domain/social_display.dart';

/// Most interests a profile can list (`ProfilePatch.interests` maxItems).
const int maxInterests = 10;

/// Longest interest the server keeps, in UTF-8 bytes (longer ones are
/// dropped by `backend/internal/users/users.go`).
const int maxInterestBytes = 40;

/// Edit profile (`PATCH /me`): photo, display name, username, bio,
/// location, interests and who can see the profile. Only changed fields
/// are sent; an emptied optional field is sent as `""` (or `[]`), which
/// clears it. The photo is uploaded with purpose `avatar` and then set with
/// `avatar_file_id` (`""` removes it; the file itself is kept).
class EditProfileScreen extends ConsumerWidget {
  /// Creates the screen.
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<MeDto> me = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileEditTitle)),
      body: AsyncValueView<MeDto>(
        value: me,
        onRetry: () => ref.invalidate(myProfileProvider),
        data: (MeDto data) => _ProfileForm(
          key: ValueKey<DateTime>(data.profile.updatedAt),
          profile: data.profile,
        ),
      ),
    );
  }
}

/// The request JSON of a profile form's values (for [partialPatch]).
Map<String, Object?> profileFormJson({
  required String displayName,
  required String username,
  required String bio,
  required String location,
  required List<String> interests,
  required ProfileDtoProfileVisibility visibility,
}) {
  String? text(String v) => v.trim().isEmpty ? null : v.trim();
  return ProfilePatch(
    displayName: text(displayName),
    username: text(normalizeUsername(username).toLowerCase()),
    bio: text(bio),
    coarseLocation: text(location),
    interests: interests.isEmpty ? null : interests,
    profileVisibility: visibility == ProfileDtoProfileVisibility.unrecognized
        ? null
        : ProfilePatchProfileVisibility.fromJson(visibility.json),
  ).toJson();
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile, super.key});

  final ProfileDto profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.displayName,
  );
  late final TextEditingController _username = TextEditingController(
    text: widget.profile.username ?? '',
  );
  late final TextEditingController _bio = TextEditingController(
    text: widget.profile.bio ?? '',
  );
  late final TextEditingController _location = TextEditingController(
    text: widget.profile.coarseLocation ?? '',
  );
  final TextEditingController _interest = TextEditingController();
  late List<String> _interests = List<String>.of(widget.profile.interests);
  late ProfileDtoProfileVisibility _visibility =
      widget.profile.profileVisibility;

  /// The photo shown; changing it does not reset the rest of the form.
  late String? _avatarId = widget.profile.avatarFileId;
  String? _interestError;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'display_name': 'name',
    'username': 'username',
    'bio': 'bio',
    'coarse_location': 'location',
    'interests': 'interests',
    'profile_visibility': 'visibility',
    'avatar_file_id': 'avatar',
  };

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _location.dispose();
    _interest.dispose();
    super.dispose();
  }

  Map<String, Object?> _json({
    required String name,
    required String username,
    required String bio,
    required String location,
    required List<String> interests,
    required ProfileDtoProfileVisibility visibility,
  }) => profileFormJson(
    displayName: name,
    username: username,
    bio: bio,
    location: location,
    interests: interests,
    visibility: visibility,
  );

  Map<String, Object?> get _patch {
    final ProfileDto p = widget.profile;
    return partialPatch(
      before: _json(
        name: p.displayName,
        username: p.username ?? '',
        bio: p.bio ?? '',
        location: p.coarseLocation ?? '',
        interests: p.interests,
        visibility: p.profileVisibility,
      ),
      after: _json(
        name: _name.text,
        username: _username.text,
        bio: _bio.text,
        location: _location.text,
        interests: _interests,
        visibility: _visibility,
      ),
      textFields: const <String>{'username', 'bio', 'coarse_location'},
      always: const <String>{},
    );
  }

  void _addInterest() {
    final AppLocalizations l10n = context.l10n;
    final String value = _interest.text.trim();
    if (value.isEmpty) {
      return;
    }
    String? problem;
    if (_interests.length >= maxInterests) {
      problem = l10n.profileEditInterestsFull(maxInterests);
    } else if (utf8.encode(value).length > maxInterestBytes) {
      problem = l10n.profileEditInterestTooLong;
    } else if (_interests.any(
      (String i) => i.toLowerCase() == value.toLowerCase(),
    )) {
      problem = l10n.profileEditInterestDuplicate;
    }
    setState(() {
      _interestError = problem;
      if (problem == null) {
        _interests = <String>[..._interests, value];
        _interest.clear();
      }
    });
  }

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final Map<String, Object?> body = _patch;
    if (!patchHasChanges(body, always: const <String>{})) {
      showSnack(context, l10n.socialNothingChanged);
      return;
    }
    try {
      final ProfileDto saved = await ref
          .read(socialApiProvider)
          .updateProfile(ProfilePatch.fromJson(body));
      _mirrorInAccount(saved);
      ref.invalidate(myProfileProvider);
      if (mounted) {
        showSnack(context, l10n.profileEditSaved);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
        );
      }
    }
  }

  /// The signed-in summary shows the name, username and photo too.
  void _mirrorInAccount(ProfileDto saved) {
    ref
        .read(authControllerProvider.notifier)
        .updateUser(
          (UserDto u) => UserDto.fromJson(<String, Object?>{
            ...u.toJson(),
            'display_name': saved.displayName,
            'username': saved.username,
            'avatar_file_id': saved.avatarFileId,
          }),
        );
  }

  Future<void> _setAvatar(String fileId) async {
    final AppLocalizations l10n = context.l10n;
    try {
      final ProfileDto saved = await ref
          .read(socialApiProvider)
          .updateProfile(ProfilePatch(avatarFileId: fileId));
      _mirrorInAccount(saved);
      if (mounted) {
        setState(() {
          _avatarId = saved.avatarFileId;
          _errors = ServerFormErrors.none;
        });
        showSnack(
          context,
          fileId.isEmpty
              ? l10n.profileEditPhotoRemoved
              : l10n.profileEditPhotoSaved,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
        );
      }
    }
  }

  Future<void> _pickAvatar() async {
    final PickedFile? picked = await pickFileFor(
      context,
      ref,
      purpose: UploadPurpose.avatar,
    );
    if (picked == null || !mounted) {
      return;
    }
    final FileDto? file = await uploadWithProgress(
      context,
      file: picked,
      purpose: UploadPurpose.avatar,
    );
    if (file == null || !mounted) {
      return;
    }
    await _setAvatar(file.id);
  }

  Future<void> _removeAvatar() async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.profileEditPhotoRemoveTitle,
      body: l10n.profileEditPhotoRemoveBody,
      confirmLabel: l10n.profileEditPhotoRemove,
    );
    if (confirmed && mounted) {
      await _setAvatar('');
    }
  }

  Future<void> _pickVisibility() async {
    final AppLocalizations l10n = context.l10n;
    final ProfileDtoProfileVisibility? picked =
        await showOptionSheet<ProfileDtoProfileVisibility>(
          context,
          title: l10n.profileEditVisibility,
          selected: _visibility,
          options: <SheetOption<ProfileDtoProfileVisibility>>[
            for (final ProfileDtoProfileVisibility v
                in <ProfileDtoProfileVisibility>[
                  ProfileDtoProfileVisibility.private,
                  ProfileDtoProfileVisibility.connections,
                  ProfileDtoProfileVisibility.public,
                ])
              SheetOption<ProfileDtoProfileVisibility>(
                value: v,
                label: visibilityLabel(l10n, v),
                subtitle: visibilityHelp(l10n, v),
              ),
          ],
        );
    if (picked != null && mounted) {
      setState(() => _visibility = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? general = _errors.general;
    final String? avatarId = _avatarId;
    final bool hasAvatar = avatarId != null && avatarId.isNotEmpty;
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
          FormSectionHeader(l10n.profileEditPhotoSection),
          Row(
            children: <Widget>[
              ProfileAvatar(
                fileId: hasAvatar ? avatarId : null,
                name: widget.profile.displayName,
                radius: 40,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  hasAvatar
                      ? l10n.profileEditPhotoHelp(
                          formatFileSize(l10n, UploadPurpose.avatar.maxBytes),
                        )
                      : l10n.profileEditPhotoNone,
                ),
              ),
            ],
          ),
          if (_errors['avatar'] case final String message) ...<Widget>[
            const SizedBox(height: Insets.sm),
            NoticeBanner(tone: NoticeTone.error, message: message),
          ],
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _pickAvatar,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  hasAvatar
                      ? l10n.profileEditPhotoChange
                      : l10n.profileEditPhotoChoose,
                ),
              ),
              if (hasAvatar)
                TextButton.icon(
                  onPressed: _removeAvatar,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.profileEditPhotoRemove),
                ),
            ],
          ),
          FormSectionHeader(l10n.profileEditDetailsSection),
          TextFormField(
            controller: _name,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.profileEditDisplayName,
              helperText: l10n.profileEditDisplayNameHelp,
              errorText: _errors['name'],
            ),
            validator: (String? v) =>
                (v ?? '').trim().isEmpty ? l10n.fieldRequired : null,
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _username,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: l10n.optionalLabel(l10n.usernameLabel),
              prefixText: '@',
              helperText: l10n.profileEditUsernameHelp,
              errorText: _errors['username'],
            ),
            validator: (String? v) => usernameProblem(l10n, v ?? ''),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _bio,
            maxLength: 280,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.optionalLabel(l10n.profileEditBio),
              helperText: l10n.profileEditBioHelp,
              errorText: _errors['bio'],
            ),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _location,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.optionalLabel(l10n.profileEditLocation),
              helperText: l10n.profileEditLocationHelp,
              errorText: _errors['location'],
            ),
          ),
          FormSectionHeader(l10n.profileEditInterests),
          Text(
            l10n.profileEditInterestsHelp(maxInterests),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.sm),
          if (_interests.isEmpty)
            Text(l10n.profileEditInterestsNone)
          else
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String interest in _interests)
                  InputChip(
                    label: Text(interest),
                    deleteButtonTooltipMessage: l10n.profileEditInterestRemove(
                      interest,
                    ),
                    onDeleted: () => setState(
                      () => _interests = <String>[
                        for (final String i in _interests)
                          if (i != interest) i,
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: Insets.sm),
          TextField(
            controller: _interest,
            enabled: _interests.length < maxInterests,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addInterest(),
            decoration: InputDecoration(
              labelText: l10n.profileEditInterestNew,
              errorText: _interestError ?? _errors['interests'],
              helperText: _interests.length >= maxInterests
                  ? l10n.profileEditInterestsFull(maxInterests)
                  : null,
              suffixIcon: IconButton(
                tooltip: l10n.profileEditInterestAdd,
                icon: const Icon(Icons.add),
                onPressed: _interests.length < maxInterests
                    ? _addInterest
                    : null,
              ),
            ),
          ),
          FormSectionHeader(l10n.profileEditVisibility),
          SelectorField(
            label: l10n.profileEditVisibility,
            value: visibilityLabel(l10n, _visibility),
            helperText: visibilityHelp(l10n, _visibility),
            errorText: _errors['visibility'],
            onTap: _pickVisibility,
          ),
          const SizedBox(height: Insets.md),
          NoticeBanner(message: l10n.profileEditFinanceNote),
          const SizedBox(height: Insets.lg),
          SubmitButton(label: l10n.actionSave, onPressed: _save),
        ],
      ),
    );
  }
}

/// Who can see a profile, in words.
String visibilityLabel(AppLocalizations l10n, ProfileDtoProfileVisibility v) =>
    switch (v) {
      ProfileDtoProfileVisibility.private ||
      ProfileDtoProfileVisibility.unrecognized =>
        l10n.profileEditVisibilityPrivate,
      ProfileDtoProfileVisibility.connections =>
        l10n.profileEditVisibilityConnections,
      ProfileDtoProfileVisibility.public => l10n.profileEditVisibilityPublic,
    };

/// What a visibility choice means.
String visibilityHelp(AppLocalizations l10n, ProfileDtoProfileVisibility v) =>
    switch (v) {
      ProfileDtoProfileVisibility.private ||
      ProfileDtoProfileVisibility.unrecognized =>
        l10n.profileEditVisibilityPrivateHelp,
      ProfileDtoProfileVisibility.connections =>
        l10n.profileEditVisibilityConnectionsHelp,
      ProfileDtoProfileVisibility.public =>
        l10n.profileEditVisibilityPublicHelp,
    };

/// The user's profile photo, read through a short-lived link
/// (`GET /files/{id}/access`), or their initials without one (or while it
/// cannot be shown).
class ProfileAvatar extends ConsumerWidget {
  /// Creates the avatar.
  const ProfileAvatar({
    required this.fileId,
    required this.name,
    this.radius = 24,
    super.key,
  });

  /// The avatar file, or null.
  final String? fileId;

  /// Display name (for initials and the screen-reader label).
  final String name;

  /// Size.
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? id = fileId;
    final DownloadedFile? file = id == null
        ? null
        : ref.watch(privateFileProvider(id)).value;
    final Widget initials = Text(
      initialsOf(name),
      style: TextStyle(fontSize: radius * 0.7),
    );
    return Semantics(
      image: true,
      label: file != null && file.isImage
          ? l10n.profileEditPhotoLabel
          : l10n.profileEditPhotoInitials(name),
      child: ExcludeSemantics(
        child: CircleAvatar(
          radius: radius,
          foregroundImage: file != null && file.isImage
              ? MemoryImage(file.bytes)
              : null,
          onForegroundImageError: file != null && file.isImage
              ? (Object _, StackTrace? _) {}
              : null,
          child: initials,
        ),
      ),
    );
  }
}

/// Up to two initials of [name] ("Asha Rao" → "AR").
String initialsOf(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }
  final String first = parts.first.characters.first;
  final String last = parts.length > 1 ? parts.last.characters.first : '';
  return (first + last).toUpperCase();
}
