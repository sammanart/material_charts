import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

/// Options for controlling what elements to include in the SVG export
class StackedBarChartSvgOptions {
  final bool includeGrid;
  final bool showValues;
  final bool includeLabels;
  final bool includeYAxis;
  final String? title;
  final double maxBarWidth;
  final double labelVerticalOffset;
  final TextStyle? defaultValueStyle;
  final TextStyle? defaultLabelStyle;
  final TextStyle? defaultTitleStyle;
  
  const StackedBarChartSvgOptions({
    this.includeGrid = true,
    this.showValues = true,
    this.includeLabels = true,
    this.includeYAxis = true,
    this.title,
    this.maxBarWidth = 60.0,
    this.labelVerticalOffset = 16.0,
    this.defaultValueStyle,
    this.defaultLabelStyle,
    this.defaultTitleStyle,
  });
}

/// SVG exporter for Stacked Bar Charts
class StackedBarChartSvgExporter {
  /// Exports a stacked bar chart to SVG format
  static String exportSvg({
    required List<StackedBarData> data,
    required StackedBarChartStyle style,
    required double width,
    required double height,
    required EdgeInsets padding,
    required StackedBarChartSvgOptions options,
    int horizontalGridLines = 5,
  }) {
    if (data.isEmpty) return '<svg></svg>';
    
    final sb = StringBuffer();
    final body = StringBuffer();
    
    final yAxisConfig = style.yAxisConfig;
    final yAxisWidth = yAxisConfig != null && options.includeYAxis ? yAxisConfig.axisWidth : 0;
    
    // Calculate chart area
    final chartArea = Rect.fromLTWH(
      padding.left + yAxisWidth,
      padding.top,
      width - padding.horizontal - yAxisWidth,
      height - padding.vertical,
    );
    
    // Draw Y-axis
    if (options.includeYAxis && yAxisConfig != null) {
      body.writeln(_drawYAxis(chartArea, data, style, yAxisConfig));
    }
    
    // Draw grid
    if (options.includeGrid) {
      body.writeln(_drawGrid(chartArea, style, yAxisConfig, data, horizontalGridLines));
    }
    
    // Draw stacked bars
    body.writeln(_drawStackedBars(chartArea, data, style, options));
    
    // Draw labels
    if (options.includeLabels) {
      body.writeln(_drawLabels(chartArea, data, style, options, padding));
    }
    
    // Draw title
    if (options.title != null && options.title!.trim().isNotEmpty) {
      body.writeln(_drawTitle(chartArea, style, options, options.title!));
    }
    
    // Build SVG
    sb.writeln('<svg width="$width" height="$height" xmlns="http://www.w3.org/2000/svg">');
    sb.writeln(_rect(0, 0, width, height, fill: _colorToRgba(style.backgroundColor)));
    sb.writeln(body.toString());
    sb.writeln('</svg>');
    
    return sb.toString();
  }
  
  static String _drawYAxis(Rect area, List<StackedBarData> data, StackedBarChartStyle style, YAxisConfig config) {
    final items = <String>[];
    final maxDataValue = data.map((bar) => bar.totalValue).reduce(max);
    final minValue = config.minValue ?? 0;
    final maxValue = config.maxValue ?? maxDataValue;
    
    // Draw axis line
    if (config.showAxisLine) {
      items.add(_line(area.left, area.top, area.left, area.bottom, _colorToRgba(style.gridColor)));
    }
    
    // Draw labels and grid lines
    for (int i = 0; i <= config.divisions; i++) {
      final y = area.bottom - (i / config.divisions) * area.height;
      final value = minValue + (i / config.divisions) * (maxValue - minValue);
      final label = config.labelFormatter?.call(value) ?? value.toStringAsFixed(1);
      final textStyle = config.labelStyle ?? TextStyle(color: style.gridColor, fontSize: 12);
      
      items.add(_text(label, area.left - 8, y, textStyle, anchor: 'end', dominantBaseline: 'middle'));
      
      if (config.showGridLines && i > 0 && i < config.divisions) {
        items.add(_line(area.left, y, area.right, y, _colorToRgba(style.gridColor.withValues(alpha: 0.2))));
      }
    }
    
    return items.join('\n');
  }
  
  static String _drawGrid(Rect area, StackedBarChartStyle style, YAxisConfig? yAxisConfig, List<StackedBarData> data, int gridLines) {
    final items = <String>[];
    final color = _colorToRgba(style.gridColor.withValues(alpha: 0.2));
    
    // Only draw grid if Y-axis config doesn't already draw it
    if (yAxisConfig == null || !yAxisConfig.showGridLines) {
      for (int i = 0; i <= gridLines; i++) {
        final y = area.top + (area.height / gridLines) * i;
        items.add(_line(area.left, y, area.right, y, color));
      }
    }
    
    return items.join('\n');
  }
  
