import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'models.dart';
import 'painter.dart';

/// A stateful widget that represents a material design bar chart with rotation support.
///
/// This widget allows customization of the bar chart's appearance,
/// interactions, animations, and rotation. It is capable of displaying data
/// dynamically with smooth animation and supports professional chart orientations
/// like Plotly (vertical, horizontal, and custom rotations).
class MaterialBarChart extends StatefulWidget {
  final List<BarChartData> data; // The data points for the bar chart
  final double width; // Width of the chart
  final double height; // Height of the chart
  final BarChartStyle style; // Styling options for the chart
  final bool showGrid; // Flag to display grid lines
  final bool showValues; // Flag to display bar values
  final EdgeInsets padding; // Padding around the chart
  final int horizontalGridLines; // Number of horizontal grid lines
  final VoidCallback?
      onAnimationComplete; // Callback for when animation finishes
  final bool interactive; // Enable hover/tap interactions
  final bool showTooltip; // Show tooltip on hover
  final Color? tooltipBackgroundColor; // Tooltip background color
  final TextStyle? tooltipTextStyle; // Tooltip text style
  final double tooltipPadding; // Tooltip inner padding
  final double tooltipRadius; // Tooltip corner radius

  /// Creates an instance of [MaterialBarChart].
  const MaterialBarChart({
    super.key,
    required this.data,
    required this.width,
    required this.height,
    this.style = const BarChartStyle(),
    this.showGrid = true,
    this.showValues = true,
    this.padding = const EdgeInsets.all(24),
    this.horizontalGridLines = 5,
    this.onAnimationComplete,
    this.interactive = true,
    this.showTooltip = false,
    this.tooltipBackgroundColor,
    this.tooltipTextStyle,
    this.tooltipPadding = 6.0,
    this.tooltipRadius = 6.0,
  });

  /// Creates a [MaterialBarChart] from JSON configuration.
  /// Supports both simple and Plotly-compatible formats including rotation.
  ///
  /// Example JSON with rotation:
  /// ```json
  /// {
  ///   "data": [
  ///     {"x": "A", "y": 10},
  ///     {"x": "B", "y": 20}
  ///   ],
  ///   "style": {
  ///     "rotation": 90  // or use "orientation": "h" for Plotly compatibility
  ///   }
  /// }
  /// ```
  factory MaterialBarChart.fromJson(Map<String, dynamic> json) {
    final config = BarChartJsonConfig.fromJson(json);
    return MaterialBarChart(
      data: config.getBarChartData(),
      width: config.width,
      height: config.height,
      style: config.getBarChartStyle(),
      showGrid: config.showGrid,
      showValues: config.showValues,
      padding: config.padding,
      horizontalGridLines: config.horizontalGridLines,
      interactive: config.interactive,
      onAnimationComplete: config.onAnimationComplete,
    );
  }

  /// Creates a [MaterialBarChart] from a JSON string.
  factory MaterialBarChart.fromJsonString(String jsonString) {
    final config = BarChartJsonConfig.fromJsonString(jsonString);
    return MaterialBarChart(
      data: config.getBarChartData(),
      width: config.width,
      height: config.height,
      style: config.getBarChartStyle(),
      showGrid: config.showGrid,
      showValues: config.showValues,
      padding: config.padding,
      horizontalGridLines: config.horizontalGridLines,
      interactive: config.interactive,
      onAnimationComplete: config.onAnimationComplete,
    );
  }

