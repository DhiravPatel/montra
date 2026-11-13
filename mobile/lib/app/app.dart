import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/date_localizations.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_router.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/app/theme/theme_mode_controller.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/settings/app_preferences.dart';
import 'package:montra_mobile/core/widgets/offline_banner.dart';
import 'package:montra_mobile/features/settings/application/preferences_providers.dart';

/// The Montra application.
///
/// Once a user is signed in, their preferences are loaded and applied app
/// wide: the language (`locale`), the date format and first day of the
/// week, reduced motion, high contrast and text size, on top of the
/// device's own accessibility settings.
class MontraApp extends ConsumerWidget {
  /// Creates the app.
  const MontraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    if (ref.watch(currentUserIdProvider) != null) {
      // Loads the preferences (and keeps them) while signed in; the answer
      // fills `preferencesSnapshotProvider`. Failures only mean defaults.
      ref.watch(preferencesProvider);
    }
    final AccessibilitySettings a11y = ref.watch(accessibilitySettingsProvider);
    // Dates are written through `LocalDates`; a change reloads the
    // localizations below (see `appLocalizationsDelegates`), so every
    // screen redraws its dates.
    final DateSettings dates = ref.watch(dateSettingsProvider);
    LocalDates.settings = dates;
    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(highContrast: a11y.highContrast),
      darkTheme: AppTheme.dark(highContrast: a11y.highContrast),
      highContrastTheme: AppTheme.light(highContrast: true),
      highContrastDarkTheme: AppTheme.dark(highContrast: true),
      themeMode: ref.watch(themeModeProvider),
      themeAnimationStyle: a11y.reducedMotion
          ? AnimationStyle.noAnimation
          : null,
      locale: ref.watch(appLocaleProvider),
      localizationsDelegates: appLocalizationsDelegates(dates),
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: applyAccessibility(MediaQuery.of(context), a11y),
        child: ConnectivityBannerHost(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Minimal app shown when build-time configuration is invalid (for example
/// a release build without an https API URL). Details are shown in debug
/// builds only.
class ConfigErrorApp extends StatelessWidget {
  /// Creates the app.
  const ConfigErrorApp({
    required this.details,
    required this.showDetails,
    super.key,
  });

  /// Developer-facing explanation (contains no secrets).
  final String details;

  /// Whether to show [details].
  final bool showDetails;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (BuildContext context) {
        final AppLocalizations l10n = context.l10n;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const ExcludeSemantics(
                    child: Icon(Icons.build_circle_outlined, size: 48),
                  ),
                  const SizedBox(height: Insets.md),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.configErrorTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(l10n.configErrorBody, textAlign: TextAlign.center),
                  if (showDetails) ...<Widget>[
                    const SizedBox(height: Insets.md),
                    SelectableText(details, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
