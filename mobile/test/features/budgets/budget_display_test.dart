import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/budgets/domain/budget_display.dart';
import 'package:montra_mobile/features/budgets/presentation/allocation_editor.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_detail_sections.dart';

import '../../helpers/budgets_fakes.dart';

void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  final AppLocalizations hi = lookupAppLocalizations(const Locale('hi'));

  String money(String amount, String currency) => '$amount $currency';
  String date(String d) => d;

  group('explanation', () {
    test('localizes the server items and says what counts', () {
      final BudgetDto b = BudgetDto.fromJson(<String, Object?>{
        ...budgetJson(includePending: true),
        'refunds_restore': false,
      });
      final ProgressDto p = ProgressDto.fromJson(
        progressJson(
          rolloverIn: '250.00',
          otherCurrencyCount: 2,
          refundsRestore: false,
        ),
      );
      final List<String> notes = budgetExplanation(
        en,
        budget: b,
        progress: p,
        money: money,
        date: date,
      );
      expect(notes, <String>[
        en.budgetExplainSpent(
          '4000.00 INR',
          '10000.00 INR',
          '2026-11-01',
          '2026-11-30',
        ),
        en.budgetExplainRefundsIgnored,
        en.budgetExplainPending,
        'Includes 250.00 INR carried over from the previous period.',
        en.budgetExplainProjected('10000.00 INR'),
        "2 matching transactions in other currencies aren't included.",
      ]);
      final List<String> hindi = budgetExplanation(
        hi,
        budget: b,
        progress: p,
        money: money,
        date: date,
      );
      expect(hindi[1], hi.budgetExplainRefundsIgnored);
      expect(hindi, contains(hi.budgetExplainOtherCurrency(2)));
    });

    test('collaborators are told they see totals; group budgets say what '
        'they count; unknown codes fall back to the English line', () {
      final List<String> shared = budgetExplanation(
        en,
        budget: budget(access: 'viewer', owner: 'u-asha'),
        progress: ProgressDto.fromJson(
          progressJson(elapsedDays: 30, totalDays: 30, collaborator: true),
        ),
        money: money,
        date: date,
      );
      expect(shared.last, en.budgetExplainCollaborator);
      expect(
        shared,
        isNot(contains(en.budgetExplainProjected('10000.00 INR'))),
      );

      final List<String> group = budgetExplanation(
        hi,
        budget: budget(groupId: 'grp-home', access: 'viewer', owner: 'u-asha'),
        progress: ProgressDto.fromJson(progressJson()),
        money: money,
        date: date,
      );
      expect(group[2], hi.budgetExplainGroup);
      expect(group, isNot(contains(hi.budgetExplainPostedOnly)));

      final List<String> unknown = budgetExplanation(
        en,
        budget: budget(),
        progress: ProgressDto.fromJson(<String, Object?>{
          ...progressJson(
            explanationItems: <Map<String, Object?>>[
              <String, Object?>{'code': 'something_new'},
            ],
          ),
          'explanation': <String>['A new kind of note.'],
        }),
        money: money,
        date: date,
      );
      expect(unknown, <String>[
        'A new kind of note.',
        en.budgetExplainPostedOnly,
      ]);
    });
  });

  test('pace reads in words with a tone and icon of its own', () {
    for (final ProgressDtoPace pace in ProgressDtoPace.values) {
      expect(budgetPaceLabel(hi, pace), isNotEmpty);
    }
    expect(budgetPaceLabel(en, ProgressDtoPace.overBudget), 'Over the limit');
    expect(budgetPaceTone(ProgressDtoPace.onTrack), StatusTone.positive);
    expect(budgetPaceTone(ProgressDtoPace.aheadOfPace), StatusTone.caution);
    expect(
      budgetPaceIcon(ProgressDtoPace.aheadOfPace),
      isNot(budgetPaceIcon(ProgressDtoPace.overBudget)),
    );
  });

  test('alert titles name the budget and the level', () {
    expect(
      budgetAlertTitle(en, budgetAlert(threshold: 75)),
      'Monthly spending: 75% of the limit used',
    );
    expect(
      budgetAlertTitle(en, budgetAlert(threshold: 100)),
      'Monthly spending: the whole limit is used',
    );
    expect(
      budgetAlertTitle(en, budgetAlert(threshold: 125)),
      'Monthly spending: 125% of the limit used',
    );
    expect(
      budgetAlertTitle(hi, budgetAlert(kind: 'forecast_overspend')),
      hi.budgetAlertForecast('Monthly spending'),
    );
    expect(
      budgetAlertTitle(en, budgetAlert(kind: 'something_new')),
      'An update about Monthly spending',
    );
  });

  test('labels cover every type, period and policy', () {
    for (final BudgetInputBudgetType t in BudgetInputBudgetType.values) {
      expect(budgetTypeLabel(hi, t), isNotEmpty);
      expect(budgetTypeHelp(hi, t), isNotEmpty);
    }
    for (final BudgetInputPeriod p in BudgetInputPeriod.values) {
      expect(budgetPeriodLabel(hi, p), isNotEmpty);
    }
    for (final BudgetInputRolloverPolicy r
        in BudgetInputRolloverPolicy.values) {
      expect(budgetRolloverLabel(hi, r), isNotEmpty);
    }
    expect(
      budgetInputType(BudgetDtoBudgetType.zeroBased),
      BudgetInputBudgetType.zeroBased,
    );
    expect(budgetNeedsAllocations(BudgetInputBudgetType.total), isFalse);
    expect(budgetNeedsAllocations(BudgetInputBudgetType.envelope), isTrue);
  });

  test('threshold choices are the published levels; group budgets take '
      'total, envelope or zero-based types', () {
    expect(budgetThresholdOptions, <int>[
      1, 5, 10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 95, 100, 110, 125, //
      150,
    ]);
    expect(groupBudgetTypes, <BudgetInputBudgetType>[
      BudgetInputBudgetType.total,
      BudgetInputBudgetType.envelope,
      BudgetInputBudgetType.zeroBased,
    ]);
    expect(
      allocationTargetsFor(group: true, type: BudgetInputBudgetType.envelope),
      <AllocationTarget>[AllocationTarget.member],
    );
    expect(
      allocationTargetsFor(group: false, type: BudgetInputBudgetType.total),
      <AllocationTarget>[AllocationTarget.category, AllocationTarget.name],
    );
    expect(
      allocationTargetsFor(group: false, type: BudgetInputBudgetType.account),
      contains(AllocationTarget.account),
    );
    expect(
      allocationTargetsFor(group: false, type: BudgetInputBudgetType.total),
      isNot(contains(AllocationTarget.merchant)),
    );
  });

  test('the stored budget becomes the same input the form builds', () {
    final BudgetDto b = BudgetDto.fromJson(
      budgetJson(
        type: 'merchant',
        merchantIds: <String>['mer-1'],
        thresholds: <int>[90, 50],
        rollover: 'carry_both',
        rolloverCap: '300.00',
        notes: '  Weekly shop  ',
        allocations: <Map<String, Object?>>[
          allocationJson(merchantId: 'mer-1', label: ' Big '),
        ],
      ),
    );
    final BudgetInput input = budgetInputOf(b);
    expect(input.merchantIds, <String>['mer-1']);
    expect(input.alertThresholds, <int>[50, 90]);
    expect(input.rolloverCap, '300.00');
    expect(input.notes, 'Weekly shop');
    expect(input.version, 3);
    expect(input.allocations!.single.toJson(), <String, Object?>{
      'label': 'Big',
      'limit': '6000.00',
      'merchant_id': 'mer-1',
    });
    expect(
      budgetSharedByLabel(en, budget(access: 'editor', owner: 'u-asha')),
      'Shared by Asha Rao · can edit',
    );
    expect(budgetSharedByLabel(en, budget()), isNull);
  });

  test('percentages and period steps', () {
    expect(budgetPercent(4050, 'en'), '40.5%');
    expect(budgetBarFraction(12500), 1);
    expect(budgetBarFraction(2500), 0.25);
    expect(dayBefore('2026-03-01'), '2026-02-28');
    expect(dayBefore('2026-01-01'), '2025-12-31');
    expect(dayBefore('not a date'), isNull);
  });

  test('allocation drafts round-trip to request items', () {
    final AllocationDraft member = AllocationDraft.fromDto(
      AllocationDto.fromJson(
        allocationJson(memberUserId: 'u-ravi', label: '  Ravi food '),
      ),
    );
    expect(member.target, AllocationTarget.member);
    final AllocInput input = member.toInput();
    expect(input.memberUserId, 'u-ravi');
    expect(input.categoryId, isNull);
    expect(input.label, 'Ravi food');
    expect(input.limit, '6000.00');

    final AllocationDraft named = AllocationDraft.fromDto(
      AllocationDto.fromJson(allocationJson(label: 'Fun money')),
    );
    expect(named.target, AllocationTarget.name);
    expect(named.toInput().toJson().keys, <String>['label', 'limit']);
  });
}
