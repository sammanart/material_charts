import 'dart:convert';

import 'package:flutter/material.dart';

import '../shared/shared_models.dart';

/// Enumeration of animation types for multi-line chart animations.
///
/// Defines different animation styles that can be applied to lines:
/// - [drawLine]: Line draws from left to right
/// - [fadeIn]: Line fades in without drawing animation
/// - [slideUp]: Line slides up from bottom
enum LineAnimationType {
  drawLine,
  fadeIn,
  slideUp,
}

/// Enumeration of animation triggers for sequential line animations.
///
/// Defines what triggers the next line's animation:
/// - [afterDelay]: Wait for a specified delay before next animation
/// - [afterPrevious]: Wait for previous line animation to complete before starting
/// - [immediate]: Start all lines at the same time
/// - [manual]: Wait for manual trigger via triggerAnimation() before starting
enum LineAnimationTrigger {
  afterDelay,
  afterPrevious,
  immediate,
  manual,
}

/// Configuration class for individual line animations.
///
/// This class defines the animation properties for a specific line in the chart.
/// It allows fine-grained control over how and when each line animates.
class LineAnimationConfig {
  /// The order in which this line animates (0-based index).
  /// Lines with lower order values animate first.
  /// Multiple lines can have the same order to animate simultaneously.
  final int animationOrder;

  /// The type of animation to apply to this line.
  final LineAnimationType animationType;

  /// What triggers the next animation in the sequence.
  final LineAnimationTrigger animationTrigger;

  /// The duration of this line's animation in milliseconds.
  /// If null, uses the style's default animationDuration.
  final Duration? duration;

  /// The delay before the next line's animation starts (in milliseconds).
  /// Only used when animationTrigger is [LineAnimationTrigger.afterDelay].
  final Duration delayBeforeNext;

  /// The animation curve for this line.
  /// If null, uses the style's default animationCurve.
  final Curve? curve;

  /// Creates an instance of [LineAnimationConfig].
  const LineAnimationConfig({
    this.animationOrder = 0,
    this.animationType = LineAnimationType.drawLine,
    this.animationTrigger = LineAnimationTrigger.afterDelay,
    this.duration,
    this.delayBeforeNext = const Duration(milliseconds: 100),
    this.curve,
  });

  /// Creates a [LineAnimationConfig] from a JSON map.
  factory LineAnimationConfig.fromJson(Map<String, dynamic> json) {
    return LineAnimationConfig(
      animationOrder: json['animationOrder'] ?? 0,
      animationType: parseAnimationType(json['animationType'] ?? 'drawLine'),
      animationTrigger:
          parseAnimationTrigger(json['animationTrigger'] ?? 'afterDelay'),
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      delayBeforeNext: json['delayBeforeNext'] != null
          ? Duration(milliseconds: json['delayBeforeNext'] as int)
          : const Duration(milliseconds: 100),
      curve: json['curve'] != null ? parseAnimationCurve(json['curve']) : null,
    );
  }

  /// Converts the [LineAnimationConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'animationOrder': animationOrder,
      'animationType': _animationTypeToString(animationType),
      'animationTrigger': _animationTriggerToString(animationTrigger),
      if (duration != null) 'duration': duration!.inMilliseconds,
      'delayBeforeNext': delayBeforeNext.inMilliseconds,
      if (curve != null) 'curve': _curveToString(curve!),
    };
  }

  /// Helper to parse animation type from string
  static LineAnimationType parseAnimationType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'drawline':
        return LineAnimationType.drawLine;
      case 'fadein':
        return LineAnimationType.fadeIn;
      case 'slideup':
        return LineAnimationType.slideUp;
      default:
        return LineAnimationType.drawLine;
    }
  }

  /// Helper to convert animation type to string
  static String _animationTypeToString(LineAnimationType type) {
    switch (type) {
      case LineAnimationType.drawLine:
        return 'drawLine';
      case LineAnimationType.fadeIn:
        return 'fadeIn';
      case LineAnimationType.slideUp:
        return 'slideUp';
    }
  }

  /// Helper to parse animation trigger from string
  static LineAnimationTrigger parseAnimationTrigger(String triggerStr) {
    switch (triggerStr.toLowerCase()) {
      case 'afterdelay':
        return LineAnimationTrigger.afterDelay;
      case 'afterprevious':
        return LineAnimationTrigger.afterPrevious;
      case 'immediate':
        return LineAnimationTrigger.immediate;
      case 'manual':
        return LineAnimationTrigger.manual;
      default:
        return LineAnimationTrigger.afterDelay;
    }
  }

  /// Helper to convert animation trigger to string
  static String _animationTriggerToString(LineAnimationTrigger trigger) {
    switch (trigger) {
      case LineAnimationTrigger.afterDelay:
        return 'afterDelay';
      case LineAnimationTrigger.afterPrevious:
        return 'afterPrevious';
      case LineAnimationTrigger.immediate:
        return 'immediate';
      case LineAnimationTrigger.manual:
        return 'manual';
    }
  }

  /// Helper to parse animation curve from string
  static Curve parseAnimationCurve(String curveStr) {
    switch (curveStr.toLowerCase()) {
      case 'linear':
        return Curves.linear;
      case 'easein':
        return Curves.easeIn;
      case 'easeout':
        return Curves.easeOut;
      case 'easeinout':
        return Curves.easeInOut;
      case 'bouncein':
        return Curves.bounceIn;
      case 'bounceout':
        return Curves.bounceOut;
      case 'elasticinout':
        return Curves.elasticInOut;
      default:
        return Curves.easeInOut;
    }
  }

  /// Helper to convert curve to string
  static String _curveToString(Curve curve) {
    if (curve == Curves.linear) return 'linear';
    if (curve == Curves.easeIn) return 'easeIn';
    if (curve == Curves.easeOut) return 'easeOut';
    if (curve == Curves.easeInOut) return 'easeInOut';
    if (curve == Curves.bounceIn) return 'bounceIn';
    if (curve == Curves.bounceOut) return 'bounceOut';
    if (curve == Curves.elasticInOut) return 'elasticInOut';
    return 'easeInOut';
  }
}

