import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'models.dart';
import 'painter.dart';

/// A widget that displays a multi-line chart with interactive features.
///
/// This chart can display multiple series of data and supports features
/// like zooming, panning, and tapping on individual data points. The
/// appearance of the chart can be customized using the [MultiLineChartStyle]
/// configuration.
class MultiLineChart extends StatefulWidget {
  final List<ChartSeries>
      series; // The data series to be displayed in the chart.
  final MultiLineChartStyle style; // The styling configuration for the chart.
  final double? height; // Optional height for the chart.
  final double? width; // Optional width for the chart.
  final ValueChanged<ChartDataPoint>?
      onPointTap; // Callback for when a point is tapped.
  final ValueChanged<Offset>?
      onChartTap; // Callback for when the chart is tapped.
  final bool enableZoom; // Flag to enable zoom functionality.
  final bool enablePan; // Flag to enable panning functionality.

  /// Creates a [MultiLineChart] widget.
  ///
  /// All parameters are required except for height, width, onPointTap,
  /// and onChartTap, which are optional. Zoom and pan functionalities are
  /// disabled by default.
  const MultiLineChart({
    super.key,
    required this.series,
    required this.style,
    this.height,
    this.width,
    this.onPointTap,
    this.onChartTap,
    this.enableZoom = false,
    this.enablePan = false,
  });

  /// Creates a [MultiLineChart] from JSON configuration.
  /// Supports both simple and Plotly-compatible formats.
  factory MultiLineChart.fromJson(Map<String, dynamic> json) {
    final config = MultiLineChartJsonConfig.fromJson(json);
    return MultiLineChart(
      series: config.series,
      style: config.style,
      height: config.height,
      width: config.width,
      onPointTap: config.onPointTap,
      onChartTap: config.onChartTap,
      enableZoom: config.enableZoom,
      enablePan: config.enablePan,
    );
  }

  /// Creates a [MultiLineChart] from a JSON string.
  /// Supports both simple and Plotly-compatible formats.
  factory MultiLineChart.fromJsonString(String jsonString) {
    final config = MultiLineChartJsonConfig.fromJsonString(jsonString);
    return MultiLineChart(
      series: config.series,
      style: config.style,
      height: config.height,
      width: config.width,
      onPointTap: config.onPointTap,
      onChartTap: config.onChartTap,
      enableZoom: config.enableZoom,
      enablePan: config.enablePan,
    );
  }

  /// Creates a [MultiLineChart] from simple data arrays.
  /// This is a convenience constructor for quick chart creation.
  factory MultiLineChart.fromData({
    required List<String> labels,
    required List<List<double>> seriesData,
    required List<String> seriesNames,
    Map<String, dynamic>? style,
    double? width,
    double? height,
    List<Color>? colors,
    bool enableZoom = false,
    bool enablePan = false,
    ValueChanged<ChartDataPoint>? onPointTap,
    ValueChanged<Offset>? onChartTap,
  }) {
    final series = <ChartSeries>[];

    for (int i = 0; i < seriesData.length && i < seriesNames.length; i++) {
      final dataPoints = <ChartDataPoint>[];
      final values = seriesData[i];

      for (int j = 0; j < labels.length && j < values.length; j++) {
        dataPoints.add(ChartDataPoint(value: values[j], label: labels[j]));
      }

      series.add(
        ChartSeries(
          name: seriesNames[i],
          dataPoints: dataPoints,
          color: colors != null && i < colors.length ? colors[i] : null,
        ),
      );
    }

    final defaultColors = colors ??
        [
          Colors.blue,
          Colors.red,
          Colors.green,
          Colors.orange,
          Colors.purple,
          Colors.teal,
          Colors.pink,
          Colors.indigo,
        ];

    final chartStyle = style != null
        ? MultiLineChartStyle.fromJson({
            ...style,
            'colors': defaultColors
                .map(
                  (c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}',
                )
                .toList(),
          })
        : MultiLineChartStyle(colors: defaultColors);

    return MultiLineChart(
      series: series,
      style: chartStyle,
      width: width,
      height: height,
      enableZoom: enableZoom,
      enablePan: enablePan,
      onPointTap: onPointTap,
      onChartTap: onChartTap,
    );
  }

