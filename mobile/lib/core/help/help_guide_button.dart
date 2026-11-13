import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/help/help_guide.dart';

/// An app-bar help icon that opens the guide explaining a screen. Screen
/// readers hear "How this works: (guide title)".
class HelpGuideButton extends StatelessWidget {
  /// Creates the button for [guide].
  const HelpGuideButton(this.guide, {super.key});

  /// The guide to open.
  final HelpGuide guide;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return IconButton(
      tooltip: l10n.helpGuidesAffordanceFor(guide.title(l10n)),
      icon: const Icon(Icons.help_outline),
      onPressed: () => context.push(guide.path),
    );
  }
}
