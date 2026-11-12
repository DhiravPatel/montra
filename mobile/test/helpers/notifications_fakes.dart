import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/notifications/data/notifications_api.dart';

class MockNotificationsApi extends Mock implements NotificationsApi {}

/// Registers fallback values for `any()` on [MockNotificationsApi].
void registerNotificationFallbacks() {
  registerFallbackValue(<PreferencePatch>[]);
  registerFallbackValue(const PreferencesPatch());
}

/// A `NotificationDTO` JSON object (live shape: a friend request).
Map<String, Object?> notificationJson({
  String id = 'n-1',
  String category = 'social',
  String eventType = 'friend_request',
  String title = 'New friend request',
  String body = 'Open Friends to accept or decline.',
  String? deepLink = '/friends?tab=requests',
  String? entityType = 'friend_request',
  String? entityId = 'fr-1',
  String? groupId,
  String priority = 'normal',
  String? readAt,
  String? archivedAt,
  String createdAt = '2026-11-12T06:14:42Z',
}) => <String, Object?>{
  'id': id,
  'category': category,
  'event_type': eventType,
  'title': title,
  'body': body,
  'deep_link': ?deepLink,
  'entity_type': ?entityType,
  'entity_id': ?entityId,
  'group_id': ?groupId,
  'priority': priority,
  'read_at': ?readAt,
  'archived_at': ?archivedAt,
  'created_at': createdAt,
};

/// A `NotificationDTO`.
NotificationDto notification({
  String id = 'n-1',
  String category = 'social',
  String title = 'New friend request',
  String body = 'Open Friends to accept or decline.',
  String? deepLink = '/friends?tab=requests',
  String? entityType = 'friend_request',
  String? entityId = 'fr-1',
  String? groupId,
  String priority = 'normal',
  String? readAt,
  String? archivedAt,
}) => NotificationDto.fromJson(
  notificationJson(
    id: id,
    category: category,
    title: title,
    body: body,
    deepLink: deepLink,
    entityType: entityType,
    entityId: entityId,
    groupId: groupId,
    priority: priority,
    readAt: readAt,
    archivedAt: archivedAt,
  ),
);

/// One page of notifications.
CursorPage<NotificationDto> notificationPage(
  List<NotificationDto> items, {
  String? next,
}) => CursorPage<NotificationDto>(items, next);

const List<String> _categories = <String>[
  'budget',
  'bill',
  'subscription',
  'recurring',
  'goal',
  'group',
  'settlement',
  'trip',
  'community',
  'challenge',
  'security',
  'import',
  'receipt',
  'export',
  'account',
  'insight',
  'system',
  'social',
];

/// The server's default preferences (every category × channel), like
/// `GET /notifications/preferences` for a new account, with [overrides]
/// (`category|channel` → enabled/digest) applied.
List<PreferenceDto> preferenceList({
  Map<String, ({bool enabled, String digest})> overrides =
      const <String, ({bool enabled, String digest})>{},
  List<Map<String, Object?>> groupRows = const <Map<String, Object?>>[],
}) => <PreferenceDto>[
  for (final String c in _categories)
    for (final String ch in <String>['in_app', 'email', 'web_push', 'push'])
      PreferenceDto.fromJson(<String, Object?>{
        'category': c,
        'channel': ch,
        'enabled':
            overrides['$c|$ch']?.enabled ??
            (ch != 'email' ||
                <String>{'security', 'account', 'export'}.contains(c)),
        'digest': overrides['$c|$ch']?.digest ?? 'immediate',
        'locked':
            <String>{'security', 'account'}.contains(c) &&
            (ch == 'in_app' || ch == 'email'),
      }),
  for (final Map<String, Object?> g in groupRows) PreferenceDto.fromJson(g),
];
