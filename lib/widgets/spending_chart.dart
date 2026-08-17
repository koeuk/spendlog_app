import 'package:flutter/material.dart';

import '../models/report.dart';
import '../theme.dart';
import '../utils/format.dart';

/// The report's bar chart, painted rather than pulled in as a dependency — it
/// draws one rectangle per bucket and needs none of what a charting package
/// brings with it.
///
/// Tapping a bar names it and its amount, which is the only thing a tooltip
/// would have said; there is no hover on a phone to show one anyway.
class SpendingChart extends StatefulWidget {
  const SpendingChart({super.key, required this.buckets, this.height = 150});

  final List<ReportBucket> buckets;
  final double height;

  @override
  State<SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<SpendingChart> {
  int? _selected;

  @override
  void didUpdateWidget(SpendingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The selection indexes into the old period's buckets; keeping it would
    // label a bar that is no longer the one being pointed at.
    if (oldWidget.buckets != widget.buckets) _selected = null;
  }

  void _selectAt(double dx, double width) {
    if (widget.buckets.isEmpty) return;

    final index = (dx / width * widget.buckets.length).floor();
    if (index < 0 || index >= widget.buckets.length) return;

    setState(() => _selected = index == _selected ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.buckets.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Nothing to chart yet.',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.4), fontSize: 13),
          ),
        ),
      );
    }

    final selected = _selected != null ? widget.buckets[_selected!] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reserves its line whether or not a bar is selected, so tapping does
        // not shunt the chart up and down.
        SizedBox(
          height: 20,
          child: selected == null
              ? null
              : Row(
                  children: [
                    Text(
                      selected.caption,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      money(selected.value),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _selectAt(details.localPosition.dx, constraints.maxWidth),
            onHorizontalDragUpdate: (details) =>
                _selectAt(details.localPosition.dx, constraints.maxWidth),
            child: CustomPaint(
              size: Size(constraints.maxWidth, widget.height),
              painter: _ChartPainter(
                buckets: widget.buckets,
                selected: _selected,
                labelStyle: TextStyle(
                  fontSize: 10,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.buckets,
    required this.selected,
    required this.labelStyle,
  });

  final List<ReportBucket> buckets;
  final int? selected;
  final TextStyle labelStyle;

  static const _axisHeight = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = size.height - _axisHeight;
    final slot = size.width / buckets.length;

    // Bars stay legible without touching: a 31-day month gets thin bars and a
    // 7-day week gets fat ones, both with the same visual gap.
    final barWidth = (slot * 0.62).clamp(2.0, 26.0);
    final radius = Radius.circular(barWidth < 6 ? barWidth / 2 : 4);

    final peak = buckets.fold<double>(0, (max, b) => b.amount > max ? b.amount : max);

    final baseline = Paint()..color = Colors.black.withValues(alpha: 0.07);
    canvas.drawRect(Rect.fromLTWH(0, plot - 1, size.width, 1), baseline);

    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final centre = slot * i + slot / 2;
      final left = centre - barWidth / 2;

      if (bucket.label.isNotEmpty) {
        _paintLabel(canvas, bucket.label, centre, plot + 4, size.width);
      }

      // A future bucket is drawn as an empty slot, not a zero — it is not a
      // measurement of nothing, it simply has not happened.
      if (bucket.isFuture) continue;

      // Every real bucket keeps a visible stub at zero so the axis reads as a
      // row of days rather than a gap.
      final scaled = peak > 0 ? (bucket.amount / peak) * (plot - 6) : 0.0;
      final height = scaled < 2 ? 2.0 : scaled;

      final isSelected = i == selected;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, plot - height, barWidth, height),
          topLeft: radius,
          topRight: radius,
        ),
        Paint()
          ..color = switch ((isSelected, bucket.isCurrent, bucket.amount > 0)) {
            (true, _, _) => AppTheme.ink,
            (_, true, _) => AppTheme.greenBright,
            (_, _, true) => AppTheme.green,
            _ => Colors.black.withValues(alpha: 0.10),
          },
      );
    }
  }

  void _paintLabel(Canvas canvas, String text, double centre, double top, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    // Clamped so the first and last labels stay inside the card.
    final dx = (centre - painter.width / 2).clamp(0.0, maxWidth - painter.width);

    painter.paint(canvas, Offset(dx, top));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.buckets != buckets || old.selected != selected;
}
