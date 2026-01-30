import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../shared/shared_models.dart';
import 'models.dart';
import 'painter.dart';

/// MaterialCandlestickChart is a stateful widget that provides a user-friendly
/// interface for displaying and interacting with candlestick chart data.
///
/// Features:
/// - Animated chart rendering
/// - Interactive scrolling
/// - Hover effects
/// - Responsive sizing
/// - Customizable styling and configuration
/// - Support for Plotly JSON format (compatible with Python Plotly)
///
/// Example usage with traditional data:
/// ```dart
/// MaterialCandlestickChart(
///   data: candlestickData,
///   width: 400,
///   height: 300,
///   style: CandlestickStyle(),
///   showGrid: true,
/// )
/// ```
///
/// Example usage with Plotly JSON:
/// ```dart
/// MaterialCandlestickChart.fromPlotlyJson(
///   plotlyJsonString: jsonString,
///   width: 400,
///   height: 300,
///   showGrid: true,
/// )
/// ```
class MaterialCandlestickChart extends StatefulWidget {
  /// The candlestick data to be displayed
  final List<CandlestickData> data;

  /// Fixed width of the chart
  final double width;

  /// Fixed height of the chart
  final double height;

  /// Optional background color for the chart container
  final Color? backgroundColor;

  /// Visual styling configuration for candlesticks
  final CandlestickStyle style;

  /// Configuration for chart axes
  final ChartAxisConfig axisConfig;

  /// Padding around the chart
  final EdgeInsets padding;

  /// Whether to show grid lines
  final bool showGrid;

  /// Callback fired when entrance animation completes
  final VoidCallback? onAnimationComplete;

  /// Optional chart title (can be extracted from Plotly JSON)
  final String? title;

  const MaterialCandlestickChart({
    super.key,
    required this.data,
    required this.width,
    required this.height,
    this.backgroundColor,
    this.style = const CandlestickStyle(),
    this.axisConfig = const ChartAxisConfig(),
    this.padding = const EdgeInsets.all(16),
    this.showGrid = true,
    this.onAnimationComplete,
    this.title,
  });

  /// Creates a MaterialCandlestickChart from Plotly JSON string.
  ///
  /// This constructor accepts a JSON string in the exact same format
  /// as Python Plotly candlestick charts and automatically parses it
  /// into the appropriate data structures.
  ///
  /// Example Plotly JSON format:
  /// ```json
  /// {
  ///   "data": [
  ///     {
  ///       "type": "candlestick",
  ///       "x": ["2023-01-01", "2023-01-02", "2023-01-03"],
  ///       "open": [100, 105, 110],
  ///       "high": [120, 125, 130],
  ///       "low": [90, 95, 100],
  ///       "close": [105, 110, 125],
  ///       "volume": [1000, 1500, 2000],
  ///       "increasing": {"line": {"color": "green"}},
  ///       "decreasing": {"line": {"color": "red"}}
  ///     }
  ///   ],
  ///   "layout": {
  ///     "title": "Stock Price Chart",
  ///     "xaxis": {"title": "Date"},
  ///     "yaxis": {"title": "Price"}
  ///   }
  /// }
  /// ```
  factory MaterialCandlestickChart.fromPlotlyJson({
    Key? key,
    required String plotlyJsonString,
    required double width,
    required double height,
    Color? backgroundColor,
    CandlestickStyle? baseStyle,
    ChartAxisConfig? baseAxisConfig,
    EdgeInsets? padding,
    bool showGrid = true,
    VoidCallback? onAnimationComplete,
  }) {
    try {
      final plotlyData = PlotlyJson.fromJsonString(plotlyJsonString);

      return MaterialCandlestickChart(
        key: key,
        data: plotlyData.toCandlestickData(),
        width: width,
        height: height,
        backgroundColor: backgroundColor,
        style: plotlyData.toStyle(baseStyle: baseStyle),
        axisConfig: plotlyData.toAxisConfig(baseConfig: baseAxisConfig),
        padding: padding ?? const EdgeInsets.all(16),
        showGrid: showGrid,
        onAnimationComplete: onAnimationComplete,
        title: plotlyData.layout?.title,
      );
    } catch (e) {
      throw ArgumentError('Failed to parse Plotly JSON: $e');
    }
  }

