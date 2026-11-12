import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/notifications/application/unread_count.dart';
import 'package:montra_mobile/features/notifications/data/notifications_api.dart';

/// What the center lists: the inbox or the archive, optionally unread ones
/// only, optionally one category (`''` = any).
typedef NotificationFilter = ({
  bool unreadOnly,
  bool archived,
  String category,
});

/// The inbox, newest first.
const NotificationFilter inboxFilter = (
  unreadOnly: false,
  archived: false,
  category: '',
);

/// Notifications for [NotificationFilter], page by page ("Load more").
/// Re-read from the first page after every notification write.
final AsyncNotifierProviderFamily<
  NotificationsController,
  PagedList<NotificationDto>,
  NotificationFilter
>
notificationsProvider = AsyncNotifierProvider.autoDispose
    .family<
      NotificationsController,
      PagedList<NotificationDto>,
      NotificationFilter
    >(NotificationsController.new);

/// See [notificationsProvider].
class NotificationsController extends PagedListController<NotificationDto> {
  /// Creates the controller for [filter].
  NotificationsController(this.filter);

  /// The filter.
  final NotificationFilter filter;

  @override
  Future<PagedList<NotificationDto>> build() async {
    ref
      ..watch(currentUserIdProvider)
      ..watch(notificationsRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<NotificationDto>> fetchPage(String? cursor) => ref
      .read(notificationsApiProvider)
      .list(
        unread: filter.unreadOnly ? true : null,
        archived: filter.archived ? true : null,
        category: filter.category.isEmpty ? null : filter.category,
        cursor: cursor,
      );

  @override
  String keyOf(NotificationDto item) => item.id;
}

/// Notification preferences: every category × channel plus group
/// overrides (`GET /notifications/preferences`).
final FutureProvider<List<PreferenceDto>> notificationPreferencesProvider =
    FutureProvider.autoDispose<List<PreferenceDto>>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(notificationsApiProvider).preferences();
    });
