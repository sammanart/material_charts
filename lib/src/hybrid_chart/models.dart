import 'dart:math';

import 'package:flutter/material.dart';

import '../area_chart/models.dart' show TooltipConfig, AreaCrosshairConfig, TooltipStyleConfig, BaselineConfig, AreaAnimationConfig, AreaAnimationType, AreaAnimationTrigger;
import '../shared/shared_models.dart';

/// Enum for y-axis position
enum YAxisPosition {
  left,
  right,
}

/// Enum for x-axis position
enum XAxisPosition { top, bottom }

/// Enum for chart type selection
enum HybridChartType {
  area('Area Chart'),
  multiLine('Multi-Line Chart'),
  line('Line Chart'),
  candlestick('Candlestick Chart');

  final String displayName;
  const HybridChartType(this.displayName);
}

/// Orientation for single crosshair when `singleCrosshair` is enabled
enum SingleCrosshairOrientation { vertical, horizontal }

/// Candlestick value types used when dragging or editing candlestick data.
enum HybridCandlestickValueType { open, close, high, low }

/// Per-data-point X-axis label display control.
/// - `defaultDisplay`: follow the chart's existing rules for showing labels.
/// - `forceDisplay`: always show this data point's X label.
/// - `forceHide`: never show this data point's X label.
enum HybridChartLabelDisplay { defaultDisplay, forceDisplay, forceHide }

/// Unified data point that can represent either area or candlestick chart data
class HybridChartData {
  /// Label for the x-axis (any string)
  final String label;

  /// Price values. `open`, `high`, and `low` are optional — when any are
  /// missing the chart cannot render candlesticks. For area/line display the
  /// `close` value is used as the Y-value; missing `open`/`high`/`low` will
  /// fallback to `close` when a numeric value is required.
  final double? open;
  final double? high;
  final double? low;
  final double close;

  /// Optional volume data
  final double? volume;

  /// Optional key event marker
  final KeyEventData? keyEvent;

  /// Tooltip configuration
  final TooltipConfig? tooltipConfig;

  /// When true, draw a vertical line at this data point's X position.
  /// Use this to force per-point vertical grid lines regardless of label presence.
  final bool? showVerticalLine;

  /// Per-data-point control for whether the X-axis label is shown.
  /// Defaults to `HybridChartLabelDisplay.defaultDisplay` which preserves
  /// the chart's existing label-selection logic.
  final HybridChartLabelDisplay labelDisplay;

  /// Segment animation group (0-based index).
  final int segmentAnimationOrder;

  const HybridChartData({
    this.label = '',
    this.open,
    this.high,
    this.low,
    required this.close,
    this.volume,
    this.keyEvent,
    this.tooltipConfig,
    this.showVerticalLine,
    this.labelDisplay = HybridChartLabelDisplay.defaultDisplay,
    this.segmentAnimationOrder = 0,
  });

  /// Get the value for area chart display (uses the close price)
  double get value => close;

  /// Check if this is bullish (for candlestick)
  bool get isBullish => close >= (open ?? close);

  /// True when `open`, `high`, and `low` are all present and a candlestick
  /// can be rendered for this data point.
  bool get canShowCandlestick => open != null && high != null && low != null;

  /// Returns a new data point with the requested candlestick value updated.
  /// Related values are adjusted to keep the OHLC bounds consistent.
  HybridChartData copyWithCandlestickValue(HybridCandlestickValueType valueType, double newValue) {
    final currentOpen = open ?? close;
    final currentClose = close;
    final currentHigh = high ?? max(currentOpen, currentClose);
    final currentLow = low ?? min(currentOpen, currentClose);

    double nextOpen = currentOpen;
    double nextClose = currentClose;
    double nextHigh = currentHigh;
    double nextLow = currentLow;

    switch (valueType) {
      case HybridCandlestickValueType.open:
        nextOpen = newValue;
        nextHigh = max(nextHigh, max(nextOpen, nextClose));
        nextLow = min(nextLow, min(nextOpen, nextClose));
        break;
      case HybridCandlestickValueType.close:
        nextClose = newValue;
        nextHigh = max(nextHigh, max(nextOpen, nextClose));
        nextLow = min(nextLow, min(nextOpen, nextClose));
        break;
      case HybridCandlestickValueType.high:
        nextHigh = max(newValue, max(nextOpen, max(nextClose, nextLow)));
        break;
      case HybridCandlestickValueType.low:
        nextLow = min(newValue, min(nextOpen, min(nextClose, nextHigh)));
        break;
    }

    return HybridChartData(
      label: label,
      open: nextOpen,
      high: nextHigh,
      low: nextLow,
      close: nextClose,
      volume: volume,
      keyEvent: keyEvent,
      tooltipConfig: tooltipConfig,
      showVerticalLine: showVerticalLine,
      labelDisplay: labelDisplay,
      segmentAnimationOrder: segmentAnimationOrder,
    );
  }
}