/// Represents a single data point in a chart.
///
/// This class holds the value of the data point, an optional label,
/// an optional color, and an optional segment animation order.
/// It is used to define individual points on various types of charts.
class ChartDataPoint {
  final double value; // The numeric value of the data point.
  final String? label; // An optional label for the data point.
  final Color? color; // An optional color associated with the data point.
  final int segmentAnimationOrder; // Segment animation group (0-based index).

  /// Creates a [ChartDataPoint] instance.
  ///
  /// [value] is required to define the data point.
  /// [label], [color], and [segmentAnimationOrder] are optional.
  const ChartDataPoint({
    required this.value,
    this.label,
    this.color,
    this.segmentAnimationOrder = 0,
  });

  /// Creates a [ChartDataPoint] instance from a JSON map.
  /// Supports both simple and Plotly-compatible formats.
  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      value: (json['y'] ?? json['value'] ?? 0.0).toDouble(),
      label: json['x'] ?? json['label'],
      color: json['color'] != null ? _parseColor(json['color']) : null,
      segmentAnimationOrder: json['segmentAnimationOrder'] ?? 0,
    );
  }

  /// Converts the [ChartDataPoint] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'x': label,
      'y': value,
      if (color != null) 'color': _colorToHex(color!),
      if (segmentAnimationOrder != 0) 'segmentAnimationOrder': segmentAnimationOrder,
    };
  }

  /// Helper method to parse color from various formats
  static Color _parseColor(dynamic colorValue) {
    if (colorValue is String) {
      if (colorValue.startsWith('#')) {
        return Color(int.parse(colorValue.replaceFirst('#', '0xFF')));
      } else if (colorValue.startsWith('rgb(')) {
        // Parse rgb(r, g, b) format
        final rgb = colorValue.replaceAll('rgb(', '').replaceAll(')', '');
        final parts = rgb.split(',').map((e) => int.parse(e.trim())).toList();
        return Color.fromRGBO(parts[0], parts[1], parts[2], 1.0);
      } else if (colorValue.startsWith('rgba(')) {
        // Parse rgba(r, g, b, a) format
        final rgba = colorValue.replaceAll('rgba(', '').replaceAll(')', '');
        final parts =
            rgba.split(',').map((e) => double.parse(e.trim())).toList();
        return Color.fromRGBO(
          parts[0].toInt(),
          parts[1].toInt(),
          parts[2].toInt(),
          parts[3],
        );
      }
    }
    return Colors.blue; // Default fallback
  }

  /// Helper method to convert Color to hex string
  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
  }
}

/// Represents the data to be displayed in a tooltip.
///
/// This class encapsulates the necessary information to display
/// a tooltip for a particular data point in the chart, including
/// the series name, the data point details, color, and the position
/// of the tooltip.
class TooltipData {
  final String
      seriesName; // The name of the series to which the data point belongs.
  final ChartDataPoint dataPoint; // The data point associated with the tooltip.
  final Color color; // The color of the tooltip.
  final Offset position; // The position of the tooltip on the screen.

