import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';

import '../shared/shared_models.dart';
import 'models.dart';
import 'painter.dart';

typedef HybridChartPointValueChanged = void Function(int seriesIndex, int pointIndex, double newValue);
typedef HybridChartCandlestickValueChanged = void Function(int seriesIndex, int pointIndex, HybridCandlestickValueType valueType, double newValue);

/// Unified chart widget supporting both area and candlestick display modes
class MaterialHybridChart extends StatefulWidget {
  final List<HybridChartSeries> series;
  final double width;
  final double height;
  final HybridChartStyle style;
  final HybridChartAxisConfig axisConfig;
  final HybridChartType initialChartType;
  final VoidCallback? onAnimationComplete;
  final Color? backgroundColor;
  final String? title;
  final bool showGrid;
  final EdgeInsets padding;
  final bool showChartTypeToggle;
  final bool enablePointDrag;
  final HybridChartPointValueChanged? onPointValueChange;
  final HybridChartPointValueChanged? onPointValueChangeEnd;
  final HybridChartCandlestickValueChanged? onCandlestickValueChange;
  final HybridChartCandlestickValueChanged? onCandlestickValueChangeEnd;
  final bool enableHoverPointScale;
  final double hoverPointScale;
  final bool showPointTooltipOnHover;
  final bool showDragTooltip;
  /// When true and `style.showVolume` is enabled, render the volume bars
  /// in a separate area below the main plotting area instead of inside
  /// the main chart area.
  final bool showVolumeBelowChart;

  const MaterialHybridChart({
    super.key,
    required this.series,
    required this.width,
    required this.height,
    this.style = const HybridChartStyle(),
    this.axisConfig = const HybridChartAxisConfig(),
    this.initialChartType = HybridChartType.area,
    this.onAnimationComplete,
    this.backgroundColor,
    this.title,
    this.showGrid = true,
    this.padding = const EdgeInsets.all(16),
    this.showChartTypeToggle = false,
    this.enablePointDrag = false,
    this.onPointValueChange,
    this.onPointValueChangeEnd,
    this.onCandlestickValueChange,
    this.onCandlestickValueChangeEnd,
    this.enableHoverPointScale = false,
    this.hoverPointScale = 1.5,
    this.showPointTooltipOnHover = false,
    this.showDragTooltip = true,
    this.showVolumeBelowChart = false,
  });

  @override
  State<MaterialHybridChart> createState() => _MaterialHybridChartState();
}

