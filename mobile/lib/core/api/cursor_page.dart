import 'package:flutter/foundation.dart';

/// One page of a cursor-paginated list (`meta.next_cursor`).
@immutable
class CursorPage<T> {
  /// Creates the page.
  const CursorPage(this.items, this.nextCursor);

  /// Items in the requested order.
  final List<T> items;

  /// Opaque cursor for the next page; null on the last page.
  final String? nextCursor;

  /// Whether more items exist.
  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}
