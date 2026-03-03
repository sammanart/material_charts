import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

/// Custom painter for rendering a bar chart with rotation support.
///
/// This class is responsible for drawing the bar chart, including bars, grid lines,
/// and labels based on the provided data and styling options. Supports rotation
/// at any angle while keeping text elements readable (non-rotated).
class BarChartPainter extends CustomPainter {
  final List<BarChartData> data; // Data points to be displayed in the chart
  final double progress; // Animation progress from 0.0 to 1.0
  final BarChartStyle style; // Styling options for the chart
  final bool showGrid; // Flag to show or hide grid lines
  final bool showValues; // Flag to show or hide bar values
  final EdgeInsets padding; // Padding around the chart
  final int horizontalGridLines; // Number of horizontal grid lines to draw
  final Offset? hoverPosition; // Position of the mouse hover (for interaction)
  final bool showTooltip; // Whether to show tooltip on hover
  final Color? tooltipBackgroundColor;
  final TextStyle? tooltipTextStyle;
  final double tooltipPadding;
  final double tooltipRadius;

  /// Creates an instance of [BarChartPainter].
  BarChartPainter({
    required this.data,
    required this.progress,
    required this.style,
    required this.showGrid,
    required this.showValues,
    required this.padding,
    required this.horizontalGridLines,
    required this.hoverPosition,
    required this.showTooltip,
    required this.tooltipBackgroundColor,
    required this.tooltipTextStyle,
    required this.tooltipPadding,
    required this.tooltipRadius,
  });

  // Temporary storage for the hovered bar to draw tooltip on top
  Offset? _pendingTooltipPos;
  double? _pendingTooltipValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return; // Exit if there's no data to display

