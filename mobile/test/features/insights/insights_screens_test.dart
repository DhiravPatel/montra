import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/insights/data/insights_api.dart';

import '../../helpers/insights_feature_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockInsightsApi api;

  setUpAll(registerInsightFeatureFallbacks);

  setUp(() => api = MockInsightsApi());

  void stubList(List<InsightDto> items, {String? next}) {
    when(
      () => api.list(
        all: any(named: 'all'),
        kind: any(named: 'kind'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => insightPage(items, next: next));
  }

  /// The detail screen reads one insight (`GET /insights/{id}`).
  void stubGet(InsightDto item) =>
      when(() => api.get(item.id)).thenAnswer((_) async => item);

  List<Override> overrides() => <Override>[
    insightsApiProvider.overrideWithValue(api),
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

  group('insights tab', () {
    testWidgets('lists localized insights and opens one', (
      WidgetTester tester,
    ) async {
      stubList(<InsightDto>[
        insight(),
        insight(id: 'ins-2', status: 'expected', messageCode: null),
      ]);
      final GoRouter router = await pump(tester, '/insights');
      expect(find.text('Insights'), findsWidgets);
      expect(find.text('Unusually large Groceries expense'), findsNWidgets(2));
      expect(find.text('Worth a look'), findsNWidgets(2));
      expect(find.text('Expected'), findsOneWidget);
      expect(find.text('English body from the server.'), findsOneWidget);

      await tester.tap(find.text('All, including handled'));
      await tester.pumpAndSettle();
      verify(
        () => api.list(
          all: true,
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).called(1);

      await tester.tap(find.text('Unusually large Groceries expense').first);
      await tester.pumpAndSettle();
      expect(locationOf(router), '/insights/ins-1');
    });

    testWidgets('empty and error states', (WidgetTester tester) async {
      int calls = 0;
      when(
        () => api.list(
          all: any(named: 'all'),
          kind: any(named: 'kind'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {
        if (calls++ == 0) {
          throw const ApiException(kind: ApiErrorKind.network);
        }
        return insightPage(<InsightDto>[]);
      });
      await pump(tester, '/insights');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing needs a look'), findsOneWidget);
    });
  });

  group('insight detail', () {
    testWidgets('shows why, the amounts and the record; acts and keeps '
        'feedback', (WidgetTester tester) async {
      stubGet(insight());
      when(() => api.act('ins-1', ActionInputAction.expected))
          .thenAnswer((_) async => insight(status: 'expected'));
      when(
        () => api.feedback('ins-1', FeedbackInputFeedback.helpful, note: 'ok'),
      ).thenAnswer(
        (_) async => insight(
          status: 'expected',
          feedback: <String, Object?>{
            'feedback': 'helpful',
            'note': 'ok',
            'updated_at': '2026-11-12T07:00:00Z',
          },
        ),
      );
      await pump(tester, '/insights/ins-1');
      expect(find.text('Insight'), findsOneWidget);
      expect(find.text('Unusually large Groceries expense'), findsOneWidget);
      expect(find.text('Why you see this'), findsOneWidget);
      expect(
        find.textContaining('at least 3 times your usual (median) amount'),
        findsOneWidget,
      );
      expect(find.text('Usual amount'), findsOneWidget);
      expect(find.text('Open the transaction'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('This was expected'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('This was expected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This was expected'));
      await tester.pumpAndSettle();
      verify(() => api.act('ins-1', ActionInputAction.expected)).called(1);
      expect(find.text('Marked as expected.'), findsOneWidget);
      expect(find.text('Open it again'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Helpful'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'ok');
      await tester.tap(find.text('Helpful'));
      await tester.pumpAndSettle();
      verify(
        () => api.feedback('ins-1', FeedbackInputFeedback.helpful, note: 'ok'),
      ).called(1);
      expect(find.text('Your answer: Helpful'), findsOneWidget);
    });

    testWidgets('mute asks first; snooze offers days', (
      WidgetTester tester,
    ) async {
      stubGet(insight());
      when(() => api.act('ins-1', ActionInputAction.mute))
          .thenAnswer((_) async => insight(status: 'muted'));
      when(() => api.act('ins-1', ActionInputAction.snooze, snoozeDays: 7))
          .thenAnswer((_) async => insight(status: 'snoozed'));
      await pump(tester, '/insights/ins-1');
      await tester.scrollUntilVisible(
        find.text('Remind me later'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Remind me later'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remind me later'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      verify(() => api.act('ins-1', ActionInputAction.snooze, snoozeDays: 7))
          .called(1);
      expect(find.text('Snoozed for 7 days.'), findsOneWidget);
    });

    testWidgets('an unknown insight is explained without listing them all', (
      WidgetTester tester,
    ) async {
      when(() => api.get('ins-404')).thenThrow(
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.notFound,
          statusCode: 404,
        ),
      );
      await pump(tester, '/insights/ins-404');
      expect(find.text("This insight isn't available"), findsOneWidget);
      verifyNever(
        () => api.list(
          all: any(named: 'all'),
          kind: any(named: 'kind'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      );
    });

    testWidgets('a malformed link reads as not available', (
      WidgetTester tester,
    ) async {
      when(() => api.get('not-an-id')).thenThrow(
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.validationError,
          statusCode: 422,
          details: <Detail>[
            Detail(field: 'path.id', message: 'invalid UUID length: 9'),
          ],
        ),
      );
      await pump(tester, '/insights/not-an-id');
      expect(find.text("This insight isn't available"), findsOneWidget);
    });

    testWidgets('a failed read offers a retry', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.get('ins-1')).thenAnswer((_) async {
        if (calls++ == 0) {
          throw const ApiException(kind: ApiErrorKind.network);
        }
        return insight();
      });
      await pump(tester, '/insights/ins-1');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Unusually large Groceries expense'), findsOneWidget);
    });
  });

  group('muted insights', () {
    testWidgets('unmute says how many came back', (WidgetTester tester) async {
      when(() => api.mutes()).thenAnswer(
        (_) async => <InsightMuteDto>[
          insightMute(),
          insightMute(scope: 'cat-1'),
        ],
      );
      when(() => api.unmute('unusual_amount', scope: '*')).thenAnswer(
        (_) async => const UnmuteResult(
          insights: <InsightDto>[],
          reopened: 2,
          scope: '*',
          subtype: 'unusual_amount',
        ),
      );
      await pump(tester, '/insights/mutes');
      expect(find.text('Unusually large expense'), findsNWidgets(2));
      expect(find.textContaining('Everywhere'), findsOneWidget);
      expect(find.textContaining('For one record'), findsOneWidget);
      await tester.tap(find.text('Unmute').first);
      await tester.pumpAndSettle();
      verify(() => api.unmute('unusual_amount', scope: '*')).called(1);
      expect(find.text('Unmuted. 2 insights are back.'), findsOneWidget);
    });

    testWidgets('empty state', (WidgetTester tester) async {
      when(() => api.mutes()).thenAnswer((_) async => <InsightMuteDto>[]);
      await pump(tester, '/insights/mutes');
      expect(find.text('Nothing is muted'), findsOneWidget);
    });
  });
}
