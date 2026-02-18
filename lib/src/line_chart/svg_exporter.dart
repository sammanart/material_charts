import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

/// Options for controlling what elements to include in the SVG export
class LineChartSvgOptions {
  final bool includeGrid;
  final bool showPoints;
  final bool includeLabels;
  final String? title;
  final TextStyle? defaultTitleStyle;
  
  const LineChartSvgOptions({
    this.includeGrid = true,
    this.showPoints = true,
    this.includeLabels = true,
    this.title,
    this.defaultTitleStyle,
  });
}

/// SVG exporter for Line Charts
class LineChartSvgExporter {
  /// Exports a line chart to SVG format
  static String exportSvg({
    required List<ChartData> data,
    required LineChartStyle style,
    required double width,
    required double height,
    required EdgeInsets padding,
    required LineChartSvgOptions options,
    int horizontalGridLines = 5,
  }) {
    if (data.isEmpty) return '<svg></svg>';
    
    final sb = StringBuffer();
    final body = StringBuffer();
    
    // Calculate chart area
    final chartArea = Rect.fromLTWH(
      padding.left,
      padding.top,
      width - padding.horizontal,
      height - padding.vertical,
    );
    
    // Draw grid
    if (options.includeGrid) {
      body.writeln(_drawGrid(chartArea, style, data.length, horizontalGridLines));
    }
    
    // Draw line
    body.writeln(_drawLine(chartArea, data, style));
    
    // Draw points
    if (options.showPoints) {
      body.writeln(_drawPoints(chartArea, data, style));
    }
    
    // Draw labels
    if (options.includeLabels) {
      body.writeln(_drawLabels(chartArea, data, style, padding));
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
  
  static String _drawGrid(Rect area, LineChartStyle style, int dataLength, int gridLines) {
    final items = <String>[];
    final color = _colorToRgba(style.gridColor.withValues(alpha: 0.2));
    
    // Horizontal grid lines
    for (int i = 0; i <= gridLines; i++) {
      final y = area.top + (area.height / gridLines) * i;
      items.add(_line(area.left, y, area.right, y, color));
    }
    
    // Vertical grid lines at each data point
    for (int i = 0; i < dataLength; i++) {
      final x = area.left + (area.width / (dataLength - 1)) * i;
      items.add(_line(x, area.top, x, area.bottom, color));
    }
    
    return items.join('\n');
  }
  
  static String _drawLine(Rect area, List<ChartData> data, LineChartStyle style) {
    if (data.isEmpty) return '';
    
    final points = _getPointCoordinates(area, data);
    
    String pathData;
    if (style.useCurvedLines) {
      pathData = _createSmoothCurvedPath(points, style.curveIntensity);
    } else {
      pathData = _createStraightPath(points);
    }
    
    return _path(pathData, _colorToRgba(style.lineColor), style.strokeWidth, style.roundedPoints);
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
  
  static String _drawPoints(Rect area, List<ChartData> data, LineChartStyle style) {
    final items = <String>[];
    final points = _getPointCoordinates(area, data);
    
    for (final point in points) {
      items.add(_circle(point.dx, point.dy, style.pointRadius, _colorToRgba(style.pointColor)));
    }
    
    return items.join('\n');
  }
  
  static String _drawLabels(Rect area, List<ChartData> data, LineChartStyle style, EdgeInsets padding) {
    final items = <String>[];
    final textStyle = style.labelStyle ?? TextStyle(color: style.lineColor, fontSize: 12);
    
    for (int i = 0; i < data.length; i++) {
      final x = area.left + (area.width / (data.length - 1)) * i;
      final y = area.bottom + padding.bottom / 2;
      items.add(_text(data[i].label, x, y, textStyle, anchor: 'middle', dominantBaseline: 'middle'));
    }
    
    return items.join('\n');
  }
  
  static String _drawTitle(Rect area, LineChartStyle style, LineChartSvgOptions options, String title) {
    final textStyle = style.labelStyle ?? options.defaultTitleStyle ?? const TextStyle(fontSize: 14, color: Colors.black);
    final y = max(12.0, area.top - 18.0);
    return _text(title, area.left, y, textStyle.copyWith(fontWeight: FontWeight.bold), 
      anchor: 'start', dominantBaseline: 'hanging');
  }
  
  static List<Offset> _getPointCoordinates(Rect area, List<ChartData> data) {
    if (data.isEmpty) return [];
    
    final maxValue = data.map((d) => d.value).reduce(max);
    final minValue = data.map((d) => d.value).reduce(min);
    final valueRange = maxValue - minValue;
    
    if (valueRange == 0) {
      return List.generate(data.length, (i) {
        final x = area.left + (area.width / (data.length - 1)) * i;
        final y = area.top + area.height / 2;
        return Offset(x, y);
      });
    }
    
    return List.generate(data.length, (i) {
      final x = area.left + (area.width / (data.length - 1)) * i;
      final normalizedValue = (data[i].value - minValue) / valueRange;
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
  
  static String _path(String d, String stroke, double strokeWidth, bool rounded) {
    final linecap = rounded ? 'round' : 'butt';
    final linejoin = rounded ? 'round' : 'miter';
    return '<path d="$d" stroke="$stroke" stroke-width="$strokeWidth" fill="none" stroke-linecap="$linecap" stroke-linejoin="$linejoin"/>';
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