  /// Creates a MaterialCandlestickChart from a Plotly JSON Map.
  ///
  /// This is useful when you already have the JSON decoded as a Map,
  /// typically from an API response or file reading.
  factory MaterialCandlestickChart.fromPlotlyMap({
    Key? key,
    required Map<String, dynamic> plotlyJsonMap,
    required double width,
    required double height,
    Color? backgroundColor,
    CandlestickStyle? baseStyle,
    ChartAxisConfig? baseAxisConfig,
    EdgeInsets? padding,
    bool showGrid = true,
    VoidCallback? onAnimationComplete,
  }) {
    try {
      final plotlyData = PlotlyJson.fromJson(plotlyJsonMap);

      return MaterialCandlestickChart(
        key: key,
        data: plotlyData.toCandlestickData(),
        width: width,
        height: height,
        backgroundColor: backgroundColor,
        style: plotlyData.toStyle(baseStyle: baseStyle),
        axisConfig: plotlyData.toAxisConfig(baseConfig: baseAxisConfig),
        padding: padding ?? const EdgeInsets.all(16),
        showGrid: showGrid,
        onAnimationComplete: onAnimationComplete,
        title: plotlyData.layout?.title,
      );
    } catch (e) {
      throw ArgumentError('Failed to parse Plotly JSON Map: $e');
    }
  }

  @override
  State<MaterialCandlestickChart> createState() =>
      _MaterialCandlestickChartState();
}

