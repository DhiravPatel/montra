import 'dart:async';

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
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/presentation/account_widgets.dart';
import 'package:montra_mobile/features/auth/domain/device_profile.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:montra_mobile/features/onboarding/presentation/onboarding_goal_step.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';
import 'package:montra_mobile/features/settings/application/preferences_providers.dart';

enum _Step {
  welcome,
  privacy,
  region,
  income,
  goals,
  accounts,
  categories,
  notifications,
}

/// Email digest choices in onboarding (`PreferencesPatch.email_digest`).
const List<PreferencesPatchEmailDigest> onboardingDigests =
    <PreferencesPatchEmailDigest>[
      PreferencesPatchEmailDigest.off,
      PreferencesPatchEmailDigest.daily,
      PreferencesPatchEmailDigest.weekly,
    ];

/// Income range choices (`PreferencesPatch.income_range`).
const List<PreferencesPatchIncomeRange> incomeRanges =
    <PreferencesPatchIncomeRange>[
      PreferencesPatchIncomeRange.under25k,
      PreferencesPatchIncomeRange.v25k50k,
      PreferencesPatchIncomeRange.v50k1l,
      PreferencesPatchIncomeRange.v1l2l,
      PreferencesPatchIncomeRange.v2l5l,
      PreferencesPatchIncomeRange.above5l,
      PreferencesPatchIncomeRange.preferNotToSay,
    ];

/// The PATCH vocabulary for a stored income range (null when unset).
PreferencesPatchIncomeRange? incomeRangeOf(PreferencesDtoIncomeRange? range) =>
    switch (range) {
      null || PreferencesDtoIncomeRange.unrecognized => null,
      PreferencesDtoIncomeRange.preferNotToSay =>
        PreferencesPatchIncomeRange.preferNotToSay,
      PreferencesDtoIncomeRange.under25k =>
        PreferencesPatchIncomeRange.under25k,
      PreferencesDtoIncomeRange.v25k50k => PreferencesPatchIncomeRange.v25k50k,
      PreferencesDtoIncomeRange.v50k1l => PreferencesPatchIncomeRange.v50k1l,
      PreferencesDtoIncomeRange.v1l2l => PreferencesPatchIncomeRange.v1l2l,
      PreferencesDtoIncomeRange.v2l5l => PreferencesPatchIncomeRange.v2l5l,
      PreferencesDtoIncomeRange.above5l => PreferencesPatchIncomeRange.above5l,
    };

/// Localized income range.
String incomeRangeLabel(
  AppLocalizations l10n,
  PreferencesPatchIncomeRange range,
) => switch (range) {
  PreferencesPatchIncomeRange.under25k => l10n.incomeUnder25k,
  PreferencesPatchIncomeRange.v25k50k => l10n.income25k50k,
  PreferencesPatchIncomeRange.v50k1l => l10n.income50k1l,
  PreferencesPatchIncomeRange.v1l2l => l10n.income1l2l,
  PreferencesPatchIncomeRange.v2l5l => l10n.income2l5l,
  PreferencesPatchIncomeRange.above5l => l10n.incomeAbove5l,
  PreferencesPatchIncomeRange.preferNotToSay ||
  PreferencesPatchIncomeRange.unrecognized => l10n.incomePreferNot,
};

/// Post-sign-up setup: welcome, privacy, region (country, currency, time
/// zone, first day of the week and of the month), income range, a first
/// goal, accounts, starter categories and email summaries. Every step is
/// optional and the whole setup can be skipped; a bank connection is never
/// needed. Answers are saved as preferences (`PATCH /me/preferences`), the
/// goal with `POST /goals`; finishing records the completed and skipped
/// steps (`POST /me/onboarding`) and opens Home.
class OnboardingScreen extends ConsumerWidget {
  /// Creates the screen.
  const OnboardingScreen({this.next, super.key});

