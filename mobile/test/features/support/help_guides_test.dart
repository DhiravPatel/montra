import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/features/settings/data/limits_api.dart';
import 'package:montra_mobile/features/support/data/support_api.dart';
import 'package:montra_mobile/features/support/domain/help_guide_content.dart';
import 'package:montra_mobile/features/support/presentation/help_guides_screen.dart';

import '../../helpers/router_app.dart';
import '../../helpers/support_fakes.dart';

void main() {
  late MockSupportApi api;
  late MockLimitsApi limitsApi;

  setUpAll(registerSupportFallbacks);

  setUp(() {
    api = MockSupportApi();
    when(() => api.list()).thenAnswer((_) async => <RequestDto>[]);
    limitsApi = MockLimitsApi();
    when(() => limitsApi.get()).thenAnswer((_) async => limitsDto());
  });

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      locale: locale,
      overrides: <Override>[
        supportApiProvider.overrideWithValue(api),
        limitsApiProvider.overrideWithValue(limitsApi),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  group('content', () {
    test('every guide has content, a unique slug and a topic', () {
      expect(
        helpGuides.map((HelpGuideContent c) => c.guide).toSet(),
        HelpGuide.values.toSet(),
      );
      expect(
        HelpGuide.values.map((HelpGuide g) => g.slug).toSet(),
        hasLength(HelpGuide.values.length),
      );
      for (final HelpGuideTopic topic in HelpGuideTopic.values) {
        expect(
          helpGuides.where((HelpGuideContent c) => c.topic == topic),
          isNotEmpty,
        );
      }
      expect(HelpGuide.fromSlug('two-step'), HelpGuide.twoStep);
      expect(HelpGuide.fromSlug('nope'), isNull);
    });

    test('every guide is translated into Hindi', () async {
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      final AppLocalizations hi = await AppLocalizations.delegate.load(
        const Locale('hi'),
      );
      for (final HelpGuideContent c in helpGuides) {
        final List<String> english = c.texts(en).toList();
        final List<String> hindi = c.texts(hi).toList();
        expect(hindi.length, english.length);
        for (int i = 0; i < english.length; i++) {
          expect(hindi[i], isNot(english[i]), reason: '${c.guide} #$i');
          expect(hindi[i], isNotEmpty);
        }
      }
    });

    test('search matches every word in the current language', () async {
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      final HelpGuideContent budgets = helpGuideContent(HelpGuide.budgets);
      expect(helpGuideMatches(budgets, en, 'ROLLOVER cap'), isTrue);
      expect(helpGuideMatches(budgets, en, 'rollover passkey'), isFalse);
      expect(helpGuideMatches(budgets, en, '  '), isTrue);
    });
  });

  testWidgets('help lists guides by topic; searching narrows them', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester, '/help');
    expect(find.text('Guides'), findsWidgets);
    await tester.tap(find.text('How Montra calculates'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/help/guides?topic=calculations');
    expect(find.text('How budgets are calculated'), findsOneWidget);
    expect(find.text('Reconciling an account'), findsNothing);

    await tester.tap(find.text('All guides'));
    await tester.pumpAndSettle();
    expect(find.text('Reconciling an account'), findsOneWidget);
    expect(find.text('Service status'), findsNothing, reason: 'not configured');

    await tester.enterText(find.byType(TextField), 'recovery codes');
    await tester.pumpAndSettle();
    expect(find.text('Two-step verification and recovery'), findsOneWidget);
    expect(find.text('How budgets are calculated'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('No guide matches “zzzz”'), findsOneWidget);
  });

  testWidgets('a guide shows its sections and opens the screen it is about', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester, '/help/guides/no-bank');
    expect(find.text('Why don’t I see my bank?'), findsOneWidget);
    expect(find.text('What Montra will never do'), findsOneWidget);
    expect(
      find.text('Ask for your bank password, PIN, card number or OTP.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('What Montra will never do'), findsOneWidget);
    await tester.tap(find.text('See connected services'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/integrations');
  });

  testWidgets('an unknown guide says so', (WidgetTester tester) async {
    await pump(tester, '/help/guides/missing');
    expect(
      find.text('This guide doesn’t exist. It may have moved.'),
      findsOneWidget,
    );
  });

  testWidgets('the status link appears only when configured', (
    WidgetTester tester,
  ) async {
    Future<void> show(String url) => tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(
            AppConfig.resolve(
              apiBaseUrl: 'http://localhost:8080',
              platform: TargetPlatform.android,
              releaseMode: false,
              clientVersion: '1.0.0+1',
              statusPageUrl: url,
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ServiceStatusLink()),
        ),
      ),
    );
    await show('https://status.example.com');
    await tester.pumpAndSettle();
    expect(find.text('Service status'), findsOneWidget);
    await show('');
    await tester.pumpAndSettle();
    expect(find.text('Service status'), findsNothing);
  });

  testWidgets('guides read in Hindi', (WidgetTester tester) async {
    await pump(tester, '/help/guides/budgets', locale: const Locale('hi'));
    expect(find.text('बजट का हिसाब कैसे होता है'), findsWidgets);
    expect(find.text('रोलओवर'), findsOneWidget);
  });

  testWidgets('screens link to their guide from the app bar', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester, '/help/guides/budgets');
    expect(
      find.byTooltip('How this works: How budgets are calculated'),
      findsNothing,
    );
    router.go('/limits');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('How this works: Fair-use limits'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/help/guides/fair-use');
  });
}