/// State class for MaterialCandlestickChart handling animations, gestures, and rendering
class _MaterialCandlestickChartState extends State<MaterialCandlestickChart>
    with SingleTickerProviderStateMixin {
  /// Controls the entrance animation
  late AnimationController _controller;

  /// Animation for progressive chart rendering
  late Animation<double> _animation;

  /// Current horizontal scroll position
  double _scrollOffset = 0.0;

  /// Current mouse hover position
  Offset? _hoverPosition;

  /// The currently active HTML tooltip for key events
  KeyEventData? _activeHtmlTooltip;

  /// Position of the active tooltip
  Offset? _activeTooltipPosition;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _scrollToEnd(); // Scroll to the last candle on initial build
  }

  @override
  void didUpdateWidget(MaterialCandlestickChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.length != widget.data.length) {
      _scrollToEnd(); // Scroll to the last candle when data updates
    }
  }

  /// Scrolls the chart to show the most recent candlesticks
  /// Called on initialization and when data updates
  void _scrollToEnd() {
    if (widget.data.isEmpty) return;

    // Calculate total candle width and scroll to show the last candle
    final totalCandleWidth =
        widget.style.candleWidth * (1 + widget.style.spacing);
    _scrollOffset = max(
      0.0,
      totalCandleWidth * (widget.data.length - 1) - widget.width,
    );
    setState(() {}); // Trigger rebuild with updated scroll offset
  }

  /// Configures the entrance animation controller and animation
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

  /// Handles pan gesture updates
  /// Updates scroll position based on drag delta
  void _handlePanUpdate(DragUpdateDetails details) {
    if (details.delta.dx.abs() < 1.0) return; // Ignore very small movements

    setState(() {
      final dx = details.delta.dx;
      final totalCandleWidth =
          widget.style.candleWidth * (1 + widget.style.spacing);

      _scrollOffset = (_scrollOffset - dx).clamp(
        0.0,
        max(0.0, totalCandleWidth * widget.data.length - widget.width),
      );
    });
  }

  /// Pure hit-test for key event markers; returns matched tooltip and its position.
  _TooltipHit _computeActiveTooltip(Rect chartArea, Offset pointerPosition) {
    if (!widget.style.showKeyEventMarkers) {
      return const _TooltipHit(null, null);
    }

    final config = widget.style.keyEventMarkerConfig ?? const KeyEventMarkerConfig();

    // Check all candlesticks for key events
    for (int i = 0; i < widget.data.length; i++) {
      final candleData = widget.data[i];
      if (candleData.keyEvent == null || !candleData.keyEvent!.hasHtmlContent) continue;

      final keyEvent = candleData.keyEvent!;
      final markerSize = keyEvent.markerSize ?? config.size;
      final verticalOffset = keyEvent.verticalOffset ?? config.verticalOffset;

      // Calculate marker position
      final candleX = _getCandleX(i, chartArea);
      final eff = _getEffectiveCandleWidth(chartArea, widget.data.length);
      final high = candleData.high;
      final low = widget.data.map((d) => d.low).reduce((a, b) => a < b ? a : b);
      final highPrice = widget.data.map((d) => d.high).reduce((a, b) => a > b ? a : b);
      final range = highPrice - low;
      final highY = chartArea.bottom - ((high - low) / range * chartArea.height);

      final markerOffset = Offset(
        candleX + eff / 2,
        highY - verticalOffset,
      );

      // Use marker size as hover radius
      final hoverRadius = markerSize / 2;
      final distance = (markerOffset - pointerPosition).distance;
      if (distance <= hoverRadius) {
        return _TooltipHit(keyEvent, markerOffset);
      }
    }

    return const _TooltipHit(null, null);
  }

  /// Calculates the X position for a candlestick at the given index
  double _getCandleX(int index, Rect chartArea) {
    final eff = _getEffectiveCandleWidth(chartArea, widget.data.length);
    final totalCandleWidth = eff * (1 + widget.style.spacing);
    return chartArea.left + (totalCandleWidth * index) - _scrollOffset;
  }

  double _getEffectiveCandleWidth(Rect chartArea, int dataPointCount) {
    final slots = dataPointCount <= 0 ? 1 : dataPointCount;
    final slotWidth = chartArea.width / slots;
    return min(widget.style.candleWidth, slotWidth * 0.8);
  }

  /// Updates the active HTML tooltip based on hover position
  void _updateActiveTooltip(Rect chartArea, Offset pointerPosition) {
    final result = _computeActiveTooltip(chartArea, pointerPosition);
    _activeHtmlTooltip = result.tooltip;
    _activeTooltipPosition = result.position;
  }

  /// Builds the HTML tooltip widget overlay
  Widget _buildHtmlTooltip(double chartWidth, double chartHeight) {
    if (_activeHtmlTooltip == null || _activeTooltipPosition == null) {
      return const SizedBox.shrink();
    }

    final padding = widget.padding;
    final opacity = _activeHtmlTooltip!.tooltipOpacity.clamp(0.0, 1.0);

    // Use tooltip-specific dimensions if provided, otherwise use style defaults
    final maxWidth = _activeHtmlTooltip!.tooltipMaxWidth ?? 300.0;
    final maxHeight = _activeHtmlTooltip!.tooltipMaxHeight ?? 200.0;

    // Calculate position (above the marker)
    double left = _activeTooltipPosition!.dx - maxWidth / 2;
    double top = _activeTooltipPosition!.dy - 120; // Approximate tooltip height offset

    // Adjust if going outside bounds
    final minLeft = padding.left;
    final maxLeft = chartWidth - maxWidth - padding.right;
    if (maxLeft >= minLeft) {
      left = left.clamp(minLeft, maxLeft);
    } else {
      // Chart is narrower than tooltip; pin to left padding
      left = minLeft;
    }

    if (top < padding.top) {
      top = _activeTooltipPosition!.dy + 15; // Show below if not enough space above
    }

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
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
    if (widget.data.isEmpty) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Colors.white,
        ),
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Optional title
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              widget.title!,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),

        // Chart
        GestureDetector(
          behavior: HitTestBehavior.opaque, // Capture all touch interactions
          onPanUpdate: _handlePanUpdate,
          child: MouseRegion(
            onEnter: (_) =>
                setState(() => _hoverPosition = null), // Reset hover
            onHover: (details) {
              setState(() {
                _hoverPosition = details.localPosition; // Update hover position
                // Calculate chart area and update active tooltip
                final chartArea = Rect.fromLTWH(
                  widget.padding.left + widget.axisConfig.yAxisWidth,
                  widget.padding.top,
                  widget.width - widget.padding.horizontal - widget.axisConfig.yAxisWidth,
                  widget.height - widget.padding.vertical - widget.axisConfig.xAxisHeight,
                );
                _updateActiveTooltip(chartArea, details.localPosition);
              });
            },
            onExit: (_) =>
                setState(() {
                  _hoverPosition = null; // Clear on exit
                  _activeHtmlTooltip = null;
                  _activeTooltipPosition = null;
                }), // Clear on exit
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    width: widget.width,
                    height: widget.height,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size(widget.width, widget.height),
                          painter: CandlestickChartPainter(
                            data: widget.data,
                            progress: _animation.value,
                            style: widget.style,
                            axisConfig: widget.axisConfig,
                            padding: widget.padding,
                            showGrid: widget.showGrid,
                            scrollOffset: _scrollOffset,
                            hoverPosition:
                                _hoverPosition, // Pass hover position to painter
                          ),
                        );
                      },
                    ),
                  ),
                  // HTML tooltip overlay for key events
                  _buildHtmlTooltip(widget.width, widget.height),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Utility class for validating and parsing Plotly JSON data