  /// Creates a [TooltipData] instance.
  ///
  /// All parameters are required to correctly configure the tooltip.
  TooltipData({
    required this.seriesName,
    required this.dataPoint,
    required this.color,
    required this.position,
  });
}

/// Represents the styling configuration for tooltips.
///
/// This class defines various properties to customize the appearance
/// and behavior of tooltips, such as text style, background color,
/// padding, and shadow effects.
class MultiLineTooltipStyle {
  final TextStyle textStyle; // Style for the text within the tooltip.
  final Color backgroundColor; // Background color of the tooltip.
  final double padding; // Padding around the tooltip content.
  final double threshold; // Threshold for showing the tooltip.
  final double borderRadius; // Border radius for rounded corners.
  final Color shadowColor; // Shadow color for the tooltip.
  final double shadowBlurRadius; // Blur radius of the tooltip's shadow.
  final double indicatorHeight; // Height of the tooltip indicator.

  /// Creates a [MultiLineTooltipStyle] instance with default values.
  ///
  /// Default values are provided for text style and colors to ensure
  /// a consistent look and feel across tooltips.
  const MultiLineTooltipStyle({
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    this.backgroundColor = Colors.black,
    this.padding = 8.0,
    this.threshold = 10.0,
    this.borderRadius = 4.0,
    this.shadowColor = Colors.black,
    this.shadowBlurRadius = 3.0,
    this.indicatorHeight = 2.0,
  });

  /// Creates a [MultiLineTooltipStyle] instance from a JSON map.
  /// Supports both simple and Plotly-compatible formats.
  factory MultiLineTooltipStyle.fromJson(Map<String, dynamic> json) {
    return MultiLineTooltipStyle(
      textStyle: _parseTextStyle(json['textStyle'] ?? json['font']) ??
          const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
      backgroundColor: json['backgroundColor'] != null
          ? ChartDataPoint._parseColor(json['backgroundColor'])
          : json['bgcolor'] != null
              ? ChartDataPoint._parseColor(json['bgcolor'])
              : Colors.black,
      padding: (json['padding'] ?? 8.0).toDouble(),
      threshold: (json['threshold'] ?? 10.0).toDouble(),
      borderRadius:
          (json['borderRadius'] ?? json['borderradius'] ?? 4.0).toDouble(),
      shadowColor: json['shadowColor'] != null
          ? ChartDataPoint._parseColor(json['shadowColor'])
          : Colors.black,
      shadowBlurRadius: (json['shadowBlurRadius'] ?? 3.0).toDouble(),
      indicatorHeight: (json['indicatorHeight'] ?? 2.0).toDouble(),
    );
  }

  /// Helper method to parse text style from JSON
  static TextStyle? _parseTextStyle(dynamic textStyle) {
    if (textStyle == null) return null;

    if (textStyle is Map<String, dynamic>) {
      return TextStyle(
        fontSize: (textStyle['size'] ?? textStyle['fontSize'] ?? 12).toDouble(),
        fontWeight: _parseFontWeight(
          textStyle['weight'] ?? textStyle['fontWeight'],
        ),
        color: textStyle['color'] != null
            ? ChartDataPoint._parseColor(textStyle['color'])
            : Colors.white,
      );
    }

    return null;
  }

  /// Helper method to parse font weight from string
  static FontWeight _parseFontWeight(dynamic weight) {
    if (weight == null) return FontWeight.normal;

    if (weight is String) {
      switch (weight.toLowerCase()) {
        case 'bold':
          return FontWeight.bold;
        case 'w100':
          return FontWeight.w100;
        case 'w200':
          return FontWeight.w200;
        case 'w300':
          return FontWeight.w300;
        case 'w400':
          return FontWeight.w400;
        case 'w500':
          return FontWeight.w500;
        case 'w600':
          return FontWeight.w600;
        case 'w700':
          return FontWeight.w700;
        case 'w800':
          return FontWeight.w800;
        case 'w900':
          return FontWeight.w900;
        default:
          return FontWeight.normal;
      }
    }

    return FontWeight.normal;
  }
}

/// Represents a series of data points on a chart.
///
/// This class encapsulates the data points for a specific series,
/// along with optional configurations such as color, visibility of
/// points, and line properties.
class ChartSeries {
  final String name; // The name of the data series.
  final List<ChartDataPoint>
      dataPoints; // The list of data points in the series.
  final Color? color; // Optional color for the series line.
  final bool? showPoints; // Flag to determine if points should be displayed.
  final bool? smoothLine; // Flag to determine if the line should be smooth.
  final double? lineWidth; // Width of the line.
  final double? pointSize; // Size of the points on the chart.
  final LineAnimationConfig?
      animationConfig; // Optional animation configuration for the series.

