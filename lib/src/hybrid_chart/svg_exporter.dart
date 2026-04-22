import 'dart:math';

import 'package:flutter/material.dart';

import '../shared/shared_models.dart';
import 'models.dart';

class HybridChartSvgOptions {
  final bool includeAxes;
  final bool includeAxisLabels;
  final bool includeGrid;
  final bool includeTitle;
  final bool includeLegend;
  final bool includeVolume;
  final bool includeKeyEvents;
  final String? title;
  final TextStyle? defaultAxisLabelStyle;
  final TextStyle? defaultTitleStyle;
  final TextStyle? defaultLegendStyle;

  const HybridChartSvgOptions({
    this.includeAxes = true,
    this.includeAxisLabels = true,
    this.includeGrid = true,
    this.includeTitle = true,
    this.includeLegend = true,
    this.includeVolume = true,
    this.includeKeyEvents = true,
    this.title,
    this.defaultAxisLabelStyle,
    this.defaultTitleStyle,
    this.defaultLegendStyle,
  });
}

class HybridChartSvgExporter {
  bool _usesStackedArea(HybridChartStyle style, HybridChartType chartType) => chartType == HybridChartType.area && style.stacked;

  String exportSvg({
    required Size size,
    required List<HybridChartSeries> series,
    required HybridChartStyle style,
    required HybridChartAxisConfig axisConfig,
    required HybridChartType chartType,
    HybridChartSvgOptions options = const HybridChartSvgOptions(),
  }) {
    if (series.isEmpty || series.first.dataPoints.isEmpty) {
      return _emptySvg(size);
    }

    if (chartType == HybridChartType.candlestick) {
      throw UnsupportedError('SVG export currently supports area/line charts only.');
    }

    final chartArea = Rect.fromLTWH(
      style.padding.left + axisConfig.yAxisWidth,
      style.padding.top,
      size.width - style.padding.horizontal - axisConfig.yAxisWidth,
      size.height - style.padding.vertical - axisConfig.xAxisHeight,
    );

    Rect mainArea = chartArea;
    Rect volumeArea = chartArea;
    if (style.showVolume && style.showVolumeBelowChart) {
      final areaRatio = style.volumeAreaHeightRatio.clamp(0.0, 0.5);
      final vOffset = style.volumeBarVerticalOffset;
      double volH = chartArea.height * areaRatio;
      if (vOffset > 0) {
        volH = (volH + vOffset).clamp(1.0, chartArea.height - 1.0);
      }
      final mainH = (chartArea.height - volH).clamp(0.0, chartArea.height);
      mainArea = Rect.fromLTWH(chartArea.left, chartArea.top, chartArea.width, mainH);
      volumeArea = Rect.fromLTWH(chartArea.left, chartArea.top + mainH, chartArea.width, volH);
    }

    final sb = StringBuffer();
    sb.write(_svgHeader(size));

    final defs = StringBuffer();
    final body = StringBuffer();

    if (style.chartAreaBackgroundColor != Colors.transparent) {
      body.writeln(
        _rect(
          chartArea.left,
          chartArea.top,
          chartArea.width,
          chartArea.height,
          fill: _colorToRgba(style.chartAreaBackgroundColor),
        ),
      );
    }

    if (options.includeGrid && style.showGrid) {
      body.writeln(_drawGrid(mainArea, style));
    }

    if (options.includeAxes) {
      body.writeln(_drawAxes(mainArea, style, axisConfig));
    }

    body.writeln(_drawVerticalLines(mainArea, style, series, chartType));

    final seriesOutput = _drawAreaSeries(
      mainArea,
      chartType == HybridChartType.line ? series.sublist(0, 1) : series,
      style,
      defs,
      chartType,
    );
    body.writeln(seriesOutput);

    if (options.includeKeyEvents && style.showKeyEventMarkers) {
      body.writeln(_drawKeyEventMarkers(mainArea, style, series, chartType));
    }

    if (options.includeVolume && style.showVolume) {
      body.writeln(_drawVolumeBars(style.showVolumeBelowChart ? volumeArea : mainArea, style, series));
    }

    if (options.includeAxisLabels) {
      body.writeln(_drawYAxisLabels(mainArea, style, axisConfig, series, chartType, options));
      body.writeln(_drawXAxisLabels(mainArea, style, axisConfig, series, chartType, options));
      body.writeln(_drawAxisTitles(mainArea, style, axisConfig, options));
    }

    if (options.includeTitle && options.title != null && options.title!.trim().isNotEmpty) {
      body.writeln(_drawTitle(chartArea, style, options, options.title!));
    }

    if (options.includeLegend) {
      body.writeln(_drawLegend(chartArea, style, series, options));
    }

    if (defs.isNotEmpty) {
      sb.writeln('<defs>');
      sb.writeln(defs.toString());
      sb.writeln('</defs>');
    }

    sb.writeln(body.toString());
    sb.writeln('</svg>');

    return sb.toString();
  }

