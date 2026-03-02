import 'package:flutter/material.dart';

/// Position of the legend on the chart.
enum PyramidLegendPosition {
  /// Position the legend at the top center
  topCenter,
  /// Position the legend at the bottom center
  bottomCenter,
  /// Position the legend at the top left
  topLeft,
  /// Position the legend at the top right
  topRight,
  /// Position the legend at the bottom left
  bottomLeft,
  /// Position the legend at the bottom right
  bottomRight,
}

/// Represents data for a single age group in the population pyramid.
class PopulationPyramidData {
  /// The age group label (e.g., '0-4', '5-9', '10-14').
  final String ageGroup;

  /// The left group population count for this age group.
  final double leftPopulation;

  /// The right group population count for this age group.
  final double rightPopulation;

  /// Optional custom color for the left group in this age group.
  final Color? leftColor;

  /// Optional custom color for the right group in this age group.
  final Color? rightColor;

  /// Constructor for [PopulationPyramidData].
  const PopulationPyramidData({
    required this.ageGroup,
    required this.leftPopulation,
    required this.rightPopulation,
    this.leftColor,
    this.rightColor,
  });

  /// Creates a [PopulationPyramidData] instance from a JSON map.
  factory PopulationPyramidData.fromJson(Map<String, dynamic> json) {
    return PopulationPyramidData(
      ageGroup: json['ageGroup'] ?? json['age'] ?? '',
      leftPopulation: (json['left'] ?? json['leftPopulation'] ?? json['male'] ?? json['males'] ?? 0.0).toDouble(),
      rightPopulation: (json['right'] ?? json['rightPopulation'] ?? json['female'] ?? json['females'] ?? 0.0).toDouble(),
      leftColor: json['leftColor'] ?? json['maleColor'] != null ? _parseColor(json['leftColor'] ?? json['maleColor']) : null,
      rightColor: json['rightColor'] ?? json['femaleColor'] != null ? _parseColor(json['rightColor'] ?? json['femaleColor']) : null,
    );
  }

  /// Converts the [PopulationPyramidData] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'ageGroup': ageGroup,
      'leftPopulation': leftPopulation,
      'rightPopulation': rightPopulation,
      'leftColor': leftColor != null ? _colorToHex(leftColor!) : null,
      'rightColor': rightColor != null ? _colorToHex(rightColor!) : null,
    };
  }

  /// Helper method to parse color from various formats
  static Color _parseColor(dynamic colorValue) {
    if (colorValue is String) {
      return Color(int.parse(colorValue.replaceFirst('#', '0xff')));
    } else if (colorValue is int) {
      return Color(colorValue);
    }
    return const Color(0xFF000000);
  }

  /// Helper method to convert color to hex string
  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0')}';
  }
}

/// Configuration class for styling the population pyramid.
class PopulationPyramidStyle {
  /// Background color of the chart
  final Color backgroundColor;

  /// Color for left group bars
  final Color leftColor;

  /// Color for right group bars
  final Color rightColor;

  /// Text color for age group labels (center labels)
  final Color labelColor;

  /// Text color for population values (at bar ends)
  final Color valueColor;

  /// Font size for age labels (center labels)
  final double labelFontSize;

  /// Font size for population values (at bar ends)
  final double valueFontSize;

  /// Font weight for age labels (center labels)
  final FontWeight labelFontWeight;

  /// Font weight for population values (at bar ends)
  final FontWeight valueFontWeight;

  /// Whether to show population values on bars
  final bool showValues;

  /// Whether to show a legend
  final bool showLegend;

  /// Whether to show grid lines
  final bool showGridLines;

  /// Whether to display percentage or absolute values
  final bool showPercentage;

  /// Color of the grid lines
  final Color gridLineColor;

  /// Width of the grid lines
  final double gridLineWidth;

  /// Number of vertical grid line sections (excluding center line)
  final int verticalGridLines;

  /// Number of horizontal grid lines (0 means one per age group)
  final int horizontalGridLines;

  /// Gap between the two groups at the center (in pixels)
  final double centerGap;

  /// Horizontal margin between bars and chart edges
  final double barHorizontalMargin;

  /// Legend position on the chart
  final PyramidLegendPosition legendPosition;

  /// Custom offset for legend positioning (overrides legendPosition if provided)
  final Offset? legendOffset;

  /// Legend text style for group labels
  final TextStyle? legendTextStyle;

  /// Horizontal spacing between legend items
  final double legendItemSpacing;

  /// Size of the legend color squares
  final double legendSquareSize;

  /// Whether to show colored squares in the legend
  final bool showLegendSquares;

  /// Custom color for left group legend square (overrides leftColor if provided)
  final Color? legendLeftColor;

  /// Custom color for right group legend square (overrides rightColor if provided)
  final Color? legendRightColor;

  /// Custom label for left group in legend
  final String legendLeftLabel;

  /// Custom label for right group in legend
  final String legendRightLabel;

  /// Vertical spacing between legend and chart
  final double legendMargin;

  /// Gap/distance between legend and the rest of the chart content
  /// Prevents legend from visually overlapping with bars
  final double legendGapFromChart;

  /// Gap between the bar and its population value text
  final double barValueGap;

  /// Constructor for [PopulationPyramidStyle].
  const PopulationPyramidStyle({
    this.backgroundColor = Colors.white,
    this.leftColor = const Color(0xFF4A90E2),
    this.rightColor = const Color(0xFFED6D91),
    this.labelColor = Colors.black87,
    this.valueColor = Colors.black54,
    this.labelFontSize = 11.0,
    this.valueFontSize = 9.0,
    this.labelFontWeight = FontWeight.w500,
    this.valueFontWeight = FontWeight.w400,
    this.showValues = true,
    this.showLegend = true,
    this.showGridLines = true,
    this.showPercentage = false,
    this.gridLineColor = const Color(0xFFE0E0E0),
    this.gridLineWidth = 0.5,
    this.verticalGridLines = 4,
    this.horizontalGridLines = 0,
    this.centerGap = 10.0,
    this.barHorizontalMargin = 0.0,
    this.legendPosition = PyramidLegendPosition.bottomCenter,
    this.legendOffset,
    this.legendTextStyle,
    this.legendItemSpacing = 40.0,
    this.legendSquareSize = 12.0,
    this.showLegendSquares = true,
    this.legendLeftColor,
    this.legendRightColor,
    this.legendLeftLabel = 'Left',
    this.legendRightLabel = 'Right',
    this.legendMargin = 5.0,
    this.legendGapFromChart = 15.0,
    this.barValueGap = 12.0,
  });
}
