import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/connectivity.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';

/// Shown while a stored session is being restored, and when restoring fails
/// because Montra cannot be reached (credentials are kept; the user can
/// retry, which also happens automatically when the device reconnects).
class SplashScreen extends ConsumerWidget {
  /// Creates the screen.
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AuthState auth = ref.watch(authControllerProvider);
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (
      AsyncValue<bool>? previous,
      AsyncValue<bool> next,
    ) {
      final bool cameOnline = previous?.value == false && (next.value ?? false);
      if (cameOnline && ref.read(authControllerProvider) is AuthRestoreFailed) {
        unawaited(ref.read(authControllerProvider.notifier).restore());
      }
    });

    final Widget body = switch (auth) {
      AuthRestoreFailed(:final ApiException error) => MessageStateView(
        icon: Icons.cloud_off_outlined,
        title: l10n.splashRestoreFailedTitle,
        body: error.isConnectivityProblem
            ? l10n.splashRestoreFailedBody
            : describeError(l10n, error),
        requestId: requestIdOf(error),
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).restore(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.actionRetry),
            ),
            const SizedBox(height: Insets.sm),
            TextButton(
              onPressed: () => ref
                  .read(authControllerProvider.notifier)
                  .discardStoredSession(),
              child: Text(l10n.splashSignOut),
            ),
          ],
        ),
      ),
      _ => LoadingStateView(label: l10n.splashRestoring),
    };
    return Scaffold(body: SafeArea(child: body));
  }
}
