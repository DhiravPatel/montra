import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/app/theme/theme_mode_controller.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';
import 'package:montra_mobile/core/settings/app_preferences.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/auth/domain/device_profile.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/settings/application/preferences_providers.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

/// Default periods Home can open with (`PreferencesPatch.default_date_range`).
const List<String> defaultRangeChoices = <String>[
  'today',
  'yesterday',
  'this_week',
  'this_month',
  'this_year',
  'last_7_days',
  'last_30_days',
  'last_90_days',
];

/// Account locales offered (the app is translated into English and Hindi;
/// the region sets number grouping).
const List<String> localeChoices = <String>['en-IN', 'en-US', 'en-GB', 'hi-IN'];

/// Common IANA time zones for the picker; any other valid zone can be typed
/// (the server checks it).
const List<String> commonTimezones = <String>[
  'Asia/Kolkata',
  'Asia/Dubai',
  'Asia/Singapore',
  'Asia/Kathmandu',
  'Asia/Dhaka',
  'Asia/Colombo',
  'Asia/Karachi',
  'Asia/Riyadh',
  'Asia/Qatar',
  'Asia/Kuwait',
  'Asia/Muscat',
  'Asia/Bahrain',
  'Asia/Bangkok',
  'Asia/Jakarta',
  'Asia/Kuala_Lumpur',
  'Asia/Hong_Kong',
  'Asia/Shanghai',
  'Asia/Tokyo',
  'Asia/Seoul',
  'Australia/Perth',
  'Australia/Sydney',
  'Pacific/Auckland',
  'Africa/Nairobi',
  'Africa/Johannesburg',
  'Africa/Lagos',
  'Europe/London',
  'Europe/Dublin',
  'Europe/Lisbon',
  'Europe/Paris',
  'Europe/Berlin',
  'Europe/Amsterdam',
  'Europe/Madrid',
  'Europe/Rome',
  'Europe/Zurich',
  'Europe/Stockholm',
  'Europe/Warsaw',
  'Europe/Athens',
  'Europe/Istanbul',
  'Europe/Moscow',
  'America/Sao_Paulo',
  'America/Mexico_City',
  'America/New_York',
  'America/Toronto',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Vancouver',
  'Pacific/Honolulu',
  'UTC',
];

