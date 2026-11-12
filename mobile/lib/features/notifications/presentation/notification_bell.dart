import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/features/notifications/application/unread_count.dart';

/// App-bar button that opens the notification center, with the unread
/// count as a badge (the count is also read out by screen readers).
///
/// While it is on screen (Home stays alive in the tab stack), it re-reads
/// the count every [unreadCountRefreshInterval] and when the app returns to
/// the foreground, so the badge stays current without push notifications.
class NotificationBell extends ConsumerStatefulWidget {
  /// Creates the button.
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(unreadCountRefreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _refresh() {
    if (mounted) {
      ref.invalidate(unreadNotificationCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final String tooltip = unread > 0
        ? '${l10n.notificationsTitle}, ${l10n.notificationsUnreadBadge(unread)}'
        : l10n.notificationsTitle;
    return IconButton(
      tooltip: tooltip,
      icon: Badge.count(
        count: unread,
        isLabelVisible: unread > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => context.push(AppRoutes.notifications),
    );
  }
}
