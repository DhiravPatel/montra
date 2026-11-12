import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/integrations/data/integrations_api.dart';
import 'package:montra_mobile/features/integrations/domain/integration_display.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/integrations_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockIntegrationsApi api;
  late MockAccountsApi accounts;
  late List<String> launched;

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    api = MockIntegrationsApi();
    accounts = MockAccountsApi();
    launched = <String>[];
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
  });

  List<Override> overrides() => <Override>[
    integrationsApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
    browserLauncherProvider.overrideWithValue((String url) async {
      launched.add(url);
      return true;
    }),
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

  testWidgets('honest statuses: unavailable and not configured providers '
      'cannot be connected', (WidgetTester tester) async {
    when(() => api.overview()).thenAnswer(
      (_) async => overview(
        providers: <Map<String, Object?>>[
          providerJson(),
          providerJson(
            id: 'demo_bank',
            name: 'Demo Bank',
            kind: 'bank_data',
            status: 'not_configured',
            statusReason: null,
          ),
        ],
      ),
    );
    await pump(tester, '/integrations');
    expect(find.text('Bank connections'), findsOneWidget);
    expect(find.text('You have no connections.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Demo Bank'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
    expect(
      find.textContaining('Needs an approved Account Aggregator partner'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Connect'), findsNothing);
  });

  testWidgets('connecting asks for consent and an account, then opens the '
      'provider in the browser', (WidgetTester tester) async {
    when(() => api.overview()).thenAnswer(
      (_) async => overview(
        providers: <Map<String, Object?>>[
          providerJson(
            id: 'demo_bank',
            name: 'Demo Bank',
            kind: 'bank_data',
            status: 'available',
            statusReason: null,
          ),
        ],
      ),
    );
    when(() => api.connect('demo_bank', 'acc-1')).thenAnswer(
      (_) async => const ConnectResult(
        authorizeUrl: 'https://provider.example/authorize?state=s',
        connectionId: 'conn-9',
      ),
    );
    await pump(tester, '/integrations');
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Connect'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connect Demo Bank?'), findsOneWidget);
    expect(
      find.text(
        'You approve access at the provider. Montra never asks for your '
        'bank password or PIN.',
      ),
      findsOneWidget,
    );
    final Finder confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Connect'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.text('I agree to share this data with Montra'));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.text('HDFC Savings').last);
    await tester.pumpAndSettle();
    verify(() => api.connect('demo_bank', 'acc-1')).called(1);
    expect(launched, <String>['https://provider.example/authorize?state=s']);
    expect(find.text('Continue at the provider'), findsOneWidget);
  });

  testWidgets('a connection shows its syncs; sync while running and '
      'disconnect with removing its transactions', (WidgetTester tester) async {
    when(() => api.overview()).thenAnswer(
      (_) async => overview(
        providers: <Map<String, Object?>>[
          providerJson(id: 'demo_bank', name: 'Demo Bank', status: 'available'),
        ],
        connections: <Map<String, Object?>>[connectionJson()],
      ),
    );
    when(() => api.status('conn-1'))
        .thenAnswer((_) async => connectionStatus());
    when(() => api.sync('conn-1')).thenThrow(
      const ApiException(
        kind: ApiErrorKind.server,
        code: ErrorObjectCode.conflict,
        statusCode: 409,
        message: 'A sync is already running.',
      ),
    );
    when(() => api.disconnect('conn-1', deleteData: true)).thenAnswer(
      (_) async => const DisconnectResult(
        deletedRecords: 4,
        status: DisconnectResultStatus.revoked,
      ),
    );
    final GoRouter router = await pump(tester, '/integrations');
    expect(find.text('Connected'), findsOneWidget);
    await tester.tap(find.text('Demo Bank').first);
    await tester.pumpAndSettle();
    expect(locationOf(router), '/integrations/connections/conn-1');
    await tester.scrollUntilVisible(
      find.text('Fetched 12 · added 10 · updated 1 · skipped 1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text("The provider didn't respond. Try again later."),
      findsWidgets,
    );

    await tester.scrollUntilVisible(
      find.text('Sync now'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();
    expect(
      find.text('A sync is already running. Try again when it finishes.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Disconnect').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Also remove the transactions it brought in'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Disconnect'),
      ),
    );
    await tester.pumpAndSettle();
    verify(() => api.disconnect('conn-1', deleteData: true)).called(1);
    expect(
      find.text('Disconnected. 4 transactions were removed.'),
      findsOneWidget,
    );
  });

  testWidgets('an error offers a retry', (WidgetTester tester) async {
    when(() => api.overview())
        .thenThrow(const ApiException(kind: ApiErrorKind.network));
    await pump(tester, '/integrations');
    expect(find.text("You're offline"), findsOneWidget);
  });
}
