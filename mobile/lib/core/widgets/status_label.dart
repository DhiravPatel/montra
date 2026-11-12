import 'package:flutter/material.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';

/// Meaning of a [StatusLabel].
enum StatusTone {
  /// Enabled, verified, done.
  positive,

  /// Neutral fact.
  neutral,

  /// Needs attention.
  caution,
}

/// A compact status chip: icon + text, never color alone.
class StatusLabel extends StatelessWidget {
  /// Creates the label.
  const StatusLabel({
    required this.text,
    this.tone = StatusTone.neutral,
    this.icon,
    this.semanticsLabel,
    super.key,
  });

  /// Visible text.
  final String text;

  /// Tone.
  final StatusTone tone;

  /// Icon override; each tone has a default.
  final IconData? icon;

  /// Fuller description for screen readers, e.g. "Two-step verification: On".
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final StatusColors status = StatusColors.of(context);
    final (
      Color background,
      Color foreground,
      IconData defaultIcon,
    ) = switch (tone) {
      StatusTone.positive => (
        status.successContainer,
        status.onSuccessContainer,
        Icons.check_circle,
      ),
      StatusTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.circle_outlined,
      ),
      StatusTone.caution => (
        status.warningContainer,
        status.onWarningContainer,
        Icons.error_outline,
      ),
    };
    return Semantics(
      label: semanticsLabel ?? text,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm + Insets.xs,
            vertical: Insets.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon ?? defaultIcon, size: 16, color: foreground),
              const SizedBox(width: Insets.xs),
              Flexible(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
