import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/formatting/dates.dart';

/// A form field that opens a picker (account, category, merchant, date…).
///
/// Looks like a text field, reads as a button to screen readers ("Account,
/// HDFC Savings. Double-tap to change"), keeps a 48dp touch target and can
/// show an error under it. [onClear] adds a clear button for optional
/// values.
class SelectorField extends StatelessWidget {
  /// Creates the field.
  const SelectorField({
    required this.label,
    required this.onTap,
    this.value,
    this.placeholder,
    this.icon,
    this.errorText,
    this.helperText,
    this.onClear,
    this.enabled = true,
    super.key,
  });

  /// Field label.
  final String label;

  /// Current value text, or null when nothing is chosen.
  final String? value;

  /// Shown when [value] is null.
  final String? placeholder;

  /// Leading icon.
  final IconData? icon;

  /// Error text.
  final String? errorText;

  /// Helper text.
  final String? helperText;

  /// Opens the picker.
  final VoidCallback? onTap;

  /// Clears the value (optional fields).
  final VoidCallback? onClear;

  /// Whether the field can be changed.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String shown = value ?? placeholder ?? l10n.selectorNotChosen;
    final bool active = enabled && onTap != null;
    return Semantics(
      button: true,
      enabled: active,
      label: label,
      value: shown,
      hint: active ? l10n.selectorChangeHint : null,
      excludeSemantics: true,
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          isEmpty: false,
          isFocused: false,
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            helperText: helperText,
            enabled: active,
            prefixIcon: icon == null ? null : Icon(icon),
            suffixIcon: onClear != null && value != null && active
                ? IconButton(
                    tooltip: l10n.selectorClear(label),
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                  )
                : const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            shown,
            style: value == null
                ? theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

/// A [SelectorField] for a calendar date (`YYYY-MM-DD`).
///
/// An empty value shows [emptyLabel] (for example "Today"), meaning the
/// server's default is used; nothing is sent until the user picks a date.
class DateSelectorField extends StatelessWidget {
  /// Creates the field.
  const DateSelectorField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.emptyLabel,
    this.errorText,
    this.helperText,
    this.firstDate,
    this.lastDate,
    this.clearable = false,
    this.enabled = true,
    super.key,
  });

  /// Field label.
  final String label;

  /// Chosen date (`YYYY-MM-DD`) or null.
  final String? value;

  /// Called with the new date, or null when cleared.
  final ValueChanged<String?> onChanged;

  /// Text for an empty value.
  final String? emptyLabel;

  /// Error text.
  final String? errorText;

  /// Helper text.
  final String? helperText;

  /// Earliest selectable date.
  final DateTime? firstDate;

  /// Latest selectable date.
  final DateTime? lastDate;

  /// Whether the value can be cleared.
  final bool clearable;

  /// Whether the field can be changed.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final String locale = Localizations.localeOf(context).toString();
    final String? current = value;
    return SelectorField(
      label: label,
      icon: Icons.event_outlined,
      value: current == null
          ? null
          : LocalDates.display(current, locale: locale),
      placeholder: emptyLabel,
      errorText: errorText,
      helperText: helperText,
      enabled: enabled,
      onClear: clearable ? () => onChanged(null) : null,
      onTap: () async {
        final DateTime today = LocalDates.today();
        final DateTime first = firstDate ?? DateTime(2000);
        final DateTime last =
            lastDate ?? DateTime(today.year + 1, today.month, today.day);
        DateTime initial = LocalDates.parse(current) ?? today;
        if (initial.isBefore(first)) {
          initial = first;
        }
        if (initial.isAfter(last)) {
          initial = last;
        }
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          helpText: label,
        );
        if (picked != null) {
          onChanged(LocalDates.format(picked));
        }
      },
    );
  }
}

/// Section header inside a form or a details page.
class FormSectionHeader extends StatelessWidget {
  /// Creates the header.
  const FormSectionHeader(this.text, {super.key});

  /// Header text.
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Insets.lg, bottom: Insets.sm),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}
