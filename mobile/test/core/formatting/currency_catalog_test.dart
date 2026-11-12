import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/currencies.dart';
import 'package:montra_mobile/core/formatting/currency_catalog.dart';
import 'package:montra_mobile/features/auth/domain/device_profile.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

const CurrencyDto inr = CurrencyDto(
  code: 'INR',
  name: 'Indian Rupee',
  exponent: 2,
  selectable: true,
  symbol: '₹',
);
const CurrencyDto eur = CurrencyDto(
  code: 'EUR',
  name: 'Euro',
  exponent: 2,
  selectable: true,
  symbol: '€',
);
const CurrencyDto bgn = CurrencyDto(
  code: 'BGN',
  name: 'Bulgarian Lev',
  exponent: 2,
  selectable: false,
  replacedBy: 'EUR',
  retiredOn: '2026-01-01',
);

void main() {
  group('CurrencyCatalog', () {
    final CurrencyCatalog catalog = CurrencyCatalog(<CurrencyDto>[
      inr,
      bgn,
      eur,
    ]);

    test('sorts by code and hides retired currencies from pickers', () {
      expect(catalog.currencies.map((CurrencyDto c) => c.code), <String>[
        'BGN',
        'EUR',
        'INR',
      ]);
      expect(catalog.selectable.map((CurrencyDto c) => c.code), <String>[
        'EUR',
        'INR',
      ]);
    });

    test('maps a retired suggestion to its replacement', () {
      expect(catalog.selectableFor('INR'), 'INR');
      expect(catalog.selectableFor('BGN'), 'EUR');
      expect(catalog.selectableFor('XYZ'), isNull);
      expect(catalog.selectableFor(null), isNull);
    });

    test('is loaded from GET /currencies without authentication', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (RequestOptions o) async => jsonResponse(
          200,
          envelope(<Object?>[inr.toJson(), bgn.toJson(), eur.toJson()]),
        ),
      );
      final ApiClient client = ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      );
      final List<CurrencyDto> list = await client.send(
        ApiEndpoints.listCurrencies,
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListCurrencyDto(json).data,
      );
      expect(adapter.requests.single.uri.path, '/api/v1/currencies');
      expect(adapter.requests.single.headers['Authorization'], isNull);
      expect(CurrencyCatalog(list).byCode('BGN')?.replacedBy, 'EUR');
    });
  });

  group('offline snapshot (generated from GET /currencies)', () {
    test('is sorted, uses exponents 0/2/3 and marks BGN as retired', () {
      final List<String> codes = Currencies.all
          .map((CurrencyDto c) => c.code)
          .toList();
      expect(codes, List<String>.of(codes)..sort());
      expect(Currencies.all.map((CurrencyDto c) => c.exponent).toSet(), <int>{
        0,
        2,
        3,
      });
      final CurrencyDto retired = Currencies.byCode('BGN')!;
      expect(retired.selectable, isFalse);
      expect(retired.replacedBy, 'EUR');
      expect(retired.retiredOn, '2026-01-01');
      expect(Currencies.byCode('EUR')!.selectable, isTrue);
      expect(Currencies.byCode('INR')!.symbol, '₹');
    });

    test('region suggestions never offer a retired currency', () {
      expect(DeviceProfile.currencyFor(const Locale('bg', 'BG')), 'EUR');
    });
  });

  group('currency picker', () {
    Future<void> pumpPicker(
      WidgetTester tester,
      FutureOr<CurrencyCatalog> Function() load,
    ) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: CurrencyPickerSheet(selected: 'INR')),
          overrides: [currencyCatalogProvider.overrideWith((_) => load())],
        ),
      );
    }

    testWidgets('lists only selectable currencies and filters by search', (
      WidgetTester tester,
    ) async {
      await pumpPicker(
        tester,
        () => CurrencyCatalog(<CurrencyDto>[inr, bgn, eur]),
      );
      await tester.pumpAndSettle();

      expect(find.text('INR · Indian Rupee'), findsOneWidget);
      expect(find.text('EUR · Euro'), findsOneWidget);
      expect(find.textContaining('BGN'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'euro');
      await tester.pumpAndSettle();
      expect(find.text('EUR · Euro'), findsOneWidget);
      expect(find.text('INR · Indian Rupee'), findsNothing);

      await tester.enterText(find.byType(TextField), 'lev');
      await tester.pumpAndSettle();
      expect(find.text('No currencies match "lev".'), findsOneWidget);
    });

    testWidgets('shows loading, then a retryable offline state', (
      WidgetTester tester,
    ) async {
      final Completer<CurrencyCatalog> pending = Completer<CurrencyCatalog>();
      await pumpPicker(tester, () => pending.future);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.completeError(const ApiException(kind: ApiErrorKind.network));
      await tester.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