  /// Where to go when setup is finished or skipped (a safe in-app path
  /// that waited for sign-in); Home otherwise.
  final String? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<PreferencesDto> prefs = ref.watch(preferencesProvider);
    final AsyncValue<OnboardingDto> saved = ref.watch(
      onboardingProgressProvider,
    );
    final Object? error = prefs.error ?? saved.error;
    if (error != null && !prefs.isLoading && !saved.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.onboardingTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref
            ..invalidate(preferencesProvider)
            ..invalidate(onboardingProgressProvider),
        ),
      );
    }
    final PreferencesDto? p = prefs.value;
    final OnboardingDto? progress = saved.value;
    if (p == null || progress == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.onboardingTitle)),
        body: const LoadingStateView(),
      );
    }
    return _Wizard(preferences: p, saved: progress, next: next);
  }
}

class _Wizard extends ConsumerStatefulWidget {
  const _Wizard({required this.preferences, required this.saved, this.next});

  final PreferencesDto preferences;
  final OnboardingDto saved;
  final String? next;

  @override
  ConsumerState<_Wizard> createState() => _WizardState();
}

class _WizardState extends ConsumerState<_Wizard> {
  _Step _step = _Step.welcome;
  late final TextEditingController _country = TextEditingController(
    text: widget.preferences.country ?? '',
  );
  late String _currency = widget.preferences.baseCurrency;
  late String _timezone = widget.preferences.timezone;
  late int _weekStart = widget.preferences.weekStart;
  late int _monthStart = widget.preferences.monthStartDay;
  late PreferencesPatchEmailDigest _digest =
      PreferencesPatchEmailDigest.fromJson(widget.preferences.emailDigest.json);
  PreferencesPatchIncomeRange? _income;
  GoalDto? _goal;
  final List<AccountDto> _created = <AccountDto>[];
  ServerFormErrors _errors = ServerFormErrors.none;
  final GlobalKey<FormState> _regionForm = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _income = incomeRangeOf(widget.preferences.incomeRange);
    // Resume where the user left off: the first step not answered yet.
    final OnboardingDto saved = widget.saved;
    final Set<String> answered = <String>{
      ...saved.completedSteps,
      ...saved.skippedSteps,
    };
    _step = _order.firstWhere(
      (_Step s) => !_stepIds(s).every(answered.contains),
      orElse: () => _Step.notifications,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.resume(saved);
      }
    });
  }

  @override
  void dispose() {
    _country.dispose();
    super.dispose();
  }

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  static const List<_Step> _order = _Step.values;

  void _next() {
    final int i = _order.indexOf(_step);
    unawaited(_controller.saveProgress());
    if (i < _order.length - 1) {
      setState(() {
        _step = _order[i + 1];
        _errors = ServerFormErrors.none;
      });
    }
  }

  void _back() {
    final int i = _order.indexOf(_step);
    if (i > 0) {
      setState(() {
        _step = _order[i - 1];
        _errors = ServerFormErrors.none;
      });
    }
  }

  List<String> _stepIds(_Step s) => switch (s) {
    _Step.welcome => <String>[OnboardingSteps.welcome],
    _Step.privacy => <String>[OnboardingSteps.privacy],
    _Step.region => OnboardingSteps.region,
    _Step.income => <String>[OnboardingSteps.income],
    _Step.goals => <String>[OnboardingSteps.goals],
    _Step.accounts => <String>[OnboardingSteps.accounts],
    _Step.categories => <String>[OnboardingSteps.categories],
    _Step.notifications => <String>[OnboardingSteps.notifications],
  };

  /// Every step after the current one.
  List<String> _remaining() => <String>[
    for (final _Step s in _order.skip(_order.indexOf(_step))) ..._stepIds(s),
  ];

  Future<void> _finish({bool skipRest = false}) async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    try {
      await _controller.finish(
        remaining: skipRest ? _remaining() : const <String>[],
      );
      if (mounted) {
        context.go(AppRoutes.safeNext(widget.next) ?? AppRoutes.home);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(
            l10n,
            error,
            fieldMap: const <String, String>{},
          ),
        );
      }
    }
  }

  Future<void> _saveRegion() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_regionForm.currentState?.validate() ?? false)) {
      return;
    }
    final PreferencesDto p = widget.preferences;
    final String country = _country.text.trim().toUpperCase();
    final PreferencesPatch patch = PreferencesPatch(
      country: country == (p.country ?? '') ? null : country,
      baseCurrency: _currency == p.baseCurrency ? null : _currency,
      timezone: _timezone == p.timezone ? null : _timezone,
      weekStart: _weekStart == p.weekStart ? null : _weekStart,
      monthStartDay: _monthStart == p.monthStartDay ? null : _monthStart,
    );
    try {
      if (patch.toJson().isNotEmpty) {
        await _controller.savePreferences(patch);
      }
      _controller.complete(OnboardingSteps.region);
      _next();
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(
            l10n,
            error,
            fieldMap: const <String, String>{
              'country': 'country',
              'base_currency': 'currency',
              'timezone': 'timezone',
              'week_start': 'weekStart',
              'month_start_day': 'monthStart',
            },
          ),
        );
      }
    }
  }

  Future<void> _saveIncome() async {
    final AppLocalizations l10n = context.l10n;
    final PreferencesPatchIncomeRange? income = _income;
    if (income == null) {
      _controller.skip(<String>[OnboardingSteps.income]);
      _next();
      return;
    }
    setState(() => _errors = ServerFormErrors.none);
    try {
      await _controller.savePreferences(PreferencesPatch(incomeRange: income));
      _controller.complete(<String>[OnboardingSteps.income]);
      _next();
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(
            l10n,
            error,
            fieldMap: const <String, String>{},
          ),
        );
      }
    }
  }

  /// Saves the email summary choice (when it changed) and finishes.
  Future<void> _saveNotifications() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    try {
      if (_digest.json != widget.preferences.emailDigest.json) {
        await _controller.savePreferences(
          PreferencesPatch(emailDigest: _digest),
        );
      }
      _controller.complete(<String>[OnboardingSteps.notifications]);
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(
            l10n,
            error,
            fieldMap: const <String, String>{},
          ),
        );
      }
      return;
    }
    await _finish();
  }

  Future<void> _pickWeekStart() async {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final int? picked = await showOptionSheet<int>(
      context,
      title: l10n.prefsWeekStart,
      selected: _weekStart,
      options: <SheetOption<int>>[
        for (final int d in weekdaysFrom(DateTime.monday))
          SheetOption<int>(value: d, label: weekdayName(d, locale)),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _weekStart = picked);
    }
  }

  Future<void> _pickMonthStart() async {
    final AppLocalizations l10n = context.l10n;
    final int? picked = await showOptionSheet<int>(
      context,
      title: l10n.prefsMonthStart,
      selected: _monthStart,
      options: <SheetOption<int>>[
        for (int d = 1; d <= 28; d++)
          SheetOption<int>(value: d, label: l10n.prefsMonthStartDay(d)),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _monthStart = picked);
    }
  }

  Future<void> _addAccount() async {
    final Object? created = await context.push(AppRoutes.newAccount);
    if (created is AccountDto && mounted) {
      setState(() => _created.add(created));
      _controller.complete(<String>[OnboardingSteps.accounts]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    // Keeps the progress alive for as long as the setup is open.
    ref.watch(onboardingControllerProvider);
    final int index = _order.indexOf(_step);
    final String? general = _errors.general;
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          _back();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: index == 0
              ? null
              : IconButton(
                  tooltip: l10n.actionBack,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _back,
                ),
          title: Text(l10n.onboardingTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: Semantics(
              label: l10n.onboardingProgress(index + 1, _order.length),
              child: LinearProgressIndicator(
                value: (index + 1) / _order.length,
              ),
            ),
          ),
        ),
        body: ScrollableContent(
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Insets.md,
              children: <Widget>[
                Text(
                  l10n.onboardingProgress(index + 1, _order.length),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                TextButton(
                  onPressed: () => _finish(skipRest: true),
                  child: Text(l10n.onboardingSkipAll),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            ..._content(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    switch (_step) {
      case _Step.welcome:
        final AuthState auth = ref.watch(authControllerProvider);
        final String name = auth is SignedIn ? auth.user.displayName : '';
        return <Widget>[
          SectionHeading(l10n.onboardingWelcomeTitle(name), large: true),
          const SizedBox(height: Insets.md),
          Text(l10n.onboardingWelcomeBody),
          const SizedBox(height: Insets.md),
          _Point(
            icon: Icons.volunteer_activism_outlined,
            text: l10n.welcomeFreeBody,
          ),
          _Point(icon: Icons.edit_note, text: l10n.welcomeManualBody),
          _Point(icon: Icons.lock_outline, text: l10n.welcomePrivateBody),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            label: l10n.actionContinue,
            onPressed: () async {
              _controller.complete(<String>[OnboardingSteps.welcome]);
              _next();
            },
          ),
        ];
      case _Step.privacy:
        return <Widget>[
          SectionHeading(l10n.onboardingPrivacyTitle, large: true),
          const SizedBox(height: Insets.md),
          _Point(
            icon: Icons.block_outlined,
            text: l10n.onboardingPrivacyNotSold,
          ),
          _Point(
            icon: Icons.account_balance_outlined,
            text: l10n.onboardingPrivacyNoBank,
          ),
          _Point(
            icon: Icons.sms_failed_outlined,
            text: l10n.onboardingPrivacyNoSms,
          ),
          _Point(icon: Icons.tune, text: l10n.onboardingPrivacyControl),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            label: l10n.actionContinue,
            onPressed: () async {
              _controller.complete(<String>[OnboardingSteps.privacy]);
              _next();
            },
          ),
        ];
      case _Step.region:
        return <Widget>[
          SectionHeading(l10n.onboardingRegionTitle, large: true),
          const SizedBox(height: Insets.sm),
          Text(l10n.onboardingRegionBody),
          const SizedBox(height: Insets.md),
          Form(
            key: _regionForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SelectorField(
                  label: l10n.onboardingCurrencyLabel,
                  icon: Icons.currency_exchange,
                  value: _currency,
                  helperText: l10n.onboardingCurrencyHelp,
                  errorText: _errors['currency'],
                  onTap: () async {
                    final String? code = await showCurrencyPicker(
                      context,
                      selected: _currency,
                    );
                    if (code != null && mounted) {
                      setState(() => _currency = code);
                    }
                  },
                ),
                const SizedBox(height: Insets.md),
                _TimezoneField(
                  value: _timezone,
                  errorText: _errors['timezone'],
                  onChanged: (String tz) => setState(() => _timezone = tz),
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
                    helperText: l10n.onboardingCountryHelp,
                    errorText: _errors['country'],
                  ),
                  validator: (String? v) {
                    final String text = (v ?? '').trim();
                    return text.isEmpty ||
                            RegExp(r'^[A-Za-z]{2}$').hasMatch(text)
                        ? null
                        : l10n.onboardingCountryInvalid;
                  },
                ),
                FormSectionHeader(l10n.onboardingCalendarSection),
                SelectorField(
                  label: l10n.prefsWeekStart,
                  icon: Icons.view_week_outlined,
                  value: weekdayName(
                    _weekStart,
                    Localizations.localeOf(context).toString(),
                  ),
                  helperText: l10n.prefsWeekStartHelp,
                  errorText: _errors['weekStart'],
                  onTap: _pickWeekStart,
                ),
                const SizedBox(height: Insets.md),
                SelectorField(
                  label: l10n.prefsMonthStart,
                  icon: Icons.calendar_month_outlined,
                  value: l10n.prefsMonthStartDay(_monthStart),
                  helperText: l10n.prefsMonthStartHelp,
                  errorText: _errors['monthStart'],
                  onTap: _pickMonthStart,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(label: l10n.actionContinue, onPressed: _saveRegion),
          const SizedBox(height: Insets.sm),
          _SkipButton(
            onPressed: () {
              _controller.skip(OnboardingSteps.region);
              _next();
            },
          ),
        ];
      case _Step.income:
        return <Widget>[
          SectionHeading(l10n.onboardingIncomeTitle, large: true),
          const SizedBox(height: Insets.sm),
          Text(l10n.onboardingIncomeBody),
          const SizedBox(height: Insets.md),
          RadioGroup<PreferencesPatchIncomeRange>(
            groupValue: _income,
            onChanged: (PreferencesPatchIncomeRange? r) =>
                setState(() => _income = r),
            child: Column(
              children: <Widget>[
                for (final PreferencesPatchIncomeRange r in incomeRanges)
                  RadioListTile<PreferencesPatchIncomeRange>(
                    contentPadding: EdgeInsets.zero,
                    value: r,
                    title: Text(incomeRangeLabel(l10n, r)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(label: l10n.actionContinue, onPressed: _saveIncome),
          const SizedBox(height: Insets.sm),
          _SkipButton(
            onPressed: () {
              _controller.skip(<String>[OnboardingSteps.income]);
              _next();
            },
          ),
        ];
      case _Step.goals:
        return <Widget>[
          OnboardingGoalStep(
            currency: _currency,
            created: _goal,
            onCreated: (GoalDto goal) {
              setState(() => _goal = goal);
              _controller.complete(<String>[OnboardingSteps.goals]);
            },
            onContinue: _next,
            onSkip: () {
              _controller.skip(<String>[OnboardingSteps.goals]);
              _next();
            },
          ),
        ];
      case _Step.accounts:
        return <Widget>[
          SectionHeading(l10n.onboardingAccountsTitle, large: true),
          const SizedBox(height: Insets.sm),
          Text(l10n.onboardingAccountsBody),
          const SizedBox(height: Insets.md),
          for (final AccountDto a in _created)
            Card(child: AccountTile(account: a)),
          if (_created.isNotEmpty) const SizedBox(height: Insets.sm),
          OutlinedButton.icon(
            onPressed: _addAccount,
            icon: const Icon(Icons.add),
            label: Text(
              _created.isEmpty
                  ? l10n.accountAddFirst
                  : l10n.onboardingAddAnother,
            ),
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            label: l10n.actionContinue,
            onPressed: () async {
              if (_created.isEmpty) {
                _controller.skip(<String>[OnboardingSteps.accounts]);
              }
              _next();
            },
          ),
        ];
      case _Step.categories:
        return <Widget>[
          SectionHeading(l10n.onboardingCategoriesTitle, large: true),
          const SizedBox(height: Insets.sm),
          Text(l10n.onboardingCategoriesBody),
          const SizedBox(height: Insets.md),
          const _StarterCategories(),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            label: l10n.actionContinue,
            onPressed: () async {
              _controller.complete(<String>[OnboardingSteps.categories]);
              _next();
            },
          ),
        ];
      case _Step.notifications:
        return <Widget>[
          SectionHeading(l10n.onboardingNotificationsTitle, large: true),
          const SizedBox(height: Insets.sm),
          Text(l10n.onboardingNotificationsBody),
          const SizedBox(height: Insets.md),
          RadioGroup<PreferencesPatchEmailDigest>(
            groupValue: _digest,
            onChanged: (PreferencesPatchEmailDigest? d) {
              if (d != null) {
                setState(() => _digest = d);
              }
            },
            child: Column(
              children: <Widget>[
                for (final PreferencesPatchEmailDigest d in onboardingDigests)
                  RadioListTile<PreferencesPatchEmailDigest>(
                    contentPadding: EdgeInsets.zero,
                    value: d,
                    title: Text(_digestLabel(l10n, d)),
                    subtitle: Text(_digestHelp(l10n, d)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
          _Point(icon: Icons.lock_outline, text: l10n.onboardingDigestSecurity),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            label: l10n.onboardingFinish,
            onPressed: _saveNotifications,
          ),
          const SizedBox(height: Insets.sm),
          _SkipButton(
            onPressed: () {
              _controller.skip(<String>[OnboardingSteps.notifications]);
              unawaited(_finish());
            },
          ),
          const SizedBox(height: Insets.sm),
          Text(
            l10n.onboardingFinishNote,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ];
    }
  }
}

String _digestLabel(AppLocalizations l10n, PreferencesPatchEmailDigest d) =>
    switch (d) {
      PreferencesPatchEmailDigest.daily => l10n.onboardingDigestDaily,
      PreferencesPatchEmailDigest.weekly => l10n.onboardingDigestWeekly,
      PreferencesPatchEmailDigest.off ||
      PreferencesPatchEmailDigest.unrecognized => l10n.onboardingDigestOff,
    };

String _digestHelp(AppLocalizations l10n, PreferencesPatchEmailDigest d) =>
    switch (d) {
      PreferencesPatchEmailDigest.daily => l10n.onboardingDigestDailyHelp,
      PreferencesPatchEmailDigest.weekly => l10n.onboardingDigestWeeklyHelp,
      PreferencesPatchEmailDigest.off ||
      PreferencesPatchEmailDigest.unrecognized => l10n.onboardingDigestOffHelp,
    };

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Insets.xs + 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: Insets.md),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    onPressed: onPressed,
    child: Text(context.l10n.onboardingSkipStep),
  );
}

class _TimezoneField extends ConsumerWidget {
  const _TimezoneField({
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? device = ref.watch(deviceProfileProvider).value?.timezone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.onboardingTimezoneLabel,
            helperText: l10n.onboardingTimezoneHelp,
            errorText: errorText,
            prefixIcon: const Icon(Icons.schedule),
          ),
          child: Text(value),
        ),
        if (device != null && device != value)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => onChanged(device),
              icon: const Icon(Icons.my_location),
              label: Text(l10n.onboardingUseDeviceTimezone(device)),
            ),
          ),
      ],
    );
  }
}

class _StarterCategories extends ConsumerWidget {
  const _StarterCategories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<CategoryDto>> categories = ref.watch(
      categoriesProvider,
    );
    if (categories.hasError && !categories.isLoading) {
      return SizedBox(
        height: 280,
        child: ErrorStateView(
          error: categories.error!,
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
      );
    }
    final List<CategoryDto>? list = categories.value;
    if (list == null) {
      return const SizedBox(height: 120, child: LoadingStateView());
    }
    final List<CategoryDto> spending =
        <CategoryDto>[
          for (final CategoryDto c in list)
            if (c.parentId == null && c.kind != CategoryDtoKind.income) c,
        ]..sort(
          (CategoryDto a, CategoryDto b) => a.sortOrder.compareTo(b.sortOrder),
        );
    final List<CategoryDto> income =
        <CategoryDto>[
          for (final CategoryDto c in list)
            if (c.parentId == null && c.kind == CategoryDtoKind.income) c,
        ]..sort(
          (CategoryDto a, CategoryDto b) => a.sortOrder.compareTo(b.sortOrder),
        );
    Widget chips(List<CategoryDto> items) => Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: <Widget>[
        for (final CategoryDto c in items)
          Chip(
            avatar: CategoryBadge(icon: c.icon, color: c.color, size: 24),
            label: Text(categoryName(l10n, c)),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FormSectionHeader(l10n.onboardingCategoriesSpending),
        chips(spending),
        FormSectionHeader(l10n.onboardingCategoriesIncome),
        chips(income),
      ],
    );
  }
}
