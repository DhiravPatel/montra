import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';

/// Asks the user to confirm an action. Returns true only on confirmation.
///
/// Destructive actions use error colors on the confirm button; the cancel
/// button is always offered and is the default when the dialog is dismissed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ColorScheme scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.actionCancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Shows a short message in the nearest [ScaffoldMessenger].
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