  static double _calculateBarHeight(double value, Rect area, List<StackedBarData> data, YAxisConfig? yAxisConfig) {
    final minValue = yAxisConfig?.minValue ?? 0;
    final maxValue = yAxisConfig?.maxValue ?? data.map((bar) => bar.totalValue).reduce(max);
    return (value / (maxValue - minValue)) * area.height;
  }
  
  static String _drawStackedBars(Rect area, List<StackedBarData> data, StackedBarChartStyle style, StackedBarChartSvgOptions options) {
    final items = <String>[];
    final calculatedBarWidth = (area.width / data.length) * (1 - style.barSpacing);
    final barWidth = calculatedBarWidth.clamp(0.0, options.maxBarWidth);
    final totalBarSpace = barWidth * data.length;
    final totalSpacing = area.width - totalBarSpace;
    final spacing = data.length > 1 ? totalSpacing / (data.length + 1) : 0;
    
    for (int i = 0; i < data.length; i++) {
      double currentHeight = 0;
      final barX = area.left + spacing + (i * (barWidth + spacing));
      
      for (var segment in data[i].segments) {
        final segmentHeight = _calculateBarHeight(segment.value, area, data, style.yAxisConfig);
        final segmentY = area.bottom - currentHeight - segmentHeight;
        
        items.add(_rect(barX, segmentY, barWidth, segmentHeight, 
          fill: _colorToRgba(segment.color), 
          rx: style.cornerRadius, 
          ry: style.cornerRadius));
        
        // Draw value label
        if (options.showValues && segmentHeight > 15) {
          final valueText = segment.value.toStringAsFixed(1);
          final textStyle = style.valueStyle ?? options.defaultValueStyle ?? const TextStyle(fontSize: 10, color: Colors.white);
          items.add(_text(valueText, barX + barWidth / 2, segmentY + segmentHeight / 2, textStyle, 
            anchor: 'middle', dominantBaseline: 'middle'));
        }
        
        currentHeight += segmentHeight;
      }
    }
    
    return items.join('\n');
  }
  
  static String _drawLabels(Rect area, List<StackedBarData> data, StackedBarChartStyle style, StackedBarChartSvgOptions options, EdgeInsets padding) {
    final items = <String>[];
    final calculatedBarWidth = (area.width / data.length) * (1 - style.barSpacing);
    final barWidth = calculatedBarWidth.clamp(0.0, options.maxBarWidth);
    final totalBarSpace = barWidth * data.length;
    final totalSpacing = area.width - totalBarSpace;
    final spacing = data.length > 1 ? totalSpacing / (data.length + 1) : 0;
    final textStyle = style.labelStyle ?? options.defaultLabelStyle ?? TextStyle(color: style.gridColor, fontSize: 12);
    
    for (int i = 0; i < data.length; i++) {
      final barX = area.left + spacing + (i * (barWidth + spacing));
      final x = barX + barWidth / 2;
      final y = area.bottom + options.labelVerticalOffset;
      items.add(_text(data[i].label, x, y, textStyle, anchor: 'middle', dominantBaseline: 'hanging'));
    }
    
    return items.join('\n');
  }
  
  static String _drawTitle(Rect area, StackedBarChartStyle style, StackedBarChartSvgOptions options, String title) {
    final textStyle = style.labelStyle ?? options.defaultTitleStyle ?? const TextStyle(fontSize: 14, color: Colors.black);
    final y = max(12.0, area.top - 18.0);
    return _text(title, area.left, y, textStyle.copyWith(fontWeight: FontWeight.bold), 
      anchor: 'start', dominantBaseline: 'hanging');
  }
  
  // SVG primitive helpers
  
  static String _rect(double x, double y, double w, double h, {String? fill, double rx = 0, double ry = 0}) {
    return '<rect x="$x" y="$y" width="$w" height="$h" fill="${fill ?? 'none'}" rx="$rx" ry="$ry"/>';
  }
  
  static String _line(double x1, double y1, double x2, double y2, String stroke, {double strokeWidth = 1}) {
    return '<line x1="$x1" y1="$y1" x2="$x2" y2="$y2" stroke="$stroke" stroke-width="$strokeWidth"/>';
  }
  
  static String _text(String content, double x, double y, TextStyle style, {String anchor = 'start', String dominantBaseline = 'auto'}) {
    final fill = _colorToRgba(style.color ?? Colors.black);
    final fontSize = style.fontSize ?? 12;
    final fontWeight = style.fontWeight == FontWeight.bold ? 'bold' : 'normal';
    return '<text x="$x" y="$y" fill="$fill" font-size="$fontSize" font-weight="$fontWeight" text-anchor="$anchor" dominant-baseline="$dominantBaseline">$content</text>';
  }
  
  static String _colorToRgba(Color color) {
    return 'rgba(${color.red},${color.green},${color.blue},${color.alpha / 255.0})';
  }
}
