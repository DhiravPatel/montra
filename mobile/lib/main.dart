import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:montra_mobile/app/app.dart';
import 'package:montra_mobile/app/bootstrap.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final List<Override> overrides;
  try {
    overrides = await Bootstrap.load();
  } on AppConfigException catch (error) {
    runApp(ConfigErrorApp(details: error.message, showDetails: kDebugMode));
    return;
  }

  final ProviderContainer container = ProviderContainer(
    overrides: overrides,
    // Failed requests are retried explicitly by the user (retry buttons),
    // not silently in the background.
    retry: (int retryCount, Object error) => null,
  );
  // Restore a stored session while the splash screen is visible.
  unawaited(container.read(authControllerProvider.notifier).restore());

  runApp(
    UncontrolledProviderScope(container: container, child: const MontraApp()),
  );
}
