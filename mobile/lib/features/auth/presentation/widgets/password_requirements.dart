import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/features/auth/domain/password_policy.dart';

/// Live checklist of the password rules. Each rule shows an icon and text
/// and announces its state ("Done" / "Not yet"), so progress is not conveyed
/// by color alone.
class PasswordRequirements extends StatelessWidget {
  /// Creates the checklist for [password]; [email] enables the email rule.
  const PasswordRequirements({required this.password, this.email, super.key});

  /// Current password text.
  final String password;

  /// Account email, when known.
  final String? email;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? address = email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.passwordRulesTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: Insets.xs),
        _Rule(
          text: l10n.passwordRuleLength(PasswordPolicy.minLength),
          met: PasswordPolicy.meetsLength(password),
        ),
        if (address != null && address.contains('@'))
          _Rule(
            text: l10n.passwordRuleNotEmail,
            met:
                password.isNotEmpty &&
                PasswordPolicy.avoidsEmail(password, address),
          ),
        _Rule(
          text: l10n.passwordRuleVariety,
          met: PasswordPolicy.hasVariety(password),
        ),
        _Rule(text: l10n.passwordRuleCommon, met: null),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.text, required this.met});

  final String text;

  /// Null when the rule can only be checked by the server.
  final bool? met;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final StatusColors status = StatusColors.of(context);
    final (IconData icon, Color color, String state) = switch (met) {
      true => (Icons.check_circle, status.success, l10n.passwordRuleMet),
      false => (
        Icons.radio_button_unchecked,
        scheme.onSurfaceVariant,
        l10n.passwordRuleNotMet,
      ),
      null => (
        Icons.info_outline,
        scheme.onSurfaceVariant,
        l10n.passwordRuleServerChecked,
      ),
    };
    return Semantics(
      label: '$text: $state',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
