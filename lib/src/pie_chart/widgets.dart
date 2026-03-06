import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'models.dart';
import 'painter.dart';

/// A stateful widget that displays a customizable pie chart with optional animations.
///
/// The [MaterialPieChart] takes a list of [PieChartData], dimensions, style settings,
/// padding, and a callback for when the animation completes.
class MaterialPieChart extends StatefulWidget {
  /// The data points to be represented in the pie chart.
  final List<PieChartData> data;

  /// Set a minimal percent size for the PieChartData representation
  final double minSizePercent;

  /// The width of the pie chart.
  final double width;

  /// The height of the pie chart.
  final double height;

  /// Style configurations for the pie chart.
  final PieChartStyle style;

  /// Padding around the pie chart.
  final EdgeInsets padding;

  /// Callback function that is invoked when the animation completes.
  final VoidCallback? onAnimationComplete;

  /// Determines whether the pie chart supports interactivity (hover effects).
  final bool interactive;

  /// Bool for showing the label only on hover
  final bool showLabelOnlyOnHover;

  /// Radius of the pie chart
  /// Started as [double.maxFinite] because it will take part in the min function
  /// at the painter class that calculates the radius
  final double chartRadius;

  /// Creates an instance of [MaterialPieChart].
  ///
  /// Requires [data], [width], and [height]. Optional parameters include [style],
  /// [padding], [onAnimationComplete], and [interactive].
  const MaterialPieChart({
    super.key,
    required this.data,
    required this.width,
    required this.height,
    this.minSizePercent = 0.0,
    this.style = const PieChartStyle(),
    this.padding = const EdgeInsets.all(24),
    this.onAnimationComplete,
    this.interactive = true,
    this.showLabelOnlyOnHover = false,
    this.chartRadius = double.maxFinite,
  });

  /// Creates a [MaterialPieChart] from JSON configuration.
  /// Supports both simple and Plotly-compatible formats.
  factory MaterialPieChart.fromJson(Map<String, dynamic> json) {
    final config = PieChartJsonConfig.fromJson(json);
    return MaterialPieChart(
      data: config.getPieChartData(),
      width: config.width,
      height: config.height,
      style: config.getPieChartStyle(),
      padding: config.padding,
      minSizePercent: config.minSizePercent,
      interactive: config.interactive,
      showLabelOnlyOnHover: config.showLabelOnlyOnHover,
      chartRadius: config.chartRadius,
      onAnimationComplete: config.onAnimationComplete,
    );
  }

  /// Creates a [MaterialPieChart] from a JSON string.
  factory MaterialPieChart.fromJsonString(String jsonString) {
    final config = PieChartJsonConfig.fromJsonString(jsonString);
    return MaterialPieChart(
      data: config.getPieChartData(),
      width: config.width,
      height: config.height,
      style: config.getPieChartStyle(),
      padding: config.padding,
      minSizePercent: config.minSizePercent,
      interactive: config.interactive,
      showLabelOnlyOnHover: config.showLabelOnlyOnHover,
      chartRadius: config.chartRadius,
      onAnimationComplete: config.onAnimationComplete,
    );
  }

  /// Creates a [MaterialPieChart] from simple data arrays.
  /// This is a convenience constructor for quick chart creation.
  factory MaterialPieChart.fromData({
    required List<String> labels,
    required List<double> values,
    List<Color>? colors,
    Map<String, dynamic>? style,
    double width = 600,
    double height = 400,
    double minSizePercent = 0.0,
    EdgeInsets padding = const EdgeInsets.all(24),
    bool interactive = true,
    bool showLabelOnlyOnHover = false,
    double chartRadius = double.maxFinite,
    VoidCallback? onAnimationComplete,
  }) {
    final data = <PieChartData>[];

    for (int i = 0; i < labels.length && i < values.length; i++) {
      data.add(
        PieChartData(
          value: values[i],
          label: labels[i],
          color: colors != null && i < colors.length ? colors[i] : null,
        ),
      );
    }

    final chartStyle =
        style != null ? PieChartStyle.fromJson(style) : const PieChartStyle();

    return MaterialPieChart(
      data: data,
      width: width,
      height: height,
      style: chartStyle,
      padding: padding,
      minSizePercent: minSizePercent,
      interactive: interactive,
      showLabelOnlyOnHover: showLabelOnlyOnHover,
      chartRadius: chartRadius,
      onAnimationComplete: onAnimationComplete,
    );
  }

