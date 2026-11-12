import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';

/// A chart with a visible text summary and a table alternative.
///
/// The drawing itself is hidden from screen readers; the [summary] text
/// describes it and [table] (a list of the same values) can replace the
/// drawing with one tap. Nothing is animated, so reduced-motion settings
/// are respected by construction.
class AccessibleChart extends StatefulWidget {
  /// Creates the chart.
  const AccessibleChart({
    required this.summary,
    required this.chart,
    required this.table,
    this.legend,
    this.initiallyShowTable = false,
    super.key,
  });

  /// Plain-language description of what the chart shows.
  final String summary;

  /// The drawing.
  final Widget chart;

  /// The same data as a list or table.
  final Widget table;

  /// Explains marks with text and shapes (never color alone).
  final Widget? legend;

  /// Start in table mode.
  final bool initiallyShowTable;

  @override
  State<AccessibleChart> createState() => _AccessibleChartState();
}

class _AccessibleChartState extends State<AccessibleChart> {
  late bool _table = widget.initiallyShowTable;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text(widget.summary, style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(height: Insets.sm),
        if (_table)
          widget.table
        else ...<Widget>[
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: widget.chart,
            ),
          ),
          if (widget.legend != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                0,
              ),
              child: widget.legend,
            ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            child: TextButton.icon(
              onPressed: () => setState(() => _table = !_table),
              icon: Icon(
                _table ? Icons.bar_chart_outlined : Icons.table_rows_outlined,
              ),
              label: Text(_table ? l10n.chartShowChart : l10n.chartShowTable),
            ),
          ),
        ),
      ],
    );
  }
}

/// How a bar is drawn. Each style has a distinct shape so series stay
/// distinguishable without color.
enum BarStyle {
  /// Solid fill.
  filled,

  /// Outline with a light fill.
  outlined,
}

/// One labelled horizontal bar.
@immutable
class BarEntry {
  /// Creates the entry; [fraction] is clamped to 0..1.
  const BarEntry({
    required this.label,
    required this.valueText,
    required this.fraction,
    this.detail,
    this.style = BarStyle.filled,
    this.onTap,
  });

  /// Category name, series name…
  final String label;

  /// Formatted value shown at the end of the row.
  final String valueText;

  /// Bar length relative to the largest value.
  final double fraction;

  /// Extra text under the label (share, count).
  final String? detail;

  /// Mark style.
  final BarStyle style;

  /// Drill-down action.
  final VoidCallback? onTap;
}

/// Horizontal bars with labels and values (category breakdown, income vs
/// spending). Long labels wrap; values are always printed.
class HorizontalBars extends StatelessWidget {
  /// Creates the bars.
  const HorizontalBars({required this.entries, super.key});

  /// Rows.
  final List<BarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final BarEntry entry in entries)
          InkWell(
            onTap: entry.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.xs + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // The value moves under the label when both don't fit
                  // (large text, long amounts).
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: Insets.sm,
                    children: <Widget>[
                      Text(entry.label, style: theme.textTheme.bodyMedium),
                      Text(entry.valueText, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  if (entry.detail != null)
                    Text(
                      entry.detail!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: Insets.xs),
                  _Bar(fraction: entry.fraction, style: entry.style),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.style});

  final double fraction;
  final BarStyle style;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double f = fraction.isNaN ? 0 : fraction.clamp(0, 1).toDouble();
    return SizedBox(
      height: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(5),
        ),
        child: FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: f == 0 ? 0 : math.max(f, 0.02),
          child: DecoratedBox(decoration: barDecoration(scheme, style)),
        ),
      ),
    );
  }
}

/// The decoration of a bar in [style].
BoxDecoration barDecoration(ColorScheme scheme, BarStyle style) =>
    switch (style) {
      BarStyle.filled => BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(5),
      ),
      BarStyle.outlined => BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.25),
        border: Border.all(color: scheme.tertiary, width: 2),
        borderRadius: BorderRadius.circular(5),
      ),
    };

/// A legend item: a small mark in [style] and its text.
class LegendItem extends StatelessWidget {
  /// Creates the item.
  const LegendItem({required this.style, required this.label, super.key});

