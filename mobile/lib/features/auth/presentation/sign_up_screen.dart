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
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/formatting/currencies.dart';
import 'package:montra_mobile/core/formatting/currency_catalog.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/checkbox_form_field.dart';
import 'package:montra_mobile/core/widgets/countdown.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/core/widgets/text_fields.dart';
import 'package:montra_mobile/features/auth/domain/device_profile.dart';
import 'package:montra_mobile/features/auth/domain/password_policy.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/password_requirements.dart';
import 'package:url_launcher/url_launcher.dart';

/// Account registration. `POST /auth/register` always answers 202 (even for
/// an existing email), so success always leads to the check-email screen.
class SignUpScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SignUpScreen({this.next, super.key});

  /// Where to go after signing in later (a safe in-app path), kept on the
  /// way to the check-email and sign-in screens.
  final String? next;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with CountdownMixin<SignUpScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  String? _chosenCurrency;
  String? _currencyError;
  bool _acceptTerms = false;
  bool _confirmAdult = false;
  bool _registrationClosed = false;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'email': 'email',
    'password': 'password',
    'display_name': 'displayName',
    'accept_terms': 'terms',
    'terms_version': 'terms',
    'privacy_version': 'terms',
    'confirm_adult': 'adult',
    'currency': 'currency',
    'locale': 'device',
    'timezone': 'device',
    'country': 'device',
  };

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// The user's choice, or the device suggestion. When the live catalog is
  /// loaded the suggestion must be selectable there (a retired currency is
  /// swapped for its replacement); otherwise the server validates it.
  String? _currencyFor(DeviceProfile? device) {
    final String? chosen = _chosenCurrency;
    if (chosen != null) {
      return chosen;
    }
    final String? suggested = device?.suggestedCurrency;
    final CurrencyCatalog? catalog = ref.read(currencyCatalogProvider).value;
    return catalog == null ? suggested : catalog.selectableFor(suggested);
  }

  Future<void> _pickCurrency(String? current) async {
    final String? picked = await showCurrencyPicker(context, selected: current);
    if (picked != null && mounted) {
      setState(() {
        _chosenCurrency = picked;
        _currencyError = null;
      });
    }
  }

  Future<void> _openDocument(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final DeviceProfile device =
        ref.read(deviceProfileProvider).value ?? const DeviceProfile();
    final String? currency = _currencyFor(device);
    setState(() {
      _errors = ServerFormErrors.none;
      _currencyError = currency == null
          ? l10n.validationCurrencyRequired
          : null;
    });
    final bool valid = _form.currentState?.validate() ?? false;
    if (!valid || currency == null) {
      return;
    }
    final String email = _email.text.trim();
    try {
      await ref
          .read(authApiProvider)
          .register(
            RegisterBody(
              email: email,
              password: _password.text,
              displayName: _name.text.trim(),
              acceptTerms: _acceptTerms,
              confirmAdult: _confirmAdult,
              termsVersion: AppConfig.termsVersion,
              privacyVersion: AppConfig.privacyVersion,
              locale: device.localeTag,
              timezone: device.timezone,
              currency: currency,
            ),
          );
      if (!mounted) {
        return;
      }
      TextInput.finishAutofillContext();
      context.go(
        AppRoutes.withNext(AppRoutes.checkEmail, widget.next),
        extra: email,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.forbidden) {
        setState(() => _registrationClosed = true);
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
    final ThemeData theme = Theme.of(context);
    final DeviceProfile? device = ref.watch(deviceProfileProvider).value;
    final CurrencyCatalog? catalog = ref.watch(currencyCatalogProvider).value;
    final String? currency = _currencyFor(device);
    final CurrencyDto? currencyInfo = currency == null
        ? null
        : catalog?.byCode(currency) ?? Currencies.byCode(currency);
    final AppConfig config = ref.watch(appConfigProvider);
    final String? currencyError = _currencyError ?? _errors['currency'];

    if (_registrationClosed) {
      return AuthScaffold(
        title: l10n.signUpTitle,
        children: <Widget>[
          NoticeBanner(tone: NoticeTone.warning, message: l10n.signUpClosed),
          const SizedBox(height: Insets.lg),
          OutlinedButton(
            onPressed: () =>
                context.go(AppRoutes.withNext(AppRoutes.signIn, widget.next)),
            child: Text(l10n.backToSignIn),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: l10n.signUpTitle,
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
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const <String>[AutofillHints.name],
                  maxLength: RegisterBody.displayNameMaxLength,
                  decoration: InputDecoration(
                    labelText: l10n.displayNameLabel,
                    helperText: l10n.displayNameHelp,
                    errorText: _errors['displayName'],
                    counterText: '',
                  ),
                  validator: (String? v) {
                    final String name = v?.trim() ?? '';
                    if (name.isEmpty) {
                      return l10n.validationDisplayNameRequired;
                    }
                    if (name.runes.length > RegisterBody.displayNameMaxLength) {
                      return l10n.validationDisplayNameLength(
                        RegisterBody.displayNameMaxLength,
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: Insets.md),
                EmailField(
                  controller: _email,
                  errorText: _errors['email'],
                  maxLength: RegisterBody.emailMaxLength,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Insets.md),
                PasswordField(
                  controller: _password,
                  label: l10n.passwordLabel,
                  errorText: _errors['password'],
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  maxLength: PasswordPolicy.maxLength,
                  validator: (String? v) => PasswordPolicy.validate(l10n, v),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Insets.sm),
                PasswordRequirements(
                  password: _password.text,
                  email: _email.text,
                ),
                const SizedBox(height: Insets.lg),
                _CurrencyField(
                  label: l10n.currencyLabel,
                  helper: l10n.currencyHelp,
                  value: currencyInfo == null
                      ? l10n.currencyNotChosen
                      : '${currencyInfo.code} · ${currencyInfo.name}',
                  errorText: currencyError,
                  onTap: () => _pickCurrency(currency),
                ),
                const SizedBox(height: Insets.md),
                _DeviceSettings(device: device, errorText: _errors['device']),
                const SizedBox(height: Insets.md),
                CheckboxFormField(
                  title: Text(l10n.termsCheckbox(AppConfig.termsVersion)),
                  errorText: _errors['terms'],
                  onChanged: (bool v) => _acceptTerms = v,
                  validator: (bool? v) =>
                      v ?? false ? null : l10n.validationTermsRequired,
                ),
                if (config.termsUrl != null || config.privacyUrl != null)
                  Wrap(
                    spacing: Insets.sm,
                    children: <Widget>[
                      if (config.termsUrl != null)
                        TextButton(
                          onPressed: () => _openDocument(config.termsUrl!),
                          child: Text(l10n.termsLink),
                        ),
                      if (config.privacyUrl != null)
                        TextButton(
                          onPressed: () => _openDocument(config.privacyUrl!),
                          child: Text(l10n.privacyLink),
                        ),
                    ],
                  ),
                CheckboxFormField(
                  title: Text(l10n.adultCheckbox),
                  errorText: _errors['adult'],
                  onChanged: (bool v) => _confirmAdult = v,
                  validator: (bool? v) =>
                      v ?? false ? null : l10n.validationAdultRequired,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        SubmitButton(
          label: isCountingDown
              ? l10n.retryIn(formatWaitShort(l10n, countdownSeconds))
              : l10n.signUpButton,
          onPressed: isCountingDown ? null : _submit,
        ),
        const SizedBox(height: Insets.md),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(l10n.haveAccountPrompt, style: theme.textTheme.bodyMedium),
            TextButton(
              onPressed: () =>
                  context.go(AppRoutes.withNext(AppRoutes.signIn, widget.next)),
              child: Text(l10n.signInLink),
            ),
          ],
        ),
      ],
    );
  }
}

/// Read-only field that opens the currency picker.
class _CurrencyField extends StatelessWidget {
  const _CurrencyField({
    required this.label,
    required this.helper,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String helper;
  final String value;
  final String? errorText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          errorText: errorText,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(value),
      ),
    ),
  );
}

/// Shows exactly which regional settings will be sent with the sign-up.
class _DeviceSettings extends StatelessWidget {
  const _DeviceSettings({required this.device, this.errorText});

  final DeviceProfile? device;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? timezone = device?.timezone;
    final String? locale = device?.localeTag;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.deviceSettingsTitle, style: theme.textTheme.labelLarge),
          const SizedBox(height: Insets.xs),
          Text(
            timezone == null
                ? l10n.deviceTimezoneUnknown
                : l10n.deviceTimezone(timezone),
            style: theme.textTheme.bodyMedium,
          ),
          if (locale != null)
            Text(l10n.deviceLocale(locale), style: theme.textTheme.bodyMedium),
          if (errorText != null)
            Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
