import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/features/payment_methods/application/payment_methods_providers.dart';

List<SelectionItem<PaymentMethodDto>> _items(
  BuildContext context,
  List<PaymentMethodDto> data,
) {
  final AppLocalizations l10n = context.l10n;
  return <SelectionItem<PaymentMethodDto>>[
    for (final PaymentMethodDto p in data)
      SelectionItem<PaymentMethodDto>(
        id: p.id,
        value: p,
        label: p.label,
        subtitle: <String>[
          paymentKindLabel(l10n, kindOf(p)),
          ?p.maskedHint,
          if (p.isDefault) l10n.paymentDefault,
        ].join(' · '),
        leading: Icon(paymentKindIcon(kindOf(p))),
      ),
  ];
}

/// Picks an active payment method. Returns null when dismissed and
/// `Picked(null)` for "No payment method".
Future<Picked<PaymentMethodDto>?> showPaymentMethodPicker(
  BuildContext context, {
  String? selectedId,
}) => showSingleSelection<PaymentMethodDto, PaymentMethodDto>(
  context,
  title: context.l10n.paymentPickerTitle,
  source: paymentMethodsProvider(false),
  onRetry: (WidgetRef ref) => ref.invalidate(paymentMethodsProvider(false)),
  items: _items,
  selectedId: selectedId,
  noneLabel: context.l10n.paymentNone,
  emptyText: context.l10n.paymentPickerEmpty,
);
