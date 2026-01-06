import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

/// Custom painter for rendering an area chart.
/// This painter is responsible for drawing the chart grid, area fills, lines,
/// data points, and tooltips on a `Canvas`.
class AreaChartPainter extends CustomPainter {
  final List<AreaChartSeries> series; // List of data series to render.
  final double progress; // Animation progress (0.0 to 1.0).
  final AreaChartStyle style; // Style configuration for the chart.
  final Offset? tooltipPosition; // Position of the cursor or hover for tooltips.

  AreaChartPainter({
    required this.series,
    required this.progress,
    required this.style,
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

    // Render each series in the chart.
    for (int i = 0; i < series.length; i++) {
      final seriesData = series[i];
      // Get the colors for the series (fallback to default style colors if not defined).
      final color = seriesData.color ?? style.colors[i % style.colors.length];
      final gradientColor = color.withValues(alpha: 0.0); //adding code, making it more transparent

      // Draw the area below the line for the series.
      _drawArea(canvas, chartArea, seriesData, color.withValues(alpha: 0.2), gradientColor); //adding code,making it start transparent

      // Draw the line connecting the data points.
      _drawLine(canvas, chartArea, seriesData, color);

      // Draw the individual data points if enabled.
      if (seriesData.showPoints ?? style.showPoints) {
        _drawPoints(canvas, chartArea, seriesData, color);
      }
    }

    // Draw crosshair if enabled and a hover position is available //adding code
    if (style.crosshair?.enabled == true && tooltipPosition != null) { //adding code
      _drawCrosshair(canvas, chartArea);//adding code
    }//adding code

    // Draw key event markers if enabled
    if (style.showKeyEventMarkers) {
      for (int i = 0; i < series.length; i++) {
        final seriesData = series[i];
        final color = seriesData.color ?? style.colors[i % style.colors.length];
        _drawKeyEventMarkers(canvas, chartArea, seriesData, color);
      }
    }
  }

  /// Draws the filled area below the line of the chart.
  void _drawArea(
    Canvas canvas,
    Rect chartArea,
    AreaChartSeries seriesData,
    Color color,
    Color gradientColor,
  ) {
    final points = _getSeriesPoints(chartArea, seriesData);
    if (points.isEmpty) return;

    // Create a path that represents the area below the line.
    final path = Path();
    path.moveTo(
      points.first.dx,
      chartArea.bottom,
    ); // Start at the bottom of the chart.
    path.lineTo(
      points.first.dx,
      points.first.dy,
    ); // Move to the first data point.

    // Connect all data points with lines.
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    path.lineTo(
      points.last.dx,
      chartArea.bottom,
    ); // Close the path at the bottom.
    path.close();

    // Create a gradient paint for the area fill.
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, gradientColor],
      ).createShader(chartArea)
      ..style = PaintingStyle.fill;

    // Apply animation progress to the path.
    final pathMetrics = path.computeMetrics().first;
    final animatedPath = pathMetrics.extractPath(
      0.0,
      pathMetrics.length * progress,
    );

