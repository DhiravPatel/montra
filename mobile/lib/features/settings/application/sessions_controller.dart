import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/settings/data/account_security_api.dart';

/// Active sessions of the signed-in user (current device first, then most
/// recently active).
final AsyncNotifierProvider<SessionsController, List<SessionDto>>
sessionsControllerProvider =
    AsyncNotifierProvider.autoDispose<SessionsController, List<SessionDto>>(
      SessionsController.new,
    );

/// Loads and revokes sessions.
class SessionsController extends AsyncNotifier<List<SessionDto>> {
  @override
  Future<List<SessionDto>> build() async {
    final List<SessionDto> sessions = await ref
        .read(accountSecurityApiProvider)
        .listSessions();
    return sortSessions(sessions);
  }

  /// Reloads the list, keeping the current list visible meanwhile.
  Future<void> reload() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // The error is exposed through `state`.
    }
  }

  /// Revokes [session]. Returns false when it had already ended (404).
  /// Throws [ApiException] for other failures.
  Future<bool> revoke(SessionDto session) async {
    try {
      await ref.read(accountSecurityApiProvider).revokeSession(session.id);
    } on ApiException catch (error) {
      if (error.code != ErrorObjectCode.notFound) {
        rethrow;
      }
      await reload();
      return false;
    }
    await reload();
    return true;
  }

  /// Current session first, then by last activity (newest first).
  static List<SessionDto> sortSessions(List<SessionDto> sessions) {
    final List<SessionDto> sorted = List<SessionDto>.of(sessions)
      ..sort((SessionDto a, SessionDto b) {
        if (a.current != b.current) {
          return a.current ? -1 : 1;
        }
        return b.lastSeenAt.compareTo(a.lastSeenAt);
      });
    return List<SessionDto>.unmodifiable(sorted);
  }
}
