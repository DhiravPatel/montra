import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/settings/data/limits_api.dart';
import 'package:montra_mobile/features/support/data/support_api.dart';

import '../../helpers/router_app.dart';
import '../../helpers/support_fakes.dart';

void main() {
  late MockSupportApi api;
  late MockLimitsApi limitsApi;

  setUpAll(registerSupportFallbacks);

  setUp(() {
    api = MockSupportApi();
    limitsApi = MockLimitsApi();
    when(() => limitsApi.get()).thenAnswer((_) async => limitsDto());
    when(() => api.list()).thenAnswer(
      (_) async => <RequestDto>[
        supportRequest(messages: 2),
        supportRequest(id: 'req-2', status: 'closed', subject: 'Old question'),
      ],
    );
    when(() => api.get('req-1')).thenAnswer((_) async => supportRequest());
    when(() => api.get('req-2'))
        .thenAnswer((_) async => supportRequest(id: 'req-2', status: 'closed'));
    when(() => api.messages(any())).thenAnswer(
      (_) async => <MessageDto>[
        supportMessage(),
        supportMessage(id: 'msg-2', staff: true, body: 'Open the budget…'),
      ],
    );
  });

  List<Override> overrides() => <Override>[
    supportApiProvider.overrideWithValue(api),
    limitsApiProvider.overrideWithValue(limitsApi),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    // A tall phone, so forms and lists fit without scrolling.
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  ApiException fieldError(String code, {String field = 'body.body'}) =>
      ApiException(
        kind: ApiErrorKind.server,
        code: ErrorObjectCode.validationError,
        statusCode: 422,
        message: 'Server says no',
        details: <Detail>[
          Detail(field: field, code: code, message: 'English text'),
        ],
      );

  group('help', () {
    testWidgets('topics and requests; a request opens its thread', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pump(tester, '/help');
      expect(find.text('Help & support'), findsOneWidget);
      expect(find.text('Common questions'), findsOneWidget);
      expect(find.text('Is anything paid?'), findsOneWidget);
      expect(find.text('Help with budgets'), findsOneWidget);
      expect(find.text('2 messages'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Closed'), findsOneWidget);
      await tester.tap(find.text('Help with budgets'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/help/requests/req-1');
      expect(find.textContaining('Montra support ·'), findsOneWidget);
      expect(find.text('Open the budget…'), findsOneWidget);
    });

    testWidgets('a topic opens the screen it is about', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pump(tester, '/help');
      await tester.tap(find.text('Is anything paid?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Everything in Montra is free'), findsWidgets);
      await tester.tap(find.text('See the limits'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/limits');
    });

    testWidgets('empty and failed states', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.list()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw const ApiException(kind: ApiErrorKind.network);
        }
        return <RequestDto>[];
      });
      await pump(tester, '/help');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("You haven't asked for help yet."), findsOneWidget);
    });
  });

  group('new request', () {
    Future<void> fill(WidgetTester tester, String body) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Subject'),
        'Export stuck',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your message'),
        body,
      );
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
    }

    testWidgets('sends and opens the new request', (WidgetTester tester) async {
      when(() => api.create(any()))
          .thenAnswer((_) async => supportRequest(id: 'req-1'));
      final GoRouter router = await pump(tester, '/help/new');
      expect(find.textContaining('Never include card numbers'), findsOneWidget);
      await fill(tester, 'It says waiting for an hour.');
      final RequestInput sent =
          verify(() => api.create(captureAny())).captured.single
              as RequestInput;
      expect(sent.kind, RequestInputKind.support);
      expect(sent.subject, 'Export stuck');
      expect(locationOf(router), '/help/requests/req-1');
    });

    testWidgets('a card number never leaves the phone', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/help/new');
      await fill(tester, 'My card is 4111 1111 1111 1111');
      expect(
        find.text(
          'Remove card numbers, PINs, one-time codes and passwords before '
          'sending.',
        ),
        findsOneWidget,
      );
      verifyNever(() => api.create(any()));
    });

    testWidgets('the server refusal and the daily limit are explained', (
      WidgetTester tester,
    ) async {
      when(() => api.create(any())).thenThrow(fieldError('contains_secret'));
      await pump(tester, '/help/new');
      await fill(tester, 'Something the server dislikes');
      expect(
        find.text(
          'Remove card numbers, PINs, one-time codes and passwords before '
          'sending.',
        ),
        findsOneWidget,
      );
      when(() => api.create(any())).thenThrow(
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.rateLimited,
          statusCode: 429,
          retryAfter: Duration(hours: 3),
          details: <Detail>[
            Detail(
              code: 'daily_cap',
              message: 'Limit',
              params: <String, String>{'limit': '10', 'window_hours': '24'},
            ),
          ],
        ),
      );
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "You've reached today's limit (10 a day). Try again in 180 minutes.",
        ),
        findsOneWidget,
      );
    });
  });

  group('request', () {
    testWidgets('a reply is sent and the thread reloads', (
      WidgetTester tester,
    ) async {
      when(() => api.reply('req-1', any()))
          .thenAnswer((_) async => supportMessage(id: 'msg-3'));
      await pump(tester, '/help/requests/req-1');
      expect(find.text('AD0B4A0D'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Add a reply'),
        'Thank you',
      );
      await tester.tap(find.text('Send reply'));
      await tester.pumpAndSettle();
      verify(() => api.reply('req-1', 'Thank you')).called(1);
      verify(() => api.messages('req-1')).called(2);
      expect(find.text('Reply sent.'), findsOneWidget);
    });

    testWidgets('a closed request takes no replies', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/help/requests/req-2');
      expect(find.textContaining('This request is closed.'), findsOneWidget);
      expect(find.text('Send reply'), findsNothing);
    });

    testWidgets('request_closed from the server is localized', (
      WidgetTester tester,
    ) async {
      when(() => api.reply('req-1', any())).thenThrow(
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.domainRuleViolation,
          statusCode: 422,
          details: <Detail>[
            Detail(code: 'request_closed', message: 'This request is closed.'),
          ],
        ),
      );
      await pump(tester, '/help/requests/req-1');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Add a reply'),
        'Hello?',
      );
      await tester.tap(find.text('Send reply'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("so it can't take more replies"),
        findsOneWidget,
      );
    });

    testWidgets('an unknown request shows an error with retry', (
      WidgetTester tester,
    ) async {
      when(() => api.get('nope')).thenThrow(
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.notFound,
          statusCode: 404,
        ),
      );
      await pump(tester, '/help/requests/nope');
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('contact (signed out)', () {
    testWidgets('validates, sends and shows the reference', (
      WidgetTester tester,
    ) async {
      when(() => api.contact(any()))
          .thenAnswer((_) async => const ContactResult(reference: 'C0FFEE12'));
      await pump(tester, '/contact');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('This is required.'), findsWidgets);
      verifyNever(() => api.contact(any()));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your email'),
        'me@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Subject'),
        'Cannot sign in',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your message'),
        'I am locked out.',
      );
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      final ContactInput sent =
          verify(() => api.contact(captureAny())).captured.single
              as ContactInput;
      expect(sent.contactEmail, 'me@example.com');
      expect(
        find.text("Your reference is C0FFEE12. We'll reply to your email."),
        findsOneWidget,
      );
    });
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('help screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final ({Widget app, GoRouter router}) r = routedApp(
        '/help',
        overrides: overrides(),
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final String location in <String>[
        '/help/new',
        '/help/requests/req-1',
        '/help/requests/req-2',
        '/contact',
      ]) {
        unawaited(r.router.push<Object?>(location));
        await tester.pumpAndSettle();
        for (int i = 0; i < 6; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: location);
        r.router.pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
