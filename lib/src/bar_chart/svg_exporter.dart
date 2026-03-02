import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

/// Options for controlling what elements to include in the SVG export
class BarChartSvgOptions {
  final bool includeGrid;
  final bool includeValues;
  final bool includeLabels;
  final String? title;
  final TextStyle? defaultTitleStyle;
  
  const BarChartSvgOptions({
    this.includeGrid = true,
    this.includeValues = true,
    this.includeLabels = true,
    this.title,
    this.defaultTitleStyle,
  });
}

/// SVG exporter for Bar Charts
class BarChartSvgExporter {
  /// Exports a bar chart to SVG format
  static String exportSvg({
    required List<BarChartData> data,
    required BarChartStyle style,
    required double width,
    required double height,
    required EdgeInsets padding,
    required BarChartSvgOptions options,
    int horizontalGridLines = 5,
  }) {
    if (data.isEmpty) return '<svg></svg>';
    
    final sb = StringBuffer();
    final defs = StringBuffer();
    final body = StringBuffer();
    
    // Calculate chart area
    final chartArea = Rect.fromLTWH(
      padding.left,
      padding.top,
      width - padding.horizontal,
      height - padding.vertical,
    );
    
    // Determine orientation
    final isHorizontal = _isHorizontalOrientation(style.rotation);
    
    // Draw grid
    if (options.includeGrid) {
      body.writeln(_drawGrid(chartArea, style, isHorizontal, horizontalGridLines));
    }
    
    // Draw bars
    body.writeln(_drawBars(chartArea, data, style, isHorizontal, defs));
    
    // Draw labels
    if (options.includeLabels) {
      body.writeln(_drawLabels(chartArea, data, style, isHorizontal, padding));
    }
    
    // Draw values
    if (options.includeValues) {
      body.writeln(_drawValues(chartArea, data, style, isHorizontal));
    }
    
    // Draw title
    if (options.title != null && options.title!.trim().isNotEmpty) {
      body.writeln(_drawTitle(chartArea, style, options, options.title!));
    }
    
    // Build SVG
    sb.writeln('<svg width="$width" height="$height" xmlns="http://www.w3.org/2000/svg">');
    
    // Background
    sb.writeln(_rect(0, 0, width, height, fill: _colorToRgba(style.backgroundColor)));
    
    if (defs.isNotEmpty) {
      sb.writeln('<defs>');
      sb.writeln(defs.toString());
      sb.writeln('</defs>');
    }
    
    sb.writeln(body.toString());
    sb.writeln('</svg>');
    
    return sb.toString();
  }
  
  static bool _isHorizontalOrientation(double rotation) {
    final normalizedRotation = rotation % 360;
    return (normalizedRotation >= 45 && normalizedRotation < 135) ||
        (normalizedRotation >= 225 && normalizedRotation < 315);
  }
  
  static bool _isInverted(double rotation) {
    final normalizedRotation = rotation % 360;
    return normalizedRotation >= 135 && normalizedRotation < 315;
  }
  
  static bool _isReversed(double rotation) {
    return rotation >= 225 && rotation < 315; // 270° mode
  }
  
  static String _drawGrid(Rect area, BarChartStyle style, bool isHorizontal, int gridLines) {
    final items = <String>[];
    final color = _colorToRgba(style.gridColor.withValues(alpha: 0.2));
    
    if (isHorizontal) {
      // Vertical grid lines for horizontal bars
      for (int i = 0; i <= gridLines; i++) {
        final x = area.left + (area.width / gridLines) * i;
        items.add(_line(x, area.top, x, area.bottom, color));
      }
    } else {
      // Horizontal grid lines for vertical bars
      for (int i = 0; i <= gridLines; i++) {
        final y = area.top + (area.height / gridLines) * i;
        items.add(_line(area.left, y, area.right, y, color));
      }
    }
    
    return items.join('\n');
  }
  
