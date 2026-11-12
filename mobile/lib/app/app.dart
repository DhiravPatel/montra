import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_router.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/app/theme/theme_mode_controller.dart';
import 'package:montra_mobile/core/widgets/offline_banner.dart';

/// The Montra application.
class MontraApp extends ConsumerWidget {
  /// Creates the app.
  const MontraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) =>
          ConnectivityBannerHost(child: child ?? const SizedBox.shrink()),
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