/// Unified series that can represent either area or candlestick series
class HybridChartSeries {
  final String name; // Series name
  final List<HybridChartData> dataPoints; // Data points
  final Color? color; // Primary color
  final Color? gradientColor; // Gradient color for area chart
  final double? lineWidth; // Line width for area chart
  final bool? showPoints; // Show points for area chart
  final double? pointSize; // Point size for area chart
  final AreaAnimationConfig? animationConfig; // Animation configuration for this series.

  const HybridChartSeries({
    required this.name,
    required this.dataPoints,
    this.color,
    this.gradientColor,
    this.lineWidth,
    this.showPoints,
    this.pointSize,
    this.animationConfig,
  });

  /// Create from area chart series
  factory HybridChartSeries.fromAreaSeries(
    String name,
    List<HybridChartData> dataPoints, {
    Color? color,
    Color? gradientColor,
    double? lineWidth,
    bool? showPoints,
    double? pointSize,
  }) {
    return HybridChartSeries(
      name: name,
      dataPoints: dataPoints,
      color: color,
      gradientColor: gradientColor,
      lineWidth: lineWidth,
      showPoints: showPoints,
      pointSize: pointSize,
      animationConfig: null,
    );
  }

  /// Create from candlestick series (typically single series per chart)
  factory HybridChartSeries.fromCandlestickSeries(
    String name,
    List<HybridChartData> dataPoints, {
    Color? bullishColor,
    Color? bearishColor,
  }) {
    return HybridChartSeries(
      name: name,
      dataPoints: dataPoints,
      color: bullishColor,
      gradientColor: bearishColor,
      animationConfig: null,
    );
  }
}

/// Unified style configuration for hybrid chart
class HybridChartStyle {
  // Common styling
  final List<Color> colors;
  final Color gridColor;
  final double gridStrokeWidth;
  final double gridOpacity;
  final Color xAxisColor;
  final double xAxisStrokeWidth;
  final double xAxisOpacity;
  final Color yAxisColor;
  final double yAxisStrokeWidth;
  final double yAxisOpacity;
  final Color backgroundColor;
  final Color chartAreaBackgroundColor;
  final TextStyle? labelStyle;
  final Duration animationDuration;
  final Curve animationCurve;
  final EdgeInsets padding;
  final bool showGrid;
  final int autoHorizontalGridLines;
  final int autoVerticalGridLines;
  final bool showVerticalLinesAtLabels;
  final String? xAxisTitle;
  final String? yAxisTitle;

  /// Optional text style for the X axis title
  final TextStyle? xAxisTitleStyle;

  /// Optional text style for the Y axis title
  final TextStyle? yAxisTitleStyle;

  /// Distance in pixels between the X axis line and the X axis title
  final double xAxisTitleGap;

  /// Distance in pixels between the Y axis line and the Y axis title
  final double yAxisTitleGap;

  /// Distance in pixels between the X axis line and the X axis labels
  final double xAxisLabelGap;

  /// Distance in pixels between the Y axis line and the Y axis labels
  final double yAxisLabelGap;

  // Key events
  final bool showKeyEventMarkers;
  final KeyEventMarkerConfig? keyEventMarkerConfig;

  // Crosshair
  final AreaCrosshairConfig? crosshair;

  /// When true, only the vertical crosshair line is drawn (no horizontal line)
  final bool singleCrosshair;

  /// When `singleCrosshair` is true, choose which direction the single crosshair takes.
  final SingleCrosshairOrientation singleCrosshairOrientation;

  // Area-specific
  final double defaultLineWidth;
  final double defaultPointSize;
  final bool showPoints;
  final double areaFillOpacityTop;
  final double areaFillOpacityBottom;
  final bool stacked;
  final bool forceYAxisFromZero;
  final double yAxisMaxOffset;
  final int? xSpanSlots; // Total slots across X axis; spreads points across this span

  // Candlestick-specific
  final Color bullishColor;
  final Color bearishColor;
  final double candleWidth;
  final double wickWidth;
  final double spacing;
  final Color verticalLineColor;
  final double verticalLineWidth;
  // Volume bars under the chart
  final bool showVolume;
  final Color volumeBarColor;
  final double volumeBarOpacity;

