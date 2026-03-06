import 'package:flutter/material.dart';

/// Enumeration of animation types for segment animations across all charts.
///
/// Defines different animation styles that can be applied to segments/points:
/// - [drawPoint]: Point/segment draws progressively
/// - [fadeIn]: Point/segment fades in
/// - [slideUp]: Point/segment slides up
enum SegmentAnimationType {
  drawPoint,
  fadeIn,
  slideUp,
}

/// Configuration class for segment-level animations used across all chart types.
///
/// This class defines animation properties for segments that animate together.
/// Segments with the same segmentAnimationOrder define a group that animates as a unit.
/// This class is shared between MultiLineChart and AreaChart to ensure consistent behavior.
class SegmentAnimationConfig {
  /// The order/group index for this segment animation (0-based).
  /// Segments with the same segmentAnimationOrder animate together.
  final int segmentAnimationOrder;

  /// The type of animation to apply to segments in this group.
  final SegmentAnimationType animationType;

  /// The duration of this segment's animation in milliseconds.
  /// If null, uses the style's default segmentAnimationDuration.
  final Duration? duration;

  /// The delay before the next segment's animation starts (in milliseconds).
  final Duration delayBeforeNext;

  /// The animation curve for this segment.
  /// If null, uses the style's default animationCurve.
  final Curve? curve;

  /// The animation trigger mechanism (from the parent chart's trigger type).
  /// Note: This is stored as a dynamic type for compatibility across different
  /// chart types (LineAnimationTrigger for MultiLineChart, AreaAnimationTrigger for AreaChart).
  /// The actual type is determined by the chart using this config.
  final dynamic animationTrigger;

  /// Creates an instance of [SegmentAnimationConfig].
  const SegmentAnimationConfig({
    required this.segmentAnimationOrder,
    this.animationType = SegmentAnimationType.drawPoint,
    this.duration,
    this.delayBeforeNext = const Duration(milliseconds: 100),
    this.curve,
    this.animationTrigger = 'afterDelay', // Default string representation
  });

  /// Creates a [SegmentAnimationConfig] from a JSON map.
  factory SegmentAnimationConfig.fromJson(Map<String, dynamic> json) {
    return SegmentAnimationConfig(
      segmentAnimationOrder: json['segmentAnimationOrder'] ?? 0,
      animationType: _parseSegmentAnimationType(json['animationType'] ?? 'drawPoint'),
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      delayBeforeNext: json['delayBeforeNext'] != null
          ? Duration(milliseconds: json['delayBeforeNext'] as int)
          : const Duration(milliseconds: 100),
      curve: json['curve'] != null ? _parseAnimationCurve(json['curve']) : null,
      animationTrigger: json['animationTrigger'] ?? 'afterDelay',
    );
  }

  /// Converts the [SegmentAnimationConfig] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'segmentAnimationOrder': segmentAnimationOrder,
      'animationType': _segmentAnimationTypeToString(animationType),
      if (duration != null) 'duration': duration!.inMilliseconds,
      'delayBeforeNext': delayBeforeNext.inMilliseconds,
      if (curve != null) 'curve': _curveToString(curve!),
      'animationTrigger': animationTrigger.toString(),
    };
  }

  /// Helper to parse segment animation type from string
  static SegmentAnimationType _parseSegmentAnimationType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'drawpoint':
        return SegmentAnimationType.drawPoint;
      case 'fadein':
        return SegmentAnimationType.fadeIn;
      case 'slideup':
        return SegmentAnimationType.slideUp;
      default:
        return SegmentAnimationType.drawPoint;
    }
  }

  /// Helper to convert segment animation type to string
  static String _segmentAnimationTypeToString(SegmentAnimationType type) {
    switch (type) {
      case SegmentAnimationType.drawPoint:
        return 'drawPoint';
      case SegmentAnimationType.fadeIn:
        return 'fadeIn';
      case SegmentAnimationType.slideUp:
        return 'slideUp';
    }
  }

  /// Helper to parse animation curve from string
  static Curve _parseAnimationCurve(String curveStr) {
    switch (curveStr.toLowerCase()) {
      case 'easeout':
        return Curves.easeOut;
      case 'easein':
        return Curves.easeIn;
      case 'easeinout':
        return Curves.easeInOut;
      case 'linear':
        return Curves.linear;
      case 'bounceout':
        return Curves.bounceOut;
      case 'bouncein':
        return Curves.bounceIn;
      case 'bounceinout':
        return Curves.bounceInOut;
      case 'elasticout':
        return Curves.elasticOut;
      case 'elasticin':
        return Curves.elasticIn;
      case 'elasticinout':
        return Curves.elasticInOut;
      default:
        return Curves.easeInOut;
    }
  }

  /// Helper to convert animation curve to string
  static String _curveToString(Curve curve) {
    if (curve == Curves.easeOut) return 'easeOut';
    if (curve == Curves.easeIn) return 'easeIn';
    if (curve == Curves.easeInOut) return 'easeInOut';
    if (curve == Curves.linear) return 'linear';
    if (curve == Curves.bounceOut) return 'bounceOut';
    if (curve == Curves.bounceIn) return 'bounceIn';
    if (curve == Curves.bounceInOut) return 'bounceInOut';
    if (curve == Curves.elasticOut) return 'elasticOut';
    if (curve == Curves.elasticIn) return 'elasticIn';
    if (curve == Curves.elasticInOut) return 'elasticInOut';
    return 'easeInOut';
  }
}

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
