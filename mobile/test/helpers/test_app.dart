import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/connectivity.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/storage/secure_store.dart';

import 'fakes.dart';

/// Wraps [child] in the app's providers, theme and localizations.
Widget testApp(
  Widget child, {
  List<Override> overrides = const <Override>[],
  SecureStore? secureStore,
  Locale locale = const Locale('en'),
}) => ProviderScope(
  retry: (int retryCount, Object error) => null,
  overrides: <Override>[
    appConfigProvider.overrideWithValue(testConfig),
    connectivityMonitorProvider.overrideWithValue(FakeConnectivityMonitor()),
    secureStoreProvider.overrideWithValue(secureStore ?? MemorySecureStore()),
    ...overrides,
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);
