import 'package:flutter/material.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';

/// Visual weight of a [SubmitButton].
enum SubmitButtonKind {
  /// Primary filled button.
  filled,

  /// Secondary outlined button.
  outlined,

  /// Destructive filled button (error colors).
  destructive,
}

/// A full-width button for asynchronous actions.
///
/// While [onPressed] runs (or while [busy] is true) the button is disabled
/// and shows a progress indicator, so repeated taps cannot submit twice.
class SubmitButton extends StatefulWidget {
  /// Creates the button. A null [onPressed] disables it.
  const SubmitButton({
    required this.label,
    required this.onPressed,
    this.kind = SubmitButtonKind.filled,
    this.busy = false,
    this.icon,
    super.key,
  });

  /// Button text.
  final String label;

  /// The action; the button stays disabled until the returned future ends.
  final Future<void> Function()? onPressed;

  /// Visual weight.
  final SubmitButtonKind kind;

  /// Externally controlled busy state (e.g. an automatic submission).
  final bool busy;

  /// Optional leading icon.
  final IconData? icon;

  @override
  State<SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<SubmitButton> {
  bool _running = false;

  bool get _busy => _running || widget.busy;

  Future<void> _handlePressed() async {
    final Future<void> Function()? action = widget.onPressed;
    if (_busy || action == null) {
      return;
    }
    setState(() => _running = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final VoidCallback? onPressed = _busy || widget.onPressed == null
        ? null
        : _handlePressed;
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (_busy)
          const ExcludeSemantics(
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 20),
        if (_busy || widget.icon != null) const SizedBox(width: Insets.sm),
        Flexible(child: Text(widget.label, textAlign: TextAlign.center)),
      ],
    );
    const ButtonStyle full = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size.fromHeight(48)),
    );
    // Material buttons already expose button/enabled semantics.
    return switch (widget.kind) {
      SubmitButtonKind.filled => FilledButton(
        onPressed: onPressed,
        style: full,
        child: content,
      ),
      SubmitButtonKind.outlined => OutlinedButton(
        onPressed: onPressed,
        style: full,
        child: content,
      ),
      SubmitButtonKind.destructive => FilledButton(
        onPressed: onPressed,
        style: full.merge(
          FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
        ),
        child: content,
      ),
    };
  }
}