class PlotlyJsonValidator {
  /// Validates that the JSON contains required candlestick fields
  static bool isValidCandlestickJson(Map<String, dynamic> json) {
    try {
      final dataList = json['data'] as List<dynamic>?;
      if (dataList == null || dataList.isEmpty) return false;

      for (final item in dataList) {
        final trace = item as Map<String, dynamic>;
        if (trace['type'] != 'candlestick') continue;

        // Check required fields
        final requiredFields = ['x', 'open', 'high', 'low', 'close'];
        for (final field in requiredFields) {
          if (!trace.containsKey(field)) return false;
          if (trace[field] is! List) return false;
        }

        // Check array lengths match
        final x = trace['x'] as List;
        final open = trace['open'] as List;
        final high = trace['high'] as List;
        final low = trace['low'] as List;
        final close = trace['close'] as List;

        if (x.length != open.length ||
            x.length != high.length ||
            x.length != low.length ||
            x.length != close.length) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Provides detailed error information for invalid JSON
  static String getValidationError(Map<String, dynamic> json) {
    try {
      final dataList = json['data'] as List<dynamic>?;
      if (dataList == null) return 'Missing "data" array';
      if (dataList.isEmpty) return 'Empty "data" array';

      for (int i = 0; i < dataList.length; i++) {
        final trace = dataList[i] as Map<String, dynamic>;

        if (trace['type'] != 'candlestick') {
          continue; // Skip non-candlestick traces
        }

        // Check required fields
        final requiredFields = ['x', 'open', 'high', 'low', 'close'];
        for (final field in requiredFields) {
          if (!trace.containsKey(field)) {
            return 'Trace $i missing required field: $field';
          }
          if (trace[field] is! List) {
            return 'Trace $i field $field must be an array';
          }
        }

        // Check array lengths
        final x = trace['x'] as List;
        final open = trace['open'] as List;
        final high = trace['high'] as List;
        final low = trace['low'] as List;
        final close = trace['close'] as List;

        if (x.length != open.length ||
            x.length != high.length ||
            x.length != low.length ||
            x.length != close.length) {
          return 'Trace $i: All arrays must have the same length';
        }

        if (x.isEmpty) {
          return 'Trace $i: Arrays cannot be empty';
        }
      }

      return 'Valid';
    } catch (e) {
      return 'JSON parsing error: $e';
    }
  }
}

/// Simple tuple for tooltip hit results
class _TooltipHit {
  final KeyEventData? tooltip;
  final Offset? position;
  const _TooltipHit(this.tooltip, this.position);
}
