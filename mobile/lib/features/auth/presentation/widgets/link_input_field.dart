import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/features/auth/domain/auth_link.dart';

/// Field for pasting an emailed link, with a "paste from clipboard" button.
///
/// Validates that the link is a Montra link of the [expected] kind. The
/// clipboard is only read when the user taps the paste button.
class LinkInputField extends StatelessWidget {
  /// Creates the field.
  const LinkInputField({
    required this.controller,
    required this.expected,
    this.errorText,
    this.onSubmitted,
    super.key,
  });

  /// Text controller.
  final TextEditingController controller;

  /// The link kind this screen handles.
  final AuthLinkKind expected;

  /// Server-side error.
  final String? errorText;

  /// Called on the keyboard action.
  final ValueChanged<String>? onSubmitted;

  /// Validates a pasted link for [expected].
  static String? validate(
    AppLocalizations l10n,
    AuthLinkKind expected,
    String? value,
  ) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return l10n.validationLinkRequired;
    }
    final AuthLink? link = AuthLinks.parse(text);
    if (link == null) {
      return l10n.validationLinkInvalid;
    }
    if (link.kind != expected) {
      return link.kind == AuthLinkKind.resetPassword
          ? l10n.validationLinkIsReset
          : l10n.validationLinkIsVerify;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      minLines: 1,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: l10n.pasteLinkLabel,
        errorText: errorText,
        suffixIcon: IconButton(
          tooltip: l10n.pasteFromClipboard,
          icon: const Icon(Icons.content_paste),
          onPressed: () async {
            final ClipboardData? data = await Clipboard.getData(
              Clipboard.kTextPlain,
            );
            final String? text = data?.text;
            if (text != null) {
              controller.text = text.trim();
            }
          },
        ),
      ),
      validator: (String? v) => validate(l10n, expected, v),
      onFieldSubmitted: onSubmitted,
    );
  }
}