  /// Creates a [MaterialBarChart] from Plotly-compatible data arrays.
  /// Supports Plotly's orientation parameter ('v' or 'h').
  ///
  /// Example:
  /// ```dart
  /// MaterialBarChart.fromPlotly(
  ///   x: ['A', 'B', 'C'],
  ///   y: [10, 20, 15],
  ///   orientation: 'h', // horizontal bars (90 degree rotation)
  /// )
  /// ```
  factory MaterialBarChart.fromPlotly({
    Key? key,
    required List<String> x,
    required List<double> y,
    List<String>? colors,
    String orientation = 'v', // 'v' for vertical, 'h' for horizontal
    Map<String, dynamic>? style,
    double width = 800,
    double height = 400,
    bool showGrid = true,
    bool showValues = true,
    EdgeInsets padding = const EdgeInsets.all(24),
    int horizontalGridLines = 5,
    bool interactive = true,
    VoidCallback? onAnimationComplete,
  }) {
    final data = <BarChartData>[];

    for (int i = 0; i < x.length; i++) {
      Color? color;
      if (colors != null && i < colors.length) {
        color = BarChartData.parseColor(colors[i]);
      }

      data.add(BarChartData(value: y[i], label: x[i], color: color));
    }

    // Merge orientation with style
    final styleMap =
        style != null ? Map<String, dynamic>.from(style) : <String, dynamic>{};
    styleMap['orientation'] = orientation;

    final chartStyle = BarChartStyle.fromJson(styleMap);

    return MaterialBarChart(
      key: key,
      data: data,
      width: width,
      height: height,
      style: chartStyle,
      showGrid: showGrid,
      showValues: showValues,
      padding: padding,
      horizontalGridLines: horizontalGridLines,
      interactive: interactive,
      onAnimationComplete: onAnimationComplete,
    );
  }

  /// Creates a [MaterialBarChart] from simple data arrays.
  /// This is a convenience constructor for quick chart creation with optional rotation.
  ///
  /// Example:
  /// ```dart
  /// MaterialBarChart.fromData(
  ///   labels: ['A', 'B', 'C'],
  ///   values: [10, 20, 15],
  ///   rotation: 90, // Optional: rotate chart 90 degrees
  /// )
  /// ```
  factory MaterialBarChart.fromData({
    Key? key,
    required List<String> labels,
    required List<double> values,
    List<String>? colors,
    Map<String, dynamic>? style,
    double? rotation, // Custom rotation in degrees
    double width = 800,
    double height = 400,
    bool showGrid = true,
    bool showValues = true,
    EdgeInsets padding = const EdgeInsets.all(24),
    int horizontalGridLines = 5,
    bool interactive = true,
    VoidCallback? onAnimationComplete,
  }) {
    final data = <BarChartData>[];

    for (int i = 0; i < labels.length; i++) {
      Color? color;
      if (colors != null && i < colors.length) {
        color = BarChartData.parseColor(colors[i]);
      }

      data.add(BarChartData(value: values[i], label: labels[i], color: color));
    }

    // Merge rotation with style if provided
    final styleMap =
        style != null ? Map<String, dynamic>.from(style) : <String, dynamic>{};
    if (rotation != null) {
      styleMap['rotation'] = rotation;
    }

    final chartStyle = BarChartStyle.fromJson(styleMap);

    return MaterialBarChart(
      key: key,
      data: data,
      width: width,
      height: height,
      style: chartStyle,
      showGrid: showGrid,
      showValues: showValues,
      padding: padding,
      horizontalGridLines: horizontalGridLines,
      interactive: interactive,
      onAnimationComplete: onAnimationComplete,
    );
  }

  @override
  State<MaterialBarChart> createState() => MaterialBarChartState();
}