  /// Creates a [MultiLineChart] with Plotly-style data format.
  /// This constructor makes it easy to use Plotly JSON data directly.
  factory MultiLineChart.fromPlotlyData({
    required List<Map<String, dynamic>> data,
    Map<String, dynamic>? layout,
    double? width,
    double? height,
    bool enableZoom = false,
    bool enablePan = false,
    ValueChanged<ChartDataPoint>? onPointTap,
    ValueChanged<Offset>? onChartTap,
  }) {
    final plotlyJson = {
      'data': data,
      if (layout != null) 'layout': layout,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      'enableZoom': enableZoom,
      'enablePan': enablePan,
    };

    return MultiLineChart.fromJson(plotlyJson);
  }

  @override
  MultiLineChartState createState() => MultiLineChartState();
}

class MultiLineChartState extends State<MultiLineChart>
    with TickerProviderStateMixin {
  late AnimationController _controller; // Controller for managing animations.
  late Animation<double>
      _animation; // Animation object for controlling the animation progress.
  Offset? _crosshairPosition; // Current position of the crosshair.
  double _scale = 1.0; // Current scale factor for zooming.
  Offset _panOffset = Offset.zero; // Current offset for panning.
  Offset? _lastFocalPoint; // Last focal point for scaling gestures.
  Size? _containerSize; // Size of the chart container.
  List<double> _lineAnimationProgress = []; // Per-line animation progress
  Map<int, double> _segmentAnimationProgress = {}; // Per-segment animation progress
  final Set<int> _manuallyTriggeredOrders = {}; // Animation orders that have been manually triggered
  final Map<int, DateTime> _manualTriggerStartTime = {}; // Tracks when each manual segment was triggered (wall clock time)
  Ticker? _manualSegmentTicker; // Separate ticker for updating manual segments

  @override
  void initState() {
    super.initState();
    _setupAnimation(); // Initializes the animation controller and starts the animation.
  }

  void _setupAnimation() {
    // Calculate total animation duration based on line animation configurations
    final totalDuration = _calculateTotalAnimationDuration();
    
    _controller = AnimationController(
      vsync: this,
      duration: totalDuration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.style.animation.curve,
    );

    // Listen to animation changes to update per-line progress
    _controller.addListener(() {
      _updateLineAnimationProgress();
    });

    // Initialize animation progress before first paint to avoid a one-frame flash
    // where lines could appear fully rendered.
    _updateLineAnimationProgress();

    // Start the animation if enabled; otherwise, set it to fully completed.
    if (widget.style.animation.enabled) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
      _updateLineAnimationProgress();
    }
  }

  /// Calculates the total animation duration based on individual line configurations
  Duration _calculateTotalAnimationDuration() {
    int lineDurationMs = 0;
    int segmentDurationMs = 0;
    
    // Calculate line animation duration (existing logic)
    // Group lines by animation order
    final linesByOrder = <int, List<int>>{};
    
    for (int i = 0; i < widget.series.length; i++) {
      final config = widget.series[i].animationConfig;
      final order = config?.animationOrder ?? 0;
      
      if (!linesByOrder.containsKey(order)) {
        linesByOrder[order] = [];
      }
      linesByOrder[order]!.add(i);
    }
    
    // Sort orders
    final sortedOrders = linesByOrder.keys.toList()..sort();
    
    // Calculate timing for each order group
    for (final order in sortedOrders) {
      int groupDuration = 0;
      int nextDelay = 0;
      
      // Find max duration in this order group
      for (final lineIndex in linesByOrder[order]!) {
        final config = widget.series[lineIndex].animationConfig;
        final duration = config?.duration?.inMilliseconds 
            ?? widget.style.defaultAnimationDuration.inMilliseconds;
        groupDuration = max(groupDuration, duration);
        
        // Get delay for next animation
        final trigger = config?.animationTrigger ?? widget.style.defaultAnimationTrigger;
        if (trigger == LineAnimationTrigger.afterDelay) {
          nextDelay = max(nextDelay, 
              (config?.delayBeforeNext ?? widget.style.defaultDelayBeforeNext).inMilliseconds);
        }
      }
      
      lineDurationMs += groupDuration;
      
      // Only add delay if there are more orders to come
      if (sortedOrders.indexOf(order) < sortedOrders.length - 1) {
        lineDurationMs += nextDelay;
      }
    }
    
    // If no custom animations, use default duration
    if (lineDurationMs == 0) {
      lineDurationMs = widget.style.defaultAnimationDuration.inMilliseconds;
    }
    
    // Calculate segment animation duration
    final segmentConfigs = widget.style.segmentAnimationConfigs;
    if (segmentConfigs.isNotEmpty) {
      final sortedSegmentOrders = segmentConfigs.keys.toList()..sort();
      
      for (final segmentOrder in sortedSegmentOrders) {
        final config = segmentConfigs[segmentOrder]!;
        
        // Only include duration for non-manual or already-triggered manual segments
        bool shouldInclude = true;
        if (config.animationTrigger == LineAnimationTrigger.manual) {
          shouldInclude = _manuallyTriggeredOrders.contains(segmentOrder);
        }
        
        if (shouldInclude) {
          final duration = config.duration?.inMilliseconds 
              ?? widget.style.defaultSegmentAnimationDuration.inMilliseconds;
          
          segmentDurationMs += duration;
          
          // Add delay if there are more segments
          if (sortedSegmentOrders.indexOf(segmentOrder) < sortedSegmentOrders.length - 1) {
            final delay = config.delayBeforeNext.inMilliseconds;
            segmentDurationMs += delay;
          }
        }
      }
    }
    
    // Total duration is line duration + segment duration (segments start after lines complete)
    final totalMilliseconds = lineDurationMs + segmentDurationMs;
    
    return Duration(milliseconds: max(totalMilliseconds, 100));
  }

  /// Updates per-line animation progress based on current animation time
  void _updateLineAnimationProgress() {
    _lineAnimationProgress = List<double>.filled(widget.series.length, 0.0);
    _segmentAnimationProgress = {};
    
    final currentTimeMs = _controller.value * _controller.duration!.inMilliseconds;
    
    // Calculate line animation duration first
    int lineDurationMs = 0;
    
    // Group lines by animation order
    final linesByOrder = <int, List<int>>{};
    for (int i = 0; i < widget.series.length; i++) {
      final config = widget.series[i].animationConfig;
      final order = config?.animationOrder ?? 0;
      
      if (!linesByOrder.containsKey(order)) {
        linesByOrder[order] = [];
      }
      linesByOrder[order]!.add(i);
    }
    
    // Sort orders
    final sortedOrders = linesByOrder.keys.toList()..sort();
    
    // Calculate when each order group should start
    int accumulatedTimeMs = 0;
    
    for (final order in sortedOrders) {
      int groupDuration = 0;
      int nextDelay = 0;
      
      // Find max duration and delay in this group
      for (final lineIndex in linesByOrder[order]!) {
        final config = widget.series[lineIndex].animationConfig;
        final duration = config?.duration?.inMilliseconds 
            ?? widget.style.defaultAnimationDuration.inMilliseconds;
        groupDuration = max(groupDuration, duration);
        
        final trigger = config?.animationTrigger ?? widget.style.defaultAnimationTrigger;
        if (trigger == LineAnimationTrigger.afterDelay) {
          nextDelay = max(nextDelay, 
              (config?.delayBeforeNext ?? widget.style.defaultDelayBeforeNext).inMilliseconds);
        }
      }
      
      // Update progress for each line in this order group
      final groupStartTimeMs = accumulatedTimeMs;
      final groupEndTimeMs = accumulatedTimeMs + groupDuration;
      
      for (final lineIndex in linesByOrder[order]!) {
        final config = widget.series[lineIndex].animationConfig;
        final trigger = config?.animationTrigger ?? widget.style.defaultAnimationTrigger;
        
        // For manual triggers, only advance if this order has been manually triggered
        bool shouldAdvance = true;
        if (trigger == LineAnimationTrigger.manual) {
          shouldAdvance = _manuallyTriggeredOrders.contains(order);
        }
        
        if (shouldAdvance) {
          if (currentTimeMs >= groupStartTimeMs && currentTimeMs <= groupEndTimeMs) {
            final lineProgress = (currentTimeMs - groupStartTimeMs) / groupDuration;
            _lineAnimationProgress[lineIndex] = min(lineProgress, 1.0);
          } else if (currentTimeMs > groupEndTimeMs) {
            _lineAnimationProgress[lineIndex] = 1.0;
          }
        }
      }
      
      accumulatedTimeMs += groupDuration + (sortedOrders.indexOf(order) < sortedOrders.length - 1 ? nextDelay : 0);
    }
    
    lineDurationMs = accumulatedTimeMs;
    
    // Calculate segment animation progress (starts after line animations complete)
    final segmentConfigs = widget.style.segmentAnimationConfigs;
    if (segmentConfigs.isNotEmpty) {
      final sortedSegmentOrders = segmentConfigs.keys.toList()..sort();
      
      for (final segmentOrder in sortedSegmentOrders) {
        final config = segmentConfigs[segmentOrder]!;
        final duration = config.duration?.inMilliseconds 
            ?? widget.style.defaultSegmentAnimationDuration.inMilliseconds;
        
        // Check if this is a manual trigger
        final isManualTrigger = config.animationTrigger == LineAnimationTrigger.manual;
        final isTriggered = _manuallyTriggeredOrders.contains(segmentOrder);
        
        if (isManualTrigger && !isTriggered) {
          // Not yet triggered - no progress
          _segmentAnimationProgress[segmentOrder] = 0.0;
          continue;
        }
        
        // Calculate progress differently for manual vs non-manual segments
        if (isManualTrigger && _manualTriggerStartTime.containsKey(segmentOrder)) {
          // Manual segment: calculate progress based on elapsed time since trigger
          final startTime = _manualTriggerStartTime[segmentOrder]!;
          final elapsed = DateTime.now().difference(startTime).inMilliseconds.toDouble();
          
          if (elapsed <= duration) {
            final segmentProgress = elapsed / duration;
            _segmentAnimationProgress[segmentOrder] = min(segmentProgress, 1.0);
          } else {
            _segmentAnimationProgress[segmentOrder] = 1.0;
          }
        } else if (!isManualTrigger) {
          // Non-manual segment: use sequential timing based on controller timeline
          // Calculate accumulated time from all previous non-manual segments
          int accumulatedSegmentTimeMs = 0;
          for (final prevOrder in sortedSegmentOrders) {
            if (prevOrder >= segmentOrder) break;
            
            final prevConfig = segmentConfigs[prevOrder]!;
            final prevIsManual = prevConfig.animationTrigger == LineAnimationTrigger.manual;
            final prevIsTriggered = _manuallyTriggeredOrders.contains(prevOrder);
            
            // Only count non-manual or triggered segments
            if (!prevIsManual || prevIsTriggered) {
              final prevDuration = prevConfig.duration?.inMilliseconds 
                  ?? widget.style.defaultSegmentAnimationDuration.inMilliseconds;
              accumulatedSegmentTimeMs += prevDuration;
              if (prevOrder < sortedSegmentOrders.last) {
                accumulatedSegmentTimeMs += prevConfig.delayBeforeNext.inMilliseconds;
              }
            }
          }
          final segmentStartTimeMs = (lineDurationMs + accumulatedSegmentTimeMs).toDouble();
          final segmentEndTimeMs = segmentStartTimeMs + duration;
          
          // Calculate progress based on current time
          if (currentTimeMs >= segmentStartTimeMs && currentTimeMs <= segmentEndTimeMs) {
            final segmentProgress = (currentTimeMs - segmentStartTimeMs) / duration;
            _segmentAnimationProgress[segmentOrder] = min(segmentProgress, 1.0);
          } else if (currentTimeMs > segmentEndTimeMs) {
            _segmentAnimationProgress[segmentOrder] = 1.0;
          } else {
            _segmentAnimationProgress[segmentOrder] = 0.0;
          }
        }
      }
    }
    
    // Check if any manual segments are still animating
    bool hasActiveManualSegments = false;
    for (final segmentOrder in _manuallyTriggeredOrders) {
      if (_segmentAnimationProgress[segmentOrder] != null && 
          _segmentAnimationProgress[segmentOrder]! < 1.0) {
        hasActiveManualSegments = true;
        break;
      }
    }
    
    // Manage manual segment ticker
    if (hasActiveManualSegments && _manualSegmentTicker == null) {
      // Start ticker for manual segments
      _manualSegmentTicker = createTicker((_) {
        if (mounted) {
          setState(() {
            _updateLineAnimationProgress();
          });
        }
      });
      _manualSegmentTicker!.start();
    } else if (!hasActiveManualSegments && _manualSegmentTicker != null) {
      // Stop ticker if no manual segments are active
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
    
    // Update UI if animation is in progress or manual segments are active
    if (mounted && (_controller.isAnimating || hasActiveManualSegments)) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the animation controller.
    _manualSegmentTicker?.dispose(); // Dispose of the manual segment ticker.
    super.dispose();
  }

  /// Triggers animation for a specific animation order.
  /// 
  /// This method marks the given [animationOrder] as manually triggered,
  /// allowing animations with [LineAnimationTrigger.manual] type to start.
  /// Animations respect order dependencies - an animation won't start
  /// until all previous orders have completed.
  /// 
  /// Example:
  /// ```dart
  /// final globalKey = GlobalKey<MultiLineChartState>();
  /// 
  /// // In your chart widget
  /// MultiLineChart(
  ///   key: globalKey,
  ///   series: [...],
  ///   style: [...],
  /// )
  /// 
  /// // Trigger animation order 0
  /// globalKey.currentState?.triggerAnimation(0);
  /// ```
  void triggerAnimation(int animationOrder) {
    _manuallyTriggeredOrders.add(animationOrder);
    
    // Record the wall clock time when this segment was triggered
    // This allows the segment to animate independently of other animations
    _manualTriggerStartTime[animationOrder] = DateTime.now();
    
    // Immediately update to detect the new manual segment and start the ticker
    _updateLineAnimationProgress();
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = widget.width ??
            constraints.maxWidth; // Determine the width of the chart.
        final height = widget.height ??
            constraints.maxHeight; // Determine the height of the chart.
        _containerSize = Size(width, height); // Set the container size.

        return MouseRegion(
          onEnter: (_) => setState(
            () => _crosshairPosition = null,
          ), // Hide the crosshair when the mouse enters.
          onExit: (_) => setState(
            () => _crosshairPosition = null,
          ), // Hide the crosshair when the mouse exits.
          onHover: (PointerHoverEvent event) {
            setState(() {
              _crosshairPosition = event
                  .localPosition; // Update the crosshair position on hover.
            });
          },
          child: widget.enableZoom || widget.enablePan
              ? GestureDetector(
                  onScaleStart:
                      _handleScaleStart, // Handle scale start gesture.
                  onScaleUpdate:
                      _handleScaleUpdate, // Handle scale update gesture.
                  child: _buildChartContent(
                    width,
                    height,
                  ), // Build the chart content.
                )
              : _buildChartContent(
                  width,
                  height,
                ), // Just build the chart content without gestures.
        );
      },
    );
  }

  /// Builds the main content of the chart.
  ///
  /// This function creates a container that holds the chart and applies
  /// the specified background color. The chart is drawn using the
  /// CustomPaint widget with an animated painter.
  Widget _buildChartContent(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: widget
            .style.backgroundColor, // Set the background color from style.
      ),
      child: AnimatedBuilder(
        animation: _animation, // Listen for animation changes.
        builder: (context, child) {
          return CustomPaint(
            painter: MultiLineChartPainter(
              series: widget.series, // Data series for the chart.
              style: widget.style, // Style configuration for the chart.
              progress: _animation.value, // Current progress of the animation.
              crosshairPosition:
                  _crosshairPosition, // Position of the crosshair.
              scale: _scale, // Current scale factor.
              panOffset: _panOffset, // Current pan offset.
              lineAnimationProgress: _lineAnimationProgress, // Per-line animation progress.
              segmentAnimationProgress: _segmentAnimationProgress, // Per-segment animation progress.
            ),
            size: Size(
              width,
              height,
            ), // Set the size of the CustomPaint widget.
          );
        },
      ),
    );
  }

  /// Constrains the pan offset to prevent the chart from being panned
  /// beyond its bounds.
  ///
  /// Returns a constrained offset based on the current scale and
  /// the size of the container.
  Offset _constrainPanOffset(Offset offset, Size containerSize) {
    // Calculate the bounds for panning based on scale and container size.
    final scaledWidth = containerSize.width * (_scale - 1);
    final scaledHeight = containerSize.height * (_scale - 1);

    // Calculate maximum allowed pan distances.
    final maxHorizontalPan = scaledWidth / 2;
    final maxVerticalPan = scaledHeight / 2;

    return Offset(
      offset.dx.clamp(-maxHorizontalPan, maxHorizontalPan),
      offset.dy.clamp(-maxVerticalPan, maxVerticalPan),
    );
  }

  /// Handles the start of a scaling gesture.
  ///
  /// Stores the focal point to calculate deltas during scaling.
  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint; // Store the focal point.
  }

  /// Handles updates during scaling gestures.
  ///
  /// Updates the scale factor and pan offset based on user interactions.
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (widget.enableZoom) {
        // Update scale first, clamping it to the defined limits.
        final newScale = (_scale * details.scale).clamp(
          1.0,
          3.0,
        ); // Minimum scale is 1.0, maximum is 3.0.
        _scale = newScale;
      }

      if (widget.enablePan && _lastFocalPoint != null) {
        // Calculate the pan delta based on the focal point.
        final delta = details.focalPoint - _lastFocalPoint!;

        // Update pan offset with constraints.
        final newPanOffset = _panOffset + delta;
        _panOffset = _constrainPanOffset(newPanOffset, _containerSize!);

        _lastFocalPoint = details.focalPoint; // Update the last focal point.
      }
    });
  }
}
