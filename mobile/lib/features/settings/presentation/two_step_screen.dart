import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/secure_window.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/core/widgets/text_fields.dart';
import 'package:montra_mobile/features/settings/data/account_security_api.dart';
import 'package:montra_mobile/features/settings/presentation/reauth_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum _View { overview, setup, recoveryCodes, disable }

/// Settings → Security → Two-step verification (TOTP).
///
/// Setup: re-authenticate if asked → scan the QR code / open the
/// `otpauth://` link / copy the key → confirm a code → save the recovery
/// codes, which are shown exactly once. Also regenerates codes and turns the
/// feature off. Secrets are displayed under [SecureWindow].
class TwoStepScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const TwoStepScreen({super.key});

  @override
  ConsumerState<TwoStepScreen> createState() => _TwoStepScreenState();
}

class _TwoStepScreenState extends ConsumerState<TwoStepScreen> {
  final GlobalKey<FormState> _activateForm = GlobalKey<FormState>();
  final GlobalKey<FormState> _disableForm = GlobalKey<FormState>();
  final TextEditingController _activationCode = TextEditingController();
  final TextEditingController _disableCode = TextEditingController();
  final TextEditingController _disableRecovery = TextEditingController();

  _View _view = _View.overview;
  MfaSetup? _setup;
  List<String> _codes = const <String>[];
  bool _codesSaved = false;
  bool _disableWithRecovery = false;
  ServerFormErrors _errors = ServerFormErrors.none;

  AccountSecurityApi get _api => ref.read(accountSecurityApiProvider);

  @override
  void dispose() {
    _activationCode.dispose();
    _disableCode.dispose();
    _disableRecovery.dispose();
    super.dispose();
  }

  Future<void> _refreshAccountQuietly() async {
    try {
      await ref.read(authControllerProvider.notifier).refreshAccount();
    } on ApiException {
      // The profile refreshes again on the next visit.
    }
  }

  void _setError(Object error, {Map<String, String> fields = const {}}) {
    setState(
      () => _errors = ServerFormErrors.from(
        context.l10n,
        error,
        fieldMap: fields,
      ),
    );
  }

  Future<void> _startSetup() async {
    setState(() => _errors = ServerFormErrors.none);
    try {
      final MfaSetup? setup = await runWithReauth<MfaSetup>(
        context,
        _api.startTotpSetup,
      );
      if (!mounted || setup == null) {
        return;
      }
      _activationCode.clear();
      setState(() {
        _setup = setup;
        _view = _View.setup;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.conflict) {
        unawaited(_refreshAccountQuietly());
      }
      _setError(error);
    }
  }

  Future<void> _openAuthenticator(String otpauthUri) async {
    final AppLocalizations l10n = context.l10n;
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(otpauthUri),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      opened = false;
    }
    if (!opened && mounted) {
      showSnack(context, l10n.twoStepNoApp);
    }
  }

