import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';

/// The end of a paged list: a "Load more" button while more pages exist, a
/// progress indicator while the next page loads, and the reason (with a
/// retry) when it failed. Nothing once everything is loaded.
class LoadMoreFooter extends StatelessWidget {
  /// Creates the footer for [list].
  const LoadMoreFooter({
    required this.list,
    required this.onLoadMore,
    super.key,
  });

  /// The loaded pages.
  final PagedList<Object?> list;

  /// Loads the next page.
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Object? error = list.loadMoreError;
    if (list.loadingMore) {
      return Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Center(
          child: Semantics(
            label: l10n.loadingLabel,
            child: const SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
      );
    }
    if (!list.hasMore) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (error != null) ...<Widget>[
            Semantics(
              liveRegion: true,
              child: Text(
                describeError(l10n, error),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: Insets.xs),
          ],
          OutlinedButton.icon(
            onPressed: onLoadMore,
            icon: Icon(error == null ? Icons.expand_more : Icons.refresh),
            label: Text(error == null ? l10n.actionLoadMore : l10n.actionRetry),
          ),
        ],
      ),
    );
  }
}
