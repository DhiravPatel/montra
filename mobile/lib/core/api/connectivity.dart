import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reports whether the device has a network interface.
///
/// This is a hint, not proof of reachability (a captive portal still counts
/// as "online"); API errors remain the source of truth for failures.
abstract interface class ConnectivityMonitor {
  /// Emits the current state, then every change.
  Stream<bool> watchOnline();
}

/// [ConnectivityMonitor] backed by `connectivity_plus`.
class PlatformConnectivityMonitor implements ConnectivityMonitor {
  /// Creates a monitor; [connectivity] is injectable for tests.
  PlatformConnectivityMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> watchOnline() async* {
    try {
      yield isOnline(await _connectivity.checkConnectivity());
    } on Exception {
      // Unknown state: assume online and let requests decide.
      yield true;
    }
    yield* _connectivity.onConnectivityChanged.map(isOnline);
  }

  /// Online when any interface other than `none` is up.
  static bool isOnline(List<ConnectivityResult> results) =>
      results.any((ConnectivityResult r) => r != ConnectivityResult.none);
}

/// The app-wide monitor. Overridden in tests.
final Provider<ConnectivityMonitor> connectivityMonitorProvider =
    Provider<ConnectivityMonitor>((Ref ref) => PlatformConnectivityMonitor());

/// Whether the device currently has a network connection.
final StreamProvider<bool> isOnlineProvider = StreamProvider<bool>(
  (Ref ref) => ref.watch(connectivityMonitorProvider).watchOnline().distinct(),
);
