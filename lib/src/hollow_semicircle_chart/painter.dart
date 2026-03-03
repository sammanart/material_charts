import 'dart:math';

import 'package:flutter/material.dart';

/// Custom painter for rendering a hollow semi-circle chart.
class HollowSemiCircleChart extends CustomPainter {
  /// The percentage of the chart that is filled.
  final double percentage;

  /// Color for the active (filled) section of the chart.
  final Color activeColor;
  /// Optional list of colors for the active (filled) section. When provided,
  /// the active sweep will be painted using these colors sequentially.
  final List<Color> activeColors;
  /// Optional list of percentages per active color segment (each 0-100).
  /// When non-empty, these values represent the percentage of the full
  /// semicircle occupied by each corresponding color.
  final List<double> activePercentages;

  /// Color for the inactive (unfilled) section of the chart.
  final Color inactiveColor;

  /// The radius ratio for the hollow section of the chart (0 < hollowRadius < 1).
  final double hollowRadius;

  /// Constructs a HollowSemiCircleChart object with required parameters.
  HollowSemiCircleChart({
    required this.percentage,
    required this.activeColor,
    required this.inactiveColor,
    required this.hollowRadius,
    this.activeColors = const [],
    this.activePercentages = const [],
  });

  /// Paints the chart onto the canvas.
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final outerRadius = size.height; // The outer radius is equal to height
    final innerRadius = outerRadius * hollowRadius; // Hollow inner radius
    final strokeWidth = outerRadius - innerRadius; // Width of the stroke

    // If hollowRadius == 0 we want a filled semicircle (solid), not a very
    // wide stroked arc. Special-case that by drawing filled arcs using
    // `useCenter: true` so the painter renders solid semicircles / segments.
    if (hollowRadius <= 0) {
      // Draw filled background semicircle
      final backgroundPaint = Paint()
        ..color = inactiveColor
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        pi, // Start angle (left side)
        pi, // Sweep angle (half-circle)
        true,
        backgroundPaint,
      );

      // Draw the progress (active) filled arcs.
      if (activePercentages.isNotEmpty) {
        final rect = Rect.fromCircle(center: center, radius: outerRadius);
        double currentStart = pi;
        final colors = activeColors.isNotEmpty ? activeColors : [activeColor];

        for (var i = 0; i < activePercentages.length; i++) {
          final p = activePercentages[i].clamp(0.0, 100.0);
          if (p <= 0) continue;
          final sweep = (p / 100.0) * pi;

          final color = i < colors.length ? colors[i] : colors.last;

          final segmentPaint = Paint()
            ..color = color
            ..style = PaintingStyle.fill;

          canvas.drawArc(rect, currentStart, sweep, true, segmentPaint);
          currentStart += sweep;
          if (currentStart >= pi * 2) break;
        }
      } else if (percentage > 0) {
        final colors = activeColors.isNotEmpty ? activeColors : [activeColor];
        final progressAngle = (percentage / 100) * pi;

        double remaining = progressAngle;
        double currentStart = pi;
        final rect = Rect.fromCircle(center: center, radius: outerRadius);
        final perSegmentMax = progressAngle / colors.length;

        for (var i = 0; i < colors.length && remaining > 0; i++) {
          final sweep = remaining < perSegmentMax ? remaining : perSegmentMax;
          final segmentPaint = Paint()
            ..color = colors[i]
            ..style = PaintingStyle.fill;

          canvas.drawArc(rect, currentStart, sweep, true, segmentPaint);
          currentStart += sweep;
          remaining -= sweep;
        }
      }

      return;
    }

    // Draw the background (inactive) arc for hollow charts (stroked ring).
    final backgroundPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: (innerRadius + outerRadius) / 2),
      pi, // Start angle (left side)
      pi, // Sweep angle (half-circle)
      false,
      backgroundPaint,
    );

    // Draw the progress (active) arcs.
    // If explicit per-segment percentages are provided, use them.
    if (activePercentages.isNotEmpty) {
      final rect =
          Rect.fromCircle(center: center, radius: (innerRadius + outerRadius) / 2);
      double currentStart = pi;
      final colors = activeColors.isNotEmpty ? activeColors : [activeColor];

      for (var i = 0; i < activePercentages.length; i++) {
        final p = activePercentages[i].clamp(0.0, 100.0);
        if (p <= 0) continue;
        final sweep = (p / 100.0) * pi;

        final color = i < colors.length ? colors[i] : colors.last;

        final segmentPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;

        canvas.drawArc(rect, currentStart, sweep, false, segmentPaint);
        currentStart += sweep;
        // stop if we reached the full semicircle
        if (currentStart >= pi * 2) break;
      }
    } else if (percentage > 0) {
      final colors = activeColors.isNotEmpty ? activeColors : [activeColor];
      final progressAngle = (percentage / 100) * pi;

      // Paint segments sequentially until we consume progressAngle.
      double remaining = progressAngle;
      double currentStart = pi; // start from left side
      final rect =
          Rect.fromCircle(center: center, radius: (innerRadius + outerRadius) / 2);

      // Divide the total progress among the provided colors evenly.
      final perSegmentMax = progressAngle / colors.length;

      for (var i = 0; i < colors.length && remaining > 0; i++) {
        final sweep = remaining < perSegmentMax ? remaining : perSegmentMax;

        final segmentPaint = Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;

        canvas.drawArc(
          rect,
          currentStart,
          sweep,
          false,
          segmentPaint,
        );

        currentStart += sweep;
        remaining -= sweep;
      }
    }
  }

  /// Determines whether the painter should repaint when the properties change.
  @override
  bool shouldRepaint(HollowSemiCircleChart oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.hollowRadius != hollowRadius ||
        oldDelegate.activeColors.length != activeColors.length ||
        oldDelegate.activePercentages.length != activePercentages.length ||
        // quick check: compare each color
        !List.generate(activeColors.length, (i) => activeColors[i])
          .asMap()
          .entries
          .every((e) => e.value == oldDelegate.activeColors[e.key]) ||
        !List.generate(activePercentages.length, (i) => activePercentages[i])
          .asMap()
          .entries
          .every((e) => e.value == oldDelegate.activePercentages[e.key]);
  }
}
