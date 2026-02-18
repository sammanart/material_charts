import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

/// Options for controlling what elements to include in the SVG export
class PieChartSvgOptions {
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showConnectorLines;
  final String? title;
  final double legendItemHeight;
  final double legendIconSize;
  final double legendVerticalOffset;
  final TextStyle? defaultLabelStyle;
  final TextStyle? defaultTitleStyle;
  
  const PieChartSvgOptions({
    this.showLabels = true,
    this.showValues = true,
    this.showLegend = true,
    this.showConnectorLines = true,
    this.title,
    this.legendItemHeight = 24.0,
    this.legendIconSize = 16.0,
    this.legendVerticalOffset = 24.0,
    this.defaultLabelStyle,
    this.defaultTitleStyle,
  });
}

/// SVG exporter for Pie Charts
class PieChartSvgExporter {
  /// Exports a pie chart to SVG format
  static String exportSvg({
    required List<PieChartData> data,
    required PieChartStyle style,
    required double width,
    required double height,
    required EdgeInsets padding,
    required PieChartSvgOptions options,
    required double chartRadius,
  }) {
    if (data.isEmpty) return '<svg></svg>';
    
    final sb = StringBuffer();
    final body = StringBuffer();
    
    // Calculate center and radius
    final radius = [
      (width - padding.horizontal) / 2,
      (height - padding.vertical) / 2,
      chartRadius,
    ].reduce(min);
    
    final centerX = switch (style.chartAlignment.horizontal) {
      Horizontal.center => width / 2,
      Horizontal.left => radius + padding.left,
      Horizontal.right => width - (padding.right + radius),
    };
    
    final centerY = switch (style.chartAlignment.vertical) {
      Vertical.center => height / 2,
      Vertical.top => radius + padding.top,
      Vertical.bottom => height - (padding.bottom + radius),
    };
    
    // Draw segments
    body.writeln(_drawSegments(Offset(centerX, centerY), radius, data, style, options));
    
    // Draw hole for doughnut chart
    if (style.holeRadius > 0) {
      body.writeln(_circle(centerX, centerY, radius * style.holeRadius, _colorToRgba(style.backgroundColor)));
    }
    
    // Draw legend
    if (options.showLegend && style.showLegend) {
      body.writeln(_drawLegend(Size(width, height), radius, padding, data, style, options));
    }
    
    // Draw title
    if (options.title != null && options.title!.trim().isNotEmpty) {
      body.writeln(_drawTitle(padding, style, options, options.title!));
    }
    
    // Build SVG
    sb.writeln('<svg width="$width" height="$height" xmlns="http://www.w3.org/2000/svg">');
    sb.writeln(_rect(0, 0, width, height, fill: _colorToRgba(style.backgroundColor)));
    sb.writeln(body.toString());
    sb.writeln('</svg>');
    
    return sb.toString();
  }
  