/// Preferences (`PATCH /me/preferences`): currencies, region, formats,
/// defaults, theme and accessibility. Only changed preferences are sent;
/// emptied optional ones are cleared (`""`, or `clear_default_account`).
/// Saved accessibility, language and number-format settings apply to the
/// whole app at once.
class PreferencesScreen extends ConsumerWidget {
  /// Creates the screen.
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<PreferencesDto> prefs = ref.watch(preferencesProvider);
    final PreferencesDto? loaded = prefs.value;
    if (loaded != null && !(prefs.hasError && !prefs.isLoading)) {
      return _PreferencesForm(
        key: ValueKey<DateTime>(loaded.updatedAt),
        original: loaded,
      );
    }
    // Loading, or the error with a retry.
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prefsTitle)),
      body: AsyncValueView<PreferencesDto>(
        value: prefs,
        onRetry: () => ref.invalidate(preferencesProvider),
        data: (PreferencesDto _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// The values of the form, as request JSON (absent = not set).
@immutable
class PreferenceValues {
  /// Creates the values.
  const PreferenceValues({
    required this.baseCurrency,
    required this.displayCurrency,
    required this.country,
    required this.timezone,
    required this.locale,
    required this.dateFormat,
    required this.numberFormat,
    required this.weekStart,
    required this.monthStartDay,
    required this.defaultRange,
    required this.defaultAccountId,
    required this.theme,
    required this.reducedMotion,
    required this.highContrast,
    required this.textScalePercent,
  });

  /// The stored preferences.
  factory PreferenceValues.of(PreferencesDto p) => PreferenceValues(
    baseCurrency: p.baseCurrency,
    displayCurrency: _blankToNull(p.displayCurrency),
    country: _blankToNull(p.country),
    timezone: p.timezone,
    locale: p.locale,
    dateFormat: p.dateFormat.json,
    numberFormat: p.numberFormat.json,
    weekStart: p.weekStart,
    monthStartDay: p.monthStartDay,
    defaultRange: _blankToNull(p.defaultDateRange),
    defaultAccountId: _blankToNull(p.defaultAccountId),
    theme: p.theme.json,
    reducedMotion: p.reducedMotion,
    highContrast: p.highContrast,
    textScalePercent: p.textScalePercent,
  );

  static String? _blankToNull(String? v) =>
      v == null || v.trim().isEmpty ? null : v.trim();

  /// ISO code.
  final String baseCurrency;

  /// ISO code, or null.
  final String? displayCurrency;

  /// ISO 3166 alpha-2, or null.
  final String? country;

  /// IANA zone.
  final String timezone;

  /// BCP 47 tag such as `en-IN`.
  final String locale;

  /// `locale`, `dmy`, `mdy` or `ymd`.
  final String dateFormat;

  /// `locale`, `indian` or `international`.
  final String numberFormat;

  /// 0 = Sunday.
  final int weekStart;

  /// 1–28.
  final int monthStartDay;

  /// A named range, or null.
  final String? defaultRange;

  /// An account ID, or null.
  final String? defaultAccountId;

  /// `system`, `light` or `dark`.
  final String theme;

  /// Reduce motion.
  final bool reducedMotion;

  /// High contrast.
  final bool highContrast;

  /// 80–200.
  final int textScalePercent;

  /// A copy with some values replaced ([clearDisplayCurrency] and
  /// [clearDefaultAccount] empty those).
  PreferenceValues copyWith({
    String? baseCurrency,
    String? displayCurrency,
    bool clearDisplayCurrency = false,
    String? country,
    bool clearCountry = false,
    String? timezone,
    String? locale,
    String? dateFormat,
    String? numberFormat,
    int? weekStart,
    int? monthStartDay,
    String? defaultRange,
    String? defaultAccountId,
    bool clearDefaultAccount = false,
    String? theme,
    bool? reducedMotion,
    bool? highContrast,
    int? textScalePercent,
  }) => PreferenceValues(
    baseCurrency: baseCurrency ?? this.baseCurrency,
    displayCurrency: clearDisplayCurrency
        ? null
        : displayCurrency ?? this.displayCurrency,
    country: clearCountry ? null : country ?? this.country,
    timezone: timezone ?? this.timezone,
    locale: locale ?? this.locale,
    dateFormat: dateFormat ?? this.dateFormat,
    numberFormat: numberFormat ?? this.numberFormat,
    weekStart: weekStart ?? this.weekStart,
    monthStartDay: monthStartDay ?? this.monthStartDay,
    defaultRange: defaultRange ?? this.defaultRange,
    defaultAccountId: clearDefaultAccount
        ? null
        : defaultAccountId ?? this.defaultAccountId,
    theme: theme ?? this.theme,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    highContrast: highContrast ?? this.highContrast,
    textScalePercent: textScalePercent ?? this.textScalePercent,
  );

  /// The request JSON of these values.
  Map<String, Object?> toJson() => <String, Object?>{
    'base_currency': baseCurrency,
    'display_currency': ?displayCurrency,
    'country': ?country,
    'timezone': timezone,
    'locale': locale,
    'date_format': dateFormat,
    'number_format': numberFormat,
    'week_start': weekStart,
    'month_start_day': monthStartDay,
    'default_date_range': ?defaultRange,
    'default_account_id': ?defaultAccountId,
    'theme': theme,
    'reduced_motion': reducedMotion,
    'high_contrast': highContrast,
    'text_scale_percent': textScalePercent,
  };
}

/// The `PATCH /me/preferences` body that turns [before] into [after]: only
/// changed preferences; an emptied country or second currency is sent as
/// `""`, an emptied default account as `clear_default_account: true`.
Map<String, Object?> preferencesPatchBody(
  PreferenceValues before,
  PreferenceValues after,
) {
  final Map<String, Object?> body = partialPatch(
    before: before.toJson(),
    after: after.toJson(),
    textFields: const <String>{'country', 'display_currency'},
    clearable: const <String>{'default_account_id'},
    always: const <String>{},
  );
  final Object? clear = body.remove('clear');
  if (clear is List<Object?> && clear.contains('default_account_id')) {
    body['clear_default_account'] = true;
  }
  return body;
}

class _PreferencesForm extends ConsumerStatefulWidget {
  const _PreferencesForm({required this.original, super.key});

  final PreferencesDto original;

  @override
  ConsumerState<_PreferencesForm> createState() => _PreferencesFormState();
}

class _PreferencesFormState extends ConsumerState<_PreferencesForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final PreferenceValues _before = PreferenceValues.of(widget.original);
  late PreferenceValues _values = _before;
  late final TextEditingController _country = TextEditingController(
    text: _before.country ?? '',
  );
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'base_currency': 'base_currency',
    'display_currency': 'display_currency',
    'country': 'country',
    'timezone': 'timezone',
    'locale': 'locale',
    'date_format': 'date_format',
    'number_format': 'number_format',
    'week_start': 'week_start',
    'month_start_day': 'month_start_day',
    'default_date_range': 'default_date_range',
    'default_account_id': 'default_account',
    'theme': 'theme',
    'reduced_motion': 'reduced_motion',
    'high_contrast': 'high_contrast',
    'text_scale_percent': 'text_scale',
  };

  @override
  void initState() {
    super.initState();
    _country.addListener(() {
      final String text = _country.text.trim().toUpperCase();
      _set(
        text.isEmpty
            ? _values.copyWith(clearCountry: true)
            : _values.copyWith(country: text),
      );
    });
  }

  @override
  void dispose() {
    _country.dispose();
    super.dispose();
  }

  void _set(PreferenceValues values) => setState(() => _values = values);

  Map<String, Object?> get _body => preferencesPatchBody(_before, _values);

  bool get _dirty => patchHasChanges(_body, always: const <String>{});

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final Map<String, Object?> body = _body;
    if (!patchHasChanges(body, always: const <String>{})) {
      showSnack(context, l10n.socialNothingChanged);
      return;
    }
    try {
      final PreferencesDto saved = await ref
          .read(preferencesApiProvider)
          .updatePreferences(PreferencesPatch.fromJson(body));
      _apply(saved);
      if (mounted) {
        showSnack(
          context,
          body.containsKey('base_currency')
              ? '${l10n.prefsSaved} '
                    '${l10n.prefsBaseCurrencyChanged(saved.baseCurrency)}'
              : l10n.prefsSaved,
        );
      }
      ref.invalidate(preferencesProvider);
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
        );
      }
    }
  }

  /// Applies saved preferences at once: app-wide settings, the signed-in
  /// summary (base currency, time zone, locale) and the theme.
  void _apply(PreferencesDto saved) {
    ref.read(preferencesSnapshotProvider.notifier).update(saved);
    ref
        .read(authControllerProvider.notifier)
        .updateUser(
          (UserDto u) => UserDto.fromJson(<String, Object?>{
            ...u.toJson(),
            'base_currency': saved.baseCurrency,
            'timezone': saved.timezone,
            'locale': saved.locale,
          }),
        );
    if (saved.theme.json == _before.theme) {
      return;
    }
    ref.read(themeModeProvider.notifier).select(switch (saved.theme) {
      PreferencesDtoTheme.light => ThemeMode.light,
      PreferencesDtoTheme.dark => ThemeMode.dark,
      PreferencesDtoTheme.system ||
      PreferencesDtoTheme.unrecognized => ThemeMode.system,
    });
  }

  Future<void> _confirmLeave() async {
    final AppLocalizations l10n = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final bool leave = await showConfirmDialog(
      context,
      title: l10n.prefsUnsavedTitle,
      body: l10n.prefsUnsavedBody,
      confirmLabel: l10n.prefsDiscard,
    );
    if (leave && mounted) {
      setState(() => _values = _before);
      navigator.pop();
    }
  }

  Future<void> _pick<T>({
    required String title,
    required List<SheetOption<T>> options,
    required T selected,
    required void Function(T value) onPicked,
  }) async {
    final T? picked = await showOptionSheet<T>(
      context,
      title: title,
      options: options,
      selected: selected,
    );
    if (picked != null && mounted) {
      onPicked(picked);
    }
  }

  Future<void> _pickTimezone() async {
    final String? zone = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          TimezonePickerSheet(selected: _values.timezone),
    );
    if (zone != null && mounted) {
      _set(_values.copyWith(timezone: zone));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String? general = _errors.general;
    final PreferenceValues v = _values;
    final bool currencyChanged = v.baseCurrency != _before.baseCurrency;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          _confirmLeave();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.prefsTitle)),
        body: Form(
          key: _form,
          child: ScrollableContent(
            children: <Widget>[
              if (general != null) ...<Widget>[
                NoticeBanner(
                  tone: NoticeTone.error,
                  message: general,
                  requestId: _errors.requestId,
                ),
                const SizedBox(height: Insets.md),
              ],
              FormSectionHeader(l10n.prefsMoneySection),
              SelectorField(
                label: l10n.prefsBaseCurrency,
                icon: Icons.currency_exchange,
                value: v.baseCurrency,
                errorText: _errors['base_currency'],
                onTap: () async {
                  final String? code = await showCurrencyPicker(
                    context,
                    selected: v.baseCurrency,
                  );
                  if (code != null && mounted) {
                    _set(_values.copyWith(baseCurrency: code));
                  }
                },
              ),
              const SizedBox(height: Insets.sm),
              NoticeBanner(
                tone: currencyChanged ? NoticeTone.warning : NoticeTone.info,
                message: currencyChanged
                    ? '${l10n.prefsBaseCurrencyExplain}\n\n'
                          '${l10n.prefsBaseCurrencyChanged(v.baseCurrency)}'
                    : l10n.prefsBaseCurrencyExplain,
              ),
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.optionalLabel(l10n.prefsDisplayCurrency),
                value: v.displayCurrency,
                placeholder: l10n.prefsNone,
                helperText: l10n.prefsDisplayCurrencyHelp,
                errorText: _errors['display_currency'],
                onClear: () =>
                    _set(_values.copyWith(clearDisplayCurrency: true)),
                onTap: () async {
                  final String? code = await showCurrencyPicker(
                    context,
                    selected: v.displayCurrency,
                  );
                  if (code != null && mounted) {
                    _set(_values.copyWith(displayCurrency: code));
                  }
                },
              ),
              const SizedBox(height: Insets.md),
              _DefaultAccountField(
                accountId: v.defaultAccountId,
                errorText: _errors['default_account'],
                onPicked: (String id) =>
                    _set(_values.copyWith(defaultAccountId: id)),
                onClear: () =>
                    _set(_values.copyWith(clearDefaultAccount: true)),
              ),
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.prefsDefaultRange,
                value: namedRangeLabel(l10n, v.defaultRange ?? 'this_month'),
                helperText: l10n.prefsDefaultRangeHelp,
                errorText: _errors['default_date_range'],
                onTap: () => _pick<String>(
                  title: l10n.prefsDefaultRange,
                  selected: v.defaultRange ?? 'this_month',
                  options: <SheetOption<String>>[
                    for (final String r in defaultRangeChoices)
                      SheetOption<String>(
                        value: r,
                        label: namedRangeLabel(l10n, r),
                      ),
                  ],
                  onPicked: (String r) =>
                      _set(_values.copyWith(defaultRange: r)),
                ),
              ),
              FormSectionHeader(l10n.prefsRegionSection),
              SelectorField(
                label: l10n.prefsLocale,
                icon: Icons.translate,
                value: localeLabel(l10n, v.locale),
                helperText: l10n.prefsLocaleHelp,
                errorText: _errors['locale'],
                onTap: () => _pick<String>(
                  title: l10n.prefsLocale,
                  selected: v.locale,
                  options: <SheetOption<String>>[
                    for (final String tag in <String>{
                      ...localeChoices,
                      v.locale,
                    })
                      SheetOption<String>(
                        value: tag,
                        label: localeLabel(l10n, tag),
                      ),
                  ],
                  onPicked: (String tag) => _set(_values.copyWith(locale: tag)),
                ),
              ),
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.onboardingTimezoneLabel,
                icon: Icons.schedule,
                value: v.timezone,
                helperText: l10n.prefsTimezoneHelp,
                errorText: _errors['timezone'],
                onTap: _pickTimezone,
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _country,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  labelText: l10n.optionalLabel(l10n.onboardingCountryLabel),
                  helperText: l10n.prefsCountryHelp,
                  errorText: _errors['country'],
                ),
                validator: (String? text) {
                  final String value = (text ?? '').trim();
                  return value.isEmpty ||
                          RegExp(r'^[A-Za-z]{2}$').hasMatch(value)
                      ? null
                      : l10n.onboardingCountryInvalid;
                },
              ),
              FormSectionHeader(l10n.prefsFormatsSection),
              SelectorField(
                label: l10n.prefsDateFormat,
                value: dateFormatLabel(l10n, v.dateFormat),
                helperText: l10n.prefsDateFormatHelp,
                errorText: _errors['date_format'],
                onTap: () => _pick<String>(
                  title: l10n.prefsDateFormat,
                  selected: v.dateFormat,
                  options: <SheetOption<String>>[
                    for (final String f in <String>[
                      'locale',
                      'dmy',
                      'mdy',
                      'ymd',
                    ])
                      SheetOption<String>(
                        value: f,
                        label: dateFormatLabel(l10n, f),
                      ),
                  ],
                  onPicked: (String f) => _set(_values.copyWith(dateFormat: f)),
                ),
              ),
              const SizedBox(height: Insets.md),
              _NumberFormatField(
                value: v.numberFormat,
                currency: v.baseCurrency,
                errorText: _errors['number_format'],
                onPicked: (String f) => _set(_values.copyWith(numberFormat: f)),
              ),
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.prefsWeekStart,
                value: weekdayName(v.weekStart, locale),
                helperText: l10n.prefsWeekStartHelp,
                errorText: _errors['week_start'],
                onTap: () => _pick<int>(
                  title: l10n.prefsWeekStart,
                  selected: v.weekStart,
                  options: <SheetOption<int>>[
                    for (int d = 0; d < 7; d++)
                      SheetOption<int>(value: d, label: weekdayName(d, locale)),
                  ],
                  onPicked: (int d) => _set(_values.copyWith(weekStart: d)),
                ),
              ),
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.prefsMonthStart,
                value: l10n.prefsMonthStartDay(v.monthStartDay),
                helperText: l10n.prefsMonthStartHelp,
                errorText: _errors['month_start_day'],
                onTap: () => _pick<int>(
                  title: l10n.prefsMonthStart,
                  selected: v.monthStartDay,
                  options: <SheetOption<int>>[
                    for (int d = 1; d <= 28; d++)
                      SheetOption<int>(
                        value: d,
                        label: l10n.prefsMonthStartDay(d),
                      ),
                  ],
                  onPicked: (int d) => _set(_values.copyWith(monthStartDay: d)),
                ),
              ),
              FormSectionHeader(l10n.prefsAppearanceSection),
              SegmentedButton<String>(
                segments: <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'system',
                    icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(l10n.themeSystem),
                  ),
                  ButtonSegment<String>(
                    value: 'light',
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(l10n.themeLight),
                  ),
                  ButtonSegment<String>(
                    value: 'dark',
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(l10n.themeDark),
                  ),
                ],
                selected: <String>{v.theme},
                onSelectionChanged: (Set<String> s) =>
                    _set(_values.copyWith(theme: s.first)),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                l10n.prefsThemeHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              FormSectionHeader(l10n.a11yTitle),
              Text(l10n.a11yIntro),
              const SizedBox(height: Insets.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.a11yReducedMotion),
                subtitle: Text(l10n.a11yReducedMotionHelp),
                value: v.reducedMotion,
                onChanged: (bool on) =>
                    _set(_values.copyWith(reducedMotion: on)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.a11yHighContrast),
                subtitle: Text(l10n.a11yHighContrastHelp),
                value: v.highContrast,
                onChanged: (bool on) =>
                    _set(_values.copyWith(highContrast: on)),
              ),
              _TextSizeField(
                percent: v.textScalePercent,
                errorText: _errors['text_scale'],
                onChanged: (int p) =>
                    _set(_values.copyWith(textScalePercent: p)),
              ),
              const SizedBox(height: Insets.lg),
              SubmitButton(label: l10n.actionSave, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// A locale tag in words (unknown tags are shown as they are).
String localeLabel(AppLocalizations l10n, String tag) => switch (tag) {
  'en-IN' => l10n.prefsLocaleEnIn,
  'en-US' => l10n.prefsLocaleEnUs,
  'en-GB' => l10n.prefsLocaleEnGb,
  'hi-IN' => l10n.prefsLocaleHiIn,
  _ => tag,
};

/// A date format choice in words.
String dateFormatLabel(AppLocalizations l10n, String format) =>
    switch (format) {
      'dmy' => l10n.prefsDateFormatDmy,
      'mdy' => l10n.prefsDateFormatMdy,
      'ymd' => l10n.prefsDateFormatYmd,
      _ => l10n.prefsDateFormatLocale,
    };

/// The name of weekday [day] (0 = Sunday) in [locale].
String weekdayName(int day, String locale) {
  // 2026-11-08 is a Sunday.
  final DateTime date = DateTime(2026, 11, 8 + (day % 7));
  try {
    return DateFormat.EEEE(locale.replaceAll('-', '_')).format(date);
  } on Object {
    return DateFormat.EEEE('en').format(date);
  }
}

/// "₹12,34,567.89"-style example of [numberFormat] for [currency].
String numberFormatExample(
  Locale app,
  String? accountLocale,
  String numberFormat,
  String currency,
) {
  final String locale = resolveNumberLocale(
    app,
    accountLocale,
    numberFormat: numberFormat,
  );
  final int exponent = currency == 'JPY' ? 0 : 2;
  final String amount = exponent == 0 ? '1234567' : '1234567.89';
  try {
    return MoneyFormatter.format(
      Money(
        amount: amount,
        amountMinor: exponent == 0 ? 1234567 : 123456789,
        currency: currency,
      ),
      locale: locale,
    );
  } on FormatException {
    return '$amount $currency';
  }
}

class _NumberFormatField extends ConsumerWidget {
  const _NumberFormatField({
    required this.value,
    required this.currency,
    required this.onPicked,
    this.errorText,
  });

  final String value;
  final String currency;
  final ValueChanged<String> onPicked;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Locale app = Localizations.localeOf(context);
    final String? account = ref.watch(
      preferencesSnapshotProvider.select((PreferencesDto? p) => p?.locale),
    );
    String example(String f) => numberFormatExample(app, account, f, currency);
    String label(String f) => switch (f) {
      'indian' => l10n.prefsNumberFormatIndian(example(f)),
      'international' => l10n.prefsNumberFormatInternational(example(f)),
      _ => l10n.prefsNumberFormatLocale,
    };
    return SelectorField(
      label: l10n.prefsNumberFormat,
      value: label(value),
      helperText: l10n.prefsNumberFormatHelp(example(value)),
      errorText: errorText,
      onTap: () async {
        final String? picked = await showOptionSheet<String>(
          context,
          title: l10n.prefsNumberFormat,
          selected: value,
          options: <SheetOption<String>>[
            for (final String f in <String>[
              'locale',
              'indian',
              'international',
            ])
              SheetOption<String>(value: f, label: label(f)),
          ],
        );
        if (picked != null) {
          onPicked(picked);
        }
      },
    );
  }
}

