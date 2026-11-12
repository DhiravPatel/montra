import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/goals/data/goals_api.dart';
import 'package:montra_mobile/features/goals/domain/goal_export.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../../helpers/files_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/goals_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockGoalsApi api;
  late MockAccountsApi accounts;
  late MockPeopleApi people;
  late MockTransactionsApi transactions;
  late MockLabelsApi labels;

  setUpAll(() {
    registerFinanceFallbacks();
    registerGoalFallbacks();
  });

  setUp(() {
    api = MockGoalsApi();
    accounts = MockAccountsApi();
    people = MockPeopleApi();
    transactions = MockTransactionsApi();
    labels = MockLabelsApi();
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    stubPeople(people);
    stubLabels(labels);
  });

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    List<Override> extra = const <Override>[],
  }) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: [
        goalsApiProvider.overrideWithValue(api),
        accountsApiProvider.overrideWithValue(accounts),
        peopleApiProvider.overrideWithValue(people),
        transactionsApiProvider.overrideWithValue(transactions),
        labelsApiProvider.overrideWithValue(labels),
        ...extra,
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Finder scrollable() => find.byType(Scrollable).first;

  /// Scrolls until [finder] is built, then fully into view.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    // A focused field would scroll itself back into view.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollable());
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  /// Lets a snack bar time out so it doesn't cover buttons.
  Future<void> waitForSnack(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  group('goals list', () {
    testWidgets('shows progress in words, filters by status and opens one', (
      WidgetTester tester,
    ) async {
      final List<String?> asked = <String?>[];
      when(() => api.list(status: any(named: 'status')))
          .thenAnswer((Invocation i) async {
            final String? status = i.namedArguments[#status] as String?;
            asked.add(status);
            return status == null
                ? <GoalDto>[
                    goal(),
                    goal(
                      id: 'goal-2',
                      name: 'Goa trip',
                      type: 'travel',
                      status: 'paused',
                      percentBp: 5050,
                      saved: '25250.00',
                      target: '50000.00',
                      remaining: '24750.00',
                      targetDate: null,
                      members: <Map<String, Object?>>[
                        goalMemberJson(id: 'u-ravi', name: 'Ravi'),
                      ],
                    ),
                  ]
                : <GoalDto>[];
          });
      stubGoal(api);
      final GoRouter router = await pump(tester, '/goals');

      expect(find.text('Emergency fund'), findsOneWidget);
      expect(
        find.text('25% saved · ₹25,000.00 of ₹1,00,000.00'),
        findsOneWidget,
      );
      expect(find.text('By Jun 30, 2027'), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('Paused'), findsWidgets);
      expect(find.text('Shared with 1 person'), findsOneWidget);
      expect(
        find.text('50.5% saved · ₹25,250.00 of ₹50,000.00'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Archived'));
      await tester.pumpAndSettle();
      expect(asked.last, 'archived');
      expect(find.text('No goals here'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Current'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/goals/goal-1');
    });

    testWidgets('an empty list invites the first goal', (
      WidgetTester tester,
    ) async {
      when(() => api.list(status: any(named: 'status')))
          .thenAnswer((_) async => <GoalDto>[]);
      final GoRouter router = await pump(tester, '/goals');

      expect(find.text('No goals yet'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Add a goal'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/goals/new');
    });

    testWidgets('a failed load can be retried', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.list(status: any(named: 'status'))).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <GoalDto>[goal()];
      });
      await pump(tester, '/goals');

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Emergency fund'), findsOneWidget);
    });
  });

  group('goal form', () {
    testWidgets('validates, then creates the goal with the default '
        'milestones and opens it', (WidgetTester tester) async {
      when(() => api.list(status: any(named: 'status')))
          .thenAnswer((_) async => <GoalDto>[]);
      GoalInput? sent;
      final List<String> keys = <String>[];
      when(() => api.create(any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments.first as GoalInput;
            keys.add(i.namedArguments[#key]! as String);
            return goal(id: 'goal-new', name: 'Goa trip', type: 'travel');
          });
      stubGoal(
        api,
        detail: goal(id: 'goal-new', name: 'Goa trip'),
      );
      final GoRouter router = await pump(tester, '/goals');
      unawaited(router.push<Object?>('/goals/new'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Create goal'));
      await tester.tap(find.text('Create goal'));
      await tester.pumpAndSettle();
      verifyNever(() => api.create(any(), key: any(named: 'key')));
      await tester.drag(scrollable(), const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text('Choose what kind of goal this is.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal name'),
        'Goa trip',
      );
      await tester.tap(find.text('Kind of goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Travel').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target amount'),
        '50000',
      );
      // Milestones: remove the first default one.
      await scrollTo(tester, find.byTooltip('Remove milestone').first);
      await tester.tap(find.byTooltip('Remove milestone').first);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Create goal'));
      await tester.tap(find.text('Create goal'));
      await tester.pumpAndSettle();

      final GoalInput input = sent!;
      expect(input.name, 'Goa trip');
      expect(input.goalType, GoalInputGoalType.travel);
      expect(input.targetAmount, '50000.00');
      expect(input.currency, 'INR');
      expect(input.version, isNull);
      expect(input.priority, 3);
      expect(input.contributionSchedule, GoalInputContributionSchedule.none);
      expect(input.plannedContribution, isNull);
      expect(input.visibility, GoalInputVisibility.private);
      expect(
        input.milestones?.map((GoalMilestoneInput m) => m.percent).toList(),
        <int>[50, 75, 100],
      );
      expect(keys.single, hasLength(greaterThanOrEqualTo(8)));
      expect(locationOf(router), '/goals/goal-new');
      expect(find.text('Goal created.'), findsOneWidget);
    });

    testWidgets('edits send only the changes with the version; emptied '
        'fields are cleared; a conflict reloads the newer one', (
      WidgetTester tester,
    ) async {
      when(() => api.list(status: any(named: 'status')))
          .thenAnswer((_) async => <GoalDto>[goal()]);
      int loads = 0;
      when(() => api.get('goal-1')).thenAnswer((_) async {
        loads++;
        return loads == 1
            ? goal(linkedAccountId: 'acc-1', description: 'For surprises')
            : goal(name: 'Rainy day fund', version: 2);
      });
      final List<GoalPatch> sent = <GoalPatch>[];
      when(() => api.update('goal-1', any())).thenAnswer((Invocation i) async {
        sent.add(i.positionalArguments[1] as GoalPatch);
        if (sent.length == 1) {
          throw serverError(ErrorObjectCode.versionConflict, status: 409);
        }
        return goal(name: 'Safety net', version: 3);
      });
      final GoRouter router = await pump(tester, '/goals');
      unawaited(router.push<Object?>('/goals/goal-1/edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit goal'), findsOneWidget);
      expect(find.text('HDFC Savings'), findsOneWidget);
      expect(
        find.text("The currency can't change after the goal is created."),
        findsOneWidget,
      );
      final Finder name = find.widgetWithText(TextFormField, 'Goal name');
      await tester.enterText(name, 'Safety net');
      // Remove the linked account and the description.
      final Finder clearAccount = find.descendant(
        of: find.ancestor(
          of: find.text('HDFC Savings'),
          matching: find.byType(SelectorField),
        ),
        matching: find.byIcon(Icons.close),
      );
      await scrollTo(tester, clearAccount);
      await tester.tap(clearAccount);
      await tester.pumpAndSettle();
      final Finder description = find.widgetWithText(
        TextFormField,
        'Description (optional)',
      );
      await scrollTo(tester, description);
      await tester.enterText(description, '');
      await scrollTo(tester, find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(sent.first.toJson(), <String, Object?>{
        'clear': <String>['linked_account_id'],
        'description': '',
        'name': 'Safety net',
        'version': 1,
      });

      await tester.drag(scrollable(), const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(find.textContaining('changed somewhere else'), findsOneWidget);
      expect(find.text('Rainy day fund'), findsOneWidget);
      await tester.enterText(name, 'Safety net');
      await scrollTo(tester, find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent.last.toJson(), <String, Object?>{
        'name': 'Safety net',
        'version': 2,
      });
      expect(locationOf(router), '/goals');
      expect(find.text('Goal saved.'), findsOneWidget);
    });

    testWidgets('shows server field errors next to the fields', (
      WidgetTester tester,
    ) async {
      when(() => api.list(status: any(named: 'status')))
          .thenAnswer((_) async => <GoalDto>[]);
      when(() => api.create(any(), key: any(named: 'key'))).thenThrow(
        serverError(
          ErrorObjectCode.validationError,
          details: const <Detail>[
            Detail(
              field: 'body.milestones',
              message: 'Milestones are distinct percentages from 1 to 100.',
            ),
          ],
        ),
      );
      final GoRouter router = await pump(tester, '/goals');
      unawaited(router.push<Object?>('/goals/new'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal name'),
        'Phone',
      );
      await tester.tap(find.text('Kind of goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phone or gadget').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target amount'),
        '30000',
      );
      await scrollTo(tester, find.text('Create goal'));
      await tester.tap(find.text('Create goal'));
      await tester.pumpAndSettle();

      await scrollTo(
        tester,
        find.text('Milestones are distinct percentages from 1 to 100.'),
      );
      expect(
        find.text('Milestones are distinct percentages from 1 to 100.'),
        findsOneWidget,
      );
      expect(locationOf(router), '/goals/new');
    });
  });

  group('goal detail', () {
    testWidgets('shows progress, outlook, milestones, contributions, '
        'members and details', (WidgetTester tester) async {
      stubGoal(
        api,
        detail: goal(
          verified: '2500.00',
          planned: '1000.00',
          linkedAccountId: 'acc-1',
          description: 'For surprises',
          members: <Map<String, Object?>>[
            goalMemberJson(
              id: 'u-ravi',
              name: 'Ravi',
              role: 'viewer',
              visibility: 'percent_only',
            ),
          ],
        ),
        contributions: <GoalContributionDto>[
          contribution(),
          contribution(
            id: 'gc-2',
            status: 'planned',
            amount: '1000.00',
            note: 'Next month',
          ),
          contribution(
            id: 'gc-3',
            mine: false,
            name: 'Ravi',
            userId: 'u-ravi',
            amount: null,
            percentBp: 250,
            status: 'verified',
            transactionId: 'tx-ravi',
          ),
          contribution(
            id: 'gc-4',
            voided: true,
            kind: 'withdrawal',
            date: '2026-10-20',
          ),
        ],
      );
      await pump(tester, '/goals/goal-1');

      expect(find.text('Emergency fund'), findsWidgets);
      expect(find.text('25% saved'), findsOneWidget);
      expect(find.text('₹25,000.00 of ₹1,00,000.00'), findsOneWidget);
      expect(find.text('Backed by transactions'), findsOneWidget);
      expect(find.text('Planned, not counted yet'), findsOneWidget);
      expect(find.text('2 contributions'), findsOneWidget);
      await scrollTo(tester, find.text('Add contribution'));
      expect(find.text('Add contribution'), findsOneWidget);

      await scrollTo(tester, find.text('Outlook'));
      expect(
        find.text('Needs a little more to finish on time'),
        findsOneWidget,
      );
      expect(find.text('Jun 30, 2027 · 237 days left'), findsOneWidget);
      expect(
        find.text(
          'To finish by the target date, set aside about ₹9,375.00 a month '
          '(₹2,165.00 a week).',
        ),
        findsOneWidget,
      );
      expect(
        find.text("At this pace, you'd reach it around Mar 5, 2028."),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('Halfway · 50% of the target'));
      expect(find.text('25% of the target'), findsOneWidget);
      expect(find.text('Reached on Nov 2, 2026'), findsOneWidget);
      expect(find.text('Not reached yet'), findsOneWidget);

      await scrollTo(tester, find.text('Contribution · 2.5% of the target'));
      expect(find.text('Contribution · ₹2,500.00'), findsOneWidget);
      expect(find.text('Recorded · Nov 5, 2026 · You'), findsOneWidget);
      expect(find.text('Planned · Nov 5, 2026 · You'), findsOneWidget);
      expect(find.text('Next month'), findsOneWidget);
      expect(find.text('Verified · Nov 5, 2026 · Ravi'), findsOneWidget);
      expect(find.text('Linked to a transaction'), findsOneWidget);
      await scrollTo(tester, find.text('Voided'));
      expect(find.text('Withdrawal · ₹2,500.00'), findsOneWidget);
      // Only the user's own, unvoided contributions can be voided.
      expect(
        find.byTooltip('Void your contribution of Nov 5, 2026'),
        findsNWidgets(2),
      );

      await scrollTo(tester, find.text('Ravi'));
      expect(
        find.text('Can only view · Shows percentages only'),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('For surprises'));
      expect(find.text('HDFC Savings'), findsOneWidget);
      expect(find.text('2 · High'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
    });

    testWidgets('pausing and archiving go through the server and archiving '
        'asks first', (WidgetTester tester) async {
      GoalDto current = goal();
      when(() => api.get('goal-1')).thenAnswer((_) async => current);
      when(() => api.contributions('goal-1', cursor: any(named: 'cursor')))
          .thenAnswer((_) async => contributionsPage(<GoalContributionDto>[]));
      when(() => api.forecast('goal-1')).thenAnswer((_) async => forecast());
      when(
        () => api.pause('goal-1', version: any(named: 'version')),
      ).thenAnswer((_) async => current = goal(status: 'paused', version: 2));
      when(
        () => api.archive('goal-1', version: any(named: 'version')),
      ).thenAnswer((_) async => current = goal(status: 'archived', version: 3));
      await pump(tester, '/goals/goal-1');
      await scrollTo(
        tester,
        find.text('No contributions yet. Add one when you set money aside.'),
      );

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause goal'));
      await tester.pumpAndSettle();
      verify(() => api.pause('goal-1', version: 1)).called(1);
      expect(find.text('Goal paused.'), findsOneWidget);
      await tester.drag(scrollable(), const Offset(0, 3000));
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.text('This goal is paused. Resume it to add contributions.'),
      );
      expect(find.text('Add contribution'), findsNothing);
      await waitForSnack(tester);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Resume goal'), findsOneWidget);
      await tester.tap(find.text('Archive goal'));
      await tester.pumpAndSettle();
      expect(find.text('Archive this goal?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive goal'));
      await tester.pumpAndSettle();
      verify(() => api.archive('goal-1', version: 2)).called(1);
      expect(find.text('Goal archived.'), findsOneWidget);
      await tester.drag(scrollable(), const Offset(0, 3000));
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.text('This goal is archived. Its history is kept.'),
      );
    });

    testWidgets('a refused change explains why and reloads', (
      WidgetTester tester,
    ) async {
      stubGoal(api);
      when(() => api.achieve('goal-1', version: any(named: 'version')))
          .thenThrow(
            serverError(
              ErrorObjectCode.conflict,
              status: 409,
              message: 'This goal is achieved.',
            ),
          );
      await pump(tester, '/goals/goal-1');
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as achieved'));
      await tester.pumpAndSettle();
      expect(find.text('Mark this goal as achieved?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Mark as achieved'));
      await tester.pumpAndSettle();
      expect(find.text('This goal is achieved.'), findsOneWidget);
      // Read again so the screen shows the current state.
      verify(() => api.get('goal-1')).called(2);
    });

    testWidgets('voids an own contribution after confirming', (
      WidgetTester tester,
    ) async {
      stubGoal(api);
      when(() => api.voidContribution('goal-1', 'gc-1'))
          .thenAnswer((_) async => goal(version: 2));
      await pump(tester, '/goals/goal-1');

      final Finder undo = find.byTooltip(
        'Void your contribution of Nov 5, 2026',
      );
      await scrollTo(tester, undo);
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(find.text('Void this contribution?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Void'));
      await tester.pumpAndSettle();
      verify(() => api.voidContribution('goal-1', 'gc-1')).called(1);
      expect(find.text('Contribution voided.'), findsOneWidget);
    });

    testWidgets('opens the transaction linked to an own contribution', (
      WidgetTester tester,
    ) async {
      stubGoal(
        api,
        contributions: <GoalContributionDto>[
          contribution(status: 'verified', transactionId: 'tx-1'),
        ],
      );
      final MockTransactionsApi txApi = transactions;
      when(() => txApi.get('tx-1')).thenAnswer((_) async => transaction());
      final GoRouter router = await pump(tester, '/goals/goal-1');

      await scrollTo(tester, find.text('Open the linked transaction'));
      await tester.tap(find.text('Open the linked transaction'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/transactions/tx-1');
    });

    testWidgets('a goal that fails to load offers a retry', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => api.get('goal-1')).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return goal();
      });
      when(() => api.contributions('goal-1', cursor: any(named: 'cursor')))
          .thenThrow(offline);
      when(() => api.forecast('goal-1')).thenAnswer((_) async => forecast());
      await pump(tester, '/goals/goal-1');

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('25% saved'), findsOneWidget);
      // The contributions card has its own error and retry.
      await scrollTo(tester, find.text('Contributions'));
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('sharing', () {
    testWidgets('the owner adds a friend with a role and removes a member', (
      WidgetTester tester,
    ) async {
      stubPeople(
        people,
        friends: <PublicProfile>[
          friend(id: 'u-meera', name: 'Meera', username: 'meera'),
          friend(id: 'u-ravi', name: 'Ravi'),
        ],
      );
      GoalDto current = goal(
        members: <Map<String, Object?>>[
          goalMemberJson(id: 'u-ravi', name: 'Ravi'),
        ],
      );
      stubGoal(api, detail: current);
      when(() => api.get('goal-1')).thenAnswer((_) async => current);
      GoalMemberInput? added;
      when(() => api.addMember('goal-1', any(), version: any(named: 'version')))
          .thenAnswer((Invocation i) async {
            added = i.positionalArguments[1] as GoalMemberInput;
            return current = goal(
              version: 2,
              members: <Map<String, Object?>>[
                goalMemberJson(id: 'u-ravi', name: 'Ravi'),
                goalMemberJson(id: 'u-meera', name: 'Meera'),
              ],
            );
          });
      when(
        () => api.removeMember(
          'goal-1',
          'u-ravi',
          version: any(named: 'version'),
        ),
      ).thenAnswer((_) async {
        current = goal(
          version: 3,
          members: <Map<String, Object?>>[
            goalMemberJson(id: 'u-meera', name: 'Meera'),
          ],
        );
      });
      await pump(tester, '/goals/goal-1');

      await scrollTo(tester, find.text('Add a person'));
      await tester.tap(find.text('Add a person'));
      await tester.pumpAndSettle();
      // Ravi is already a member, so only Meera is offered.
      expect(find.text('Meera'), findsOneWidget);
      expect(find.text('@meera'), findsOneWidget);
      await tester.tap(find.text('Meera'));
      await tester.pumpAndSettle();
      expect(find.text('What can Meera do?'), findsOneWidget);
      await tester.tap(find.text('Can add contributions'));
      await tester.pumpAndSettle();
      expect(added?.userId, 'u-meera');
      expect(added?.role, GoalMemberInputRole.contributor);
      expect(find.text('Meera added.'), findsOneWidget);
      await waitForSnack(tester);

      await scrollTo(tester, find.text('Ravi'));
      await tester.tap(find.text('Ravi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from goal'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Ravi?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove from goal'));
      await tester.pumpAndSettle();
      verify(() => api.removeMember('goal-1', 'u-ravi', version: 2)).called(1);
      expect(find.text('Ravi removed.'), findsOneWidget);
      expect(find.text('Ravi'), findsNothing);
    });

    testWidgets('a goal shared with a group can add one of its members', (
      WidgetTester tester,
    ) async {
      stubGoal(
        api,
        detail: goal(groupId: 'grp-home', visibility: 'members'),
      );
      when(() => people.group('grp-home')).thenAnswer(
        (_) async => groupDetail(
          members: <Map<String, Object?>>[
            groupMemberJson(id: goalsTestUserId, name: 'Asha', role: 'owner'),
            groupMemberJson(id: 'u-kabir', name: 'Kabir'),
          ],
        ),
      );
      GoalMemberInput? added;
      when(() => api.addMember('goal-1', any(), version: any(named: 'version')))
          .thenAnswer((Invocation i) async {
            added = i.positionalArguments[1] as GoalMemberInput;
            return goal(groupId: 'grp-home', version: 2);
          });
      await pump(tester, '/goals/goal-1');

      await scrollTo(tester, find.text('Home'));
      await scrollTo(tester, find.text('Add a person'));
      await tester.tap(find.text('Add a person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("From this goal's group"));
      await tester.pumpAndSettle();
      expect(find.text('Choose a group member'), findsOneWidget);
      await tester.tap(find.text('Kabir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Can only view'));
      await tester.pumpAndSettle();
      expect(added?.userId, 'u-kabir');
      expect(added?.role, GoalMemberInputRole.viewer);
    });

    testWidgets('a member changes what others see and can leave', (
      WidgetTester tester,
    ) async {
      final GoalDto shared = goal(
        access: 'contributor',
        visibility: 'members',
        members: <Map<String, Object?>>[
          goalMemberJson(id: goalsTestUserId, name: 'Asha'),
        ],
      );
      stubGoal(api, detail: shared);
      when(() => api.list(status: any(named: 'status')))
          .thenAnswer((_) async => <GoalDto>[shared]);
      GoalMemberUpdate? update;
      when(
        () => api.updateMember(
          'goal-1',
          goalsTestUserId,
          any(),
          version: any(named: 'version'),
        ),
      ).thenAnswer((Invocation i) async {
        update = i.positionalArguments[2] as GoalMemberUpdate;
        return shared;
      });
      when(
        () => api.removeMember(
          'goal-1',
          goalsTestUserId,
          version: any(named: 'version'),
        ),
      ).thenAnswer((_) async {});
      final GoRouter router = await pump(tester, '/goals');
      expect(find.text('Shared by Asha Rao'), findsOneWidget);
      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Asha (you)'));
      await tester.tap(find.text('Asha (you)'));
      await tester.pumpAndSettle();
      expect(
        find.text('What others see of your contributions'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keeps contributions private'));
      await tester.pumpAndSettle();
      expect(
        update?.contributionVisibility,
        GoalMemberUpdateContributionVisibility.hidden,
      );
      expect(update?.role, isNull);
      await waitForSnack(tester);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Pause goal'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      await tester.tap(find.text('Leave goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave goal'));
      await tester.pumpAndSettle();
      verify(() => api.removeMember('goal-1', goalsTestUserId, version: 1))
          .called(1);
      expect(locationOf(router), '/goals');
      expect(find.text('You left the goal.'), findsOneWidget);
    });
  });

  group('contributions', () {
    testWidgets('a retry after a lost connection reuses the idempotency key', (
      WidgetTester tester,
    ) async {
      stubGoal(api);
      final List<String> keys = <String>[];
      final List<GoalContributionInput> inputs = <GoalContributionInput>[];
      when(() => api.addContribution('goal-1', any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            keys.add(i.namedArguments[#key]! as String);
            inputs.add(i.positionalArguments[1] as GoalContributionInput);
            if (keys.length == 1) {
              throw offline;
            }
            return contribution(status: 'planned');
          });
      final GoRouter router = await pump(tester, '/goals/goal-1');
      await scrollTo(tester, find.text('Add contribution'));
      await tester.tap(find.text('Add contribution'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/goals/goal-1/contribute');
      expect(find.text('Add to Emergency fund'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount added'),
        '2500',
      );
      await tester.tap(find.text('Planned'));
      await tester.pumpAndSettle();
      expect(find.textContaining("isn't counted as saved yet"), findsOneWidget);
      await scrollTo(tester, find.text('Save contribution'));
      await tester.tap(find.text('Save contribution'));
      await tester.pumpAndSettle();
      await tester.drag(scrollable(), const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(
        find.text('Check your internet connection and try again.'),
        findsOneWidget,
      );

      await scrollTo(tester, find.text('Save contribution'));
      await tester.tap(find.text('Save contribution'));
      await tester.pumpAndSettle();
      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      expect(inputs.last.amount, '2500.00');
      expect(inputs.last.status, GoalContributionInputStatus.planned);
      expect(inputs.last.kind, GoalContributionInputKind.contribution);
      expect(inputs.last.transactionId, isNull);
      expect(locationOf(router), '/goals/goal-1');
      expect(find.text('Contribution added.'), findsOneWidget);
    });

    testWidgets('linking a transaction records a verified withdrawal', (
      WidgetTester tester,
    ) async {
      stubGoal(api);
      when(
        () => transactions.list(
          any(),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => page(<TransactionDto>[
          transaction(id: 'tx-9', merchant: 'SBI transfer'),
        ]),
      );
      GoalContributionInput? sent;
      when(() => api.addContribution('goal-1', any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments[1] as GoalContributionInput;
            return contribution(kind: 'withdrawal', status: 'verified');
          });
      final GoRouter router = await pump(tester, '/goals/goal-1');
      unawaited(router.push<Object?>('/goals/goal-1/contribute'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Withdrawal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount taken out'),
        '1250.75',
      );
      await scrollTo(
        tester,
        find.text('Choose the transaction that moved the money'),
      );
      await tester.tap(
        find.text('Choose the transaction that moved the money'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Which transaction moved the money?'), findsOneWidget);
      await tester.tap(find.text('SBI transfer'));
      await tester.pumpAndSettle();
      expect(
        find.text('SBI transfer · ₹1,250.75 · Nov 4, 2026'),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('Save withdrawal'));
      await tester.tap(find.text('Save withdrawal'));
      await tester.pumpAndSettle();

      expect(sent?.transactionId, 'tx-9');
      expect(sent?.status, GoalContributionInputStatus.recorded);
      expect(sent?.kind, GoalContributionInputKind.withdrawal);
      expect(sent?.amount, '1250.75');
      expect(find.text('Withdrawal recorded.'), findsOneWidget);
    });

    testWidgets('explains when the goal no longer takes contributions', (
      WidgetTester tester,
    ) async {
      stubGoal(api);
      when(() => api.addContribution('goal-1', any(), key: any(named: 'key')))
          .thenThrow(
            serverError(
              ErrorObjectCode.domainRuleViolation,
              details: const <Detail>[
                Detail(message: 'server text', code: 'goal_inactive'),
              ],
            ),
          );
      final GoRouter router = await pump(tester, '/goals/goal-1');
      unawaited(router.push<Object?>('/goals/goal-1/contribute'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount added'),
        '100',
      );
      await scrollTo(tester, find.text('Save contribution'));
      await tester.tap(find.text('Save contribution'));
      await tester.pumpAndSettle();
      await tester.drag(scrollable(), const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(
        find.text('Contributions can be added to active goals only.'),
        findsOneWidget,
      );
      expect(find.text('server text'), findsNothing);
    });
  });

  group('recording and paging contributions', () {
    testWidgets('more contributions load page by page', (
      WidgetTester tester,
    ) async {
      stubGoal(api);
      when(() => api.contributions('goal-1', cursor: any(named: 'cursor')))
          .thenAnswer(
            (_) async => contributionsPage(<GoalContributionDto>[
              contribution(),
            ], next: 'c2'),
          );
      when(() => api.contributions('goal-1', cursor: 'c2')).thenAnswer(
        (_) async => contributionsPage(<GoalContributionDto>[
          contribution(id: 'gc-old', date: '2026-01-15', note: 'Oldest one'),
        ]),
      );
      await pump(tester, '/goals/goal-1');
      await scrollTo(tester, find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      verify(() => api.contributions('goal-1', cursor: 'c2')).called(1);
      await scrollTo(tester, find.text('Oldest one'));
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('records a planned contribution once, with its own key', (
      WidgetTester tester,
    ) async {
      stubGoal(
        api,
        contributions: <GoalContributionDto>[
          contribution(id: 'gc-plan', status: 'planned', note: 'Next month'),
          contribution(id: 'gc-other', status: 'planned', mine: false),
        ],
      );
      final List<String> keys = <String>[];
      GoalContributionRecordInput? sent;
      when(
        () => api.recordContribution(
          'goal-1',
          'gc-plan',
          any(),
          key: any(named: 'key'),
        ),
      ).thenAnswer((Invocation i) async {
        keys.add(i.namedArguments[#key]! as String);
        sent = i.positionalArguments[2] as GoalContributionRecordInput;
        if (keys.length == 1) {
          throw offline;
        }
        return contribution(id: 'gc-plan');
      });
      await pump(tester, '/goals/goal-1');

      // Only the user's own planned contribution can be recorded.
      await scrollTo(tester, find.text('Record'));
      expect(find.text('Record'), findsOneWidget);
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
      expect(find.text('Record this planned contribution'), findsOneWidget);
      await tester.tap(find.text('Record contribution'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Check your internet connection'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Record contribution'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record contribution'));
      await tester.pumpAndSettle();
      expect(keys, hasLength(2));
      expect(keys.first, keys.last, reason: 'a retry reuses the key');
      // The planned amount is recorded as it is.
      expect(sent?.toJson(), <String, Object?>{});
      expect(find.text('Contribution recorded.'), findsOneWidget);
    });

    testWidgets('a contribution that was already recorded is explained', (
      WidgetTester tester,
    ) async {
      stubGoal(
        api,
        contributions: <GoalContributionDto>[
          contribution(id: 'gc-plan', status: 'planned'),
        ],
      );
      when(
        () => api.recordContribution(
          'goal-1',
          'gc-plan',
          any(),
          key: any(named: 'key'),
        ),
      ).thenThrow(
        serverError(
          ErrorObjectCode.conflict,
          status: 409,
          details: const <Detail>[
            Detail(
              code: 'contribution_not_planned',
              message: 'This contribution is already recorded.',
              params: <String, String>{'status': 'recorded'},
            ),
          ],
        ),
      );
      await pump(tester, '/goals/goal-1');
      await scrollTo(tester, find.text('Record'));
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record contribution'));
      await tester.pumpAndSettle();
      expect(
        find.text('This contribution is already recorded.'),
        findsOneWidget,
      );
    });

    testWidgets('the owner is listed as the owner and chooses what others '
        'see', (WidgetTester tester) async {
      stubGoal(
        api,
        detail: goal(
          members: <Map<String, Object?>>[
            goalMemberJson(id: 'u-ravi', name: 'Ravi', role: 'viewer'),
          ],
        ),
      );
      GoalMemberUpdate? update;
      when(
        () => api.updateMember(
          'goal-1',
          goalsTestUserId,
          any(),
          version: any(named: 'version'),
        ),
      ).thenAnswer((Invocation i) async {
        update = i.positionalArguments[2] as GoalMemberUpdate;
        return goal(version: 2);
      });
      await pump(tester, '/goals/goal-1');
      await scrollTo(tester, find.text('Asha Rao (you)'));
      expect(find.text('Owner · Shows amounts'), findsOneWidget);
      expect(find.textContaining("You can't leave it"), findsOneWidget);
      await tester.tap(find.text('Asha Rao (you)'));
      await tester.pumpAndSettle();
      expect(find.text('Leave goal'), findsNothing);
      expect(find.text('Remove from goal'), findsNothing);
      await tester.tap(find.text('Shows percentages only'));
      await tester.pumpAndSettle();
      expect(
        update?.contributionVisibility,
        GoalMemberUpdateContributionVisibility.percentOnly,
      );
      verify(
        () => api.updateMember('goal-1', goalsTestUserId, any(), version: 1),
      ).called(1);
    });
  });

  group('export', () {
    testWidgets('shares and saves the CSV file', (WidgetTester tester) async {
      when(() => api.export('goal-1')).thenAnswer(
        (_) async => const GoalExport(
          csv: 'date,amount\n2026-11-05,2500.00\n',
          fileName: 'goal-contributions-2026-11-05.csv',
        ),
      );
      final FakeFileExporter exporter = FakeFileExporter();
      await pump(
        tester,
        '/goals/goal-1/export',
        extra: <Override>[fileExporterProvider.overrideWithValue(exporter)],
      );
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(exporter.shared.single.name, 'goal-contributions-2026-11-05.csv');
      expect(exporter.shared.single.mimeType, 'text/csv');
      await tester.tap(find.text('Save to device'));
      await tester.pumpAndSettle();
      expect(exporter.saved.single.name, 'goal-contributions-2026-11-05.csv');
      expect(find.text('Saved.'), findsOneWidget);
    });

    testWidgets('previews the CSV and copies it', (WidgetTester tester) async {
      when(() => api.export('goal-1')).thenAnswer(
        (_) async => const GoalExport(
          csv:
              'date,contributor,kind,status,amount,currency,'
              'share_of_target_percent,voided,note\n'
              '2026-11-05,Asha,contribution,recorded,2500.00,INR,,no,first\n',
          fileName: 'emergency-fund-contributions.csv',
        ),
      );
      final List<MethodCall> calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(tester, '/goals/goal-1/export');

      expect(find.text('Export contributions'), findsOneWidget);
      expect(find.text('emergency-fund-contributions.csv'), findsOneWidget);
      expect(find.text('1 row'), findsOneWidget);
      expect(find.textContaining('2026-11-05,Asha'), findsOneWidget);
      await tester.tap(find.text('Copy CSV'));
      await tester.pumpAndSettle();
      final MethodCall copy = calls.firstWhere(
        (MethodCall c) => c.method == 'Clipboard.setData',
      );
      expect(
        (copy.arguments as Map<Object?, Object?>)['text'],
        startsWith('date,contributor'),
      );
      expect(find.textContaining('CSV copied.'), findsOneWidget);
    });

    testWidgets('a failed export offers a retry', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.export('goal-1')).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return const GoalExport(csv: 'date,amount\n');
      });
      await pump(tester, '/goals/goal-1/export');
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No rows yet'), findsOneWidget);
      expect(
        find.text(
          'There are no contributions yet, so only the column names are '
          'included.',
        ),
        findsOneWidget,
      );
    });
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('goal screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final GoalDto long = goal(
        name: 'A very long goal name for the family emergency fund',
        members: <Map<String, Object?>>[
          goalMemberJson(id: 'u-ravi', name: 'Ravindra Krishnamurthy'),
        ],
        status: 'paused',
        description: 'A long description that wraps over several lines.',
      );
      when(() => api.list(status: any(named: 'status')))
          .thenAnswer((_) async => <GoalDto>[long, goal(id: 'goal-2')]);
      stubGoal(
        api,
        detail: long,
        contributions: <GoalContributionDto>[
          contribution(note: 'A fairly long note about this contribution'),
          contribution(id: 'gc-2', amount: null, percentBp: 1234, mine: false),
          contribution(id: 'gc-3', status: 'planned', note: 'Planned saving'),
        ],
      );
      when(() => api.export('goal-1')).thenAnswer(
        (_) async => const GoalExport(
          csv:
              'date,contributor,kind,status,amount\n'
              '2026-11-05,Asha,contribution,recorded,2500.00\n',
          fileName: 'a-very-long-goal-name-contributions.csv',
        ),
      );
      final ({Widget app, GoRouter router}) r = routedApp(
        '/goals',
        overrides: [
          goalsApiProvider.overrideWithValue(api),
          accountsApiProvider.overrideWithValue(accounts),
          peopleApiProvider.overrideWithValue(people),
          transactionsApiProvider.overrideWithValue(transactions),
          labelsApiProvider.overrideWithValue(labels),
        ],
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final String location in <String>[
        '/goals/goal-1',
        '/goals/new',
        '/goals/goal-1/edit',
        '/goals/goal-1/contribute',
        '/goals/goal-1/export',
      ]) {
        r.router.go(location);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
        for (int i = 0; i < 10; i++) {
          await tester.drag(scrollable(), const Offset(0, -600));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: location);
      }
      // The sheet that records a planned contribution (active goals).
      when(() => api.get('goal-1')).thenAnswer(
        (_) async => goal(
          name: 'A very long goal name for the family emergency fund',
          members: <Map<String, Object?>>[
            goalMemberJson(id: 'u-ravi', name: 'Ravindra Krishnamurthy'),
          ],
        ),
      );
      r.router.go('/goals/goal-1');
      await tester.pumpAndSettle();
      final Finder record = find.text(
        locale.languageCode == 'hi' ? 'दर्ज करें' : 'Record',
      );
      await tester.scrollUntilVisible(record, 300, scrollable: scrollable());
      await tester.pumpAndSettle();
      await tester.tap(record);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'record sheet');
    });
  }
}
