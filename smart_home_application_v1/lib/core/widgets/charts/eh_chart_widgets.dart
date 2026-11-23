import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Data point for energy waveform and line charts
class EHChartDataPoint {
  const EHChartDataPoint({
    required this.x,
    required this.y,
    this.label = '',
  });

  final double x;
  final double y;
  final String label;
}

/// Item for proportional multi-device or multi-channel energy distribution
class EHEnergyDistributionItem {
  const EHEnergyDistributionItem({
    required this.label,
    required this.valueKwh,
    required this.color,
    this.subtitle,
  });

  final String label;
  final double valueKwh;
  final Color color;
  final String? subtitle;
}

/// Production-grade smooth cubic Bezier waveform area chart
class EHEnergyWaveformChart extends StatelessWidget {
  const EHEnergyWaveformChart({
    super.key,
    required this.points,
    this.height = 140,
    this.accentColor,
    this.unit = 'W',
    this.showGrid = true,
    this.showPeakIndicator = true,
  });

  final List<EHChartDataPoint> points;
  final double height;
  final Color? accentColor;
  final String unit;
  final bool showGrid;
  final bool showPeakIndicator;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final color = accentColor ?? tokens.bluePrimary;

    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No telemetry points recorded',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    final maxY = points.map((p) => p.y).reduce(math.max);
    final effectiveMaxY = maxY > 0 ? maxY * 1.15 : 100.0;

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _WaveformChartPainter(
          points: points,
          maxY: effectiveMaxY,
          color: color,
          tokens: tokens,
          unit: unit,
          showGrid: showGrid,
          showPeakIndicator: showPeakIndicator,
        ),
      ),
    );
  }
}

class _WaveformChartPainter extends CustomPainter {
  _WaveformChartPainter({
    required this.points,
    required this.maxY,
    required this.color,
    required this.tokens,
    required this.unit,
    required this.showGrid,
    required this.showPeakIndicator,
  });

