import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockPaymentMethodsApi api;
  late MockAccountsApi accounts;

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    api = MockPaymentMethodsApi();
    accounts = MockAccountsApi();
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
  });

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: [
        paymentMethodsApiProvider.overrideWithValue(api),
        accountsApiProvider.overrideWithValue(accounts),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  testWidgets('lists methods with masked hints and removes after confirming', (
    WidgetTester tester,
  ) async {
    bool removed = false;
    when(() => api.list()).thenAnswer(
      (_) async => <PaymentMethodDto>[
        paymentMethod(isDefault: true, accountId: 'acc-1'),
        if (!removed)
          paymentMethod(
            id: 'pm-2',
            kind: 'cash',
            label: 'Wallet cash',
            hint: null,
          ),
      ],
    );
    when(() => api.remove('pm-2')).thenAnswer((_) async {
      removed = true;
      return const PaymentMethodDeleteResult(archived: false, deleted: true);
    });
    await pump(tester, '/payment-methods');

    expect(find.text('GPay'), findsOneWidget);
    expect(find.text('UPI · ••21 · Linked to HDFC Savings'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Wallet cash'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Wallet cash'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this payment method?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    verify(() => api.remove('pm-2')).called(1);
    expect(find.text('Payment method removed.'), findsOneWidget);
    expect(find.text('Wallet cash'), findsNothing);
  });

  testWidgets('shows an empty state with a way to add one', (
    WidgetTester tester,
  ) async {
    when(() => api.list()).thenAnswer((_) async => <PaymentMethodDto>[]);
    await pump(tester, '/payment-methods');

    expect(find.text('No payment methods yet'), findsOneWidget);
    expect(find.text('Add payment method'), findsWidgets);
  });

  testWidgets('refuses full card numbers and sends the complete method', (
    WidgetTester tester,
  ) async {
    when(() => api.list()).thenAnswer((_) async => <PaymentMethodDto>[]);
    PaymentMethodInput? sent;
    when(() => api.create(any())).thenAnswer((Invocation i) async {
      sent = i.positionalArguments.first as PaymentMethodInput;
      return paymentMethod();
    });
    final GoRouter router = await pump(tester, '/payment-methods');
    unawaited(router.push<Object?>('/payment-methods/new'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'HDFC card',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Masked hint (optional)'),
      '4111 1111',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Use at most 4 digits'), findsOneWidget);
    verifyNever(() => api.create(any()));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Masked hint (optional)'),
      '•••• 4821',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(sent?.label, 'HDFC card');
    expect(sent?.kind, PaymentMethodInputKind.upi);
    expect(sent?.maskedHint, '•••• 4821');
    expect(sent?.isDefault, isFalse);
    expect(find.text('Payment method added.'), findsOneWidget);
  });

  testWidgets('edits send only the change; a stale version reloads first', (
    WidgetTester tester,
  ) async {
    when(() => api.list())
        .thenAnswer((_) async => <PaymentMethodDto>[paymentMethod()]);
    int loads = 0;
    when(() => api.get('pm-1')).thenAnswer((_) async {
      loads++;
      return loads == 1
          ? paymentMethod()
          : PaymentMethodDto.fromJson(<String, Object?>{
              ...paymentMethod(label: 'GPay personal').toJson(),
              'version': 2,
            });
    });
    final List<PaymentMethodPatch> sent = <PaymentMethodPatch>[];
    when(() => api.update('pm-1', any())).thenAnswer((Invocation i) async {
      sent.add(i.positionalArguments[1] as PaymentMethodPatch);
      if (sent.length == 1) {
        throw serverError(ErrorObjectCode.versionConflict, status: 409);
      }
      return paymentMethod(label: 'GPay personal', hint: null);
    });
    final GoRouter router = await pump(tester, '/payment-methods');
    unawaited(router.push<Object?>(AppRoutes.editPaymentMethod('pm-1')));
    await tester.pumpAndSettle();

    // Clearing the hint sends an empty string, and nothing else changes.
    final Finder hint = find.widgetWithText(
      TextFormField,
      'Masked hint (optional)',
    );
    await tester.enterText(hint, '');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(sent.first.version, 1);
    expect(sent.first.maskedHint, '');
    expect(sent.first.label, isNull);
    expect(sent.first.kind, isNull);
    expect(sent.first.clearAccount, isNull);

    // The newer version is loaded and the user is told to redo the change.
    expect(find.textContaining('changed somewhere else'), findsOneWidget);
    expect(find.text('GPay personal'), findsOneWidget);
    await tester.enterText(hint, '');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(sent.last.version, 2);
    expect(sent.last.maskedHint, '');
    expect(find.text('Payment method saved.'), findsOneWidget);
  });

  testWidgets('a used method is archived on remove and can be restored', (
    WidgetTester tester,
  ) async {
    bool archived = false;
    when(() => api.list()).thenAnswer(
      (_) async => <PaymentMethodDto>[if (!archived) paymentMethod()],
    );
    when(() => api.list(includeArchived: true)).thenAnswer(
      (_) async => <PaymentMethodDto>[paymentMethod(archived: archived)],
    );
    when(() => api.remove('pm-1')).thenAnswer((_) async {
      archived = true;
      return const PaymentMethodDeleteResult(archived: true, deleted: false);
    });
    when(() => api.restore('pm-1')).thenAnswer((_) async {
      archived = false;
      return paymentMethod();
    });
    await pump(tester, '/payment-methods');

    await tester.tap(find.byTooltip('Remove GPay'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Archived because transactions use it'),
      findsOneWidget,
    );
    expect(find.text('GPay'), findsNothing);

    await tester.tap(find.text('Show archived methods'));
    await tester.pumpAndSettle();
    expect(find.text('GPay'), findsOneWidget);
    await tester.tap(find.byTooltip('Restore GPay'));
    await tester.pumpAndSettle();
    verify(() => api.restore('pm-1')).called(1);
    expect(find.text('Payment method restored.'), findsOneWidget);
    expect(find.byTooltip('Remove GPay'), findsOneWidget);
  });
}
