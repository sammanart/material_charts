import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_html/flutter_html.dart';

import '../shared/shared_models.dart';
import 'models.dart';
import 'painter.dart';

/// The main area chart widget
class MaterialAreaChart extends StatefulWidget {
  final List<AreaChartSeries> series; // List of series data for the area chart
  final double width; // Width of the chart
  final double height; // Height of the chart
  final AreaChartStyle style; // Style configuration for the chart
  final VoidCallback? onAnimationComplete; // Callback for when the animation completes
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
    final AreaChartStyle finalStyle = styleOverrides != null ? mergeStyles(plotlyData.style, styleOverrides) : plotlyData.style;

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
    final AreaChartStyle finalStyle = styleOverrides != null ? mergeStyles(parsedData.style, styleOverrides) : parsedData.style;

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
  static AreaChartStyle mergeStyles(
    AreaChartStyle baseStyle,
    AreaChartStyle overrides,
  ) {
    return AreaChartStyle(
      colors: overrides.colors.isNotEmpty ? overrides.colors : baseStyle.colors,
      gridColor: overrides.gridColor != Colors.grey ? overrides.gridColor : baseStyle.gridColor,
      backgroundColor: overrides.backgroundColor != Colors.white ? overrides.backgroundColor : baseStyle.backgroundColor,
      labelStyle: overrides.labelStyle ?? baseStyle.labelStyle,
      defaultLineWidth: overrides.defaultLineWidth != 2.0 ? overrides.defaultLineWidth : baseStyle.defaultLineWidth,
      defaultPointSize: overrides.defaultPointSize != 4.0 ? overrides.defaultPointSize : baseStyle.defaultPointSize,
      showPoints: overrides.showPoints != true ? overrides.showPoints : baseStyle.showPoints,
      showGrid: overrides.showGrid != true ? overrides.showGrid : baseStyle.showGrid,
      animationDuration: overrides.animationDuration != const Duration(milliseconds: 1500) ? overrides.animationDuration : baseStyle.animationDuration,
      animationCurve: overrides.animationCurve != Curves.easeInOut ? overrides.animationCurve : baseStyle.animationCurve,
      padding: overrides.padding != const EdgeInsets.all(24) ? overrides.padding : baseStyle.padding,
      horizontalGridLines: overrides.horizontalGridLines != 5 ? overrides.horizontalGridLines : baseStyle.horizontalGridLines,
      forceYAxisFromZero: overrides.forceYAxisFromZero != true ? overrides.forceYAxisFromZero : baseStyle.forceYAxisFromZero,
      title: overrides.title ?? baseStyle.title,
      xAxisTitle: overrides.xAxisTitle ?? baseStyle.xAxisTitle,
      yAxisTitle: overrides.yAxisTitle ?? baseStyle.yAxisTitle,
      stacked: overrides.stacked != false ? overrides.stacked : baseStyle.stacked,
    );
  }

  @override
  MaterialAreaChartState createState() => MaterialAreaChartState();
}

class MaterialAreaChartState extends State<MaterialAreaChart> with TickerProviderStateMixin {
  late AnimationController _controller; // Animation controller for managing the animation
  late Animation<double> _animation; // Animation for the progress of the chart
  Offset? _tooltipPosition; // Position of the tooltip when hovering over points
  KeyEventData? _activeHtmlTooltip; // The currently active HTML tooltip
  Offset? _activeTooltipPosition; // Position of the active HTML tooltip
  List<double> _seriesAnimationProgress = []; // Per-series animation progress
  Map<int, double> _segmentAnimationProgress = {}; // Per-segment animation progress
  final Set<int> _manuallyTriggeredOrders = {}; // Animation orders that have been manually triggered
  final Map<int, DateTime> _manualTriggerStartTime = {}; // Wall-clock time when each manual trigger was activated
  Ticker? _manualSegmentTicker; // Separate ticker for driving manual segment animation updates

  @override
  void initState() {
    super.initState();
    _setupAnimation(); // Set up the animation when the widget is initialized
  }