class _DefaultAccountField extends ConsumerWidget {
  const _DefaultAccountField({
    required this.accountId,
    required this.onPicked,
    required this.onClear,
    this.errorText,
  });

  final String? accountId;
  final ValueChanged<String> onPicked;
  final VoidCallback onClear;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? id = accountId;
    String? name;
    if (id != null) {
      final List<AccountDto>? accounts = ref
          .watch(accountsProvider(false))
          .value;
      name = accounts == null
          ? l10n.loadingLabel
          : accounts.where((AccountDto a) => a.id == id).firstOrNull?.name ??
                l10n.prefsDefaultAccountMissing;
    }
    return SelectorField(
      label: l10n.optionalLabel(l10n.prefsDefaultAccount),
      icon: Icons.account_balance_wallet_outlined,
      value: name,
      placeholder: l10n.prefsNone,
      helperText: l10n.prefsDefaultAccountHelp,
      errorText: errorText,
      onClear: onClear,
      onTap: () async {
        final AccountDto? picked = await showAccountPicker(
          context,
          selectedId: id,
          title: l10n.prefsDefaultAccount,
        );
        if (picked != null) {
          onPicked(picked.id);
        }
      },
    );
  }
}

class _TextSizeField extends StatelessWidget {
  const _TextSizeField({
    required this.percent,
    required this.onChanged,
    this.errorText,
  });

