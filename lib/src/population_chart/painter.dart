import 'package:flutter/material.dart';

import 'models.dart';

/// Custom painter class for rendering a population pyramid.
class PopulationPyramidPainter extends CustomPainter {
  /// List of data points for the population pyramid.
  final List<PopulationPyramidData> data;

  /// Progress value for animation, ranging from 0.0 to 1.0.
  final double progress;

  /// Style properties for customizing the pyramid appearance.
  final PopulationPyramidStyle style;

  /// Padding around the pyramid.
  final EdgeInsets padding;

  /// Constructor for [PopulationPyramidPainter].
  PopulationPyramidPainter({
    required this.data,
    required this.progress,
    required this.style,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = style.backgroundColor,
    );

    // Calculate total population for percentage calculations
    final totalPopulation = data.fold<double>(
      0,
      (prev, item) => prev + item.leftPopulation + item.rightPopulation,
    );

    // Calculate effective top padding based on legend position
    var effectiveTopPadding = padding.top;
    var effectiveBottomPadding = padding.bottom;
    
    if (style.showLegend) {
      final legendSpaceNeeded = style.legendSquareSize + 
          (style.labelFontSize * 0.5) + 
          (style.legendMargin * 2);
          
      if (style.legendPosition == PyramidLegendPosition.topCenter || 
          style.legendPosition == PyramidLegendPosition.topLeft || 
          style.legendPosition == PyramidLegendPosition.topRight) {
        effectiveTopPadding = padding.top + legendSpaceNeeded;
      } else {
        effectiveBottomPadding = padding.bottom + legendSpaceNeeded;
      }
    }

    // Calculate available space
    final availableHeight = size.height - effectiveTopPadding - effectiveBottomPadding;
    final availableWidth = size.width - padding.horizontal;

    final barHeight = availableHeight / (data.length + 1);
    final centerX = size.width / 2;
    final maxPopulation = data.fold<double>(
      0,
      (prev, item) =>
          prev > (item.leftPopulation + item.rightPopulation)
              ? prev
              : item.leftPopulation + item.rightPopulation,
    );

    // Draw grid lines if enabled
    if (style.showGridLines) {
      _drawGridLines(canvas, size, centerX, effectiveTopPadding, effectiveBottomPadding);
    }

    // Draw each age group's bars
    for (int i = 0; i < data.length; i++) {
      final dataPoint = data[i];
      final y = effectiveTopPadding + (i + 0.5) * barHeight;

      // Calculate bar widths (using centerGap for spacing)
      final halfGap = style.centerGap / 2;
      final maxBarWidth = (availableWidth / 2) - halfGap - style.barHorizontalMargin;
      final leftWidth = (dataPoint.leftPopulation / maxPopulation) *
          maxBarWidth *
          progress;
      final rightWidth = (dataPoint.rightPopulation / maxPopulation) *
          maxBarWidth *
          progress;

      // Draw left group bar (left side)
      final leftRect = Rect.fromLTWH(
        centerX - leftWidth - halfGap,
        y - barHeight * 0.35,
        leftWidth,
        barHeight * 0.7,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(leftRect, const Radius.circular(2)),
        Paint()
          ..color = (dataPoint.leftColor ?? style.leftColor).withAlpha(220),
      );

      // Draw right group bar (right side)
      final rightRect = Rect.fromLTWH(
        centerX + halfGap,
        y - barHeight * 0.35,
        rightWidth,
        barHeight * 0.7,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rightRect, const Radius.circular(2)),
        Paint()
          ..color = (dataPoint.rightColor ?? style.rightColor).withAlpha(220),
      );

      // Draw age group label
      _drawLabel(
        canvas,
        dataPoint.ageGroup,
        Offset(centerX, y),
        TextAlign.center,
      );

      // Draw values if enabled
      if (style.showValues && progress == 1.0) {
        final halfGap = style.centerGap / 2;
        _drawValue(
          canvas,
          _formatNumber(dataPoint.leftPopulation, totalPopulation),
          Offset(centerX - leftWidth - halfGap - style.barValueGap, y),
          TextAlign.right,
        );

        _drawValue(
          canvas,
          _formatNumber(dataPoint.rightPopulation, totalPopulation),
          Offset(centerX + rightWidth + halfGap + style.barValueGap, y),
          TextAlign.left,
        );
      }
    }

