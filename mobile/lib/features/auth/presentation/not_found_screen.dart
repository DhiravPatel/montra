import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';

/// Shown for links the app does not handle. The location itself is never
/// displayed or logged because links can carry tokens.
class NotFoundScreen extends StatelessWidget {
  /// Creates the screen.
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: MessageStateView(
        icon: Icons.link_off,
        title: l10n.notFoundTitle,
        body: l10n.notFoundBody,
        action: FilledButton(
          onPressed: () => context.go(AppRoutes.root),
          child: Text(l10n.goHome),
        ),
      ),
    );
  }
}