  final int percent;
  final ValueChanged<int> onChanged;
  final String? errorText;

  static const int _step = 10;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    const int min = AccessibilitySettings.minTextScalePercent;
    const int max = AccessibilitySettings.maxTextScalePercent;
    final int value = percent.clamp(min, max);
    final String valueText = l10n.a11yTextSizeValue(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Insets.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(l10n.a11yTextSize, style: theme.textTheme.bodyLarge),
            ),
            Text(valueText, style: theme.textTheme.titleMedium),
          ],
        ),
        Row(
          children: <Widget>[
            IconButton(
              tooltip: l10n.a11yTextSizeSmaller,
              icon: const Icon(Icons.text_decrease),
              onPressed: value > min ? () => onChanged(value - _step) : null,
            ),
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: (max - min) ~/ _step,
                label: valueText,
                semanticFormatterCallback: (double v) =>
                    l10n.a11yTextSizeValue(v.round()),
                onChanged: (double v) => onChanged(v.round()),
              ),
            ),
            IconButton(
              tooltip: l10n.a11yTextSizeLarger,
              icon: const Icon(Icons.text_increase),
              onPressed: value < max ? () => onChanged(value + _step) : null,
            ),
          ],
        ),
        Text(l10n.a11yTextSizeHelp, style: theme.textTheme.bodySmall),
        if (errorText case final String error)
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        const SizedBox(height: Insets.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(
              l10n.a11yTextSizePreview,
              textScaler: TextScaler.linear(value / 100),
            ),
          ),
        ),
      ],
    );
  }
}

