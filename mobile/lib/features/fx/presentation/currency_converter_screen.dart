import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/formatting/amount_input.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/fx/data/fx_api.dart';
import 'package:montra_mobile/features/fx/domain/fx_display.dart';

/// Converts an amount between currencies (`GET /fx/convert`) with the
/// latest rate or the rate on a date. The result shows the server's exact
/// amounts and discloses the rate, its source and date.
class CurrencyConverterScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CurrencyConverterScreen({super.key});

  @override
  ConsumerState<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState
    extends ConsumerState<CurrencyConverterScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  String? _from;
  String? _to;
  bool _historical = false;
  String? _date;
  String? _formError;
  ConversionDto? _result;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final AuthState auth = ref.read(authControllerProvider);
    _from = auth is SignedIn ? auth.user.baseCurrency : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final String? picked = await showCurrencyPicker(
      context,
      selected: from ? _from : _to,
    );
    if (picked != null && mounted) {
      setState(() {
        if (from) {
          _from = picked;
        } else {
          _to = picked;
        }
        _formError = null;
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _convert() async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _formError = null;
      _error = null;
      _result = null;
    });
    final String? from = _from;
    final String? to = _to;
    if (from == null || to == null) {
      setState(() => _formError = l10n.fxPairRequired);
      return;
    }
    if (_historical && _date == null) {
      setState(() => _formError = l10n.fxDateRequired);
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final AmountParseResult amount = readAmount(
      context,
      ref,
      _amount.text,
      currency: from,
      allowZero: true,
    );
    final String? value = amount.value;
    if (value == null) {
      return;
    }
    try {
      final ConversionDto result = await ref
          .read(fxApiProvider)
          .convert(
            amount: value,
            from: from,
            to: to,
            historical: _historical,
            date: _date,
          );
      if (mounted) {
        setState(() => _result = result);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ConversionDto? result = _result;
    final ApiException? error = _error;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fxConvertTitle)),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            Text(l10n.fxConvertIntro),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.fxFromLabel,
              icon: Icons.payments_outlined,
              value: _from,
              placeholder: l10n.currencyNotChosen,
              onTap: () => _pick(true),
            ),
            const SizedBox(height: Insets.sm),
            SelectorField(
              label: l10n.fxToLabel,
              icon: Icons.payments_outlined,
              value: _to,
              placeholder: l10n.currencyNotChosen,
              errorText: _formError,
              onTap: () => _pick(false),
            ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _amount,
              label: l10n.amountLabel,
              currency: _from,
              allowZero: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: Insets.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _historical,
              title: Text(l10n.fxUseDate),
              subtitle: Text(l10n.fxUseDateHelp),
              onChanged: (bool v) => setState(() {
                _historical = v;
                _result = null;
              }),
            ),
            if (_historical)
              DateSelectorField(
                label: l10n.fxDateLabel,
                value: _date,
                lastDate: LocalDates.today(),
                onChanged: (String? d) => setState(() {
                  _date = d;
                  _result = null;
                }),
              ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              icon: Icons.calculate_outlined,
              label: l10n.fxConvertAction,
              onPressed: _convert,
            ),
            const SizedBox(height: Insets.lg),
            if (error != null)
              _ConvertError(error: error, from: _from, to: _to)
            else if (result != null)
              _Result(result: result),
          ],
        ),
      ),
    );
  }
}

class _ConvertError extends StatelessWidget {
  const _ConvertError({
    required this.error,
    required this.from,
    required this.to,
  });

  final ApiException error;
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (error.code == ErrorObjectCode.notFound && from != null && to != null) {
      return NoticeBanner(
        tone: NoticeTone.warning,
        message: l10n.fxNoRate(from!, to!),
        action: TextButton(
          onPressed: () => context.push(
            Uri(
              path: AppRoutes.newExchangeRate,
              queryParameters: <String, String>{'base': from!, 'quote': to!},
            ).toString(),
          ),
          child: Text(l10n.fxAddRate),
        ),
      );
    }
    return NoticeBanner(
      tone: NoticeTone.error,
      message: describeError(l10n, error),
      requestId: requestIdOf(error),
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({required this.result});

  final ConversionDto result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Rate rate = result.rate;
    final String from = formatMoney(context, ref, result.from);
    final String to = formatMoney(context, ref, result.to);
    return Semantics(
      liveRegion: true,
      child: SectionCard(
        title: l10n.fxResultTitle,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(
              l10n.fxResultLine(from, to),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: Insets.sm),
          DetailRow(
            label: l10n.fxRateLabel,
            value: l10n.fxRatePair(
              rate.baseValue,
              displayRate(rate.rate),
              rate.quote,
            ),
          ),
          DetailRow(
            label: l10n.fxSourceLabel,
            value: conversionSourceLabel(l10n, rate.source),
          ),
          DetailRow(
            label: l10n.fxRateDateLabel,
            value: formatDateTime(rate.asOf, locale: locale),
          ),
          DetailRow(
            label: l10n.fxPolicyLabel,
            value: result.policy == ConversionDtoPolicy.historical
                ? l10n.fxPolicyHistorical
                : l10n.fxPolicyCurrent,
          ),
          if (rate.inverted)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.xs,
                Insets.md,
                0,
              ),
              child: Text(
                l10n.fxInvertedNote(rate.quote, rate.baseValue),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_isNonZero(result.roundingDelta))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.xs,
                Insets.md,
                0,
              ),
              child: Text(
                l10n.fxRoundingNote(result.roundingDelta),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: Insets.sm),
        ],
      ),
    );
  }

  static bool _isNonZero(String decimal) => RegExp('[1-9]').hasMatch(decimal);
}
