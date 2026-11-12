import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/countdown.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/core/widgets/text_fields.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/auth_scaffold.dart';

/// Requests a password reset email. The response is identical whether or not
/// the account exists, and so is the confirmation shown here.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with CountdownMixin<ForgotPasswordScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  ServerFormErrors _errors = ServerFormErrors.none;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final String email = _email.text.trim();
    try {
      await ref.read(authApiProvider).forgotPassword(email);
      if (mounted) {
        setState(() => _sentTo = email);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final Duration? wait = error.retryAfter;
      if (error.isThrottled && wait != null) {
        startCountdown(wait);
      }
      setState(
        () => _errors = ServerFormErrors.from(
          l10n,
          error,
          fieldMap: const <String, String>{'email': 'email'},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? sentTo = _sentTo;
    if (sentTo != null) {
      return AuthScaffold(
        title: l10n.forgotSentTitle,
        children: <Widget>[
          NoticeBanner(
            tone: NoticeTone.success,
            message: l10n.forgotSentBody(sentTo),
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => context.push(AppRoutes.resetPassword),
            icon: const Icon(Icons.link),
            label: Text(l10n.haveLinkButton),
          ),
          const SizedBox(height: Insets.sm),
          TextButton(
            onPressed: () => context.go(AppRoutes.signIn),
            child: Text(l10n.backToSignIn),
          ),
        ],
      );
    }
    return AuthScaffold(
      title: l10n.forgotTitle,
      intro: l10n.forgotBody,
      children: <Widget>[
        if (_errors.general != null) ...<Widget>[
          NoticeBanner(
            tone: NoticeTone.error,
            message: _errors.general!,
            requestId: _errors.requestId,
          ),
          const SizedBox(height: Insets.md),
        ],
        Form(
          key: _form,
          child: EmailField(
            controller: _email,
            errorText: _errors['email'],
            maxLength: EmailBody.emailMaxLength,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: Insets.lg),
        SubmitButton(
          label: isCountingDown
              ? l10n.retryIn(formatWaitShort(l10n, countdownSeconds))
              : l10n.forgotButton,
          onPressed: isCountingDown ? null : _submit,
        ),
        const SizedBox(height: Insets.sm),
        TextButton(
          onPressed: () => context.push(AppRoutes.resetPassword),
          child: Text(l10n.haveLinkButton),
        ),
      ],
    );
  }
}
