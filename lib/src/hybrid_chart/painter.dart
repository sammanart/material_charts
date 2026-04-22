import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../area_chart/models.dart' show AreaAnimationType;
import '../shared/shared_models.dart';
import 'models.dart';

/// Unified painter for rendering both area and candlestick charts
class HybridChartPainter extends CustomPainter {
  final List<HybridChartSeries> series;
  final double progress;
  final List<double> seriesAnimationProgress;
  final Map<int, double> segmentAnimationProgress;
  final HybridChartStyle style;
  final HybridChartAxisConfig axisConfig;
  final Offset? hoverPosition;
  final HybridChartType chartType;
  final double scrollOffset;
  final bool volumeBelowChart;
  final bool enableHoverPointScale;
  final double hoverPointScale;

  HybridChartPainter({
    required this.series,
    required this.progress,
    this.seriesAnimationProgress = const [],
    this.segmentAnimationProgress = const {},
    required this.style,
    required this.axisConfig,
    required this.chartType,
    this.hoverPosition,
    this.scrollOffset = 0.0,
    this.volumeBelowChart = false,
    this.enableHoverPointScale = false,
    this.hoverPointScale = 1.5,
  });

  bool get _usesStackedArea => chartType == HybridChartType.area && style.stacked;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series[0].dataPoints.isEmpty) return;

    final chartArea = Rect.fromLTWH(
      style.padding.left + axisConfig.yAxisWidth,
      style.padding.top,
      size.width - style.padding.horizontal - axisConfig.yAxisWidth,
      size.height - style.padding.vertical - axisConfig.xAxisHeight,
    );

    // If volume bars are displayed below the main chart, split the
    // available chartArea into a main plotting area and a volume area
    // using `style.volumeBarHeightRatio` as the fraction reserved for
    // the volume area at the bottom.
    Rect mainArea = chartArea;
    Rect volumeArea = chartArea;
    if (style.showVolume && volumeBelowChart) {
      final areaRatio = style.volumeAreaHeightRatio.clamp(0.0, 0.5);
      final vOffset = style.volumeBarVerticalOffset;
      // Base reserved height for volume area
      double volH = chartArea.height * areaRatio;
      // If caller requests a positive downward offset, give extra room
      // to the volume area so bars can be pushed further down. Clamp
      // volH so the main plotting area remains at least 1px high.
      if (vOffset > 0) {
        volH = (volH + vOffset).clamp(1.0, chartArea.height - 1.0);
      }
      final mainH = (chartArea.height - volH).clamp(0.0, chartArea.height);
      mainArea = Rect.fromLTWH(chartArea.left, chartArea.top, chartArea.width, mainH);
      volumeArea = Rect.fromLTWH(chartArea.left, chartArea.top + mainH, chartArea.width, volH);
    }

    // Draw overall background for the full chart area (includes volume area)
    if (style.chartAreaBackgroundColor != Colors.transparent) {
      final bgPaint = Paint()
        ..color = style.chartAreaBackgroundColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(chartArea, bgPaint);
    }

    // Draw main plotting area clipped so nothing from the hybrid chart
    // appears below the volume bars when `volumeBelowChart` is enabled.
    canvas.save();
    canvas.clipRect(mainArea);

    // Axes, grid and vertical lines are specific to the main plotting area.
    _drawAxes(canvas, mainArea);
    if (style.showGrid) _drawGrid(canvas, mainArea);
    _drawVerticalLines(canvas, mainArea);

    // Draw main chart content
    if (chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line) {
      _drawAreaChart(canvas, mainArea, skipFill: chartType != HybridChartType.area, singleSeries: chartType == HybridChartType.line);
    } else {
      _drawCandlestickChart(canvas, mainArea);
    }

    if (style.baseline?.show == true && (chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line)) {
      _drawBaseline(canvas, mainArea);
    }

    if (style.crosshair?.enabled == true && hoverPosition != null) {
      _drawCrosshairLines(canvas, mainArea);
    } else if (hoverPosition != null) {
      _drawVerticalLine(canvas, mainArea);
    }

    canvas.restore();

    // Draw key event markers and Y-axis labels relative to the main area
    if (style.showKeyEventMarkers) {
      _drawKeyEventMarkers(canvas, mainArea);
    }
    _drawYAxisLabels(canvas, mainArea);

    // Draw volume bars in their own area beneath the main plot when requested
    if (style.showVolume && volumeBelowChart) {
      canvas.save();
      canvas.clipRect(volumeArea);
      _drawVolumeBars(canvas, volumeArea);
      canvas.restore();
    } else if (style.showVolume) {
      // Legacy: draw volume inside the main plotting area
      _drawVolumeBars(canvas, mainArea);
    }

    // X-axis labels and titles should be tied to the main plotting area
    // so they remain above the volume area when `volumeBelowChart` is true.
    _drawXAxisLabels(canvas, mainArea);
    _drawAxisTitles(canvas, mainArea);

    // Draw volume tooltip on top of chart elements (so it appears above crosshair lines)
    if (style.showVolume && style.showVolumeTooltip && hoverPosition != null) {
      final volInfo = _getHoveredVolumeBarInfo(volumeBelowChart ? volumeArea : mainArea);
      if (volInfo != null) {
        _drawVolumeTooltip(canvas, volInfo, volumeBelowChart ? volumeArea : mainArea);
      }
    }

    // Draw crosshair labels last so they appear on top
    if (style.crosshair?.enabled == true && hoverPosition != null && style.crosshair!.showLabel) {
      _drawCrosshairLabels(canvas, mainArea);
    }
  }

  void _drawVolumeBars(Canvas canvas, Rect chartArea) {
    if (series.isEmpty) return;

    // We'll use the first series' data points for volume
    final dataPoints = series[0].dataPoints;
    if (dataPoints.isEmpty) return;

    final volumes = dataPoints.map((d) => d.volume ?? 0.0).toList();
    final maxVol = volumes.isEmpty ? 0.0 : volumes.reduce((a, b) => a > b ? a : b);
    if (maxVol <= 0) return;

    final slots = style.xSpanSlots ?? dataPoints.length;
    final count = min(dataPoints.length, slots);

    final availableWidth = chartArea.width;
    final slotWidth = availableWidth / (slots > 0 ? slots : 1);
    // When `volumeBelowChart` is true the provided `chartArea` already
    // represents the reserved volume area — use its full height. Otherwise
    // treat `volumeBarHeightRatio` as the fraction of the provided area.
    // Always apply `volumeBarHeightRatio` to control the maximum drawn
    // bar height inside the provided area. This lets callers decide how
    // tall bars are even when the volume area is reserved separately.
    final ratio = style.volumeBarHeightRatio.isNaN ? 0.0 : style.volumeBarHeightRatio;
    final barMaxHeight = chartArea.height * (ratio < 0.0 ? 0.0 : ratio);
    final vOffset = volumeBelowChart ? style.volumeBarVerticalOffset : 0.0;

    final paint = Paint()
      ..color = style.volumeBarColor.withValues(alpha: style.volumeBarOpacity)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final vol = volumes[i];
      if (vol <= 0) continue;

      // X position: center within slot
      final xCenter = chartArea.left + (slotWidth * i) + slotWidth / 2;
      final barWidth = min(style.volumeBarWidth, slotWidth * 0.8);

      final height = (vol / maxVol) * barMaxHeight;
      // Apply vertical offset. Positive values move bars downward, negative
      // values move them upward. Clamp so bars remain within the chartArea.
      double top = (chartArea.bottom - height) + vOffset;
      top = top.clamp(chartArea.top, chartArea.bottom - height);

      final rect = Rect.fromLTWH(xCenter - barWidth / 2, top, barWidth, height);
      canvas.drawRect(rect, paint);
    }
  }

  /// Returns hovered volume info if the hoverPosition falls on a volume bar.
  Map<String, dynamic>? _getHoveredVolumeBarInfo(Rect chartArea) {
    if (series.isEmpty) return null;
    final dataPoints = series[0].dataPoints;
    if (dataPoints.isEmpty) return null;

    final volumes = dataPoints.map((d) => d.volume ?? 0.0).toList();
    final maxVol = volumes.isEmpty ? 0.0 : volumes.reduce((a, b) => a > b ? a : b);
    if (maxVol <= 0) return null;

    final slots = style.xSpanSlots ?? dataPoints.length;
    final count = min(dataPoints.length, slots);

    final availableWidth = chartArea.width;
    final slotWidth = availableWidth / (slots > 0 ? slots : 1);
    final ratio = style.volumeBarHeightRatio.isNaN ? 0.0 : style.volumeBarHeightRatio;
    final barMaxHeight = chartArea.height * (ratio < 0.0 ? 0.0 : ratio);
    final vOffset = volumeBelowChart ? style.volumeBarVerticalOffset : 0.0;

    for (int i = 0; i < count; i++) {
      final vol = volumes[i];
      if (vol <= 0) continue;

      final xCenter = chartArea.left + (slotWidth * i) + slotWidth / 2;
      final barWidth = min(style.volumeBarWidth, slotWidth * 0.8);
      final height = (vol / maxVol) * barMaxHeight;
      double top = (chartArea.bottom - height) + vOffset;
      top = top.clamp(chartArea.top, chartArea.bottom - height);
      final rect = Rect.fromLTWH(xCenter - barWidth / 2, top, barWidth, height);
      if (hoverPosition != null && rect.contains(hoverPosition!)) {
        return {'rect': rect, 'vol': vol, 'xCenter': xCenter, 'top': top, 'barWidth': barWidth};
      }
    }

    return null;
  }

  void _drawVolumeTooltip(Canvas canvas, Map<String, dynamic> info, Rect chartArea) {
    final vol = info['vol'] as double;
    final xCenter = info['xCenter'] as double;
    final top = info['top'] as double;
    // final barWidth = info['barWidth'] as double; (unused)

    final volText = vol % 1 == 0 ? vol.toInt().toString() : _formatNumber(vol);
    final textStyle = TextStyle(color: style.volumeTooltipTextColor, fontSize: 12);
    final span = TextSpan(text: volText, style: textStyle);
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();

    final tooltipPaddingH = 6.0;
    final tooltipPaddingV = 4.0;
    double tx = xCenter - tp.width / 2 - tooltipPaddingH;
    double tw = tp.width + tooltipPaddingH * 2;
    if (tx < chartArea.left) tx = chartArea.left + 2;
    if (tx + tw > chartArea.right) tx = chartArea.right - tw - 2;
    final ty = (top - tp.height - tooltipPaddingV * 2 - 6).clamp(chartArea.top, chartArea.bottom - tp.height - tooltipPaddingV * 2);

    final tooltipRect = Rect.fromLTWH(tx, ty, tw, tp.height + tooltipPaddingV * 2);
    final tooltipPaint = Paint()..color = style.volumeTooltipBackgroundColor.withOpacity(style.volumeTooltipOpacity.clamp(0.0, 1.0));
    canvas.drawRRect(RRect.fromRectAndRadius(tooltipRect, Radius.circular(style.volumeTooltipBorderRadius)), tooltipPaint);
    tp.paint(canvas, Offset(tooltipRect.left + tooltipPaddingH, tooltipRect.top + tooltipPaddingV));
  }

  void _drawAreaChart(Canvas canvas, Rect chartArea, {bool skipFill = false, bool singleSeries = false}) {
    final seriesIndices = singleSeries ? <int>[0] : (_usesStackedArea ? List<int>.generate(series.length, (i) => series.length - 1 - i) : List<int>.generate(series.length, (i) => i));
    for (final seriesIdx in seriesIndices) {
      final seriesData = series[seriesIdx];
      final color = seriesData.color ?? style.colors[seriesIdx % style.colors.length];
      final topFill = color.withValues(alpha: style.areaFillOpacityTop.clamp(0.0, 1.0));
      final bottomFill = color.withValues(alpha: style.areaFillOpacityBottom.clamp(0.0, 1.0));

      final seriesProgress = seriesAnimationProgress.isNotEmpty && seriesIdx < seriesAnimationProgress.length ? seriesAnimationProgress[seriesIdx] : progress;

      final segmentGroups = <int, List<int>>{};
      for (int pointIdx = 0; pointIdx < seriesData.dataPoints.length; pointIdx++) {
        final point = seriesData.dataPoints[pointIdx];
        final segmentOrder = point.segmentAnimationOrder;
        if (!segmentGroups.containsKey(segmentOrder)) {
          segmentGroups[segmentOrder] = [];
        }
        segmentGroups[segmentOrder]!.add(pointIdx);
      }

      final sortedOrders = segmentGroups.keys.toList()..sort();

      for (final segmentOrder in sortedOrders) {
        final indices = segmentGroups[segmentOrder]!;
        if (indices.isEmpty) continue;

        final contiguousRuns = _splitContiguousRuns(indices);

        final hasSegmentConfig = style.segmentAnimationConfigs.containsKey(segmentOrder);

        for (final runIndices in contiguousRuns) {
          if (runIndices.isEmpty) continue;

          if (hasSegmentConfig) {
            final segmentProgress = segmentAnimationProgress[segmentOrder] ?? 0.0;
            if (segmentProgress > 0.001) {
              _drawSegmentGroup(
                canvas,
                chartArea,
                seriesIdx,
                seriesData,
                runIndices,
                color,
                topFill,
                bottomFill,
                segmentProgress,
                segmentOrder,
                skipFill: skipFill,
              );
            }
          } else {
            if (seriesProgress > 0.0) {
              _drawSegmentGroup(
                canvas,
                chartArea,
                seriesIdx,
                seriesData,
                runIndices,
                color,
                topFill,
                bottomFill,
                seriesProgress,
                segmentOrder,
                useSeriesAnimation: true,
                skipFill: skipFill,
              );
            }
          }
        }
      }
    }
  }

  List<List<int>> _splitContiguousRuns(List<int> indices) {
    if (indices.isEmpty) return const [];

    final sorted = List<int>.from(indices)..sort();
    final runs = <List<int>>[];
    var currentRun = <int>[sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      if (curr == prev + 1) {
        currentRun.add(curr);
      } else {
        runs.add(currentRun);
        currentRun = <int>[curr];
      }
    }

    runs.add(currentRun);
    return runs;
  }

  void _drawSegmentGroup(
    Canvas canvas,
    Rect chartArea,
    int seriesIndex,
    HybridChartSeries seriesData,
    List<int> indices,
    Color color,
    Color topFill,
    Color bottomFill,
    double progress,
    int segmentOrder, {
    bool useSeriesAnimation = false,
    bool skipFill = false,
  }) {
    final points = _getAreaChartPoints(chartArea, seriesData, seriesIndex: seriesIndex);
    if (points.isEmpty || indices.isEmpty) return;

    int startIdx = indices.first.clamp(0, points.length - 1);
    int endIdx = indices.last.clamp(0, points.length - 1);

    if (!useSeriesAnimation && startIdx > 0) {
      startIdx = (startIdx - 1).clamp(0, points.length - 1);
    }

    if (startIdx >= points.length || endIdx >= points.length || startIdx > endIdx) return;

    final segmentPoints = points.sublist(startIdx, endIdx + 1);
    final lowerBoundaryPoints = _usesStackedArea ? _getAreaChartLowerBoundaryPoints(chartArea, seriesIndex).sublist(startIdx, endIdx + 1) : null;
    if (segmentPoints.length < 2) return;

    double opacity = 1.0;
    double offsetY = 0.0;
    bool shouldDrawProgressively = true;

    if (useSeriesAnimation) {
      final animConfig = seriesData.animationConfig;
      final animType = animConfig?.animationType ?? style.defaultAnimationType;
      if (animType == AreaAnimationType.fadeIn) {
        opacity = progress;
        shouldDrawProgressively = false;
      } else if (animType == AreaAnimationType.slideUp) {
        opacity = progress;
        offsetY = (1.0 - progress) * 20.0;
        shouldDrawProgressively = false;
      }
    } else {
      final segmentConfig = style.segmentAnimationConfigs[segmentOrder];
      if (segmentConfig != null) {
        final animType = segmentConfig.animationType;
        if (animType == SegmentAnimationType.fadeIn) {
          opacity = progress;
          shouldDrawProgressively = false;
        } else if (animType == SegmentAnimationType.slideUp) {
          opacity = progress;
          offsetY = (1.0 - progress) * 20.0;
          shouldDrawProgressively = false;
        }
      }
    }

    if (shouldDrawProgressively && progress <= 0.0) return;
    if (!shouldDrawProgressively && opacity <= 0.0) return;

    canvas.save();
    if (offsetY != 0.0) {
      canvas.translate(0, offsetY);
    }

    if (!skipFill && segmentPoints.length >= 2) {
      _drawAreaFill(canvas, chartArea, segmentPoints, lowerBoundaryPoints, topFill, bottomFill, progress, opacity, shouldDrawProgressively);
    }

    _drawAreaLine(canvas, segmentPoints, seriesData, color, progress, opacity, shouldDrawProgressively);

    if (seriesData.showPoints ?? style.showPoints) {
      final pointSize = seriesData.pointSize ?? style.defaultPointSize;
      int? hoverIndex;
      if (enableHoverPointScale && hoverPosition != null) {
        final hitRadius = max(8.0, pointSize / 2 + 6.0);
        hoverIndex = _getHoveredPointIndex(segmentPoints, hoverPosition!, hitRadius);
      }
      _drawAreaPoints(
        canvas,
        segmentPoints,
        color,
        progress: progress,
        opacity: opacity,
        shouldDrawProgressively: shouldDrawProgressively,
        hasConnectingPoint: !useSeriesAnimation && startIdx > 0,
        pointSize: pointSize,
        hoverIndex: hoverIndex,
        hoverScale: enableHoverPointScale ? hoverPointScale : 1.0,
      );
    }

    canvas.restore();
  }

  void _drawCandlestickChart(Canvas canvas, Rect chartArea) {
    if (series.isEmpty) return;
    final seriesData = series[0]; // Candlestick typically has one series
    // Use `close` as a fallback when high/low are nullable (models allow nulls).
    final high = seriesData.dataPoints.map((d) => d.high ?? d.close).reduce(max);
    final lowest = seriesData.dataPoints.map((d) => d.low ?? d.close).reduce(min);
    final low = style.forceYAxisFromZero ? 0.0 : lowest;
    final maxOffset = style.yAxisMaxOffset < 0 ? 0.0 : style.yAxisMaxOffset;
    final range = (high + maxOffset) - low;

    // Limit candlesticks based on xSpanSlots
    final slots = style.xSpanSlots ?? seriesData.dataPoints.length;
    final maxCandles = min(seriesData.dataPoints.length, slots);
    final progressCount = (maxCandles * progress).floor();

    for (int i = 0; i < progressCount; i++) {
      final data = seriesData.dataPoints[i];

      final candleX = _getCandleX(i, chartArea, seriesData.dataPoints.length);
      final effectiveWidth = _getEffectiveCandleWidth(chartArea, seriesData.dataPoints.length);
      final openVal = data.open ?? data.close;
      final highVal = data.high ?? data.close;
      final lowVal = data.low ?? data.close;

      final openY = chartArea.bottom - ((openVal - low) / range * chartArea.height);
      final closeY = chartArea.bottom - ((data.close - low) / range * chartArea.height);
      final highY = chartArea.bottom - ((highVal - low) / range * chartArea.height);
      final lowY = chartArea.bottom - ((lowVal - low) / range * chartArea.height);

      final color = data.isBullish ? style.bullishColor : style.bearishColor;

      // Draw wick
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = style.wickWidth;
      canvas.drawLine(Offset(candleX + effectiveWidth / 2, highY), Offset(candleX + effectiveWidth / 2, lowY), wickPaint);

      // Draw body
      final bodyRect = Rect.fromLTRB(
        candleX,
        min(openY, closeY),
        candleX + effectiveWidth,
        max(openY, closeY),
      );
      final bodyPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawRect(bodyRect, bodyPaint);
    }
  }

  void _drawAreaFill(
    Canvas canvas,
    Rect chartArea,
    List<Offset> points,
    List<Offset>? lowerBoundaryPoints,
    Color topColor,
    Color bottomColor,
    double progress,
    double opacity,
    bool shouldDrawProgressively,
  ) {
    if (points.isEmpty) return;

    final path = Path();
    final lowerPoints = lowerBoundaryPoints;
    final startY = lowerPoints?.first.dy ?? chartArea.bottom;
    final endY = lowerPoints?.last.dy ?? chartArea.bottom;

    path.moveTo(points.first.dx, startY);
    path.lineTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    path.lineTo(points.last.dx, endY);
    if (lowerPoints != null) {
      for (int i = lowerPoints.length - 2; i >= 0; i--) {
        path.lineTo(lowerPoints[i].dx, lowerPoints[i].dy);
      }
    }
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          topColor.withValues(alpha: opacity * topColor.a),
          bottomColor.withValues(alpha: opacity * bottomColor.a),
        ],
      ).createShader(chartArea);

    if (shouldDrawProgressively) {
      if (progress <= 0.0) return;
      if (progress >= 1.0) {
        canvas.drawPath(path, paint);
        return;
      }

      final startX = points.first.dx;
      final endX = points.last.dx;
      final revealX = startX + (endX - startX) * progress;

      canvas.save();
      canvas.clipRect(Rect.fromLTRB(startX, chartArea.top, revealX, chartArea.bottom));
      canvas.drawPath(path, paint);
      canvas.restore();
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawAreaLine(
    Canvas canvas,
    List<Offset> points,
    HybridChartSeries seriesData,
    Color color,
    double progress,
    double opacity,
    bool shouldDrawProgressively,
  ) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = seriesData.lineWidth ?? style.defaultLineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    if (shouldDrawProgressively) {
      final pathMetrics = path.computeMetrics().toList();
      if (pathMetrics.isEmpty) return;
      final metric = pathMetrics.first;
      final animatedPath = metric.extractPath(0.0, metric.length * progress);
      canvas.drawPath(animatedPath, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawAreaPoints(
    Canvas canvas,
    List<Offset> points,
    Color color, {
    required double progress,
    required double opacity,
    required bool shouldDrawProgressively,
    required bool hasConnectingPoint,
    required double pointSize,
    int? hoverIndex,
    double hoverScale = 1.0,
  }) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final safeScale = hoverScale <= 0 ? 1.0 : hoverScale;
    final baseRadius = pointSize / 2;

    int pointsToDraw;
    if (shouldDrawProgressively) {
      pointsToDraw = (points.length * progress).floor();
      pointsToDraw = pointsToDraw.clamp(0, points.length);
    } else {
      pointsToDraw = points.length;
    }

    final startIndex = hasConnectingPoint ? 1 : 0;

    for (int i = startIndex; i < pointsToDraw; i++) {
      final point = points[i];
      final isHovered = hoverIndex != null && hoverIndex == i;
      final radius = isHovered ? baseRadius * safeScale : baseRadius;
      canvas.drawCircle(point, radius, paint);
    }
  }

  int? _getHoveredPointIndex(List<Offset> points, Offset hover, double hitRadius) {
    final hitRadiusSq = hitRadius * hitRadius;
    for (int i = 0; i < points.length; i++) {
      final dx = points[i].dx - hover.dx;
      final dy = points[i].dy - hover.dy;
      if ((dx * dx + dy * dy) <= hitRadiusSq) {
        return i;
      }
    }
    return null;
  }

  List<Offset> _getAreaChartPoints(Rect chartArea, HybridChartSeries seriesData, {int? seriesIndex}) {
    if (seriesData.dataPoints.isEmpty) return [];

    final resolvedSeriesIndex = seriesIndex ?? series.indexOf(seriesData);
    if (resolvedSeriesIndex == -1) return [];

    final dataPoints = seriesData.dataPoints;
    final count = _getRenderedPointCount(seriesData);

    return List.generate(count, (i) {
      final x = _getXCoordinate(chartArea, i, dataPoints.length);
      final value = _usesStackedArea ? _getStackedValue(resolvedSeriesIndex, i) : dataPoints[i].value;
      final y = _mapAreaValueToY(chartArea, value);
      return Offset(x, y);
    });
  }

  List<Offset> _getAreaChartLowerBoundaryPoints(Rect chartArea, int seriesIndex) {
    final seriesData = series[seriesIndex];
    final count = _getRenderedPointCount(seriesData);
    return List.generate(count, (i) {
      final x = _getXCoordinate(chartArea, i, seriesData.dataPoints.length);
      final y = _mapAreaValueToY(chartArea, _getStackedValue(seriesIndex + 1, i));
      return Offset(x, y);
    });
  }

  int _getRenderedPointCount(HybridChartSeries seriesData) {
    final slots = style.xSpanSlots;
    return slots == null ? seriesData.dataPoints.length : min(seriesData.dataPoints.length, slots);
  }

  double _getStackedValue(int startSeriesIndex, int pointIndex) {
    double total = 0.0;
    for (int i = startSeriesIndex; i < series.length; i++) {
      final seriesData = series[i];
      if (pointIndex < _getRenderedPointCount(seriesData)) {
        total += seriesData.dataPoints[pointIndex].value;
      }
    }
    return total;
  }

  List<double> _collectAreaVisibleValues() {
    if (!_usesStackedArea) {
      return series.expand((seriesData) {
        final count = _getRenderedPointCount(seriesData);
        return seriesData.dataPoints.take(count).map((point) => point.value);
      }).toList();
    }

    final values = <double>[0.0];
    final maxCount = series.fold<int>(0, (currentMax, seriesData) => max(currentMax, _getRenderedPointCount(seriesData)));

    for (int pointIndex = 0; pointIndex < maxCount; pointIndex++) {
      double cumulative = 0.0;
      values.add(cumulative);
      for (int seriesIndex = series.length - 1; seriesIndex >= 0; seriesIndex--) {
        final seriesData = series[seriesIndex];
        if (pointIndex < _getRenderedPointCount(seriesData)) {
          cumulative += seriesData.dataPoints[pointIndex].value;
          values.add(cumulative);
        }
      }
    }

    return values;
  }

  double _getAreaMinValue() {
    if (style.forceYAxisFromZero) return 0.0;
    final values = _collectAreaVisibleValues();
    return values.isEmpty ? 0.0 : values.reduce(min);
  }

  double _getAreaMaxValue() {
    final values = _collectAreaVisibleValues();
    final maxOffset = style.yAxisMaxOffset < 0 ? 0.0 : style.yAxisMaxOffset;
    return (values.isEmpty ? 0.0 : values.reduce(max)) + maxOffset;
  }

  double _mapAreaValueToY(Rect chartArea, double value) {
    final minValue = _getAreaMinValue();
    final maxValue = _getAreaMaxValue();
    final valueRange = maxValue - minValue;
    if (valueRange == 0) {
      return chartArea.top + chartArea.height / 2;
    }
    final normalizedValue = (value - minValue) / valueRange;
    return chartArea.bottom - (normalizedValue * chartArea.height);
  }

  double _getXCoordinate(Rect chartArea, int index, int totalPoints) {
    // Calculate X position based on xSpanSlots if defined
    final slots = style.xSpanSlots ?? totalPoints;
    final denom = (slots - 1) <= 0 ? 1 : (slots - 1);
    return chartArea.left + (chartArea.width / denom) * index;
  }

  double _getCandleX(int index, Rect chartArea, int dataPointCount) {
    // Calculate width per candle using xSpanSlots if defined
    final slots = style.xSpanSlots ?? dataPointCount;
    final availableWidth = chartArea.width;
    final candleSpacing = availableWidth / (slots > 0 ? slots : 1);
    // Use style.spacing to reserve fraction of each slot as spacing between candles.
    final effectiveWidth = min(style.candleWidth, candleSpacing * (1.0 - (style.spacing.clamp(0.0, 0.9))));
    final candleX = chartArea.left + (candleSpacing * index) + (candleSpacing - effectiveWidth) / 2;
    return candleX;
  }

  double _getEffectiveCandleWidth(Rect chartArea, int dataPointCount) {
    final slots = style.xSpanSlots ?? dataPointCount;
    final availableWidth = chartArea.width;
    final slotWidth = availableWidth / (slots > 0 ? slots : 1);
    return min(style.candleWidth, slotWidth * 0.8);
  }

  /// Calculate Y pixel position from a value, accounting for chart type and offset settings
  double _valueToYPixel(double value, Rect chartArea, HybridChartSeries seriesData) {
    if (chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line) {
      return _mapAreaValueToY(chartArea, value);
    } else {
      // Candlestick scaling (use `close` as fallback when OHLC are nullable)
      final high = seriesData.dataPoints.map((d) => d.high ?? d.close).reduce(max);
      final lowest = seriesData.dataPoints.map((d) => d.low ?? d.close).reduce(min);
      final low = style.forceYAxisFromZero ? 0.0 : lowest;
      final maxOffset = style.yAxisMaxOffset < 0 ? 0.0 : style.yAxisMaxOffset;
      final range = (high + maxOffset) - low;
      return chartArea.bottom - ((value - low) / range * chartArea.height);
    }
  }

  /// Format numbers for display on Y axis and crosshair labels.
  /// If the value has no fractional part (e.g. 123.00) show as integer `123`.
  String _formatNumber(double v) {
    final s = v.toStringAsFixed(2);
    if (s.endsWith('.00')) return v.toInt().toString();
    return s;
  }

  void _drawKeyEventMarkers(Canvas canvas, Rect chartArea) {
    final config = style.keyEventMarkerConfig ?? const KeyEventMarkerConfig();

    for (int seriesIdx = 0; seriesIdx < series.length; seriesIdx++) {
      final seriesData = series[seriesIdx];

      // Determine how many data points to process based on chart type and xSpanSlots
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

        Offset markerOffset;

        if (chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line) {
          final points = _getAreaChartPoints(chartArea, seriesData);
          if (i >= points.length) continue;
          markerOffset = Offset(points[i].dx, points[i].dy - verticalOffset);
        } else {
          // Use data.high (or fallback to close) for marker position, properly scaled with offset
          final markerY = _valueToYPixel(data.high ?? data.close, chartArea, seriesData);
          final candleX = _getCandleX(i, chartArea, seriesData.dataPoints.length);
          final effWidth = _getEffectiveCandleWidth(chartArea, seriesData.dataPoints.length);
          markerOffset = Offset(candleX + effWidth / 2, markerY - verticalOffset);
        }

        // Draw marker
        final markerPaint = Paint()
          ..color = markerColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(markerOffset, markerSize / 2, markerPaint);
      }
    }
  }

  void _drawVerticalLine(Canvas canvas, Rect chartArea) {
    final paint = Paint()
      ..color = style.verticalLineColor
      ..strokeWidth = style.verticalLineWidth;

    canvas.drawLine(
      Offset(hoverPosition!.dx, chartArea.top),
      Offset(hoverPosition!.dx, chartArea.bottom),
      paint,
    );
  }

  /// Draws the crosshair lines (vertical and horizontal).
  void _drawCrosshairLines(Canvas canvas, Rect chartArea) {
    if (hoverPosition == null || style.crosshair == null) return;

    final cfg = style.crosshair!;
    final paint = Paint()
      ..color = cfg.lineColor
      ..strokeWidth = cfg.lineWidth;

    // Draw based on singleCrosshair flag and orientation
    if (style.singleCrosshair == true) {
      // Only one line: orientation chooses which
      if (style.singleCrosshairOrientation == SingleCrosshairOrientation.horizontal) {
        // Horizontal only
        canvas.drawLine(
          Offset(chartArea.left, hoverPosition!.dy),
          Offset(chartArea.right, hoverPosition!.dy),
          paint,
        );
      } else {
        // Vertical only
        canvas.drawLine(
          Offset(hoverPosition!.dx, chartArea.top),
          Offset(hoverPosition!.dx, chartArea.bottom),
          paint,
        );
      }
    } else {
      // Full crosshair: draw both
      canvas.drawLine(
        Offset(hoverPosition!.dx, chartArea.top),
        Offset(hoverPosition!.dx, chartArea.bottom),
        paint,
      );
      canvas.drawLine(
        Offset(chartArea.left, hoverPosition!.dy),
        Offset(chartArea.right, hoverPosition!.dy),
        paint,
      );
    }
  }

  /// Draws labels for crosshair (Y value and X label if available).
  void _drawCrosshairLabels(Canvas canvas, Rect chartArea) {
    if (hoverPosition == null || style.crosshair == null) return;

    final cfg = style.crosshair!;
    // Use the same text style as axis labels for consistency
    final baseTextStyle = style.labelStyle ?? const TextStyle(fontSize: 12, color: Colors.grey);
    final textStyle = cfg.labelStyle ?? baseTextStyle;
    // Determine background color/paint for labels so X label can still use it when Y label is omitted
    Color bgColor = cfg.labelBackgroundColor ?? style.backgroundColor;
    if (textStyle.backgroundColor != null) {
      bgColor = textStyle.backgroundColor!;
    }

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;

    // Y-axis value label
    // Show Y label when not using singleCrosshair (full crosshair),
    // or when singleCrosshair is horizontal (we place the label at the right next to the horizontal line).
    double yVal = 0.0;
    if (!style.singleCrosshair || style.singleCrosshairOrientation == SingleCrosshairOrientation.horizontal) {
      if ((chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line) && series.isNotEmpty) {
        // For area chart, calculate Y value from the chart area
        final minY = _getAreaMinValue();
        final maxY = _getAreaMaxValue();
        final normalizedY = ((chartArea.bottom - hoverPosition!.dy) / chartArea.height).clamp(0.0, 1.0);
        yVal = minY + (normalizedY * (maxY - minY));
      } else if (chartType == HybridChartType.candlestick && series.isNotEmpty) {
        // For candlestick chart, use close price or estimate from height
        final minY = style.forceYAxisFromZero ? 0.0 : series.expand((s) => s.dataPoints.map((d) => d.low ?? d.close)).reduce((a, b) => a < b ? a : b);
        final maxOffset = style.yAxisMaxOffset < 0 ? 0.0 : style.yAxisMaxOffset;
        final maxY = series.expand((s) => s.dataPoints.map((d) => d.high ?? d.close)).reduce((a, b) => a > b ? a : b) + maxOffset;
        final normalizedY = ((chartArea.bottom - hoverPosition!.dy) / chartArea.height).clamp(0.0, 1.0);
        yVal = minY + (normalizedY * (maxY - minY));
      }
      final yText = _formatNumber(yVal);
      final ySpan = TextSpan(text: yText, style: textStyle);
      final yPainter = TextPainter(text: ySpan, textDirection: TextDirection.ltr)..layout();

      // Position: for horizontal single crosshair place label on the same
      // side as the configured Y axis (left/right). Otherwise place next
      // to the configured Y axis side as before.
      final yLabelX = (style.singleCrosshair == true && style.singleCrosshairOrientation == SingleCrosshairOrientation.horizontal) ? (axisConfig.yAxisPosition == YAxisPosition.left ? chartArea.left - yPainter.width - style.yAxisLabelGap - 4 : chartArea.right + style.yAxisLabelGap) : (axisConfig.yAxisPosition == YAxisPosition.right ? chartArea.right + style.yAxisLabelGap : chartArea.left - yPainter.width - style.yAxisLabelGap - 4);

      final yRect = Rect.fromLTWH(
        yLabelX,
        (hoverPosition!.dy - yPainter.height / 2).clamp(chartArea.top, chartArea.bottom - yPainter.height),
        yPainter.width + 4,
        yPainter.height + 2,
      );

      canvas.drawRect(yRect, bgPaint);
      yPainter.paint(canvas, Offset(yRect.left + 2, yRect.top + 1));
    }

    // X-axis label from nearest index
    // Draw bottom X label when not using singleCrosshair (full crosshair),
    // or when singleCrosshair orientation is vertical (keep legacy bottom label for vertical single crosshair).
    if ((!style.singleCrosshair || style.singleCrosshairOrientation == SingleCrosshairOrientation.vertical) && series.isNotEmpty && series.first.dataPoints.isNotEmpty) {
      final rawCount = series.first.dataPoints.length;
      final slots = style.xSpanSlots ?? rawCount;
      final count = min(rawCount, slots);
      final denom = (slots - 1) <= 0 ? 1 : (slots - 1);

      final t = ((hoverPosition!.dx - chartArea.left) / chartArea.width).clamp(0.0, 1.0);
      final slotIdx = (t * denom).round();
      final idx = slotIdx.clamp(0, count - 1);
      final label = series.first.dataPoints[idx].label;

      // Only display X-axis crosshair label when it's non-null and non-empty
      if (label.trim().isNotEmpty) {
        final xSpan = TextSpan(text: label, style: textStyle);
        final xPainter = TextPainter(text: xSpan, textDirection: TextDirection.ltr)..layout();

        final xY = axisConfig.xAxisPosition == XAxisPosition.top ? (chartArea.top - xPainter.height - style.xAxisLabelGap) : (chartArea.bottom + style.xAxisLabelGap);
        final xRect = Rect.fromLTWH(
          (hoverPosition!.dx - xPainter.width / 2).clamp(chartArea.left, chartArea.right - xPainter.width),
          xY,
          xPainter.width + 4,
          xPainter.height + 2,
        );

        canvas.drawRect(xRect, bgPaint);
        xPainter.paint(canvas, Offset(xRect.left + 2, xRect.top + 1));
      }
    }
  }

  void _drawAxes(Canvas canvas, Rect chartArea) {
    // Y-axis with configurable color, stroke width, and opacity
    final yAxisPaint = Paint()
      ..color = style.yAxisColor.withValues(alpha: style.yAxisOpacity)
      ..strokeWidth = style.yAxisStrokeWidth;

    // Choose X position for Y-axis based on configured position (left/right)
    final double yAxisX = axisConfig.yAxisPosition == YAxisPosition.right ? chartArea.right : chartArea.left;
    final double yAxisStart = chartArea.top + (axisConfig.xAxisPosition == XAxisPosition.top ? style.xAxisStrokeWidth / 2 : 0.0);
    final double yAxisEnd = chartArea.bottom - (axisConfig.xAxisPosition == XAxisPosition.bottom ? style.xAxisStrokeWidth / 2 : 0.0);
    canvas.drawLine(
      Offset(yAxisX, yAxisStart),
      Offset(yAxisX, yAxisEnd),
      yAxisPaint,
    );

    // X-axis with configurable color, stroke width, and opacity
    final xAxisPaint = Paint()
      ..color = style.xAxisColor.withValues(alpha: style.xAxisOpacity)
      ..strokeWidth = style.xAxisStrokeWidth;

    final double xAxisYPos = axisConfig.xAxisPosition == XAxisPosition.top ? chartArea.top : chartArea.bottom;
    canvas.drawLine(
      Offset(chartArea.left, xAxisYPos),
      Offset(chartArea.right, xAxisYPos),
      xAxisPaint,
    );
  }

  void _drawGrid(Canvas canvas, Rect chartArea) {
    final paint = Paint()
      ..color = style.gridColor.withValues(alpha: style.gridOpacity)
      ..strokeWidth = style.gridStrokeWidth;

    // Horizontal lines
    if (style.autoHorizontalGridLines > 0) {
      for (int i = 0; i < style.autoHorizontalGridLines; i++) {
        final y = chartArea.top + (chartArea.height / style.autoHorizontalGridLines * i) + 1;
        canvas.drawLine(
          Offset(chartArea.left, y),
          Offset(chartArea.right, y),
          paint,
        );
      }
    }

    // Vertical lines - evenly spaced across the chart area using xSpanSlots if set
    if (style.autoVerticalGridLines > 0) {
      // Draw N lines, evenly spaced, skipping the very left and right edges
      final n = style.autoVerticalGridLines;
      if (n > 0) {
        for (int i = 1; i <= n; i++) {
          final x = chartArea.left + (i * chartArea.width) / (n + 1);
          canvas.drawLine(
            Offset(x, chartArea.top),
            Offset(x, chartArea.bottom),
            paint,
          );
        }
      }
    }
  }

  void _drawVerticalLines(Canvas canvas, Rect chartArea) {
    if (series.isEmpty || series[0].dataPoints.isEmpty) return;

    final dataPoints = series[0].dataPoints;
    final indicesToDraw = <int>[];

    // Add labeled positions when enabled in style, and also any data points
    // that explicitly request a vertical line via `showVerticalLine`.
    for (int i = 0; i < dataPoints.length; i++) {
      final dp = dataPoints[i];
      final labelPref = dp.labelDisplay;

      final shouldFromLabelSetting = style.showVerticalLinesAtLabels && dp.label.isNotEmpty && labelPref != HybridChartLabelDisplay.forceHide;
      final shouldForce = (labelPref == HybridChartLabelDisplay.forceDisplay) || (dp.showVerticalLine == true);

      if (shouldFromLabelSetting || shouldForce) {
        indicesToDraw.add(i);
      }
    }

    if (indicesToDraw.isEmpty) return;

    final paint = Paint()
      ..color = style.gridColor.withValues(alpha: style.gridOpacity)
      ..strokeWidth = style.gridStrokeWidth;

    for (final index in indicesToDraw) {
      if (index < 0 || index >= dataPoints.length) continue;

      double x;
      if (chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line) {
        final points = _getAreaChartPoints(chartArea, series[0]);
        if (index >= points.length) continue;
        x = points[index].dx;
      } else {
        final eff = _getEffectiveCandleWidth(chartArea, dataPoints.length);
        x = _getCandleX(index, chartArea, dataPoints.length) + eff / 2;
      }

      canvas.drawLine(
        Offset(x, chartArea.top),
        Offset(x, chartArea.bottom),
        paint,
      );
    }
  }

  /// Draws a dotted horizontal baseline at the height of the first data point value (area chart only)
  void _drawBaseline(Canvas canvas, Rect chartArea) {
    if (series.isEmpty || series[0].dataPoints.isEmpty || style.baseline == null) return;

    final config = style.baseline!;
    final firstValue = _usesStackedArea ? _getStackedValue(0, 0) : series[0].dataPoints.first.value;
    final seriesColor = series[0].color ?? style.colors.first;
    final baselineColor = config.color ?? seriesColor;

    // Calculate Y position for the first value
    final maxValue = _getAreaMaxValue();
    final minValue = _getAreaMinValue();
    final valueRange = maxValue - minValue;

    if (valueRange == 0) return;

    final normalizedValue = (firstValue - minValue) / valueRange;
    final y = chartArea.bottom - (normalizedValue * chartArea.height);

    // Create paint for the dotted line
    final paint = Paint()
      ..color = baselineColor
      ..strokeWidth = config.strokeWidth
      ..style = PaintingStyle.stroke;

    // Draw dotted line across the chart
    final path = Path();
    double startX = chartArea.left;
    final endX = chartArea.right;

    // Create dashed pattern
    final dashWidth = config.dashPattern[0];
    final dashSpace = config.dashPattern.length > 1 ? config.dashPattern[1] : dashWidth;

    while (startX < endX) {
      path.moveTo(startX, y);
      startX += dashWidth;
      if (startX > endX) startX = endX;
      path.lineTo(startX, y);
      startX += dashSpace;
    }

    canvas.drawPath(path, paint);
  }

  void _drawYAxisLabels(Canvas canvas, Rect chartArea) {
    final textStyle = style.labelStyle ?? const TextStyle(fontSize: 12, color: Colors.grey);

    // If grid lines are set to 0, skip drawing Y axis labels (but do not break chart/tooltip/crosshair)
    if (style.autoHorizontalGridLines == 0) {
      return;
    }

    // Get value range based on chart type
    double minValue, maxValue;

    if (chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line) {
      maxValue = _getAreaMaxValue();
      minValue = _getAreaMinValue();
    } else {
      final allHighs = series[0].dataPoints.map((d) => d.high ?? d.close);
      final allLows = series[0].dataPoints.map((d) => d.low ?? d.close);
      final maxOffset = style.yAxisMaxOffset < 0 ? 0.0 : style.yAxisMaxOffset;
      maxValue = (allHighs.isEmpty ? 0 : allHighs.reduce((a, b) => a > b ? a : b)) + maxOffset;
      final lowest = allLows.isEmpty ? 0 : allLows.reduce((a, b) => a < b ? a : b);
      minValue = style.forceYAxisFromZero ? 0.0 : lowest.toDouble();
    }

    final range = maxValue - minValue;

    for (int i = 0; i <= style.autoHorizontalGridLines; i++) {
      // Defensive: avoid division by zero
      if (style.autoHorizontalGridLines == 0) break;
      final value = minValue + (range * i / style.autoHorizontalGridLines);
      final y = chartArea.bottom - (i / style.autoHorizontalGridLines * chartArea.height);

      final label = axisConfig.priceFormatter?.call(value) ?? _formatNumber(value);
      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      // Position based on yAxisPosition setting
      final xPosition = axisConfig.yAxisPosition == YAxisPosition.right ? chartArea.right + style.yAxisLabelGap : chartArea.left - textPainter.width - style.yAxisLabelGap;

      textPainter.paint(
        canvas,
        Offset(xPosition, y - textPainter.height / 2),
      );
    }
  }

  void _drawXAxisLabels(Canvas canvas, Rect chartArea) {
    final textStyle = style.labelStyle ?? const TextStyle(fontSize: 12, color: Colors.grey);

    if (series.isEmpty || series[0].dataPoints.isEmpty) return;

    final dataPoints = series[0].dataPoints;

    // Determine max data points to show based on chart type and xSpanSlots
    int maxDataPoints = dataPoints.length;
    if (chartType == HybridChartType.candlestick) {
      final slots = style.xSpanSlots ?? dataPoints.length;
      maxDataPoints = min(dataPoints.length, slots);
    }

    final labelCount = min(axisConfig.dateDivisions, maxDataPoints);
    final step = max(1, (maxDataPoints / labelCount).ceil());

    // Determine indices selected by stepping
    final indicesToDraw = <int>[];
    for (int i = 0; i < maxDataPoints; i += step) {
      if (i >= maxDataPoints) break;
      indicesToDraw.add(i);
    }

    // Also include any forced-display labels
    for (int i = 0; i < maxDataPoints; i++) {
      final dp = dataPoints[i];
      if (dp.labelDisplay == HybridChartLabelDisplay.forceDisplay && !indicesToDraw.contains(i)) {
        indicesToDraw.add(i);
      }
    }

    // Paint labels for the collected indices (respecting forceHide)
    for (final i in indicesToDraw) {
      if (i < 0 || i >= maxDataPoints) continue;
      final data = dataPoints[i];
      if (data.labelDisplay == HybridChartLabelDisplay.forceHide) continue;

      final label = data.label;
      double x;
      if (chartType == HybridChartType.area || chartType == HybridChartType.multiLine || chartType == HybridChartType.line) {
        final points = _getAreaChartPoints(chartArea, series[0]);
        if (i >= points.length) continue;
        x = points[i].dx;
      } else {
        final eff = _getEffectiveCandleWidth(chartArea, dataPoints.length);
        x = _getCandleX(i, chartArea, dataPoints.length) + eff / 2;
      }

      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final labelY = axisConfig.xAxisPosition == XAxisPosition.top ? (chartArea.top - textPainter.height - style.xAxisLabelGap) : (chartArea.bottom + style.xAxisLabelGap);
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, labelY),
      );
    }
  }

  void _drawAxisTitles(Canvas canvas, Rect chartArea) {
    final textStyle = style.labelStyle ?? const TextStyle(fontSize: 12, color: Colors.grey);

    // X Axis Title — position using style.xAxisTitleGap as distance from axis line
    if (style.xAxisTitle != null && style.xAxisTitle!.isNotEmpty) {
      final titleStyle = style.xAxisTitleStyle ?? textStyle.copyWith(fontWeight: FontWeight.bold);
      final span = TextSpan(text: style.xAxisTitle, style: titleStyle);
      final tp = TextPainter(text: span, textDirection: ui.TextDirection.ltr)..layout();
      final x = chartArea.left + chartArea.width / 2 - tp.width / 2;
      final y = axisConfig.xAxisPosition == XAxisPosition.top ? (chartArea.top - style.xAxisTitleGap - tp.height) : (chartArea.bottom + style.xAxisTitleGap);
      tp.paint(canvas, Offset(x, y));
    }

    // Y Axis Title (rotated vertically)
    if (style.yAxisTitle != null && style.yAxisTitle!.isNotEmpty) {
      final titleStyle = style.yAxisTitleStyle ?? textStyle.copyWith(fontWeight: FontWeight.bold);
      final span = TextSpan(text: style.yAxisTitle, style: titleStyle);
      final tp = TextPainter(text: span, textDirection: ui.TextDirection.ltr)..layout();
      // Position near the y-axis area depending on left/right setting
      if (axisConfig.yAxisPosition == YAxisPosition.right) {
        final x = chartArea.right + style.yAxisTitleGap;
        final y = chartArea.top + chartArea.height / 2;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-pi / 2);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      } else {
        final x = chartArea.left - style.yAxisTitleGap;
        final y = chartArea.top + chartArea.height / 2;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-pi / 2);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(HybridChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.seriesAnimationProgress != seriesAnimationProgress || oldDelegate.segmentAnimationProgress != segmentAnimationProgress || oldDelegate.series != series || oldDelegate.style != style || oldDelegate.chartType != chartType || oldDelegate.hoverPosition != hoverPosition || oldDelegate.scrollOffset != scrollOffset;
  }
}
