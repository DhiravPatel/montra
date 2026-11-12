import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_error_code.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/countdown.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/core/widgets/text_fields.dart';
import 'package:montra_mobile/features/auth/domain/auth_link.dart';
import 'package:montra_mobile/features/auth/domain/password_policy.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/link_input_field.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/password_requirements.dart';

enum _Phase { needLink, form, done, expired }

/// Sets a new password from `/reset-password#token=...` (deep link) or a
/// pasted link. A successful reset signs out every device, including this
/// one if it was signed in.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [initialToken] comes from the deep link.
  const ResetPasswordScreen({this.initialToken, super.key});

  /// Token from the opened link, if any.
  final String? initialToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with CountdownMixin<ResetPasswordScreen> {
  final GlobalKey<FormState> _linkForm = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordForm = GlobalKey<FormState>();
  final TextEditingController _link = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  _Phase _phase = _Phase.needLink;
  String? _token;
  ServerFormErrors _errors = ServerFormErrors.none;

  /// The server names `body.new_password` here; `body.password` (used by
  /// older servers) is still accepted so the mapping stays tolerant.
  static const Map<String, String> _fields = <String, String>{
    'new_password': 'password',
    'password': 'password',
  };

  @override
  void initState() {
    super.initState();
    final String? token = widget.initialToken;
    if (token != null && AuthLinks.isPlausibleToken(token)) {
      _token = token;
      _phase = _Phase.form;
    }
  }

  @override
  void dispose() {
    _link.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _useLink() {
    if (!(_linkForm.currentState?.validate() ?? false)) {
      return;
    }
    final AuthLink? link = AuthLinks.parse(_link.text);
    if (link != null) {
      setState(() {
        _token = link.token;
        _phase = _Phase.form;
        _errors = ServerFormErrors.none;
      });
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final String? token = _token;
    setState(() => _errors = ServerFormErrors.none);
    if (token == null || !(_passwordForm.currentState?.validate() ?? false)) {
      return;
    }
    try {
      await ref
          .read(authApiProvider)
          .resetPassword(token: token, newPassword: _password.text);
      if (!mounted) {
        return;
      }
      TextInput.finishAutofillContext();
      // Every session was revoked server-side, including this device's.
      if (ref.read(authControllerProvider) is SignedIn) {
        await ref
            .read(authControllerProvider.notifier)
            .endLocalSession(SessionEndReason.passwordReset);
      }
      if (mounted) {
        setState(() => _phase = _Phase.done);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.gone ||
          error.bodyFieldErrors.containsKey('token')) {
        setState(() => _phase = _Phase.expired);
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
    final List<Widget> children = switch (_phase) {
      _Phase.done => <Widget>[
        NoticeBanner(
          tone: NoticeTone.success,
          title: l10n.resetSuccessTitle,
          message: l10n.resetSuccessBody,
        ),
        const SizedBox(height: Insets.lg),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => context.go(AppRoutes.signIn),
          child: Text(l10n.signInButton),
        ),
      ],
      _Phase.expired => <Widget>[
        NoticeBanner(tone: NoticeTone.warning, message: l10n.resetExpired),
        const SizedBox(height: Insets.lg),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => context.go(AppRoutes.forgotPassword),
          child: Text(l10n.requestNewLink),
        ),
      ],
      _Phase.needLink => <Widget>[
        Text(l10n.resetPasteBody, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: Insets.md),
        Form(
          key: _linkForm,
          child: LinkInputField(
            controller: _link,
            expected: AuthLinkKind.resetPassword,
            onSubmitted: (_) => _useLink(),
          ),
        ),
        const SizedBox(height: Insets.md),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _useLink,
          child: Text(l10n.actionContinue),
        ),
      ],
      _Phase.form => <Widget>[
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
            key: _passwordForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PasswordField(
                  controller: _password,
                  label: l10n.newPasswordLabel,
                  errorText: _errors['password'],
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  maxLength: PasswordPolicy.maxLength,
                  validator: (String? v) => PasswordPolicy.validate(l10n, v),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Insets.sm),
                PasswordRequirements(password: _password.text),
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
                    return v == _password.text
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
              : l10n.resetButton,
          onPressed: isCountingDown ? null : _submit,
        ),
      ],
    };
    return AuthScaffold(title: l10n.resetTitle, children: children);
  }
}
