import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/currency_catalog.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/features/fx/data/fx_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/insights_fakes.dart';
import '../../helpers/router_app.dart';

const List<CurrencyDto> _currencies = <CurrencyDto>[
  CurrencyDto(
    code: 'INR',
    name: 'Indian Rupee',
    exponent: 2,
    selectable: true,
    symbol: '₹',
  ),
  CurrencyDto(
    code: 'USD',
    name: 'US Dollar',
    exponent: 2,
    selectable: true,
    symbol: r'$',
  ),
  CurrencyDto(
    code: 'EUR',
    name: 'Euro',
    exponent: 2,
    selectable: true,
    symbol: '€',
  ),
];

void main() {
  late MockFxApi api;

  setUpAll(registerInsightsFallbacks);

  setUp(() {
    api = MockFxApi();
  });

  List<Override> overrides() => <Override>[
    fxApiProvider.overrideWithValue(api),
    currencyCatalogProvider.overrideWith(
      (_) async => CurrencyCatalog(_currencies),
    ),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> pickCurrency(
    WidgetTester tester,
    String label,
    String code,
  ) async {
    await tester.tap(find.widgetWithText(SelectorField, label));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('$code ·'));
    await tester.pumpAndSettle();
  }

  group('rates', () {
    testWidgets('shows own and published rates; the user deletes their own '
        'after confirming', (WidgetTester tester) async {
      int calls = 0;
      when(
        () => api.rates(
          base: any(named: 'base'),
          quote: any(named: 'quote'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return <RateDto>[
          rateDto(
            id: 'rate-ecb',
            base: 'EUR',
            rate: '90.500000000000',
            source: 'ecb',
            mine: false,
          ),
          if (calls == 1) rateDto(),
        ];
      });
      when(() => api.deleteRate(any())).thenAnswer((_) async {});
      await pump(tester, '/exchange-rates');

      expect(find.text('Exchange rates'), findsOneWidget);
      expect(find.text('1 USD = 83.1234 INR'), findsOneWidget);
      expect(find.text('1 EUR = 90.5 INR'), findsOneWidget);
      expect(find.textContaining('European Central Bank'), findsOneWidget);
      expect(find.byTooltip('Delete your EUR to INR rate'), findsNothing);

      await tester.tap(find.byTooltip('Delete your USD to INR rate'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this rate?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      verify(() => api.deleteRate('rate-1')).called(1);
      expect(find.text('Rate deleted.'), findsOneWidget);
      expect(find.text('1 USD = 83.1234 INR'), findsNothing);
    });

    testWidgets('filters by currency; empty and failed states', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(
        () => api.rates(
          base: any(named: 'base'),
          quote: any(named: 'quote'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <RateDto>[];
      });
      await pump(tester, '/exchange-rates');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No exchange rates yet'), findsOneWidget);

      await pickCurrency(tester, 'From', 'USD');
      verify(() => api.rates(base: 'USD')).called(1);
      expect(find.text('No rates for these currencies'), findsOneWidget);
    });
  });

  group('manual rate', () {
    testWidgets('checks the rate and saves it for the chosen pair', (
      WidgetTester tester,
    ) async {
      when(
        () => api.rates(
          base: any(named: 'base'),
          quote: any(named: 'quote'),
        ),
      ).thenAnswer((_) async => <RateDto>[]);
      when(() => api.setRate(any())).thenAnswer((_) async => rateDto());
      final GoRouter router = await pump(tester, '/exchange-rates');
      unawaited(router.push<Object?>('/exchange-rates/new?base=USD&quote=INR'));
      await tester.pumpAndSettle();

      expect(
        find.text('How many INR one USD is worth, for example 83.12'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField), '83.12.4');
      await tester.ensureVisible(find.text('Save rate'));
      await tester.tap(find.text('Save rate'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Enter a number above zero with at most 12 decimal places, for '
          'example 83.12.',
        ),
        findsOneWidget,
      );
      verifyNever(() => api.setRate(any()));

      await tester.enterText(find.byType(TextFormField), '83,1234');
      await tester.tap(find.text('Save rate'));
      await tester.pumpAndSettle();
      final ManualRateInput sent =
          verify(() => api.setRate(captureAny())).captured.single
              as ManualRateInput;
      expect(sent.toJson(), <String, Object?>{
        'base': 'USD',
        'quote': 'INR',
        'rate': '83.1234',
      });
      expect(locationOf(router), '/exchange-rates');
      expect(find.text('Rate saved.'), findsOneWidget);
    });

    testWidgets('asks for two different currencies and shows server field '
        'errors', (WidgetTester tester) async {
      when(() => api.setRate(any())).thenThrow(
        serverError(
          ErrorObjectCode.validationError,
          details: const <Detail>[
            Detail(
              field: 'body.as_of',
              message: 'A rate cannot be dated in the future.',
            ),
          ],
        ),
      );
      await pump(tester, '/exchange-rates/new?base=USD&quote=USD');
      await tester.enterText(find.byType(TextFormField), '1.5');
      await tester.ensureVisible(find.text('Save rate'));
      await tester.tap(find.text('Save rate'));
      await tester.pumpAndSettle();
      expect(find.text('Choose two different currencies.'), findsOneWidget);
      verifyNever(() => api.setRate(any()));

      await tester.ensureVisible(find.text('To currency'));
      await pickCurrency(tester, 'To currency', 'INR');
      await tester.ensureVisible(find.text('Save rate'));
      await tester.tap(find.text('Save rate'));
      await tester.pumpAndSettle();
      expect(
        find.text('A rate cannot be dated in the future.'),
        findsOneWidget,
      );
    });
  });

  group('converter', () {
    testWidgets('converts with the disclosed rate', (
      WidgetTester tester,
    ) async {
      when(
        () => api.convert(
          amount: any(named: 'amount'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          historical: any(named: 'historical'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => conversion(inverted: true));
      await pump(tester, '/exchange-rates/convert');

      expect(find.text('INR'), findsWidgets, reason: 'the main currency');
      await pickCurrency(tester, 'To', 'USD');
      await tester.enterText(find.byType(TextFormField), '1000');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Convert'));
      await tester.tap(find.widgetWithText(FilledButton, 'Convert'));
      await tester.pumpAndSettle();

      verify(() => api.convert(amount: '1000.00', from: 'INR', to: 'USD'))
          .called(1);
      await tester.ensureVisible(find.text('Result'));
      expect(find.textContaining('₹1,000.00 ='), findsOneWidget);
      expect(find.text('1 INR = 0.012030306749 USD'), findsOneWidget);
      expect(find.text('Worked out from the USD to INR rate.'), findsOneWidget);
      expect(
        find.textContaining('Rounded to the smallest unit'),
        findsOneWidget,
      );
    });

    testWidgets('without a rate it offers to add one', (
      WidgetTester tester,
    ) async {
      when(
        () => api.convert(
          amount: any(named: 'amount'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          historical: any(named: 'historical'),
          date: any(named: 'date'),
        ),
      ).thenThrow(serverError(ErrorObjectCode.notFound, status: 404));
      final GoRouter router = await pump(tester, '/exchange-rates/convert');
      await pickCurrency(tester, 'To', 'USD');
      await tester.enterText(find.byType(TextFormField), '10');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Convert'));
      await tester.tap(find.widgetWithText(FilledButton, 'Convert'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No exchange rate is available for INR to USD. Add your own rate.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Add a rate'));
      await tester.tap(find.text('Add a rate'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/exchange-rates/new?base=INR&quote=USD');
    });
  });
}
