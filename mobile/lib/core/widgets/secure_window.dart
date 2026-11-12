import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Blocks screenshots, screen recording and the recents thumbnail on
/// Android (`FLAG_SECURE`) while sensitive content is visible, such as a
/// two-step verification secret or recovery codes.
///
/// iOS offers no equivalent API; there this is a no-op (documented in the
/// README). The native side lives in `MainActivity.kt`.
class SecureWindow extends StatefulWidget {
  /// Protects the window while [child] is mounted.
  const SecureWindow({required this.child, super.key});

  /// Sensitive content.
  final Widget child;

  @override
  State<SecureWindow> createState() => _SecureWindowState();
}

class _SecureWindowState extends State<SecureWindow> {
  @override
  void initState() {
    super.initState();
    SecureWindowController.instance.acquire();
  }

  @override
  void dispose() {
    SecureWindowController.instance.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Reference-counted access to the native secure-window flag.
class SecureWindowController {
  SecureWindowController._();

  /// Shared instance.
  static final SecureWindowController instance = SecureWindowController._();

  static const MethodChannel _channel = MethodChannel(
    'app.montra.mobile/secure_window',
  );

  int _holders = 0;

  /// Marks the window secure (first holder enables the flag).
  void acquire() {
    _holders++;
    if (_holders == 1) {
      unawaited(_invoke('enable'));
    }
  }

  /// Releases a hold (last holder clears the flag).
  void release() {
    if (_holders == 0) {
      return;
    }
    _holders--;
    if (_holders == 0) {
      unawaited(_invoke('disable'));
    }
  }

  Future<void> _invoke(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Tests and non-Android hosts have no native handler.
    } on PlatformException {
      // Best effort: the content still renders.
    }
  }
}
