import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/app.dart';
import 'package:montra_mobile/app/l10n/generated/app_localizations.dart';
import 'package:montra_mobile/app/theme/theme_mode_controller.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/storage/preferences_store.dart';
import 'package:montra_mobile/core/storage/secure_store.dart';

/// On-device journeys run the real app against a live Montra API.
///
/// The API origin comes from `--dart-define=API_BASE_URL=...` (the same key
/// the app uses; the Android emulator reaches the host at 10.0.2.2). The dev
/// API must have `AUTH_DEV_AUTO_VERIFY_EMAIL=true` so a throwaway user can
/// sign in right after signing up.
///
/// Session tokens and preferences are kept in memory, never in the device's
/// secure storage or shared preferences, so a session someone else left
/// signed in on the same emulator is neither read nor overwritten.

/// English strings, so finders follow the ARB catalog instead of copies.
final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

/// Password for throwaway users (meets the sign-up policy).
const String journeyPassword = 'quiet-harbor-71-e2e';

/// `e2e.<timestamp>.ci@example.com`: unique, clearly synthetic.
String throwawayEmail() =>
    'e2e.${DateTime.now().millisecondsSinceEpoch}.ci@example.com';

/// Configuration resolved exactly as the app does at start-up.
AppConfig journeyConfig() => AppConfig.resolve(
  apiBaseUrl: AppConfig.apiBaseUrlDefine,
  platform: defaultTargetPlatform,
  releaseMode: kReleaseMode,
  clientVersion: '1.0.0+integration',
  deviceName: 'Integration test device',
);

/// Fails fast with a clear message when the API is not reachable.
Future<void> expectApiReady(AppConfig config) async {
  final Uri ready = config.apiBaseUrl.resolve('/health/ready');
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  try {
    final HttpClientRequest request = await client.getUrl(ready);
    final HttpClientResponse response = await request.close();
    final String body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      fail('API at $ready answered ${response.statusCode}: $body');
    }
  } on SocketException catch (error) {
    fail(
      'API at $ready is not reachable ($error). Start it and pass '
      '--dart-define=API_BASE_URL=http://10.0.2.2:<port> on the emulator.',
    );
  } finally {
    client.close(force: true);
  }
}

/// Boots the real app (router, shell, theme, l10n, network stack) with
/// in-memory storage.
Future<void> launchApp(WidgetTester tester, AppConfig config) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      secureStoreProvider.overrideWithValue(MemorySecureStore()),
      preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
      initialThemeModeProvider.overrideWithValue(ThemeMode.light),
    ],
    retry: (int retryCount, Object error) => null,
  );
  addTearDown(container.dispose);
  unawaited(container.read(authControllerProvider.notifier).restore());
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MontraApp()),
  );
}

/// Pumps frames until [finder] matches, or fails after [timeout].
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail(
    'Timed out after ${timeout.inSeconds}s waiting for $finder\n'
    'On screen: ${visibleTexts()}',
  );
}

/// Pumps frames until [finder] no longer matches.
Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) {
      return;
    }
  }
  fail(
    'Timed out after ${timeout.inSeconds}s waiting for $finder to go\n'
    'On screen: ${visibleTexts()}',
  );
}

/// Lets route transitions and snack bars settle without requiring the
/// whole tree to go idle (progress indicators animate forever).
Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Scrolls the main vertical list until [finder] is built, then into view.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final DateTime end = DateTime.now().add(timeout);
  double direction = -300;
  int drags = 0;
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      await settle(tester, 4);
      return;
    }
    final Finder lists = find.byWidgetPredicate(
      (Widget w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.vertical,
    );
    if (lists.evaluate().isEmpty) {
      continue;
    }
    // Down first; after a while also try back up (lists keep their offset).
    if (++drags % 12 == 0) {
      direction = -direction;
    }
    await tester.drag(lists.first, Offset(0, direction), warnIfMissed: false);
  }
  fail(
    'Timed out after ${timeout.inSeconds}s scrolling to $finder\n'
    'On screen: ${visibleTexts()}',
  );
}

/// A button (filled, outlined, text, icon variants) whose label is [label].
Finder button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((Widget w) => w is ButtonStyleButton),
);

/// A text field whose decoration label is [label].
Finder field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextField));

/// Brings [finder] into view and taps the first match.
///
/// With [last] the last match is tapped instead (for example an option in a
/// bottom sheet whose label also appears on the page underneath).
Future<void> tapOn(
  WidgetTester tester,
  Finder finder, {
  bool last = false,
}) async {
  await waitFor(tester, finder);
  // Close the keyboard first: it shrinks the viewport, so a button scrolled
  // into view while it is open can end up below the screen when it closes.
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, 6);
  final Finder target = last ? finder.last : finder.first;
  await tester.ensureVisible(target);
  await settle(tester, 2);
  await tester.tap(target);
  await settle(tester);
}

/// Taps the screen's floating action button once no snack bar covers it.
Future<void> tapFab(WidgetTester tester) async {
  clearSnackBars(tester);
  await settle(tester);
  await tapOn(tester, find.byType(FloatingActionButton));
}

/// Dismisses snack bars ("Account added.") that would cover buttons.
void clearSnackBars(WidgetTester tester) {
  for (final Element e in find.byType(ScaffoldMessenger).evaluate()) {
    final State<StatefulWidget> state = (e as StatefulElement).state;
    if (state is ScaffoldMessengerState) {
      state.clearSnackBars();
    }
  }
}

/// Types [value] into the text field labelled [label].
Future<void> enter(WidgetTester tester, String label, String value) async {
  final Finder target = field(label);
  await waitFor(tester, target);
  await tester.ensureVisible(target.first);
  await settle(tester, 2);
  await tester.enterText(target.first, value);
  await settle(tester, 2);
}

/// Goes back (app bar back button) until the bottom navigation shows.
Future<void> backToTabs(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await settle(tester);
    if (find.byType(NavigationBar).evaluate().isNotEmpty) {
      return;
    }
    final Finder back = find.byTooltip(
      const DefaultMaterialLocalizations().backButtonTooltip,
    );
    await waitFor(tester, back);
    await tester.tap(back.last);
  }
  await waitFor(tester, find.byType(NavigationBar));
}

/// Taps a bottom navigation destination.
Future<void> openTab(WidgetTester tester, String label) => tapOn(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

/// Texts currently on screen, to explain a timeout in the test log.
String visibleTexts() => find
    .byType(Text)
    .evaluate()
    .map((Element e) => (e.widget as Text).data)
    .whereType<String>()
    .where((String t) => t.trim().isNotEmpty)
    .take(80)
    .join(' | ');

/// Prints a progress line to the test log.
void step(String message) => debugPrint('[journey] $message');

/// Secure storage that lives only as long as the test.
class MemorySecureStore implements SecureStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();
}

/// Preferences that live only as long as the test.
class MemoryPreferencesStore implements PreferencesStore {
  ThemeMode? _theme;
  bool _installed = true;

  @override
  Future<ThemeMode?> readThemeMode() async => _theme;

  @override
  Future<void> writeThemeMode(ThemeMode mode) async => _theme = mode;

  @override
  Future<bool> hasInstallMarker() async => _installed;

  @override
  Future<void> writeInstallMarker() async => _installed = true;
}
