import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/groups/application/groups_providers.dart';
import 'package:montra_mobile/features/groups/presentation/group_detail_screen.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';

/// Everything that happened in a group, newest first, in sentences built
/// from the typed events (`GET /groups/{id}/activity`, `before` paging).
class GroupActivityScreen extends ConsumerWidget {
  /// Creates the screen for [groupId].
  const GroupActivityScreen({required this.groupId, super.key});

  /// The group.
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, String> names = switch (ref.watch(
      groupDetailProvider(groupId),
    )) {
      AsyncValue<GroupDetail>(:final GroupDetail value) => memberNames(value),
      _ => const <String, String>{},
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupActivityTitle)),
      body: AsyncValueView<ActivityFeed>(
        value: ref.watch(groupActivityProvider(groupId)),
        onRetry: () => ref.invalidate(groupActivityProvider(groupId)),
        isEmpty: (ActivityFeed f) => f.events.isEmpty,
        empty: MessageStateView(
          icon: Icons.history,
          title: l10n.groupActivityEmpty,
        ),
        data: (ActivityFeed feed) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(groupActivityProvider(groupId));
            try {
              await ref.read(groupActivityProvider(groupId).future);
            } on Object {
              // Shown by the screen state.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              for (final GroupActivityDto e in feed.events)
                ActivityTile(event: e, names: names, groupId: groupId),
              if (feed.loadingMore)
                const Padding(
                  padding: EdgeInsets.all(Insets.md),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (feed.hasMore)
                Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (feed.loadMoreError case final Object error)
                        Text(describeError(l10n, error)),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(groupActivityProvider(groupId).notifier)
                            .loadMore(),
                        icon: const Icon(Icons.expand_more),
                        label: Text(l10n.actionLoadMore),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
