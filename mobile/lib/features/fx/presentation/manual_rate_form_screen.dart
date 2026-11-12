import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/fx/data/fx_api.dart';
import 'package:montra_mobile/features/fx/domain/fx_display.dart';

/// Adds a manual exchange rate (`POST /fx/rates`): how many units of one
/// currency one unit of another is worth, optionally as of a past date.
/// The user's own rates are used before published ones; earlier rates are
/// kept for history.
class ManualRateFormScreen extends ConsumerStatefulWidget {
  /// Creates the form, optionally with the pair preset.
  const ManualRateFormScreen({this.base, this.quote, super.key});

  /// Preset currency to convert from.
  final String? base;

  /// Preset currency to convert to.
  final String? quote;

  @override
  ConsumerState<ManualRateFormScreen> createState() =>
      _ManualRateFormScreenState();
}

class _ManualRateFormScreenState extends ConsumerState<ManualRateFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _rate = TextEditingController();
  late String? _base = widget.base;
  late String? _quote = widget.quote;
  String? _asOf;
  String? _pairError;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'base': 'base',
    'quote': 'quote',
    'rate': 'rate',
    'as_of': 'asOf',
  };

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _pick(bool base) async {
    final String? picked = await showCurrencyPicker(
      context,
      selected: base ? _base : _quote,
    );
    if (picked != null && mounted) {
      setState(() {
        if (base) {
          _base = picked;
        } else {
          _quote = picked;
        }
        _pairError = null;
      });
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() {
      _errors = ServerFormErrors.none;
      _pairError = null;
    });
    final bool fieldsOk = _form.currentState?.validate() ?? false;
    final String? base = _base;
    final String? quote = _quote;
    if (base == null || quote == null) {
      setState(() => _pairError = l10n.fxPairRequired);
      return;
    }
    if (base == quote) {
      setState(() => _pairError = l10n.fxPairDifferent);
      return;
    }
    final String? rate = parseRate(_rate.text);
    if (!fieldsOk || rate == null) {
      return;
    }
    try {
      await ref
          .read(fxApiProvider)
          .setRate(
            ManualRateInput(
              baseValue: base,
              quote: quote,
              rate: rate,
              asOf: _asOf,
            ),
          );
      finance.bump();
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.fxSaved);
      context.pop();
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? general = _errors.general;
    final String? base = _base;
    final String? quote = _quote;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fxAddRate)),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            Text(l10n.fxManualIntro),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.fxBaseLabel,
              icon: Icons.payments_outlined,
              value: base,
              placeholder: l10n.currencyNotChosen,
              errorText: _errors['base'],
              onTap: () => _pick(true),
            ),
            const SizedBox(height: Insets.sm),
            SelectorField(
              label: l10n.fxQuoteLabel,
              icon: Icons.payments_outlined,
              value: quote,
              placeholder: l10n.currencyNotChosen,
              errorText: _pairError ?? _errors['quote'],
              onTap: () => _pick(false),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.fxRateLabel,
                helperText: base != null && quote != null
                    ? l10n.fxRateHelpPair(base, quote)
                    : l10n.fxRateHelp,
                errorText: _errors['rate'],
                suffixText: quote,
              ),
              validator: (String? v) =>
                  parseRate(v ?? '') == null ? l10n.fxRateInvalid : null,
            ),
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.fxAsOfLabel,
              value: _asOf,
              emptyLabel: l10n.fxAsOfNow,
              helperText: l10n.fxAsOfHelp,
              errorText: _errors['asOf'],
              lastDate: LocalDates.today(),
              clearable: true,
              onChanged: (String? d) => setState(() => _asOf = d),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              icon: Icons.save_outlined,
              label: l10n.fxSaveRate,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