/// Picks an IANA time zone: this device's zone, common ones (searchable)
/// or any typed zone (checked by the server). Pops the chosen zone.
class TimezonePickerSheet extends ConsumerStatefulWidget {
  /// Creates the sheet; [selected] is marked as chosen.
  const TimezonePickerSheet({required this.selected, super.key});

  /// The current zone.
  final String selected;

  @override
  ConsumerState<TimezonePickerSheet> createState() =>
      _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends ConsumerState<TimezonePickerSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? device = ref.watch(deviceProfileProvider).value?.timezone;
    final String q = _query.text.trim();
    final String needle = q.toLowerCase().replaceAll(' ', '_');
    final List<String> zones = <String>[
      for (final String z in <String>{
        widget.selected,
        ?device,
        ...commonTimezones,
      })
        if (needle.isEmpty || z.toLowerCase().contains(needle)) z,
    ];
    final bool typed =
        q.contains('/') &&
        !zones.any((String z) => z == q.replaceAll(' ', '_'));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            0,
            Insets.md,
            Insets.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              l10n.onboardingTimezoneLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: TextField(
            controller: _query,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.prefsTimezoneSearch,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              if (typed)
                ListTile(
                  leading: const Icon(Icons.edit_location_alt_outlined),
                  title: Text(l10n.prefsTimezoneUseTyped(q)),
                  onTap: () =>
                      Navigator.of(context).pop(q.replaceAll(' ', '_')),
                ),
              for (final String zone in zones)
                ListTile(
                  leading: Icon(
                    zone == widget.selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(
                    zone == device ? l10n.prefsTimezoneDevice(zone) : zone,
                  ),
                  selected: zone == widget.selected,
                  onTap: () => Navigator.of(context).pop(zone),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
