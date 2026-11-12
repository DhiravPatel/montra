import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';
import 'package:montra_mobile/features/social/application/social_providers.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';
import 'package:montra_mobile/features/social/domain/social_display.dart';
import 'package:share_plus/share_plus.dart';

/// Shares plain text (an invitation link) through the system share sheet.
/// Overridden in tests.
final Provider<Future<void> Function(String text)> textSharerProvider =
    Provider<Future<void> Function(String text)>(
      (Ref ref) =>
          (String text) => SharePlus.instance.share(ShareParams(text: text)),
    );

/// Copies [text] and says so.
Future<void> copyText(BuildContext context, String text) async {
  final String done = context.l10n.copiedToClipboard;
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    showSnack(context, done);
  }
}

/// One person in a list: initials, name (user text, shown as plain text),
/// `@username` and status labels for mute and block.
class PersonTile extends StatelessWidget {
  /// Creates the tile.
  const PersonTile({
    required this.person,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  /// The person.
  final PersonView person;

  /// Extra line under the handle.
  final String? subtitle;

  /// Trailing widget (actions).
  final Widget? trailing;

  /// Opens the person's actions.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? handle = usernameHandle(person.username);
    return ListTile(
      leading: InitialsAvatar(name: person.displayName),
      title: Text(person.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (handle != null) Text(handle),
          if (subtitle != null) Text(subtitle!),
          if (person.muted || person.blockedByMe)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Wrap(
                spacing: Insets.xs,
                runSpacing: Insets.xs,
                children: <Widget>[
                  if (person.blockedByMe)
                    StatusLabel(
                      text: l10n.friendBlockedLabel,
                      icon: Icons.block,
                      tone: StatusTone.caution,
                    ),
                  if (person.muted)
                    StatusLabel(
                      text: l10n.friendMutedLabel,
                      icon: Icons.volume_off_outlined,
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing:
          trailing ?? (onTap == null ? null : const Icon(Icons.more_vert)),
      onTap: onTap,
    );
  }
}

enum _PersonAction { request, mute, unmute, block, unblock, remove }

/// Runs a social write and reports the result; refreshes every list that
/// shows people afterwards. Returns whether it succeeded.
Future<bool> runSocialAction(
  BuildContext context,
  WidgetRef ref, {
  required Future<String> Function(SocialApi api) action,
}) async {
  final AppLocalizations l10n = context.l10n;
  final SocialApi api = ref.read(socialApiProvider);
  try {
    final String done = await action(api);
    refreshSocial(ref);
    if (context.mounted) {
      showSnack(context, done);
    }
    return true;
  } on ApiException catch (error) {
    if (error.code == ErrorObjectCode.conflict) {
      // Already friends, already asked…: show the current state.
      refreshSocial(ref);
    }
    if (context.mounted) {
      showSnack(context, describeError(l10n, error));
    }
    return false;
  }
}

/// The actions for [person]: send a request, mute or unmute, block or
/// unblock, and remove a friend (each destructive one confirmed).
Future<void> showPersonActions(
  BuildContext context,
  WidgetRef ref,
  PersonView person,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool friend = person.connection == PublicProfileConnection.friend;
  final bool canRequest =
      !person.blockedByMe &&
      (person.connection == PublicProfileConnection.none ||
          person.connection == PublicProfileConnection.requestReceived);
  final _PersonAction? action = await showOptionSheet<_PersonAction>(
    context,
    title: person.displayName,
    options: <SheetOption<_PersonAction>>[
      if (canRequest)
        SheetOption<_PersonAction>(
          value: _PersonAction.request,
          label: person.connection == PublicProfileConnection.requestReceived
              ? l10n.friendRequestAcceptTheirs
              : l10n.friendRequestSend,
          icon: Icons.person_add_alt_1_outlined,
        ),
      if (person.muted)
        SheetOption<_PersonAction>(
          value: _PersonAction.unmute,
          label: l10n.friendUnmute,
          icon: Icons.volume_up_outlined,
        )
      else
        SheetOption<_PersonAction>(
          value: _PersonAction.mute,
          label: l10n.friendMute,
          subtitle: l10n.friendMuteHelp,
          icon: Icons.volume_off_outlined,
        ),
      if (person.blockedByMe)
        SheetOption<_PersonAction>(
          value: _PersonAction.unblock,
          label: l10n.friendUnblock,
          icon: Icons.lock_open_outlined,
        )
      else
        SheetOption<_PersonAction>(
          value: _PersonAction.block,
          label: l10n.friendBlock,
          subtitle: l10n.friendBlockHelp,
          icon: Icons.block,
          destructive: true,
        ),
      if (friend)
        SheetOption<_PersonAction>(
          value: _PersonAction.remove,
          label: l10n.friendRemove,
          icon: Icons.person_remove_outlined,
          destructive: true,
        ),
    ],
  );
  if (action == null || !context.mounted) {
    return;
  }
  final String name = person.displayName;
  switch (action) {
    case _PersonAction.request:
      await sendFriendRequest(context, ref, person);
    case _PersonAction.mute:
      await runSocialAction(
        context,
        ref,
        action: (SocialApi api) async {
          await api.setMuted(person.userId, muted: true);
          return l10n.friendMutedDone(name);
        },
      );
    case _PersonAction.unmute:
      await runSocialAction(
        context,
        ref,
        action: (SocialApi api) async {
          await api.setMuted(person.userId, muted: false);
          return l10n.friendUnmutedDone(name);
        },
      );
    case _PersonAction.block:
      final bool ok = await showConfirmDialog(
        context,
        title: l10n.friendBlockConfirmTitle(name),
        body: l10n.friendBlockConfirmBody,
        confirmLabel: l10n.friendBlock,
        destructive: true,
      );
      if (ok && context.mounted) {
        await runSocialAction(
          context,
          ref,
          action: (SocialApi api) async {
            await api.block(person.userId);
            return l10n.friendBlockedDone(name);
          },
        );
      }
    case _PersonAction.unblock:
      await runSocialAction(
        context,
        ref,
        action: (SocialApi api) async {
          await api.unblock(person.userId);
          return l10n.friendUnblockedDone(name);
        },
      );
    case _PersonAction.remove:
      final bool ok = await showConfirmDialog(
        context,
        title: l10n.friendRemoveConfirmTitle(name),
        body: l10n.friendRemoveConfirmBody,
        confirmLabel: l10n.friendRemove,
        destructive: true,
      );
      if (ok && context.mounted) {
        await runSocialAction(
          context,
          ref,
          action: (SocialApi api) async {
            await api.removeFriend(person.userId);
            return l10n.friendRemovedDone(name);
          },
        );
      }
  }
}

/// Sends a friend request to [person]. When they had already asked, the
/// server accepts their request instead and the two are friends now.
Future<bool> sendFriendRequest(
  BuildContext context,
  WidgetRef ref,
  PersonView person,
) {
  final AppLocalizations l10n = context.l10n;
  return runSocialAction(
    context,
    ref,
    action: (SocialApi api) async {
      final FriendRequestDto result = await api.sendFriendRequest(
        person.userId,
      );
      return result.status == FriendRequestDtoStatus.accepted
          ? l10n.friendNowFriends(person.displayName)
          : l10n.friendRequestSentDone(person.displayName);
    },
  );
}
