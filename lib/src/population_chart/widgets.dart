import 'package:flutter/material.dart';

import 'models.dart';
import 'painter.dart';

/// A customizable population pyramid widget that displays population data by age and demographic groups.
///
/// The [MaterialPopulationPyramid] takes a list of [PopulationPyramidData], dimensions, and style settings
/// to create a demographic pyramid with the left group on the left and right group on the right.
class MaterialPopulationPyramid extends StatefulWidget {
  /// The data points to be represented in the population pyramid.
  final List<PopulationPyramidData> data;

  /// The width of the chart.
  final double width;

  /// The height of the chart.
  final double height;

  /// Style configurations for the population pyramid.
  final PopulationPyramidStyle style;

  /// Padding around the pyramid.
  final EdgeInsets padding;

  /// Callback function invoked when animation completes.
  final VoidCallback? onAnimationComplete;

  /// Animation duration for the chart.
  final Duration animationDuration;

  /// Creates an instance of [MaterialPopulationPyramid].
  const MaterialPopulationPyramid({
    super.key,
    required this.data,
    required this.width,
    required this.height,
    this.style = const PopulationPyramidStyle(),
    this.padding = const EdgeInsets.all(16.0),
    this.onAnimationComplete,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  @override
  State<MaterialPopulationPyramid> createState() =>
      _MaterialPopulationPyramidState();
}

class _MaterialPopulationPyramidState extends State<MaterialPopulationPyramid>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward().then((_) {
      widget.onAnimationComplete?.call();
    });
  }

  @override
  void didUpdateWidget(MaterialPopulationPyramid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.animationDuration != widget.animationDuration) {
      _animationController.dispose();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.style.backgroundColor,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: PopulationPyramidPainter(
              data: widget.data,
              progress: _animation.value,
              style: widget.style,
              padding: widget.padding,
            ),
            size: Size(widget.width, widget.height),
          );
        },
      ),
    );
  }
}