  /// Mark style.
  final BarStyle style;

  /// Series name.
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox.square(
          dimension: 14,
          child: DecoratedBox(decoration: barDecoration(scheme, style)),
        ),
        const SizedBox(width: Insets.xs + 2),
        Flexible(child: Text(label)),
      ],
    );
  }
}

/// One group of vertical bars (a time bucket).
@immutable
class ColumnGroup {
  /// Creates the group; [fractions] are relative to the chart maximum.
  const ColumnGroup({required this.label, required this.fractions});

  /// Axis label (e.g. `4 Nov`).
  final String label;

  /// One value per series, 0..1.
  final List<double> fractions;
}

/// Grouped vertical bars over time (e.g. income and spending per day).
/// Scrolls horizontally when there are many groups; only some axis labels
/// are drawn to avoid overlap (the table lists every value).
class GroupedColumns extends StatelessWidget {
  /// Creates the chart; [styles] has one entry per series.
  const GroupedColumns({
    required this.groups,
    required this.styles,
    this.height = 140,
    super.key,
  });

  /// Groups in time order.
  final List<ColumnGroup> groups;

  /// Style per series.
  final List<BarStyle> styles;

  /// Drawing height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const double barWidth = 10;
    const double gap = 2;
    final double groupWidth = styles.length * (barWidth + gap) + Insets.sm;
    final int labelEvery = math.max(1, (groups.length / 6).ceil());
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < groups.length; i++)
            SizedBox(
              width: math.max(groupWidth, labelEvery == 1 ? 44 : groupWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: height,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        for (int s = 0; s < styles.length; s++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: gap / 2,
                            ),
                            child: SizedBox(
                              width: barWidth,
                              height: _barHeight(groups[i], s),
                              child: DecoratedBox(
                                decoration: barDecoration(
                                  theme.colorScheme,
                                  styles[s],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  SizedBox(
                    height: 18,
                    child: i % labelEvery == 0
                        ? Text(
                            groups[i].label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: theme.textTheme.labelSmall,
                            textScaler: TextScaler.noScaling,
                          )
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _barHeight(ColumnGroup group, int series) {
    if (series >= group.fractions.length) {
      return 0;
    }
    final double f = group.fractions[series];
    if (f.isNaN || f <= 0) {
      return 0;
    }
    return math.max(2, f.clamp(0, 1) * height);
  }
}

/// A line of values over time (account balance history). Values may be
/// negative (credit cards); a zero line is drawn when the range crosses it.
class Sparkline extends StatelessWidget {
  /// Creates the line from [values] in time order.
  const Sparkline({required this.values, this.height = 96, super.key});

  /// Values (e.g. minor units); only their relative size matters.
  final List<int> values;

  /// Drawing height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          line: scheme.primary,
          zero: scheme.outline,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.line,
    required this.zero,
  });

  final List<int> values;
  final Color line;
  final Color zero;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }
    int lo = values.reduce(math.min);
    int hi = values.reduce(math.max);
    if (lo > 0) {
      lo = 0;
    }
    if (hi < 0) {
      hi = 0;
    }
    final double span = (hi - lo) == 0 ? 1 : (hi - lo).toDouble();
    double y(int v) => size.height - ((v - lo) / span) * size.height;
    final double step = values.length == 1
        ? 0
        : size.width / (values.length - 1);
    if (lo < 0 && hi > 0) {
      final Paint zeroPaint = Paint()
        ..color = zero
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), zeroPaint);
    }
    final Path path = Path()..moveTo(0, y(values.first));
    for (int i = 1; i < values.length; i++) {
      path.lineTo(i * step, y(values[i]));
    }
    if (values.length == 1) {
      path.lineTo(size.width, y(values.first));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.line != line ||
      oldDelegate.zero != zero;
}

/// Ratio of two non-negative minor-unit values for drawing only (bar
/// length); never used for amounts shown to the user.
double barFraction(int value, int max) {
  if (max <= 0 || value <= 0) {
    return 0;
  }
  return value / max;
}