  /// Creates a [ChartSeries] instance.
  ///
  /// [name] and [dataPoints] are required to define the series.
  /// Other parameters are optional to allow customization.
  const ChartSeries({
    required this.name,
    required this.dataPoints,
    this.color,
    this.showPoints,
    this.smoothLine,
    this.lineWidth,
    this.pointSize,
    this.animationConfig,
  });

  /// Creates a [ChartSeries] instance from a JSON map.
  /// Supports both simple and Plotly-compatible formats.
  factory ChartSeries.fromJson(Map<String, dynamic> json) {
    List<ChartDataPoint> dataPoints = [];

    // Handle Plotly format: x and y as arrays
    if (json['x'] is List && json['y'] is List) {
      final xValues = json['x'] as List;
      final yValues = json['y'] as List;

      for (int i = 0; i < xValues.length && i < yValues.length; i++) {
        dataPoints.add(
          ChartDataPoint(
            value: yValues[i].toDouble(),
            label: xValues[i]?.toString(),
          ),
        );
      }
    }
    // Handle simple format: dataPoints as array of objects
    else if (json['dataPoints'] is List) {
      final points = json['dataPoints'] as List;
      dataPoints = points
          .map(
            (point) => ChartDataPoint.fromJson(point as Map<String, dynamic>),
          )
          .toList();
    }
    // Handle data as array of individual points
    else if (json['data'] is List) {
      final points = json['data'] as List;
      dataPoints = points
          .map(
            (point) => ChartDataPoint.fromJson(point as Map<String, dynamic>),
          )
          .toList();
    }

    return ChartSeries(
      name: json['name'] ?? json['title'] ?? 'Series',
      dataPoints: dataPoints,
      color: json['color'] != null
          ? ChartDataPoint._parseColor(json['color'])
          : json['line']?['color'] != null
              ? ChartDataPoint._parseColor(json['line']['color'])
              : json['marker']?['color'] != null
                  ? ChartDataPoint._parseColor(json['marker']['color'])
                  : null,
      showPoints:
          json['showPoints'] ?? json['mode']?.toString().contains('markers'),
      smoothLine: json['smoothLine'] ??
          (json['line']?['shape'] == 'spline') ??
          (json['type'] == 'smooth'),
      lineWidth:
          json['lineWidth']?.toDouble() ?? json['line']?['width']?.toDouble(),
      pointSize:
          json['pointSize']?.toDouble() ?? json['marker']?['size']?.toDouble(),
      animationConfig: json['animationConfig'] != null
          ? LineAnimationConfig.fromJson(json['animationConfig'])
          : null,
    );
  }

  /// Converts the [ChartSeries] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'x': dataPoints.map((point) => point.label).toList(),
      'y': dataPoints.map((point) => point.value).toList(),
      if (color != null) 'color': ChartDataPoint._colorToHex(color!),
      if (showPoints != null) 'showPoints': showPoints,
      if (smoothLine != null) 'smoothLine': smoothLine,
      if (lineWidth != null) 'lineWidth': lineWidth,
      if (pointSize != null) 'pointSize': pointSize,
      if (animationConfig != null) 'animationConfig': animationConfig!.toJson(),
    };
  }
}

// models/chart_style.dart
/// Represents the overall styling configuration for charts.
///
/// This class defines how charts should be rendered visually,
/// including colors, styles for labels and legends, and options
/// for grid lines and animations.
class MultiLineChartStyle {
  final List<Color> colors; // List of colors used for different series.
  final double defaultLineWidth; // Default line width for series.
  final double defaultPointSize; // Default size of points in series.
  final Color gridColor; // Color for the grid lines.
  final Color backgroundColor; // Background color of the chart.
  final TextStyle? labelStyle; // Style for axis labels.
  final TextStyle? legendStyle; // Style for legend items.
  final bool smoothLines; // Flag to enable smooth lines for series.
  final EdgeInsets padding; // Padding around the chart.
  final bool showPoints; // Flag to show points on the lines.
  final bool showGrid; // Flag to show grid lines.
  final bool showLegend; // Flag to show legend.
  final double gridLineWidth; // Width of the grid lines.
  final int horizontalGridLines; // Number of horizontal grid lines.
  final ChartAnimation animation; // Configuration for chart animations.
  final LegendPosition legendPosition; // Position of the legend.
  final CrosshairConfig? crosshair; // Configuration for the crosshair.
  final bool forceYAxisFromZero; // Flag to enforce Y-axis to start from zero.
  final MultiLineTooltipStyle
      tooltipStyle; // Styling configuration for tooltips.
  final LineAnimationType defaultAnimationType; // Default animation type for lines.
  final LineAnimationTrigger defaultAnimationTrigger; // Default animation trigger for lines.
  final Duration defaultAnimationDuration; // Default animation duration for lines.
  final Duration defaultDelayBeforeNext; // Default delay between sequential animations.
  final Curve defaultAnimationCurve; // Default animation curve for lines.
  final Map<int, SegmentAnimationConfig> segmentAnimationConfigs; // Per-segment animation configs grouped by segmentAnimationOrder.
  final Duration defaultSegmentAnimationDuration; // Default duration for segment animations.

