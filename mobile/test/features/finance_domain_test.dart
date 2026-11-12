import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/features/accounts/domain/account_types.dart';
import 'package:montra_mobile/features/accounts/presentation/account_widgets.dart';
import 'package:montra_mobile/features/dashboard/application/dashboard_providers.dart';
import 'package:montra_mobile/features/dashboard/presentation/dashboard_widgets.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_form_screen.dart';

import '../helpers/finance_fakes.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations hi;

  setUpAll(() async {
    await initializeDateFormatting('en');
    en = lookupAppLocalizations(const Locale('en'));
    hi = lookupAppLocalizations(const Locale('hi'));
  });

  group('accounts', () {
    test('groups by type in a fixed order, active first, then by name', () {
      final List<AccountGroup> groups = groupAccounts(<AccountDto>[
        account(
          id: 'c',
          name: 'Visa',
          type: 'credit_card',
          balance: '-3200.00',
        ),
        account(id: 'b2', name: 'Zeta bank', type: 'bank'),
        account(id: 'b1', name: 'Axis', type: 'bank', status: 'archived'),
        account(id: 'w', name: 'Wallet', type: 'cash'),
        account(id: 'b3', name: 'Alpha bank', type: 'bank'),
        account(id: 'x', name: 'Odd', type: 'future_type'),
      ]);
      expect(
        groups.map((AccountGroup g) => g.type).toList(),
        <AccountInputAccountType>[
          AccountInputAccountType.cash,
          AccountInputAccountType.bank,
          AccountInputAccountType.creditCard,
          AccountInputAccountType.custom,
        ],
      );
      expect(groups[1].accounts.map((AccountDto a) => a.id).toList(), <String>[
        'b3',
        'b2',
        'b1',
      ]);
    });

    test('liability balances read as amounts owed without a sign', () {
      final AccountDto card = account(type: 'credit_card', balance: '-3200.00');
      expect(balanceKindOf(card), BalanceKind.owed);
      expect(unsignedMoney(card.balance).amount, '3200.00');
      expect(unsignedMoney(card.balance).amountMinor, 320000);
      expect(
        balanceKindOf(account(type: 'credit_card', balance: '50.00')),
        BalanceKind.inCredit,
      );
      expect(balanceKindOf(account(balance: '-1.00')), BalanceKind.overdrawn);
      expect(balanceKindOf(account()), BalanceKind.normal);
      expect(isUsableAccount(account(status: 'archived')), isFalse);
      expect(isUsableAccount(account(owned: false)), isFalse);
    });
  });

  group('categories', () {
    test('starter names are localized unless the user renamed them', () {
      expect(categoryName(hi, category()), 'किराना');
      expect(categoryName(en, category()), 'Groceries');
      expect(categoryName(hi, category(name: 'Kirana store')), 'Kirana store');
      expect(categoryName(hi, category(systemKey: null, name: 'Pets')), 'Pets');
    });

    test('trees put subcategories under their parent', () {
      final List<(CategoryDto, int)> tree = categoryTree(<CategoryDto>[
        category(
          id: 'child',
          name: 'Vegetables',
          systemKey: null,
          parentId: 'g',
        ),
        category(id: 'g', sortOrder: 10),
        category(id: 'f', name: 'Fuel', systemKey: 'fuel', sortOrder: 5),
      ]);
      expect(
        tree.map(((CategoryDto, int) e) => '${e.$1.id}:${e.$2}').toList(),
        <String>['f:0', 'g:0', 'child:1'],
      );
    });

    test('kind filters mirror the server rule', () {
      final CategoryDto income = category(kind: 'income');
      final CategoryDto both = category(kind: 'both');
      expect(categoryMatches(income, CategoryKindFilter.spending), isFalse);
      expect(categoryMatches(income, CategoryKindFilter.income), isTrue);
      expect(categoryMatches(both, CategoryKindFilter.spending), isTrue);
    });
  });

  test('audit changes are described with formatted amounts and dates', () {
    final AuditEventDto event = AuditEventDto.fromJson(<String, Object?>{
      'id': 21,
      'action': 'updated',
      'actor_kind': 'user',
      'version': 2,
      'changes': <String, Object?>{
        'amount_minor': <String, Object?>{'from': 125075, 'to': 130075},
        'local_date': <String, Object?>{
          'from': '2026-11-03',
          'to': '2026-11-04',
        },
        'notes_changed': <String, Object?>{'from': false, 'to': true},
      },
      'created_at': '2026-11-04T13:16:24Z',
    });
    final List<String> lines = auditChangeLines(
      en,
      event,
      currency: 'INR',
      numberLocale: 'en_IN',
      dateLocale: 'en',
    );
    expect(lines, <String>[
      'Amount: ₹1,250.75 → ₹1,300.75',
      'Date: Nov 3, 2026 → Nov 4, 2026',
      'Notes changed',
    ]);
    expect(
      auditActionLabel(hi, AuditEventDtoAction.refundAdded),
      'रिफ़ंड दर्ज हुआ',
    );
    expect(
      auditActorLabel(en, AuditEventDtoActorKind.recurring),
      'by a recurring rule',
    );
  });

  test('onboarding progress replaces skips with later answers', () {
    const OnboardingProgress start = OnboardingProgress();
    final OnboardingProgress p = start
        .complete(<String>['welcome'])
        .skip(<String>['income', 'welcome'])
        .complete(<String>['income']);
    expect(p.completed, <String>['welcome', 'income']);
    expect(p.skipped, isEmpty);
  });

  group('dashboard', () {
    test('layout sorts by position and keeps ties stable', () {
      final List<WidgetDto> sorted = DashboardLayoutController.sortLayout(
        <WidgetDto>[
          const WidgetDto(
            key: WidgetDtoKey.cashFlow,
            position: 2,
            settings: null,
            visible: true,
          ),
          const WidgetDto(
            key: WidgetDtoKey.balances,
            position: 0,
            settings: null,
            visible: true,
          ),
          const WidgetDto(
            key: WidgetDtoKey.topMerchants,
            position: 2,
            settings: null,
            visible: false,
          ),
        ],
      );
      expect(sorted.map((WidgetDto w) => w.key).toList(), <WidgetDtoKey>[
        WidgetDtoKey.balances,
        WidgetDtoKey.cashFlow,
        WidgetDtoKey.topMerchants,
      ]);
    });

    test('currencies list the base currency first and are never mixed', () {
      final DashboardSummary s = summary(withUsd: true);
      expect(dashboardCurrencies(s, 'USD'), <String>['USD', 'INR']);
      expect(dashboardCurrencies(s, null), <String>['INR', 'USD']);
      final DashboardContext usd = DashboardContext(
        summary: s,
        currency: 'USD',
      );
      expect(usd.cashFlow?.netExpense.amount, '40.00');
      expect(usd.categories, isEmpty);
      final DashboardContext inr = DashboardContext(
        summary: s,
        currency: 'INR',
      );
      expect(inr.trend.map((SeriesPoint p) => p.bucket).toList(), <String>[
        '2026-11-03',
        '2026-11-04',
      ]);
      expect(formatBasisPoints(9881, 'en'), '98.8%');
    });
  });

  group('coded server messages', () {
    test('calculation notes are localized by code, unknown ones kept', () {
      final DashboardSummary s = DashboardSummary.fromJson(<String, Object?>{
        ...summary().toJson(),
        'notes': <String>['Transfers note', 'Refunds note', 'A new note'],
        'note_codes': <String>[
          'excludes_transfers_adjustments',
          'refunds_reduce_spending',
          'some_future_code',
        ],
      });
      expect(dashboardNotes(en, s), <String>[
        en.noteExcludesTransfers,
        en.noteRefundsReduceSpending,
        'A new note',
      ]);
      expect(dashboardNotes(hi, s).first, hi.noteExcludesTransfers);
    });

    test('duplicate hints explain the match from reason codes', () {
      const DuplicateHint hint = DuplicateHint(
        daysApart: 2,
        localDate: '2026-11-02',
        reasonCodes: <String>[
          'same_account_amount',
          'within_days',
          'unknown_reason',
        ],
        reasons: <String>[],
        transactionId: 'tx-9',
      );
      expect(
        duplicateReasons(en, hint),
        'same account and amount, 2 days apart',
      );
    });

    test('finance rule violations are localized with their params', () {
      expect(
        detailMessage(
          en,
          const Detail(
            message: 'server text',
            code: 'refund_exceeds_remaining',
            params: <String, String>{'remaining': '150.00', 'currency': 'INR'},
          ),
        ),
        contains('150.00 INR can still be refunded'),
      );
      expect(
        detailMessage(
          en,
          const Detail(
            message: 'server text',
            code: 'currency_mismatch',
            params: <String, String>{'currency': 'USD'},
          ),
        ),
        'Use the same currency as the original (USD).',
      );
      expect(
        detailMessage(en, const Detail(message: 'Server text', code: 'new')),
        'Server text',
      );
      expect(
        describeError(
          en,
          serverError(
            ErrorObjectCode.domainRuleViolation,
            details: const <Detail>[
              Detail(message: 'm', code: 'has_linked_refunds'),
            ],
          ),
        ),
        en.ruleHasLinkedRefunds,
      );
    });

    test('the uncategorized slice uses the localized name', () {
      final CategorySlice slice = CategorySlice.fromJson(<String, Object?>{
        'category_id': 'cat-u',
        'system_key': 'uncategorized',
        'name': 'Uncategorized',
        'count': 1,
        'currency': 'INR',
        'drill_down_path': '/transactions?uncategorized=true',
        'amount': moneyJson('10.00'),
        'net_expense': moneyJson('10.00'),
        'share_bp': 100,
        'subcategory': false,
      });
      expect(categorySliceName(hi, slice), hi.categoryUncategorized);
    });
  });
}
