import 'dart:async';

import 'package:flutter/widgets.dart';

/// Adds a one-second countdown to a [State], used to honor `Retry-After`
/// and to space out "resend email" requests.
mixin CountdownMixin<T extends StatefulWidget> on State<T> {
  Timer? _countdownTimer;
  int _remaining = 0;

  /// Seconds left; zero when idle.
  int get countdownSeconds => _remaining;

  /// Whether the countdown is running.
  bool get isCountingDown => _remaining > 0;

  /// Starts (or restarts) a countdown of [duration], rounded up to seconds.
  void startCountdown(Duration duration) {
    _countdownTimer?.cancel();
    final int seconds = (duration.inMilliseconds / 1000).ceil();
    if (seconds <= 0) {
      setState(() => _remaining = 0);
      return;
    }
    setState(() => _remaining = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining = _remaining > 0 ? _remaining - 1 : 0);
      if (_remaining == 0) {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
