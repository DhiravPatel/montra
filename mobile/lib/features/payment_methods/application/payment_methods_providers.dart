import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';

/// Payment methods; archived ones too when the argument is true.
final FutureProviderFamily<List<PaymentMethodDto>, bool>
paymentMethodsProvider = FutureProvider.autoDispose
    .family<List<PaymentMethodDto>, bool>((Ref ref, bool includeArchived) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(paymentMethodsApiProvider)
          .list(includeArchived: includeArchived);
    });

/// Payment methods by ID, archived ones included (names in details).
final Provider<Map<String, PaymentMethodDto>> paymentMethodIndexProvider =
    Provider.autoDispose<Map<String, PaymentMethodDto>>(
      (Ref ref) => <String, PaymentMethodDto>{
        for (final PaymentMethodDto p
            in ref.watch(paymentMethodsProvider(true)).value ??
                const <PaymentMethodDto>[])
          p.id: p,
      },
    );

/// One payment method by ID (archived ones too).
final FutureProviderFamily<PaymentMethodDto, String> paymentMethodProvider =
    FutureProvider.autoDispose.family<PaymentMethodDto, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(financeRevisionProvider);
      return ref.read(paymentMethodsApiProvider).get(id);
    });

/// Localized payment method kind.
String paymentKindLabel(AppLocalizations l10n, PaymentMethodInputKind kind) =>
    switch (kind) {
      PaymentMethodInputKind.cash => l10n.paymentKindCash,
      PaymentMethodInputKind.upi => l10n.paymentKindUpi,
      PaymentMethodInputKind.debitCard => l10n.paymentKindDebitCard,
      PaymentMethodInputKind.creditCard => l10n.paymentKindCreditCard,
      PaymentMethodInputKind.bankTransfer => l10n.paymentKindBankTransfer,
      PaymentMethodInputKind.wallet => l10n.paymentKindWallet,
      PaymentMethodInputKind.cheque => l10n.paymentKindCheque,
      PaymentMethodInputKind.other ||
      PaymentMethodInputKind.unrecognized => l10n.paymentKindOther,
    };

/// A method's kind in the create/edit vocabulary.
PaymentMethodInputKind kindOf(PaymentMethodDto method) => switch (method.kind) {
  PaymentMethodDtoKind.cash => PaymentMethodInputKind.cash,
  PaymentMethodDtoKind.upi => PaymentMethodInputKind.upi,
  PaymentMethodDtoKind.debitCard => PaymentMethodInputKind.debitCard,
  PaymentMethodDtoKind.creditCard => PaymentMethodInputKind.creditCard,
  PaymentMethodDtoKind.bankTransfer => PaymentMethodInputKind.bankTransfer,
  PaymentMethodDtoKind.wallet => PaymentMethodInputKind.wallet,
  PaymentMethodDtoKind.cheque => PaymentMethodInputKind.cheque,
  PaymentMethodDtoKind.other ||
  PaymentMethodDtoKind.unrecognized => PaymentMethodInputKind.other,
};

/// A method's network in the create/edit vocabulary, or null.
PaymentMethodInputNetwork? networkOf(PaymentMethodDto method) =>
    switch (method.network) {
      null => null,
      PaymentMethodDtoNetwork.visa => PaymentMethodInputNetwork.visa,
      PaymentMethodDtoNetwork.mastercard =>
        PaymentMethodInputNetwork.mastercard,
      PaymentMethodDtoNetwork.rupay => PaymentMethodInputNetwork.rupay,
      PaymentMethodDtoNetwork.amex => PaymentMethodInputNetwork.amex,
      PaymentMethodDtoNetwork.discover => PaymentMethodInputNetwork.discover,
      PaymentMethodDtoNetwork.diners => PaymentMethodInputNetwork.diners,
      PaymentMethodDtoNetwork.jcb => PaymentMethodInputNetwork.jcb,
      PaymentMethodDtoNetwork.upi => PaymentMethodInputNetwork.upi,
      PaymentMethodDtoNetwork.other ||
      PaymentMethodDtoNetwork.unrecognized => PaymentMethodInputNetwork.other,
    };

