import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/countdown.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/core/widgets/text_fields.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/resend_verification_button.dart';

/// Email + password sign-in, followed by a two-step verification step when
/// the account requires it (`status: mfa_required`).
///
/// Successful sign-in updates the auth state; the router then leaves this
/// screen, so it never navigates on success itself.
class SignInScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  /// Widget keys used by tests and UI automation.
  static const Key emailKey = Key('signIn.email');
  static const Key passwordKey = Key('signIn.password');
  static const Key submitKey = Key('signIn.submit');
  static const Key codeKey = Key('signIn.mfaCode');
  static const Key recoveryCodeKey = Key('signIn.recoveryCode');
  static const Key verifyKey = Key('signIn.mfaVerify');

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with CountdownMixin<SignInScreen> {
  final GlobalKey<FormState> _credentialsForm = GlobalKey<FormState>();
  final GlobalKey<FormState> _mfaForm = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _recoveryCode = TextEditingController();

  String? _mfaToken;
  String? _stepNotice;
  bool _useRecoveryCode = false;
  bool _emailNotVerified = false;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _credentialFields = <String, String>{
    'email': 'email',
    'password': 'password',
  };
  static const Map<String, String> _mfaFields = <String, String>{
    'code': 'code',
    'recovery_code': 'recoveryCode',
  };

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _recoveryCode.dispose();
    super.dispose();
  }

  Future<void> _submitCredentials() async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _errors = ServerFormErrors.none;
      _emailNotVerified = false;
      _stepNotice = null;
    });
    if (!(_credentialsForm.currentState?.validate() ?? false)) {
      return;
    }
    try {
      final SignInOutcome outcome = await ref
          .read(authControllerProvider.notifier)
          .signIn(email: _email.text.trim(), password: _password.text);
      if (!mounted) {
        return;
      }
      switch (outcome) {
        case SignInNeedsMfa(:final String mfaToken):
          _password.clear();
          setState(() {
            _mfaToken = mfaToken;
            _useRecoveryCode = false;
          });
        case SignInCompleted():
          TextInput.finishAutofillContext();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showError(
        l10n,
        error,
        _credentialFields,
        (ApiException e) => switch (e.code) {
          // On this form UNAUTHENTICATED means wrong email or password.
          ErrorObjectCode.unauthenticated => l10n.signInInvalidCredentials,
          _ => describeError(l10n, e),
        },
      );
    }
  }

  Future<void> _submitMfa() async {
    final AppLocalizations l10n = context.l10n;
    final String? token = _mfaToken;
    if (token == null) {
      return;
    }
    setState(() => _errors = ServerFormErrors.none);
    if (!(_mfaForm.currentState?.validate() ?? false)) {
      return;
    }
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyMfa(
            mfaToken: token,
            code: _useRecoveryCode ? null : _code.text.trim(),
            recoveryCode: _useRecoveryCode ? _recoveryCode.text.trim() : null,
          );
      if (mounted) {
        TextInput.finishAutofillContext();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      switch (error.code) {
        case ErrorObjectCode.mfaCodeInvalid:
          // Wrong code: the same challenge (mfa_token) can be retried.
          _code.clear();
          _recoveryCode.clear();
          setState(
            () => _errors = ServerFormErrors(
              fields: <String, String>{
                if (_useRecoveryCode)
                  'recoveryCode': l10n.mfaRecoveryCodeInvalid
                else
                  'code': l10n.mfaCodeInvalid,
              },
            ),
          );
        case ErrorObjectCode.mfaChallengeExpired:
          // The attempt expired or its attempts are used up: sign in again.
          _restartSignIn(notice: l10n.mfaChallengeExpired);
        default:
          _showError(
            l10n,
            error,
            _mfaFields,
            (ApiException e) => describeError(l10n, e),
          );
      }
    }
  }

  void _showError(
    AppLocalizations l10n,
    ApiException error,
    Map<String, String> fields,
    String Function(ApiException error) general,
  ) {
    if (error.code == ErrorObjectCode.emailNotVerified) {
      setState(() => _emailNotVerified = true);
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
        fieldMap: fields,
        generalMessage: general,
      ),
    );
  }

  /// Leaves the second step. [notice] explains why when the server ended
  /// the attempt; the email stays filled in.
  void _restartSignIn({String? notice}) {
    _code.clear();
    _recoveryCode.clear();
    _password.clear();
    setState(() {
      _mfaToken = null;
      _stepNotice = notice;
      _errors = ServerFormErrors.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AuthState auth = ref.watch(authControllerProvider);
    final String? notice = auth is SignedOut
        ? switch (auth.reason) {
            SessionEndReason.expired => l10n.sessionExpiredNotice,
            SessionEndReason.signedOutEverywhere =>
              l10n.signedOutEverywhereNotice,
            SessionEndReason.passwordReset => l10n.passwordResetNotice,
            SessionEndReason.signedOut || null => null,
          }
        : null;
    final bool mfaStep = _mfaToken != null;
    return AuthScaffold(
      title: mfaStep ? l10n.mfaTitle : l10n.signInTitle,
      children: mfaStep ? _mfaStep(l10n) : _credentialsStep(l10n, notice),
    );
  }

  List<Widget> _generalError() => <Widget>[
    if (_errors.general != null) ...<Widget>[
      NoticeBanner(
        tone: NoticeTone.error,
        message: _errors.general!,
        requestId: _errors.requestId,
      ),
      const SizedBox(height: Insets.md),
    ],
  ];

  List<Widget> _credentialsStep(
    AppLocalizations l10n,
    String? notice,
  ) => <Widget>[
    if (notice != null) ...<Widget>[
      NoticeBanner(message: notice),
      const SizedBox(height: Insets.md),
    ],
    if (_stepNotice != null) ...<Widget>[
      NoticeBanner(tone: NoticeTone.warning, message: _stepNotice!),
      const SizedBox(height: Insets.md),
    ],
    ..._generalError(),
    if (_emailNotVerified) ...<Widget>[
      NoticeBanner(
        tone: NoticeTone.warning,
        title: l10n.signInEmailNotVerifiedTitle,
        message: l10n.signInEmailNotVerifiedBody,
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ResendVerificationButton(email: () => _email.text.trim()),
            TextButton(
              onPressed: () => context.push(AppRoutes.verifyEmail),
              child: Text(l10n.haveLinkButton),
            ),
          ],
        ),
      ),
      const SizedBox(height: Insets.md),
    ],
    AutofillGroup(
      child: Form(
        key: _credentialsForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            EmailField(
              key: SignInScreen.emailKey,
              controller: _email,
              errorText: _errors['email'],
              maxLength: LoginBody.emailMaxLength,
            ),
            const SizedBox(height: Insets.md),
            PasswordField(
              key: SignInScreen.passwordKey,
              controller: _password,
              label: l10n.passwordLabel,
              errorText: _errors['password'],
              maxLength: LoginBody.passwordMaxLength,
              validator: (String? v) =>
                  (v ?? '').isEmpty ? l10n.validationPasswordRequired : null,
              onFieldSubmitted: (_) => _submitCredentials(),
            ),
          ],
        ),
      ),
    ),
    Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton(
        onPressed: () => context.push(AppRoutes.forgotPassword),
        child: Text(l10n.forgotPasswordLink),
      ),
    ),
    const SizedBox(height: Insets.sm),
    SubmitButton(
      key: SignInScreen.submitKey,
      label: isCountingDown
          ? l10n.retryIn(formatWaitShort(l10n, countdownSeconds))
          : l10n.signInButton,
      onPressed: isCountingDown ? null : _submitCredentials,
    ),
    const SizedBox(height: Insets.lg),
    Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(l10n.noAccountPrompt),
        TextButton(
          onPressed: () => context.push(AppRoutes.signUp),
          child: Text(l10n.createAccountLink),
        ),
      ],
    ),
    Center(
      child: TextButton(
        onPressed: () => context.push(AppRoutes.contact),
        child: Text(l10n.contactEntry),
      ),
    ),
  ];

  List<Widget> _mfaStep(AppLocalizations l10n) => <Widget>[
    ..._generalError(),
    Text(
      _useRecoveryCode ? l10n.mfaRecoveryBody : l10n.mfaBody,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    const SizedBox(height: Insets.lg),
    Form(
      key: _mfaForm,
      child: _useRecoveryCode
          ? TextFormField(
              key: SignInScreen.recoveryCodeKey,
              controller: _recoveryCode,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              maxLength: MfaVerifyBody.recoveryCodeMaxLength,
              decoration: InputDecoration(
                labelText: l10n.mfaRecoveryLabel,
                errorText: _errors['recoveryCode'],
                counterText: '',
              ),
              validator: (String? v) => (v ?? '').trim().isEmpty
                  ? l10n.validationRecoveryRequired
                  : null,
              onFieldSubmitted: (_) => _submitMfa(),
            )
          : OtpCodeField(
              key: SignInScreen.codeKey,
              controller: _code,
              label: l10n.mfaCodeLabel,
              errorText: _errors['code'],
              autofocus: true,
              onFieldSubmitted: (_) => _submitMfa(),
            ),
    ),
    const SizedBox(height: Insets.lg),
    SubmitButton(
      key: SignInScreen.verifyKey,
      label: isCountingDown
          ? l10n.retryIn(formatWaitShort(l10n, countdownSeconds))
          : l10n.mfaVerifyButton,
      onPressed: isCountingDown ? null : _submitMfa,
    ),
    const SizedBox(height: Insets.sm),
    TextButton(
      onPressed: () => setState(() {
        _useRecoveryCode = !_useRecoveryCode;
        _errors = ServerFormErrors.none;
      }),
      child: Text(_useRecoveryCode ? l10n.mfaUseCode : l10n.mfaUseRecovery),
    ),
    TextButton(onPressed: _restartSignIn, child: Text(l10n.mfaStartOver)),
  ];
}