  final List<EHChartDataPoint> points;
  final double maxY;
  final Color color;
  final EHThemeTokens tokens;
  final String unit;
  final bool showGrid;
  final bool showPeakIndicator;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftPadding = 36.0;
    const bottomPadding = 20.0;
    const topPadding = 12.0;
    const rightPadding = 10.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // 1. Draw subtle horizontal grid lines & Y labels
    if (showGrid) {
      final gridPaint = Paint()
        ..color = tokens.borderSubtle.withValues(alpha: 0.6)
        ..strokeWidth = 1.0;

      final textStyle = TextStyle(
        color: tokens.textSecondary.withValues(alpha: 0.7),
        fontSize: 9,
        fontWeight: FontWeight.w600,
      );

      final steps = [0.0, 0.5, 1.0];
      for (final step in steps) {
        final yVal = maxY * step;
        final yPos = topPadding + chartHeight * (1.0 - step);
        canvas.drawLine(
          Offset(leftPadding, yPos),
          Offset(size.width - rightPadding, yPos),
          gridPaint,
        );

        final label = '${yVal.toStringAsFixed(0)}$unit';
        final textPainter = TextPainter(
          text: TextSpan(text: label, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(leftPadding - textPainter.width - 4, yPos - textPainter.height / 2),
        );
      }
    }

    // 2. Map data points to screen coordinates
    final n = points.length;
    final coords = <Offset>[];
    int peakIndex = 0;
    double maxVal = -1;

    for (int i = 0; i < n; i++) {
      final p = points[i];
      final xPos = leftPadding + (n > 1 ? (i / (n - 1)) * chartWidth : chartWidth / 2);
      final ratio = (p.y / maxY).clamp(0.0, 1.0);
      final yPos = topPadding + chartHeight * (1.0 - ratio);
      coords.add(Offset(xPos, yPos));

      if (p.y > maxVal) {
        maxVal = p.y;
        peakIndex = i;
      }
    }

    if (coords.isEmpty) return;

    // 3. Build smooth cubic Bezier path
    final path = Path();
    path.moveTo(coords[0].dx, coords[0].dy);

    for (int i = 0; i < coords.length - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // 4. Fill gradient area under curve
    final fillPath = Path.from(path)
      ..lineTo(coords.last.dx, topPadding + chartHeight)
      ..lineTo(coords.first.dx, topPadding + chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight));

    canvas.drawPath(fillPath, fillPaint);

    // 5. Stroke line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // 6. Highlight peak indicator
    if (showPeakIndicator && maxVal > 0) {
      final peakPoint = coords[peakIndex];
      final peakHaloPaint = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(peakPoint, 7, peakHaloPaint);

      final peakDotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(peakPoint, 3.5, peakDotPaint);

      final peakText = '${maxVal.toStringAsFixed(0)} $unit Peak';
      final peakPainter = TextPainter(
        text: TextSpan(
          text: peakText,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final bubbleX = (peakPoint.dx - peakPainter.width / 2)
          .clamp(leftPadding, size.width - rightPadding - peakPainter.width);
      final bubbleY = (peakPoint.dy - peakPainter.height - 8).clamp(0.0, size.height);

      peakPainter.paint(canvas, Offset(bubbleX, bubbleY));
    }

    // 7. Draw X-axis timestamps if labels exist
    final labelStyle = TextStyle(
      color: tokens.textSecondary.withValues(alpha: 0.8),
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    // Stride labels to avoid overlap
    final stride = (n / 5).ceil().clamp(1, 10);
    for (int i = 0; i < n; i += stride) {
      if (points[i].label.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(text: points[i].label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final xPos = coords[i].dx - textPainter.width / 2;
        final clampedX = xPos.clamp(leftPadding, size.width - rightPadding - textPainter.width);
        textPainter.paint(canvas, Offset(clampedX, size.height - bottomPadding + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxY != maxY ||
        oldDelegate.color != color;
  }
}

/// Production-grade vertical bar chart for daily / weekly consumption
class EHEnergyBarChart extends StatelessWidget {
  const EHEnergyBarChart({
    super.key,
    required this.bars,
    this.height = 140,
    this.barColor,
    this.activeBarColor,
    this.unit = 'kWh',
  });

  final List<EHChartDataPoint> bars;
  final double height;
  final Color? barColor;
  final Color? activeBarColor;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final defaultColor = barColor ?? tokens.bluePrimary.withValues(alpha: 0.45);
    final highlightColor = activeBarColor ?? tokens.bluePrimary;

    if (bars.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No periodic consumption recorded',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    final maxY = bars.map((b) => b.y).reduce(math.max);
    final effectiveMaxY = maxY > 0 ? maxY * 1.2 : 10.0;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final barCount = bars.length;
          final barWidth = (totalWidth / (barCount * 1.6)).clamp(12.0, 36.0);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(barCount, (index) {
              final b = bars[index];
              final ratio = (b.y / effectiveMaxY).clamp(0.04, 1.0);
              final isLatest = index == barCount - 1;
              final color = isLatest ? highlightColor : defaultColor;

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    b.y > 0 ? b.y.toStringAsFixed(1) : '0',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isLatest ? FontWeight.w800 : FontWeight.w600,
                      color: isLatest ? highlightColor : tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: barWidth,
                    height: (height - 40) * ratio,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    b.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isLatest ? FontWeight.w700 : FontWeight.w500,
                      color: isLatest ? tokens.textPrimary : tokens.textSecondary,
                    ),
                  ),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}

/// Proportional horizontal distribution bar for rooms or devices
class EHEnergyDistributionBar extends StatelessWidget {
  const EHEnergyDistributionBar({
    super.key,
    required this.items,
    this.totalLabel = 'Total Usage',
  });

  final List<EHEnergyDistributionItem> items;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final total = items.fold<double>(0.0, (acc, item) => acc + item.valueKwh);

    if (items.isEmpty || total <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Multi-segment progress track
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: items.map((item) {
                final flex = ((item.valueKwh / total) * 1000).toInt().clamp(1, 1000);
                return Expanded(
                  flex: flex,
                  child: Container(
                    color: item.color,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Legend items
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: items.map((item) {
            final pct = (item.valueKwh / total * 100).toStringAsFixed(0);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${item.label} ($pct%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
