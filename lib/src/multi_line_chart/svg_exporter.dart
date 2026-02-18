import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

/// Options for controlling what elements to include in the SVG export
class MultiLineChartSvgOptions {
  final bool includeGrid;
  final bool showPoints;
  final bool showLegend;
  final String? title;
  final double legendHeight;
  final double legendItemWidth;
  final double legendIconSize;
  final double legendSpacing;
  final double labelVerticalOffset;
  final TextStyle? defaultLabelStyle;
  final TextStyle? defaultLegendStyle;
  final TextStyle? defaultTitleStyle;
  
  const MultiLineChartSvgOptions({
    this.includeGrid = true,
    this.showPoints = true,
    this.showLegend = true,
    this.title,
    this.legendHeight = 40.0,
    this.legendItemWidth = 120.0,
    this.legendIconSize = 8.0,
    this.legendSpacing = 16.0,
    this.labelVerticalOffset = 12.0,
    this.defaultLabelStyle,
    this.defaultLegendStyle,
    this.defaultTitleStyle,
  });
}

/// SVG exporter for Multi-Line Charts
class MultiLineChartSvgExporter {
  /// Exports a multi-line chart to SVG format
  static String exportSvg({
    required List<ChartSeries> series,
    required MultiLineChartStyle style,
    required double width,
    required double height,
    required EdgeInsets padding,
    required MultiLineChartSvgOptions options,
  }) {
    if (series.isEmpty) return '<svg></svg>';
    
    final sb = StringBuffer();
    final body = StringBuffer();
    
    // Calculate chart area
    final legendHeight = options.showLegend && style.showLegend ? options.legendHeight : 0.0;
    final chartArea = Rect.fromLTWH(
      padding.left,
      padding.top,
      width - padding.horizontal,
      height - padding.vertical - legendHeight,
    );
    
    // Draw grid
    if (options.includeGrid && style.showGrid) {
      body.writeln(_drawGrid(chartArea, style, series));
    }
    
    // Draw each series
    for (int i = 0; i < series.length; i++) {
      final seriesData = series[i];
      final color = seriesData.color ?? style.colors[i % style.colors.length];
      
      // Draw line
      body.writeln(_drawLine(chartArea, seriesData, series, style, color));
      
      // Draw points
      if (options.showPoints && (seriesData.showPoints ?? style.showPoints)) {
        body.writeln(_drawPoints(chartArea, seriesData, series, style, color));
      }
    }
    
    // Draw X-axis labels
    body.writeln(_drawLabels(chartArea, series, style, options));
    
    // Draw legend
    if (options.showLegend && style.showLegend) {
      body.writeln(_drawLegend(chartArea, series, style, options, width, height, legendHeight));
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
  
  static String _drawGrid(Rect area, MultiLineChartStyle style, List<ChartSeries> series) {
    final items = <String>[];
    final color = _colorToRgba(style.gridColor.withValues(alpha: 0.2));
    final maxLength = series.map((s) => s.dataPoints.length).reduce(max);
    
    // Horizontal grid lines
    for (int i = 0; i <= style.horizontalGridLines; i++) {
      final y = area.top + (area.height / style.horizontalGridLines) * i;
      items.add(_line(area.left, y, area.right, y, color));
    }
    
    // Vertical grid lines
    final xCount = maxLength > 1 ? maxLength - 1 : 1;
    for (int i = 0; i < maxLength; i++) {
      final x = area.left + (area.width / xCount) * i;
      items.add(_line(x, area.top, x, area.bottom, color));
    }
    
    return items.join('\n');
  }
  
  static String _drawLine(
    Rect area, 
    ChartSeries seriesData, 
    List<ChartSeries> allSeries,
    MultiLineChartStyle style, 
    Color color,
  ) {
    final points = _getSeriesPoints(area, seriesData, allSeries);
    if (points.isEmpty) return '';
    
    String pathData;
    if (style.smoothLines) {
      pathData = _createSmoothCurvedPath(points, 0.3);
    } else {
      pathData = _createStraightPath(points);
    }
    
    final lineWidth = seriesData.lineWidth ?? style.defaultLineWidth;
    return '<path d="$pathData" stroke="${_colorToRgba(color)}" stroke-width="$lineWidth" fill="none" stroke-linecap="round" stroke-linejoin="round"/>';
  }
  
  static String _createStraightPath(List<Offset> points) {
    if (points.isEmpty) return '';
    
    final sb = StringBuffer();
    sb.write('M ${points[0].dx} ${points[0].dy}');
    
    for (int i = 1; i < points.length; i++) {
      sb.write(' L ${points[i].dx} ${points[i].dy}');
    }
    
    return sb.toString();
  }
  
  static String _createSmoothCurvedPath(List<Offset> points, double intensity) {
    if (points.length < 2) return _createStraightPath(points);
    
    final sb = StringBuffer();
    sb.write('M ${points[0].dx} ${points[0].dy}');
    
    if (points.length == 2) {
      sb.write(' L ${points[1].dx} ${points[1].dy}');
      return sb.toString();
    }
    
    final controlPoints = _generateSmoothControlPoints(points, intensity);
    
    for (int i = 0; i < points.length - 1; i++) {
      final next = points[i + 1];
      final cp1 = controlPoints[i * 2];
      final cp2 = controlPoints[i * 2 + 1];
      sb.write(' C ${cp1.dx} ${cp1.dy}, ${cp2.dx} ${cp2.dy}, ${next.dx} ${next.dy}');
    }
    
    return sb.toString();
  }
  
  static List<Offset> _generateSmoothControlPoints(List<Offset> points, double intensity) {
    final controlPoints = <Offset>[];
    final clampedIntensity = intensity.clamp(0.0, 1.0);
    
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      
      final distance = (next - current).distance;
      final controlDistance = distance * clampedIntensity * 0.4;
      
      Offset cp1, cp2;
      
      if (i == 0) {
        cp1 = current + Offset(controlDistance, 0);
        cp2 = next - Offset(controlDistance, 0);
      } else if (i == points.length - 2) {
        cp1 = current + Offset(controlDistance, 0);
        cp2 = next - Offset(controlDistance, 0);
      } else {
        final prev = points[i - 1];
        final after = i + 2 < points.length ? points[i + 2] : next;
        
        final tangent1 = _normalized(next - prev) * controlDistance;
        final tangent2 = _normalized(after - current) * controlDistance;
        
        cp1 = current + tangent1;
        cp2 = next - tangent2;
      }
      
      controlPoints.add(cp1);
      controlPoints.add(cp2);
    }
    
    return controlPoints;
  }
  
  static Offset _normalized(Offset offset) {
    final length = offset.distance;
    if (length == 0) return Offset.zero;
    return offset / length;
  }
  
  static String _drawPoints(
    Rect area, 
    ChartSeries seriesData, 
    List<ChartSeries> allSeries,
    MultiLineChartStyle style, 
    Color color,
  ) {
    final items = <String>[];
    final points = _getSeriesPoints(area, seriesData, allSeries);
    final pointSize = seriesData.pointSize ?? style.defaultPointSize;
    
    for (final point in points) {
      items.add(_circle(point.dx, point.dy, pointSize, _colorToRgba(color)));
    }
    
    return items.join('\n');
  }
  
  static String _drawLabels(Rect area, List<ChartSeries> series, MultiLineChartStyle style, MultiLineChartSvgOptions options) {
    if (series.isEmpty || series[0].dataPoints.isEmpty) return '';
    
    final items = <String>[];
    final firstSeries = series[0];
    final maxLength = series.map((s) => s.dataPoints.length).reduce(max);
    final xCount = maxLength > 1 ? maxLength - 1 : 1;
    final textStyle = style.labelStyle ?? options.defaultLabelStyle ?? const TextStyle(fontSize: 10, color: Colors.black54);
    
    for (int i = 0; i < firstSeries.dataPoints.length; i++) {
      final label = firstSeries.dataPoints[i].label ?? '';
      if (label.isEmpty) continue;
      final x = area.left + (area.width / xCount) * i;
      final y = area.bottom + options.labelVerticalOffset;
      items.add(_text(label, x, y, textStyle, 
        anchor: 'middle', dominantBaseline: 'hanging'));
    }
    
    return items.join('\n');
  }
  
  static String _drawLegend(Rect area, List<ChartSeries> series, MultiLineChartStyle style, MultiLineChartSvgOptions options, double width, double height, double legendHeight) {
    final items = <String>[];
    final itemWidth = options.legendItemWidth;
    final iconSize = options.legendIconSize;
    final spacing = options.legendSpacing;
    
    final legendY = area.bottom + spacing;
    var currentX = area.left;
    
    for (int i = 0; i < series.length; i++) {
      final color = series[i].color ?? style.colors[i % style.colors.length];
      
      // Draw color circle (matching Flutter rendering)
      items.add(_circle(currentX + iconSize / 2, legendY + iconSize / 2, iconSize / 2, _colorToRgba(color)));
      
      // Draw label
      final textStyle = style.legendStyle ?? options.defaultLegendStyle ?? const TextStyle(fontSize: 12, color: Colors.black87);
      items.add(_text(series[i].name, currentX + iconSize + 8, legendY + iconSize / 2, textStyle, anchor: 'start', dominantBaseline: 'middle'));
      
      currentX += itemWidth;
      if (currentX + itemWidth > area.right) {
        currentX = area.left;
        legendY + iconSize + spacing;
      }
    }
    
    return items.join('\n');
  }
  
  static String _drawTitle(Rect area, MultiLineChartStyle style, MultiLineChartSvgOptions options, String title) {
    final textStyle = style.labelStyle ?? options.defaultTitleStyle ?? const TextStyle(fontSize: 14, color: Colors.black);
    final y = max(12.0, area.top - 18.0);
    return _text(title, area.left, y, textStyle.copyWith(fontWeight: FontWeight.bold), 
      anchor: 'start', dominantBaseline: 'hanging');
  }
  
  static List<Offset> _getSeriesPoints(Rect area, ChartSeries seriesData, List<ChartSeries> allSeries) {
    if (seriesData.dataPoints.isEmpty) return [];
    
    final allValues = allSeries.expand((s) => s.dataPoints.map((d) => d.value));
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    final minValue = allValues.reduce((a, b) => a < b ? a : b);
    final valueRange = maxValue - minValue;
    
    if (valueRange == 0) {
      return List.generate(seriesData.dataPoints.length, (i) {
        final x = area.left + (area.width / (seriesData.dataPoints.length - 1)) * i;
        final y = area.top + area.height / 2;
        return Offset(x, y);
      });
    }
    
    return List.generate(seriesData.dataPoints.length, (i) {
      final x = area.left + (area.width / (seriesData.dataPoints.length - 1)) * i;
      final normalizedValue = (seriesData.dataPoints[i].value - minValue) / valueRange;
      final y = area.bottom - (normalizedValue * area.height);
      return Offset(x, y);
    });
  }
  
  // SVG primitive helpers
  
  static String _rect(double x, double y, double w, double h, {String? fill}) {
    return '<rect x="$x" y="$y" width="$w" height="$h" fill="${fill ?? 'none'}"/>';
  }
  
  static String _line(double x1, double y1, double x2, double y2, String stroke, {double strokeWidth = 1}) {
    return '<line x1="$x1" y1="$y1" x2="$x2" y2="$y2" stroke="$stroke" stroke-width="$strokeWidth"/>';
  }
  
  static String _circle(double cx, double cy, double r, String fill) {
    return '<circle cx="$cx" cy="$cy" r="$r" fill="$fill"/>';
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