    final chartArea = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );

    // Determine if we're in horizontal mode (90 or 270 degrees)
    final isHorizontalMode = _isHorizontalOrientation();

    if (showGrid) {
      _drawGrid(canvas, chartArea, isHorizontalMode);
    }

    // Reset pending tooltip before drawing
    _pendingTooltipPos = null;
    _pendingTooltipValue = null;

    _drawBars(canvas, chartArea, isHorizontalMode);
    _drawLabels(canvas, chartArea, isHorizontalMode);

    // Draw tooltip last so it appears on top of bars
    if (showTooltip && _pendingTooltipPos != null && _pendingTooltipValue != null) {
      _drawTooltip(canvas, _pendingTooltipPos!, _pendingTooltipValue!, chartArea);
    }
  }

  /// Determines if the chart is in horizontal orientation
  bool _isHorizontalOrientation() {
    final normalizedRotation = style.rotation % 360;
    // Consider horizontal if rotation is around 90° or 270°
    return (normalizedRotation >= 45 && normalizedRotation < 135) ||
        (normalizedRotation >= 225 && normalizedRotation < 315);
  }

  /// Determines if the chart is inverted (180° or 270°)
  bool _isInverted() {
    final normalizedRotation = style.rotation % 360;
    return normalizedRotation >= 135 && normalizedRotation < 315;
  }

  /// Draws the grid lines on the chart.
  void _drawGrid(Canvas canvas, Rect chartArea, bool isHorizontal) {
    final paint = Paint()
      ..color = style.gridColor.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    if (isHorizontal) {
      // Vertical grid lines for horizontal bars
      for (int i = 0; i <= horizontalGridLines; i++) {
        final x = chartArea.left + (chartArea.width / horizontalGridLines) * i;
        canvas.drawLine(
          Offset(x, chartArea.top),
          Offset(x, chartArea.bottom),
          paint,
        );
      }
    } else {
      // Horizontal grid lines for vertical bars (default)
      for (int i = 0; i <= horizontalGridLines; i++) {
        final y = chartArea.top + (chartArea.height / horizontalGridLines) * i;
        canvas.drawLine(
          Offset(chartArea.left, y),
          Offset(chartArea.right, y),
          paint,
        );
      }
    }
  }

  /// Draws the bars on the chart.
  void _drawBars(Canvas canvas, Rect chartArea, bool isHorizontal) {
    final range = _resolveValueRange();

    if (style.groupByLabel) {
      // If grouping is enabled, use grouped drawing logic
      if (isHorizontal) {
        _drawGroupedHorizontalBars(canvas, chartArea, range);
      } else {
        _drawGroupedVerticalBars(canvas, chartArea, range);
      }
    } else {
      // Original drawing logic
      if (isHorizontal) {
        _drawHorizontalBars(canvas, chartArea, range);
      } else {
        _drawVerticalBars(canvas, chartArea, range);
      }
    }
  }

  _ValueRange _resolveValueRange() {
    final minValue = data.map((point) => point.value).reduce(min);
    final maxValue = data.map((point) => point.value).reduce(max);

    double lower = min(minValue, 0.0);
    double upper = max(maxValue, 0.0);

    if (lower == upper) {
      if (upper == 0.0) {
        upper = 1.0;
      } else if (upper > 0) {
        lower = 0.0;
      } else {
        upper = 0.0;
      }
    }

    final span = upper - lower;
    return _ValueRange(lower: lower, upper: upper, span: span <= 0 ? 1.0 : span);
  }

  double _valueToVerticalY(
    double value,
    Rect chartArea,
    _ValueRange range,
    bool isInverted,
  ) {
    final normalized = (value - range.lower) / range.span;
    if (isInverted) {
      return chartArea.top + (normalized * chartArea.height);
    }
    return chartArea.bottom - (normalized * chartArea.height);
  }

  double _valueToHorizontalX(
    double value,
    Rect chartArea,
    _ValueRange range,
    bool isReversed,
  ) {
    final normalized = (value - range.lower) / range.span;
    if (isReversed) {
      return chartArea.right - (normalized * chartArea.width);
    }
    return chartArea.left + (normalized * chartArea.width);
  }

  double _sanitizeSpacing(double spacing) {
    return spacing.clamp(0.0, 0.95).toDouble();
  }

  double _groupInnerGapRatio() {
    if (style.barSpacing <= 0) return 0.0;
    return (style.barSpacing * 0.5).clamp(0.0, 0.25).toDouble();
  }

  /// Groups data by label, returning a list of label groups with their bars.
  List<MapEntry<String, List<int>>> _groupDataByLabel() {
    final grouped = <String, List<int>>{};
    for (int i = 0; i < data.length; i++) {
      final label = data[i].label;
      grouped.putIfAbsent(label, () => []).add(i);
    }
    return grouped.entries.toList();
  }

  /// Draws vertical bars grouped by label (when groupByLabel is enabled)
  void _drawGroupedVerticalBars(
    Canvas canvas,
    Rect chartArea,
    _ValueRange range,
  ) {
    final groups = _groupDataByLabel();
    if (groups.isEmpty) return;
    final isInverted = _isInverted();
    final zeroY = _valueToVerticalY(0, chartArea, range, isInverted);

    // Space allocated for each label group
    final spacingRatio = _sanitizeSpacing(style.barSpacing);
    final groupUnitWidth = chartArea.width / groups.length;
    final groupWidth = groupUnitWidth * (1 - spacingRatio);
    final groupSpacing = groupUnitWidth * spacingRatio;

    // Width of each individual bar within a group
    final barsPerGroup = max(
      1,
      groups.fold<int>(0, (prev, group) => group.value.length > prev ? group.value.length : prev),
    );
    final slotWidth = groupWidth / barsPerGroup;
    final innerGap = barsPerGroup > 1 ? slotWidth * _groupInnerGapRatio() : 0.0;
    final barWidth = max(0.0, slotWidth - innerGap);

    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      final groupX =
          chartArea.left + (g * (groupWidth + groupSpacing)) + (groupSpacing / 2);

      // Draw bars for each series in this label group
      for (int b = 0; b < group.value.length; b++) {
        final dataIndex = group.value[b];
        final barX = groupX + (b * slotWidth) + (innerGap / 2);

        final valueY =
            _valueToVerticalY(data[dataIndex].value, chartArea, range, isInverted);
        final fullHeight = (valueY - zeroY).abs();
        final barHeight = fullHeight * progress;
        final barTop = valueY < zeroY ? zeroY - barHeight : zeroY;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barTop, barWidth, barHeight),
          Radius.circular(style.cornerRadius),
        );

        final paint = Paint()..style = PaintingStyle.fill;

        // Apply colors and gradients
        _applyBarStyle(
          paint,
          rect,
          dataIndex,
          isInverted ? Alignment.topCenter : Alignment.bottomCenter,
          isInverted ? Alignment.bottomCenter : Alignment.topCenter,
        );

        if (_isRectHovered(rect.outerRect)) {
          _applyHoverEffect(
            canvas,
            rect,
            paint,
            dataIndex,
            isInverted ? Alignment.topCenter : Alignment.bottomCenter,
            isInverted ? Alignment.bottomCenter : Alignment.topCenter,
          );
          if (showTooltip && hoverPosition != null) {
            _pendingTooltipPos = hoverPosition;
            _pendingTooltipValue = data[dataIndex].value;
          }
        }

        canvas.drawRRect(rect, paint);

        // Draw value labels
        if (showValues) {
          final isUpward = valueY < zeroY;
          _drawValueLabel(
            canvas,
            data[dataIndex].value,
            Offset(
              barX + barWidth / 2,
              isUpward ? (barTop - 4) : (barTop + barHeight + 4),
            ),
            data[dataIndex].color ?? style.barColor,
            isAbove: isUpward,
          );
        }
      }
    }
  }

  /// Draws horizontal bars grouped by label (when groupByLabel is enabled)
  void _drawGroupedHorizontalBars(
    Canvas canvas,
    Rect chartArea,
    _ValueRange range,
  ) {
    final groups = _groupDataByLabel();
    if (groups.isEmpty) return;
    final isReversed = style.rotation >= 225 && style.rotation < 315; // 270° mode
    final zeroX = _valueToHorizontalX(0, chartArea, range, isReversed);

    // Space allocated for each label group
    final spacingRatio = _sanitizeSpacing(style.barSpacing);
    final groupUnitHeight = chartArea.height / groups.length;
    final groupHeight = groupUnitHeight * (1 - spacingRatio);
    final groupSpacing = groupUnitHeight * spacingRatio;

    // Height of each individual bar within a group
    final barsPerGroup = max(
      1,
      groups.fold<int>(0, (prev, group) => group.value.length > prev ? group.value.length : prev),
    );
    final slotHeight = groupHeight / barsPerGroup;
    final innerGap = barsPerGroup > 1 ? slotHeight * _groupInnerGapRatio() : 0.0;
    final barHeight = max(0.0, slotHeight - innerGap);

    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      final groupY =
          chartArea.top + (g * (groupHeight + groupSpacing)) + (groupSpacing / 2);

      // Draw bars for each series in this label group
      for (int b = 0; b < group.value.length; b++) {
        final dataIndex = group.value[b];
        final barY = groupY + (b * slotHeight) + (innerGap / 2);
        final valueX =
            _valueToHorizontalX(data[dataIndex].value, chartArea, range, isReversed);
        final fullWidth = (valueX - zeroX).abs();
        final barWidth = fullWidth * progress;
        final barLeft = valueX < zeroX ? zeroX - barWidth : zeroX;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barLeft, barY, barWidth, barHeight),
          Radius.circular(style.cornerRadius),
        );

        final paint = Paint()..style = PaintingStyle.fill;

        // Apply colors and gradients
        _applyBarStyle(
          paint,
          rect,
          dataIndex,
          isReversed ? Alignment.centerRight : Alignment.centerLeft,
          isReversed ? Alignment.centerLeft : Alignment.centerRight,
        );

        if (_isRectHovered(rect.outerRect)) {
          _applyHoverEffect(
            canvas,
            rect,
            paint,
            dataIndex,
            isReversed ? Alignment.centerRight : Alignment.centerLeft,
            isReversed ? Alignment.centerLeft : Alignment.centerRight,
          );
          if (showTooltip && hoverPosition != null) {
            _pendingTooltipPos = hoverPosition;
            _pendingTooltipValue = data[dataIndex].value;
          }
        }

        canvas.drawRRect(rect, paint);

        // Draw value labels
        if (showValues) {
          final isToRight = valueX > zeroX;
          _drawValueLabel(
            canvas,
            data[dataIndex].value,
            Offset(
              isToRight ? barLeft + barWidth + 4 : barLeft - 4,
              barY + barHeight / 2,
            ),
            data[dataIndex].color ?? style.barColor,
            isAbove: false,
            isLeftAligned: !isToRight,
          );
        }
      }
    }
  }

  void _drawVerticalBars(Canvas canvas, Rect chartArea, _ValueRange range) {
    final spacingRatio = _sanitizeSpacing(style.barSpacing);
    final unitWidth = chartArea.width / data.length;
    final barWidth = unitWidth * (1 - spacingRatio);
    final spacing = unitWidth * spacingRatio;
    final isInverted = _isInverted();
    final zeroY = _valueToVerticalY(0, chartArea, range, isInverted);

    for (int i = 0; i < data.length; i++) {
      final barX = chartArea.left + (i * (barWidth + spacing)) + (spacing / 2);
      final valueY = _valueToVerticalY(data[i].value, chartArea, range, isInverted);
      final fullHeight = (valueY - zeroY).abs();
      final barHeight = fullHeight * progress;
      final barTop = valueY < zeroY ? zeroY - barHeight : zeroY;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barTop, barWidth, barHeight),
        Radius.circular(style.cornerRadius),
      );

      final paint = Paint()..style = PaintingStyle.fill;

      // Apply colors and gradients
      _applyBarStyle(
        paint,
        rect,
        i,
        isInverted ? Alignment.topCenter : Alignment.bottomCenter,
        isInverted ? Alignment.bottomCenter : Alignment.topCenter,
      );

      if (_isRectHovered(rect.outerRect)) {
        _applyHoverEffect(
          canvas,
          rect,
          paint,
          i,
          isInverted ? Alignment.topCenter : Alignment.bottomCenter,
          isInverted ? Alignment.bottomCenter : Alignment.topCenter,
        );
        if (showTooltip && hoverPosition != null) {
          _pendingTooltipPos = hoverPosition;
          _pendingTooltipValue = data[i].value;
        }
      }

      canvas.drawRRect(rect, paint);

      // Draw value labels (always horizontal)
      if (showValues) {
        final isUpward = valueY < zeroY;
        _drawValueLabel(
          canvas,
          data[i].value,
          Offset(
            barX + barWidth / 2,
            isUpward ? (barTop - 4) : (barTop + barHeight + 4),
          ),
          data[i].color ?? style.barColor,
          isAbove: isUpward,
        );
      }
    }
  }

  /// Draws horizontal bars (90° or 270°)
  void _drawHorizontalBars(Canvas canvas, Rect chartArea, _ValueRange range) {
    final spacingRatio = _sanitizeSpacing(style.barSpacing);
    final unitHeight = chartArea.height / data.length;
    final barHeight = unitHeight * (1 - spacingRatio);
    final spacing = unitHeight * spacingRatio;
    final isReversed =
        style.rotation >= 225 && style.rotation < 315; // 270° mode
    final zeroX = _valueToHorizontalX(0, chartArea, range, isReversed);

    for (int i = 0; i < data.length; i++) {
      final barY = chartArea.top + (i * (barHeight + spacing)) + (spacing / 2);
      final valueX = _valueToHorizontalX(data[i].value, chartArea, range, isReversed);
      final fullWidth = (valueX - zeroX).abs();
      final barWidth = fullWidth * progress;
      final barLeft = valueX < zeroX ? zeroX - barWidth : zeroX;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barY, barWidth, barHeight),
        Radius.circular(style.cornerRadius),
      );

      final paint = Paint()..style = PaintingStyle.fill;

      // Apply colors and gradients
      _applyBarStyle(
        paint,
        rect,
        i,
        isReversed ? Alignment.centerRight : Alignment.centerLeft,
        isReversed ? Alignment.centerLeft : Alignment.centerRight,
      );

      if (_isRectHovered(rect.outerRect)) {
        _applyHoverEffect(
          canvas,
          rect,
          paint,
          i,
          isReversed ? Alignment.centerRight : Alignment.centerLeft,
          isReversed ? Alignment.centerLeft : Alignment.centerRight,
        );
        if (showTooltip && hoverPosition != null) {
          _pendingTooltipPos = hoverPosition;
          _pendingTooltipValue = data[i].value;
        }
      }

      canvas.drawRRect(rect, paint);

      // Draw value labels (always horizontal)
      if (showValues) {
        final isToRight = valueX > zeroX;
        _drawValueLabel(
          canvas,
          data[i].value,
          Offset(
            isToRight ? barLeft + barWidth + 4 : barLeft - 4,
            barY + barHeight / 2,
          ),
          data[i].color ?? style.barColor,
          isAbove: false,
          isLeftAligned: !isToRight,
        );
      }
    }
  }

  /// Applies bar styling (color or gradient)
  void _applyBarStyle(
    Paint paint,
    RRect rect,
    int index,
    Alignment gradientBegin,
    Alignment gradientEnd,
  ) {
    if (data[index].color != null) {
      paint.color = data[index].color!;
    } else if (style.gradientEffect && style.gradientColors != null) {
      paint.shader = LinearGradient(
        begin: gradientBegin,
        end: gradientEnd,
        colors: style.gradientColors!,
      ).createShader(rect.outerRect);
    } else {
      paint.color = style.barColor;
    }
  }

  /// Applies hover effect to a bar
  void _applyHoverEffect(
    Canvas canvas,
    RRect rect,
    Paint paint,
    int index,
    Alignment gradientBegin,
    Alignment gradientEnd,
  ) {
    if (paint.shader != null) {
      paint.shader = LinearGradient(
        begin: gradientBegin,
        end: gradientEnd,
        colors:
            style.gradientColors!.map((c) => c.withValues(alpha: 0.8)).toList(),
      ).createShader(rect.outerRect);
    } else {
      paint.color = paint.color.withValues(alpha: 0.8);
    }

    // Draw hover indicator
    final hoverPaint = Paint()
      ..color = (data[index].color ?? style.barColor).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rect, hoverPaint);
  }

  /// Draws a value label (always horizontal and readable)
  void _drawValueLabel(
    Canvas canvas,
    double value,
    Offset position,
    Color color, {
    bool isAbove = true,
    bool isLeftAligned = false,
  }) {
    final valueText = value.toStringAsFixed(1);
    final textStyle = style.valueStyle ??
        TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold);
    final textSpan = TextSpan(text: valueText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    Offset textPosition;
    if (isAbove) {
      // Center horizontally, position above or below
      textPosition = Offset(
        position.dx - textPainter.width / 2,
        position.dy - (isAbove ? textPainter.height : 0),
      );
    } else {
      // Position to left or right, center vertically
      textPosition = Offset(
        isLeftAligned ? position.dx - textPainter.width : position.dx,
        position.dy - textPainter.height / 2,
      );
    }

    textPainter.paint(canvas, textPosition);
  }

  /// Draws the labels for each bar on the chart (always horizontal and readable)
  void _drawLabels(Canvas canvas, Rect chartArea, bool isHorizontal) {
    final textStyle =
        style.labelStyle ?? TextStyle(color: style.barColor, fontSize: 12);

    if (style.groupByLabel) {
      // Use grouped label drawing
      if (isHorizontal) {
        _drawGroupedHorizontalLabels(canvas, chartArea, textStyle);
      } else {
        _drawGroupedVerticalLabels(canvas, chartArea, textStyle);
      }
    } else {
      // Original label drawing logic
      if (isHorizontal) {
        _drawHorizontalLabels(canvas, chartArea, textStyle);
      } else {
        _drawVerticalLabels(canvas, chartArea, textStyle);
      }
    }
  }

  /// Draws labels for grouped vertical bars
  void _drawGroupedVerticalLabels(Canvas canvas, Rect chartArea, TextStyle textStyle) {
    final groups = _groupDataByLabel();
    if (groups.isEmpty) return;
    final isInverted = _isInverted();

    final spacingRatio = _sanitizeSpacing(style.barSpacing);
    final groupUnitWidth = chartArea.width / groups.length;
    final groupWidth = groupUnitWidth * (1 - spacingRatio);
    final groupSpacing = groupUnitWidth * spacingRatio;

    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      final groupX = chartArea.left + (g * (groupWidth + groupSpacing)) + (groupSpacing / 2);
      final textSpan = TextSpan(text: group.key, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final yPosition = isInverted
          ? chartArea.top - textPainter.height - 8
          : chartArea.bottom + padding.bottom / 2 - textPainter.height / 2;

      textPainter.paint(
        canvas,
        Offset(groupX + (groupWidth - textPainter.width) / 2, yPosition),
      );
    }
  }

  /// Draws labels for grouped horizontal bars
  void _drawGroupedHorizontalLabels(Canvas canvas, Rect chartArea, TextStyle textStyle) {
    final groups = _groupDataByLabel();
    if (groups.isEmpty) return;
    final isReversed = style.rotation >= 225 && style.rotation < 315;

    final spacingRatio = _sanitizeSpacing(style.barSpacing);
    final groupUnitHeight = chartArea.height / groups.length;
    final groupHeight = groupUnitHeight * (1 - spacingRatio);
    final groupSpacing = groupUnitHeight * spacingRatio;

    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      final groupY = chartArea.top + (g * (groupHeight + groupSpacing)) + (groupSpacing / 2);
      final textSpan = TextSpan(text: group.key, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final xPosition = isReversed
          ? chartArea.right + padding.right / 4
          : chartArea.left - textPainter.width - padding.left / 4;

      textPainter.paint(
        canvas,
        Offset(xPosition, groupY + (groupHeight - textPainter.height) / 2),
      );
    }
  }

  /// Draws labels for vertical bars
  void _drawVerticalLabels(Canvas canvas, Rect chartArea, TextStyle textStyle) {
    final spacingRatio = _sanitizeSpacing(style.barSpacing);
    final unitWidth = chartArea.width / data.length;
    final barWidth = unitWidth * (1 - spacingRatio);
    final spacing = unitWidth * spacingRatio;
    final isInverted = _isInverted();

    for (int i = 0; i < data.length; i++) {
      final x = chartArea.left + (i * (barWidth + spacing)) + (spacing / 2);
      final textSpan = TextSpan(text: data[i].label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final yPosition = isInverted
          ? chartArea.top - textPainter.height - 8
          : chartArea.bottom + padding.bottom / 2 - textPainter.height / 2;

      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, yPosition),
      );
    }
  }

  /// Draws labels for horizontal bars
  void _drawHorizontalLabels(
    Canvas canvas,
    Rect chartArea,
    TextStyle textStyle,
  ) {
    final spacingRatio = _sanitizeSpacing(style.barSpacing);
    final unitHeight = chartArea.height / data.length;
    final barHeight = unitHeight * (1 - spacingRatio);
    final spacing = unitHeight * spacingRatio;
    final isReversed = style.rotation >= 225 && style.rotation < 315;

    for (int i = 0; i < data.length; i++) {
      final y = chartArea.top + (i * (barHeight + spacing)) + (spacing / 2);
      final textSpan = TextSpan(text: data[i].label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final xPosition = isReversed
          ? chartArea.right + padding.right / 4
          : chartArea.left - textPainter.width - padding.left / 4;

      textPainter.paint(
        canvas,
        Offset(xPosition, y + (barHeight - textPainter.height) / 2),
      );
    }
  }

  bool _isRectHovered(Rect rect) {
    if (hoverPosition == null) return false;
    return rect.contains(hoverPosition!);
  }

  @override
  bool shouldRepaint(BarChartPainter oldDelegate) {
    // Determines whether the painter should repaint when properties change
    return oldDelegate.progress != progress ||
        oldDelegate.data != data ||
        oldDelegate.style != style ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.showTooltip != showTooltip ||
        oldDelegate.tooltipBackgroundColor != tooltipBackgroundColor ||
        oldDelegate.tooltipTextStyle != tooltipTextStyle ||
        oldDelegate.tooltipPadding != tooltipPadding ||
        oldDelegate.tooltipRadius != tooltipRadius ||
        oldDelegate.horizontalGridLines != horizontalGridLines;
  }
}

