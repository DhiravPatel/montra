import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';

/// The pages of a cursor-paginated list loaded so far (`meta.next_cursor`).
///
/// Used by every "Load more" list of the organize and planning screens
/// (merchants, budget transactions and alerts, goal contributions).
@immutable
class PagedList<T> {
  /// Creates the state.
  const PagedList({
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// Items loaded so far, in server order.
  final List<T> items;

  /// Cursor of the next page; null after the last page.
  final String? nextCursor;

  /// Whether the next page is being fetched.
  final bool loadingMore;

  /// Why the last "load more" failed (the loaded items stay visible).
  final Object? loadMoreError;

  /// Whether more pages exist.
  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  /// A copy with other paging fields.
  PagedList<T> copyWith({
    List<T>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
    Object? loadMoreError,
  }) => PagedList<T>(
    items: items ?? this.items,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    loadingMore: loadingMore ?? false,
    loadMoreError: loadMoreError,
  );
}

/// Loads a cursor-paginated list page by page. Subclasses fetch a page and
/// name each item's key (duplicates across pages are dropped); [build]
/// watches whatever should restart the list and returns [firstPage].
abstract class PagedListController<T> extends AsyncNotifier<PagedList<T>> {
  /// Fetches the page after [cursor] (the first page when null).
  Future<CursorPage<T>> fetchPage(String? cursor);

  /// A stable key of [item] (its ID).
  String keyOf(T item);

  /// Loads the first page.
  Future<PagedList<T>> firstPage() async {
    final CursorPage<T> page = await fetchPage(null);
    return PagedList<T>(items: page.items, nextCursor: page.nextCursor);
  }

  /// Loads the next page, if any. Failures keep the loaded items and are
  /// reported in [PagedList.loadMoreError].
  Future<void> loadMore() async {
    final PagedList<T>? current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        state.isLoading) {
      return;
    }
    state = AsyncData<PagedList<T>>(current.copyWith(loadingMore: true));
    try {
      final CursorPage<T> page = await fetchPage(current.nextCursor);
      if (!ref.mounted) {
        return;
      }
      final Set<String> seen = <String>{
        for (final T item in current.items) keyOf(item),
      };
      state = AsyncData<PagedList<T>>(
        PagedList<T>(
          items: <T>[
            ...current.items,
            for (final T item in page.items)
              if (!seen.contains(keyOf(item))) item,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncData<PagedList<T>>(current.copyWith(loadMoreError: error));
    }
  }
}