  String _svgHeader(Size size) {
    return '<svg xmlns="http://www.w3.org/2000/svg" width="${size.width}" height="${size.height}" viewBox="0 0 ${size.width} ${size.height}">';
  }

  String _emptySvg(Size size) {
    return '${_svgHeader(size)}</svg>';
  }

  String _drawAxes(Rect area, HybridChartStyle style, HybridChartAxisConfig axisConfig) {
    final yAxisX = axisConfig.yAxisPosition == YAxisPosition.right ? area.right : area.left;
    final yAxisStart = area.top + (axisConfig.xAxisPosition == XAxisPosition.top ? style.xAxisStrokeWidth / 2 : 0.0);
    final yAxisEnd = area.bottom - (axisConfig.xAxisPosition == XAxisPosition.bottom ? style.xAxisStrokeWidth / 2 : 0.0);

    final xAxisY = axisConfig.xAxisPosition == XAxisPosition.top ? area.top : area.bottom;

    final yColor = _colorToRgba(style.yAxisColor, opacity: style.yAxisOpacity);
    final xColor = _colorToRgba(style.xAxisColor, opacity: style.xAxisOpacity);

    return [
      _line(yAxisX, yAxisStart, yAxisX, yAxisEnd, stroke: yColor, strokeWidth: style.yAxisStrokeWidth),
      _line(area.left, xAxisY, area.right, xAxisY, stroke: xColor, strokeWidth: style.xAxisStrokeWidth),
    ].join('\n');
  }

  String _drawGrid(Rect area, HybridChartStyle style) {
    final stroke = _colorToRgba(style.gridColor, opacity: style.gridOpacity);
    final lines = <String>[];

    if (style.autoHorizontalGridLines > 0) {
      for (int i = 0; i < style.autoHorizontalGridLines; i++) {
        final y = area.top + (area.height / style.autoHorizontalGridLines * i) + 1;
        lines.add(_line(area.left, y, area.right, y, stroke: stroke, strokeWidth: style.gridStrokeWidth));
      }
    }

    if (style.autoVerticalGridLines > 0) {
      final n = style.autoVerticalGridLines;
      for (int i = 1; i <= n; i++) {
        final x = area.left + (i * area.width) / (n + 1);
        lines.add(_line(x, area.top, x, area.bottom, stroke: stroke, strokeWidth: style.gridStrokeWidth));
      }
    }

    return lines.join('\n');
  }

  String _drawVerticalLines(
    Rect area,
    HybridChartStyle style,
    List<HybridChartSeries> series,
    HybridChartType chartType,
  ) {
    if (!style.showVerticalLinesAtLabels || series.isEmpty) {
      return '';
    }

    final dataPoints = series.first.dataPoints;
    if (dataPoints.isEmpty) return '';

    final indicesToDraw = <int>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final dp = dataPoints[i];
      final labelPref = dp.labelDisplay;
      final shouldFromLabelSetting = style.showVerticalLinesAtLabels && dp.label.isNotEmpty && labelPref != HybridChartLabelDisplay.forceHide;
      final shouldForce = (labelPref == HybridChartLabelDisplay.forceDisplay) || (dp.showVerticalLine == true);
      if (shouldFromLabelSetting || shouldForce) {
        indicesToDraw.add(i);
      }
    }

    if (indicesToDraw.isEmpty) return '';

    final stroke = _colorToRgba(style.gridColor, opacity: style.gridOpacity);
    final lines = <String>[];

