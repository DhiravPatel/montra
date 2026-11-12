import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/currency_catalog.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';

/// Opens a searchable list of the currencies `GET /currencies` marks as
/// selectable (retired ones such as BGN are hidden). Returns the chosen ISO
/// code, or null when dismissed.
Future<String?> showCurrencyPicker(BuildContext context, {String? selected}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          CurrencyPickerSheet(selected: selected),
    );

/// The picker's content (public for tests).
class CurrencyPickerSheet extends ConsumerStatefulWidget {
  /// Creates the sheet; [selected] is marked as chosen.
  const CurrencyPickerSheet({this.selected, super.key});

  /// Currently chosen code.
  final String? selected;

  @override
  ConsumerState<CurrencyPickerSheet> createState() =>
      _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends ConsumerState<CurrencyPickerSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<CurrencyDto> _matches(CurrencyCatalog catalog) {
    final String q = _query.text.trim().toLowerCase();
    final List<CurrencyDto> options = catalog.selectable;
    if (q.isEmpty) {
      return options;
    }
    return <CurrencyDto>[
      for (final CurrencyDto c in options)
        if (c.code.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q))
          c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CurrencyCatalog> catalog = ref.watch(
      currencyCatalogProvider,
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    l10n.currencyPickerTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.currencySearchHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<CurrencyCatalog>(
              value: catalog,
              onRetry: () => ref.invalidate(currencyCatalogProvider),
              data: (CurrencyCatalog loaded) {
                final List<CurrencyDto> matches = _matches(loaded);
                if (matches.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.lg),
                      child: Text(
                        l10n.currencyNoResults(_query.text.trim()),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (BuildContext context, int index) {
                    final CurrencyDto c = matches[index];
                    final bool isSelected = c.code == widget.selected;
                    return ListTile(
                      selected: isSelected,
                      title: Text('${c.code} · ${c.name}'),
                      trailing: isSelected ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.of(context).pop(c.code),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
