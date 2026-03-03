import 'package:flutter/material.dart';

import 'models.dart';
import 'painter.dart';

/// A material design hollow semi-circle chart widget that displays a
/// percentage value visually as a hollow semi-circle with optional legend and
/// percentage text.
class MaterialChartHollowSemiCircle extends BaseChart {
  /// The radius ratio for the hollow section of the chart.
  /// This value should be between 0 and 1, where 0 represents a solid
  /// circle and 1 represents a fully hollow circle.
  final double hollowRadius;

  /// Constructs a [MaterialChartHollowSemiCircle] widget with required parameters.
  /// The [percentage] parameter indicates the percentage value to be displayed,
  /// and the [hollowRadius] determines how hollow the center of the chart will be.
  const MaterialChartHollowSemiCircle({
    super.key,
    required super.percentage, // Percentage to display on the chart
    super.size = 200, // Default size of the chart
    this.hollowRadius = 0.6, // Default hollow radius ratio
    super.style, // Optional style configuration for the chart
    super.onAnimationComplete, // Optional callback when animation completes
  }) : assert(
          hollowRadius >= 0 && hollowRadius < 1,
          'Hollow radius must be between 0 and 1',
        );

  /// Creates a [MaterialChartHollowSemiCircle] from JSON configuration.
  /// Supports both simple and Plotly-compatible formats.
  ///
  /// Example simple JSON:
  /// ```json
  /// {
  ///   "percentage": 75,
  ///   "size": 300,
  ///   "hollowRadius": 0.5,
  ///   "style": {
  ///     "activeColor": "#4CAF50",
  ///     "inactiveColor": "#E0E0E0",
  ///     "showPercentageText": true,
  ///     "showLegend": false
  ///   }
  /// }
  /// ```
  ///
  /// Example Plotly JSON:
  /// ```json
  /// {
  ///   "data": [
  ///     {
  ///       "type": "indicator",
  ///       "mode": "gauge+number",
  ///       "value": 75,
  ///       "gauge": {
  ///         "axis": {"range": [0, 100]},
  ///         "bar": {"color": "darkblue"},
  ///         "bgcolor": "lightgray",
  ///         "hole": 0.6
  ///       }
  ///     }
  ///   ],
  ///   "layout": {
  ///     "width": 400,
  ///     "height": 200,
  ///     "font": {"color": "black", "size": 14}
  ///   }
  /// }
  /// ```
  factory MaterialChartHollowSemiCircle.fromJson(Map<String, dynamic> json) {
    final config = HollowSemiCircleChartJsonConfig.fromJson(json);
    return MaterialChartHollowSemiCircle(
      percentage: config.percentage,
      size: config.size,
      hollowRadius: config.hollowRadius,
      style: config.getChartStyle(),
      onAnimationComplete: config.onAnimationComplete,
    );
  }

  /// Creates a [MaterialChartHollowSemiCircle] from a JSON string.
  /// Supports both simple and Plotly-compatible formats.
  factory MaterialChartHollowSemiCircle.fromJsonString(String jsonString) {
    final config = HollowSemiCircleChartJsonConfig.fromJsonString(jsonString);
    return MaterialChartHollowSemiCircle(
      percentage: config.percentage,
      size: config.size,
      hollowRadius: config.hollowRadius,
      style: config.getChartStyle(),
      onAnimationComplete: config.onAnimationComplete,
    );
  }

  /// Creates a [MaterialChartHollowSemiCircle] with simplified parameters.
  /// This is a convenience constructor for quick chart creation.
  factory MaterialChartHollowSemiCircle.simple({
    required double percentage,
    double size = 200,
    double hollowRadius = 0.6,
    Color activeColor = Colors.blue,
    Color inactiveColor = const Color(0xFFE0E0E0),
    Color? textColor,
    bool showPercentageText = true,
    bool showLegend = true,
    Duration animationDuration = const Duration(milliseconds: 1500),
    Curve animationCurve = Curves.easeInOut,
    VoidCallback? onAnimationComplete,
    double legendSpacing = 24.0,
  }) {
    return MaterialChartHollowSemiCircle(
      percentage: percentage,
      size: size,
      hollowRadius: hollowRadius,
      style: ChartStyle(
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        textColor: textColor,
        animationDuration: animationDuration,
        animationCurve: animationCurve,
        showPercentageText: showPercentageText,
        showLegend: showLegend,
        legendSpacing: legendSpacing,
      ),
      onAnimationComplete: onAnimationComplete,
    );
  }

