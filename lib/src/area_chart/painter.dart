import 'dart:math';

import 'package:flutter/material.dart';

import '../shared/shared_models.dart';
import 'models.dart';

/// Custom painter for rendering an area chart.
/// This painter is responsible for drawing the chart grid, area fills, lines,
/// data points, and tooltips on a `Canvas`.
class AreaChartPainter extends CustomPainter {
  final List<AreaChartSeries> series; // List of data series to render.
  final double progress; // Animation progress (0.0 to 1.0).
  final List<double> seriesAnimationProgress; // Per-series animation progress
  final Map<int, double> segmentAnimationProgress; // Per-segment animation progress
  final AreaChartStyle style; // Style configuration for the chart.
  final Offset? tooltipPosition; // Position of the cursor or hover for tooltips.

  AreaChartPainter({
    required this.series,
    required this.progress,
    required this.style,
    this.seriesAnimationProgress = const [],
    this.segmentAnimationProgress = const {},
    this.tooltipPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Define the drawable chart area excluding padding.
    final chartArea = _getChartArea(size);

    // Draw grid lines if enabled in the style.
    if (style.showGrid) {
      _drawGrid(canvas, chartArea);
    }

    // Render each series in the chart with segment support.
    for (int i = 0; i < series.length; i++) {
      final seriesData = series[i];
      // Get the colors for the series (fallback to default style colors if not defined).
      final color = seriesData.color ?? style.colors[i % style.colors.length];
      final topFill = color.withValues(alpha: style.areaFillOpacityTop.clamp(0.0, 1.0));
      final bottomFill = color.withValues(alpha: style.areaFillOpacityBottom.clamp(0.0, 1.0));

      // Use per-series animation progress if available, otherwise use global progress
      final seriesProgress = seriesAnimationProgress.isNotEmpty && i < seriesAnimationProgress.length ? seriesAnimationProgress[i] : progress;

      // Group data points by segmentAnimationOrder
      final segmentGroups = <int, List<int>>{};
      for (int j = 0; j < seriesData.dataPoints.length; j++) {
        final point = seriesData.dataPoints[j];
        final segmentOrder = point.segmentAnimationOrder;
        if (!segmentGroups.containsKey(segmentOrder)) {
          segmentGroups[segmentOrder] = [];
        }
        segmentGroups[segmentOrder]!.add(j);
      }

      final sortedOrders = segmentGroups.keys.toList()..sort();

      // Draw each segment group based on whether it has explicit animation config
      for (final segmentOrder in sortedOrders) {
        final indices = segmentGroups[segmentOrder]!;
        if (indices.isEmpty) continue;

        // Check if this segment has explicit animation config
        final hasSegmentConfig = style.segmentAnimationConfigs.containsKey(segmentOrder);

        if (hasSegmentConfig) {
          // Draw with segment animation (only during segment phase)
          final segmentProgress = segmentAnimationProgress[segmentOrder] ?? 0.0;
          if (segmentProgress > 0.001) {
            _drawSegmentGroup(
              canvas,
              chartArea,
              seriesData,
              indices,
              color,
              topFill,
              bottomFill,
              segmentProgress,
              segmentOrder,
            );
          }
        } else {
          // Draw with series animation (default behavior for segments without explicit config)
          if (seriesProgress > 0.0) {
            _drawSegmentGroup(
              canvas,
              chartArea,
              seriesData,
              indices,
              color,
              topFill,
              bottomFill,
              seriesProgress,
              segmentOrder,
              useSeriesAnimation: true,
            );
          }
        }
      }
    }

    // Draw crosshair if enabled and a hover position is available
    if (style.crosshair?.enabled == true && tooltipPosition != null) {
      _drawCrosshair(canvas, chartArea);
    }

    // Draw baseline if enabled
    if (style.baseline?.show == true) {
      _drawBaseline(canvas, chartArea);
    }

    // Draw key event markers if enabled
    if (style.showKeyEventMarkers) {
      for (int i = 0; i < series.length; i++) {
        final seriesData = series[i];
        final color = seriesData.color ?? style.colors[i % style.colors.length];
        _drawKeyEventMarkers(canvas, chartArea, seriesData, color);
      }
    }
  }

  /// Draws a single segment group with animation.
  ///
  /// This unified method handles both series-animation-phase and segment-animation-phase rendering.
  /// When useSeriesAnimation is true, applies series-level animation effects.
  /// When false, applies segment-level animation effects.
  void _drawSegmentGroup(
    Canvas canvas,
    Rect chartArea,
    AreaChartSeries seriesData,
    List<int> indices,
    Color color,
    Color topFill,
    Color bottomFill,
    double progress,
    int segmentOrder, {
    bool useSeriesAnimation = false,
  }) {
    final points = _getSeriesPoints(chartArea, seriesData);
    if (points.isEmpty || indices.isEmpty) return;

    // Get start and end indices for this segment
    // Important: indices refer to dataPoint indices, but points might be shorter due to xSpanSlots
    // Clamp indices to the actual points length
    int startIdx = indices.first.clamp(0, points.length - 1);
    int endIdx = indices.last.clamp(0, points.length - 1);

    // For segment animations (not series animation), connect to previous segment's last point
    // This ensures continuity when revealing new segments progressively
    if (!useSeriesAnimation && startIdx > 0) {
      startIdx = (startIdx - 1).clamp(0, points.length - 1); // Include previous point to connect the area/line
    }

    // Ensure we have valid indices
    if (startIdx >= points.length || endIdx >= points.length || startIdx > endIdx) return;

    final segmentPoints = points.sublist(startIdx, endIdx + 1);

    if (segmentPoints.length < 2) return;

    // Determine animation effects based on phase
    double opacity = 1.0;
    double offsetY = 0.0;
    bool shouldDrawProgressively = true;

    if (useSeriesAnimation) {
      // Apply series animation effects
      final animConfig = seriesData.animationConfig;
      final animType = animConfig?.animationType ?? AreaAnimationType.drawLine;
      if (animType == AreaAnimationType.fadeIn) {
        opacity = progress;
        shouldDrawProgressively = false;
      } else if (animType == AreaAnimationType.slideUp) {
        opacity = progress;
        offsetY = (1.0 - progress) * 20.0;
        shouldDrawProgressively = false;
      }
    } else {
      // Apply segment animation effects
      final segmentConfig = style.segmentAnimationConfigs[segmentOrder];
      if (segmentConfig != null) {
        final animType = segmentConfig.animationType;
        if (animType == SegmentAnimationType.fadeIn) {
          opacity = progress;
          shouldDrawProgressively = false;
        } else if (animType == SegmentAnimationType.slideUp) {
          opacity = progress;
          offsetY = (1.0 - progress) * 20.0;
          shouldDrawProgressively = false;
        }
        // drawPoint means progressive drawing
      }
    }

    // Early exit for zero progress/opacity
    if (shouldDrawProgressively && progress <= 0.0) return;
    if (!shouldDrawProgressively && opacity <= 0.0) return;

    canvas.save();
    if (offsetY != 0.0) {
      canvas.translate(0, offsetY);
    }

    // Draw the area
    _drawSegmentArea(canvas, chartArea, segmentPoints, topFill, bottomFill, progress, opacity, shouldDrawProgressively);

    // Draw the line
    _drawSegmentLine(canvas, segmentPoints, seriesData, color, progress, opacity, shouldDrawProgressively);

    // Draw points if enabled
    if (seriesData.showPoints ?? style.showPoints) {
      _drawSegmentPoints(canvas, segmentPoints, seriesData, color, progress, opacity, shouldDrawProgressively, !useSeriesAnimation && startIdx > 0);
    }

    canvas.restore();
  }

  /// Draws the area for a segment
  void _drawSegmentArea(
    Canvas canvas,
    Rect chartArea,
    List<Offset> segmentPoints,
    Color topFill,
    Color bottomFill,
    double progress,
    double opacity,
    bool shouldDrawProgressively,
  ) {
    // Safety check: need at least 2 points to draw an area
    if (segmentPoints.isEmpty) return;

    // Create a path that represents the area below the line.
    final path = Path();
    path.moveTo(segmentPoints.first.dx, chartArea.bottom);
    path.lineTo(segmentPoints.first.dx, segmentPoints.first.dy);

    for (int i = 1; i < segmentPoints.length; i++) {
      path.lineTo(segmentPoints[i].dx, segmentPoints[i].dy);
    }

    path.lineTo(segmentPoints.last.dx, chartArea.bottom);
    path.close();

    // Create a gradient paint for the area fill with opacity.
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          topFill.withValues(alpha: opacity * topFill.a),
          bottomFill.withValues(alpha: opacity * bottomFill.a),
        ],
      ).createShader(chartArea)
      ..style = PaintingStyle.fill;