  @override
  State<MaterialPieChart> createState() => MaterialPieChartState();
}

class MaterialPieChartState extends State<MaterialPieChart>
    with TickerProviderStateMixin {
  late AnimationController _controller; // Controls the animation.
  late Animation<double>
      _animation; // Represents the current progress of the animation.
  int?
      _hoveredSegmentIndex; // Holds the index of the currently hovered segment.
  List<double> _sliceAnimationProgress = []; // Per-slice animation progress
  final Set<int> _manuallyTriggeredOrders = {}; // Animation orders that have been manually triggered
  final Map<int, DateTime> _manualTriggerStartTime = {}; // Tracks when each manual slice was triggered
  final Set<int> _reversedAnimationOrders = {}; // Animation orders currently being reversed
  final Map<int, DateTime> _reverseStartTime = {}; // Tracks when each reverse animation started
  Ticker? _manualSliceTicker; // Separate ticker for updating manual slices

  @override
  void initState() {
    super.initState();
    _setupAnimation(); // Initialize the animation settings.
  }

  /// Sets up the animation controller and its animation properties.
  void _setupAnimation() {
    // Calculate total animation duration based on slice animation configurations
    final totalDuration = _calculateTotalAnimationDuration();
    
    // Create an animation controller with the calculated duration
    _controller = AnimationController(
      duration: totalDuration > Duration.zero ? totalDuration : widget.style.animationDuration,
      vsync: this, // Provides a TickerProvider for the animation.
    );

    // Create a tween animation that progresses from 0.0 to 1.0.
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget
            .style.animationCurve, // Use a customizable curve for animation.
      ),
    )..addStatusListener((status) {
        // Invoke the callback when the animation completes.
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete?.call();
        }
      });

    // Listen to animation changes to update per-slice progress
    _controller.addListener(() {
      _updateSliceAnimationProgress();
    });

    // Initialize animation progress before first paint
    _updateSliceAnimationProgress();

    // Start the animation if slice animations are enabled
    if (widget.style.sliceAnimationsEnabled) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
      _updateSliceAnimationProgress();
    }
  }
  
  /// Calculates the total animation duration based on individual slice configurations
  Duration _calculateTotalAnimationDuration() {
    if (!widget.style.sliceAnimationsEnabled) {
      return widget.style.animationDuration;
    }
    
    int totalDurationMs = 0;
    
    // Group slices by animation order
    final slicesByOrder = <int, List<int>>{};
    
    for (int i = 0; i < widget.data.length; i++) {
      final config = widget.data[i].animationConfig;
      final order = config?.animationOrder ?? 0;
      
      if (!slicesByOrder.containsKey(order)) {
        slicesByOrder[order] = [];
      }
      slicesByOrder[order]!.add(i);
    }
    
    // Sort orders
    final sortedOrders = slicesByOrder.keys.toList()..sort();
    
    // Calculate timing for each order group
    for (final order in sortedOrders) {
      int groupDuration = 0;
      int nextDelay = 0;
      
      // Find max duration in this order group
      for (final sliceIndex in slicesByOrder[order]!) {
        final config = widget.data[sliceIndex].animationConfig;
        final duration = config?.duration?.inMilliseconds 
            ?? widget.style.defaultSliceAnimationDuration.inMilliseconds;
        groupDuration = max(groupDuration, duration);
        
        // Get delay for next animation
        final trigger = config?.animationTrigger ?? widget.style.defaultSliceAnimationTrigger;
        if (trigger == SliceAnimationTrigger.afterDelay) {
          nextDelay = max(nextDelay, 
              (config?.delayBeforeNext ?? widget.style.defaultDelayBeforeNext).inMilliseconds);
        }
      }
      
      totalDurationMs += groupDuration;
      
      // Only add delay if there are more orders to come
      if (sortedOrders.indexOf(order) < sortedOrders.length - 1) {
        totalDurationMs += nextDelay;
      }
    }
    
    // If no custom animations, use default duration
    if (totalDurationMs == 0) {
      return widget.style.animationDuration;
    }
    
    return Duration(milliseconds: totalDurationMs);
  }
  
  /// Updates per-slice animation progress based on the current animation value
  void _updateSliceAnimationProgress() {
    if (!widget.style.sliceAnimationsEnabled) {
      _sliceAnimationProgress = List.filled(widget.data.length, 1.0);
      return;
    }
    
    final now = DateTime.now();
    final totalDurationMs = _controller.duration!.inMilliseconds.toDouble();
    final currentTimeMs = _controller.value * totalDurationMs;
    
    // Group slices by animation order
    final slicesByOrder = <int, List<int>>{};
    for (int i = 0; i < widget.data.length; i++) {
      final config = widget.data[i].animationConfig;
      final order = config?.animationOrder ?? 0;
      
      if (!slicesByOrder.containsKey(order)) {
        slicesByOrder[order] = [];
      }
      slicesByOrder[order]!.add(i);
    }
    
    final sortedOrders = slicesByOrder.keys.toList()..sort();
    
    // Initialize progress list
    _sliceAnimationProgress = List.filled(widget.data.length, 0.0);
    
    var accumulatedTimeMs = 0.0;
    
    for (final order in sortedOrders) {
      final slices = slicesByOrder[order]!;
      
      // Check if any slice in this order is manual
      bool hasManualTrigger = false;
      for (final sliceIndex in slices) {
        final config = widget.data[sliceIndex].animationConfig;
        final trigger = config?.animationTrigger ?? widget.style.defaultSliceAnimationTrigger;
        if (trigger == SliceAnimationTrigger.manual) {
          hasManualTrigger = true;
          break;
        }
      }
      
      // If manual and not triggered, skip this order
      if (hasManualTrigger && !_manuallyTriggeredOrders.contains(order)) {
        accumulatedTimeMs += _getOrderDuration(order);
        continue;
      }
      
      // Calculate progress for slices in this order
      final orderDuration = _getOrderDuration(order);
      
      for (final sliceIndex in slices) {
        final config = widget.data[sliceIndex].animationConfig;
        final trigger = config?.animationTrigger ?? widget.style.defaultSliceAnimationTrigger;
        final sliceDuration = (config?.duration?.inMilliseconds 
            ?? widget.style.defaultSliceAnimationDuration.inMilliseconds).toDouble();
        
        double progress = 0.0;
        
        if (trigger == SliceAnimationTrigger.manual && _manuallyTriggeredOrders.contains(order)) {
          if (_reversedAnimationOrders.contains(order)) {
            // Reverse animation: go from 1.0 back to 0.0
            final reverseTime = _reverseStartTime[order];
            if (reverseTime != null) {
              final elapsedMs = now.difference(reverseTime).inMilliseconds.toDouble();
              final reverseProgress = (elapsedMs / sliceDuration).clamp(0.0, 1.0);
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
              progress = (elapsedMs / sliceDuration).clamp(0.0, 1.0);
            }
          }
        } else {
          // Use animation controller time for auto animations
          if (currentTimeMs >= accumulatedTimeMs) {
            final timeIntoOrder = currentTimeMs - accumulatedTimeMs;
            progress = (timeIntoOrder / sliceDuration).clamp(0.0, 1.0);
          }
        }
        
        _sliceAnimationProgress[sliceIndex] = progress;
      }
      
      accumulatedTimeMs += orderDuration;
      
      // Add delay before next order if configured
      for (final sliceIndex in slices) {
        final config = widget.data[sliceIndex].animationConfig;
        final trigger = config?.animationTrigger ?? widget.style.defaultSliceAnimationTrigger;
        if (trigger == SliceAnimationTrigger.afterDelay) {
          final delay = config?.delayBeforeNext?.inMilliseconds 
              ?? widget.style.defaultDelayBeforeNext.inMilliseconds;
          accumulatedTimeMs += delay.toDouble();
          break; // Only add delay once per order
        }
      }
    }
    
    // Start manual ticker if we have any active manual animations or reverse animations
    bool hasActiveManualAnimations = false;
    
    // Check for active forward animations
    for (final order in _manuallyTriggeredOrders) {
      if (!_reversedAnimationOrders.contains(order) && slicesByOrder.containsKey(order)) {
        for (final sliceIndex in slicesByOrder[order]!) {
          if (_sliceAnimationProgress[sliceIndex] < 1.0) {
            hasActiveManualAnimations = true;
            break;
          }
        }
      }
    }
    
    // Check for active reverse animations
    if (!hasActiveManualAnimations) {
      for (final order in _reversedAnimationOrders) {
        if (slicesByOrder.containsKey(order)) {
          for (final sliceIndex in slicesByOrder[order]!) {
            if (_sliceAnimationProgress[sliceIndex] > 0.0) {
              hasActiveManualAnimations = true;
              break;
            }
          }
        }
      }
    }
    
    if (hasActiveManualAnimations && _manualSliceTicker == null) {
      _manualSliceTicker = createTicker((elapsed) {
        if (mounted) {
          setState(() {
            _updateSliceAnimationProgress();
          });
        }
      });
      _manualSliceTicker!.start();
    } else if (!hasActiveManualAnimations && _manualSliceTicker != null) {
      _manualSliceTicker!.dispose();
      _manualSliceTicker = null;
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
  
  /// Gets the duration for a specific animation order
  double _getOrderDuration(int order) {
    double maxDuration = 0.0;
    
    for (int i = 0; i < widget.data.length; i++) {
      final config = widget.data[i].animationConfig;
      if ((config?.animationOrder ?? 0) == order) {
        final duration = config?.duration?.inMilliseconds.toDouble() 
            ?? widget.style.defaultSliceAnimationDuration.inMilliseconds.toDouble();
        maxDuration = max(maxDuration, duration);
      }
    }
    
    return maxDuration;
  }
  
  /// Triggers animation for a specific animation order.
  /// 
  /// This method marks the given [animationOrder] as manually triggered,
  /// allowing animations with [SliceAnimationTrigger.manual] type to start.
  /// Animations respect order dependencies - an animation won't start
  /// until all previous orders have completed.
  /// 
  /// Example:
  /// ```dart
  /// final globalKey = GlobalKey<MaterialPieChartState>();
  /// 
  /// // In your chart widget
  /// MaterialPieChart(
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
    
    // Record the wall clock time when this slice was triggered
    _manualTriggerStartTime[animationOrder] = DateTime.now();
    
    // Immediately update to detect the new manual slice and start the ticker
    _updateSliceAnimationProgress();
    
    if (mounted) {
      setState(() {});
    }
  }

  /// Resets (reverses) a manually triggered animation with a smooth animation.
  /// 
  /// This smoothly animates the slice back to its original state, making it
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
      _updateSliceAnimationProgress();
      
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualSliceTicker?.dispose();
    super.dispose();
  }

  /// Set the size of pie slices
  ///
  /// Set the size of each pie slice based on minSizePercent,
  /// if 0, essentialy nothing is changed
  List<double> _setSizes(double total) {
    // Minimal value that all slices must have
    double minValue = total * widget.minSizePercent / 100;
    // List os all values for easy change and access
    Iterable<double> values = widget.data.map((item) => item.value);

    // Looped verification for cases where resizing sets a previously valid value
    // to a invalid one
    while (true) {
      // Quantiti of slices to scale up
      final qttToScaleUp = values.where((item) => item < minValue).length;
      // Sum of all values of valid slices
      final validTotal = values
          .where((item) => item >= minValue)
          .fold(0.0, (sum, item) => sum + item);
      // New minimal value based on reconfigured values
      final newMinValue = validTotal /
          (1 - (qttToScaleUp * widget.minSizePercent / 100)) *
          widget.minSizePercent /
          100;
      // When true, this means that all the proporsions are over the minial
      if (newMinValue == minValue) break;
      // Sets the minValue to the new one for the next loop verification
      minValue = newMinValue;
    }
    // Sets the invalid values to the minimal one
    values = values.map((item) => max(item, minValue));
    // Gets the new total for further resizing
    final newTotal = values.fold(0.0, (sum, item) => sum + item);
    // Resizes all values in proporsion to the old one
    values = values.map((item) => item * (total / newTotal));
    return values.toList();
  }

  /// Determines which segment of the pie chart is hovered based on the mouse position.
  ///
  /// Returns the index of the hovered segment or null if not hovering over any segment.
  int? _getHoveredSegment(Offset localPosition) {
    // Get outer and inner radius
    final outerRadius = [
      (widget.width - widget.padding.horizontal) / 2,
      (widget.height - widget.padding.vertical) / 2,
      widget.chartRadius,
    ].reduce(min);
    final innerRadius = outerRadius * widget.style.holeRadius;

    // Center of the pie chart
    final position = Offset(
      switch (widget.style.chartAlignment.horizontal) {
        Horizontal.center => widget.width / 2,
        Horizontal.left => outerRadius + widget.padding.left,
        Horizontal.right => widget.width - (widget.padding.right + outerRadius),
      },
      switch (widget.style.chartAlignment.vertical) {
        Vertical.center => widget.height / 2,
        Vertical.top => outerRadius + widget.padding.top,
        Vertical.bottom =>
          widget.height - (widget.padding.bottom + outerRadius),
      },
    );

    // Calculate distance from the center to the mouse position
    final dx = localPosition.dx - position.dx;
    final dy = localPosition.dy - position.dy;
    final distance = sqrt(dx * dx + dy * dy);

    // Check if the mouse is within the outer radius but outside the inner radius
    if (distance < innerRadius || distance > outerRadius) {
      return null; // Mouse is outside the pie chart area
    }

    // Calculate the angle
    var angle = atan2(dy, dx) * 180 / pi; // Convert to degrees
    angle = (angle + 360) % 360; // Normalize to [0, 360)

    // Adjust for the starting angle
    angle = (angle - widget.style.startAngle + 360) % 360;

    // Find the hovered segment
    final total = widget.data.fold(0.0, (sum, item) => sum + item.value);
    var currentAngle = 0.0;

    final sizesList = _setSizes(total);

    for (int i = 0; i < widget.data.length; i++) {
      // Calculate sweep angle using value * 3.6
      final sweepAngle = (sizesList[i] / total) * 360; // Calculate sweep angle
      if (angle >= currentAngle && angle < currentAngle + sweepAngle) {
        return i; // Return the index of the hovered segment
      }
      currentAngle += sweepAngle; // Move to the next segment
    }

    return null; // No segment found
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      // Handle mouse hover events for interactivity.
      onHover: widget.interactive
          ? (event) {
              // Get the index of the currently hovered segment based on mouse position.
              final newIndex = _getHoveredSegment(event.localPosition);
              // Update state only if the hovered segment has changed.
              if (newIndex != _hoveredSegmentIndex) {
                setState(() => _hoveredSegmentIndex = newIndex);
              }
            }
          : null,
      // Handle mouse exit events to reset the hovered segment.
      onExit: widget.interactive
          ? (_) => setState(() => _hoveredSegmentIndex = null)
          : null,
      child: InkWell(
        // Prevent InkWell from drawing any hover/highlight overlay
        // so the background/box color doesn't change when hovering
        // over the widget area (but keep tap handling).
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        onTapUp: widget.interactive
            ? (event) {
                // Get the index of the currently hovered segment based on mouse position.
                final newIndex = _getHoveredSegment(event.localPosition);
                // Update state only if the hovered segment has changed.
                if (newIndex != null) {
                  setState(() => _hoveredSegmentIndex = newIndex);
                  if (newIndex < widget.data.length) {
                    widget.data[newIndex].onTap?.call();
                  }
                }
              }
            : null,
        child: Container(
          width: widget.width, // Set the width of the pie chart.
          height: widget.height, // Set the height of the pie chart.
          color: widget
              .style.backgroundColor, // Set the background color from style.
          child: AnimatedBuilder(
            // Build the pie chart with animation.
            animation: _animation,
            builder: (context, _) {
              return CustomPaint(
                size: Size(
                  widget.width,
                  widget.height,
                ), // Size of the custom painter.
                painter: PieChartPainter(
                  data: widget.data, // Pass the data for pie chart segments.
                  sliceSizes: _setSizes(
                    widget.data.fold(0.0, (sum, item) => sum + item.value),
                  ),
                  // Pass the sizes of the piechart slices
                  progress: _animation.value, // Pass the animation progress.
                  style: widget.style, // Pass the style configurations.
                  showLabelOnlyOnHover: widget.showLabelOnlyOnHover,
                  // Pass the show label configuration
                  padding: widget.padding, // Pass the padding.
                  hoveredSegmentIndex:
                      _hoveredSegmentIndex, // Pass the index of the hovered segment.
                  chartRadius: widget.chartRadius, // Pass the chart radius
                  sliceAnimationProgress: _sliceAnimationProgress, // Pass per-slice animation progress
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
