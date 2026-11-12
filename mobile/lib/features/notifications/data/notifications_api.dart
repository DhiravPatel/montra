import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Notifications` tag: the in-app notification center
/// and its preferences. Mobile push is not registered by this app (no push
/// SDK is bundled), so `/me/push-endpoints` and `/notifications/push-config`
/// are never called; everything arrives in the center.
class NotificationsApi {
  /// Creates the API over [client].
  NotificationsApi(this._client);

  final ApiClient _client;

  /// Notifications fetched per page of the center.
  static const int pageSize = 30;

  /// `GET /notifications`: one page, newest first. [unread] keeps unread
  /// ones only, [archived] lists the archive instead of the inbox, and
  /// [category] limits the page to one category.
  Future<CursorPage<NotificationDto>> list({
    bool? unread,
    bool? archived,
    String? category,
    String? cursor,
    int limit = pageSize,
  }) => _client.send(
    ApiEndpoints.listNotifications,
    query: <String, Object?>{
      'unread': unread,
      'archived': archived,
      'category': category,
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListNotificationDto envelope =
          decodeEnvelopeListNotificationDto(json);
      final bool more = envelope.meta.hasMore ?? true;
      return CursorPage<NotificationDto>(
        envelope.data,
        more ? envelope.meta.nextCursor : null,
      );
    },
  );

  /// `PATCH /notifications/{notificationId}`: marks it read or unread
  /// ([read]) and moves it into or out of the archive ([archived]). Fields
  /// left null keep their value.
  Future<NotificationDto> update(String id, {bool? read, bool? archived}) =>
      _client.send(
        ApiEndpoints.updateNotification,
        pathParameters: <String, String>{'notificationId': id},
        body: NotificationsUpdateRequest(
          read: read,
          archived: archived,
        ).toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeNotificationDto(json).data,
      );

  /// `POST /notifications/read-all`: returns how many were marked read.
  Future<int> readAll() => _client.send(
    ApiEndpoints.readAllNotifications,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeMapStringInt64(json).data['updated'] ?? 0,
  );

  /// `GET /notifications/unread-count`.
  Future<int> unreadCount() => _client.send(
    ApiEndpoints.unreadNotificationCount,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeUnreadCount(json).data.unread,
  );

  /// `GET /notifications/preferences`: every category × channel, plus
  /// group overrides (`group_id`).
  Future<List<PreferenceDto>> preferences() => _client.send(
    ApiEndpoints.notificationPreferences,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListPreferenceDto(json).data,
  );

  /// `PATCH /notifications/preferences`: each item changes only the fields
  /// it sends (`enabled`, `digest` or both). Returns the full list.
  Future<List<PreferenceDto>> updatePreferences(List<PreferencePatch> items) =>
      _client.send(
        ApiEndpoints.updateNotificationPreferences,
        body: NotificationsPreferencesUpdateRequest(items: items).toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListPreferenceDto(json).data,
      );
}

/// Notification endpoints. Overridden in tests.
final Provider<NotificationsApi> notificationsApiProvider =
    Provider<NotificationsApi>(
      (Ref ref) => NotificationsApi(ref.watch(apiClientProvider)),
    );
