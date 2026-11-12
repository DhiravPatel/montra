import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';
import 'package:montra_mobile/features/notifications/application/notifications_providers.dart';
import 'package:montra_mobile/features/notifications/application/unread_count.dart';
import 'package:montra_mobile/features/notifications/data/notifications_api.dart';
import 'package:montra_mobile/features/notifications/domain/deep_links.dart';
import 'package:montra_mobile/features/notifications/domain/notification_display.dart';

/// Which part of the center is shown.
enum _View { inbox, unread, archive }

/// The notification center (`GET /notifications`, page by page): inbox,
/// unread only or the archive, optionally one category. Opening a
/// notification marks it read and goes to the screen its link names; each
/// one can be marked read or unread and archived. Push notifications are
/// not set up in this mobile build, so everything arrives here.
class NotificationsScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [now] is injectable for tests.
  const NotificationsScreen({this.now, super.key});

  /// Clock for "5 minutes ago".
  final DateTime Function()? now;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _View _view = _View.inbox;
  String _category = '';
  final Set<String> _busy = <String>{};

  NotificationFilter get _filter => (
    unreadOnly: _view == _View.unread,
    archived: _view == _View.archive,
    category: _category,
  );

  void _changed() => ref.read(notificationsRevisionProvider.notifier).bump();

  Future<void> _refresh() async {
    ref
      ..invalidate(notificationsProvider(_filter))
      ..invalidate(unreadNotificationCountProvider);
    try {
      await ref.read(notificationsProvider(_filter).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  Future<bool> _update(NotificationDto n, {bool? read, bool? archived}) async {
    if (_busy.contains(n.id)) {
      return false;
    }
    setState(() => _busy.add(n.id));
    try {
      await ref
          .read(notificationsApiProvider)
          .update(n.id, read: read, archived: archived);
      _changed();
      return true;
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, describeError(context.l10n, error));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy.remove(n.id));
      }
    }
  }

  Future<void> _open(NotificationDto n) async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    final String? route = notificationRoute(n);
    if (n.readAt == null) {
      await _update(n, read: true);
    }
    if (!mounted) {
      return;
    }
    if (route == null) {
      showSnack(context, l10n.notifNothingToOpen);
      return;
    }
    await router.push(route);
  }

  Future<void> _readAll() async {
    final AppLocalizations l10n = context.l10n;
    try {
      final int updated = await ref.read(notificationsApiProvider).readAll();
      _changed();
      if (mounted) {
        showSnack(context, l10n.notifReadAllDone(updated));
      }
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  Future<void> _actions(NotificationDto n) async {
    final AppLocalizations l10n = context.l10n;
    final bool unread = n.readAt == null;
    final bool archived = n.archivedAt != null;
    final _Action? action = await showOptionSheet<_Action>(
      context,
      title: n.title,
      options: <SheetOption<_Action>>[
        SheetOption<_Action>(
          value: unread ? _Action.read : _Action.unread,
          label: unread ? l10n.notifMarkRead : l10n.notifMarkUnread,
          icon: unread
              ? Icons.mark_email_read_outlined
              : Icons.mark_email_unread_outlined,
        ),
        SheetOption<_Action>(
          value: archived ? _Action.unarchive : _Action.archive,
          label: archived ? l10n.notifMoveToInbox : l10n.notifArchive,
          icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
        ),
      ],
    );
    if (action == null || !mounted) {
      return;
    }
    final bool ok = switch (action) {
      _Action.read => await _update(n, read: true),
      _Action.unread => await _update(n, read: false),
      _Action.archive => await _update(n, archived: true),
      _Action.unarchive => await _update(n, archived: false),
    };
    if (ok && mounted) {
      showSnack(context, switch (action) {
        _Action.read => l10n.notifMarkedRead,
        _Action.unread => l10n.notifMarkedUnread,
        _Action.archive => l10n.notifArchived,
        _Action.unarchive => l10n.notifMovedToInbox,
      });
    }
  }

  Future<void> _pickCategory() async {
    final AppLocalizations l10n = context.l10n;
    final String? picked = await showOptionSheet<String>(
      context,
      title: l10n.notifCategoryFilter,
      selected: _category,
      options: <SheetOption<String>>[
        SheetOption<String>(
          value: '',
          label: l10n.notifCategoryAll,
          icon: Icons.all_inbox_outlined,
        ),
        for (final String c in notificationCategories)
          SheetOption<String>(
            value: c,
            label: notificationCategoryLabel(l10n, c),
            icon: notificationCategoryIcon(c),
          ),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _category = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final NotificationFilter filter = _filter;
    final AsyncValue<PagedList<NotificationDto>> list = ref.watch(
      notificationsProvider(filter),
    );
    final int unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        bottom: list.isLoading && list.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.notifReadAll,
            icon: const Icon(Icons.done_all),
            onPressed: unread > 0 ? _readAll : null,
          ),
          IconButton(
            tooltip: l10n.notifSettingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.notificationSettings),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              Insets.xs,
            ),
            child: Row(
              children: <Widget>[
                for (final _View v in _View.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Insets.sm),
                    child: ChoiceChip(
                      label: Text(switch (v) {
                        _View.inbox => l10n.notifViewInbox,
                        _View.unread => l10n.notifViewUnread,
                        _View.archive => l10n.notifViewArchive,
                      }),
                      selected: _view == v,
                      onSelected: (_) => setState(() => _view = v),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.filter_list, size: 18),
                  label: Text(
                    _category.isEmpty
                        ? l10n.notifCategoryAll
                        : notificationCategoryLabel(l10n, _category),
                  ),
                  tooltip: l10n.notifCategoryFilter,
                  onPressed: _pickCategory,
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<PagedList<NotificationDto>>(
              value: list,
              onRetry: () => ref.invalidate(notificationsProvider(filter)),
              isEmpty: (PagedList<NotificationDto> p) => p.items.isEmpty,
              empty: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    MessageStateView(
                      icon: Icons.notifications_none_outlined,
                      title: switch (_view) {
                        _View.inbox => l10n.notifEmptyTitle,
                        _View.unread => l10n.notifEmptyUnreadTitle,
                        _View.archive => l10n.notifEmptyArchiveTitle,
                      },
                      body: l10n.notifEmptyBody,
                    ),
                  ],
                ),
              ),
              data: (PagedList<NotificationDto> p) => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: Insets.xl),
                  itemCount: p.items.length + 1,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == p.items.length) {
                      return LoadMoreFooter(
                        list: p,
                        onLoadMore: () => ref
                            .read(notificationsProvider(filter).notifier)
                            .loadMore(),
                      );
                    }
                    final NotificationDto n = p.items[index];
                    return NotificationTile(
                      notification: n,
                      now: (widget.now ?? DateTime.now)(),
                      busy: _busy.contains(n.id),
                      onOpen: () => _open(n),
                      onActions: () => _actions(n),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Action { read, unread, archive, unarchive }

/// One notification: category icon, title (bold while unread), the plain
/// text body, category, time and priority; tapping opens it, the menu
/// button marks it read/unread or archives it.
class NotificationTile extends StatelessWidget {
  /// Creates the tile.
  const NotificationTile({
    required this.notification,
    required this.now,
    required this.onOpen,
    required this.onActions,
    this.busy = false,
    super.key,
  });

  /// The notification.
  final NotificationDto notification;

  /// The current time, for relative times.
  final DateTime now;

  /// Opens it.
  final VoidCallback onOpen;

  /// Shows its actions.
  final VoidCallback onActions;

  /// Whether a change is being saved.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final NotificationDto n = notification;
    final bool unread = n.readAt == null;
    final String? priority = notificationPriorityLabel(l10n, n.priority);
    final String meta = <String>[
      notificationCategoryLabel(l10n, n.category),
      formatRelativeTime(l10n, n.createdAt, now: now, locale: locale),
    ].join(' · ');
    return Semantics(
      label: unread ? l10n.notifUnreadLabel : null,
      child: ListTile(
        onTap: busy ? null : onOpen,
        leading: ExcludeSemantics(
          child: Badge(
            isLabelVisible: unread,
            smallSize: 10,
            child: Icon(notificationCategoryIcon(n.category)),
          ),
        ),
        title: Text(
          n.title,
          style: unread
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )
              : theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (n.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text(n.body),
              ),
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Text(meta, style: theme.textTheme.bodySmall),
            ),
            if (priority != null || unread)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    if (unread)
                      StatusLabel(
                        text: l10n.notifUnreadLabel,
                        icon: Icons.markunread_outlined,
                      ),
                    if (priority != null)
                      StatusLabel(
                        text: priority,
                        tone: StatusTone.caution,
                        icon: Icons.priority_high,
                      ),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: l10n.notifActions,
                icon: const Icon(Icons.more_vert),
                onPressed: onActions,
              ),
      ),
    );
  }
}
