import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/formatting/frequency.dart';

/// Chips for reminder offsets in days before a due date (`reminder_days_before`:
/// 0–30 days, at most [maxSelected]). [value] is reported sorted; offsets the
/// server sent that are not among [options] are shown too.
class ReminderDaysField extends StatelessWidget {
  /// Creates the field.
  const ReminderDaysField({
    required this.value,
    required this.onChanged,
    this.options = const <int>[0, 1, 3, 7, 14, 30],
    this.maxSelected = 5,
    this.label,
    this.enabled = true,
    super.key,
  });

  /// Selected offsets.
  final List<int> value;

  /// Called with the new sorted offsets.
  final ValueChanged<List<int>> onChanged;

  /// Offsets offered.
  final List<int> options;

  /// Most offsets allowed.
  final int maxSelected;

  /// Heading; defaults to "Remind me".
  final String? label;

  /// Whether the chips can be changed.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final Set<int> selected = value.toSet();
    final List<int> shown = <int>{...options, ...selected}.toList()..sort();
    final bool full = selected.length >= maxSelected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label ?? l10n.reminderDaysLabel, style: text.titleSmall),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final int days in shown)
              FilterChip(
                label: Text(reminderOffsetLabel(l10n, days)),
                selected: selected.contains(days),
                onSelected: !enabled || (full && !selected.contains(days))
                    ? null
                    : (bool on) {
                        final Set<int> next = <int>{...selected};
                        if (on) {
                          next.add(days);
                        } else {
                          next.remove(days);
                        }
                        onChanged(next.toList()..sort());
                      },
              ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        Text(
          selected.isEmpty
              ? l10n.reminderNone
              : l10n.reminderDaysHelp(maxSelected),
          style: text.bodySmall,
        ),
      ],
    );
  }
}
