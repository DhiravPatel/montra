import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/group_money_fakes.dart';

/// Who may do what, the form helpers and the localized coded errors.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('hi');
  });

  final GroupPeople owner = GroupPeople(goaGroup(), me);
  final GroupPeople member = GroupPeople(goaGroup(myRole: 'member'), me);

  group('settlement actions follow the status and the role', () {
    test('payer of a planned payment marks it paid', () {
      expect(
        settlementActionsFor(
          settlement(status: 'proposed', payer: me, payee: ravi),
          member,
        ),
        <SettlementAction>[SettlementAction.markPaid, SettlementAction.voidIt],
      );
    });

    test('payee confirms or disputes a reported payment', () {
      expect(settlementActionsFor(settlement(), member), <SettlementAction>[
        SettlementAction.confirm,
        SettlementAction.dispute,
        SettlementAction.voidIt,
      ]);
    });

    test('the payer records a reported payment; the payee only once it is '
        'confirmed', () {
      expect(
        settlementActionsFor(settlement(payer: me, payee: ravi), member),
        contains(SettlementAction.record),
      );
      expect(
        settlementActionsFor(settlement(), member),
        isNot(contains(SettlementAction.record)),
      );
      expect(
        settlementActionsFor(settlement(status: 'confirmed'), member),
        contains(SettlementAction.record),
      );
      expect(
        settlementActionsFor(
          settlement(status: 'confirmed', myTransactionId: 'tx-1'),
          member,
        ),
        <SettlementAction>[
          SettlementAction.dispute,
          SettlementAction.unlink,
          SettlementAction.voidIt,
        ],
      );
    });

    test('an admin confirms for a former member; a plain member cannot', () {
      final SettlementDto toFormer = settlement(payer: ravi, payee: former);
      expect(
        settlementActionsFor(toFormer, owner),
        contains(SettlementAction.confirm),
      );
      expect(settlementActionsFor(toFormer, member), isEmpty);
    });

    test('voided payments only allow removing my own record', () {
      expect(
        settlementActionsFor(
          settlement(status: 'voided', myTransactionId: 'tx-1'),
          owner,
        ),
        <SettlementAction>[SettlementAction.unlink],
      );
      expect(
        canCorrectSettlement(settlement(status: 'voided'), owner),
        isFalse,
      );
      expect(canCorrectSettlement(settlement(), member), isTrue);
    });
  });

  test('expenses: the creator or an admin deletes; members edit', () {
    expect(canDeleteExpense(expenseDetail(createdBy: ravi), owner), isTrue);
    expect(canDeleteExpense(expenseDetail(createdBy: ravi), member), isFalse);
    expect(canEditExpense(expenseDetail(createdBy: ravi), member), isTrue);
    expect(canEditExpense(expenseDetail(status: 'deleted'), owner), isFalse);
    final GroupPeople archived = GroupPeople(goaGroup(status: 'archived'), me);
    expect(canEditExpense(expenseDetail(), archived), isFalse);
  });

  test('recurring: the creator or an admin manages it', () {
    expect(canManageRecurring(recurring(createdBy: ravi), owner), isTrue);
    expect(canManageRecurring(recurring(createdBy: ravi), member), isFalse);
    expect(canManageRecurring(recurring(), member), isTrue);
  });

  test('people: names, you and former members', () async {
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(owner.name(l10n, me), 'You');
    expect(owner.name(l10n, ravi), 'Ravi Kumar');
    expect(owner.name(l10n, 'u-gone', fallback: 'Gone Person'), 'Gone Person');
    expect(owner.name(l10n, 'u-gone'), 'Former member');
    expect(owner.activeMembers.first.userId, me);
    expect(
      owner.activeMembers.map((GroupMemberDto m) => m.userId),
      isNot(contains(former)),
    );
    expect(
      owner.everyone.map((GroupMemberDto m) => m.userId),
      contains(former),
    );
  });

  test('form helpers', () {
    expect(minorOf('1234.50', 2), 123450);
    expect(minorOf('5', 2), 500);
    expect(minorOf('-0.07', 2), -7);
    expect(minorOf('1.234', 2), isNull);
    expect(hundredthsOfPercent('33.33'), 3333);
    expect(hundredthsOfPercent('33,3'), 3330);
    expect(hundredthsOfPercent('abc'), isNull);
    expect(percentWire(' 33,34 '), '33.34');
    expect(isWholeShares('2'), isTrue);
    expect(isWholeShares('0'), isFalse);
    expect(isValidRate('83.25'), isTrue);
    expect(isValidRate('0'), isFalse);
    expect(isValidRate('0.000000000001'), isTrue);
    expect(absMoney(money('-6964.83')).amount, '6964.83');
    expect(netDirection(money('-1.00')), NetDirection.owes);
    expect(netDirection(money('0.00')), NetDirection.settled);
    expect(
      const GroupExpenseFilter(status: 'deleted').toQuery(),
      <String, Object?>{
        'status': 'deleted',
        'include_deleted': true,
        'from': null,
        'to': null,
        'payer_user_id': null,
        'category_key': null,
      },
    );
  });

  group('coded errors are localized in English and Hindi', () {
    Future<void> check(
      Locale locale,
      Detail detail,
      ErrorObjectCode code,
      String expected,
    ) async {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        locale,
      );
      expect(
        describeError(l10n, serverError(code, details: <Detail>[detail])),
        expected,
      );
    }

    test('English', () async {
      await check(
        const Locale('en'),
        const Detail(
          code: 'fx_rate_unavailable',
          message: 'x',
          params: <String, String>{
            'from': 'JPY',
            'to': 'INR',
            'date': '2026-11-04',
          },
        ),
        ErrorObjectCode.domainRuleViolation,
        'Montra has no JPY to INR rate for Nov 4, 2026. Enter the rate you used.',
      );
      await check(
        const Locale('en'),
        const Detail(
          code: 'settlement_not_proposed',
          message: 'x',
          params: <String, String>{'status': 'user_reported_paid'},
        ),
        ErrorObjectCode.conflict,
        'Only a planned payment can be marked paid. It is now: Waiting for confirmation.',
      );
      await check(
        const Locale('en'),
        const Detail(code: 'payers_total_mismatch', message: 'x'),
        ErrorObjectCode.domainRuleViolation,
        'What the payers paid must add up to the total.',
      );
    });

    test('Hindi', () async {
      await check(
        const Locale('hi'),
        const Detail(code: 'expense_deleted', message: 'x'),
        ErrorObjectCode.conflict,
        'यह खर्च हटा दिया गया, इसलिए अब बदला नहीं जा सकता।',
      );
    });

    test('unknown codes keep the server message', () async {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(
        describeError(
          l10n,
          serverError(
            ErrorObjectCode.domainRuleViolation,
            details: const <Detail>[
              Detail(code: 'brand_new', message: 'Server text'),
            ],
          ),
        ),
        'Server text',
      );
      expect(ApiErrorKind.server, isNotNull);
    });
  });
}