  @override
  State<MaterialChartHollowSemiCircle> createState() =>
      _MaterialChartHollowSemiCircleState();
}

/// State class for [MaterialChartHollowSemiCircle].
/// This class manages the animation of the chart and updates its state
/// when the percentage value changes.
class _MaterialChartHollowSemiCircleState
    extends State<MaterialChartHollowSemiCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController; // Controller for the animation
  late Animation<double> _animation; // Animation for the percentage value

  @override
  void initState() {
    super.initState();
    _setupAnimation(); // Set up the animation when the widget initializes
  }

  /// Initializes the animation controller and the animation for the percentage.
  /// The animation goes from 0 to the specified percentage, using the defined
  /// animation duration and curve.
  void _setupAnimation() {
    _animationController = AnimationController(
      vsync: this, // Use the current state as the TickerProvider
      duration: widget.style.animationDuration, // Duration of the animation
    );

    // Tween to animate the percentage value from 0 to the specified percentage.
    _animation = Tween<double>(
      begin: 0, // Starting value of the animation
      end: widget.percentage, // Ending value of the animation
    ).animate(
      CurvedAnimation(
        parent: _animationController, // The animation controller
        curve: widget.style.animationCurve, // Curve for the animation
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete
              ?.call(); // Call the completion callback if set.
        }
      });

    _animationController.forward(); // Start the animation
  }

  @override
  void didUpdateWidget(MaterialChartHollowSemiCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the percentage has changed, update the animation.
    if (oldWidget.percentage != widget.percentage) {
      // Create a new Tween to animate from the old percentage to the new percentage.
      _animation = Tween<double>(
        begin: oldWidget.percentage, // Start from the old percentage
        end: widget.percentage, // End at the new percentage
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: widget.style.animationCurve, // Use the same curve as before
        ),
      );
      _animationController.forward(from: 0); // Restart the animation from 0
    }
  }

  @override
  void dispose() {
    _animationController
        .dispose(); // Dispose of the animation controller to free up resources
    super.dispose(); // Call the super class dispose method
  }

  /// Formats the percentage value for display in the chart.
  /// If a custom formatter is provided, it uses that; otherwise, it defaults
  /// to showing the percentage as an integer followed by a percent sign.
  String _formatPercentage(double value) {
    if (widget.style.percentageFormatter != null) {
      return widget.style.percentageFormatter!(value);
    }
    return '${value.toStringAsFixed(0)}%'; // Default formatting
  }

  /// Formats the legend label for the chart.
  /// If a custom legend formatter is provided, it uses that; otherwise,
  /// it defaults to displaying the type and value.
  String _formatLegendLabel(String type, double value) {
    if (widget.style.legendFormatter != null) {
      return widget.style.legendFormatter!(type, value);
    }
    return '$type (${value.toStringAsFixed(0)}%)'; // Default legend formatting
  }

  @override
  Widget build(BuildContext context) {
    // Build legend content (rows of _LegendItem). We create the content
    // regardless of placement and wrap it with appropriate padding when
    // placing it around the chart.
    final Widget legendContent = widget.style.showLegend
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.style.activePercentages != null &&
                  widget.style.activePercentages!.isNotEmpty) ...[
                for (var i = 0; i < widget.style.activePercentages!.length; i++) ...[
                  _LegendItem(
                    color: (widget.style.activeColors != null && i < widget.style.activeColors!.length)
                        ? widget.style.activeColors![i]
                        : widget.style.activeColor,
                    label: _formatLegendLabel(
                      widget.style.activeLabels != null && i < widget.style.activeLabels!.length
                          ? widget.style.activeLabels![i]
                          : 'Segment ${i + 1}',
                      widget.style.activePercentages![i],
                    ),
                    style: widget.style.legendStyle,
                  ),
                  if (i != widget.style.activePercentages!.length - 1)
                    const SizedBox(width: 16),
                ],
                const SizedBox(width: 24),
                _LegendItem(
                  color: widget.style.inactiveColor,
                  label: _formatLegendLabel('Remaining',
                      100 - widget.style.activePercentages!.fold(0.0, (a, b) => a + b)),
                  style: widget.style.legendStyle,
                ),
              ] else ...[
                _LegendItem(
                  color: widget.style.activeColor,
                  label: _formatLegendLabel('Active', widget.percentage),
                  style: widget.style.legendStyle,
                ),
                const SizedBox(width: 24),
                _LegendItem(
                  color: widget.style.inactiveColor,
                  label: _formatLegendLabel('Inactive', 100 - widget.percentage),
                  style: widget.style.legendStyle,
                ),
              ],
            ],
          )
        : const SizedBox.shrink();

    // The chart widget (kept as before)
    final Widget chartWidget = SizedBox(
      width: widget.size,
      height: widget.size / 2,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size / 2),
                painter: HollowSemiCircleChart(
                  percentage: _animation.value,
                  activeColor: widget.style.activeColor,
                  activeColors: widget.style.activeColors ?? [],
                  inactiveColor: widget.style.inactiveColor,
                  hollowRadius: widget.hollowRadius,
                ),
              ),
              if (widget.style.showPercentageText)
                (() {
                  final pos = widget.style.percentagePosition;
                  final offset = widget.style.percentageOffset;
                  final fontSize = widget.size / 8;
                  final baseDistance = fontSize * 2.0;
                  final text = Text(
                    _formatPercentage(_animation.value),
                    style: widget.style.percentageStyle?.copyWith(
                          color: widget.style.textColor,
                        ) ??
                        TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: widget.style.textColor,
                        ),
                  );

                  if (pos == PercentagePosition.center) {
                    return Positioned(bottom: 0, left: 0, right: 0, child: Center(child: text));
                  }

                  final verticalCenterTop = (widget.size / 2 - fontSize) / 2;

                  switch (pos) {
                    case PercentagePosition.top:
                      return Positioned(top: -baseDistance - offset, left: 0, right: 0, child: Center(child: text));
                    case PercentagePosition.bottom:
                      return Positioned(bottom: -baseDistance - offset, left: 0, right: 0, child: Center(child: text));
                    case PercentagePosition.left:
                      return Positioned(left: -baseDistance - offset, top: verticalCenterTop, child: text);
                    case PercentagePosition.right:
                      return Positioned(right: -baseDistance - offset, top: verticalCenterTop, child: text);
                    default:
                      return Positioned(bottom: 0, left: 0, right: 0, child: Center(child: text));
                  }
                }()),
            ],
          );
        },
      ),
    );

    // Place legend relative to the chart according to `legendPosition`.
    switch (widget.style.semiCircleLegendPosition) {
      case SemiCircleLegendPosition.top:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: EdgeInsets.only(bottom: widget.style.legendSpacing), child: legendContent),
          chartWidget,
        ]);
      case SemiCircleLegendPosition.bottom:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          chartWidget,
          Padding(padding: EdgeInsets.only(top: widget.style.legendSpacing), child: legendContent),
        ]);
      case SemiCircleLegendPosition.left:
        return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Padding(padding: EdgeInsets.only(right: widget.style.legendSpacing), child: legendContent),
          chartWidget,
        ]);
      case SemiCircleLegendPosition.right:
        return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          chartWidget,
          Padding(padding: EdgeInsets.only(left: widget.style.legendSpacing), child: legendContent),
        ]);
      default:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: EdgeInsets.only(bottom: widget.style.legendSpacing), child: legendContent),
          chartWidget,
        ]);
    }
  }
}

/// A widget that represents a single item in the legend of the chart.
/// Displays a colored square and a label.
class _LegendItem extends StatelessWidget {
  /// The color of the legend item.
  final Color color;

  /// The label to display next to the color.
  final String label;

  /// Optional style for the legend text.
  final TextStyle? style;

  /// Constructs a [_LegendItem] with the specified color, label, and optional style.
  const _LegendItem({
    required this.color, // Required color for the legend item
    required this.label, // Required label for the legend item
    this.style, // Optional text style for the legend
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Minimize the space taken by the row
      children: [
        // Create a small square to represent the legend color
        Container(
          width: 16, // Width of the square
          height: 16, // Height of the square
          decoration: BoxDecoration(
            color: color, // Set the background color of the square
            shape: BoxShape.rectangle, // Shape of the box
            borderRadius: BorderRadius.circular(2), // Rounded corners
          ),
        ),
        const SizedBox(width: 8), // Space between the color box and the label
        // Display the label text for the legend
        Text(
          label,
          style: style ??
              const TextStyle(
                fontSize: 14,
              ), // Use the provided style or default size
        ),
      ],
    );
  }
}
