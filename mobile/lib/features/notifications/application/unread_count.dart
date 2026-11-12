import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/notifications/data/notifications_api.dart';

/// A counter bumped after every notification write (read, unread, archive,
/// read-all), so the center and the badge re-read from the server.
final NotifierProvider<NotificationsRevision, int>
notificationsRevisionProvider = NotifierProvider<NotificationsRevision, int>(
  NotificationsRevision.new,
);

/// See [notificationsRevisionProvider].
class NotificationsRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(currentUserIdProvider);
    return 0;
  }

  /// Marks notifications as changed.
  void bump() => state++;
}

/// How often the badge re-reads the count while the app is open (the Home
/// app bar's [NotificationBell] drives it, and it re-reads when the app
/// comes back to the foreground).
const Duration unreadCountRefreshInterval = Duration(minutes: 2);

/// Unread notifications (`GET /notifications/unread-count`), for the badge
/// on the app's navigation and the Home app bar. Never fails: a read error
/// (offline, signed out) counts as zero. Re-read after every notification
/// write; see [unreadCountRefreshInterval].
final FutureProvider<int> unreadNotificationCountProvider = FutureProvider<int>(
  (Ref ref) async {
    final String? userId = ref.watch(currentUserIdProvider);
    ref.watch(notificationsRevisionProvider);
    if (userId == null) {
      return 0;
    }
    try {
      return await ref.read(notificationsApiProvider).unreadCount();
    } on Object {
      return 0;
    }
  },
);