/// Draw a small tooltip near the hover position showing the bar value.
extension on BarChartPainter {
  void _drawTooltip(Canvas canvas, Offset pos, double value, Rect bounds) {
    final text = value.toStringAsFixed(1);
    final effectiveTextStyle = tooltipTextStyle ?? TextStyle(color: Colors.white, fontSize: 12);
    final textSpan = TextSpan(text: text, style: effectiveTextStyle);
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

    final padding = tooltipPadding;
    final bgWidth = tp.width + padding * 2;
    final bgHeight = tp.height + padding * 2;

    double x = pos.dx + 10;
    double y = pos.dy - bgHeight - 10;

    if (x + bgWidth > bounds.right) x = bounds.right - bgWidth - 4;
    if (x < bounds.left) x = bounds.left + 4;
    if (y < bounds.top) y = pos.dy + 10;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, bgWidth, bgHeight),
      Radius.circular(tooltipRadius),
    );

    final paint = Paint()..color = (tooltipBackgroundColor ?? Colors.black).withOpacity(0.75);
    canvas.drawRRect(rect, paint);

    tp.paint(canvas, Offset(x + padding, y + padding));
  }
}

class _ValueRange {
  final double lower;
  final double upper;
  final double span;

  const _ValueRange({
    required this.lower,
    required this.upper,
    required this.span,
  });
}