  static String _drawSegments(Offset center, double radius, List<PieChartData> data, PieChartStyle style, PieChartSvgOptions options) {
    final items = <String>[];
    final total = data.fold(0.0, (sum, item) => sum + item.value);
    var startAngle = style.startAngle * pi / 180;
    
    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i].value / total) * 2 * pi;
      final segmentColor = data[i].color ?? style.defaultColors[i % style.defaultColors.length];
      
      // Draw arc
      items.add(_drawArc(center, radius, startAngle, sweepAngle, segmentColor));
      
      // Draw labels and values
      if (options.showLabels || options.showValues) {
        items.add(_drawLabelsAndValues(
          center,
          radius,
          startAngle,
          sweepAngle,
          data[i],
          (data[i].value / total * 100).toStringAsFixed(1),
          style,
          options,
        ));
      }
      
      startAngle += sweepAngle;
    }
    
    return items.join('\n');
  }
  
  static String _drawArc(Offset center, double radius, double startAngle, double sweepAngle, Color color) {
    final endAngle = startAngle + sweepAngle;
    
    // Calculate start and end points
    final startX = center.dx + cos(startAngle) * radius;
    final startY = center.dy + sin(startAngle) * radius;
    final endX = center.dx + cos(endAngle) * radius;
    final endY = center.dy + sin(endAngle) * radius;
    
    // Determine if we need large arc flag
    final largeArcFlag = sweepAngle > pi ? 1 : 0;
    
    // Build path
    final path = StringBuffer();
    path.write('M ${center.dx} ${center.dy} '); // Move to center
    path.write('L $startX $startY '); // Line to arc start
    path.write('A $radius $radius 0 $largeArcFlag 1 $endX $endY '); // Arc
    path.write('Z'); // Close path
    
    return '<path d="$path" fill="${_colorToRgba(color)}"/>';
  }
  
  static String _drawLabelsAndValues(
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    PieChartData data,
    String percentage,
    PieChartStyle style,
    PieChartSvgOptions options,
  ) {
    final items = <String>[];
    final midAngle = startAngle + (sweepAngle / 2);
    final isRightSide = cos(midAngle) > 0;
    
    // Determine label radius
    double labelRadius;
    if (style.labelPosition == LabelPosition.inside) {
      labelRadius = radius * 0.7;
    } else {
      labelRadius = radius + style.labelOffset;
    }
    
    // Calculate label position
    final x = center.dx + cos(midAngle) * labelRadius;
    final y = center.dy + sin(midAngle) * labelRadius;
    
    // Define text style
    final labelStyle = style.labelStyle ??
        TextStyle(
          color: style.labelPosition == LabelPosition.inside
              ? Colors.white
              : Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
    
    // Draw connector lines if outside
    if (style.labelPosition == LabelPosition.outside && options.showConnectorLines && style.showConnectorLines) {
      final innerX = center.dx + cos(midAngle) * radius;
      final innerY = center.dy + sin(midAngle) * radius;
      final outerX = center.dx + cos(midAngle) * (radius + style.labelOffset / 2);
      final outerY = center.dy + sin(midAngle) * (radius + style.labelOffset / 2);
      final endX = isRightSide ? x + 20 : x - 20;
      final endY = y;
      
      items.add(_polyline(
        [Offset(innerX, innerY), Offset(outerX, outerY), Offset(endX, endY)],
        _colorToRgba(style.connectorLineColor),
        style.connectorLineStrokeWidth,
      ));
    }
    
    // Create text content
    final textContent = options.showValues 
        ? '${data.label} ($percentage%)'
        : data.label;
    
    // Position text
    String anchor;
    double textX;
    if (style.labelPosition == LabelPosition.inside) {
      textX = x;
      anchor = 'middle';
    } else {
      textX = isRightSide ? x + 25 : x - 25;
      anchor = isRightSide ? 'start' : 'end';
    }
    
    items.add(_text(textContent, textX, y, labelStyle, anchor: anchor, dominantBaseline: 'middle'));
    
    return items.join('\n');
  }
  
  static String _drawLegend(Size size, double radius, EdgeInsets padding, List<PieChartData> data, PieChartStyle style, PieChartSvgOptions options) {
    final itemHeight = options.legendItemHeight;
    final iconSize = options.legendIconSize;
    
    final items = <String>[];
    var currentY = switch (style.legendPosition) {
      PieChartLegendPosition.right => padding.top,
      PieChartLegendPosition.bottom => padding.vertical + radius * 2 + options.legendVerticalOffset,
    };
    
    final legendLeft = switch (style.legendPosition) {
      PieChartLegendPosition.right => size.width - padding.right - 120,
      PieChartLegendPosition.bottom => padding.left,
    };
    
    for (int i = 0; i < data.length; i++) {
      final color = data[i].color ?? style.defaultColors[i % style.defaultColors.length];
      
      // Draw color box
      items.add(_rect(legendLeft, currentY + 4, iconSize, iconSize, 
        fill: _colorToRgba(color), rx: 4, ry: 4));
      
      // Draw label
      final textStyle = style.labelStyle ?? options.defaultLabelStyle ?? const TextStyle(fontSize: 12, color: Colors.black87);
      items.add(_text(data[i].label, legendLeft + iconSize + 8, currentY + 12, textStyle, 
        anchor: 'start', dominantBaseline: 'middle'));
      
      currentY += itemHeight;
    }
    
    return items.join('\n');
  }
  
  static String _drawTitle(EdgeInsets padding, PieChartStyle style, PieChartSvgOptions options, String title) {
    final textStyle = style.labelStyle ?? options.defaultTitleStyle ?? const TextStyle(fontSize: 14, color: Colors.black);
    return _text(title, padding.left, max(12.0, padding.top - 18.0), 
      textStyle.copyWith(fontWeight: FontWeight.bold), 
      anchor: 'start', dominantBaseline: 'hanging');
  }
  
  // SVG primitive helpers
  
  static String _rect(double x, double y, double w, double h, {String? fill, double rx = 0, double ry = 0}) {
    return '<rect x="$x" y="$y" width="$w" height="$h" fill="${fill ?? 'none'}" rx="$rx" ry="$ry"/>';
  }
  
  static String _circle(double cx, double cy, double r, String fill) {
    return '<circle cx="$cx" cy="$cy" r="$r" fill="$fill"/>';
  }
  
  static String _polyline(List<Offset> points, String stroke, double strokeWidth) {
    final pointsStr = points.map((p) => '${p.dx},${p.dy}').join(' ');
    return '<polyline points="$pointsStr" stroke="$stroke" stroke-width="$strokeWidth" fill="none"/>';
  }
  
  static String _text(String content, double x, double y, TextStyle style, {String anchor = 'start', String dominantBaseline = 'auto'}) {
    final fill = _colorToRgba(style.color ?? Colors.black);
    final fontSize = style.fontSize ?? 12;
    final fontWeight = style.fontWeight == FontWeight.bold || style.fontWeight == FontWeight.w500 ? 'bold' : 'normal';
    return '<text x="$x" y="$y" fill="$fill" font-size="$fontSize" font-weight="$fontWeight" text-anchor="$anchor" dominant-baseline="$dominantBaseline">$content</text>';
  }
  
  static String _colorToRgba(Color color) {
    return 'rgba(${color.red},${color.green},${color.blue},${color.alpha / 255.0})';
  }
}
