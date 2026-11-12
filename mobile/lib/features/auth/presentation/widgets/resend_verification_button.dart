import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/countdown.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';

/// Sends `POST /auth/email/resend` for [email], then waits [cooldown]
/// (or the server's `Retry-After`) before allowing another request.
class ResendVerificationButton extends ConsumerStatefulWidget {
  /// Creates the button. [email] is read when pressed.
  const ResendVerificationButton({
    required this.email,
    this.cooldown = const Duration(seconds: 60),
    this.onInvalidEmail,
    super.key,
  });

  /// Supplies the address to resend to; return null to block the request
  /// (e.g. when a form field is invalid).
  final String? Function() email;

  /// Courtesy delay between requests.
  final Duration cooldown;

  /// Called instead of sending when [email] returns null.
  final VoidCallback? onInvalidEmail;

  @override
  ConsumerState<ResendVerificationButton> createState() =>
      _ResendVerificationButtonState();
}

class _ResendVerificationButtonState
    extends ConsumerState<ResendVerificationButton>
    with CountdownMixin<ResendVerificationButton> {
  Future<void> _resend() async {
    final AppLocalizations l10n = context.l10n;
    final String? email = widget.email();
    if (email == null || email.isEmpty) {
      widget.onInvalidEmail?.call();
      return;
    }
    try {
      await ref.read(authApiProvider).resendVerification(email);
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.resendEmailSent);
      startCountdown(widget.cooldown);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.retryAfter != null) {
        startCountdown(error.retryAfter!);
      }
      showSnack(context, describeError(l10n, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SubmitButton(
      kind: SubmitButtonKind.outlined,
      icon: Icons.forward_to_inbox_outlined,
      label: isCountingDown
          ? l10n.resendEmailCooldown(formatWaitShort(l10n, countdownSeconds))
          : l10n.resendEmailButton,
      onPressed: isCountingDown ? null : _resend,
    );
  }
}
