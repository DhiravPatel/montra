import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/settings/data/account_security_api.dart';
import 'package:montra_mobile/features/settings/presentation/sessions_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

class MockAccountSecurityApi extends Mock implements AccountSecurityApi {}

final DateTime now = DateTime.utc(2026, 11, 4, 10);

SessionDto session({
  required String id,
  required bool current,
  String clientKind = 'android',
  String? deviceName,
  String lastSeenAt = '2026-11-04T09:55:00Z',
}) => SessionDto.fromJson(
  sessionJson(
    id: id,
    current: current,
    clientKind: clientKind,
    deviceName: deviceName,
    lastSeenAt: lastSeenAt,
  ),
);

void main() {
  late MockAccountSecurityApi api;

  setUp(() => api = MockAccountSecurityApi());

  Future<void> pumpSessions(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        SessionsScreen(now: () => now),
        overrides: [accountSecurityApiProvider.overrideWithValue(api)],
      ),
    );
  }

  testWidgets('shows a loading state while sessions load', (
    WidgetTester tester,
  ) async {
    final Completer<List<SessionDto>> pending = Completer<List<SessionDto>>();
    when(() => api.listSessions()).thenAnswer((Invocation _) => pending.future);
    await pumpSessions(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    pending.complete(<SessionDto>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('lists sessions with a current-device marker', (
    WidgetTester tester,
  ) async {
    when(() => api.listSessions()).thenAnswer(
      (Invocation _) async => <SessionDto>[
        session(
          id: 'other',
          current: false,
          clientKind: 'web',
          lastSeenAt: '2026-11-04T07:00:00Z',
        ),
        session(id: 'mine', current: true, deviceName: 'Google Pixel 8'),
      ],
    );
    await pumpSessions(tester);
    await tester.pumpAndSettle();

    // Current device first, marked with text (not color alone) that is part
    // of the tile's merged screen-reader label.
    expect(find.text('This device'), findsOneWidget);
    expect(find.text('Google Pixel 8'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('This device')), findsOneWidget);
    expect(find.text('Last active 5 minutes ago'), findsOneWidget);
    expect(find.text('Web browser'), findsOneWidget);
    expect(find.text('Last active 3 hours ago'), findsOneWidget);
    // Only the other session can be signed out from here.
    expect(find.text('Sign out'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Google Pixel 8')).dy,
      lessThan(tester.getTopLeft(find.text('Web browser')).dy),
    );
  });

  testWidgets('shows an empty state', (WidgetTester tester) async {
    when(() => api.listSessions())
        .thenAnswer((Invocation _) async => <SessionDto>[]);
    await pumpSessions(tester);
    await tester.pumpAndSettle();

    expect(find.text('There are no active sessions.'), findsOneWidget);
  });

  testWidgets('shows an error with its reference and retries', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(() => api.listSessions()).thenAnswer((Invocation _) async {
      calls++;
      if (calls == 1) {
        throw const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.internalError,
          statusCode: 500,
          requestId: 'req-42',
        );
      }
      return <SessionDto>[session(id: 'mine', current: true)];
    });
    await pumpSessions(tester);
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Reference: req-42'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.bySemanticsLabel(RegExp('This device')), findsOneWidget);
  });

  testWidgets('shows an offline state for connectivity failures', (
    WidgetTester tester,
  ) async {
    when(() => api.listSessions())
        .thenThrow(const ApiException(kind: ApiErrorKind.network));
    await pumpSessions(tester);
    await tester.pumpAndSettle();

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows a permission-denied state for FORBIDDEN', (
    WidgetTester tester,
  ) async {
    when(() => api.listSessions()).thenThrow(
      const ApiException(
        kind: ApiErrorKind.server,
        code: ErrorObjectCode.forbidden,
        statusCode: 403,
        requestId: 'req-403',
      ),
    );
    await pumpSessions(tester);
    await tester.pumpAndSettle();

    expect(find.text("You don't have access"), findsOneWidget);
    expect(find.text('Reference: req-403'), findsOneWidget);
  });

  testWidgets('revokes another session after confirmation', (
    WidgetTester tester,
  ) async {
    bool revoked = false;
    when(() => api.listSessions()).thenAnswer(
      (Invocation _) async => <SessionDto>[
        session(id: 'mine', current: true),
        if (!revoked) session(id: 'other', current: false, clientKind: 'web'),
      ],
    );
    when(() => api.revokeSession('other')).thenAnswer((Invocation _) async {
      revoked = true;
    });
    await pumpSessions(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out this device?'), findsOneWidget);

    // Cancelling does nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => api.revokeSession(any()));

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Sign out'),
      ),
    );
    await tester.pumpAndSettle();

    verify(() => api.revokeSession('other')).called(1);
    expect(find.text('Device signed out.'), findsOneWidget);
    expect(find.text('Web browser'), findsNothing);
  });
}
