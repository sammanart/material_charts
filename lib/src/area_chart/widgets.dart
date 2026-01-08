import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import 'models.dart';
import 'painter.dart';

/// The main area chart widget
class MaterialAreaChart extends StatefulWidget {
  final List<AreaChartSeries> series; // List of series data for the area chart
  final double width; // Width of the chart
  final double height; // Height of the chart
  final AreaChartStyle style; // Style configuration for the chart
  final VoidCallback?
      onAnimationComplete; // Callback for when the animation completes
  final bool interactive; // Flag to enable or disable interactivity

  const MaterialAreaChart({
    super.key,
    required this.series, // Required series data
    required this.width, // Required width
    required this.height, // Required height
    this.style = const AreaChartStyle(), // Default style if none provided
    this.onAnimationComplete, // Optional callback for animation completion
    this.interactive = true, // Default to interactive
  }); 

  /// Creates a MaterialAreaChart from Plotly JSON string.
  ///
  /// This constructor allows you to directly use JSON data formatted
  /// for Plotly (commonly used in Python scripts) to create the area chart.
  ///
  /// Example usage:
  /// ```dart
  /// MaterialAreaChart.fromPlotlyJson(
  ///   plotlyJson: '''
  ///   {
  ///     "data": [
  ///       {
  ///         "x": [1, 2, 3, 4],
  ///         "y": [10, 11, 12, 13],
  ///         "type": "scatter",
  ///         "mode": "lines",
  ///         "fill": "tozeroy",
  ///         "name": "Series 1",
  ///         "line": {"color": "blue", "width": 2}
  ///       }
  ///     ],
  ///     "layout": {
  ///       "title": "My Area Chart"
  ///     }
  ///   }
  ///   ''',
  ///   width: 400,
  ///   height: 300,
  /// )
  /// ```
  factory MaterialAreaChart.fromPlotlyJson({
    Key? key,
    required String plotlyJson,
    required double width,
    required double height,
    AreaChartStyle? styleOverrides,
    VoidCallback? onAnimationComplete,
    bool interactive = true,
  }) {
    final PlotlyAreaChartData plotlyData = PlotlyAreaChartParser.fromJson(
      plotlyJson,
    );

    // Merge style overrides with parsed style
    final AreaChartStyle finalStyle = styleOverrides != null
        ? _mergeStyles(plotlyData.style, styleOverrides)
        : plotlyData.style;

    return MaterialAreaChart(
      key: key,
      series: plotlyData.series,
      width: width,
      height: height,
      style: finalStyle,
      onAnimationComplete: onAnimationComplete,
      interactive: interactive,
    );
  }

  /// Creates a MaterialAreaChart from Plotly data map.
  ///
  /// representing Plotly data structure.
  factory MaterialAreaChart.fromPlotlyMap({
    Key? key,
    required Map<String, dynamic> plotlyData,
    required double width,
    required double height,
    AreaChartStyle? styleOverrides,
    VoidCallback? onAnimationComplete,
    bool interactive = true,
  }) {
    final PlotlyAreaChartData parsedData = PlotlyAreaChartParser.fromMap(
      plotlyData,
    );

    // Merge style overrides with parsed style
    final AreaChartStyle finalStyle = styleOverrides != null
        ? _mergeStyles(parsedData.style, styleOverrides)
        : parsedData.style;

    return MaterialAreaChart(
      key: key,
      series: parsedData.series,
      width: width,
      height: height,
      style: finalStyle,
      onAnimationComplete: onAnimationComplete,
      interactive: interactive,
    );
  }

  /// Helper method to merge style overrides with parsed style
  static AreaChartStyle _mergeStyles(
    AreaChartStyle baseStyle,
    AreaChartStyle overrides,
  ) {
    return AreaChartStyle(
      colors: overrides.colors.isNotEmpty ? overrides.colors : baseStyle.colors,
      gridColor: overrides.gridColor != Colors.grey
          ? overrides.gridColor
          : baseStyle.gridColor,
      backgroundColor: overrides.backgroundColor != Colors.white
          ? overrides.backgroundColor
          : baseStyle.backgroundColor,
      labelStyle: overrides.labelStyle ?? baseStyle.labelStyle,
      defaultLineWidth: overrides.defaultLineWidth != 2.0
          ? overrides.defaultLineWidth
          : baseStyle.defaultLineWidth,
      defaultPointSize: overrides.defaultPointSize != 4.0
          ? overrides.defaultPointSize
          : baseStyle.defaultPointSize,
      showPoints: overrides.showPoints != true
          ? overrides.showPoints
          : baseStyle.showPoints,
      showGrid:
          overrides.showGrid != true ? overrides.showGrid : baseStyle.showGrid,
      animationDuration:
          overrides.animationDuration != const Duration(milliseconds: 1500)
              ? overrides.animationDuration
              : baseStyle.animationDuration,
      animationCurve: overrides.animationCurve != Curves.easeInOut
          ? overrides.animationCurve
          : baseStyle.animationCurve,
      padding: overrides.padding != const EdgeInsets.all(24)
          ? overrides.padding
          : baseStyle.padding,
      horizontalGridLines: overrides.horizontalGridLines != 5
          ? overrides.horizontalGridLines
          : baseStyle.horizontalGridLines,
      forceYAxisFromZero: overrides.forceYAxisFromZero != true
          ? overrides.forceYAxisFromZero
          : baseStyle.forceYAxisFromZero,
      title: overrides.title ?? baseStyle.title,
      xAxisTitle: overrides.xAxisTitle ?? baseStyle.xAxisTitle,
      yAxisTitle: overrides.yAxisTitle ?? baseStyle.yAxisTitle,
    );
  }

