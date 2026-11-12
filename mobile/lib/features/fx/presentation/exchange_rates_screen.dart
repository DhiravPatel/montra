import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/fx/data/fx_api.dart';
import 'package:montra_mobile/features/fx/domain/fx_display.dart';

/// Exchange rates (`GET /fx/rates`): published rates and the user's own
/// manual rates (which win over published ones for that user). Manual rates
/// can be added and the user's own deleted; conversions disclose the rate.
class ExchangeRatesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ExchangeRatesScreen({super.key});

  @override
  ConsumerState<ExchangeRatesScreen> createState() =>
      _ExchangeRatesScreenState();
}

class _ExchangeRatesScreenState extends ConsumerState<ExchangeRatesScreen> {
  String? _base;
  String? _quote;
  String? _deleting;

  RateFilter get _filter => (base: _base, quote: _quote);

  Future<void> _refresh() async {
    ref.invalidate(fxRatesProvider(_filter));
    try {
      await ref.read(fxRatesProvider(_filter).future);
    } on Object {
      // Shown by the list state.
    }
  }

  Future<void> _delete(RateDto rate) async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.fxDeleteTitle,
      body: l10n.fxDeleteBody(rate.baseValue, rate.quote),
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deleting = rate.id);
    try {
      await ref.read(fxApiProvider).deleteRate(rate.id);
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.fxDeleted);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = null);
      }
    }
  }

  Future<void> _pick(bool base) async {
    final String? picked = await showCurrencyPicker(
      context,
      selected: base ? _base : _quote,
    );
    if (picked != null && mounted) {
      setState(() => base ? _base = picked : _quote = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<RateDto>> rates = ref.watch(fxRatesProvider(_filter));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.entryExchangeRates),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.fxConvertTitle,
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => context.push(AppRoutes.currencyConverter),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(
          Uri(
            path: AppRoutes.newExchangeRate,
            queryParameters: <String, String>{'base': ?_base, 'quote': ?_quote},
          ).toString(),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.fxAddRate),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              0,
            ),
            child: Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: SelectorField(
                    label: l10n.fxFilterFrom,
                    value: _base,
                    placeholder: l10n.fxFilterAny,
                    onTap: () => _pick(true),
                    onClear: _base == null
                        ? null
                        : () => setState(() => _base = null),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SelectorField(
                    label: l10n.fxFilterTo,
                    value: _quote,
                    placeholder: l10n.fxFilterAny,
                    onTap: () => _pick(false),
                    onClear: _quote == null
                        ? null
                        : () => setState(() => _quote = null),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<RateDto>>(
              value: rates,
              onRetry: _refresh,
              data: (List<RateDto> list) => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.md,
                        Insets.sm,
                        Insets.md,
                        Insets.sm,
                      ),
                      child: Text(l10n.fxIntro),
                    ),
                    if (list.isEmpty)
                      MessageStateView(
                        icon: Icons.currency_exchange,
                        title: _base == null && _quote == null
                            ? l10n.fxEmptyTitle
                            : l10n.fxNoMatchTitle,
                        body: l10n.fxEmptyBody,
                      )
                    else
                      for (final RateDto r in sortRates(list))
                        _RateTile(
                          rate: r,
                          deleting: _deleting == r.id,
                          onDelete: r.mine && _deleting == null
                              ? () => _delete(r)
                              : null,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.rate,
    required this.deleting,
    required this.onDelete,
  });

  final RateDto rate;
  final bool deleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String pair = l10n.fxRatePair(
      rate.baseValue,
      displayRate(rate.rate),
      rate.quote,
    );
    return ListTile(
      leading: const CircleAvatar(
        child: ExcludeSemantics(child: Icon(Icons.currency_exchange)),
      ),
      title: Text(pair),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.fxAsOf(
              rateSourceLabel(l10n, rate.source),
              formatDateTime(rate.asOf, locale: locale),
            ),
          ),
          if (rate.mine)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: StatusLabel(
                text: l10n.fxYourRate,
                tone: StatusTone.positive,
                icon: Icons.person_outline,
              ),
            ),
        ],
      ),
      trailing: deleting
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : onDelete == null
          ? null
          : IconButton(
              tooltip: l10n.fxDeleteLabel(rate.baseValue, rate.quote),
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
    );
  }
}
