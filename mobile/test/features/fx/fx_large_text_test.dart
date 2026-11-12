import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/currency_catalog.dart';
import 'package:montra_mobile/features/fx/data/fx_api.dart';

import '../../helpers/insights_fakes.dart';
import '../../helpers/router_app.dart';

/// Exchange-rate screens at 200 % text in English and Hindi must lay out
/// without overflow.
void main() {
  late MockFxApi api;

  setUpAll(registerInsightsFallbacks);

  setUp(() {
    api = MockFxApi();
    when(
      () => api.rates(
        base: any(named: 'base'),
        quote: any(named: 'quote'),
      ),
    ).thenAnswer(
      (_) async => <RateDto>[
        rateDto(),
        rateDto(
          id: 'rate-2',
          base: 'EUR',
          rate: '90.500000000000',
          source: 'ecb',
          mine: false,
        ),
      ],
    );
  });

  List<Override> overrides() => <Override>[
    fxApiProvider.overrideWithValue(api),
    currencyCatalogProvider.overrideWith(
      (_) async => CurrencyCatalog(const <CurrencyDto>[]),
    ),
  ];

  /// Opens [start], then pushes each of [locations] at 200 % text in
  /// [locale], scrolling through it; any overflow fails the test.
  Future<void> walk(
    WidgetTester tester,
    Locale locale,
    String start,
    List<String> locations, {
    Future<void> Function(WidgetTester tester, String location)? extra,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ({Widget app, GoRouter router}) r = routedApp(
      start,
      overrides: overrides(),
      locale: locale,
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: start);
    for (final String location in locations) {
      unawaited(r.router.push<Object?>(location));
      await tester.pumpAndSettle();
      for (int i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: location);
      if (extra != null) {
        await extra(tester, location);
        expect(tester.takeException(), isNull, reason: '$location (more)');
      }
      r.router.pop();
      await tester.pumpAndSettle();
    }
  }

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('exchange-rate screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      await walk(tester, locale, '/exchange-rates', <String>[
        '/exchange-rates/new?base=USD&quote=INR',
        '/exchange-rates/convert',
      ]);
    });
  }
}
