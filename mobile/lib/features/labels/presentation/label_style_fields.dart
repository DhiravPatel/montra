import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/domain/organize_display.dart';

/// Named color choices for a category or tag. [value] is `#RRGGBB` or null
/// for no color ("No color" is offered when [allowNone]).
class LabelColorField extends StatelessWidget {
  /// Creates the field.
  const LabelColorField({
    required this.value,
    required this.onChanged,
    this.allowNone = true,
    super.key,
  });

  /// Selected color.
  final String? value;

  /// Called with the new color (null for none).
  final ValueChanged<String?> onChanged;

  /// Whether "No color" can be chosen.
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? current = value?.toUpperCase();
    final bool known = labelColors.any(
      (LabelColor c) => c.hex.toUpperCase() == current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.labelColorLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          children: <Widget>[
            if (allowNone)
              ChoiceChip(
                label: Text(l10n.labelColorNone),
                selected: current == null,
                onSelected: (_) => onChanged(null),
              ),
            if (current != null && !known)
              _swatch(context, current, l10n.labelColorCustom, selected: true),
            for (final LabelColor c in labelColors)
              _swatch(
                context,
                c.hex,
                c.name(l10n),
                selected: c.hex.toUpperCase() == current,
              ),
          ],
        ),
      ],
    );
  }

  Widget _swatch(
    BuildContext context,
    String hex,
    String name, {
    required bool selected,
  }) => ChoiceChip(
    avatar: ExcludeSemantics(
      child: CircleAvatar(radius: 8, backgroundColor: parseHexColor(hex)),
    ),
    label: Text(name),
    selected: selected,
    onSelected: (_) => onChanged(hex),
  );
}

/// Icon choices for a category; each has a spoken name.
class CategoryIconField extends StatelessWidget {
  /// Creates the field.
  const CategoryIconField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Selected icon name.
  final String? value;

  /// Called with the chosen icon name.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.categoryIconLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final String name in categoryIconNames)
              IconButton.outlined(
                isSelected: name == value,
                selectedIcon: Icon(categoryIcon(name)),
                icon: Icon(categoryIcon(name)),
                tooltip: categoryIconLabel(l10n, name),
                onPressed: () => onChanged(name),
              ),
          ],
        ),
      ],
    );
  }
}