  /// Width of each volume bar in pixels
  final double volumeBarWidth;

  /// Whether to show a small tooltip when hovering a volume bar
  final bool showVolumeTooltip;

  /// Background color for the volume tooltip
  final Color volumeTooltipBackgroundColor;

  /// Text color for the volume tooltip
  final Color volumeTooltipTextColor;

  /// Border radius for the volume tooltip box
  final double volumeTooltipBorderRadius;

  /// Opacity for the volume tooltip background (0.0 - 1.0)
  final double volumeTooltipOpacity;

  /// Fraction of the chart height allocated to volume bars (0.0 - 1.0)
  /// Multiplier applied to the chart area's height to determine the
  /// maximum drawable height for volume bars. Values > 1.0 are allowed
  /// and act as a multiplier (e.g. 2.0 makes the max bar height twice
  /// the chart area's height). Negative values are treated as 0.
  final double volumeBarHeightRatio;

  /// Fraction of the main chart area reserved for the volume area when
  /// `showVolumeBelowChart` is true. Keep this <= 0.5 to avoid crowding.
  final double volumeAreaHeightRatio;

  /// When true and `showVolume` is enabled, render the volume bars in a
  /// separate area below the main plotting area.
  final bool showVolumeBelowChart;

  /// Vertical offset (in pixels) applied to drawn volume bars. Positive
  /// values move the bars downward; negative values move them upward.
  final double volumeBarVerticalOffset;
  final TooltipStyleConfig? tooltipStyle;
  final BaselineConfig? baseline;
  final AreaAnimationType defaultAnimationType; // Default animation type for areas.
  final AreaAnimationTrigger defaultAnimationTrigger; // Default animation trigger for areas.
  final Duration defaultDelayBeforeNext; // Default delay between sequential animations.
  final Map<int, SegmentAnimationConfig> segmentAnimationConfigs; // Per-segment animation configs grouped by segmentAnimationOrder.
  final Duration defaultSegmentAnimationDuration; // Default duration for segment animations.

  const HybridChartStyle({
    // Common
    this.colors = const [Colors.blue, Colors.green, Colors.red],
    this.gridColor = Colors.grey,
    this.gridStrokeWidth = 0.5,
    this.gridOpacity = 0.3,
    this.xAxisColor = Colors.black,
    this.xAxisStrokeWidth = 1.0,
    this.xAxisOpacity = 1.0,
    this.yAxisColor = Colors.black,
    this.yAxisStrokeWidth = 1.0,
    this.yAxisOpacity = 1.0,
    this.backgroundColor = Colors.white,
    this.chartAreaBackgroundColor = Colors.transparent,
    this.labelStyle,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.animationCurve = Curves.easeInOut,
    this.padding = const EdgeInsets.all(24),
    this.showGrid = true,
    this.autoHorizontalGridLines = 5,
    this.autoVerticalGridLines = 0,
    this.showVerticalLinesAtLabels = false,
    this.xAxisTitle,
    this.yAxisTitle,
    this.xAxisTitleStyle,
    this.yAxisTitleStyle,
    this.xAxisTitleGap = 8.0,
    this.yAxisTitleGap = 12.0,
    this.xAxisLabelGap = 8.0,
    this.yAxisLabelGap = 8.0,
    this.showKeyEventMarkers = true,
    this.keyEventMarkerConfig,
    this.crosshair,
    this.singleCrosshair = false,
    this.singleCrosshairOrientation = SingleCrosshairOrientation.vertical,
    // Area-specific
    this.defaultLineWidth = 2.0,
    this.defaultPointSize = 4.0,
    this.showPoints = true,
    this.areaFillOpacityTop = 0.3,
    this.areaFillOpacityBottom = 0.05,
    this.stacked = false,
    this.forceYAxisFromZero = true,
    this.yAxisMaxOffset = 0.0,
    this.xSpanSlots,
    // Candlestick-specific
    this.bullishColor = Colors.green,
    this.bearishColor = Colors.red,
    this.candleWidth = 12.0,
    this.wickWidth = 2.0,
    this.spacing = 0.2,
    this.verticalLineColor = Colors.blue,
    this.verticalLineWidth = 1.0,
    this.showVolume = false,
    this.volumeBarColor = Colors.grey,
    this.volumeBarOpacity = 0.5,
    this.volumeBarWidth = 8.0,
    this.showVolumeTooltip = false,
    this.volumeTooltipBackgroundColor = Colors.black,
    this.volumeTooltipTextColor = Colors.white,
    this.volumeTooltipBorderRadius = 4.0,
    this.volumeTooltipOpacity = 0.9,
    this.volumeBarHeightRatio = 0.2,
    this.volumeAreaHeightRatio = 0.2,
    this.volumeBarVerticalOffset = 0.0,
    this.showVolumeBelowChart = false,
    this.tooltipStyle,
    this.baseline,
    this.defaultAnimationType = AreaAnimationType.drawLine,
    this.defaultAnimationTrigger = AreaAnimationTrigger.afterDelay,
    this.defaultDelayBeforeNext = const Duration(milliseconds: 100),
    this.segmentAnimationConfigs = const {},
    this.defaultSegmentAnimationDuration = const Duration(milliseconds: 600),
  });