  @override
  State<MaterialAreaChart> createState() => _MaterialAreaChartState();
}

class _MaterialAreaChartState extends State<MaterialAreaChart>
    with SingleTickerProviderStateMixin {
  late AnimationController
      _controller; // Animation controller for managing the animation
  late Animation<double> _animation; // Animation for the progress of the chart
  Offset? _tooltipPosition; // Position of the tooltip when hovering over points
  KeyEventData? _activeHtmlTooltip; // The currently active HTML tooltip
  Offset? _activeTooltipPosition; // Position of the active HTML tooltip

  @override
  void initState() {
    super.initState();
    _setupAnimation(); // Set up the animation when the widget is initialized
  }

  /// Sets up the animation controller and animation
  void _setupAnimation() {
    _controller = AnimationController(
      duration: widget
          .style.animationDuration, // Duration of the animation from the style
      vsync: this, // Use this state as the vsync provider
    );

    // Create a tween animation from 0.0 to 1.0
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller, // Use the controller as the parent
        curve:
            widget.style.animationCurve, // Use the curve defined in the style
      ),
    )..addStatusListener((status) {
        // Listen for animation status changes
        if (status == AnimationStatus.completed) {
          // Call the completion callback if the animation is finished
          widget.onAnimationComplete?.call();
        }
      });

    _controller.forward(); // Start the animation
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add title if present
        if (widget.style.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              widget.style.title!,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

        // Main chart area with HTML tooltip overlay
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: MouseRegion(
            onHover: widget.interactive ? _handleHover : null,
            onExit: widget.interactive
                ? (_) => setState(() {
                      _tooltipPosition = null;
                      _activeHtmlTooltip = null;
                      _activeTooltipPosition = null;
                    })
                : null,
            child: Stack(
              children: [
                // Chart canvas
                Container(
                  width: widget.width,
                  height: widget.height,
                  color: widget.style.backgroundColor,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) {
                      // Update active HTML tooltip based on hover
                      _updateActiveTooltip();
                      
                      return CustomPaint(
                        size: Size(widget.width, widget.height),
                        painter: AreaChartPainter(
                          series: widget.series,
                          progress: _animation.value,
                          style: widget.style,
                          tooltipPosition: _tooltipPosition,
                        ),
                      );
                    },
                  ),
                ),
                
                // HTML tooltip overlay
                if (_activeHtmlTooltip != null && _activeTooltipPosition != null)
                  _buildHtmlTooltip(),
              ],
            ),
          ),
        ),

        // Add axis titles if present
        if (widget.style.xAxisTitle != null || widget.style.yAxisTitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Y-axis title (rotated)
                if (widget.style.yAxisTitle != null)
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      widget.style.yAxisTitle!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),

                const Spacer(),

                // X-axis title
                if (widget.style.xAxisTitle != null)
                  Text(
                    widget.style.xAxisTitle!,
                    style: const TextStyle(fontSize: 14),
                  ),

                const Spacer(),

                // Empty space for balance
                if (widget.style.yAxisTitle != null) const SizedBox(width: 20),
              ],
            ),
          ),
      ],
    );
  }

  /// Handles mouse hover events to show the tooltip
  void _handleHover(PointerHoverEvent event) {
    if (!widget.interactive) return; // Exit if not interactive
    setState(
      () => _tooltipPosition = event.localPosition,
    ); // Update tooltip position based on mouse location
  }
  
  /// Updates the active HTML tooltip based on hover position
  void _updateActiveTooltip() {
    if (_tooltipPosition == null || !widget.style.showKeyEventMarkers) {
      _activeHtmlTooltip = null;
      _activeTooltipPosition = null;
      return;
    }
    
    final config = widget.style.keyEventMarkerConfig ?? const KeyEventMarkerConfig();
    
    // Check all series for key events
    for (final seriesData in widget.series) {
      final points = _getSeriesPoints(seriesData);
      
      for (int i = 0; i < seriesData.dataPoints.length; i++) {
        final dataPoint = seriesData.dataPoints[i];
        if (dataPoint.keyEvent == null || !dataPoint.keyEvent!.hasHtmlContent) continue;
        
        if (i >= points.length) continue;
        
        final markerSize = dataPoint.keyEvent!.markerSize ?? config.size;
        final calculatedRadius = markerSize / 2;
        final hoverRadius = calculatedRadius > config.minHoverRadius ? calculatedRadius : config.minHoverRadius;
        
        final markerOffset = Offset(
          points[i].dx,
          points[i].dy - config.verticalOffset,
        );
        
        final distance = (markerOffset - _tooltipPosition!).distance;
        if (distance <= hoverRadius) {
          _activeHtmlTooltip = dataPoint.keyEvent;
          _activeTooltipPosition = markerOffset;
          return;
        }
      }
    }
    
    _activeHtmlTooltip = null;
    _activeTooltipPosition = null;
  }
  
  /// Builds the HTML tooltip widget overlay
  Widget _buildHtmlTooltip() {
    if (_activeHtmlTooltip == null || _activeTooltipPosition == null) {
      return const SizedBox.shrink();
    }
    
    final padding = widget.style.padding;
    final opacity = _activeHtmlTooltip!.tooltipOpacity.clamp(0.0, 1.0);
    
    // Get tooltip style configuration or use defaults
    final tooltipStyle = widget.style.tooltipStyle ?? const TooltipStyleConfig();
    
    // Use tooltip-specific dimensions if provided, otherwise use style defaults
    final maxWidth = _activeHtmlTooltip!.tooltipMaxWidth ?? tooltipStyle.defaultMaxWidth;
    final maxHeight = _activeHtmlTooltip!.tooltipMaxHeight ?? tooltipStyle.defaultMaxHeight;
    
    // Calculate position (above the marker)
    double left = _activeTooltipPosition!.dx - maxWidth / 2;
    double top = _activeTooltipPosition!.dy - 120; // Approximate tooltip height offset
    
    // Adjust if going outside bounds
    left = left.clamp(padding.left, widget.width - maxWidth - padding.right);
    if (top < padding.top) {
      top = _activeTooltipPosition!.dy + 15; // Show below if not enough space above
    }
    
    return Positioned(
      left: left,
      top: top,
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(tooltipStyle.borderRadius),
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          decoration: BoxDecoration(
            color: tooltipStyle.backgroundColor.withValues(
              alpha: opacity * tooltipStyle.backgroundOpacity,
            ),
            borderRadius: BorderRadius.circular(tooltipStyle.borderRadius),
            border: tooltipStyle.borderWidth > 0
                ? Border.all(
                    color: tooltipStyle.borderColor,
                    width: tooltipStyle.borderWidth,
                  )
                : null,
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
    );
  }
  
  /// Helper method to get series points (same logic as painter)
  List<Offset> _getSeriesPoints(AreaChartSeries seriesData) {
    if (seriesData.dataPoints.isEmpty) return [];
    
    final chartArea = Rect.fromLTWH(
      widget.style.padding.left,
      widget.style.padding.top,
      widget.width - widget.style.padding.horizontal,
      widget.height - widget.style.padding.vertical,
    );
    
    final slots = widget.style.xSpanSlots;
    final allValues = widget.series.expand((s) {
      final takeCount = slots == null ? s.dataPoints.length : (s.dataPoints.length < slots ? s.dataPoints.length : slots);
      return s.dataPoints.take(takeCount).map((p) => p.value);
    });
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    final minValue = widget.style.forceYAxisFromZero 
        ? 0.0 
        : allValues.reduce((a, b) => a < b ? a : b);
    final valueRange = maxValue - minValue;
    
    final count = slots == null
        ? seriesData.dataPoints.length
        : (seriesData.dataPoints.length < slots ? seriesData.dataPoints.length : slots);
    return List.generate(count, (i) {
      final slots = widget.style.xSpanSlots ?? seriesData.dataPoints.length;
      final denom = (slots - 1) <= 0 ? 1 : (slots - 1);
      final x = chartArea.left + (chartArea.width / denom) * i;
      final normalizedValue = (seriesData.dataPoints[i].value - minValue) / valueRange;
      final y = chartArea.bottom - (normalizedValue * chartArea.height);
      return Offset(x, y);
    });
  }
}
