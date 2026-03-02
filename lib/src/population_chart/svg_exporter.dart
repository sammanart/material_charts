import 'package:flutter/material.dart';

import 'models.dart';

/// Options for controlling SVG-specific export settings
class PopulationPyramidSvgOptions {
  final String? title;
  final double titleFontSize;

  const PopulationPyramidSvgOptions({
    this.title,
    this.titleFontSize = 18.0,
  });
}

/// SVG exporter for Population Pyramids
class PopulationPyramidSvgExporter {
  /// Exports a population pyramid to SVG format
  static String exportSvg({
    required List<PopulationPyramidData> data,
    required PopulationPyramidStyle style,
    required double width,
    required double height,
    required EdgeInsets padding,
    required PopulationPyramidSvgOptions options,
  }) {
    if (data.isEmpty) return '<svg></svg>';

    final sb = StringBuffer();

    // SVG header
    sb.writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height">');
    
    // Background - only render if not fully transparent
    if (style.backgroundColor.opacity > 0) {
      final opacity = style.backgroundColor.opacity;
      if (opacity < 1.0) {
        sb.writeln(
            '<rect width="$width" height="$height" fill="${_colorToHex(style.backgroundColor)}" fill-opacity="$opacity"/>');
      } else {
        sb.writeln(
            '<rect width="$width" height="$height" fill="${_colorToHex(style.backgroundColor)}"/>');
      }
    }

    // Title
    if (options.title != null && options.title!.isNotEmpty) {
      final titleY = padding.top + 15;
      sb.writeln(
          '<text x="${width / 2}" y="$titleY" text-anchor="middle" font-size="${options.titleFontSize}" font-weight="bold">${options.title}</text>');
    }

    // Calculate dimensions
    final availableHeight = height - padding.vertical - 40;
    final availableWidth = width - padding.horizontal;
    final barHeight = availableHeight / (data.length + 1);
    final centerX = width / 2;

    // Calculate total population for percentage calculations
    final totalPopulation = data.fold<double>(
      0,
      (prev, item) => prev + item.leftPopulation + item.rightPopulation,
    );

    // Find max population
    final maxPopulation = data.fold<double>(
      0,
      (prev, item) =>
          prev > (item.leftPopulation + item.rightPopulation)
              ? prev
              : item.leftPopulation + item.rightPopulation,
    );

    final chartStartY = padding.top + (options.title != null ? 40 : 20);

    // Draw grid lines if enabled
    if (style.showGridLines) {
      _drawGridLines(sb, width, height, padding, data.length, centerX, style);
    }

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      final dataPoint = data[i];
      final y = chartStartY + (i + 0.5) * barHeight;

      final halfGap = style.centerGap / 2;
      final maxBarWidth = (availableWidth / 2) - halfGap - style.barHorizontalMargin;
      
      final leftWidth = (dataPoint.leftPopulation / maxPopulation) * maxBarWidth;
      final rightWidth = (dataPoint.rightPopulation / maxPopulation) * maxBarWidth;

      final leftColor = _colorToHex(
          dataPoint.leftColor ?? style.leftColor);
      final rightColor = _colorToHex(
          dataPoint.rightColor ?? style.rightColor);

      // Left group bar (left)
      sb.writeln(
          '<rect x="${centerX - leftWidth - halfGap}" y="${y - barHeight * 0.35}" width="$leftWidth" height="${barHeight * 0.7}" fill="$leftColor" rx="2" ry="2"/>');

      // Right group bar (right)
      sb.writeln(
          '<rect x="${centerX + halfGap}" y="${y - barHeight * 0.35}" width="$rightWidth" height="${barHeight * 0.7}" fill="$rightColor" rx="2" ry="2"/>');

      // Age label (always shown, controlled by data having ageGroup)
      sb.writeln(
          '<text x="$centerX" y="$y" text-anchor="middle" dominant-baseline="middle" font-size="${style.labelFontSize}" font-weight="${_fontWeightToString(style.labelFontWeight)}" fill="${_colorToHex(style.labelColor)}">${dataPoint.ageGroup}</text>');

      // Values
      if (style.showValues) {
        final leftValue = _formatNumber(dataPoint.leftPopulation, totalPopulation, style.showPercentage);
        final rightValue = _formatNumber(dataPoint.rightPopulation, totalPopulation, style.showPercentage);

        sb.writeln(
            '<text x="${centerX - leftWidth - halfGap - style.barValueGap}" y="$y" text-anchor="end" dominant-baseline="middle" font-size="${style.valueFontSize}" font-weight="${_fontWeightToString(style.valueFontWeight)}" fill="${_colorToHex(style.valueColor)}">$leftValue</text>');

        sb.writeln(
            '<text x="${centerX + rightWidth + halfGap + style.barValueGap}" y="$y" text-anchor="start" dominant-baseline="middle" font-size="${style.valueFontSize}" font-weight="${_fontWeightToString(style.valueFontWeight)}" fill="${_colorToHex(style.valueColor)}">$rightValue</text>');
      }
    }