    // Draw legend if enabled
    if (style.showLegend) {
      // Create adjusted padding for legend positioning that matches the effective padding
      EdgeInsets legendPadding = padding;
      if (style.legendPosition == PyramidLegendPosition.topCenter || 
          style.legendPosition == PyramidLegendPosition.topLeft || 
          style.legendPosition == PyramidLegendPosition.topRight) {
        legendPadding = padding.copyWith(top: effectiveTopPadding);
      } else {
        legendPadding = padding.copyWith(bottom: effectiveBottomPadding);
      }
      _drawLegend(canvas, size, legendPadding);
    }
  }

  void _drawGridLines(Canvas canvas, Size size, double centerX, double topPadding, double bottomPadding) {
    final gridPaint = Paint()
      ..color = style.gridLineColor
      ..strokeWidth = style.gridLineWidth;

    // Vertical grid lines
    if (style.verticalGridLines > 0) {
      final step = (size.width - padding.horizontal) / (style.verticalGridLines + 1);
      for (int i = 1; i <= style.verticalGridLines; i++) {
        final x = padding.left + i * step;
        canvas.drawLine(
          Offset(x, topPadding),
          Offset(x, size.height - bottomPadding),
          gridPaint,
        );
      }
    }

    // Horizontal grid lines
    final availableHeight = size.height - topPadding - bottomPadding;
    final lineCount = style.horizontalGridLines > 0 ? style.horizontalGridLines : data.length;
    final barHeight = availableHeight / (lineCount + 1);
    for (int i = 1; i <= lineCount; i++) {
      final y = topPadding + i * barHeight;
      canvas.drawLine(
        Offset(padding.left, y),
        Offset(size.width - padding.right, y),
        gridPaint,
      );
    }
  }

  void _drawLegend(Canvas canvas, Size size, EdgeInsets chartPadding) {
    final legendPos = _calculateLegendPosition(size, chartPadding);
    final leftLegendColor = style.legendLeftColor ?? style.leftColor;
    final rightLegendColor = style.legendRightColor ?? style.rightColor;

    // Get text style with defaults
    final textStyle = style.legendTextStyle ??
        TextStyle(
          color: style.labelColor,
          fontSize: style.labelFontSize,
          fontWeight: FontWeight.w500,
        );

    // Left group legend
    double currentX = legendPos.dx;
    
    if (style.showLegendSquares) {
      canvas.drawRect(
        Rect.fromLTWH(currentX, legendPos.dy, style.legendSquareSize, style.legendSquareSize),
        Paint()..color = leftLegendColor,
      );
      currentX += style.legendSquareSize + 6;
    }

    _drawLegendText(
      canvas,
      style.legendLeftLabel,
      Offset(currentX, legendPos.dy + style.legendSquareSize / 2),
      textStyle,
    );

    // Calculate width of left label for positioning right legend
    final leftLabelWidth = _measureText(style.legendLeftLabel, textStyle).width;
    currentX += leftLabelWidth + style.legendItemSpacing;

    // Right group legend
    if (style.showLegendSquares) {
      canvas.drawRect(
        Rect.fromLTWH(currentX, legendPos.dy, style.legendSquareSize, style.legendSquareSize),
        Paint()..color = rightLegendColor,
      );
      currentX += style.legendSquareSize + 6;
    }

    _drawLegendText(
      canvas,
      style.legendRightLabel,
      Offset(currentX, legendPos.dy + style.legendSquareSize / 2),
      textStyle,
    );
  }

  Offset _calculateLegendPosition(Size size, EdgeInsets chartPadding) {
    // If custom offset is provided, use it
    if (style.legendOffset != null) {
      return style.legendOffset!;
    }

    double x, y;
    final totalLegendWidth = _estimateLegendWidth();

    switch (style.legendPosition) {
      case PyramidLegendPosition.topCenter:
        x = (size.width - totalLegendWidth) / 2;
        y = chartPadding.top / 2 + 40 - style.legendGapFromChart;
        break;
      case PyramidLegendPosition.topLeft:
        x = chartPadding.left + style.legendMargin;
        y = chartPadding.top / 2 + 40 - style.legendGapFromChart;
        break;
      case PyramidLegendPosition.topRight:
        x = size.width - chartPadding.right - totalLegendWidth - style.legendMargin;
        y = chartPadding.top / 2 + 40 - style.legendGapFromChart;
        break;
      case PyramidLegendPosition.bottomCenter:
        x = (size.width - totalLegendWidth) / 2;
        y = size.height - (chartPadding.bottom / 2) - 40 + style.legendGapFromChart;
        break;
      case PyramidLegendPosition.bottomLeft:
        x = chartPadding.left + style.legendMargin;
        y = size.height - (chartPadding.bottom / 2) - 40 + style.legendGapFromChart;
        break;
      case PyramidLegendPosition.bottomRight:
        x = size.width - chartPadding.right - totalLegendWidth - style.legendMargin;
        y = size.height - (chartPadding.bottom / 2) - 40 + style.legendGapFromChart;
        break;
    }

    return Offset(x, y);
  }

  double _estimateLegendWidth() {
    final textStyle = style.legendTextStyle ??
        TextStyle(
          color: style.labelColor,
          fontSize: style.labelFontSize,
          fontWeight: FontWeight.w500,
        );

    double width = 0;
    
    if (style.showLegendSquares) {
      width += style.legendSquareSize * 2 + 12; // Two squares + spacing
    }

    width += _measureText(style.legendLeftLabel, textStyle).width;
    width += _measureText(style.legendRightLabel, textStyle).width;
    width += style.legendItemSpacing;

    return width;
  }

  Size _measureText(String text, TextStyle textStyle) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return Size(textPainter.width, textPainter.height);
  }

  void _drawLegendText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle textStyle,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    textPainter.layout();

    final textOffset = Offset(
      offset.dx,
      offset.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, textOffset);
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset,
    TextAlign textAlign,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: style.labelColor,
          fontSize: style.labelFontSize,
          fontWeight: style.labelFontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    );

    textPainter.layout();

    final textOffset = Offset(
      offset.dx - textPainter.width / 2,
      offset.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, textOffset);
  }

  void _drawValue(
    Canvas canvas,
    String text,
    Offset offset,
    TextAlign textAlign,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: style.valueColor,
          fontSize: style.valueFontSize,
          fontWeight: style.valueFontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    );

    textPainter.layout();

    final textOffset = Offset(
      offset.dx - textPainter.width / 2,
      offset.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, textOffset);
  }

  String _formatNumber(double value, double total) {
    if (style.showPercentage) {
      final percentage = (value / total * 100).toStringAsFixed(1);
      return '$percentage%';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(PopulationPyramidPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.data != data;
  }
}