  /// Creates a [MultiLineChartStyle] instance with default values.
  ///
  /// All parameters can be customized, with defaults provided to
  /// facilitate immediate use.
  const MultiLineChartStyle({
    required this.colors,
    this.defaultLineWidth = 2.0,
    this.defaultPointSize = 4.0,
    this.gridColor = Colors.grey,
    this.backgroundColor = Colors.white,
    this.labelStyle,
    this.legendStyle,
    this.smoothLines = false,
    this.padding = const EdgeInsets.all(20),
    this.showPoints = true,
    this.showGrid = true,
    this.showLegend = true,
    this.gridLineWidth = 1.0,
    this.horizontalGridLines = 5,
    this.animation = const ChartAnimation(),
    this.legendPosition = LegendPosition.bottom,
    this.crosshair,
    this.forceYAxisFromZero =
        false, // Default to false to maintain existing behavior.
    this.tooltipStyle =
        const MultiLineTooltipStyle(), // Initialize tooltip style.
    this.defaultAnimationType = LineAnimationType.drawLine,
    this.defaultAnimationTrigger = LineAnimationTrigger.afterDelay,
    this.defaultAnimationDuration = const Duration(milliseconds: 800),
    this.defaultDelayBeforeNext = const Duration(milliseconds: 100),
    this.defaultAnimationCurve = Curves.easeInOut,
    this.segmentAnimationConfigs = const {},
    this.defaultSegmentAnimationDuration = const Duration(milliseconds: 600),
  });