    // Legend
    if (style.showLegend) {
      final legendY = height - padding.bottom + style.legendMargin;
      double legendX = 0;
      
      // Calculate legend position
      switch (style.legendPosition) {
        case PyramidLegendPosition.topCenter:
        case PyramidLegendPosition.bottomCenter:
          legendX = centerX - (style.legendItemSpacing + 
              (style.showLegendSquares ? style.legendSquareSize * 2 + 12 : 0)) / 2;
          break;
        case PyramidLegendPosition.topLeft:
        case PyramidLegendPosition.bottomLeft:
          legendX = padding.left + style.legendMargin;
          break;
        case PyramidLegendPosition.topRight:
        case PyramidLegendPosition.bottomRight:
          legendX = width - padding.right - style.legendMargin - 100; // Approximate width
          break;
      }

      final leftLegendColor = _colorToHex(style.legendLeftColor ?? style.leftColor);
      final rightLegendColor = _colorToHex(style.legendRightColor ?? style.rightColor);
      
      double currentX = legendX;
      
      // Left group legend
      if (style.showLegendSquares) {
        sb.writeln(
            '<rect x="$currentX" y="$legendY" width="${style.legendSquareSize}" height="${style.legendSquareSize}" fill="$leftLegendColor"/>');
        currentX += style.legendSquareSize + 6;
      }
      
      final legendFontSize = style.legendTextStyle?.fontSize ?? style.labelFontSize;
      final legendFontWeight = _fontWeightToString(
          style.legendTextStyle?.fontWeight ?? style.labelFontWeight);
          
      sb.writeln(
          '<text x="$currentX" y="${legendY + style.legendSquareSize / 2}" dominant-baseline="middle" font-size="$legendFontSize" font-weight="$legendFontWeight">${style.legendLeftLabel}</text>');

      currentX += 40 + style.legendItemSpacing; // Approximate text width + spacing

      // Right group legend
      if (style.showLegendSquares) {
        sb.writeln(
            '<rect x="$currentX" y="$legendY" width="${style.legendSquareSize}" height="${style.legendSquareSize}" fill="$rightLegendColor"/>');
        currentX += style.legendSquareSize + 6;
      }
      
      sb.writeln(
          '<text x="$currentX" y="${legendY + style.legendSquareSize / 2}" dominant-baseline="middle" font-size="$legendFontSize" font-weight="$legendFontWeight">${style.legendRightLabel}</text>');
    }

    sb.writeln('</svg>');
    return sb.toString();
  }

  static void _drawGridLines(
    StringBuffer sb,
    double width,
    double height,
    EdgeInsets padding,
    int dataCount,
    double centerX,
    PopulationPyramidStyle style,
  ) {
    final gridColor = _colorToHex(style.gridLineColor);
    final gridWidth = style.gridLineWidth;

    final chartStartY = padding.top + 20;

    // Vertical grid lines
    if (style.verticalGridLines > 0) {
      final step = (width - padding.horizontal) / (style.verticalGridLines + 1);
      for (int i = 1; i <= style.verticalGridLines; i++) {
        final x = padding.left + i * step;
        sb.writeln(
            '<line x1="$x" y1="${padding.top}" x2="$x" y2="${height - padding.bottom}" stroke="$gridColor" stroke-width="$gridWidth"/>');
      }
    }

    // Horizontal grid lines
    final availableHeight = height - padding.vertical - 40;
    final lineCount = style.horizontalGridLines > 0 ? style.horizontalGridLines : dataCount;
    final barHeight = availableHeight / (lineCount + 1);

    for (int i = 1; i <= lineCount; i++) {
      final y = chartStartY + i * barHeight;
      sb.writeln(
          '<line x1="${padding.left}" y1="$y" x2="${width - padding.right}" y2="$y" stroke="$gridColor" stroke-width="$gridWidth"/>');
    }
  }

  static String _formatNumber(double value, double total, bool showPercentage) {
    if (showPercentage) {
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

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static String _fontWeightToString(FontWeight fontWeight) {
    if (fontWeight == FontWeight.w100) return '100';
    if (fontWeight == FontWeight.w200) return '200';
    if (fontWeight == FontWeight.w300) return '300';
    if (fontWeight == FontWeight.w400) return '400';
    if (fontWeight == FontWeight.w500) return '500';
    if (fontWeight == FontWeight.w600) return '600';
    if (fontWeight == FontWeight.w700 || fontWeight == FontWeight.bold) return '700';
    if (fontWeight == FontWeight.w800) return '800';
    if (fontWeight == FontWeight.w900) return '900';
    return '400'; // Default to normal
  }
}