  static _ValueRange _resolveValueRange(List<BarChartData> data) {
    final minValue = data.map((d) => d.value).reduce(min);
    final maxValue = data.map((d) => d.value).reduce(max);

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

  static double _valueToVerticalY(
    double value,
    Rect area,
    _ValueRange range,
    bool isInverted,
  ) {
    final normalized = (value - range.lower) / range.span;
    if (isInverted) {
      return area.top + (normalized * area.height);
    }
    return area.bottom - (normalized * area.height);
  }

  static double _valueToHorizontalX(
    double value,
    Rect area,
    _ValueRange range,
    bool isReversed,
  ) {
    final normalized = (value - range.lower) / range.span;
    if (isReversed) {
      return area.right - (normalized * area.width);
    }
    return area.left + (normalized * area.width);
  }

  static String _drawBars(Rect area, List<BarChartData> data, BarChartStyle style, bool isHorizontal, StringBuffer defs) {
    if (data.isEmpty) return '';
    final range = _resolveValueRange(data);
    if (isHorizontal) {
      return _drawHorizontalBars(area, data, style, defs, range);
    } else {
      return _drawVerticalBars(area, data, style, defs, range);
    }
  }
  
  static String _drawVerticalBars(Rect area, List<BarChartData> data, BarChartStyle style, StringBuffer defs, _ValueRange range) {
    final items = <String>[];
    final spacingRatio = style.barSpacing.clamp(0.0, 0.95);
    final unitWidth = area.width / data.length;
    final barWidth = unitWidth * (1 - spacingRatio);
    final spacing = unitWidth * spacingRatio;
    final isInverted = _isInverted(style.rotation);
    final zeroY = _valueToVerticalY(0, area, range, isInverted);
    
    for (int i = 0; i < data.length; i++) {
      final valueY = _valueToVerticalY(data[i].value, area, range, isInverted);
      final fullHeight = (valueY - zeroY).abs();
      final barTop = valueY < zeroY ? zeroY - fullHeight : zeroY;
      final barX = area.left + (i * (barWidth + spacing)) + (spacing / 2);
      
      String fill;
      if (data[i].color != null) {
        fill = _colorToRgba(data[i].color!);
      } else if (style.gradientEffect && style.gradientColors != null) {
        final gradientId = 'barGradient$i';
        defs.writeln(_linearGradientDef(
          gradientId,
          style.gradientColors!,
          x1: 0.5, y1: isInverted ? 0.0 : 1.0,
          x2: 0.5, y2: isInverted ? 1.0 : 0.0,
        ));
        fill = 'url(#$gradientId)';
      } else {
        fill = _colorToRgba(style.barColor);
      }
      
      items.add(_rect(barX, barTop, barWidth, fullHeight, 
        fill: fill, 
        rx: style.cornerRadius, 
        ry: style.cornerRadius));
    }
    
    return items.join('\n');
  }
  
  static String _drawHorizontalBars(Rect area, List<BarChartData> data, BarChartStyle style, StringBuffer defs, _ValueRange range) {
    final items = <String>[];
    final spacingRatio = style.barSpacing.clamp(0.0, 0.95);
    final unitHeight = area.height / data.length;
    final barHeight = unitHeight * (1 - spacingRatio);
    final spacing = unitHeight * spacingRatio;
    final isReversed = _isReversed(style.rotation);
    final zeroX = _valueToHorizontalX(0, area, range, isReversed);
    
    for (int i = 0; i < data.length; i++) {
      final valueX = _valueToHorizontalX(data[i].value, area, range, isReversed);
      final fullWidth = (valueX - zeroX).abs();
      final barLeft = valueX < zeroX ? zeroX - fullWidth : zeroX;
      final barY = area.top + (i * (barHeight + spacing)) + (spacing / 2);
      
      String fill;
      if (data[i].color != null) {
        fill = _colorToRgba(data[i].color!);
      } else if (style.gradientEffect && style.gradientColors != null) {
        final gradientId = 'barGradient$i';
        defs.writeln(_linearGradientDef(
          gradientId,
          style.gradientColors!,
          x1: isReversed ? 1.0 : 0.0, y1: 0.5,
          x2: isReversed ? 0.0 : 1.0, y2: 0.5,
        ));
        fill = 'url(#$gradientId)';
      } else {
        fill = _colorToRgba(style.barColor);
      }
      
      items.add(_rect(barLeft, barY, fullWidth, barHeight, 
        fill: fill, 
        rx: style.cornerRadius, 
        ry: style.cornerRadius));
    }
    
    return items.join('\n');
  }
  
  static String _drawLabels(Rect area, List<BarChartData> data, BarChartStyle style, bool isHorizontal, EdgeInsets padding) {
    final items = <String>[];
    final textStyle = style.labelStyle ?? TextStyle(color: style.barColor, fontSize: 12);
    
    if (isHorizontal) {
      final barHeight = (area.height / data.length) * (1 - style.barSpacing);
      final spacing = (area.height / data.length) * style.barSpacing;
      final isReversed = _isReversed(style.rotation);
      
      for (int i = 0; i < data.length; i++) {
        final y = area.top + (i * (barHeight + spacing)) + (spacing / 2) + barHeight / 2;
        final x = isReversed ? area.right + 8 : area.left - 8;
        items.add(_text(data[i].label, x, y, textStyle, 
          anchor: isReversed ? 'start' : 'end', 
          dominantBaseline: 'middle'));
      }
    } else {
      final barWidth = (area.width / data.length) * (1 - style.barSpacing);
      final spacing = (area.width / data.length) * style.barSpacing;
      final isInverted = _isInverted(style.rotation);
      
      for (int i = 0; i < data.length; i++) {
        final x = area.left + (i * (barWidth + spacing)) + (spacing / 2) + barWidth / 2;
        final y = isInverted ? area.top - 8 : area.bottom + 16;
        items.add(_text(data[i].label, x, y, textStyle, 
          anchor: 'middle', 
          dominantBaseline: isInverted ? 'auto' : 'hanging'));
      }
    }
    
    return items.join('\n');
  }
  
  static String _drawValues(Rect area, List<BarChartData> data, BarChartStyle style, bool isHorizontal) {
    final items = <String>[];
    final range = _resolveValueRange(data);
    final baseTextStyle = style.valueStyle ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    
    if (isHorizontal) {
      final spacingRatio = style.barSpacing.clamp(0.0, 0.95);
      final unitHeight = area.height / data.length;
      final barHeight = unitHeight * (1 - spacingRatio);
      final spacing = unitHeight * spacingRatio;
      final isReversed = _isReversed(style.rotation);
      final zeroX = _valueToHorizontalX(0, area, range, isReversed);
      
      for (int i = 0; i < data.length; i++) {
        final barColor = data[i].color ?? style.barColor;
        final textStyle = baseTextStyle.copyWith(color: barColor);
        final valueX = _valueToHorizontalX(data[i].value, area, range, isReversed);
        final fullWidth = (valueX - zeroX).abs();
        final barLeft = valueX < zeroX ? zeroX - fullWidth : zeroX;
        final y = area.top + (i * (barHeight + spacing)) + (spacing / 2) + barHeight / 2;
        final isToRight = valueX > zeroX;
        final x = isToRight ? barLeft + fullWidth + 4 : barLeft - 4;
        final valueText = data[i].value.toStringAsFixed(1);
        items.add(_text(valueText, x, y, textStyle, 
          anchor: isToRight ? 'start' : 'end', 
          dominantBaseline: 'middle'));
      }
    } else {
      final spacingRatio = style.barSpacing.clamp(0.0, 0.95);
      final unitWidth = area.width / data.length;
      final barWidth = unitWidth * (1 - spacingRatio);
      final spacing = unitWidth * spacingRatio;
      final isInverted = _isInverted(style.rotation);
      final zeroY = _valueToVerticalY(0, area, range, isInverted);
      
      for (int i = 0; i < data.length; i++) {
        final barColor = data[i].color ?? style.barColor;
        final textStyle = baseTextStyle.copyWith(color: barColor);
        final valueY = _valueToVerticalY(data[i].value, area, range, isInverted);
        final fullHeight = (valueY - zeroY).abs();
        final barTop = valueY < zeroY ? zeroY - fullHeight : zeroY;
        final x = area.left + (i * (barWidth + spacing)) + (spacing / 2) + barWidth / 2;
        final isUpward = valueY < zeroY;
        final y = isUpward ? barTop - 4 : barTop + fullHeight + 4;
        final valueText = data[i].value.toStringAsFixed(1);
        items.add(_text(valueText, x, y, textStyle, 
          anchor: 'middle', 
          dominantBaseline: isUpward ? 'auto' : 'hanging'));
      }
    }
    
    return items.join('\n');
  }
  
  static String _drawTitle(Rect area, BarChartStyle style, BarChartSvgOptions options, String title) {
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
  
  static String _linearGradientDef(String id, List<Color> colors, {double x1 = 0, double y1 = 0, double x2 = 1, double y2 = 1}) {
    final stops = <String>[];
    for (int i = 0; i < colors.length; i++) {
      final offset = i / (colors.length - 1);
      final color = _colorToHex(colors[i]);
      final opacity = _colorOpacity(colors[i]);
      stops.add('<stop offset="$offset" stop-color="$color" stop-opacity="$opacity"/>');
    }
    return '<linearGradient id="$id" x1="$x1" y1="$y1" x2="$x2" y2="$y2">\n${stops.join('\n')}\n</linearGradient>';
  }
  
  static String _colorToRgba(Color color) {
    return 'rgba(${color.red},${color.green},${color.blue},${color.alpha / 255.0})';
  }
  
  static String _colorToHex(Color color) {
    return '#${color.red.toRadixString(16).padLeft(2, '0')}${color.green.toRadixString(16).padLeft(2, '0')}${color.blue.toRadixString(16).padLeft(2, '0')}';
  }
  
  static double _colorOpacity(Color color) {
    return color.alpha / 255.0;
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
