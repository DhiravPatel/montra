import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
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

/// Runs [action]; if the server answers `REAUTH_REQUIRED`, asks the user to
/// confirm their password (and TOTP code) and retries once.
///
/// Returns null when the user dismissed the prompt. Other errors propagate.
Future<T?> runWithReauth<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } on ApiException catch (error) {
    if (error.code != ErrorObjectCode.reauthRequired || !context.mounted) {
      rethrow;
    }
    final bool confirmed = await ReauthSheet.show(context);
    if (!confirmed) {
      return null;
    }
    return action();
  }
}

/// Bottom sheet for `POST /auth/reauthenticate`.
///
/// Asks for the password and, when two-step verification is on, an
/// authenticator code or — for users who lost their authenticator — one of
/// their single-use recovery codes.
class ReauthSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ReauthSheet({super.key});

  /// Widget keys used by tests and UI automation.
  static const Key passwordKey = Key('reauth.password');
  static const Key codeKey = Key('reauth.code');
  static const Key recoveryCodeKey = Key('reauth.recoveryCode');
  static const Key submitKey = Key('reauth.submit');

  /// Shows the sheet; resolves to true when re-authentication succeeded.
  static Future<bool> show(BuildContext context) async {
    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => const ReauthSheet(),
    );
    return ok ?? false;
  }

  @override
  ConsumerState<ReauthSheet> createState() => _ReauthSheetState();
}

class _ReauthSheetState extends ConsumerState<ReauthSheet>
    with CountdownMixin<ReauthSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _recoveryCode = TextEditingController();
  late bool _needsCode;
  bool _useRecoveryCode = false;
  ServerFormErrors _errors = ServerFormErrors.none;

  @override
  void initState() {
    super.initState();
    _needsCode =
        ref.read(authControllerProvider.notifier).currentUser?.mfaEnabled ??
        false;
  }

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    _recoveryCode.dispose();
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
          .read(authApiProvider)
          .reauthenticate(
            password: _password.text,
            code: _needsCode && !_useRecoveryCode ? _code.text.trim() : null,
            recoveryCode: _needsCode && _useRecoveryCode
                ? _recoveryCode.text.trim()
                : null,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.reauthRequired) {
        setState(
          () => _errors = ServerFormErrors(
            fields: <String, String>{'password': l10n.reauthWrongPassword},
          ),
        );
        return;
      }
      if (error.code == ErrorObjectCode.mfaRequired) {
        // A code (or recovery code) is missing or wrong. Also reveals the
        // field when the cached profile did not know two-step was on.
        setState(() {
          _needsCode = true;
          _errors = ServerFormErrors(
            fields: <String, String>{
              if (_useRecoveryCode)
                'recoveryCode': l10n.reauthRecoveryInvalid
              else
                'code': l10n.reauthCodeInvalid,
            },
          );
        });
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
          fieldMap: const <String, String>{
            'password': 'password',
            'code': 'code',
            'recovery_code': 'recoveryCode',
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.reauthTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                !_needsCode
                    ? l10n.reauthBody
                    : _useRecoveryCode
                    ? l10n.reauthBodyWithRecovery
                    : l10n.reauthBodyWithCode,
              ),
              const SizedBox(height: Insets.md),
              if (_errors.general != null) ...<Widget>[
                NoticeBanner(
                  tone: NoticeTone.error,
                  message: _errors.general!,
                  requestId: _errors.requestId,
                ),
                const SizedBox(height: Insets.md),
              ],
              PasswordField(
                key: ReauthSheet.passwordKey,
                controller: _password,
                label: l10n.passwordLabel,
                autofocus: true,
                errorText: _errors['password'],
                maxLength: ReauthBody.passwordMaxLength,
                textInputAction: _needsCode
                    ? TextInputAction.next
                    : TextInputAction.done,
                validator: (String? v) =>
                    (v ?? '').isEmpty ? l10n.validationPasswordRequired : null,
                onFieldSubmitted: _needsCode ? null : (_) => _submit(),
              ),
              if (_needsCode) ...<Widget>[
                const SizedBox(height: Insets.md),
                if (_useRecoveryCode)
                  TextFormField(
                    key: ReauthSheet.recoveryCodeKey,
                    controller: _recoveryCode,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    maxLength: ReauthBody.recoveryCodeMaxLength,
                    decoration: InputDecoration(
                      labelText: l10n.mfaRecoveryLabel,
                      errorText: _errors['recoveryCode'],
                      counterText: '',
                    ),
                    validator: (String? v) => (v ?? '').trim().isEmpty
                        ? l10n.validationRecoveryRequired
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  )
                else
                  OtpCodeField(
                    key: ReauthSheet.codeKey,
                    controller: _code,
                    label: l10n.mfaCodeLabel,
                    errorText: _errors['code'],
                    onFieldSubmitted: (_) => _submit(),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _useRecoveryCode = !_useRecoveryCode;
                      _errors = ServerFormErrors.none;
                    }),
                    child: Text(
                      _useRecoveryCode ? l10n.mfaUseCode : l10n.mfaUseRecovery,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Insets.lg),
              SubmitButton(
                key: ReauthSheet.submitKey,
                label: isCountingDown
                    ? l10n.retryIn(formatWaitShort(l10n, countdownSeconds))
                    : l10n.reauthButton,
                onPressed: isCountingDown ? null : _submit,
              ),
              const SizedBox(height: Insets.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
