import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/widgets/layout.dart';

/// First screen for signed-out users. States only what is true today: the
/// product is free, private by default and works without linking a bank.
class WelcomeScreen extends StatelessWidget {
  /// Creates the screen.
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentFrame(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: Insets.xl),
                ExcludeSemantics(
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: Insets.md),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.appTitle,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.sm),
                Text(l10n.welcomeTagline, style: theme.textTheme.titleMedium),
                const SizedBox(height: Insets.xl),
                _Principle(
                  icon: Icons.volunteer_activism_outlined,
                  title: l10n.welcomeFreeTitle,
                  body: l10n.welcomeFreeBody,
                ),
                _Principle(
                  icon: Icons.lock_outline,
                  title: l10n.welcomePrivateTitle,
                  body: l10n.welcomePrivateBody,
                ),
                _Principle(
                  icon: Icons.edit_note_outlined,
                  title: l10n.welcomeManualTitle,
                  body: l10n.welcomeManualBody,
                ),
                const SizedBox(height: Insets.xl),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => context.push(AppRoutes.signUp),
                  child: Text(l10n.welcomeCreateAccount),
                ),
                const SizedBox(height: Insets.sm + Insets.xs),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => context.push(AppRoutes.signIn),
                  child: Text(l10n.welcomeSignIn),
                ),
                const SizedBox(height: Insets.sm),
                TextButton(
                  onPressed: () => context.push(AppRoutes.contact),
                  child: Text(l10n.contactEntry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Principle extends StatelessWidget {
  const _Principle({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(icon, color: theme.colorScheme.secondary),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: Insets.xs),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
