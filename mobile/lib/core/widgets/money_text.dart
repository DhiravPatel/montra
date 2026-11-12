import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';

/// How a money flow is presented. The direction is always spelled out (a
/// `+`/`−` sign on screen and a word for screen readers), so meaning never
/// depends on color.
enum MoneyFlow {
  /// A plain amount (balances, totals).
  none,

  /// Money coming in (income, refunds, transfers in).
  inflow,

  /// Money going out (spending, fees, transfers out).
  outflow,
}

/// Formats [money] for display in [locale]; falls back to `amount CODE`
/// if the value cannot be formatted.
String formatMoneyText(Money money, String locale) {
  try {
    return MoneyFormatter.format(money, locale: locale);
  } on FormatException {
    return '${money.amount} ${money.currency}';
  }
}

/// A screen-reader label for [money] (`minus 1,234.50 INR`).
String moneySemantics(AppLocalizations l10n, Money money, String locale) {
  try {
    return MoneyFormatter.semanticLabel(
      money,
      locale: locale,
      minusWord: l10n.moneyMinusWord,
    );
  } on FormatException {
    return '${money.amount} ${money.currency}';
  }
}

/// Formats [money] using the signed-in user's number locale.
String formatMoney(BuildContext context, WidgetRef ref, Money money) =>
    formatMoneyText(money, numberLocaleOf(context, ref));

/// An exact amount from the server, formatted for the user's locale.
///
/// [flow] adds a visible sign and the words "received"/"spent" for screen
/// readers. [label] prefixes the screen-reader text (e.g. "Balance").
class MoneyText extends ConsumerWidget {
  /// Creates the text.
  const MoneyText(
    this.money, {
    this.flow = MoneyFlow.none,
    this.style,
    this.label,
    this.textAlign,
    this.colored = false,
    super.key,
  });

  /// The amount.
  final Money money;

  /// Direction shown with the amount.
  final MoneyFlow flow;

  /// Text style.
  final TextStyle? style;

  /// Screen-reader prefix.
  final String? label;

  /// Alignment.
  final TextAlign? textAlign;

  /// Tint inflows with the success color (the sign still carries the
  /// meaning).
  final bool colored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = numberLocaleOf(context, ref);
    final String formatted = formatMoneyText(money, locale);
    final String spoken = moneySemantics(l10n, money, locale);
    final String text = switch (flow) {
      MoneyFlow.none => formatted,
      MoneyFlow.inflow => '+$formatted',
      MoneyFlow.outflow => '−$formatted',
    };
    final String flowWord = switch (flow) {
      MoneyFlow.none => spoken,
      MoneyFlow.inflow => l10n.moneyInflowSemantics(spoken),
      MoneyFlow.outflow => l10n.moneyOutflowSemantics(spoken),
    };
    final String semantics = label == null ? flowWord : '$label, $flowWord';
    TextStyle? effective = style;
    if (colored && flow == MoneyFlow.inflow) {
      effective = (style ?? DefaultTextStyle.of(context).style).copyWith(
        color: StatusColors.of(context).success,
      );
    }
    return Text(
      text,
      style: effective,
      textAlign: textAlign,
      semanticsLabel: semantics,
    );
  }
}
