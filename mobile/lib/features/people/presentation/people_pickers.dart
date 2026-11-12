import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';

/// A person chosen to share a budget or goal with.
@immutable
class PersonChoice {
  /// Creates a choice.
  const PersonChoice({
    required this.userId,
    required this.displayName,
    this.username,
  });

  /// The person's user ID.
  final String userId;

  /// Name shown in the app.
  final String displayName;

  /// Public handle, if any.
  final String? username;
}

/// A circle with the first letter of [name] (decorative; screen readers
/// read the name next to it).
class InitialsAvatar extends StatelessWidget {
  /// Creates the avatar.
  const InitialsAvatar({required this.name, this.size = 36, super.key});

  /// Name to take the initial from.
  final String name;

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String trimmed = name.trim();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: colors.secondaryContainer,
        foregroundColor: colors.onSecondaryContainer,
        child: Text(
          trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
        ),
      ),
    );
  }
}

String? _handle(String? username) =>
    username == null || username.isEmpty ? null : '@$username';

/// Picks a connection or, with [groupId], a current member of that group.
/// People in [excludeIds] (already added) are left out. Returns null when
/// dismissed.
Future<PersonChoice?> showPersonPicker(
  BuildContext context, {
  String? groupId,
  Set<String> excludeIds = const <String>{},
}) async {
  final AppLocalizations l10n = context.l10n;
  final String? group = groupId;
  final Picked<PersonChoice>? picked = group == null
      ? await showSingleSelection<PublicProfile, PersonChoice>(
          context,
          title: l10n.personPickerTitle,
          source: friendsProvider,
          onRetry: (WidgetRef ref) => ref.invalidate(friendsProvider),
          items: (BuildContext context, List<PublicProfile> data) =>
              <SelectionItem<PersonChoice>>[
                for (final PublicProfile p in data)
                  if (!excludeIds.contains(p.userId))
                    SelectionItem<PersonChoice>(
                      id: p.userId,
                      value: PersonChoice(
                        userId: p.userId,
                        displayName: p.displayName,
                        username: p.username,
                      ),
                      label: p.displayName,
                      subtitle: _handle(p.username),
                      searchText: '${p.displayName} ${p.username ?? ''}',
                      leading: InitialsAvatar(name: p.displayName),
                    ),
              ],
          emptyText: l10n.personPickerEmpty,
        )
      : await showSingleSelection<GroupMemberDto, PersonChoice>(
          context,
          title: l10n.groupMemberPickerTitle,
          source: groupMembersProvider(group),
          onRetry: (WidgetRef ref) =>
              ref.invalidate(groupDetailProvider(group)),
          items: (BuildContext context, List<GroupMemberDto> data) =>
              <SelectionItem<PersonChoice>>[
                for (final GroupMemberDto m in data)
                  if (!excludeIds.contains(m.userId))
                    SelectionItem<PersonChoice>(
                      id: m.userId,
                      value: PersonChoice(
                        userId: m.userId,
                        displayName: m.displayName,
                        username: m.username,
                      ),
                      label: m.displayName,
                      subtitle: _handle(m.username),
                      searchText: '${m.displayName} ${m.username ?? ''}',
                      leading: InitialsAvatar(name: m.displayName),
                    ),
              ],
          emptyText: l10n.groupMemberPickerEmpty,
        );
  return picked?.value;
}

/// Picks one of the user's active groups. Returns null when dismissed and
/// `Picked(null)` for "No group" (offered when [allowNone]).
Future<Picked<GroupDto>?> showGroupPicker(
  BuildContext context, {
  String? selectedId,
  bool allowNone = true,
}) {
  final AppLocalizations l10n = context.l10n;
  return showSingleSelection<GroupDto, GroupDto>(
    context,
    title: l10n.groupPickerTitle,
    source: groupsProvider,
    onRetry: (WidgetRef ref) => ref.invalidate(groupsProvider),
    items: (BuildContext context, List<GroupDto> data) =>
        <SelectionItem<GroupDto>>[
          for (final GroupDto g in data)
            SelectionItem<GroupDto>(
              id: g.id,
              value: g,
              label: g.name,
              subtitle: l10n.groupMemberCount(g.memberCount),
              leading: const Icon(Icons.groups_outlined),
            ),
        ],
    selectedId: selectedId,
    noneLabel: allowNone ? l10n.groupNone : null,
    emptyText: l10n.groupPickerEmpty,
  );
}
