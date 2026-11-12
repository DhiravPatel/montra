import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_router.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/connectivity.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/storage/secure_store.dart';

import 'fakes.dart';
import 'finance_fakes.dart';

/// A test app running the real route table (shell, tabs, detail routes)
/// from [initialLocation], with a signed-in user and [overrides] for the
/// feature APIs. The auth redirect is not installed: these tests start
/// inside the signed-in app.
({Widget app, GoRouter router}) routedApp(
  String initialLocation, {
  List<Override> overrides = const <Override>[],
  Locale locale = const Locale('en'),
}) {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: buildAppRoutes(),
  );
  final Widget app = ProviderScope(
    retry: (int retryCount, Object error) => null,
    overrides: <Override>[
      appConfigProvider.overrideWithValue(testConfig),
      connectivityMonitorProvider.overrideWithValue(FakeConnectivityMonitor()),
      secureStoreProvider.overrideWithValue(MemorySecureStore()),
      ...signedInOverrides(),
      ...overrides,
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  return (app: app, router: router);
}

/// The location of the top-most route, including pushed ones.
String locationOf(GoRouter router) => router.state.uri.toString();
