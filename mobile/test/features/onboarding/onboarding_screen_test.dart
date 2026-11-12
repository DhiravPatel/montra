import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

import '../../helpers/dashboard_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockPreferencesApi api;
  late MockLabelsApi labels;
  late MockDashboardApi dashboard;
  final List<(List<String>, List<String>, bool)> recorded =
      <(List<String>, List<String>, bool)>[];

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    api = MockPreferencesApi();
    labels = MockLabelsApi();
    dashboard = MockDashboardApi();
    recorded.clear();
    stubLabels(
      labels,
      categories: <CategoryDto>[
        category(),
        category(
          id: 'salary',
          name: 'Salary',
          systemKey: 'salary',
          kind: 'income',
        ),
      ],
    );
    when(() => api.preferences()).thenAnswer((_) async => preferences());
    when(() => api.onboarding()).thenAnswer(
      (_) async => const OnboardingDto(
        completedSteps: <String>[],
        skippedSteps: <String>[],
      ),
    );
    when(
      () => api.recordOnboarding(
        completed: any(named: 'completed'),
        skipped: any(named: 'skipped'),
        complete: any(named: 'complete'),
      ),
    ).thenAnswer((Invocation i) async {
      final List<String> completed =
          i.namedArguments[#completed] as List<String>;
      final List<String> skipped = i.namedArguments[#skipped] as List<String>;
      recorded.add((completed, skipped, i.namedArguments[#complete] as bool));
      return OnboardingDto(
        completedSteps: completed,
        skippedSteps: skipped,
        completedAt: DateTime.utc(2026, 11, 4),
      );
    });
    when(() => dashboard.summary(any()))
        .thenAnswer((_) async => summary(empty: true));
    when(() => dashboard.widgets()).thenAnswer((_) async => widgetLayout());
    when(() => dashboard.planning())
        .thenAnswer((_) async => dashboardPlanning(empty: true));
  });

  List<Override> overrides() => <Override>[
    preferencesApiProvider.overrideWithValue(api),
    labelsApiProvider.overrideWithValue(labels),
    dashboardApiProvider.overrideWithValue(dashboard),
  ];

  Future<GoRouter> pump(WidgetTester tester) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      '/onboarding',
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('walks through every step and records what was answered', (
    WidgetTester tester,
  ) async {
    PreferencesPatch? patch;
    when(() => api.updatePreferences(any())).thenAnswer((Invocation i) async {
      patch = i.positionalArguments.first as PreferencesPatch;
      return preferences();
    });
    final GoRouter router = await pump(tester);

    expect(find.text('Welcome, Asha'), findsOneWidget);
    expect(find.text('Step 1 of 6'), findsOneWidget);
    await tapContinue(tester);
    expect(find.text('Your data stays yours'), findsOneWidget);
    expect(find.textContaining("doesn't read your SMS"), findsOneWidget);
    await tapContinue(tester);

    // Region: nothing changed, so nothing is sent.
    expect(find.text('Currency and time zone'), findsOneWidget);
    expect(find.text('INR'), findsOneWidget);
    expect(find.text('Asia/Kolkata'), findsOneWidget);
    await tapContinue(tester);
    verifyNever(() => api.updatePreferences(any()));

    // Income range is optional; choosing one saves it.
    await tester.tap(find.text('₹1 lakh – ₹2 lakh'));
    await tester.pumpAndSettle();
    await tapContinue(tester);
    expect(patch?.incomeRange, PreferencesPatchIncomeRange.v1l2l);

    // No account added: the step counts as skipped.
    expect(find.text('Add an account (optional)'), findsOneWidget);
    await tapContinue(tester);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    await tester.ensureVisible(find.text('Finish setup'));
    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    // Progress is saved after each step; the last call finishes setup.
    expect(
      recorded.where(((List<String>, List<String>, bool) r) => r.$3),
      hasLength(1),
    );
    expect(recorded.last.$3, isTrue);
    expect(recorded.last.$1, <String>[
      'welcome',
      'privacy',
      'country',
      'currency',
      'timezone',
      'income',
      'categories',
    ]);
    expect(recorded.last.$2, <String>['accounts']);
    expect(locationOf(router), '/home');
  });

  testWidgets('the whole setup can be skipped', (WidgetTester tester) async {
    final GoRouter router = await pump(tester);

    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    expect(recorded.single.$1, isEmpty);
    expect(recorded.single.$2, <String>[
      'welcome',
      'privacy',
      'country',
      'currency',
      'timezone',
      'income',
      'accounts',
      'categories',
    ]);
    expect(locationOf(router), '/home');
  });

  testWidgets('resumes at the first step that was not answered yet', (
    WidgetTester tester,
  ) async {
    when(() => api.onboarding()).thenAnswer(
      (_) async => const OnboardingDto(
        completedSteps: <String>['welcome'],
        skippedSteps: <String>['privacy'],
      ),
    );
    await pump(tester);

    expect(find.text('Step 3 of 6'), findsOneWidget);
    expect(find.text('Currency and time zone'), findsOneWidget);
    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();
    // Earlier answers are kept: welcome stays completed, privacy skipped.
    expect(recorded.last.$1, <String>['welcome']);
    expect(recorded.last.$2, containsAll(<String>['privacy', 'country']));
  });

  testWidgets('a failed save keeps the user on the step with the reason', (
    WidgetTester tester,
  ) async {
    when(() => api.updatePreferences(any())).thenThrow(
      serverError(
        ErrorObjectCode.validationError,
        details: const <Detail>[
          Detail(
            field: 'body.country',
            message: 'Use an ISO 3166-1 alpha-2 code.',
          ),
        ],
      ),
    );
    await pump(tester);
    await tapContinue(tester);
    await tapContinue(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Country or region code (optional)'),
      'ZZ',
    );
    await tapContinue(tester);

    expect(find.text('Use an ISO 3166-1 alpha-2 code.'), findsOneWidget);
    expect(find.text('Currency and time zone'), findsOneWidget);
  });

  testWidgets('shows an offline state when preferences cannot load', (
    WidgetTester tester,
  ) async {
    when(() => api.preferences()).thenThrow(offline);
    await pump(tester);

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