  /// Creates a [MultiLineChartStyle] instance from a JSON map.
  /// Supports both simple and Plotly-compatible formats.
  factory MultiLineChartStyle.fromJson(Map<String, dynamic> json) {
    // Parse colors from various formats
    List<Color> colors = [];
    if (json['colors'] is List) {
      colors = (json['colors'] as List)
          .map((color) => ChartDataPoint._parseColor(color))
          .toList();
    } else if (json['colorway'] is List) {
      // Plotly format
      colors = (json['colorway'] as List)
          .map((color) => ChartDataPoint._parseColor(color))
          .toList();
    }

    if (colors.isEmpty) {
      colors = [
        Colors.blue,
        Colors.red,
        Colors.green,
        Colors.orange,
        Colors.purple,
      ];
    }

    return MultiLineChartStyle(
      colors: colors,
      defaultLineWidth:
          (json['defaultLineWidth'] ?? json['line']?['width'] ?? 2.0)
              .toDouble(),
      defaultPointSize:
          (json['defaultPointSize'] ?? json['marker']?['size'] ?? 4.0)
              .toDouble(),
      gridColor: json['gridColor'] != null
          ? ChartDataPoint._parseColor(json['gridColor'])
          : json['xaxis']?['gridcolor'] != null
              ? ChartDataPoint._parseColor(json['xaxis']['gridcolor'])
              : json['yaxis']?['gridcolor'] != null
                  ? ChartDataPoint._parseColor(json['yaxis']['gridcolor'])
                  : Colors.grey,
      backgroundColor: json['backgroundColor'] != null
          ? ChartDataPoint._parseColor(json['backgroundColor'])
          : json['plot_bgcolor'] != null
              ? ChartDataPoint._parseColor(json['plot_bgcolor'])
              : json['paper_bgcolor'] != null
                  ? ChartDataPoint._parseColor(json['paper_bgcolor'])
                  : Colors.white,
      labelStyle: _parseTextStyle(
        json['labelStyle'] ??
            json['xaxis']?['tickfont'] ??
            json['yaxis']?['tickfont'],
      ),
      legendStyle: _parseTextStyle(
        json['legendStyle'] ?? json['legend']?['font'],
      ),
      smoothLines:
          json['smoothLines'] ?? json['line']?['shape'] == 'spline' ?? false,
      padding: _parsePadding(json['padding'] ?? json['margin']),
      showPoints: json['showPoints'] ?? true,
      showGrid: json['showGrid'] ??
          json['showgrid'] ??
          json['xaxis']?['showgrid'] ??
          json['yaxis']?['showgrid'] ??
          true,
      showLegend: json['showLegend'] ?? json['showlegend'] ?? true,
      gridLineWidth: (json['gridLineWidth'] ?? 1.0).toDouble(),
      horizontalGridLines:
          (json['horizontalGridLines'] ?? json['yaxis']?['nticks'] ?? 5)
              .toInt(),
      animation: ChartAnimation.fromJson(json['animation'] ?? {}),
      legendPosition: _parseLegendPosition(
        json['legendPosition'] ?? json['legend']?['orientation'],
      ),
      crosshair: json['crosshair'] != null
          ? CrosshairConfig.fromJson(json['crosshair'])
          : null,
      forceYAxisFromZero: json['forceYAxisFromZero'] ??
          json['yaxis']?['rangemode'] == 'tozero' ??
          false,
      tooltipStyle: MultiLineTooltipStyle.fromJson(
        json['tooltipStyle'] ?? json['hoverlabel'] ?? {},
      ),
      defaultAnimationType: LineAnimationConfig.parseAnimationType(
        json['defaultAnimationType'] ?? 'drawLine',
      ),
      defaultAnimationTrigger: LineAnimationConfig.parseAnimationTrigger(
        json['defaultAnimationTrigger'] ?? 'afterDelay',
      ),
      defaultAnimationDuration: json['defaultAnimationDuration'] != null
          ? Duration(milliseconds: json['defaultAnimationDuration'] as int)
          : const Duration(milliseconds: 800),
      defaultDelayBeforeNext: json['defaultDelayBeforeNext'] != null
          ? Duration(milliseconds: json['defaultDelayBeforeNext'] as int)
          : const Duration(milliseconds: 100),
      defaultAnimationCurve: LineAnimationConfig.parseAnimationCurve(
        json['defaultAnimationCurve'] ?? 'easeInOut',
      ),
      segmentAnimationConfigs: json['segmentAnimationConfigs'] != null
          ? Map<int, SegmentAnimationConfig>.fromEntries(
              (json['segmentAnimationConfigs'] as List)
                  .map((cfg) => MapEntry(
                        cfg['segmentAnimationOrder'] as int,
                        SegmentAnimationConfig.fromJson(cfg),
                      ))
                  .toList(),
            )
          : const {},
      defaultSegmentAnimationDuration: json['defaultSegmentAnimationDuration'] != null
          ? Duration(milliseconds: json['defaultSegmentAnimationDuration'] as int)
          : const Duration(milliseconds: 600),
    );
  }

  /// Helper method to parse text style from JSON
  static TextStyle? _parseTextStyle(dynamic textStyle) {
    if (textStyle == null) return null;

    if (textStyle is Map<String, dynamic>) {
      return TextStyle(
        fontSize: (textStyle['size'] ?? textStyle['fontSize'] ?? 12).toDouble(),
        fontWeight: MultiLineTooltipStyle._parseFontWeight(
          textStyle['weight'] ?? textStyle['fontWeight'],
        ),
        color: textStyle['color'] != null
            ? ChartDataPoint._parseColor(textStyle['color'])
            : null,
      );
    }

    return null;
  }

  /// Helper method to parse padding from JSON
  static EdgeInsets _parsePadding(dynamic padding) {
    if (padding == null) return const EdgeInsets.all(20);

    if (padding is Map<String, dynamic>) {
      return EdgeInsets.only(
        left: (padding['left'] ?? padding['l'] ?? 20).toDouble(),
        top: (padding['top'] ?? padding['t'] ?? 20).toDouble(),
        right: (padding['right'] ?? padding['r'] ?? 20).toDouble(),
        bottom: (padding['bottom'] ?? padding['b'] ?? 20).toDouble(),
      );
    }

    return const EdgeInsets.all(20);
  }

  /// Helper method to parse legend position from string
  static LegendPosition _parseLegendPosition(dynamic position) {
    if (position == null) return LegendPosition.bottom;

    if (position is String) {
      switch (position.toLowerCase()) {
        case 'top':
          return LegendPosition.top;
        case 'left':
          return LegendPosition.left;
        case 'right':
          return LegendPosition.right;
        case 'bottom':
        default:
          return LegendPosition.bottom;
      }
    }

    return LegendPosition.bottom;
  }