    canvas.drawPath(animatedPath, paint);
  }

  /// Draws the line connecting the data points.
  void _drawLine(
    Canvas canvas,
    Rect chartArea,
    AreaChartSeries seriesData,
    Color color,
  ) {
    final points = _getSeriesPoints(chartArea, seriesData);
    if (points.isEmpty) return;

    // Create a path for the line connecting data points.
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    // Draw straight lines between consecutive points.
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Define the paint for the line.
    final paint = Paint()
      ..color = color
      ..strokeWidth = seriesData.lineWidth ?? style.defaultLineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Apply animation progress to the path.
    final pathMetrics = path.computeMetrics().first;
    final animatedPath = pathMetrics.extractPath(
      0.0,
      pathMetrics.length * progress,
    );

    canvas.drawPath(animatedPath, paint);
  }

  /// Draws data points as circles and displays tooltips when hovered.
  void _drawPoints(
    Canvas canvas,
    Rect chartArea,
    AreaChartSeries seriesData,
    Color color,
  ) {
    final points = _getSeriesPoints(chartArea, seriesData);
    final progressPoints = (points.length * progress).floor(); // Limit points based on animation progress.
    final pointSize = seriesData.pointSize ?? style.defaultPointSize;

    // Use default tooltip configuration if series-specific config is not available.
    const defaultTooltip = TooltipConfig();
    final seriesTooltip = seriesData.tooltipConfig ?? defaultTooltip;

    // Iterate through the visible points.
    for (int i = 0; i < progressPoints; i++) {
      final dataPoint = seriesData.dataPoints[i];
      final tooltipConfig = dataPoint.tooltipConfig ?? seriesTooltip; // Use point-specific config or fallback.

      // Draw the data point as a filled circle.
      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(points[i], pointSize, pointPaint);

      // Draw a border around the point for better visibility.
      final borderPaint = Paint()
        ..color = style.backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(points[i], pointSize, borderPaint);

      // Check if tooltip should be displayed based on hover distance.
      if (tooltipPosition != null) {
        final distance = (points[i] - tooltipPosition!).distance;
        if (distance <= tooltipConfig.hoverRadius) {
          _drawTooltip(
            canvas,
            points[i],
            seriesData.name,
            dataPoint,
            chartArea,
            tooltipConfig,
          );
        }
      }
    }
  }

  /// Draws a tooltip near a hovered data point.
  void _drawTooltip(
    Canvas canvas,
    Offset point,
    String seriesName,
    AreaChartData dataPoint,
    Rect chartArea,
    TooltipConfig config,
  ) {
    // If custom content is provided, we can't render it directly on canvas
    // The widget layer will need to handle this
    // For now, we'll draw the text-based tooltip
    final text = config.text ?? '$seriesName: ${dataPoint.value.toStringAsFixed(1)}';
    final textSpan = TextSpan(text: text, style: config.textStyle);

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: config.maxWidth ?? double.infinity);

    // Calculate tooltip dimensions and position.
    final tooltipWidth = textPainter.width + config.padding.horizontal;
    final tooltipHeight = textPainter.height + config.padding.vertical;
    var tooltipX = point.dx - tooltipWidth / 2;
    var tooltipY = point.dy - tooltipHeight - 10;

    // Adjust tooltip position if it goes outside the chart area.
    tooltipX = tooltipX.clamp(chartArea.left, chartArea.right - tooltipWidth);
    if (tooltipY < chartArea.top) {
      tooltipY = point.dy + 10;
    }

    // Draw tooltip background using custom decoration or default
    if (config.decoration != null) {
      config.decoration!.createBoxPainter().paint(
        canvas,
        Offset(tooltipX, tooltipY),
        ImageConfiguration(size: Size(tooltipWidth, tooltipHeight)),
      );
    } else {
      final bgPaint = Paint()
        ..color = config.backgroundColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
          Radius.circular(config.borderRadius),
        ),
        bgPaint,
      );
    }

    // Render the tooltip text.
    textPainter.paint(
      canvas,
      Offset(tooltipX + config.padding.left, tooltipY + config.padding.top),
    );
  }

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
      final pointCount = series[0].dataPoints.length;
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
    return List.generate(seriesData.dataPoints.length, (i) {
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
    return chartArea.left + (chartArea.width / (totalPoints - 1)) * index;
  }

  double _getMaxValue() {
    // Finds the maximum data point value across all series to scale the chart correctly.
    return series.expand((s) => s.dataPoints).map((p) => p.value).reduce(max);
  }

  double _getMinValue() {
    // Finds the minimum data point value across all series to scale the chart correctly.
    // Forces the Y-axis to start from zero if specified in the style.
    if (style.forceYAxisFromZero) return 0;
    return series.expand((s) => s.dataPoints).map((p) => p.value).reduce(min);
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
      ..color = style.backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(yRect, bgPaint);
    yPainter.paint(canvas, Offset(yRect.left + 2, yRect.top + 1));

    // X-axis label from nearest index (first series)
    if (series.isNotEmpty && series.first.dataPoints.isNotEmpty) {
      final count = series.first.dataPoints.length;
      final t = ((tooltipPosition!.dx - chartArea.left) / chartArea.width).clamp(0.0, 1.0);
      final idx = (t * (count - 1)).round();
      final xLabel = series.first.dataPoints[idx].label ?? '${idx + 1}';

      final xSpan = TextSpan(text: xLabel, style: textStyle);
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
      
      // Calculate marker position (above the line point)
      final markerOffset = Offset(
        points[i].dx,
        points[i].dy - config.verticalOffset,
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
