import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/frequency.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';

enum _EndMode { never, date, count }

/// Edits a [ScheduleValue] (recurring rules and bills): frequency, custom
/// interval, the weekday or day of the month, start, end and time. A
/// readable summary is shown above the fields. Server field errors are
/// passed in [errors] with the keys `frequency`, `interval`, `anchor`,
/// `start`, `end`, `count` and `time`.
class ScheduleEditor extends StatefulWidget {
  /// Creates the editor.
  const ScheduleEditor({
    required this.value,
    required this.onChanged,
    this.errors = const <String, String>{},
    this.enabled = true,
    super.key,
  });

  /// Current schedule.
  final ScheduleValue value;

  /// Called with each change.
  final ValueChanged<ScheduleValue> onChanged;

  /// Server errors by field key.
  final Map<String, String> errors;

  /// Whether fields can be changed.
  final bool enabled;

  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  final TextEditingController _interval = TextEditingController();
  final TextEditingController _count = TextEditingController();
  late _EndMode _end;

  @override
  void initState() {
    super.initState();
    _sync(widget.value, force: true);
  }

  @override
  void didUpdateWidget(covariant ScheduleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _sync(widget.value);
    }
  }

  void _sync(ScheduleValue v, {bool force = false}) {
    final String interval = '${v.intervalCount ?? 1}';
    if (force || int.tryParse(_interval.text) != (v.intervalCount ?? 1)) {
      _interval.text = interval;
    }
    final int? count = v.maxOccurrences;
    if (force || (count != null && int.tryParse(_count.text) != count)) {
      _count.text = count == null ? '' : '$count';
    }
    if (force) {
      _end = v.endDate != null
          ? _EndMode.date
          : v.maxOccurrences != null
          ? _EndMode.count
          : _EndMode.never;
    } else if (v.endDate != null) {
      _end = _EndMode.date;
    } else if (v.maxOccurrences != null) {
      _end = _EndMode.count;
    }
  }

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  ScheduleValue get _v => widget.value;

  /// Schedules can start or end years ahead.
  DateTime get _lastSelectable =>
      DateTime(LocalDates.today().year + 10, 12, 31);

  void _emit(ScheduleValue next) => widget.onChanged(next.normalized());

  void _setFrequency(String frequency) {
    // A new frequency drops anchors that no longer apply.
    final ScheduleValue next = ScheduleValue(
      frequency: frequency,
      startDate: _v.startDate,
      intervalCount: frequency == 'custom' ? (_v.intervalCount ?? 1) : null,
      intervalUnit: frequency == 'custom' ? (_v.intervalUnit ?? 'day') : null,
      byMonthDay: _v.byMonthDay,
      byWeekday: _v.byWeekday,
      byWeekOfMonth: _v.byWeekOfMonth,
      endDate: _v.endDate,
      maxOccurrences: _v.maxOccurrences,
      localTime: _v.localTime,
    );
    _emit(next);
  }

  void _setAnchor(ScheduleAnchor anchor) {
    final DateTime? start = LocalDates.parse(_v.startDate);
    switch (anchor) {
      case ScheduleAnchor.startDate:
        _emit(_v.copyWith(clearAnchors: true));
      case ScheduleAnchor.monthDay:
        _emit(_v.copyWith(clearAnchors: true, byMonthDay: start?.day ?? 1));
      case ScheduleAnchor.nthWeekday:
        _emit(
          _v.copyWith(
            clearAnchors: true,
            byWeekOfMonth: 1,
            byWeekday: (start?.weekday ?? 1) % 7,
          ),
        );
    }
  }

  void _setEndMode(_EndMode mode) {
    setState(() => _end = mode);
    switch (mode) {
      case _EndMode.never:
        _count.clear();
        _emit(_v.copyWith(clearEnd: true));
      case _EndMode.date:
        _emit(_v.copyWith(clearEnd: true));
      case _EndMode.count:
        _emit(
          _v.copyWith(
            clearEnd: true,
            maxOccurrences: int.tryParse(_count.text),
          ),
        );
    }
  }

  Future<void> _pickTime() async {
    final List<String> parts = (_v.localTime ?? '09:00').split(':');
    final TimeOfDay initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null && mounted) {
      String two(int n) => n.toString().padLeft(2, '0');
      _emit(
        _v.copyWith(localTime: '${two(picked.hour)}:${two(picked.minute)}'),
      );
    }
  }

  String _timeText(BuildContext context) {
    final List<String> parts = (_v.localTime ?? '09:00').split(':');
    final TimeOfDay time = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final ThemeData theme = Theme.of(context);
    final Map<String, String> errors = widget.errors;
    final bool enabled = widget.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: <Widget>[
              const ExcludeSemantics(child: Icon(Icons.repeat, size: 20)),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '${scheduleSummary(l10n, _v, locale: locale)}\n'
                    '${scheduleRange(l10n, _v, locale: locale)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('frequency-${_v.frequency}'),
          initialValue: scheduleFrequencies.contains(_v.frequency)
              ? _v.frequency
              : 'custom',
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.scheduleFrequencyLabel,
            errorText: errors['frequency'],
          ),
          items: <DropdownMenuItem<String>>[
            for (final String f in scheduleFrequencies)
              DropdownMenuItem<String>(
                value: f,
                child: Text(frequencyLabel(l10n, f)),
              ),
          ],
          onChanged: enabled
              ? (String? f) {
                  if (f != null) {
                    _setFrequency(f);
                  }
                }
              : null,
        ),
        if (_v.frequency == 'custom') ...<Widget>[
          const SizedBox(height: Insets.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: _interval,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.scheduleEveryLabel,
                    errorText: errors['interval'],
                  ),
                  validator: (String? v) {
                    final int? n = int.tryParse((v ?? '').trim());
                    return n == null || n < 1 || n > 366
                        ? l10n.scheduleIntervalInvalid
                        : null;
                  },
                  onChanged: (String v) {
                    final int? n = int.tryParse(v.trim());
                    if (n != null && n >= 1 && n <= 366) {
                      _emit(_v.copyWith(intervalCount: n));
                    }
                  },
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>('unit-${_v.intervalUnit}'),
                  initialValue: intervalUnits.contains(_v.intervalUnit)
                      ? _v.intervalUnit
                      : 'day',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.scheduleUnitLabel,
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final String u in intervalUnits)
                      DropdownMenuItem<String>(
                        value: u,
                        child: Text(intervalUnitLabel(l10n, u)),
                      ),
                  ],
                  onChanged: enabled
                      ? (String? u) {
                          if (u != null) {
                            _emit(
                              _v.copyWith(intervalUnit: u, clearAnchors: true),
                            );
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
        if (_v.isWeekBased) ...<Widget>[
          const SizedBox(height: Insets.md),
          DropdownButtonFormField<int?>(
            key: ValueKey<String>('weekday-${_v.byWeekday}'),
            initialValue: _v.byWeekday,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.scheduleWeekdayLabel,
              errorText: errors['anchor'],
            ),
            items: <DropdownMenuItem<int?>>[
              DropdownMenuItem<int?>(child: Text(l10n.scheduleSameWeekday)),
              for (final int d in weekdayOrder)
                DropdownMenuItem<int?>(
                  value: d,
                  child: Text(weekdayName(d, locale)),
                ),
            ],
            onChanged: enabled
                ? (int? d) => _emit(
                    d == null
                        ? _v.copyWith(clearAnchors: true)
                        : _v.copyWith(clearAnchors: true, byWeekday: d),
                  )
                : null,
          ),
        ],
        if (_v.isMonthBased) ...<Widget>[
          const SizedBox(height: Insets.md),
          DropdownButtonFormField<ScheduleAnchor>(
            key: ValueKey<String>('anchor-${_v.anchor.name}'),
            initialValue: _v.anchor,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.scheduleDayLabel,
              errorText: errors['anchor'],
            ),
            items: <DropdownMenuItem<ScheduleAnchor>>[
              DropdownMenuItem<ScheduleAnchor>(
                value: ScheduleAnchor.startDate,
                child: Text(l10n.scheduleAnchorStart),
              ),
              DropdownMenuItem<ScheduleAnchor>(
                value: ScheduleAnchor.monthDay,
                child: Text(l10n.scheduleAnchorMonthDay),
              ),
              DropdownMenuItem<ScheduleAnchor>(
                value: ScheduleAnchor.nthWeekday,
                child: Text(l10n.scheduleAnchorNthWeekday),
              ),
            ],
            onChanged: enabled
                ? (ScheduleAnchor? a) {
                    if (a != null) {
                      _setAnchor(a);
                    }
                  }
                : null,
          ),
          if (_v.anchor == ScheduleAnchor.monthDay) ...<Widget>[
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<int>(
              key: ValueKey<String>('monthday-${_v.byMonthDay}'),
              initialValue: _v.byMonthDay,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.scheduleMonthDayLabel,
                helperText: (_v.byMonthDay ?? 0) > 28
                    ? l10n.scheduleMonthDayHelp
                    : null,
                helperMaxLines: 3,
              ),
              items: <DropdownMenuItem<int>>[
                for (int d = 1; d <= 31; d++)
                  DropdownMenuItem<int>(value: d, child: Text('$d')),
                DropdownMenuItem<int>(
                  value: -1,
                  child: Text(l10n.scheduleLastDay),
                ),
              ],
              onChanged: enabled
                  ? (int? d) {
                      if (d != null) {
                        _emit(_v.copyWith(clearAnchors: true, byMonthDay: d));
                      }
                    }
                  : null,
            ),
          ],
          if (_v.anchor == ScheduleAnchor.nthWeekday) ...<Widget>[
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<int>(
              key: ValueKey<String>('week-${_v.byWeekOfMonth}'),
              initialValue: _v.byWeekOfMonth,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.scheduleWeekOfMonthLabel,
              ),
              items: <DropdownMenuItem<int>>[
                for (final int w in <int>[1, 2, 3, 4, 5, -1])
                  DropdownMenuItem<int>(
                    value: w,
                    child: Text(weekOfMonthLabel(l10n, w)),
                  ),
              ],
              onChanged: enabled
                  ? (int? w) {
                      if (w != null) {
                        _emit(_v.copyWith(byWeekOfMonth: w));
                      }
                    }
                  : null,
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<int>(
              key: ValueKey<String>('nthday-${_v.byWeekday}'),
              initialValue: _v.byWeekday,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.scheduleWeekdayLabel),
              items: <DropdownMenuItem<int>>[
                for (final int d in weekdayOrder)
                  DropdownMenuItem<int>(
                    value: d,
                    child: Text(weekdayName(d, locale)),
                  ),
              ],
              onChanged: enabled
                  ? (int? d) {
                      if (d != null) {
                        _emit(_v.copyWith(byWeekday: d));
                      }
                    }
                  : null,
            ),
          ],
        ],
        const SizedBox(height: Insets.md),
        DateSelectorField(
          label: l10n.scheduleStartLabel,
          value: _v.startDate,
          errorText: errors['start'],
          lastDate: _lastSelectable,
          enabled: enabled,
          onChanged: (String? d) {
            if (d != null) {
              _emit(_v.copyWith(startDate: d));
            }
          },
        ),
        const SizedBox(height: Insets.md),
        DropdownButtonFormField<_EndMode>(
          key: ValueKey<String>('end-${_end.name}'),
          initialValue: _end,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.scheduleEndsLabel),
          items: <DropdownMenuItem<_EndMode>>[
            DropdownMenuItem<_EndMode>(
              value: _EndMode.never,
              child: Text(l10n.scheduleEndsNever),
            ),
            DropdownMenuItem<_EndMode>(
              value: _EndMode.date,
              child: Text(l10n.scheduleEndsOnDate),
            ),
            DropdownMenuItem<_EndMode>(
              value: _EndMode.count,
              child: Text(l10n.scheduleEndsAfter),
            ),
          ],
          onChanged: enabled
              ? (_EndMode? m) {
                  if (m != null) {
                    _setEndMode(m);
                  }
                }
              : null,
        ),
        if (_end == _EndMode.date) ...<Widget>[
          const SizedBox(height: Insets.md),
          DateSelectorField(
            label: l10n.scheduleEndDateLabel,
            value: _v.endDate,
            emptyLabel: l10n.scheduleEndDateChoose,
            errorText:
                errors['end'] ??
                (_v.endDate != null && _v.endDate!.compareTo(_v.startDate) < 0
                    ? l10n.scheduleEndBeforeStart
                    : null),
            firstDate: LocalDates.parse(_v.startDate),
            lastDate: _lastSelectable,
            enabled: enabled,
            onChanged: (String? d) => _emit(
              d == null
                  ? _v.copyWith(clearEnd: true)
                  : _v.copyWith(clearEnd: true, endDate: d),
            ),
          ),
        ],
        if (_end == _EndMode.count) ...<Widget>[
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _count,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            decoration: InputDecoration(
              labelText: l10n.scheduleTimesLabel,
              errorText: errors['count'],
            ),
            validator: (String? v) {
              final int? n = int.tryParse((v ?? '').trim());
              return n == null || n < 1 || n > 10000
                  ? l10n.scheduleTimesInvalid
                  : null;
            },
            onChanged: (String v) {
              final int? n = int.tryParse(v.trim());
              _emit(
                _v.copyWith(
                  clearEnd: true,
                  maxOccurrences: n != null && n >= 1 && n <= 10000 ? n : null,
                ),
              );
            },
          ),
        ],
        const SizedBox(height: Insets.md),
        SelectorField(
          label: l10n.scheduleTimeLabel,
          value: _timeText(context),
          icon: Icons.schedule,
          helperText: l10n.scheduleTimeHelp,
          errorText: errors['time'],
          enabled: enabled,
          onTap: enabled ? _pickTime : null,
        ),
      ],
    );
  }
}