/// The PATCH vocabulary for a kind.
PaymentMethodPatchKind patchKind(PaymentMethodInputKind kind) => switch (kind) {
  PaymentMethodInputKind.cash => PaymentMethodPatchKind.cash,
  PaymentMethodInputKind.upi => PaymentMethodPatchKind.upi,
  PaymentMethodInputKind.debitCard => PaymentMethodPatchKind.debitCard,
  PaymentMethodInputKind.creditCard => PaymentMethodPatchKind.creditCard,
  PaymentMethodInputKind.bankTransfer => PaymentMethodPatchKind.bankTransfer,
  PaymentMethodInputKind.wallet => PaymentMethodPatchKind.wallet,
  PaymentMethodInputKind.cheque => PaymentMethodPatchKind.cheque,
  PaymentMethodInputKind.other ||
  PaymentMethodInputKind.unrecognized => PaymentMethodPatchKind.other,
};

/// The PATCH vocabulary for a network; null clears it (sent as `""`).
PaymentMethodPatchNetwork patchNetwork(PaymentMethodInputNetwork? network) =>
    switch (network) {
      null => PaymentMethodPatchNetwork.value10,
      PaymentMethodInputNetwork.visa => PaymentMethodPatchNetwork.visa,
      PaymentMethodInputNetwork.mastercard =>
        PaymentMethodPatchNetwork.mastercard,
      PaymentMethodInputNetwork.rupay => PaymentMethodPatchNetwork.rupay,
      PaymentMethodInputNetwork.amex => PaymentMethodPatchNetwork.amex,
      PaymentMethodInputNetwork.discover => PaymentMethodPatchNetwork.discover,
      PaymentMethodInputNetwork.diners => PaymentMethodPatchNetwork.diners,
      PaymentMethodInputNetwork.jcb => PaymentMethodPatchNetwork.jcb,
      PaymentMethodInputNetwork.upi => PaymentMethodPatchNetwork.upi,
      PaymentMethodInputNetwork.other ||
      PaymentMethodInputNetwork.unrecognized => PaymentMethodPatchNetwork.other,
    };

/// Icon for a payment method kind.
IconData paymentKindIcon(PaymentMethodInputKind kind) => switch (kind) {
  PaymentMethodInputKind.cash => Icons.payments_outlined,
  PaymentMethodInputKind.upi => Icons.qr_code_2,
  PaymentMethodInputKind.debitCard => Icons.credit_card_outlined,
  PaymentMethodInputKind.creditCard => Icons.credit_card,
  PaymentMethodInputKind.bankTransfer => Icons.account_balance_outlined,
  PaymentMethodInputKind.wallet => Icons.account_balance_wallet_outlined,
  PaymentMethodInputKind.cheque => Icons.receipt_long_outlined,
  PaymentMethodInputKind.other ||
  PaymentMethodInputKind.unrecognized => Icons.more_horiz,
};

/// Localized card network.
String networkLabel(AppLocalizations l10n, PaymentMethodInputNetwork n) =>
    switch (n) {
      PaymentMethodInputNetwork.visa => 'Visa',
      PaymentMethodInputNetwork.mastercard => 'Mastercard',
      PaymentMethodInputNetwork.rupay => 'RuPay',
      PaymentMethodInputNetwork.amex => 'American Express',
      PaymentMethodInputNetwork.discover => 'Discover',
      PaymentMethodInputNetwork.diners => 'Diners Club',
      PaymentMethodInputNetwork.jcb => 'JCB',
      PaymentMethodInputNetwork.upi => 'UPI',
      PaymentMethodInputNetwork.other ||
      PaymentMethodInputNetwork.unrecognized => l10n.paymentNetworkOther,
    };

/// Whether [kind] uses a card network.
bool hasNetwork(PaymentMethodInputKind kind) =>
    kind == PaymentMethodInputKind.debitCard ||
    kind == PaymentMethodInputKind.creditCard ||
    kind == PaymentMethodInputKind.upi;