    // Apply animation progress to the path if needed
    if (shouldDrawProgressively) {
      if (progress <= 0.0) return;
      if (progress >= 1.0) {
        canvas.drawPath(path, paint);
        return;
      }

      final startX = segmentPoints.first.dx;
      final endX = segmentPoints.last.dx;
      final revealX = startX + (endX - startX) * progress;

      canvas.save();
      canvas.clipRect(Rect.fromLTRB(startX, chartArea.top, revealX, chartArea.bottom));
      canvas.drawPath(path, paint);
      canvas.restore();
    } else {
      canvas.drawPath(path, paint);
    }
  }

  /// Draws the line for a segment
  void _drawSegmentLine(
    Canvas canvas,
    List<Offset> segmentPoints,
    AreaChartSeries seriesData,
    Color color,
    double progress,
    double opacity,
    bool shouldDrawProgressively,
  ) {
    // Safety check: need at least 1 point to draw
    if (segmentPoints.isEmpty) return;
    final path = Path();
    path.moveTo(segmentPoints.first.dx, segmentPoints.first.dy);

    for (int i = 1; i < segmentPoints.length; i++) {
      path.lineTo(segmentPoints[i].dx, segmentPoints[i].dy);
    }

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = seriesData.lineWidth ?? style.defaultLineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (shouldDrawProgressively) {
      final pathMetrics = path.computeMetrics().toList();
      if (pathMetrics.isEmpty) return;
      final metric = pathMetrics.first;
      final animatedPath = metric.extractPath(0.0, metric.length * progress);
      canvas.drawPath(animatedPath, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  /// Draws points for a segment
  void _drawSegmentPoints(
    Canvas canvas,
    List<Offset> segmentPoints,
    AreaChartSeries seriesData,
    Color color,
    double progress,
    double opacity,
    bool shouldDrawProgressively,
    bool hasConnectingPoint,
  ) {
    // Safety check: need at least 1 point to draw
    if (segmentPoints.isEmpty) return;
    final pointSize = seriesData.pointSize ?? style.defaultPointSize;
    final pointPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = style.backgroundColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (shouldDrawProgressively) {
      // Calculate cumulative distances to each point in the segment
      final distancesToPoints = <double>[0.0];
      double cumulativeDist = 0.0;
      for (int i = 0; i < segmentPoints.length - 1; i++) {
        final p1 = segmentPoints[i];
        final p2 = segmentPoints[i + 1];
        cumulativeDist += (p2 - p1).distance;
        distancesToPoints.add(cumulativeDist);
      }

      final totalDist = cumulativeDist > 0 ? cumulativeDist : 1.0;
      final drawnDistance = totalDist * progress;

      // Show points progressively as line reaches them
      for (int i = 0; i < segmentPoints.length; i++) {
        // For segment animations, always show the first point (connecting point from previous segment)
        final isConnectingPoint = hasConnectingPoint && i == 0;
        if (isConnectingPoint || drawnDistance >= distancesToPoints[i]) {
          canvas.drawCircle(segmentPoints[i], pointSize, pointPaint);
          canvas.drawCircle(segmentPoints[i], pointSize, borderPaint);
        }
      }
    } else {
      // Show all points with opacity effect
      for (final point in segmentPoints) {
        canvas.drawCircle(point, pointSize, pointPaint);
        canvas.drawCircle(point, pointSize, borderPaint);
      }
    }
  }

  /// Draws a tooltip near a hovered data point.
  /// Draws the grid lines and their labels (horizontal and vertical).
  void _drawGrid(Canvas canvas, Rect chartArea) {
    final paint = Paint()
      ..color = style.gridColor.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    // Horizontal grid lines and labels.
    for (int i = 0; i <= style.horizontalGridLines; i++) {
      final y = chartArea.top + (chartArea.height / style.horizontalGridLines) * i;
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right + 25, y), //adding code, allows to have a longer horizontal line where the stats can rest.
        paint,
      );

      if (series.isNotEmpty) {
        final maxValue = _getMaxValue();
        final minValue = _getMinValue();
        final valueRange = maxValue - minValue;
        final value = maxValue - (valueRange / style.horizontalGridLines * i);

        final textSpan = TextSpan(
          text: value.toStringAsFixed(1),
          style: style.labelStyle ?? TextStyle(color: style.gridColor, fontSize: 10),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            //CURRENT CHANGES
            chartArea.right + 25, //adding code, make the y axis label more to the right
            y - textPainter.height / 2, //is only the height of the number
          ),
        );
      }
    }

    // Vertical grid lines and labels.
    if (series.isNotEmpty && series[0].dataPoints.isNotEmpty) {
      final slots = style.xSpanSlots ?? series[0].dataPoints.length;
      final pointCount = min(series[0].dataPoints.length, slots);
      for (int i = 0; i < pointCount; i++) {
        if (series[0].dataPoints.elementAt(i).label != null && series[0].dataPoints.elementAt(i).label != "") {
          //adding code, this condition allows a vertical line to be drawn ONLY if the data point has a label or an empty string.
          //It will STILL display if you put a space " ". So you have a way to display a VERTICAL LINE WITHOUT TEXT.
          final x = _getXCoordinate(chartArea, i, pointCount);
          canvas.drawLine(
            Offset(x, chartArea.top),
            Offset(x, chartArea.bottom),
            paint,
          );

          final label = series[0].dataPoints[i].label;
          if (label != null) {
            final textSpan = TextSpan(
              text: label,
              style: style.labelStyle ?? TextStyle(color: style.gridColor, fontSize: 10),
            );
            final textPainter = TextPainter(
              text: textSpan,
              textDirection: TextDirection.ltr,
            )..layout();

            textPainter.paint(
              canvas,
              Offset(x - textPainter.width / 2, chartArea.bottom + 5),
            );
          }
        }
      }
    }
  }

  /// Calculates the drawable chart area, excluding padding.
  Rect _getChartArea(Size size) {
    return Rect.fromLTWH(
      style.padding.left,
      style.padding.top,
      size.width - style.padding.horizontal,
      size.height - style.padding.vertical,
    );
  }

  /// Maps data points to their visual positions in the chart.
  List<Offset> _getSeriesPoints(Rect chartArea, AreaChartSeries seriesData) {
    // If there are no data points, return an empty list.
    if (seriesData.dataPoints.isEmpty) return [];

    // Retrieve the maximum and minimum values from the series data to normalize the points.
    final maxValue = _getMaxValue();
    final minValue = _getMinValue();
    final valueRange = maxValue - minValue;

    // Generate a list of points representing the chart's data. Each point is calculated
    // by mapping the data value to the Y-coordinate within the chart area.
    final slots = style.xSpanSlots ?? seriesData.dataPoints.length;
    final count = seriesData.dataPoints.length < slots ? seriesData.dataPoints.length : slots;
    return List.generate(count, (i) {
      final x = _getXCoordinate(
        chartArea,
        i,
        seriesData.dataPoints.length,
      ); // X position
      final normalizedValue = (seriesData.dataPoints[i].value - minValue) / valueRange; // Normalize Y value
      final y = chartArea.bottom - (normalizedValue * chartArea.height); // Y position
      return Offset(x, y); // Return the computed coordinate
    });
  }

  double _getXCoordinate(Rect chartArea, int index, int totalPoints) {
    // Calculates the X-coordinate for a data point based on its index.
    // Distributes points evenly across the width of the chart area.
    final slots = style.xSpanSlots ?? totalPoints;
    final denom = (slots - 1) <= 0 ? 1 : (slots - 1);

    return chartArea.left + (chartArea.width / denom) * index;
  }

  double _getMaxValue() {
    // Finds the maximum value across all series within the effective slot window.
    final slots = style.xSpanSlots;
    final values = <double>[];
    for (final s in series) {
      final takeCount = slots == null ? s.dataPoints.length : min(s.dataPoints.length, slots);
      if (takeCount > 0) {
        values.addAll(s.dataPoints.take(takeCount).map((p) => p.value));
      }
    }
    return values.reduce(max);
  }

  double _getMinValue() {
    // Finds the minimum value across all series within the effective slot window.
    // Forces the Y-axis to start from zero if specified in the style.
    if (style.forceYAxisFromZero) return 0;
    final slots = style.xSpanSlots;
    final values = <double>[];
    for (final s in series) {
      final takeCount = slots == null ? s.dataPoints.length : min(s.dataPoints.length, slots);
      if (takeCount > 0) {
        values.addAll(s.dataPoints.take(takeCount).map((p) => p.value));
      }
    }
    return values.reduce(min);
  }

  /// Retrieves the value represented at the specified position within the chart.
  /// The value is normalized based on the position of the pointer in the chart area.
  double _getValueAtPosition(Offset position, Rect chartArea) {
    final maxValue = _getMaxValue();
    final minValue = _getMinValue();
    final range = maxValue - minValue;
    if (range == 0) return minValue;

    // Map Y from top->bottom to max->min
    final clampedY = position.dy.clamp(chartArea.top, chartArea.bottom);
    final t = (clampedY - chartArea.top) / chartArea.height;
    return maxValue - t * range;
  }

  /// Draws the crosshair lines and optional labels similar to Multi-Line chart.
  void _drawCrosshair(Canvas canvas, Rect chartArea) {
    if (tooltipPosition == null || style.crosshair == null) return;

    final cfg = style.crosshair!;
    final paint = Paint()
      ..color = cfg.lineColor
      ..strokeWidth = cfg.lineWidth;

    // Vertical line
    canvas.drawLine(
      Offset(tooltipPosition!.dx, chartArea.top),
      Offset(tooltipPosition!.dx, chartArea.bottom),
      paint,
    );

    // Horizontal line
    canvas.drawLine(
      Offset(chartArea.left, tooltipPosition!.dy),
      Offset(chartArea.right, tooltipPosition!.dy),
      paint,
    );

    if (cfg.showLabel) {
      _drawCrosshairLabels(canvas, chartArea);
    }
  }

  /// Draws labels for crosshair (Y value and X label if available).
  void _drawCrosshairLabels(Canvas canvas, Rect chartArea) {
    if (tooltipPosition == null || style.crosshair == null) return;

    final cfg = style.crosshair!;
    final textStyle = cfg.labelStyle ?? TextStyle(color: cfg.lineColor, fontSize: 10);

    // Y-axis value label
    final yVal = _getValueAtPosition(tooltipPosition!, chartArea).toStringAsFixed(1);
    final ySpan = TextSpan(text: yVal, style: textStyle);
    final yPainter = TextPainter(text: ySpan, textDirection: TextDirection.ltr)..layout();

    final yRect = Rect.fromLTWH(
      chartArea.right + 23,
      (tooltipPosition!.dy - yPainter.height / 2).clamp(chartArea.top, chartArea.bottom - yPainter.height),
      yPainter.width + 4,
      yPainter.height + 2,
    );

    final bgPaint = Paint()
      ..color = cfg.labelBackgroundColor ?? style.backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(yRect, bgPaint);
    yPainter.paint(canvas, Offset(yRect.left + 2, yRect.top + 1));

    // X-axis label from nearest index (first series)
    if (series.isNotEmpty && series.first.dataPoints.isNotEmpty) {
      final rawCount = series.first.dataPoints.length;
      final slots = style.xSpanSlots ?? rawCount;
      final count = min(rawCount, slots);
      final denom = (slots - 1) <= 0 ? 1 : (slots - 1);

      final t = ((tooltipPosition!.dx - chartArea.left) / chartArea.width).clamp(0.0, 1.0);
      final slotIdx = (t * denom).round();
      final idx = slotIdx.clamp(0, count - 1);
      final label = series.first.dataPoints[idx].label;
      // Only display X-axis crosshair label when it's non-null and non-empty
      if (label != null && label.trim().isNotEmpty) {
        final xSpan = TextSpan(text: label, style: textStyle);
        final xPainter = TextPainter(text: xSpan, textDirection: TextDirection.ltr)..layout();

        final xRect = Rect.fromLTWH(
          (tooltipPosition!.dx - xPainter.width / 2).clamp(chartArea.left, chartArea.right - xPainter.width),
          chartArea.bottom + 4,
          xPainter.width + 4,
          xPainter.height + 2,
        );

        canvas.drawRect(xRect, bgPaint);
        xPainter.paint(canvas, Offset(xRect.left + 2, xRect.top + 1));
      }
    }
  }

  /// Draws a dotted horizontal baseline at the height of the first data point value
  void _drawBaseline(Canvas canvas, Rect chartArea) {
    if (series.isEmpty || series.first.dataPoints.isEmpty) return;

    final config = style.baseline!;
    final firstValue = series.first.dataPoints.first.value;
    final seriesColor = series.first.color ?? style.colors.first;
    final baselineColor = config.color ?? seriesColor;

    // Calculate Y position for the first value
    final maxValue = _getMaxValue();
    final minValue = _getMinValue();
    final valueRange = maxValue - minValue;

    if (valueRange == 0) return;

    final normalizedValue = (firstValue - minValue) / valueRange;
    final y = chartArea.bottom - (normalizedValue * chartArea.height);

    // Create paint for the dotted line
    final paint = Paint()
      ..color = baselineColor
      ..strokeWidth = config.strokeWidth
      ..style = PaintingStyle.stroke;

    // Draw dotted line across the chart
    final path = Path();
    double startX = chartArea.left;
    final endX = chartArea.right;

    // Create dashed pattern
    final dashWidth = config.dashPattern[0];
    final dashSpace = config.dashPattern.length > 1 ? config.dashPattern[1] : dashWidth;

    while (startX < endX) {
      path.moveTo(startX, y);
      startX += dashWidth;
      if (startX > endX) startX = endX;
      path.lineTo(startX, y);
      startX += dashSpace;
    }

    canvas.drawPath(path, paint);
  }

  /// Draws key event markers above the line for data points that have key events
  void _drawKeyEventMarkers(
    Canvas canvas,
    Rect chartArea,
    AreaChartSeries seriesData,
    Color seriesColor,
  ) {
    final points = _getSeriesPoints(chartArea, seriesData);
    final progressPoints = (points.length * progress).floor();
    final config = style.keyEventMarkerConfig ?? const KeyEventMarkerConfig();

    for (int i = 0; i < progressPoints; i++) {
      final dataPoint = seriesData.dataPoints[i];
      if (dataPoint.keyEvent == null) continue;

      final keyEvent = dataPoint.keyEvent!;
      final markerColor = keyEvent.markerColor ?? config.defaultColor;
      final markerSize = keyEvent.markerSize ?? config.size; // Use custom size if provided
      final verticalOffset = keyEvent.verticalOffset ?? config.verticalOffset; // Use custom offset if provided

      // Calculate marker position (above the line point)
      final markerOffset = Offset(
        points[i].dx,
        points[i].dy - verticalOffset,
      );

      // Draw the main marker circle
      final markerPaint = Paint()
        ..color = markerColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(markerOffset, markerSize / 2, markerPaint);

      // Check if we should show tooltip for this key event
      if (tooltipPosition != null) {
        final distance = (markerOffset - tooltipPosition!).distance;
        // Use marker size as hover radius (cursor must be on the circle)
        final hoverRadius = markerSize / 2;
        if (distance <= hoverRadius) {
          _drawKeyEventTooltip(canvas, markerOffset, keyEvent, chartArea);
        }
      }
    }
  }

  /// Draws a rich tooltip for key events
  /// HTML tooltips are rendered by the widget overlay, not here
  void _drawKeyEventTooltip(
    Canvas canvas,
    Offset markerPosition,
    KeyEventData keyEvent,
    Rect chartArea,
  ) {
    // All tooltips are now HTML-based and rendered by the widget overlay
    // If no HTML content is provided, nothing is displayed
    return;
  }

  @override
  bool shouldRepaint(AreaChartPainter oldDelegate) {
    // Determines if the painter needs to redraw the chart. Triggers repaint if:
    // - The animation progress changes
    // - The data series change
    // - The chart style is updated
    // - The tooltip position changes
    return oldDelegate.progress != progress || oldDelegate.series != series || oldDelegate.style != style || oldDelegate.tooltipPosition != tooltipPosition;
  }
}