class MaterialBarChartState extends State<MaterialBarChart>
    with TickerProviderStateMixin {
  late AnimationController _controller; // Controller for the animation
  late Animation<double> _animation; // Animation for the chart
  Offset? _hoverPosition; // Position of the mouse hover
  late List<double> _barAnimationProgress; // Per-bar animation progress values
  final Set<int> _manuallyTriggeredOrders = {}; // Animation orders that have been manually triggered
  final Map<int, DateTime> _manualTriggerStartTime = {}; // Tracks when each manual bar was triggered
  final Set<int> _reversedAnimationOrders = {}; // Animation orders currently being reversed
  final Map<int, DateTime> _reverseStartTime = {}; // Tracks when each reverse animation started
  Ticker? _manualBarTicker; // Separate ticker for updating manual bars
  @override
  void initState() {
    super.initState();
    _initializeBarAnimationProgress();
    _setupAnimation(); // Set up the animation
  }

  /// Initializes the bar animation progress list with zeros.
  void _initializeBarAnimationProgress() {
    _barAnimationProgress = List<double>.filled(widget.data.length, 0.0);
  }

  /// Configures the animation for the chart rendering.
  void _setupAnimation() {
    _controller = AnimationController(
      duration: _calculateTotalAnimationDuration(),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    )..addListener(() {
        _updateBarAnimationProgress();
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete
              ?.call(); // Callback when animation completes
        }
      });

    _controller.forward(); // Start the animation
  }

  /// Calculates the total animation duration considering all bar animations.
  Duration _calculateTotalAnimationDuration() {
    if (widget.data.isEmpty) return widget.style.animationDuration;

    double totalDurationMs = 0;
    final animationsByOrder = <int, List<int>>{};

    // Group bar indices by animation order
    for (int i = 0; i < widget.data.length; i++) {
      final order =
          widget.data[i].animationConfig?.animationOrder ?? 0;
      animationsByOrder.putIfAbsent(order, () => []).add(i);
    }

    // Get sorted orders
    final sortedOrders = animationsByOrder.keys.toList()..sort();

    for (int i = 0; i < sortedOrders.length; i++) {
      final order = sortedOrders[i];
      final barsInOrder = animationsByOrder[order]!;

      // Duration for this animation set
      final maxBarDuration = barsInOrder.fold<Duration>(
        Duration.zero,
        (max, barIndex) {
          final config = widget.data[barIndex].animationConfig;
          final duration = config?.duration ?? widget.style.animationDuration;
          return duration > max ? duration : max;
        },
      );

      totalDurationMs += maxBarDuration.inMilliseconds.toDouble();

      // Add delay before next animation group if not the last
      if (i < sortedOrders.length - 1) {
        final nextOrderBars = animationsByOrder[sortedOrders[i + 1]]!;
        final delay = nextOrderBars.fold<Duration>(
          Duration.zero,
          (max, barIndex) {
            final config = widget.data[barIndex].animationConfig;
            final delayBeforeNext = config?.delayBeforeNext ??
                widget.style.defaultDelayBeforeNext;
            return delayBeforeNext > max ? delayBeforeNext : max;
          },
        );
        totalDurationMs += delay.inMilliseconds.toDouble();
      }
    }

    return Duration(milliseconds: totalDurationMs.toInt());
  }

  /// Updates the animation progress for each bar based on the current animation value.
  /// Handles both automatic and manually triggered animations.
  void _updateBarAnimationProgress() {
    final currentTimeMs = _animation.value * _controller.duration!.inMilliseconds;
    final now = DateTime.now();
    final animationsByOrder = <int, List<int>>{};

    // Group bar indices by animation order
    for (int i = 0; i < widget.data.length; i++) {
      final order =
          widget.data[i].animationConfig?.animationOrder ?? 0;
      animationsByOrder.putIfAbsent(order, () => []).add(i);
    }

    // Get sorted orders
    final sortedOrders = animationsByOrder.keys.toList()..sort();

    double elapsedTimeMs = 0;

    for (int orderIndex = 0; orderIndex < sortedOrders.length; orderIndex++) {
      final order = sortedOrders[orderIndex];
      final barsInOrder = animationsByOrder[order]!;

      // Check if any bar in this order is manual
      bool hasManualTrigger = false;
      for (final barIndex in barsInOrder) {
        final config = widget.data[barIndex].animationConfig;
        final trigger = config?.animationTrigger ?? BarAnimationTrigger.afterDelay;
        if (trigger == BarAnimationTrigger.manual) {
          hasManualTrigger = true;
          break;
        }
      }

      // If manual and not triggered, skip this order
      if (hasManualTrigger && !_manuallyTriggeredOrders.contains(order)) {
        elapsedTimeMs += _getOrderDuration(order).inMilliseconds.toDouble();
        continue;
      }

      // Duration for this animation set (max duration of bars in this order)
      final maxBarDuration = barsInOrder.fold<Duration>(
        Duration.zero,
        (max, barIndex) {
          final config = widget.data[barIndex].animationConfig;
          final duration = config?.duration ?? widget.style.animationDuration;
          return duration > max ? duration : max;
        },
      );

      final orderStartTimeMs = elapsedTimeMs;
      final orderEndTimeMs = orderStartTimeMs + maxBarDuration.inMilliseconds;

      // Update progress for each bar in this order
      for (final barIndex in barsInOrder) {
        final config = widget.data[barIndex].animationConfig;
        final barDuration =
            config?.duration ?? widget.style.animationDuration;
        final curve = config?.curve ?? widget.style.animationCurve;
        final trigger = config?.animationTrigger ?? BarAnimationTrigger.afterDelay;

        double progress = 0.0;

        if (trigger == BarAnimationTrigger.manual && _manuallyTriggeredOrders.contains(order)) {
          if (_reversedAnimationOrders.contains(order)) {
            // Reverse animation: go from 1.0 back to 0.0
            final reverseTime = _reverseStartTime[order];
            if (reverseTime != null) {
              final elapsedMs = now.difference(reverseTime).inMilliseconds.toDouble();
              final reverseProgress = (elapsedMs / barDuration.inMilliseconds).clamp(0.0, 1.0);
              progress = 1.0 - reverseProgress;

              // If reverse animation is complete, remove from tracking
              if (reverseProgress >= 1.0) {
                _manuallyTriggeredOrders.remove(order);
                _manualTriggerStartTime.remove(order);
                _reversedAnimationOrders.remove(order);
                _reverseStartTime.remove(order);
              }
            }
          } else {
            // Forward animation: go from 0.0 to 1.0
            final triggerTime = _manualTriggerStartTime[order];
            if (triggerTime != null) {
              final elapsedMs = now.difference(triggerTime).inMilliseconds.toDouble();
              progress = (elapsedMs / barDuration.inMilliseconds).clamp(0.0, 1.0);
            }
          }
        } else {
          // Use animation controller time for auto animations
          if (currentTimeMs < orderStartTimeMs) {
            // Animation hasn't started yet
            progress = 0.0;
          } else if (currentTimeMs >= orderEndTimeMs) {
            // Animation is complete
            progress = 1.0;
          } else {
            // Animation is in progress
            final barProgress =
                (currentTimeMs - orderStartTimeMs) / barDuration.inMilliseconds;
            progress = barProgress.clamp(0.0, 1.0);
          }
        }

        _barAnimationProgress[barIndex] = curve.transform(progress);
      }

      // Add delay time for next animation group
      elapsedTimeMs = orderEndTimeMs;
      if (orderIndex < sortedOrders.length - 1) {
        final nextOrderBars = animationsByOrder[sortedOrders[orderIndex + 1]]!;
        final delay = nextOrderBars.fold<Duration>(
          Duration.zero,
          (max, barIndex) {
            final config = widget.data[barIndex].animationConfig;
            final delayBeforeNext = config?.delayBeforeNext ??
                widget.style.defaultDelayBeforeNext;
            return delayBeforeNext > max ? delayBeforeNext : max;
          },
        );
        elapsedTimeMs += delay.inMilliseconds.toDouble();
      }
    }
    
    // Start/stop manual ticker as needed
    bool hasActiveManualAnimations = false;
    for (final order in _manuallyTriggeredOrders) {
      if (!_reversedAnimationOrders.contains(order) && animationsByOrder.containsKey(order)) {
        for (final barIndex in animationsByOrder[order]!) {
          if (_barAnimationProgress[barIndex] < 1.0) {
            hasActiveManualAnimations = true;
            break;
          }
        }
      }
    }

    // Check for active reverse animations
    if (!hasActiveManualAnimations) {
      for (final order in _reversedAnimationOrders) {
        if (animationsByOrder.containsKey(order)) {
          for (final barIndex in animationsByOrder[order]!) {
            if (_barAnimationProgress[barIndex] > 0.0) {
              hasActiveManualAnimations = true;
              break;
            }
          }
        }
      }
    }

    if (hasActiveManualAnimations && _manualBarTicker == null) {
      _manualBarTicker = createTicker((_) {
        if (mounted) {
          setState(() {
            _updateBarAnimationProgress();
          });
        }
      });
      _manualBarTicker!.start();
    } else if (!hasActiveManualAnimations && _manualBarTicker != null) {
      _manualBarTicker!.dispose();
      _manualBarTicker = null;
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
  }

  /// Gets the total duration for a specific animation order.
  Duration _getOrderDuration(int order) {
    double durationMs = 0;
    for (int i = 0; i < widget.data.length; i++) {
      final config = widget.data[i].animationConfig;
      if ((config?.animationOrder ?? 0) == order) {
        final duration = config?.duration ?? widget.style.animationDuration;
        durationMs = (durationMs > duration.inMilliseconds ? durationMs : duration.inMilliseconds).toDouble();
      }
    }
    return Duration(milliseconds: durationMs.toInt());
  }

  @override
  void didUpdateWidget(MaterialBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Restart animation if data or style changes significantly
    if (oldWidget.data != widget.data ||
        oldWidget.style.rotation != widget.style.rotation) {
      _initializeBarAnimationProgress();
      _controller.reset();
      _controller.duration = _calculateTotalAnimationDuration();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualBarTicker?.dispose();
    super.dispose();
  }

  /// Triggers animation for a specific animation order.
  /// 
  /// This method marks the given [animationOrder] as manually triggered,
  /// allowing animations with [BarAnimationTrigger.manual] type to start.
  /// Animations respect order dependencies - an animation won't start
  /// until all previous orders have completed.
  /// 
  /// Example:
  /// ```dart
  /// final globalKey = GlobalKey<MaterialBarChartState>();
  /// 
  /// // In your chart widget
  /// MaterialBarChart(
  ///   key: globalKey,
  ///   data: [...],
  ///   style: [...],
  /// )
  /// 
  /// // Trigger animation order 0
  /// globalKey.currentState?.triggerAnimation(0);
  /// ```
  void triggerAnimation(int animationOrder) {
    _manuallyTriggeredOrders.add(animationOrder);
    
    // Record the wall clock time when this bar was triggered
    _manualTriggerStartTime[animationOrder] = DateTime.now();
    
    // Immediately update to detect the new manual bar and start the ticker
    _updateBarAnimationProgress();
    
    if (mounted) {
      setState(() {});
    }
  }

  /// Resets (reverses) a manually triggered animation with a smooth animation.
  /// 
  /// This smoothly animates the bar back to its original state, making it
  /// disappear gradually over the same duration as the forward animation.
  /// 
  /// Example:
  /// ```dart
  /// // Reset animation order 0
  /// globalKey.currentState?.resetAnimation(0);
  /// ```
  void resetAnimation(int animationOrder) {
    // Only reverse if this animation order was actually triggered
    if (_manuallyTriggeredOrders.contains(animationOrder)) {
      _reversedAnimationOrders.add(animationOrder);
      _reverseStartTime[animationOrder] = DateTime.now();
      
      // Update to start the reverse animation
      _updateBarAnimationProgress();
      
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: widget.interactive ? _handleHover : null, // Handle hover events
      onExit: widget.interactive
          ? (_) => setState(
                () => _hoverPosition = null,
              ) // Clear hover position on exit
          : null,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: widget.style.backgroundColor,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return CustomPaint(
              size: Size(widget.width, widget.height),
              painter: BarChartPainter(
                data: widget.data,
                progress: _animation.value,
                barAnimationProgress: List<double>.from(_barAnimationProgress),
                style: widget.style,
                showGrid: widget.showGrid,
                showValues: widget.showValues,
                padding: widget.padding,
                horizontalGridLines: widget.horizontalGridLines,
                hoverPosition: _hoverPosition,
                  showTooltip: widget.showTooltip,
                  tooltipBackgroundColor: widget.tooltipBackgroundColor,
                  tooltipTextStyle: widget.tooltipTextStyle,
                  tooltipPadding: widget.tooltipPadding,
                  tooltipRadius: widget.tooltipRadius,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Handles hover events over the bar chart to update the hovered bar index.
  void _handleHover(PointerHoverEvent event) {
    if (!widget.interactive) return;
    setState(() => _hoverPosition = event.localPosition);
  }
}