  /// Creates a copy of the current [MultiLineChartStyle] instance with optional overrides.
  ///
  /// This method allows modification of the existing style while retaining
  /// the other properties, useful for creating variations of the chart style.
  MultiLineChartStyle copyWith({
    List<Color>? colors,
    double? defaultLineWidth,
    double? defaultPointSize,
    Color? gridColor,
    Color? backgroundColor,
    TextStyle? labelStyle,
    TextStyle? legendStyle,
    bool? smoothLines,
    EdgeInsets? padding,
    bool? showPoints,
    bool? showGrid,
    bool? showLegend,
    double? gridLineWidth,
    int? horizontalGridLines,
    ChartAnimation? animation,
    LegendPosition? legendPosition,
    CrosshairConfig? crosshair,
    bool? forceYAxisFromZero,
    MultiLineTooltipStyle? tooltipStyle,
    LineAnimationType? defaultAnimationType,
    LineAnimationTrigger? defaultAnimationTrigger,
    Duration? defaultAnimationDuration,
    Duration? defaultDelayBeforeNext,
    Curve? defaultAnimationCurve,
    Map<int, SegmentAnimationConfig>? segmentAnimationConfigs,
    Duration? defaultSegmentAnimationDuration,
  }) {
    return MultiLineChartStyle(
      colors: colors ?? this.colors,
      defaultLineWidth: defaultLineWidth ?? this.defaultLineWidth,
      defaultPointSize: defaultPointSize ?? this.defaultPointSize,
      gridColor: gridColor ?? this.gridColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      labelStyle: labelStyle ?? this.labelStyle,
      legendStyle: legendStyle ?? this.legendStyle,
      smoothLines: smoothLines ?? this.smoothLines,
      padding: padding ?? this.padding,
      showPoints: showPoints ?? this.showPoints,
      showGrid: showGrid ?? this.showGrid,
      showLegend: showLegend ?? this.showLegend,
      gridLineWidth: gridLineWidth ?? this.gridLineWidth,
      horizontalGridLines: horizontalGridLines ?? this.horizontalGridLines,
      animation: animation ?? this.animation,
      legendPosition: legendPosition ?? this.legendPosition,
      crosshair: crosshair ?? this.crosshair,
      forceYAxisFromZero: forceYAxisFromZero ?? this.forceYAxisFromZero,
      tooltipStyle: tooltipStyle ?? this.tooltipStyle,
      defaultAnimationType: defaultAnimationType ?? this.defaultAnimationType,
      defaultAnimationTrigger: defaultAnimationTrigger ?? this.defaultAnimationTrigger,
      defaultAnimationDuration: defaultAnimationDuration ?? this.defaultAnimationDuration,
      defaultDelayBeforeNext: defaultDelayBeforeNext ?? this.defaultDelayBeforeNext,
      defaultAnimationCurve: defaultAnimationCurve ?? this.defaultAnimationCurve,
      segmentAnimationConfigs: segmentAnimationConfigs ?? this.segmentAnimationConfigs,
      defaultSegmentAnimationDuration: defaultSegmentAnimationDuration ?? this.defaultSegmentAnimationDuration,
    );
  }
}

/// Represents a single item in the legend.
///
/// This private class holds the text and color associated with a legend item.
class LegendItem {
  final String text; // The text label for the legend item.
  final Color color; // The color associated with the legend item.

  /// Creates a [_LegendItem] instance.
  ///
  /// [text] and [color] are required for defining a legend item.
  LegendItem({required this.text, required this.color});
}

// models/chart_config.dart
/// Defines possible positions for the legend in the chart.
///
/// This enum allows for easy configuration of where the legend
/// should be displayed in relation to the chart.
enum LegendPosition { top, bottom, left, right }

/// Represents the animation configuration for the chart.
///
/// This class allows for customization of how animations are applied
/// when the chart is rendered, including duration and easing curve.
class ChartAnimation {
  final Duration duration; // Duration of the animation.
  final Curve curve; // Easing curve for the animation.
  final bool enabled; // Flag to enable or disable animations.

  /// Creates a [ChartAnimation] instance.
  ///
  /// Default values are provided to ensure animations are smooth
  /// and consistent unless otherwise specified.
  const ChartAnimation({
    this.duration = const Duration(milliseconds: 1000),
    this.curve = Curves.easeInOut,
    this.enabled = true,
  });

  /// Creates a [ChartAnimation] instance from a JSON map.
  factory ChartAnimation.fromJson(Map<String, dynamic> json) {
    return ChartAnimation(
      duration: Duration(milliseconds: (json['duration'] ?? 1000).toInt()),
      curve: _parseCurve(json['curve'] ?? 'easeInOut'),
      enabled: json['enabled'] ?? true,
    );
  }

