import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/settings/app_preferences.dart';
import 'package:montra_mobile/features/dashboard/data/dashboard_api.dart';
import 'package:montra_mobile/features/goals/data/goals_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

import '../../helpers/dashboard_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/goals_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockPreferencesApi api;
  late MockLabelsApi labels;
  late MockDashboardApi dashboard;
  late MockGoalsApi goals;
  final List<(List<String>, List<String>, bool)> recorded =
      <(List<String>, List<String>, bool)>[];
  final List<PreferencesPatch> patches = <PreferencesPatch>[];
  final List<(GoalInput, String)> created = <(GoalInput, String)>[];

  setUpAll(() {
    registerFinanceFallbacks();
    registerGoalFallbacks();
  });

  setUp(() {
    api = MockPreferencesApi();
    labels = MockLabelsApi();
    dashboard = MockDashboardApi();
    goals = MockGoalsApi();
    recorded.clear();
    patches.clear();
    created.clear();
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
    when(() => api.updatePreferences(any())).thenAnswer((Invocation i) async {
      final PreferencesPatch patch =
          i.positionalArguments.first as PreferencesPatch;
      patches.add(patch);
      return preferences(
        weekStart: patch.weekStart ?? 1,
        monthStartDay: patch.monthStartDay ?? 1,
      );
    });
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
    when(() => goals.create(any(), key: any(named: 'key')))
        .thenAnswer((Invocation i) async {
          final GoalInput input = i.positionalArguments.first as GoalInput;
          created.add((input, i.namedArguments[#key] as String));
          return goal(
            id: 'goal-new',
            name: input.name,
            type: input.goalType.json,
            target: input.targetAmount,
            targetDate: input.targetDate,
            saved: '0.00',
            starting: '0.00',
            percentBp: 0,
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
    goalsApiProvider.overrideWithValue(goals),
  ];

  Future<GoRouter> pump(WidgetTester tester, {Locale? locale}) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      '/onboarding',
      overrides: overrides(),
      locale: locale ?? const Locale('en'),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapContinue(WidgetTester tester) => tapText(tester, 'Continue');

  /// Resumes setup at [step] (everything before it answered).
  void resumeAt(List<String> completed) {
    when(() => api.onboarding()).thenAnswer(
      (_) async => OnboardingDto(
        completedSteps: completed,
        skippedSteps: const <String>[],
      ),
    );
  }

  const List<String> beforeGoals = <String>[
    'welcome',
    'privacy',
    'country',
    'currency',
    'timezone',
    'income',
  ];
  const List<String> beforeNotifications = <String>[
    ...beforeGoals,
    'goals',
    'accounts',
    'categories',
  ];

  Future<void> fillGoal(WidgetTester tester, {String name = 'Goa trip'}) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Goal name'),
      name,
    );
    await tester.tap(find.text('Kind of goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Travel').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Target amount'),
      '50000',
    );
  }

  testWidgets('walks through every step and records what was answered', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester);

    expect(find.text('Welcome, Asha'), findsOneWidget);
    expect(find.text('Step 1 of 8'), findsOneWidget);
    await tapContinue(tester);
    expect(find.text('Your data stays yours'), findsOneWidget);
    expect(find.textContaining("doesn't read your SMS"), findsOneWidget);
    await tapContinue(tester);

    // Region: nothing changed, so nothing is sent.
    expect(find.text('Currency and time zone'), findsOneWidget);
    expect(find.text('INR'), findsOneWidget);
    expect(find.text('Asia/Kolkata'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    await tapContinue(tester);
    expect(patches, isEmpty);

    // Income range is optional; choosing one saves it.
    await tester.tap(find.text('₹1 lakh – ₹2 lakh'));
    await tester.pumpAndSettle();
    await tapContinue(tester);
    expect(patches.single.incomeRange, PreferencesPatchIncomeRange.v1l2l);

    // Goals: optional, skipped here.
    expect(find.text('Step 5 of 8'), findsOneWidget);
    expect(find.text('Save toward something (optional)'), findsOneWidget);
    await tapText(tester, 'Skip this step');
    verifyNever(() => goals.create(any(), key: any(named: 'key')));

    // No account added: the step counts as skipped.
    expect(find.text('Add an account (optional)'), findsOneWidget);
    await tapContinue(tester);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    await tapContinue(tester);

    // Email summaries: unchanged, so nothing more is sent.
    expect(find.text('Step 8 of 8'), findsOneWidget);
    expect(find.text('Email summaries'), findsOneWidget);
    await tapText(tester, 'Finish setup');
    expect(patches, hasLength(1));

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
      'notifications',
    ]);
    expect(recorded.last.$2, <String>['goals', 'accounts']);
    expect(locationOf(router), '/home');
  });

  testWidgets('the region step saves the first day of the week and of the '
      'month', (WidgetTester tester) async {
    resumeAt(<String>['welcome', 'privacy']);
    await pump(tester);

    expect(find.text('Weeks and months'), findsOneWidget);
    await tapText(tester, 'Monday');
    await tapText(tester, 'Sunday');
    await tapText(tester, 'Day 1');
    await tapText(tester, 'Day 25');
    expect(find.text('Sunday'), findsOneWidget);
    expect(find.text('Day 25'), findsOneWidget);
    await tapContinue(tester);

    // Applied at once: the later steps' date pickers start on Sunday.
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).last),
    );
    expect(container.read(preferencesSnapshotProvider)?.weekStart, 0);
    final PreferencesPatch patch = patches.single;
    expect(patch.weekStart, 0);
    expect(patch.monthStartDay, 25);
    expect(patch.baseCurrency, isNull);
    expect(
      patch.toJson().keys,
      unorderedEquals(<String>['week_start', 'month_start_day']),
    );
    expect(find.text('Step 4 of 8'), findsOneWidget);
  });

  testWidgets('a refused week or month start is shown on its field', (
    WidgetTester tester,
  ) async {
    when(() => api.updatePreferences(any())).thenThrow(
      serverError(
        ErrorObjectCode.validationError,
        details: const <Detail>[
          Detail(
            field: 'body.month_start_day',
            message: 'Use a day from 1 to 28.',
          ),
        ],
      ),
    );
    resumeAt(<String>['welcome', 'privacy']);
    await pump(tester);
    await tapText(tester, 'Day 1');
    await tapText(tester, 'Day 28');
    await tapContinue(tester);

    expect(find.text('Use a day from 1 to 28.'), findsOneWidget);
    expect(find.text('Weeks and months'), findsOneWidget);
  });

  group('goals step', () {
    testWidgets('creates a first goal with an idempotency key and records '
        'the step', (WidgetTester tester) async {
      resumeAt(beforeGoals);
      await pump(tester);
      expect(find.text('Step 5 of 8'), findsOneWidget);

      await fillGoal(tester);
      await tapText(tester, 'Create goal');

      final (GoalInput input, String key) = created.single;
      expect(input.name, 'Goa trip');
      expect(input.goalType, GoalInputGoalType.travel);
      expect(input.targetAmount, '50000.00');
      expect(input.currency, 'INR');
      expect(input.targetDate, isNull);
      expect(key.length, greaterThanOrEqualTo(8));
      expect(find.text('Goal created'), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('Target ₹50,000.00'), findsOneWidget);

      await tapContinue(tester);
      expect(find.text('Add an account (optional)'), findsOneWidget);
      await tester.tap(find.text('Skip setup'));
      await tester.pumpAndSettle();
      expect(recorded.last.$1, contains('goals'));
      expect(recorded.last.$2, isNot(contains('goals')));
    });

    testWidgets('requires a name, kind and amount before sending', (
      WidgetTester tester,
    ) async {
      resumeAt(beforeGoals);
      await pump(tester);
      await tapText(tester, 'Create goal');

      verifyNever(() => goals.create(any(), key: any(named: 'key')));
      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text('Choose what kind of goal this is.'), findsOneWidget);
    });

    testWidgets('a failed create says why; trying again reuses the key', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => goals.create(any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            final GoalInput input = i.positionalArguments.first as GoalInput;
            created.add((input, i.namedArguments[#key] as String));
            calls++;
            if (calls == 1) {
              throw offline;
            }
            return goal(id: 'goal-new', name: input.name, target: '50000.00');
          });
      resumeAt(beforeGoals);
      await pump(tester);
      await fillGoal(tester);
      await tapText(tester, 'Create goal');

      expect(
        find.text('Check your internet connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('Goal created'), findsNothing);

      await tapText(tester, 'Create goal');
      expect(created, hasLength(2));
      expect(created[1].$2, created[0].$2);
      expect(find.text('Goal created'), findsOneWidget);
    });

    testWidgets('server field errors appear on the goal fields', (
      WidgetTester tester,
    ) async {
      when(() => goals.create(any(), key: any(named: 'key'))).thenThrow(
        serverError(
          ErrorObjectCode.validationError,
          details: const <Detail>[
            Detail(field: 'body.name', message: 'Use a shorter name.'),
          ],
        ),
      );
      resumeAt(beforeGoals);
      await pump(tester);
      await fillGoal(tester);
      await tapText(tester, 'Create goal');
      expect(find.text('Use a shorter name.'), findsOneWidget);
    });
  });

  group('email summaries step', () {
    testWidgets('saves the chosen summary and finishes', (
      WidgetTester tester,
    ) async {
      resumeAt(beforeNotifications);
      final GoRouter router = await pump(tester);
      expect(find.text('Step 8 of 8'), findsOneWidget);
      expect(find.text('Send each email right away'), findsOneWidget);
      expect(
        find.textContaining('Security and account emails'),
        findsOneWidget,
      );

      await tapText(tester, 'Weekly summary');
      await tapText(tester, 'Finish setup');

      expect(patches.single.emailDigest, PreferencesPatchEmailDigest.weekly);
      expect(recorded.last.$3, isTrue);
      expect(recorded.last.$1, contains('notifications'));
      expect(locationOf(router), '/home');
    });

    testWidgets('can be skipped', (WidgetTester tester) async {
      resumeAt(beforeNotifications);
      final GoRouter router = await pump(tester);
      await tapText(tester, 'Daily summary');
      await tapText(tester, 'Skip this step');

      expect(patches, isEmpty);
      expect(recorded.last.$3, isTrue);
      expect(recorded.last.$2, <String>['notifications']);
      expect(locationOf(router), '/home');
    });

    testWidgets('a failed save keeps the user on the step', (
      WidgetTester tester,
    ) async {
      when(() => api.updatePreferences(any())).thenThrow(offline);
      resumeAt(beforeNotifications);
      final GoRouter router = await pump(tester);
      await tapText(tester, 'Daily summary');
      await tapText(tester, 'Finish setup');

      expect(
        find.text('Check your internet connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('Email summaries'), findsOneWidget);
      expect(
        recorded.where(((List<String>, List<String>, bool) r) => r.$3),
        isEmpty,
      );
      expect(locationOf(router), '/onboarding');
    });
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
      'goals',
      'accounts',
      'categories',
      'notifications',
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

    expect(find.text('Step 3 of 8'), findsOneWidget);
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

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    for (final (String name, List<String> resume) in <(String, List<String>)>[
      ('region', <String>['welcome', 'privacy']),
      ('goals', beforeGoals),
      ('email summaries', beforeNotifications),
    ]) {
      testWidgets('the $name step fits at 200% text ($locale)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        resumeAt(resume);
        await pump(tester, locale: locale);
        final Finder list = find.byType(Scrollable).first;
        for (int i = 0; i < 8; i++) {
          await tester.drag(list, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a created goal fits at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      resumeAt(beforeGoals);
      await pump(tester, locale: locale);
      await tester.enterText(find.byType(TextFormField).first, 'Goa trip');
      final Finder kind = find.byType(DropdownButton<GoalInputGoalType>);
      await tester.ensureVisible(kind);
      await tester.pumpAndSettle();
      await tester.tap(kind);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byIcon(Icons.flight_takeoff, skipOffstage: false).last,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '50000');
      final Finder create = find.byType(FilledButton).first;
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