  /// Create a style combining the best of both area and candlestick
  factory HybridChartStyle.unified({
    List<Color>? colors,
    Color? gridColor,
    double? gridStrokeWidth,
    double? gridOpacity,
    Color? xAxisColor,
    double? xAxisStrokeWidth,
    double? xAxisOpacity,
    Color? yAxisColor,
    double? yAxisStrokeWidth,
    double? yAxisOpacity,
    Color? backgroundColor,
    Color? chartAreaBackgroundColor,
    TextStyle? labelStyle,
    Duration? animationDuration,
    Curve? animationCurve,
    EdgeInsets? padding,
    bool? showGrid,
    int? autoHorizontalGridLines,
    int? autoVerticalGridLines,
    bool? showVerticalLinesAtEveryLabels,
    String? xAxisTitle,
    String? yAxisTitle,
    TextStyle? xAxisTitleStyle,
    TextStyle? yAxisTitleStyle,
    double? xAxisTitleGap,
    double? yAxisTitleGap,
    double? xAxisLabelGap,
    double? yAxisLabelGap,
    bool? showKeyEventMarkers,
    KeyEventMarkerConfig? keyEventMarkerConfig,
    AreaCrosshairConfig? crosshair,
    bool? singleCrosshair,
    SingleCrosshairOrientation? singleCrosshairOrientation,
    double? defaultLineWidth,
    double? defaultPointSize,
    bool? showPoints,
    double? areaFillOpacityTop,
    double? areaFillOpacityBottom,
    bool? stacked,
    bool? forceYAxisFromZero,
    double? yAxisMaxOffset,
    int? xSpanSlots,
    Color? bullishColor,
    Color? bearishColor,
    double? candleWidth,
    double? wickWidth,
    double? spacing,
    Color? verticalLineColor,
    double? verticalLineWidth,
    bool? showVolume,
    Color? volumeBarColor,
    double? volumeBarOpacity,
    double? volumeBarWidth,
    bool? showVolumeTooltip,
    Color? volumeTooltipBackgroundColor,
    Color? volumeTooltipTextColor,
    double? volumeTooltipBorderRadius,
    double? volumeTooltipOpacity,
    double? volumeBarHeightRatio,
    double? volumeAreaHeightRatio,
    double? volumeBarVerticalOffset,
    bool? showVolumeBelowChart,
    TooltipStyleConfig? tooltipStyle,
    BaselineConfig? baseline,
    AreaAnimationType? defaultAnimationType,
    AreaAnimationTrigger? defaultAnimationTrigger,
    Duration? defaultDelayBeforeNext,
    Map<int, SegmentAnimationConfig>? segmentAnimationConfigs,
    Duration? defaultSegmentAnimationDuration,
  }) {
    return HybridChartStyle(
      colors: colors ?? const [Colors.blue, Colors.green, Colors.red],
      gridColor: gridColor ?? Colors.grey,
      gridStrokeWidth: gridStrokeWidth ?? 0.5,
      gridOpacity: gridOpacity ?? 0.3,
      xAxisColor: xAxisColor ?? Colors.black,
      xAxisStrokeWidth: xAxisStrokeWidth ?? 1.0,
      xAxisOpacity: xAxisOpacity ?? 1.0,
      yAxisColor: yAxisColor ?? Colors.black,
      yAxisStrokeWidth: yAxisStrokeWidth ?? 1.0,
      yAxisOpacity: yAxisOpacity ?? 1.0,
      backgroundColor: backgroundColor ?? Colors.white,
      chartAreaBackgroundColor: chartAreaBackgroundColor ?? Colors.transparent,
      labelStyle: labelStyle,
      animationDuration: animationDuration ?? const Duration(milliseconds: 1500),
      animationCurve: animationCurve ?? Curves.easeInOut,
      padding: padding ?? const EdgeInsets.all(24),
      showGrid: showGrid ?? true,
      autoHorizontalGridLines: autoHorizontalGridLines ?? 5,
      autoVerticalGridLines: autoVerticalGridLines ?? 0,
      showVerticalLinesAtLabels: showVerticalLinesAtEveryLabels ?? false,
      xAxisTitle: xAxisTitle,
      yAxisTitle: yAxisTitle,
      xAxisTitleStyle: xAxisTitleStyle,
      yAxisTitleStyle: yAxisTitleStyle,
      xAxisTitleGap: xAxisTitleGap ?? 8.0,
      yAxisTitleGap: yAxisTitleGap ?? 12.0,
      xAxisLabelGap: xAxisLabelGap ?? 8.0,
      yAxisLabelGap: yAxisLabelGap ?? 8.0,
      showKeyEventMarkers: showKeyEventMarkers ?? true,
      keyEventMarkerConfig: keyEventMarkerConfig,
      crosshair: crosshair,
      singleCrosshair: singleCrosshair ?? false,
      singleCrosshairOrientation: singleCrosshairOrientation ?? SingleCrosshairOrientation.vertical,
      defaultLineWidth: defaultLineWidth ?? 2.0,
      defaultPointSize: defaultPointSize ?? 4.0,
      showPoints: showPoints ?? true,
      areaFillOpacityTop: areaFillOpacityTop ?? 0.3,
      areaFillOpacityBottom: areaFillOpacityBottom ?? 0.05,
      stacked: stacked ?? false,
      forceYAxisFromZero: forceYAxisFromZero ?? true,
      yAxisMaxOffset: yAxisMaxOffset ?? 0.0,
      xSpanSlots: xSpanSlots,
      bullishColor: bullishColor ?? Colors.green,
      bearishColor: bearishColor ?? Colors.red,
      candleWidth: candleWidth ?? 12.0,
      wickWidth: wickWidth ?? 2.0,
      spacing: spacing ?? 0.2,
      verticalLineColor: verticalLineColor ?? Colors.blue,
      verticalLineWidth: verticalLineWidth ?? 1.0,
      showVolume: showVolume ?? false,
      volumeBarColor: volumeBarColor ?? Colors.grey,
      volumeBarOpacity: volumeBarOpacity ?? 0.5,
      volumeBarWidth: volumeBarWidth ?? 8.0,
      showVolumeTooltip: showVolumeTooltip ?? false,
      volumeTooltipBackgroundColor: volumeTooltipBackgroundColor ?? Colors.black,
      volumeTooltipTextColor: volumeTooltipTextColor ?? Colors.white,
      volumeTooltipBorderRadius: volumeTooltipBorderRadius ?? 4.0,
      volumeTooltipOpacity: volumeTooltipOpacity ?? 0.9,
      volumeBarHeightRatio: volumeBarHeightRatio ?? 0.2,
      volumeAreaHeightRatio: volumeAreaHeightRatio ?? 0.2,
      volumeBarVerticalOffset: volumeBarVerticalOffset ?? 0.0,
      showVolumeBelowChart: showVolumeBelowChart ?? false,
      tooltipStyle: tooltipStyle,
      baseline: baseline,
      defaultAnimationType: defaultAnimationType ?? AreaAnimationType.drawLine,
      defaultAnimationTrigger: defaultAnimationTrigger ?? AreaAnimationTrigger.afterDelay,
      defaultDelayBeforeNext: defaultDelayBeforeNext ?? const Duration(milliseconds: 100),
      segmentAnimationConfigs: segmentAnimationConfigs ?? const {},
      defaultSegmentAnimationDuration: defaultSegmentAnimationDuration ?? const Duration(milliseconds: 600),
    );
  }
}

/// Axis configuration for hybrid chart
class HybridChartAxisConfig {
  final int priceDivisions;
  final int dateDivisions;
  final TextStyle? labelStyle;
  final double yAxisWidth;
  final double xAxisHeight;
  final XAxisPosition xAxisPosition;
  final String Function(double price)? priceFormatter;
  final String Function(DateTime date)? dateFormatter;
  final YAxisPosition yAxisPosition;

  const HybridChartAxisConfig({
    this.priceDivisions = 5,
    this.dateDivisions = 5,
    this.labelStyle,
    this.yAxisWidth = 60.0,
    this.xAxisHeight = 30.0,
    this.xAxisPosition = XAxisPosition.bottom,
    this.priceFormatter,
    this.dateFormatter,
    this.yAxisPosition = YAxisPosition.right,
  });
}
