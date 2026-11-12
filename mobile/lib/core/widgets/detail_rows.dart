import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';

/// A label/value pair on a details page, read as one item by screen
/// readers ("Account: HDFC Savings"). Wraps instead of overflowing at large
/// text sizes.
class DetailRow extends StatelessWidget {
  /// Creates the row from a [value] text or a custom [child].
  const DetailRow({
    required this.label,
    this.value,
    this.child,
    this.semanticsValue,
    this.onTap,
    super.key,
  }) : assert(value != null || child != null, 'value or child is required');

  /// Label.
  final String label;

  /// Value text.
  final String? value;

  /// Custom value widget (e.g. an amount).
  final Widget? child;

  /// Screen-reader value when [child] is used.
  final String? semanticsValue;

  /// Makes the row tappable (e.g. open the linked record).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm + Insets.xs,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Insets.md,
        runSpacing: Insets.xs,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          child ??
              Text(
                value!,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.end,
              ),
          if (onTap != null)
            const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 20)),
        ],
      ),
    );
    final String spoken = semanticsValue ?? value ?? '';
    return MergeSemantics(
      child: Semantics(
        label: spoken.isEmpty ? label : '$label: $spoken',
        button: onTap != null,
        excludeSemantics: semanticsValue != null || value != null,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// A card with an optional heading, used to group details.
class SectionCard extends StatelessWidget {
  /// Creates the card.
  const SectionCard({
    required this.children,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(vertical: Insets.sm),
    super.key,
  });

  /// Heading.
  final String? title;

  /// Widget next to the heading (e.g. "See all").
  final Widget? trailing;

  /// Content.
  final List<Widget> children;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.sm,
                  Insets.sm,
                  Insets.xs,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title!, style: theme.textTheme.titleMedium),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// One choice in [showOptionSheet].
@immutable
class SheetOption<T> {
  /// Creates the option.
  const SheetOption({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.destructive = false,
  });

  /// Returned when chosen.
  final T value;

  /// Text.
  final String label;

  /// Leading icon.
  final IconData? icon;

  /// Second line.
  final String? subtitle;

  /// Shown with error colors (e.g. delete).
  final bool destructive;
}

/// A bottom sheet with a list of [options]. Returns the chosen value or
/// null when dismissed.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetOption<T>> options,
  T? selected,
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (BuildContext sheetContext) {
    final ThemeData theme = Theme.of(sheetContext);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                0,
                Insets.md,
                Insets.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleLarge),
              ),
            ),
            for (final SheetOption<T> option in options)
              ListTile(
                leading: option.icon == null
                    ? null
                    : Icon(
                        option.icon,
                        color: option.destructive
                            ? theme.colorScheme.error
                            : null,
                      ),
                title: Text(
                  option.label,
                  style: option.destructive
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
                subtitle: option.subtitle == null
                    ? null
                    : Text(option.subtitle!),
                selected: selected != null && option.value == selected,
                trailing: selected != null && option.value == selected
                    ? Icon(
                        Icons.check,
                        semanticLabel: sheetContext.l10n.selectedLabel,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option.value),
              ),
          ],
        ),
      ),
    );
  },
);
