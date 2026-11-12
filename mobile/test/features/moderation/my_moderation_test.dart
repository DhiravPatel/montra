import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/moderation/data/moderation_api.dart';

import '../../helpers/communities_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/moderation_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockModerationApi api;

  setUpAll(registerModerationFallbacks);

  setUp(() {
    api = MockModerationApi();
    when(() => api.myAppeals()).thenAnswer(
      (_) async => <ModerationAppealDto>[
        appealDto(status: 'upheld', note: 'It broke rule 2.'),
      ],
    );
    when(() => api.myReports())
        .thenAnswer((_) async => <ModerationReportDto>[myReport()]);
  });

  List<Override> overrides() => <Override>[
    moderationApiProvider.overrideWithValue(api),
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

  testWidgets('decisions show the reason, the appeal window and outcomes; '
      'appealing sends the statement', (WidgetTester tester) async {
    final DateTime later = DateTime.now().add(const Duration(days: 20));
    final DateTime past = DateTime.now().subtract(const Duration(days: 1));
    when(() => api.myModeration()).thenAnswer(
      (_) async => <ModerationActionDto>[
        modAction(appealUntil: later.toUtc().toIso8601String()),
        modAction(
          id: 'act-2',
          action: 'restrict',
          targetType: 'member',
          appealable: false,
          appealUntil: null,
          reversedAt: '2026-11-07T08:00:00Z',
          appeal: <String, Object?>{
            'id': 'apl-2',
            'status': 'overturned',
            'decision_note': 'Fair point',
            'decided_at': '2026-11-07T08:00:00Z',
            'created_at': '2026-11-06T08:00:00Z',
          },
        ),
        modAction(
          id: 'act-3',
          action: 'warn',
          targetType: 'member',
          appealable: false,
          appealUntil: past.toUtc().toIso8601String(),
        ),
      ],
    );
    when(() => api.appeal('act-1', any())).thenAnswer((_) async => appealDto());
    await pump(tester, '/moderation');
    final Finder list = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(find.text('Hidden · Comment'), findsOneWidget);
    expect(find.text('Reason: Off topic'), findsWidgets);
    expect(find.textContaining('You can appeal until'), findsOneWidget);
    expect(find.text('Decision reversed'), findsOneWidget);
    expect(
      find.textContaining('Note from the reviewer: Fair point'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Appeals can be made within 30 days of the decision.'),
      200,
      scrollable: list,
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Appeal'),
      -200,
      scrollable: list,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Appeal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'It was on topic.');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Send appeal'));
    await tester.pumpAndSettle();
    verify(() => api.appeal('act-1', 'It was on topic.')).called(1);
    expect(
      find.text('Appeal sent. You will be told the outcome.'),
      findsOneWidget,
    );
  });

  testWidgets('appeals and reports tabs explain outcomes', (
    WidgetTester tester,
  ) async {
    when(() => api.myModeration())
        .thenAnswer((_) async => <ModerationActionDto>[]);
    await pump(tester, '/moderation');
    expect(find.text('Nothing here'), findsOneWidget);
    await tester.tap(find.text('Your appeals'));
    await tester.pumpAndSettle();
    expect(find.text('Decision stands'), findsOneWidget);
    expect(
      find.text('Your appeal was reviewed and the decision stands.'),
      findsOneWidget,
    );
    expect(
      find.text('Note from the reviewer: It broke rule 2.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Your reports'));
    await tester.pumpAndSettle();
    expect(find.text('Post · Spam'), findsOneWidget);
    expect(find.text('No action needed'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry; empty tabs', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(() => api.myModeration()).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw offline;
      }
      return <ModerationActionDto>[];
    });
    when(() => api.myAppeals())
        .thenAnswer((_) async => <ModerationAppealDto>[]);
    when(() => api.myReports())
        .thenAnswer((_) async => <ModerationReportDto>[]);
    await pump(tester, '/moderation');
    expect(find.text("You're offline"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here'), findsOneWidget);
    await tester.tap(find.text('Your appeals'));
    await tester.pumpAndSettle();
    expect(find.text("You haven't made any appeals."), findsOneWidget);
    await tester.tap(find.text('Your reports'));
    await tester.pumpAndSettle();
    expect(find.text("You haven't reported anything."), findsOneWidget);
  });
}
