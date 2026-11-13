import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_period_reports.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

import '../../helpers/insights_fakes.dart';

void main() {
  test('the bucket without a payment method is named by its key', () async {
    final AppLocalizations en = await AppLocalizations.delegate.load(
      const Locale('en'),
    );
    final AppLocalizations hi = await AppLocalizations.delegate.load(
      const Locale('hi'),
    );
    final List<PaymentMethodSlice> slices =
        paymentMethodReport().paymentMethods;
    final PaymentMethodSlice none = slices.firstWhere(
      (PaymentMethodSlice s) => s.key == 'unspecified',
    );
    expect(paymentMethodSliceName(en, none), 'No payment method');
    expect(paymentMethodSliceName(hi, none), 'कोई भुगतान तरीका नहीं');
    expect(paymentMethodSliceDetail(en, none), isNull);
    expect(paymentMethodSliceName(en, slices.first), 'HDFC Card');
    expect(paymentMethodSliceDetail(en, slices.first), 'Credit card ·· 4321');
    expect(paymentMethodSliceName(hi, slices[2]), 'Old wallet (संग्रहित)');
  });

  test('transactions accept payment_method_id=none from links and saved '
      'filters', () {
    final TransactionFilter linked = TransactionFilter.fromQuery(
      <String, String>{'payment_method_id': 'none', 'currency': 'INR'},
    );
    expect(linked.withoutPaymentMethod, isTrue);
    expect(linked.toQuery()['payment_method_id'], 'none');
    expect(
      Uri.parse(linked.toLocation()).queryParameters['payment_method_id'],
      'none',
    );
    final TransactionFilter saved = TransactionFilter.fromSavedJson(
      <String, Object?>{'payment_method_id': 'none'},
    )!;
    expect(saved.paymentMethodId, TransactionFilter.noPaymentMethod);
    expect(
      TransactionFilter.fromSavedJson(<String, Object?>{
        'payment_method_id': 'nothing',
      }),
      isNull,
    );
  });

  test('503 provider and storage errors say to try again later', () async {
    final AppLocalizations en = await AppLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(
      describeError(
        en,
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.providerUnavailable,
          statusCode: 503,
          message: 'Provider down.',
        ),
      ),
      'Montra is temporarily unavailable. Try again in a few minutes.',
    );
    expect(
      describeError(
        en,
        const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.storageUnavailable,
          statusCode: 503,
        ),
      ),
      "File storage isn't available right now. Try again in a few minutes.",
    );
  });
}