  Future<void> _activate() async {
    setState(() => _errors = ServerFormErrors.none);
    if (!(_activateForm.currentState?.validate() ?? false)) {
      return;
    }
    try {
      final List<String> codes = await _api.activateTotp(
        _activationCode.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _codes = codes;
        _codesSaved = false;
        _setup = null;
        _view = _View.recoveryCodes;
      });
      unawaited(_refreshAccountQuietly());
    } on ApiException catch (error) {
      if (mounted) {
        _setError(error, fields: const <String, String>{'code': 'code'});
      }
    }
  }

  Future<void> _regenerate() async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.twoStepRegenerateConfirmTitle,
      body: l10n.twoStepRegenerateConfirmBody,
      confirmLabel: l10n.twoStepRegenerateConfirm,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _errors = ServerFormErrors.none);
    try {
      final List<String>? codes = await runWithReauth<List<String>>(
        context,
        _api.regenerateRecoveryCodes,
      );
      if (!mounted || codes == null) {
        return;
      }
      setState(() {
        _codes = codes;
        _codesSaved = false;
        _view = _View.recoveryCodes;
      });
    } on ApiException catch (error) {
      if (mounted) {
        _setError(error);
      }
    }
  }

  Future<void> _disable() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_disableForm.currentState?.validate() ?? false)) {
      return;
    }
    final String? code = _disableWithRecovery ? null : _disableCode.text.trim();
    final String? recovery = _disableWithRecovery
        ? _disableRecovery.text.trim()
        : null;
    try {
      final bool? done = await runWithReauth<bool>(context, () async {
        await _api.disableTotp(code: code, recoveryCode: recovery);
        return true;
      });
      if (!mounted || done != true) {
        return;
      }
      await _refreshAccountQuietly();
      if (!mounted) {
        return;
      }
      _disableCode.clear();
      _disableRecovery.clear();
      setState(() => _view = _View.overview);
      showSnack(context, l10n.twoStepDisabledNotice);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.mfaRequired) {
        // TOTP replay protection rejects a code that was just used for
        // re-authentication, so explain that a fresh code is needed.
        setState(
          () => _errors = ServerFormErrors(
            fields: <String, String>{
              _disableWithRecovery
                  ? 'recoveryCode'
                  : 'code': _disableWithRecovery
                  ? l10n.reauthCodeInvalid
                  : l10n.twoStepDisableCodeRejected,
            },
          ),
        );
        return;
      }
      _setError(
        error,
        fields: const <String, String>{
          'code': 'code',
          'recovery_code': 'recoveryCode',
        },
      );
    }
  }

  void _finishRecoveryCodes() {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _codes = const <String>[];
      _codesSaved = false;
      _view = _View.overview;
    });
    final AuthState auth = ref.read(authControllerProvider);
    if (auth is SignedIn && auth.user.mfaEnabled) {
      showSnack(context, l10n.twoStepEnabledNotice);
    }
  }

  Future<void> _confirmLeaveCodes() async {
    final AppLocalizations l10n = context.l10n;
    final bool leave = await showConfirmDialog(
      context,
      title: l10n.recoveryCodesLeaveTitle,
      body: l10n.recoveryCodesLeaveBody,
      confirmLabel: l10n.recoveryCodesLeave,
    );
    if (!leave || !mounted) {
      return;
    }
    setState(() {
      _codes = const <String>[];
      _view = _View.overview;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.canPop()) {
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AuthState auth = ref.watch(authControllerProvider);
    final bool enabled = auth is SignedIn && auth.user.mfaEnabled;
    final bool protectCodes = _view == _View.recoveryCodes && !_codesSaved;
    final List<Widget> content = switch (_view) {
      _View.overview => _overview(l10n, enabled),
      _View.setup => _setupView(l10n, _setup!),
      _View.recoveryCodes => _recoveryCodesView(l10n),
      _View.disable => _disableView(l10n),
    };
    final Widget body = ScrollableContent(
      children: <Widget>[
        if (_errors.general != null) ...<Widget>[
          NoticeBanner(
            tone: NoticeTone.error,
            message: _errors.general!,
            requestId: _errors.requestId,
          ),
          const SizedBox(height: Insets.md),
        ],
        ...content,
      ],
    );
    return PopScope(
      canPop: !protectCodes,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && protectCodes) {
          unawaited(_confirmLeaveCodes());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.twoStepTitle)),
        body: _view == _View.setup || _view == _View.recoveryCodes
            ? SecureWindow(child: body)
            : body,
      ),
    );
  }

  List<Widget> _overview(AppLocalizations l10n, bool enabled) {
    final String status = enabled ? l10n.statusOn : l10n.statusOff;
    return <Widget>[
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: StatusLabel(
          text: status,
          tone: enabled ? StatusTone.positive : StatusTone.neutral,
          semanticsLabel: l10n.twoStepStatus(status),
        ),
      ),
      const SizedBox(height: Insets.md),
      Text(
        enabled ? l10n.twoStepEnabledBody : l10n.twoStepIntro,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: Insets.lg),
      if (!enabled)
        SubmitButton(
          icon: Icons.qr_code_2,
          label: l10n.twoStepSetupButton,
          onPressed: _startSetup,
        )
      else ...<Widget>[
        SubmitButton(
          kind: SubmitButtonKind.outlined,
          icon: Icons.key_outlined,
          label: l10n.twoStepRegenerate,
          onPressed: _regenerate,
        ),
        const SizedBox(height: Insets.sm),
        SubmitButton(
          kind: SubmitButtonKind.destructive,
          label: l10n.twoStepDisable,
          onPressed: () async => setState(() {
            _errors = ServerFormErrors.none;
            _view = _View.disable;
          }),
        ),
      ],
    ];
  }

  List<Widget> _setupView(AppLocalizations l10n, MfaSetup setup) {
    final ThemeData theme = Theme.of(context);
    final String grouped = setup.secret
        .replaceAllMapped(RegExp('.{4}'), (Match m) => '${m.group(0)} ')
        .trim();
    return <Widget>[
      SectionHeading(l10n.twoStepScanTitle),
      const SizedBox(height: Insets.xs),
      Text(l10n.twoStepScanBody),
      const SizedBox(height: Insets.md),
      Center(
        // Scanners need dark modules on a light background in both themes.
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: setup.otpauthUri,
            size: 220,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
            semanticsLabel: l10n.twoStepQrSemantics,
          ),
        ),
      ),
      const SizedBox(height: Insets.md),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: () => _openAuthenticator(setup.otpauthUri),
        icon: const Icon(Icons.open_in_new),
        label: Text(l10n.twoStepOpenApp),
      ),
      const SizedBox(height: Insets.lg),
      SectionHeading(l10n.twoStepManualTitle),
      const SizedBox(height: Insets.sm),
      SelectableText(
        grouped,
        style: theme.textTheme.titleMedium?.copyWith(
          fontFamily: 'monospace',
          letterSpacing: 1.2,
        ),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: setup.secret));
            if (mounted) {
              showSnack(context, l10n.copiedToClipboard);
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: Text(l10n.twoStepCopyKey),
        ),
      ),
      const SizedBox(height: Insets.lg),
      SectionHeading(l10n.twoStepVerifyTitle),
      const SizedBox(height: Insets.sm),
      Form(
        key: _activateForm,
        child: OtpCodeField(
          controller: _activationCode,
          label: l10n.mfaCodeLabel,
          errorText: _errors['code'],
          onFieldSubmitted: (_) => _activate(),
        ),
      ),
      const SizedBox(height: Insets.lg),
      SubmitButton(label: l10n.twoStepActivateButton, onPressed: _activate),
      const SizedBox(height: Insets.sm),
      TextButton(
        onPressed: () => setState(() {
          _setup = null;
          _errors = ServerFormErrors.none;
          _view = _View.overview;
        }),
        child: Text(l10n.twoStepCancelSetup),
      ),
    ];
  }

  List<Widget> _recoveryCodesView(AppLocalizations l10n) {
    final ThemeData theme = Theme.of(context);
    return <Widget>[
      NoticeBanner(
        tone: NoticeTone.warning,
        title: l10n.recoveryCodesTitle,
        message: l10n.recoveryCodesBody,
      ),
      const SizedBox(height: Insets.md),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Semantics(
            label: l10n.recoveryCodesListLabel,
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String code in _codes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                    child: SelectableText(
                      code,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: Insets.md),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: _codes.join('\n')));
          if (mounted) {
            showSnack(context, l10n.recoveryCodesCopied);
          }
        },
        icon: const Icon(Icons.copy_all_outlined),
        label: Text(l10n.recoveryCodesCopy),
      ),
      const SizedBox(height: Insets.sm),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _codesSaved,
        title: Text(l10n.recoveryCodesConfirm),
        onChanged: (bool? v) => setState(() => _codesSaved = v ?? false),
      ),
      const SizedBox(height: Insets.sm),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _codesSaved ? _finishRecoveryCodes : null,
        child: Text(l10n.actionDone),
      ),
    ];
  }

  List<Widget> _disableView(AppLocalizations l10n) => <Widget>[
    Text(l10n.twoStepDisableBody, style: Theme.of(context).textTheme.bodyLarge),
    const SizedBox(height: Insets.md),
    Form(
      key: _disableForm,
      child: _disableWithRecovery
          ? TextFormField(
              controller: _disableRecovery,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              maxLength: DisableMfaBody.recoveryCodeMaxLength,
              decoration: InputDecoration(
                labelText: l10n.mfaRecoveryLabel,
                errorText: _errors['recoveryCode'],
                counterText: '',
              ),
              validator: (String? v) => (v ?? '').trim().isEmpty
                  ? l10n.validationRecoveryRequired
                  : null,
              onFieldSubmitted: (_) => _disable(),
            )
          : OtpCodeField(
              controller: _disableCode,
              label: l10n.mfaCodeLabel,
              errorText: _errors['code'],
              onFieldSubmitted: (_) => _disable(),
            ),
    ),
    TextButton(
      onPressed: () => setState(() {
        _disableWithRecovery = !_disableWithRecovery;
        _errors = ServerFormErrors.none;
      }),
      child: Text(_disableWithRecovery ? l10n.mfaUseCode : l10n.mfaUseRecovery),
    ),
    const SizedBox(height: Insets.md),
    SubmitButton(
      kind: SubmitButtonKind.destructive,
      label: l10n.twoStepDisableConfirm,
      onPressed: _disable,
    ),
    const SizedBox(height: Insets.sm),
    TextButton(
      onPressed: () => setState(() {
        _errors = ServerFormErrors.none;
        _view = _View.overview;
      }),
      child: Text(l10n.actionCancel),
    ),
  ];
}
