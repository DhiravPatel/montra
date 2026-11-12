import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/settings/app_preferences.dart';

import '../helpers/finance_fakes.dart';

/// The account's accessibility settings (`reduced_motion`, `high_contrast`,
/// `text_scale_percent`) and formats, applied on top of the device's.
void main() {
  group('applyAccessibility', () {
    const MediaQueryData device = MediaQueryData(
      textScaler: TextScaler.linear(1.3),
    );

    test('defaults keep the device settings', () {
      final MediaQueryData out = applyAccessibility(
        device,
        const AccessibilitySettings(),
      );
      expect(out.disableAnimations, isFalse);
      expect(out.highContrast, isFalse);
      expect(out.textScaler, device.textScaler);
    });

    test('the account turns reduced motion and high contrast on and '
        'multiplies the text size', () {
      final MediaQueryData out = applyAccessibility(
        device,
        const AccessibilitySettings(
          reducedMotion: true,
          highContrast: true,
          textScalePercent: 150,
        ),
      );
      expect(out.disableAnimations, isTrue);
      expect(out.highContrast, isTrue);
      expect(out.textScaler.scale(10), closeTo(19.5, 0.0001));
      // The device can still ask for them when the account does not.
      final MediaQueryData system = applyAccessibility(
        const MediaQueryData(disableAnimations: true, highContrast: true),
        const AccessibilitySettings(textScalePercent: 80),
      );
      expect(system.disableAnimations, isTrue);
      expect(system.highContrast, isTrue);
      expect(system.textScaler.scale(10), closeTo(8, 0.0001));
    });

    test('a scaled text scaler can be clamped like any other', () {
      const ScaledTextScaler scaler = ScaledTextScaler(TextScaler.linear(2), 2);
      expect(scaler.scale(10), 40);
      expect(scaler.clamp(maxScaleFactor: 3).scale(10), 30);
      expect(scaler.clamp(minScaleFactor: 1, maxScaleFactor: 1).scale(10), 10);
    });

    test(
      'settings come from the preferences and stay in the allowed range',
      () {
        expect(AccessibilitySettings.of(null), const AccessibilitySettings());
        final PreferencesDto p = PreferencesDto.fromJson(<String, Object?>{
          ...preferences().toJson(),
          'reduced_motion': true,
          'text_scale_percent': 400,
        });
        expect(
          AccessibilitySettings.of(p),
          const AccessibilitySettings(
            reducedMotion: true,
            textScalePercent: 200,
          ),
        );
      },
    );

    test(
      'the app language follows the account locale it is translated into',
      () {
        expect(appLocaleFor('hi-IN'), const Locale('hi'));
        expect(appLocaleFor('en-GB'), const Locale('en'));
        expect(appLocaleFor('fr-FR'), isNull);
        expect(appLocaleFor(null), isNull);
      },
    );

    test('the number format preference picks the grouping', () {
      expect(
        resolveNumberLocale(
          const Locale('en'),
          'en-US',
          numberFormat: 'indian',
        ),
        'en_IN',
      );
      expect(
        resolveNumberLocale(
          const Locale('hi'),
          'hi-IN',
          numberFormat: 'international',
        ),
        'en_US',
      );
      expect(
        resolveNumberLocale(
          const Locale('en'),
          'en-IN',
          numberFormat: 'locale',
        ),
        'en_IN',
      );
    });
  });

  group('themes', () {
    test('high contrast uses stronger colors and borders', () {
      final ThemeData normal = AppTheme.light();
      final ThemeData strong = AppTheme.light(highContrast: true);
      expect(strong.colorScheme.primary, isNot(normal.colorScheme.primary));
      expect((strong.cardTheme.shape! as RoundedRectangleBorder).side.width, 2);
      expect(
        StatusColors.forScheme(strong.colorScheme, highContrast: true).warning,
        isNot(StatusColors.forScheme(normal.colorScheme).warning),
      );
      expect(
        AppTheme.dark(highContrast: true).colorScheme.brightness,
        Brightness.dark,
      );
    });

    for (final bool reduce in <bool>[false, true]) {
      testWidgets('page transitions ${reduce ? 'are skipped' : 'animate'} '
          'when reduced motion is ${reduce ? 'on' : 'off'}', (
        WidgetTester tester,
      ) async {
        final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            theme: AppTheme.light(),
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: applyAccessibility(
                MediaQuery.of(context),
                AccessibilitySettings(reducedMotion: reduce),
              ),
              child: child!,
            ),
            home: const Scaffold(body: Text('first')),
          ),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Center(child: Text('second'))),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final Offset early = tester.getCenter(find.text('second'));
        final double opacity = _opacityOf(tester, find.text('second'));
        await tester.pumpAndSettle();
        final Offset settled = tester.getCenter(find.text('second'));
        final bool moving = early != settled || opacity < 1;
        expect(moving, !reduce);
      });
    }
  });
}

/// The combined opacity of the [FadeTransition]s above [finder].
double _opacityOf(WidgetTester tester, Finder finder) {
  double value = 1;
  for (final FadeTransition fade in tester.widgetList<FadeTransition>(
    find.ancestor(of: finder, matching: find.byType(FadeTransition)),
  )) {
    value *= fade.opacity.value;
  }
  return value;
}