class _MaterialHybridChartState extends State<MaterialHybridChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late HybridChartType _currentChartType;
  double _scrollOffset = 0.0;
  Offset? _hoverPosition;
  KeyEventData? _activeHtmlTooltip;
  Offset? _activeTooltipPosition;
  final GlobalKey _htmlTooltipKey = GlobalKey();
  Size? _activeTooltipSize;
  _PointDrag? _activeDragPoint;
  double? _lastDragValue;

  @override
  void initState() {
    super.initState();
    _currentChartType = widget.initialChartType;
    _setupAnimation();
    _scrollToEnd();
  }

  void _setupAnimation() {
    _controller = AnimationController(
      duration: widget.style.animationDuration,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.style.animationCurve),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete?.call();
        }
      });

    _controller.forward();
  }

  void _scrollToEnd() {
    if (widget.series.isEmpty) return;
    final slots = widget.style.xSpanSlots ?? widget.series[0].dataPoints.length;
    final slotWidth = widget.width / (slots > 0 ? slots : 1);
    _scrollOffset = max(0.0, slotWidth * (widget.series[0].dataPoints.length - 1) - widget.width);
  }

  void _switchChartType(HybridChartType type) {
    setState(() {
      _currentChartType = type;
      _activeHtmlTooltip = null;
      _activeTooltipPosition = null;
    });
    // Restart animation when switching chart types so the new mode animates
    try {
      _controller.reset();
      _controller.forward();
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant MaterialHybridChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If animation duration or curve changed, update controller
    if (oldWidget.style.animationDuration != widget.style.animationDuration ||
        oldWidget.style.animationCurve != widget.style.animationCurve) {
      _controller.duration = widget.style.animationDuration;
      // Recreate the animation with the new curve
      _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: widget.style.animationCurve),
      );
      try {
        _controller.reset();
        _controller.forward();
      } catch (_) {}
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_activeDragPoint != null) return;
    if (details.delta.dx.abs() < 1.0) return;
    setState(() {
      final slots = widget.style.xSpanSlots ?? widget.series[0].dataPoints.length;
      final slotWidth = widget.width / (slots > 0 ? slots : 1);
      _scrollOffset = (_scrollOffset - details.delta.dx).clamp(
        0.0,
        max(0.0, slotWidth * widget.series[0].dataPoints.length - widget.width),
      );
    });
  }

  _TooltipHit _computeActiveTooltip(Rect chartArea, Offset pointerPosition) {
    if (widget.series.isEmpty) {
      return const _TooltipHit(null, null);
    }

    // Check for point hover tooltips in area/line modes first if enabled
    if (widget.showPointTooltipOnHover && 
        (_currentChartType == HybridChartType.area || 
         _currentChartType == HybridChartType.multiLine || 
         _currentChartType == HybridChartType.line)) {
      final pointHit = _checkPointHover(chartArea, pointerPosition);
      if (pointHit != null) return pointHit;
    }

    if (!widget.style.showKeyEventMarkers) {
      return const _TooltipHit(null, null);
    }

    final config = widget.style.keyEventMarkerConfig ?? const KeyEventMarkerConfig();

    for (int seriesIdx = 0; seriesIdx < widget.series.length; seriesIdx++) {
      final seriesData = widget.series[seriesIdx];

      // Determine how many data points to process based on chart type and xSpanSlots
      int maxPoints = seriesData.dataPoints.length;
      if (_currentChartType == HybridChartType.candlestick) {
        final slots = widget.style.xSpanSlots ?? seriesData.dataPoints.length;
        maxPoints = min(seriesData.dataPoints.length, slots);
      }

      for (int i = 0; i < maxPoints; i++) {
        final data = seriesData.dataPoints[i];
        if (data.keyEvent == null || !data.keyEvent!.hasHtmlContent) continue;

        final keyEvent = data.keyEvent!;
        final markerSize = keyEvent.markerSize ?? config.size;
        final verticalOffset = keyEvent.verticalOffset ?? config.verticalOffset;

        Offset markerOffset;
        if (_currentChartType == HybridChartType.area || _currentChartType == HybridChartType.multiLine || _currentChartType == HybridChartType.line) {
          final points = _getAreaChartPoints(chartArea, seriesData);
          if (i >= points.length) continue;
          markerOffset = Offset(points[i].dx, points[i].dy - verticalOffset);
        } else {
          // Use data.high (or fallback to close) for marker position, properly scaled with offset
          final markerY = _valueToYPixel(data.high ?? data.close, chartArea, seriesData);
          final candleX = _getCandleX(i, chartArea, seriesData.dataPoints.length);
          final eff = _getEffectiveCandleWidth(chartArea, seriesData.dataPoints.length);
          markerOffset = Offset(candleX + eff / 2, markerY - verticalOffset);
        }

        final hoverRadius = max(markerSize / 2, config.minHoverRadius);
        // Use rectangular hit area centered on the drawn marker but apply a
        // small upward nudge so the trigger/tooltip sits slightly above
        // the marker for easier pointer access. Reduce the nudge so the
        // trigger area and tooltip anchor remain visually close to markers.
        final dx = (pointerPosition.dx - markerOffset.dx).abs();
        final double triggerNudge = 0.0; // no nudge
        final hitY = markerOffset.dy - triggerNudge;
        final dy = (pointerPosition.dy - hitY).abs();
        if (dx <= hoverRadius && dy <= hoverRadius) {
          // Return the marker position (unshifted); the hit test used an
          // upward nudge but the tooltip anchor should sit closer to the
          // visible marker to avoid being pushed too far up.
          return _TooltipHit(keyEvent, markerOffset);
        }
      }
    }

    // If nothing matched and we're in candlestick mode, check if pointer is over a candle
    if (_currentChartType == HybridChartType.candlestick && widget.series.isNotEmpty) {
      final seriesData = widget.series[0];
      final rawCount = seriesData.dataPoints.length;
      final slots = widget.style.xSpanSlots ?? rawCount;
      final count = min(rawCount, slots);

      for (int i = 0; i < count; i++) {
        final eff = _getEffectiveCandleWidth(chartArea, seriesData.dataPoints.length);
        final candleX = _getCandleX(i, chartArea, seriesData.dataPoints.length);
        if (pointerPosition.dx >= candleX && pointerPosition.dx <= candleX + eff) {
          final data = seriesData.dataPoints[i];
          // Only show tooltip when cursor is over the candle body (between open and close)
          final openY = _valueToYPixel(data.open ?? data.close, chartArea, seriesData);
          final closeY = _valueToYPixel(data.close, chartArea, seriesData);
          final topBody = min(openY, closeY);
          final bottomBody = max(openY, closeY);
          // Add a small tolerance so very thin bodies are still hoverable
          const double bodyTolerance = 3.0;
          // Shift the trigger area up specifically for candlestick bars.
          // When `forceYAxisFromZero` is enabled the visual scaling
          // can make previous nudges feel too large; reduce the nudge
          // in that case so hit-tests and tooltip anchors align better.
          final double barTriggerNudge = 0.0; // remove upward nudge so trigger aligns with body
          final adjTop = topBody - barTriggerNudge;
          final adjBottom = bottomBody - barTriggerNudge;
          if (!(pointerPosition.dy >= adjTop - bodyTolerance && pointerPosition.dy <= adjBottom + bodyTolerance)) {
            continue;
          }
          // Build HTML similar to candlestick painter's tooltip
            final dateStr = (data.label.trim().isNotEmpty)
              ? data.label
              : DateFormat('MMM dd, yyyy').format(DateTime.now());
          final html = '''
            <div style="font-family: Arial, sans-serif; padding:6px;">
              <div style="font-weight:bold;margin-bottom:6px;">$dateStr</div>
              <div>Open: ${(data.open ?? data.close).toStringAsFixed(2)}</div>
              <div>High: ${(data.high ?? data.close).toStringAsFixed(2)}</div>
              <div>Low: ${(data.low ?? data.close).toStringAsFixed(2)}</div>
              <div>Close: ${data.close.toStringAsFixed(2)}</div>
            </div>
          ''';

          final keyEvent = KeyEventData(htmlContent: html, markerColor: widget.style.bullishColor);
          // Anchor tooltip nearer the candle body center so it doesn't
          // appear overly high when the hit-test uses an upward nudge.
          final markerCenterY = (topBody + bottomBody) / 2;
          final markerOffset = Offset(candleX + eff / 2, markerCenterY);
          return _TooltipHit(keyEvent, markerOffset);
        }
      }
    }

    return const _TooltipHit(null, null);
  }

  /// Calculate Y pixel position from a value, accounting for chart type and offset settings
  double _valueToYPixel(double value, Rect chartArea, HybridChartSeries seriesData) {
    if (_currentChartType == HybridChartType.area || _currentChartType == HybridChartType.multiLine || _currentChartType == HybridChartType.line) {
      // Area chart scaling
      final allValues = widget.series.expand((s) => s.dataPoints.map((d) => d.value));
      final maxOffset = widget.style.yAxisMaxOffset < 0 ? 0.0 : widget.style.yAxisMaxOffset;
      final maxValue = allValues.reduce((a, b) => a > b ? a : b) + maxOffset;
      final minValue = widget.style.forceYAxisFromZero ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
      final valueRange = maxValue - minValue;
      final normalizedValue = (value - minValue) / valueRange;
      return chartArea.bottom - (normalizedValue * chartArea.height);
    } else {
      // Candlestick scaling
      // Use `close` as fallback when high/low are nullable in models.
      final high = seriesData.dataPoints.map((d) => d.high ?? d.close).reduce(max);
      final lowest = seriesData.dataPoints.map((d) => d.low ?? d.close).reduce(min);
      final low = widget.style.forceYAxisFromZero ? 0.0 : lowest;
      final maxOffset = widget.style.yAxisMaxOffset < 0 ? 0.0 : widget.style.yAxisMaxOffset;
      final range = (high + maxOffset) - low;
      return chartArea.bottom - ((value - low) / range * chartArea.height);
    }
  }

  double _yPixelToValue(double y, Rect chartArea, HybridChartSeries seriesData) {
    double minValue;
    double maxValue;

    if (_currentChartType == HybridChartType.candlestick) {
      final high = seriesData.dataPoints.map((d) => d.high ?? d.close).reduce(max);
      final lowest = seriesData.dataPoints.map((d) => d.low ?? d.close).reduce(min);
      minValue = widget.style.forceYAxisFromZero ? 0.0 : lowest;
      final maxOffset = widget.style.yAxisMaxOffset < 0 ? 0.0 : widget.style.yAxisMaxOffset;
      maxValue = high + maxOffset;
    } else {
      final allValues = widget.series.expand((s) => s.dataPoints.map((d) => d.value));
      final maxOffset = widget.style.yAxisMaxOffset < 0 ? 0.0 : widget.style.yAxisMaxOffset;
      maxValue = allValues.reduce((a, b) => a > b ? a : b) + maxOffset;
      minValue = widget.style.forceYAxisFromZero ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    }

    final valueRange = maxValue - minValue;
    if (valueRange <= 0) return minValue;

    final clampedY = y.clamp(chartArea.top, chartArea.bottom) as double;
    final normalized = ((chartArea.bottom - clampedY) / chartArea.height).clamp(0.0, 1.0) as double;
    return minValue + (normalized * valueRange);
  }

  double _getCandleX(int index, Rect chartArea, int dataPointCount) {
    // Calculate width per candle using xSpanSlots if defined
    final slots = widget.style.xSpanSlots ?? dataPointCount;
    final availableWidth = chartArea.width;
    final candleSpacing = availableWidth / (slots > 0 ? slots : 1);
    final effectiveWidth = min(widget.style.candleWidth, candleSpacing * 0.8);
    final candleX = chartArea.left + (candleSpacing * index) + (candleSpacing - effectiveWidth) / 2;
    return candleX;
  }

  double _getEffectiveCandleWidth(Rect chartArea, int dataPointCount) {
    final slots = widget.style.xSpanSlots ?? dataPointCount;
    final availableWidth = chartArea.width;
    final slotWidth = availableWidth / (slots > 0 ? slots : 1);
    return min(widget.style.candleWidth, slotWidth * 0.8);
  }

  List<Offset> _getAreaChartPoints(Rect chartArea, HybridChartSeries seriesData) {
    final dataPoints = seriesData.dataPoints;
    if (dataPoints.isEmpty) return [];

    // Calculate min and max values using the 'open' field (displayed as value for area chart)
    final allValues = widget.series.expand((s) => s.dataPoints.map((d) => d.value));
    final maxOffset = widget.style.yAxisMaxOffset < 0 ? 0.0 : widget.style.yAxisMaxOffset;
    final maxValue = allValues.reduce((a, b) => a > b ? a : b) + maxOffset;
    final minValue = widget.style.forceYAxisFromZero ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    final valueRange = maxValue - minValue;

    // Use xSpanSlots if defined to spread points across total slots
    final slots = widget.style.xSpanSlots ?? dataPoints.length;
    final count = dataPoints.length < slots ? dataPoints.length : slots;

    return List.generate(count, (i) {
      final x = _getXCoordinate(chartArea, i, dataPoints.length);
      final normalizedValue = (dataPoints[i].value - minValue) / valueRange;
      final y = chartArea.bottom - (normalizedValue * chartArea.height);
      return Offset(x, y);
    });
  }

  double _getXCoordinate(Rect chartArea, int index, int totalPoints) {
    // Calculate X position based on xSpanSlots if defined
    final slots = widget.style.xSpanSlots ?? totalPoints;
    final denom = (slots - 1) <= 0 ? 1 : (slots - 1);
    return chartArea.left + (chartArea.width / denom) * index;
  }

  bool _isPointDragEnabled() {
    return widget.enablePointDrag;
  }

  _PointDrag? _hitTestPoint(Rect chartArea, Offset position) {
    if (!_isPointDragEnabled()) return null;

    for (int seriesIdx = 0; seriesIdx < widget.series.length; seriesIdx++) {
      final seriesData = widget.series[seriesIdx];

      if (_currentChartType == HybridChartType.candlestick) {
        if (seriesData.dataPoints.isEmpty) continue;
        final slots = widget.style.xSpanSlots ?? seriesData.dataPoints.length;
        final count = min(seriesData.dataPoints.length, slots);
        final eff = _getEffectiveCandleWidth(chartArea, seriesData.dataPoints.length);

        for (int i = 0; i < count; i++) {
          final candleX = _getCandleX(i, chartArea, seriesData.dataPoints.length);
          if (position.dx < candleX || position.dx > candleX + eff) continue;

          final data = seriesData.dataPoints[i];
          final openY = _valueToYPixel(data.open ?? data.close, chartArea, seriesData);
          final closeY = _valueToYPixel(data.close, chartArea, seriesData);
          final highY = _valueToYPixel(data.high ?? data.close, chartArea, seriesData);
          final lowY = _valueToYPixel(data.low ?? data.close, chartArea, seriesData);
          final topBody = min(openY, closeY);
          final bottomBody = max(openY, closeY);
          const double bodyTolerance = 6.0;
          final double lineTolerance = 6.0;
          final bool hitBody = position.dy >= topBody - bodyTolerance && position.dy <= bottomBody + bodyTolerance;
          final bool hitOpenLine = (position.dy - openY).abs() <= lineTolerance;
          final bool hitCloseLine = (position.dy - closeY).abs() <= lineTolerance;
          final bool hitHighLine = (position.dy - highY).abs() <= lineTolerance;
          final bool hitLowLine = (position.dy - lowY).abs() <= lineTolerance;
          if (hitHighLine) {
            return _PointDrag(seriesIdx, i, HybridCandlestickValueType.high);
          }
          if (hitLowLine) {
            return _PointDrag(seriesIdx, i, HybridCandlestickValueType.low);
          }
          if (hitOpenLine) {
            return _PointDrag(seriesIdx, i, HybridCandlestickValueType.open);
          }
          if (hitCloseLine) {
            return _PointDrag(seriesIdx, i, HybridCandlestickValueType.close);
          }
          if (hitBody) {
            final target = (position.dy - openY).abs() <= (position.dy - closeY).abs()
                ? HybridCandlestickValueType.open
                : HybridCandlestickValueType.close;
            return _PointDrag(seriesIdx, i, target);
          }
        }

        continue;
      }

      final points = _getAreaChartPoints(chartArea, seriesData);
      if (points.isEmpty) continue;

      final pointSize = seriesData.pointSize ?? widget.style.defaultPointSize;
      final hitRadius = max(8.0, pointSize + 6.0);

      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final dx = (position.dx - p.dx).abs();
        final dy = (position.dy - p.dy).abs();
        if (dx <= hitRadius && dy <= hitRadius) {
          return _PointDrag(seriesIdx, i, null);
        }
      }
    }

    return null;
  }

  bool _tryStartPointDrag(Rect chartArea, Offset position) {
    final hit = _hitTestPoint(chartArea, position);
    if (hit == null) return false;

    setState(() {
      _activeDragPoint = hit;
      _lastDragValue = null;
      _hoverPosition = position;
      _activeHtmlTooltip = null;
      _activeTooltipPosition = null;
    });

    _updateDraggedPoint(chartArea, position);
    return true;
  }

  void _updateDraggedPoint(Rect chartArea, Offset position) {
    final active = _activeDragPoint;
    if (active == null) return;

    final seriesData = widget.series[active.seriesIndex];
    final newValue = _yPixelToValue(position.dy, chartArea, seriesData);
    _lastDragValue = newValue;

    if (widget.showDragTooltip) {
      _showDragTooltip(chartArea, seriesData, active, newValue);
    }

    if (active.valueType != null) {
      if (widget.onCandlestickValueChange != null) {
        widget.onCandlestickValueChange!(active.seriesIndex, active.pointIndex, active.valueType!, newValue);
      } else {
        widget.onPointValueChange?.call(active.seriesIndex, active.pointIndex, newValue);
      }
    } else {
      widget.onPointValueChange?.call(active.seriesIndex, active.pointIndex, newValue);
    }

    setState(() {
      _hoverPosition = position;
    });
  }

  void _endPointDrag() {
    final active = _activeDragPoint;
    if (active == null) return;

    final lastValue = _lastDragValue;
    setState(() {
      _activeDragPoint = null;
      _lastDragValue = null;
      if (widget.showDragTooltip) {
        _activeHtmlTooltip = null;
        _activeTooltipPosition = null;
      }
    });

    if (lastValue != null) {
      if (active.valueType != null) {
        if (widget.onCandlestickValueChangeEnd != null) {
          widget.onCandlestickValueChangeEnd!(active.seriesIndex, active.pointIndex, active.valueType!, lastValue);
        } else {
          widget.onPointValueChangeEnd?.call(active.seriesIndex, active.pointIndex, lastValue);
        }
      } else {
        widget.onPointValueChangeEnd?.call(active.seriesIndex, active.pointIndex, lastValue);
      }
    }
  }

  void _showDragTooltip(Rect chartArea, HybridChartSeries seriesData, _PointDrag active, double newValue) {
    String label = seriesData.dataPoints[active.pointIndex].label;
    if (label.trim().isEmpty) {
      label = DateFormat('MMM dd, yyyy').format(DateTime.now());
    }

    String valueLabel = 'Value';
    if (active.valueType != null) {
      switch (active.valueType!) {
        case HybridCandlestickValueType.open:
          valueLabel = 'Open';
          break;
        case HybridCandlestickValueType.close:
          valueLabel = 'Close';
          break;
        case HybridCandlestickValueType.high:
          valueLabel = 'High';
          break;
        case HybridCandlestickValueType.low:
          valueLabel = 'Low';
          break;
      }
    }

    final html = '''
      <div style="font-family: Arial, sans-serif; padding:6px;">
        <div style="font-weight:bold;margin-bottom:6px;">$label</div>
        <div>$valueLabel: ${newValue.toStringAsFixed(2)}</div>
      </div>
    ''';

    final tooltip = KeyEventData(
      htmlContent: html,
      markerColor: seriesData.color ?? widget.style.bullishColor,
    );

    double x;
    double y;
    if (_currentChartType == HybridChartType.candlestick) {
      final eff = _getEffectiveCandleWidth(chartArea, seriesData.dataPoints.length);
      x = _getCandleX(active.pointIndex, chartArea, seriesData.dataPoints.length) + eff / 2;
      y = _valueToYPixel(newValue, chartArea, seriesData);
    } else {
      x = _getXCoordinate(chartArea, active.pointIndex, seriesData.dataPoints.length);
      y = _valueToYPixel(newValue, chartArea, seriesData);
    }

    setState(() {
      _activeHtmlTooltip = tooltip;
      _activeTooltipPosition = Offset(x, y);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHtmlTooltip());
  }

  void _updateActiveTooltip(Rect chartArea, Offset pointerPosition) {
    final result = _computeActiveTooltip(chartArea, pointerPosition);
    _activeHtmlTooltip = result.tooltip;
    _activeTooltipPosition = result.position;
    // Measure tooltip size after it's built so we can position it accurately
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHtmlTooltip());
  }

  _TooltipHit? _checkPointHover(Rect chartArea, Offset pointerPosition) {
    for (int seriesIdx = 0; seriesIdx < widget.series.length; seriesIdx++) {
      final seriesData = widget.series[seriesIdx];
      final points = _getAreaChartPoints(chartArea, seriesData);
      if (points.isEmpty) continue;

      final pointSize = seriesData.pointSize ?? widget.style.defaultPointSize;
      final hitRadius = max(8.0, pointSize + 6.0);

      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final dx = (pointerPosition.dx - p.dx).abs();
        final dy = (pointerPosition.dy - p.dy).abs();
        if (dx <= hitRadius && dy <= hitRadius) {
          final data = seriesData.dataPoints[i];
          String label = data.label;
          if (label.trim().isEmpty) {
            label = DateFormat('MMM dd, yyyy').format(DateTime.now());
          }

          final html = '''
            <div style="font-family: Arial, sans-serif; padding:6px;">
              <div style="font-weight:bold;margin-bottom:6px;">$label</div>
              <div>Value: ${data.value.toStringAsFixed(2)}</div>
            </div>
          ''';

          final tooltip = KeyEventData(
            htmlContent: html,
            markerColor: seriesData.color ?? widget.style.colors[seriesIdx % widget.style.colors.length],
          );

          return _TooltipHit(tooltip, p);
        }
      }
    }
    return null;
  }

  void _measureHtmlTooltip() {
    try {
      final ctx = _htmlTooltipKey.currentContext;
      if (ctx == null) return;
      final renderBox = ctx.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;
      final newSize = renderBox.size;
      if (_activeTooltipSize == null || _activeTooltipSize != newSize) {
        setState(() {
          _activeTooltipSize = newSize;
        });
      }
    } catch (_) {}
  }

  Widget _buildHtmlTooltip(double chartWidth, double chartHeight) {
    if (_activeHtmlTooltip == null || _activeTooltipPosition == null) {
      return const SizedBox.shrink();
    }

    final opacity = _activeHtmlTooltip!.tooltipOpacity.clamp(0.0, 1.0);
    final maxWidth = _activeHtmlTooltip!.tooltipMaxWidth ?? 300.0;
    final maxHeight = _activeHtmlTooltip!.tooltipMaxHeight ?? 200.0;

    // Determine tooltip width/height if we measured it, otherwise rely on defaults
    final measuredW = _activeTooltipSize?.width ?? maxWidth;
    final measuredH = _activeTooltipSize?.height ?? (_activeHtmlTooltip!.tooltipMaxHeight ?? 120.0);

    double left = _activeTooltipPosition!.dx - measuredW / 2;
    if (left < 2) left = 2;
    if (left + measuredW > chartWidth - 2) left = chartWidth - measuredW - 2;

    // Position tooltip above marker using measured height when available
    final cfg = widget.style.keyEventMarkerConfig ?? const KeyEventMarkerConfig();
    final markerSize = _activeHtmlTooltip!.markerSize ?? cfg.size;
    final markerVerticalOffset = _activeHtmlTooltip!.verticalOffset ?? cfg.verticalOffset;
    final gap = 8.0;

    // _activeTooltipPosition is already the marker position adjusted by the verticalOffset
    // (marker dy = dataPointDy - verticalOffset). Therefore we should NOT subtract
    // the vertical offset again; position tooltip relative to the already-adjusted marker.
    double top = _activeTooltipPosition!.dy - markerSize / 2 - gap - measuredH;
    // Respect top/bottom padding from the style so tooltip does not overlap
    final minTop = widget.style.padding.top + 4.0;
    final maxTop = chartHeight - widget.style.padding.bottom - measuredH - 4.0;
    if (top < minTop) top = minTop;
    if (top > maxTop) top = maxTop;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Material(
          key: _htmlTooltipKey,
          elevation: 0,
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Html(
                data: _activeHtmlTooltip!.htmlContent,
                style: {
                  "*": Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    backgroundColor: Colors.transparent,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.series.isEmpty || widget.series[0].dataPoints.isEmpty) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: widget.backgroundColor ?? widget.style.backgroundColor ?? Colors.white),
        child: const Center(child: Text('No data available')),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the actual chart height (excluding title/toggle bar if present)
          final topBarHeight = (widget.title != null || widget.showChartTypeToggle) ? 60.0 : 0.0;
          final actualHeight = constraints.maxHeight - topBarHeight;

          final chartArea = Rect.fromLTWH(
            widget.style.padding.left + widget.axisConfig.yAxisWidth,
            widget.style.padding.top,
            constraints.maxWidth - widget.style.padding.horizontal - widget.axisConfig.yAxisWidth,
            actualHeight - widget.style.padding.vertical - widget.axisConfig.xAxisHeight,
          );

          // When volume is shown below the main chart we must reserve
          // a bottom area for volume bars. Compute the main plotting
          // area here (same logic as the painter) and use the main
          // area for hit-testing and tooltip anchoring so triggers
          // remain aligned with visible markers/candles.
          Rect mainArea = chartArea;
          Rect volumeArea = chartArea;
          if (widget.style.showVolume && widget.style.showVolumeBelowChart) {
            final areaRatio = widget.style.volumeAreaHeightRatio.clamp(0.0, 0.5);
            final vOffset = widget.style.volumeBarVerticalOffset;
            double volH = chartArea.height * areaRatio;
            if (vOffset > 0) {
              volH = (volH + vOffset).clamp(1.0, chartArea.height - 1.0);
            }
            final mainH = (chartArea.height - volH).clamp(0.0, chartArea.height);
            mainArea = Rect.fromLTWH(chartArea.left, chartArea.top, chartArea.width, mainH);
            volumeArea = Rect.fromLTWH(chartArea.left, chartArea.top + mainH, chartArea.width, volH);
          }

          // Recalculate tooltip position if active (handles resize automatically)
          if (_activeHtmlTooltip != null) {
            final pointerPos = _hoverPosition ?? Offset.zero;
            final result = _computeActiveTooltip(mainArea, pointerPos);
            if (result.tooltip?.htmlContent == _activeHtmlTooltip!.htmlContent && result.position != _activeTooltipPosition) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && result.position != _activeTooltipPosition) {
                  setState(() {
                    _activeTooltipPosition = result.position;
                  });
                }
              });
            }
          }

            return Column(
          mainAxisSize: MainAxisSize.max,
      children: [
        // Title and chart type switcher
        if (widget.title != null || widget.showChartTypeToggle)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.title != null)
                  Text(
                    widget.title!,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              // Chart type toggle
              if (widget.showChartTypeToggle)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      for (final type in HybridChartType.values)
                        GestureDetector(
                          onTap: () => _switchChartType(type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _currentChartType == type
                                  ? Colors.blue.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              border: _currentChartType == type
                                  ? Border(
                                      bottom: BorderSide(
                                        color: Colors.blue,
                                        width: 2,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Text(
                              type.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _currentChartType == type ? FontWeight.bold : FontWeight.normal,
                                color: _currentChartType == type ? Colors.blue : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                    ],
                ),
              ),
            ],
          ),
        ),

        // Chart
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              _tryStartPointDrag(mainArea, details.localPosition);
            },
            onPanUpdate: (details) {
              if (_activeDragPoint != null) {
                _updateDraggedPoint(mainArea, details.localPosition);
                return;
              }
              _handlePanUpdate(details);
            },
            onPanEnd: (_) => _endPointDrag(),
            onPanCancel: _endPointDrag,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hoverPosition = null),
              onHover: (details) {
                if (_activeDragPoint != null) {
                  setState(() => _hoverPosition = details.localPosition);
                  return;
                }
                setState(() {
                  _hoverPosition = details.localPosition;
                  _updateActiveTooltip(mainArea, details.localPosition);
                });
              },
              onExit: (_) => setState(() {
                _hoverPosition = null;
                _activeHtmlTooltip = null;
                _activeTooltipPosition = null;
              }),
              child: SizedBox(
                width: constraints.maxWidth,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: widget.backgroundColor ?? widget.style.backgroundColor ?? Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, _) {
                          return CustomPaint(
                            size: Size(constraints.maxWidth, actualHeight),
                            painter: HybridChartPainter(
                              series: widget.series,
                              progress: _animation.value,
                              style: widget.style,
                              axisConfig: widget.axisConfig,
                              chartType: _currentChartType,
                              hoverPosition: _hoverPosition,
                              scrollOffset: _scrollOffset,
                              volumeBelowChart: widget.style.showVolumeBelowChart,
                              enableHoverPointScale: widget.enableHoverPointScale,
                              hoverPointScale: widget.hoverPointScale,
                            ),
                          );
                        },
                      ),
                    ),
                    // Tooltip overlay
                    _buildHtmlTooltip(constraints.maxWidth, actualHeight),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Simple tuple for tooltip hit results
class _TooltipHit {
  final KeyEventData? tooltip;
  final Offset? position;
  const _TooltipHit(this.tooltip, this.position);
}

class _PointDrag {
  final int seriesIndex;
  final int pointIndex;
  final HybridCandlestickValueType? valueType;
  const _PointDrag(this.seriesIndex, this.pointIndex, this.valueType);
}
