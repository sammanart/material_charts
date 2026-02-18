import 'dart:math';

import 'package:flutter/material.dart';

import '../shared/shared_models.dart';
import 'models.dart';

/// Options for controlling what elements to include in the SVG export
class AreaChartSvgOptions {
  final bool includeGrid;
  final bool showPoints;
  final bool showKeyEventMarkers;
  final String? title;
  final double labelVerticalOffset;
  final TextStyle? defaultLabelStyle;
  final TextStyle? defaultTitleStyle;
  
  const AreaChartSvgOptions({
    this.includeGrid = true,
    this.showPoints = true,
    this.showKeyEventMarkers = true,
    this.title,
    this.labelVerticalOffset = 12.0,
    this.defaultLabelStyle,
    this.defaultTitleStyle,
  });
}

/// SVG exporter for Area Charts
class AreaChartSvgExporter {
  /// Exports an area chart to SVG format
  static String exportSvg({
    required List<AreaChartSeries> series,
    required AreaChartStyle style,
    required double width,
    required double height,
    required EdgeInsets padding,
    required AreaChartSvgOptions options,
  }) {
    if (series.isEmpty) return '<svg></svg>';
    
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
    
    // Draw grid
    if (options.includeGrid && style.showGrid) {
      body.writeln(_drawGrid(chartArea, style, series));
    }
    
    // Draw each series
    for (int i = 0; i < series.length; i++) {
      final seriesData = series[i];
      final color = seriesData.color ?? style.colors[i % style.colors.length];
      final topFill = color.withValues(alpha: style.areaFillOpacityTop.clamp(0.0, 1.0));
      final bottomFill = color.withValues(alpha: style.areaFillOpacityBottom.clamp(0.0, 1.0));
      
      // Draw area
      body.writeln(_drawArea(chartArea, seriesData, series, style, topFill, bottomFill, defs, i));
      
      // Draw line
      body.writeln(_drawLine(chartArea, seriesData, series, style, color));
      
      // Draw points
      if (options.showPoints && (seriesData.showPoints ?? style.showPoints)) {
        body.writeln(_drawPoints(chartArea, seriesData, series, style, color));
      }
      
      // Draw key event markers
      if (options.showKeyEventMarkers && style.showKeyEventMarkers) {
        body.writeln(_drawKeyEventMarkers(chartArea, seriesData, series, style, color));
      }
    }
    
    // Draw labels and Y-axis
    body.writeln(_drawLabels(chartArea, series, style, options));
    body.writeln(_drawYAxisLabels(chartArea, series, style, options));
    
    // Draw baseline if configured
    if (style.baseline != null) {
      body.writeln(_drawBaseline(chartArea, series, style));
    }
    
    // Draw title
    if (options.title != null && options.title!.trim().isNotEmpty) {
      body.writeln(_drawTitle(chartArea, style, options, options.title!));
    }
    
    // Build SVG
    sb.writeln('<svg width="$width" height="$height" xmlns="http://www.w3.org/2000/svg">');
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
  
  static String _drawGrid(Rect area, AreaChartStyle style, List<AreaChartSeries> series) {
    final items = <String>[];
    final color = _colorToRgba(style.gridColor.withValues(alpha: 0.2));
    
    // Horizontal grid lines only
    for (int i = 0; i <= style.horizontalGridLines; i++) {
      final y = area.top + (area.height / style.horizontalGridLines) * i;
      items.add(_line(area.left, y, area.right, y, color));
    }
    
    return items.join('\n');
  }
  
  static String _drawArea(
    Rect area, 
    AreaChartSeries seriesData, 
    List<AreaChartSeries> allSeries,
    AreaChartStyle style, 
    Color topFill, 
    Color bottomFill,
    StringBuffer defs,
    int seriesIndex,
  ) {
    final points = _getSeriesPoints(area, seriesData, allSeries, style);
    if (points.isEmpty) return '';
    
    // Build path
    final pathSb = StringBuffer();
    pathSb.write('M ${points.first.dx} ${area.bottom} ');
    pathSb.write('L ${points.first.dx} ${points.first.dy} ');
    
    for (int i = 1; i < points.length; i++) {
      pathSb.write('L ${points[i].dx} ${points[i].dy} ');
    }
    
    pathSb.write('L ${points.last.dx} ${area.bottom} Z');
    
    // Create gradient
    final gradientId = 'areaGradient$seriesIndex';
    defs.writeln(_linearGradientDef(gradientId, [topFill, bottomFill], x1: 0.5, y1: 0.0, x2: 0.5, y2: 1.0));
    
    return '<path d="$pathSb" fill="url(#$gradientId)"/>';
  }
  
  static String _drawLine(
    Rect area, 
    AreaChartSeries seriesData, 
    List<AreaChartSeries> allSeries,
    AreaChartStyle style, 
    Color color,
  ) {
    final points = _getSeriesPoints(area, seriesData, allSeries, style);
    if (points.isEmpty) return '';
    
    final pathSb = StringBuffer();
    pathSb.write('M ${points.first.dx} ${points.first.dy}');
    
    for (int i = 1; i < points.length; i++) {
      pathSb.write(' L ${points[i].dx} ${points[i].dy}');
    }
    
    final lineWidth = seriesData.lineWidth ?? style.defaultLineWidth;
    return '<path d="$pathSb" stroke="${_colorToRgba(color)}" stroke-width="$lineWidth" fill="none" stroke-linecap="round" stroke-linejoin="round"/>';
  }
  
  static String _drawPoints(
    Rect area, 
    AreaChartSeries seriesData, 
    List<AreaChartSeries> allSeries,
    AreaChartStyle style, 
    Color color,
  ) {
    final items = <String>[];
    final points = _getSeriesPoints(area, seriesData, allSeries, style);
    final pointSize = seriesData.pointSize ?? style.defaultPointSize;
    
    for (final point in points) {
      // Draw filled circle with series color, then add border
      items.add(_circle(point.dx, point.dy, pointSize, _colorToRgba(color), strokeColor: _colorToRgba(style.backgroundColor), strokeWidth: 2));
    }
    
    return items.join('\n');
  }
  
  static String _drawKeyEventMarkers(
    Rect area, 
    AreaChartSeries seriesData, 
    List<AreaChartSeries> allSeries,
    AreaChartStyle style, 
    Color color,
  ) {
    final items = <String>[];
    final points = _getSeriesPoints(area, seriesData, allSeries, style);
    final config = style.keyEventMarkerConfig ?? const KeyEventMarkerConfig();
    
    for (int i = 0; i < seriesData.dataPoints.length && i < points.length; i++) {
      final keyEvent = seriesData.dataPoints[i].keyEvent;
      if (keyEvent != null) {
        final point = points[i];
        final markerSize = keyEvent.markerSize ?? config.size; // Use custom size if provided
        final verticalOffset = keyEvent.verticalOffset ?? config.verticalOffset; // Use custom offset if provided
        final markerY = point.dy - verticalOffset;
        final markerColor = keyEvent.markerColor ?? config.defaultColor;
        
        // Note: markerSize is the diameter, so radius is markerSize / 2
        items.add(_circle(point.dx, markerY, markerSize / 2, _colorToRgba(markerColor)));
      }
    }
    
    return items.join('\n');
  }
  
  static String _drawLabels(Rect area, List<AreaChartSeries> series, AreaChartStyle style, AreaChartSvgOptions options) {
    if (series.isEmpty || series[0].dataPoints.isEmpty) return '';
    
    final items = <String>[];
    final firstSeries = series[0];
    final slots = style.xSpanSlots ?? firstSeries.dataPoints.length;
    final pointCount = min(firstSeries.dataPoints.length, slots);
    final denom = (slots - 1) <= 0 ? 1 : (slots - 1);
    final textStyle = style.labelStyle ?? options.defaultLabelStyle ?? const TextStyle(fontSize: 10, color: Colors.black54);
    // Vertical lines use faded gridColor to match painter behavior
    final verticalLineColor = _colorToRgba(style.gridColor.withValues(alpha: 0.2));
    
    // Draw vertical lines and labels for data points with labels
    for (int i = 0; i < pointCount; i++) {
      final label = firstSeries.dataPoints.elementAt(i).label;
      // Only draw vertical line if label is not null and not empty string
      if (label != null && label != "") {
        final x = area.left + (area.width / denom) * i;
        // Draw vertical line
        items.add(_line(x, area.top, x, area.bottom, verticalLineColor));
        // Draw label text
        final y = area.bottom + options.labelVerticalOffset;
        items.add(_text(label, x, y, textStyle, 
          anchor: 'middle', dominantBaseline: 'hanging'));
      }
    }
    
    return items.join('\n');
  }
  
  static String _drawYAxisLabels(Rect area, List<AreaChartSeries> series, AreaChartStyle style, AreaChartSvgOptions options) {
    if (series.isEmpty) return '';
    
    final items = <String>[];
    final allValues = series.expand((s) => s.dataPoints.map((d) => d.value));
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    final minValue = style.forceYAxisFromZero ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    final valueRange = maxValue - minValue;
    
    final textStyle = style.labelStyle ?? options.defaultLabelStyle ?? const TextStyle(fontSize: 10, color: Colors.black54);
    
    // Draw Y-axis labels for each horizontal grid line
    for (int i = 0; i <= style.horizontalGridLines; i++) {
      final y = area.top + (area.height / style.horizontalGridLines) * i;
      final value = maxValue - (valueRange / style.horizontalGridLines * i);
      
      final labelText = value.toStringAsFixed(1);
      final labelX = area.right + 8;  // Position to the right of the chart
      final labelY = y;
      
      items.add(_text(labelText, labelX, labelY, textStyle, 
        anchor: 'start', dominantBaseline: 'middle'));
    }
    
    return items.join('\n');
  }
  
  static String _drawBaseline(Rect area, List<AreaChartSeries> series, AreaChartStyle style) {
    final baseline = style.baseline;
    if (baseline == null || !baseline.show) return '';
    if (series.isEmpty || series[0].dataPoints.isEmpty) return '';
    
    final firstValue = series[0].dataPoints[0].value;
    final seriesColor = series[0].color ?? style.colors[0];
    final baselineColor = baseline.color ?? seriesColor;
    
    final allValues = series.expand((s) => s.dataPoints.map((d) => d.value));
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    final minValue = style.forceYAxisFromZero ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    final valueRange = maxValue - minValue;
    
    if (valueRange == 0) return '';
    
    final normalizedValue = (firstValue - minValue) / valueRange;
    final y = area.bottom - (normalizedValue * area.height);
    
    // Create dashed line
    final items = <String>[];
    final dashWidth = baseline.dashPattern.isNotEmpty ? baseline.dashPattern[0] : 5.0;
    final dashSpace = baseline.dashPattern.length > 1 ? baseline.dashPattern[1] : 5.0;
    var startX = area.left;
    
    while (startX < area.right) {
      final endX = (startX + dashWidth).clamp(area.left, area.right);
      items.add(_line(startX, y, endX, y, _colorToRgba(baselineColor), 
        strokeWidth: baseline.strokeWidth));
      startX = endX + dashSpace;
    }
    
    return items.join('\n');
  }
  
  static String _drawTitle(Rect area, AreaChartStyle style, AreaChartSvgOptions options, String title) {
    final textStyle = style.labelStyle ?? options.defaultTitleStyle ?? const TextStyle(fontSize: 14, color: Colors.black);
    final y = max(12.0, area.top - 18.0);
    return _text(title, area.left, y, textStyle.copyWith(fontWeight: FontWeight.bold), 
      anchor: 'start', dominantBaseline: 'hanging');
  }
  
  static List<Offset> _getSeriesPoints(
    Rect area, 
    AreaChartSeries seriesData,
    List<AreaChartSeries> allSeries,
    AreaChartStyle style,
  ) {
    if (seriesData.dataPoints.isEmpty) return [];
    
    final dataPoints = seriesData.dataPoints;
    final allValues = allSeries.expand((s) => s.dataPoints.map((d) => d.value));
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    final minValue = style.forceYAxisFromZero ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    final valueRange = maxValue - minValue;
    
    // Handle xSpanSlots to spread points across wider area
    final slots = style.xSpanSlots ?? dataPoints.length;
    final denom = (slots - 1) <= 0 ? 1 : (slots - 1);
    
    if (valueRange == 0) {
      return List.generate(dataPoints.length, (i) {
        final x = area.left + (area.width / denom) * i;
        final y = area.top + area.height / 2;
        return Offset(x, y);
      });
    }
    
    return List.generate(dataPoints.length, (i) {
      final x = area.left + (area.width / denom) * i;
      final normalizedValue = (dataPoints[i].value - minValue) / valueRange;
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
  
  static String _circle(double cx, double cy, double r, String fill, {String? strokeColor, double strokeWidth = 0}) {
    if (strokeColor != null && strokeWidth > 0) {
      return '<circle cx="$cx" cy="$cy" r="$r" fill="$fill" stroke="$strokeColor" stroke-width="$strokeWidth"/>';
    }
    return '<circle cx="$cx" cy="$cy" r="$r" fill="$fill"/>';
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