  /// Helper method to parse animation curve from string
  static Curve _parseCurve(String curveName) {
    switch (curveName.toLowerCase()) {
      case 'linear':
        return Curves.linear;
      case 'easein':
        return Curves.easeIn;
      case 'easeout':
        return Curves.easeOut;
      case 'easeinout':
        return Curves.easeInOut;
      case 'bouncein':
        return Curves.bounceIn;
      case 'bounceout':
        return Curves.bounceOut;
      default:
        return Curves.easeInOut;
    }
  }
}

/// Configures the crosshair behavior in the chart.
///
/// This class defines the appearance and behavior of the crosshair
/// that follows the pointer, enhancing data visualization.
class CrosshairConfig {
  final Color lineColor; // Color of the crosshair line.
  final double lineWidth; // Width of the crosshair line.
  final bool enabled; // Flag to enable or disable the crosshair.
  final bool showLabel; // Flag to show the label with the crosshair.
  final TextStyle? labelStyle; // Style for the crosshair label.

  /// Creates a [CrosshairConfig] instance.
  ///
  /// Default values are provided for a consistent appearance.
  const CrosshairConfig({
    this.lineColor = Colors.grey,
    this.lineWidth = 1.0,
    this.enabled = true,
    this.showLabel = true,
    this.labelStyle,
  });

  /// Creates a [CrosshairConfig] instance from a JSON map.
  factory CrosshairConfig.fromJson(Map<String, dynamic> json) {
    return CrosshairConfig(
      lineColor: json['lineColor'] != null
          ? ChartDataPoint._parseColor(json['lineColor'])
          : Colors.grey,
      lineWidth: (json['lineWidth'] ?? 1.0).toDouble(),
      enabled: json['enabled'] ?? true,
      showLabel: json['showLabel'] ?? true,
      labelStyle: MultiLineChartStyle._parseTextStyle(json['labelStyle']),
    );
  }
}

/// JSON configuration for multi-line charts with optional Plotly compatibility.
/// This class provides a bridge between JSON format and Flutter widgets.
class MultiLineChartJsonConfig {
  /// The series data for the chart
  final List<ChartSeries> series;

  /// The style configuration
  final MultiLineChartStyle style;

  /// Chart dimensions
  final double? width;
  final double? height;

  /// Callback functions
  final ValueChanged<ChartDataPoint>? onPointTap;
  final ValueChanged<Offset>? onChartTap;

  /// Interactive features
  final bool enableZoom;
  final bool enablePan;

  /// Creates a [MultiLineChartJsonConfig] instance.
  const MultiLineChartJsonConfig({
    required this.series,
    required this.style,
    this.width,
    this.height,
    this.onPointTap,
    this.onChartTap,
    this.enableZoom = false,
    this.enablePan = false,
  });

  /// Creates a [MultiLineChartJsonConfig] from a JSON map.
  /// Supports both simple and Plotly-compatible formats.
  factory MultiLineChartJsonConfig.fromJson(Map<String, dynamic> json) {
    List<ChartSeries> series = [];
    Map<String, dynamic> styleData = json['layout'] ?? json['style'] ?? {};

    // Handle data parsing
    if (json['data'] is List) {
      final data = json['data'] as List;

      // Parse each series from the data array
      for (var seriesData in data) {
        if (seriesData is Map<String, dynamic>) {
          series.add(ChartSeries.fromJson(seriesData));
        }
      }
    } else if (json['series'] is List) {
      // Handle direct series format
      final seriesData = json['series'] as List;
      for (var seriesItem in seriesData) {
        if (seriesItem is Map<String, dynamic>) {
          series.add(ChartSeries.fromJson(seriesItem));
        }
      }
    }

    return MultiLineChartJsonConfig(
      series: series,
      style: MultiLineChartStyle.fromJson(styleData),
      width: json['width']?.toDouble() ?? styleData['width']?.toDouble(),
      height: json['height']?.toDouble() ?? styleData['height']?.toDouble(),
      enableZoom: json['enableZoom'] ?? false,
      enablePan: json['enablePan'] ?? false,
    );
  }

  /// Creates a [MultiLineChartJsonConfig] from a JSON string.
  factory MultiLineChartJsonConfig.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return MultiLineChartJsonConfig.fromJson(json);
  }

  /// Converts the configuration to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'data': series.map((s) => s.toJson()).toList(),
      'layout': {
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'enableZoom': enableZoom,
        'enablePan': enablePan,
      },
    };
  }

  /// Converts the configuration to a JSON string.
  String toJsonString() {
    return jsonEncode(toJson());
  }
}
