import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/countdown.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/core/widgets/text_fields.dart';
import 'package:montra_mobile/features/auth/domain/password_policy.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/password_requirements.dart';
import 'package:montra_mobile/features/settings/data/account_security_api.dart';

/// Settings → Security → Change password (`POST /me/password`). The server
/// signs out the user's other sessions; this device stays signed in.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen>
    with CountdownMixin<ChangePasswordScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  ServerFormErrors _errors = ServerFormErrors.none;

  /// The server names `body.new_password`; `body.password` (used by older
  /// servers) is still accepted so the mapping stays tolerant.
  static const Map<String, String> _fields = <String, String>{
    'current_password': 'current',
    'new_password': 'next',
    'password': 'next',
  };

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    try {
      await ref
          .read(accountSecurityApiProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) {
        return;
      }
      TextInput.finishAutofillContext();
      showSnack(context, l10n.changePasswordSuccess);
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final Duration? wait = error.retryAfter;
      if (error.isThrottled && wait != null) {
        startCountdown(wait);
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? email = ref
        .watch(authControllerProvider.notifier)
        .currentUser
        ?.email;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePasswordTitle)),
      body: ScrollableContent(
        children: <Widget>[
          if (_errors.general != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.error,
              message: _errors.general!,
              requestId: _errors.requestId,
            ),
            const SizedBox(height: Insets.md),
          ],
          AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  PasswordField(
                    controller: _current,
                    label: l10n.currentPasswordLabel,
                    errorText: _errors['current'],
                    textInputAction: TextInputAction.next,
                    maxLength: ChangePasswordBody.currentPasswordMaxLength,
                    validator: (String? v) => (v ?? '').isEmpty
                        ? l10n.validationPasswordRequired
                        : null,
                  ),
                  const SizedBox(height: Insets.md),
                  PasswordField(
                    controller: _next,
                    label: l10n.newPasswordLabel,
                    errorText: _errors['next'],
                    autofillHints: const <String>[AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    maxLength: PasswordPolicy.maxLength,
                    validator: (String? v) => PasswordPolicy.validate(l10n, v),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Insets.sm),
                  PasswordRequirements(password: _next.text, email: email),
                  const SizedBox(height: Insets.md),
                  PasswordField(
                    controller: _confirm,
                    label: l10n.confirmPasswordLabel,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    maxLength: PasswordPolicy.maxLength,
                    validator: (String? v) {
                      if ((v ?? '').isEmpty) {
                        return l10n.validationConfirmPasswordRequired;
                      }
                      return v == _next.text
                          ? null
                          : l10n.validationPasswordsDontMatch;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            label: isCountingDown
                ? l10n.retryIn(formatWaitShort(l10n, countdownSeconds))
                : l10n.changePasswordButton,
            onPressed: isCountingDown ? null : _submit,
          ),
        ],
      ),
    );
  }
}