  /// Sets up the animation controller and animation
  void _setupAnimation() {
    // Calculate total animation duration based on series animation configurations
    final totalDuration = _calculateTotalAnimationDuration();

    _controller = AnimationController(
      duration: totalDuration,
      vsync: this, // Use this state as the vsync provider
    );

    // Create a tween animation from 0.0 to 1.0
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller, // Use the controller as the parent
        curve: widget.style.animationCurve, // Use the curve defined in the style
      ),
    )..addStatusListener((status) {
        // Listen for animation status changes
        if (status == AnimationStatus.completed) {
          // Call the completion callback if the animation is finished
          widget.onAnimationComplete?.call();
        }
      });

    // Listen to animation changes to update per-series and per-segment progress
    _controller.addListener(() {
      _updateAnimationProgress();
    });

    // Initialize animation progress before first paint to avoid a one-frame flash
    // where areas could appear fully rendered.
    _updateAnimationProgress();

    _controller.forward(); // Start the animation
  }

  /// Calculates the total animation duration based on individual series configurations
  Duration _calculateTotalAnimationDuration() {
    int seriesDurationMs = 0;
    int segmentDurationMs = 0;

    // Calculate series animation duration
    // Group series by animation order
    final seriesByOrder = <int, List<int>>{};

    for (int i = 0; i < widget.series.length; i++) {
      final config = widget.series[i].animationConfig;
      final order = config?.animationOrder ?? 0;

      if (!seriesByOrder.containsKey(order)) {
        seriesByOrder[order] = [];
      }
      seriesByOrder[order]!.add(i);
    }

    // Sort orders
    final sortedOrders = seriesByOrder.keys.toList()..sort();

    // Calculate timing for each order group
    for (final order in sortedOrders) {
      int groupDuration = 0;
      int nextDelay = 0;

      // Find max duration in this order group
      for (final seriesIndex in seriesByOrder[order]!) {
        final config = widget.series[seriesIndex].animationConfig;
        final duration = config?.duration?.inMilliseconds ?? widget.style.animationDuration.inMilliseconds;
        groupDuration = math.max(groupDuration, duration);

        // Get delay for next animation
        final trigger = config?.animationTrigger ?? widget.style.defaultAnimationTrigger;
        if (trigger == AreaAnimationTrigger.afterDelay) {
          nextDelay = math.max(nextDelay, (config?.delayBeforeNext ?? widget.style.defaultDelayBeforeNext).inMilliseconds);
        }
      }

      seriesDurationMs += groupDuration;

      // Only add delay if there are more orders to come
      if (sortedOrders.indexOf(order) < sortedOrders.length - 1) {
        seriesDurationMs += nextDelay;
      }
    }

    // If no custom animations, use default duration
    if (seriesDurationMs == 0) {
      seriesDurationMs = widget.style.animationDuration.inMilliseconds;
    }

    // Calculate segment animation duration (only count auto-trigger segments for total duration)
    final segmentConfigs = widget.style.segmentAnimationConfigs;
    if (segmentConfigs.isNotEmpty) {
      final sortedSegmentOrders = segmentConfigs.keys.toList()..sort();

      for (final segmentOrder in sortedSegmentOrders) {
        final config = segmentConfigs[segmentOrder]!;
        // Only count duration for auto-trigger segments; manual ones are not part of the timeline
        if (config.animationTrigger != AreaAnimationTrigger.manual) {
          final duration = config.duration?.inMilliseconds ?? widget.style.defaultSegmentAnimationDuration.inMilliseconds;

          segmentDurationMs += duration;

          // Add delay if there are more segments
          if (sortedSegmentOrders.indexOf(segmentOrder) < sortedSegmentOrders.length - 1) {
            final delay = config.delayBeforeNext.inMilliseconds;
            segmentDurationMs += delay;
          }
        }
      }
    }

    // Total duration is series duration + auto-trigger segment duration only
    // Manual segments are driven by a separate ticker, not the main controller
    final totalMilliseconds = seriesDurationMs + segmentDurationMs;

    return Duration(milliseconds: math.max(totalMilliseconds, 100));
  }

  /// Updates per-series and per-segment animation progress based on current animation time
  void _updateAnimationProgress() {
    _seriesAnimationProgress = List<double>.filled(widget.series.length, 0.0);
    _segmentAnimationProgress = {};

    final currentTimeMs = _controller.value * _controller.duration!.inMilliseconds;

    // Calculate series animation duration first
    int seriesDurationMs = 0;

    // Group series by animation order
    final seriesByOrder = <int, List<int>>{};
    for (int i = 0; i < widget.series.length; i++) {
      final config = widget.series[i].animationConfig;
      final order = config?.animationOrder ?? 0;

      if (!seriesByOrder.containsKey(order)) {
        seriesByOrder[order] = [];
      }
      seriesByOrder[order]!.add(i);
    }

    // Sort orders
    final sortedOrders = seriesByOrder.keys.toList()..sort();

    // Calculate when each order group should start
    int accumulatedTimeMs = 0;

    for (final order in sortedOrders) {
      int groupDuration = 0;
      int nextDelay = 0;

      // Find max duration and delay in this group
      for (final seriesIndex in seriesByOrder[order]!) {
        final config = widget.series[seriesIndex].animationConfig;
        final duration = config?.duration?.inMilliseconds ?? widget.style.animationDuration.inMilliseconds;
        groupDuration = math.max(groupDuration, duration);

        final trigger = config?.animationTrigger ?? widget.style.defaultAnimationTrigger;
        if (trigger == AreaAnimationTrigger.afterDelay) {
          nextDelay = math.max(nextDelay, (config?.delayBeforeNext ?? widget.style.defaultDelayBeforeNext).inMilliseconds);
        }
      }

      // Update progress for each series in this order group
      final groupStartTimeMs = accumulatedTimeMs;
      final groupEndTimeMs = accumulatedTimeMs + groupDuration;

      for (final seriesIndex in seriesByOrder[order]!) {
        final config = widget.series[seriesIndex].animationConfig;
        final trigger = config?.animationTrigger ?? widget.style.defaultAnimationTrigger;

        // For manual triggers, only advance if this order has been manually triggered
        bool shouldAdvance = true;
        if (trigger == AreaAnimationTrigger.manual) {
          shouldAdvance = _manuallyTriggeredOrders.contains(order);
        }

        if (shouldAdvance) {
          if (trigger == AreaAnimationTrigger.manual) {
            // Manual series: use wall-clock elapsed time since trigger (consistent with manual segments)
            if (_manualTriggerStartTime.containsKey(order)) {
              final seriesDuration = config?.duration?.inMilliseconds ?? widget.style.animationDuration.inMilliseconds;
              final elapsed = DateTime.now().difference(_manualTriggerStartTime[order]!).inMilliseconds.toDouble();
              _seriesAnimationProgress[seriesIndex] = math.min(elapsed / seriesDuration.toDouble(), 1.0);
            }
          } else {
            if (currentTimeMs >= groupStartTimeMs && currentTimeMs <= groupEndTimeMs) {
              final seriesProgress = (currentTimeMs - groupStartTimeMs) / groupDuration;
              _seriesAnimationProgress[seriesIndex] = math.min(seriesProgress, 1.0);
            } else if (currentTimeMs > groupEndTimeMs) {
              _seriesAnimationProgress[seriesIndex] = 1.0;
            }
          }
        }
      }

      accumulatedTimeMs += groupDuration + (sortedOrders.indexOf(order) < sortedOrders.length - 1 ? nextDelay : 0);
    }

    seriesDurationMs = accumulatedTimeMs;

    // Calculate segment animation progress (for manual triggers, use actual trigger time)
    final segmentConfigs = widget.style.segmentAnimationConfigs;
    if (segmentConfigs.isNotEmpty) {
      final sortedSegmentOrders = segmentConfigs.keys.toList()..sort();
      int segmentAccumulatedTimeMs = 0;

      for (final segmentOrder in sortedSegmentOrders) {
        final config = segmentConfigs[segmentOrder]!;
        final duration = config.duration?.inMilliseconds ?? widget.style.defaultSegmentAnimationDuration.inMilliseconds;

        // For manual triggers, use wall-clock elapsed time; for auto triggers, use pre-calculated timeline
        if (config.animationTrigger == AreaAnimationTrigger.manual) {
          // Manual trigger: only animate if triggered, and calculate progress from wall-clock trigger time
          if (!_manuallyTriggeredOrders.contains(segmentOrder)) {
            _segmentAnimationProgress[segmentOrder] = 0.0;
          } else if (_manualTriggerStartTime.containsKey(segmentOrder)) {
            final elapsed = DateTime.now().difference(_manualTriggerStartTime[segmentOrder]!).inMilliseconds.toDouble();
            if (elapsed <= duration) {
              _segmentAnimationProgress[segmentOrder] = math.min(elapsed / duration, 1.0);
            } else {
              _segmentAnimationProgress[segmentOrder] = 1.0;
            }
          } else {
            _segmentAnimationProgress[segmentOrder] = 0.0;
          }
        } else {
          // Auto trigger: use pre-calculated timing
          final segmentStartTimeMs = seriesDurationMs + segmentAccumulatedTimeMs;
          final segmentEndTimeMs = segmentStartTimeMs + duration;

          if (currentTimeMs >= segmentStartTimeMs && currentTimeMs <= segmentEndTimeMs) {
            final segmentProgress = (currentTimeMs - segmentStartTimeMs) / duration;
            _segmentAnimationProgress[segmentOrder] = math.min(segmentProgress, 1.0);
          } else if (currentTimeMs > segmentEndTimeMs) {
            _segmentAnimationProgress[segmentOrder] = 1.0;
          } else {
            _segmentAnimationProgress[segmentOrder] = 0.0;
          }
        }

        // Add delay before next segment (only for auto triggers)
        if (config.animationTrigger != AreaAnimationTrigger.manual) {
          if (sortedSegmentOrders.indexOf(segmentOrder) < sortedSegmentOrders.length - 1) {
            segmentAccumulatedTimeMs += duration + config.delayBeforeNext.inMilliseconds;
          } else {
            segmentAccumulatedTimeMs += duration;
          }
        }
      }
    }

    // Check if any manual segments are still animating
    bool hasActiveManualSegments = false;
    for (final segmentOrder in _manuallyTriggeredOrders) {
      if (_segmentAnimationProgress[segmentOrder] != null && _segmentAnimationProgress[segmentOrder]! < 1.0) {
        hasActiveManualSegments = true;
        break;
      }
    }

    // Check if any manual series are still animating
    bool hasActiveManualSeries = false;
    for (int i = 0; i < widget.series.length; i++) {
      final seriesConfig = widget.series[i].animationConfig;
      final seriesTrigger = seriesConfig?.animationTrigger ?? widget.style.defaultAnimationTrigger;
      final seriesOrder = seriesConfig?.animationOrder ?? 0;
      if (seriesTrigger == AreaAnimationTrigger.manual && _manuallyTriggeredOrders.contains(seriesOrder) && _seriesAnimationProgress[i] < 1.0) {
        hasActiveManualSeries = true;
        break;
      }
    }

    final hasActiveManualAnimations = hasActiveManualSegments || hasActiveManualSeries;

    // Manage manual segment ticker
    if (hasActiveManualAnimations && _manualSegmentTicker == null) {
      _manualSegmentTicker = createTicker((_) {
        if (mounted) {
          setState(() {
            _updateAnimationProgress();
          });
        }
      });
      _manualSegmentTicker!.start();
    } else if (!hasActiveManualAnimations && _manualSegmentTicker != null) {
      _manualSegmentTicker!.dispose();
      _manualSegmentTicker = null;
      // Force a final repaint to show the completed animation even if focus is elsewhere
      // This ensures the final frame is rendered after the ticker stops
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }

    // Update UI if animation is in progress or manual animations are active
    if (mounted && (_controller.isAnimating || hasActiveManualAnimations)) {
      setState(() {});
    }
  }

  /// Manually triggers animation for a specific animation order
  ///
  /// This is used for manual animation triggers where animations wait
  /// for explicit triggers rather than automatic timing.
  /// The animation starts from the exact moment this method is called.
  ///
  /// Example usage:
  /// ```dart
  /// final globalKey = GlobalKey<MaterialAreaChartState>();
  /// // ... later in code
  /// globalKey.currentState?.triggerAnimation(1);
  /// ```
  void triggerAnimation(int animationOrder) {
    _manuallyTriggeredOrders.add(animationOrder);
    // Record the wall-clock time when this segment was triggered
    // This allows the segment to animate independently of the main animation controller
    _manualTriggerStartTime[animationOrder] = DateTime.now();
    _updateAnimationProgress();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the animation controller
    _manualSegmentTicker?.dispose(); // Dispose of the manual segment ticker
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

        // Main chart area with LayoutBuilder to respond to resizes
        LayoutBuilder(
          builder: (context, constraints) {
            // Use actual available space; clamp to constraints so compressed layouts stay in sync
            final maxW = constraints.hasBoundedWidth && constraints.maxWidth.isFinite ? constraints.maxWidth : widget.width;
            final maxH = constraints.hasBoundedHeight && constraints.maxHeight.isFinite ? constraints.maxHeight : widget.height;
            final chartWidth = widget.width > 0 ? math.min(widget.width, maxW) : maxW;
            final chartHeight = widget.height > 0 ? math.min(widget.height, maxH) : maxH;

            // Calculate chartArea identically to the painter
            final chartArea = Rect.fromLTWH(
              widget.style.padding.left,
              widget.style.padding.top,
              chartWidth - widget.style.padding.horizontal,
              chartHeight - widget.style.padding.vertical,
            );

            // If the pointer is already inside when layout changes (e.g., window resize),
            // recompute active tooltip to keep hover in sync without extra mouse movement.
            if (_tooltipPosition != null && widget.interactive) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final result = _computeActiveTooltip(chartArea, _tooltipPosition!);
                if (result.tooltip != _activeHtmlTooltip || result.position != _activeTooltipPosition) {
                  setState(() {
                    _activeHtmlTooltip = result.tooltip;
                    _activeTooltipPosition = result.position;
                  });
                }
              });
            }

            return SizedBox(
              width: chartWidth,
              height: chartHeight,
              child: MouseRegion(
                onHover: widget.interactive
                    ? (event) => setState(() {
                          _tooltipPosition = event.localPosition;
                          _updateActiveTooltip(chartArea, event.localPosition);
                        })
                    : null,
                onExit: widget.interactive
                    ? (_) => setState(() {
                          _tooltipPosition = null;
                          _activeHtmlTooltip = null;
                          _activeTooltipPosition = null;
                        })
                    : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Chart canvas
                    Container(
                      width: chartWidth,
                      height: chartHeight,
                      color: widget.style.backgroundColor,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, _) {
                          return CustomPaint(
                            size: Size(chartWidth, chartHeight),
                            painter: AreaChartPainter(
                              series: widget.series,
                              progress: _animation.value,
                              seriesAnimationProgress: _seriesAnimationProgress,
                              segmentAnimationProgress: _segmentAnimationProgress,
                              style: widget.style,
                              tooltipPosition: _tooltipPosition,
                            ),
                          );
                        },
                      ),
                    ),

                    // HTML tooltip overlay
                    if (_activeHtmlTooltip != null && _activeTooltipPosition != null) _buildHtmlTooltip(chartWidth, chartHeight),
                  ],
                ),
              ),
            );
          },
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

  /// Pure hit-test for key event markers; returns matched tooltip and its position.
  _TooltipHit _computeActiveTooltip(Rect chartArea, Offset pointerPosition) {
    if (!widget.style.showKeyEventMarkers) {
      return const _TooltipHit(null, null);
    }

    final config = widget.style.keyEventMarkerConfig ?? const KeyEventMarkerConfig();

    // Check all series for key events
    for (final seriesData in widget.series) {
      final points = _getSeriesPoints(chartArea, seriesData);

      for (int i = 0; i < seriesData.dataPoints.length; i++) {
        final dataPoint = seriesData.dataPoints[i];
        if (dataPoint.keyEvent == null || !dataPoint.keyEvent!.hasHtmlContent) continue;

        if (i >= points.length) continue;

        final keyEvent = dataPoint.keyEvent!;
        final markerSize = keyEvent.markerSize ?? config.size;
        final verticalOffset = keyEvent.verticalOffset ?? config.verticalOffset;

        // Use marker size as hover radius to match painter behavior
        final hoverRadius = markerSize / 2;

        final markerOffset = Offset(
          points[i].dx,
          points[i].dy - verticalOffset,
        );

        final distance = (markerOffset - pointerPosition).distance;
        if (distance <= hoverRadius) {
          return _TooltipHit(keyEvent, markerOffset);
        }
      }
    }

    return const _TooltipHit(null, null);
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
      ),
    );
  }

  /// replicating the way the data painters are drawn
  List<Offset> _getSeriesPoints(Rect chartArea, AreaChartSeries seriesData) {
    if (seriesData.dataPoints.isEmpty) return [];
    final seriesIndex = widget.series.indexOf(seriesData);
    if (seriesIndex == -1) return [];

    final count = _getRenderedPointCount(seriesData);
    return List.generate(count, (i) {
      final x = _getXCoordinate(chartArea, i, seriesData.dataPoints.length);
      final value = widget.style.stacked ? _getStackedValue(seriesIndex, i) : seriesData.dataPoints[i].value;
      final y = _mapValueToY(chartArea, value);
      return Offset(x, y);
    });
  }

  int _getRenderedPointCount(AreaChartSeries seriesData) {
    final slots = widget.style.xSpanSlots;
    return slots == null ? seriesData.dataPoints.length : math.min(seriesData.dataPoints.length, slots);
  }

  double _getXCoordinate(Rect chartArea, int index, int totalPoints) {
    final slots = widget.style.xSpanSlots ?? totalPoints;
    final denom = (slots - 1) <= 0 ? 1 : (slots - 1);
    return chartArea.left + (chartArea.width / denom) * index;
  }

  double _getStackedValue(int seriesIndex, int pointIndex) {
    double total = 0.0;
    for (int i = seriesIndex; i < widget.series.length; i++) {
      final seriesData = widget.series[i];
      if (pointIndex < _getRenderedPointCount(seriesData)) {
        total += seriesData.dataPoints[pointIndex].value;
      }
    }
    return total;
  }

  double _mapValueToY(Rect chartArea, double value) {
    final maxValue = _getMaxValue();
    final minValue = _getMinValue();
    final valueRange = maxValue - minValue;
    if (valueRange == 0) {
      return chartArea.top + chartArea.height / 2;
    }
    final normalizedValue = (value - minValue) / valueRange;
    return chartArea.bottom - (normalizedValue * chartArea.height);
  }

  double _getMaxValue() {
    final values = _collectVisibleValues();
    return values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
  }

  double _getMinValue() {
    if (widget.style.forceYAxisFromZero) return 0.0;
    final values = _collectVisibleValues();
    return values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
  }

  List<double> _collectVisibleValues() {
    if (!widget.style.stacked) {
      return widget.series.expand((seriesData) {
        final takeCount = _getRenderedPointCount(seriesData);
        return seriesData.dataPoints.take(takeCount).map((point) => point.value);
      }).toList();
    }

    final values = <double>[0.0];
    final maxCount = widget.series.fold<int>(0, (maxCount, seriesData) => math.max(maxCount, _getRenderedPointCount(seriesData)));

    for (int pointIndex = 0; pointIndex < maxCount; pointIndex++) {
      double cumulative = 0.0;
      values.add(cumulative);
      for (int seriesIndex = widget.series.length - 1; seriesIndex >= 0; seriesIndex--) {
        final seriesData = widget.series[seriesIndex];
        if (pointIndex < _getRenderedPointCount(seriesData)) {
          cumulative += seriesData.dataPoints[pointIndex].value;
          values.add(cumulative);
        }
      }
    }

    return values;
  }
}

/// Simple tuple for tooltip hit results
class _TooltipHit {
  final KeyEventData? tooltip;
  final Offset? position;
  const _TooltipHit(this.tooltip, this.position);
}
