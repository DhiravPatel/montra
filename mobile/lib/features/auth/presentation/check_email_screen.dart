import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/resend_verification_button.dart';

/// Shown after registration. The address is passed in memory (route
/// `extra`), never in the URL.
class CheckEmailScreen extends StatelessWidget {
  /// Creates the screen.
  const CheckEmailScreen({this.email, this.next, super.key});

  /// Where to go after signing in (a safe in-app path).
  final String? next;

  /// The address the link was sent to, when known.
  final String? email;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? address = email;
    return AuthScaffold(
      title: l10n.checkEmailTitle,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(
            Icons.mark_email_unread_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: Insets.md),
        Text(
          address == null
              ? l10n.checkEmailBodyNoAddress
              : l10n.checkEmailBody(address),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: Insets.sm),
        Text(l10n.checkEmailSpamHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: Insets.lg),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => context.push(AppRoutes.verifyEmail),
          icon: const Icon(Icons.link),
          label: Text(l10n.haveLinkButton),
        ),
        if (address != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          ResendVerificationButton(email: () => address),
        ],
        const SizedBox(height: Insets.sm),
        TextButton(
          onPressed: () =>
              context.go(AppRoutes.withNext(AppRoutes.signIn, next)),
          child: Text(l10n.backToSignIn),
        ),
      ],
    );
  }
}
