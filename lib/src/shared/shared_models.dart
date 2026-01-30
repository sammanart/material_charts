import 'package:flutter/material.dart';

/// Represents the style configuration for tooltips across all chart types.
///
/// Tooltips provide contextual information when a user hovers over a
/// data point, enhancing user experience by displaying relevant data
/// in a visually appealing manner.
class TooltipStyle {
  /// The background color of the tooltip.
  ///
  /// This property defines the color of the tooltip's background,
  /// allowing customization to improve visibility and aesthetics.
  final Color backgroundColor;

  /// The border color of the tooltip.
  ///
  /// This property defines the color of the tooltip's border, which can
  /// enhance its appearance and distinguish it from the chart background.
  final Color borderColor;

  /// The border radius of the tooltip.
  ///
  /// This property controls the roundness of the tooltip's corners,
  /// contributing to its overall shape and design.
  final double borderRadius;

  /// The text style used within the tooltip.
  ///
  /// This property defines the styling for the text displayed in the
  /// tooltip, including color, font size, and font weight.
  final TextStyle textStyle;

  /// The padding around the tooltip's content.
  ///
  /// This property specifies the amount of space between the tooltip's
  /// content and its border, improving readability and visual appeal.
  final EdgeInsets padding;

  const TooltipStyle({
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.grey,
    this.borderRadius = 5.0,
    this.textStyle = const TextStyle(color: Colors.black, fontSize: 12),
    this.padding = const EdgeInsets.all(8),
  });
}

/// Represents key event data for special markers on charts.
///
/// This class holds information about significant events that can be
/// displayed as markers on charts, such as earnings announcements,
/// dividend payments, or other important events.
class KeyEventData {
  final String? htmlContent; // HTML string for rich tooltip content (required for tooltip display)
  final Color? markerColor; // Color of the event marker
  final double? markerSize; // Optional custom size for this marker (overrides config default)
  final double? verticalOffset; // Optional custom vertical offset for this marker (overrides config default)
  final double? tooltipMaxWidth; // Maximum width for the tooltip
  final double? tooltipMaxHeight; // Maximum height for the tooltip
  final double tooltipOpacity; // Opacity of the tooltip (0.0 to 1.0, default 1.0)

  /// Creates a KeyEventData with HTML content for rich tooltips
  /// Use the flutter_html package to render the HTML in the chart widget
  /// If htmlContent is null or empty, no tooltip will be displayed
  const KeyEventData({
    required String htmlContent,
    Color? markerColor,
    double? markerSize,
    double? verticalOffset,
    double? tooltipMaxWidth,
    double? tooltipMaxHeight,
    double tooltipOpacity = 1.0,
  }) : htmlContent = htmlContent,
       markerColor = markerColor,
       markerSize = markerSize,
       verticalOffset = verticalOffset,
       tooltipMaxWidth = tooltipMaxWidth,
       tooltipMaxHeight = tooltipMaxHeight,
       tooltipOpacity = tooltipOpacity;
  
  /// Whether this event has HTML content
  bool get hasHtmlContent => htmlContent != null && htmlContent!.isNotEmpty;
}

/// Configuration for key event markers
class KeyEventMarkerConfig {
  final double size; // Size of the marker
  final Color defaultColor; // Default color for markers
  final double verticalOffset; // Offset above the data point
  final double minHoverRadius; // Minimum hover radius for tooltip detection (ensures visibility even on small canvases)
  

  const KeyEventMarkerConfig({
    this.size = 10.0,
    this.defaultColor = Colors.orange,
    this.verticalOffset = 18.0,
    this.minHoverRadius = 15.0,
  
  });
}