    for (final index in indicesToDraw) {
      if (index < 0 || index >= dataPoints.length) continue;
      double x;
      if (chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line) {
        final points = _getAreaChartPoints(area, series, series.first, style, chartType: chartType, seriesIndex: 0);
        if (index >= points.length) continue;
        x = points[index].dx;
      } else {
        continue;
      }

      lines.add(_line(x, area.top, x, area.bottom, stroke: stroke, strokeWidth: style.gridStrokeWidth));
    }

    return lines.join('\n');
  }

  String _drawAreaSeries(
    Rect area,
    List<HybridChartSeries> series,
    HybridChartStyle style,
    StringBuffer defs,
    HybridChartType chartType,
  ) {
    final sb = StringBuffer();
    final skipFill = chartType != HybridChartType.area;
    final seriesIndices = _usesStackedArea(style, chartType) ? List<int>.generate(series.length, (i) => series.length - 1 - i) : List<int>.generate(series.length, (i) => i);
    for (final i in seriesIndices) {
      final seriesData = series[i];
      final color = seriesData.color ?? style.colors[i % style.colors.length];
      final points = _getAreaChartPoints(area, series, seriesData, style, chartType: chartType, seriesIndex: i);
      if (points.isEmpty) continue;

      if (!skipFill) {
        final gradientId = 'areaGradient_$i';
        defs.writeln(_linearGradientDef(
          gradientId,
          color.withValues(alpha: style.areaFillOpacityTop.clamp(0.0, 1.0)),
          color.withValues(alpha: style.areaFillOpacityBottom.clamp(0.0, 1.0)),
        ));
        final lowerBoundaryPoints = _usesStackedArea(style, chartType) ? _getAreaChartLowerBoundaryPoints(area, series, style, chartType, i) : null;
        final path = _areaFillPath(area, points, lowerBoundaryPoints);
        sb.writeln('<path d="$path" fill="url(#$gradientId)" stroke="none" />');
      }

      final linePath = _polylinePath(points);
      final strokeWidth = seriesData.lineWidth ?? style.defaultLineWidth;
      sb.writeln(
        '<path d="$linePath" fill="none" stroke="${_colorToRgba(color)}" stroke-width="$strokeWidth" />',
      );

      if (style.showPoints) {
        final pointSize = seriesData.pointSize ?? style.defaultPointSize;
        final radius = pointSize / 2;
        for (final p in points) {
          sb.writeln(
            '<circle cx="${p.dx}" cy="${p.dy}" r="$radius" fill="${_colorToRgba(color)}" />',
          );
        }
      }
    }
    return sb.toString();
  }

  String _drawVolumeBars(Rect area, HybridChartStyle style, List<HybridChartSeries> series) {
    if (series.isEmpty) return '';
    final dataPoints = series.first.dataPoints;
    if (dataPoints.isEmpty) return '';

    final volumes = dataPoints.map((d) => d.volume ?? 0.0).toList();
    final maxVol = volumes.isEmpty ? 0.0 : volumes.reduce((a, b) => a > b ? a : b);
    if (maxVol <= 0) return '';

    final slots = style.xSpanSlots ?? dataPoints.length;
    final count = min(dataPoints.length, slots);

    final slotWidth = area.width / (slots > 0 ? slots : 1);
    final ratio = style.volumeBarHeightRatio.isNaN ? 0.0 : style.volumeBarHeightRatio;
    final barMaxHeight = area.height * (ratio < 0.0 ? 0.0 : ratio);
    final vOffset = style.showVolumeBelowChart ? style.volumeBarVerticalOffset : 0.0;

    final fill = _colorToRgba(style.volumeBarColor, opacity: style.volumeBarOpacity);
    final rects = <String>[];

    for (int i = 0; i < count; i++) {
      final vol = volumes[i];
      if (vol <= 0) continue;
      final xCenter = area.left + (slotWidth * i) + slotWidth / 2;
      final barWidth = min(style.volumeBarWidth, slotWidth * 0.8);
      final height = (vol / maxVol) * barMaxHeight;
      double top = (area.bottom - height) + vOffset;
      top = top.clamp(area.top, area.bottom - height);

      rects.add(_rect(xCenter - barWidth / 2, top, barWidth, height, fill: fill));
    }

    return rects.join('\n');
  }

  String _drawKeyEventMarkers(
    Rect area,
    HybridChartStyle style,
    List<HybridChartSeries> series,
    HybridChartType chartType,
  ) {
    final config = style.keyEventMarkerConfig ?? const KeyEventMarkerConfig();
    final markers = <String>[];

    for (int seriesIdx = 0; seriesIdx < series.length; seriesIdx++) {
      final seriesData = series[seriesIdx];
      if (seriesData.dataPoints.isEmpty) continue;

      int maxPoints = seriesData.dataPoints.length;
      if (chartType == HybridChartType.candlestick) {
        final slots = style.xSpanSlots ?? seriesData.dataPoints.length;
        maxPoints = min(seriesData.dataPoints.length, slots);
      }

      for (int i = 0; i < maxPoints; i++) {
        final data = seriesData.dataPoints[i];
        if (data.keyEvent == null) continue;

        final keyEvent = data.keyEvent!;
        final markerColor = keyEvent.markerColor ?? config.defaultColor;
        final markerSize = keyEvent.markerSize ?? config.size;
        final verticalOffset = keyEvent.verticalOffset ?? config.verticalOffset;

        if (chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line) {
          final points = _getAreaChartPoints(area, series, seriesData, style, chartType: chartType, seriesIndex: seriesIdx);
          if (i >= points.length) continue;
          final x = points[i].dx;
          final y = points[i].dy - verticalOffset;
          markers.add('<circle cx="$x" cy="$y" r="${markerSize / 2}" fill="${_colorToRgba(markerColor)}" />');
        }
      }
    }

    return markers.join('\n');
  }

  String _drawYAxisLabels(
    Rect area,
    HybridChartStyle style,
    HybridChartAxisConfig axisConfig,
    List<HybridChartSeries> series,
    HybridChartType chartType,
    HybridChartSvgOptions options,
  ) {
    if (style.autoHorizontalGridLines == 0) return '';
    final textStyle = style.labelStyle ?? options.defaultAxisLabelStyle ?? const TextStyle(fontSize: 12, color: Colors.grey);

    double minValue;
    double maxValue;

    if (chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line) {
      final allValues = _collectVisibleValues(series, style, chartType);
      final maxOffset = style.yAxisMaxOffset < 0 ? 0.0 : style.yAxisMaxOffset;
      maxValue = (allValues.isEmpty ? 0.0 : allValues.reduce((a, b) => a > b ? a : b)) + maxOffset;
      minValue = style.forceYAxisFromZero ? 0.0 : (allValues.isEmpty ? 0.0 : allValues.reduce((a, b) => a < b ? a : b));
    } else {
      return '';
    }

    final range = maxValue - minValue;
    final labels = <String>[];
    for (int i = 0; i <= style.autoHorizontalGridLines; i++) {
      final value = minValue + (range * i / style.autoHorizontalGridLines);
      final y = area.bottom - (i / style.autoHorizontalGridLines * area.height);
      final label = axisConfig.priceFormatter?.call(value) ?? _formatNumber(value);

      final x = axisConfig.yAxisPosition == YAxisPosition.right ? area.right + style.yAxisLabelGap : area.left - style.yAxisLabelGap;
      final anchor = axisConfig.yAxisPosition == YAxisPosition.right ? 'start' : 'end';
      labels.add(_text(label, x, y, textStyle, anchor: anchor, dominantBaseline: 'middle'));
    }

    return labels.join('\n');
  }

  String _drawXAxisLabels(
    Rect area,
    HybridChartStyle style,
    HybridChartAxisConfig axisConfig,
    List<HybridChartSeries> series,
    HybridChartType chartType,
    HybridChartSvgOptions options,
  ) {
    final textStyle = style.labelStyle ?? options.defaultAxisLabelStyle ?? const TextStyle(fontSize: 12, color: Colors.grey);
    if (series.isEmpty || series.first.dataPoints.isEmpty) return '';

    final dataPoints = series.first.dataPoints;
    int maxDataPoints = dataPoints.length;
    if (chartType == HybridChartType.candlestick) {
      final slots = style.xSpanSlots ?? dataPoints.length;
      maxDataPoints = min(dataPoints.length, slots);
    }

    final labelCount = min(axisConfig.dateDivisions, maxDataPoints);
    final step = max(1, (maxDataPoints / labelCount).ceil());

    final indicesToDraw = <int>[];
    for (int i = 0; i < maxDataPoints; i += step) {
      if (i >= maxDataPoints) break;
      indicesToDraw.add(i);
    }

    for (int i = 0; i < maxDataPoints; i++) {
      final dp = dataPoints[i];
      if (dp.labelDisplay == HybridChartLabelDisplay.forceDisplay && !indicesToDraw.contains(i)) {
        indicesToDraw.add(i);
      }
    }

    final labels = <String>[];
    for (final i in indicesToDraw) {
      if (i < 0 || i >= maxDataPoints) continue;
      final data = dataPoints[i];
      if (data.labelDisplay == HybridChartLabelDisplay.forceHide) continue;

      final points = _getAreaChartPoints(area, series, series.first, style, chartType: chartType, seriesIndex: 0);
      if (i >= points.length) continue;
      final x = points[i].dx;

      final labelY = axisConfig.xAxisPosition == XAxisPosition.top ? (area.top - style.xAxisLabelGap) : (area.bottom + style.xAxisLabelGap);
      labels.add(_text(data.label, x, labelY, textStyle, anchor: 'middle', dominantBaseline: axisConfig.xAxisPosition == XAxisPosition.top ? 'auto' : 'hanging'));
    }

    return labels.join('\n');
  }

  String _drawAxisTitles(Rect area, HybridChartStyle style, HybridChartAxisConfig axisConfig, HybridChartSvgOptions options) {
    final textStyle = style.labelStyle ?? options.defaultAxisLabelStyle ?? const TextStyle(fontSize: 12, color: Colors.grey);
    final items = <String>[];

    if (style.xAxisTitle != null && style.xAxisTitle!.isNotEmpty) {
      final titleStyle = style.xAxisTitleStyle ?? textStyle.copyWith(fontWeight: FontWeight.bold);
      final x = area.left + area.width / 2;
      final y = axisConfig.xAxisPosition == XAxisPosition.top ? (area.top - style.xAxisTitleGap) : (area.bottom + style.xAxisTitleGap);
      items.add(_text(style.xAxisTitle!, x, y, titleStyle, anchor: 'middle', dominantBaseline: axisConfig.xAxisPosition == XAxisPosition.top ? 'auto' : 'hanging'));
    }

    if (style.yAxisTitle != null && style.yAxisTitle!.isNotEmpty) {
      final titleStyle = style.yAxisTitleStyle ?? textStyle.copyWith(fontWeight: FontWeight.bold);
      final x = axisConfig.yAxisPosition == YAxisPosition.right ? area.right + style.yAxisTitleGap : area.left - style.yAxisTitleGap;
      final y = area.top + area.height / 2;
      items.add(_rotatedText(style.yAxisTitle!, x, y, titleStyle, -90));
    }

    return items.join('\n');
  }

  String _drawTitle(Rect area, HybridChartStyle style, HybridChartSvgOptions options, String title) {
    final textStyle = style.labelStyle ?? options.defaultTitleStyle ?? const TextStyle(fontSize: 14, color: Colors.black);
    final y = max(12.0, area.top - 18.0);
    return _text(title, area.left, y, textStyle.copyWith(fontWeight: FontWeight.bold), anchor: 'start', dominantBaseline: 'hanging');
  }

  String _drawLegend(Rect area, HybridChartStyle style, List<HybridChartSeries> series, HybridChartSvgOptions options) {
    if (series.isEmpty) return '';
    final textStyle = style.labelStyle ?? options.defaultLegendStyle ?? const TextStyle(fontSize: 12, color: Colors.black);
    final items = <String>[];
    final startX = area.left;
    double y = max(12.0, area.top - 4.0);

    for (int i = 0; i < series.length; i++) {
      final color = series[i].color ?? style.colors[i % style.colors.length];
      final rect = _rect(startX, y - 10, 10, 10, fill: _colorToRgba(color));
      final text = _text(series[i].name, startX + 14, y, textStyle, anchor: 'start', dominantBaseline: 'middle');
      items.add(rect);
      items.add(text);
      y += 14;
    }

    return items.join('\n');
  }

  List<Offset> _getAreaChartPoints(Rect chartArea, List<HybridChartSeries> allSeries, HybridChartSeries seriesData, HybridChartStyle style, {required HybridChartType chartType, int? seriesIndex}) {
    if (seriesData.dataPoints.isEmpty) return [];

    final resolvedSeriesIndex = seriesIndex ?? allSeries.indexOf(seriesData);
    if (resolvedSeriesIndex == -1) return [];

    final dataPoints = seriesData.dataPoints;

    final slots = style.xSpanSlots ?? dataPoints.length;
    final count = dataPoints.length < slots ? dataPoints.length : slots;

    return List.generate(count, (i) {
      final x = _getXCoordinate(chartArea, i, dataPoints.length, style);
      final value = _usesStackedArea(style, chartType) ? _getStackedValue(allSeries, resolvedSeriesIndex, i, style) : dataPoints[i].value;
      final y = _mapAreaValueToY(chartArea, value, allSeries, style, chartType);
      return Offset(x, y);
    });
  }

  List<Offset> _getAreaChartLowerBoundaryPoints(
    Rect chartArea,
    List<HybridChartSeries> allSeries,
    HybridChartStyle style,
    HybridChartType chartType,
    int seriesIndex,
  ) {
    final seriesData = allSeries[seriesIndex];
    final count = _getRenderedPointCount(seriesData, style);
    return List.generate(count, (i) {
      final x = _getXCoordinate(chartArea, i, seriesData.dataPoints.length, style);
      final y = _mapAreaValueToY(chartArea, _getStackedValue(allSeries, seriesIndex + 1, i, style), allSeries, style, chartType);
      return Offset(x, y);
    });
  }

  int _getRenderedPointCount(HybridChartSeries seriesData, HybridChartStyle style) {
    final slots = style.xSpanSlots;
    return slots == null ? seriesData.dataPoints.length : min(seriesData.dataPoints.length, slots);
  }

  double _getStackedValue(List<HybridChartSeries> allSeries, int startSeriesIndex, int pointIndex, HybridChartStyle style) {
    double total = 0.0;
    for (int i = startSeriesIndex; i < allSeries.length; i++) {
      final seriesData = allSeries[i];
      if (pointIndex < _getRenderedPointCount(seriesData, style)) {
        total += seriesData.dataPoints[pointIndex].value;
      }
    }
    return total;
  }

  double _mapAreaValueToY(
    Rect chartArea,
    double value,
    List<HybridChartSeries> allSeries,
    HybridChartStyle style,
    HybridChartType chartType,
  ) {
    final visibleValues = _collectVisibleValues(allSeries, style, chartType);
    final maxOffset = style.yAxisMaxOffset < 0 ? 0.0 : style.yAxisMaxOffset;
    final maxValue = (visibleValues.isEmpty ? 0.0 : visibleValues.reduce((a, b) => a > b ? a : b)) + maxOffset;
    final minValue = style.forceYAxisFromZero ? 0.0 : (visibleValues.isEmpty ? 0.0 : visibleValues.reduce((a, b) => a < b ? a : b));
    final valueRange = maxValue - minValue;
    if (valueRange == 0) {
      return chartArea.top + chartArea.height / 2;
    }
    final normalizedValue = (value - minValue) / valueRange;
    return chartArea.bottom - (normalizedValue * chartArea.height);
  }

  double _getXCoordinate(Rect chartArea, int index, int totalPoints, HybridChartStyle style) {
    final slots = style.xSpanSlots ?? totalPoints;
    final denom = (slots - 1) <= 0 ? 1 : (slots - 1);
    return chartArea.left + (chartArea.width / denom) * index;
  }

  List<double> _collectVisibleValues(List<HybridChartSeries> allSeries, HybridChartStyle style, HybridChartType chartType) {
    if (!_usesStackedArea(style, chartType)) {
      return allSeries.expand((seriesData) {
        final count = _getRenderedPointCount(seriesData, style);
        return seriesData.dataPoints.take(count).map((point) => point.value);
      }).toList();
    }

    final values = <double>[0.0];
    final maxCount = allSeries.fold<int>(0, (currentMax, seriesData) => max(currentMax, _getRenderedPointCount(seriesData, style)));

    for (int pointIndex = 0; pointIndex < maxCount; pointIndex++) {
      double cumulative = 0.0;
      values.add(cumulative);
      for (int seriesIndex = allSeries.length - 1; seriesIndex >= 0; seriesIndex--) {
        final seriesData = allSeries[seriesIndex];
        if (pointIndex < _getRenderedPointCount(seriesData, style)) {
          cumulative += seriesData.dataPoints[pointIndex].value;
          values.add(cumulative);
        }
      }
    }

    return values;
  }

  String _areaFillPath(Rect area, List<Offset> points, List<Offset>? lowerBoundaryPoints) {
    final sb = StringBuffer();
    sb.write('M ${points.first.dx} ${lowerBoundaryPoints?.first.dy ?? area.bottom} ');
    sb.write('L ${points.first.dx} ${points.first.dy} ');
    for (int i = 1; i < points.length; i++) {
      sb.write('L ${points[i].dx} ${points[i].dy} ');
    }
    sb.write('L ${points.last.dx} ${lowerBoundaryPoints?.last.dy ?? area.bottom} ');
    if (lowerBoundaryPoints != null) {
      for (int i = lowerBoundaryPoints.length - 2; i >= 0; i--) {
        sb.write('L ${lowerBoundaryPoints[i].dx} ${lowerBoundaryPoints[i].dy} ');
      }
    }
    sb.write('Z');
    return sb.toString();
  }

  String _polylinePath(List<Offset> points) {
    final sb = StringBuffer();
    sb.write('M ${points.first.dx} ${points.first.dy} ');
    for (int i = 1; i < points.length; i++) {
      sb.write('L ${points[i].dx} ${points[i].dy} ');
    }
    return sb.toString();
  }

  String _linearGradientDef(String id, Color top, Color bottom) {
    final topHex = _colorToHex(top);
    final bottomHex = _colorToHex(bottom);
    final topOpacity = _colorOpacity(top);
    final bottomOpacity = _colorOpacity(bottom);
    return '<linearGradient id="$id" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0%" stop-color="$topHex" stop-opacity="$topOpacity" />'
        '<stop offset="100%" stop-color="$bottomHex" stop-opacity="$bottomOpacity" />'
        '</linearGradient>';
  }

  String _rect(double x, double y, double w, double h, {required String fill}) {
    return '<rect x="$x" y="$y" width="$w" height="$h" fill="$fill" />';
  }

  String _line(double x1, double y1, double x2, double y2, {required String stroke, required double strokeWidth}) {
    return '<line x1="$x1" y1="$y1" x2="$x2" y2="$y2" stroke="$stroke" stroke-width="$strokeWidth" />';
  }

  String _text(
    String value,
    double x,
    double y,
    TextStyle style, {
    String anchor = 'start',
    String dominantBaseline = 'alphabetic',
  }) {
    final fill = _colorToRgba(style.color ?? Colors.black);
    final fontSize = style.fontSize ?? 12;
    final weight = style.fontWeight == FontWeight.bold ? 'bold' : 'normal';
    final family = style.fontFamily != null ? ' font-family="${style.fontFamily}"' : '';
    return '<text x="$x" y="$y" fill="$fill" font-size="$fontSize" font-weight="$weight" text-anchor="$anchor" dominant-baseline="$dominantBaseline"$family>${_escape(value)}</text>';
  }

  String _rotatedText(String value, double x, double y, TextStyle style, double angle) {
    final fill = _colorToRgba(style.color ?? Colors.black);
    final fontSize = style.fontSize ?? 12;
    final weight = style.fontWeight == FontWeight.bold ? 'bold' : 'normal';
    final family = style.fontFamily != null ? ' font-family="${style.fontFamily}"' : '';
    return '<text x="$x" y="$y" fill="$fill" font-size="$fontSize" font-weight="$weight" text-anchor="middle" dominant-baseline="middle" transform="rotate($angle $x $y)"$family>${_escape(value)}</text>';
  }

  String _colorToRgba(Color color, {double? opacity}) {
    final a = (opacity ?? (color.alpha / 255)).clamp(0.0, 1.0);
    return 'rgba(${color.red}, ${color.green}, ${color.blue}, $a)';
  }

  String _colorToHex(Color color) {
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  String _colorOpacity(Color color) {
    return (color.alpha / 255).clamp(0.0, 1.0).toStringAsFixed(3);
  }

  String _formatNumber(double v) {
    final s = v.toStringAsFixed(2);
    if (s.endsWith('.00')) return v.toInt().toString();
    return s;
  }

  String _escape(String value) {
    return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  }
}
