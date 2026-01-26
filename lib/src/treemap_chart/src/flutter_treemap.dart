import 'dart:math';

import 'package:flutter/material.dart';

import './treemap.dart';

/// A widget that displays a **Treemap visualization**.
///
/// Each [Treemap] node is drawn as a rectangle whose area is
/// proportional to its `value`.
/// Layout is computed using a **squarified treemap algorithm**
/// for improved readability and aspect ratios.
///
/// Example:
/// ```dart
/// FlutterTreemap(
///   nodes: [
///     Treemap(title: "A", value: 40, color: Colors.blue),
///     Treemap(title: "B", value: 30, color: Colors.green),
///   ],
/// )
/// ```
class FlutterTreemap extends StatefulWidget {
  /// The list of treemap nodes to display.
  final List<Treemap> nodes;

  /// Minimum allowed ratio of a tile relative to the total.
  ///
  /// Helps prevent tiles from becoming too small to see.
  /// Must be between `0` and `1`. Default is `0.02`.
  final double minTileRatio;

  /// Whether to show the label text of each node.
  final bool showLabel;

  /// Whether to show the numeric value of each node.
  final bool showValue;

  /// Custom style for the label text.
  final TextStyle? labelStyle;

  /// Custom style for the value text.
  final TextStyle? valueStyle;

  /// Padding inside each treemap tile.
  final EdgeInsetsGeometry tilePadding;

  /// Optional border for each tile.
  final BoxBorder? border;

  /// A wrapper around each built tile.
  ///
  /// Useful for adding custom behaviors such as
  /// [GestureDetector] for onTap, onHover, etc.
  ///
  /// If null, the tile is returned as-is.
  final Widget Function(
    BuildContext context,
    Widget child,
    Treemap node,
    int index,
    Rect rect,
  )?
  tileWrapper;

  /// A custom builder for rendering a tile.
  ///
  /// If null, the default tile layout (label + value) is used.
  final Widget Function(
    BuildContext context,
    Treemap node,
    int index,
    Rect rect,
  )?
  tileBuilder;

  const FlutterTreemap({
    super.key,
    required this.nodes,
    this.minTileRatio = 0.02,
    this.showLabel = true,
    this.showValue = true,
    this.labelStyle,
    this.valueStyle,
    this.tilePadding = const EdgeInsets.all(2),
    this.border,
    this.tileBuilder,
    this.tileWrapper,
  });

  @override
  State<FlutterTreemap> createState() => _FlutterTreemapState();
}

class _FlutterTreemapState extends State<FlutterTreemap> {
  double totalWeight = 0;

  @override
  Widget build(BuildContext context) {
    // Compute total weight (sum of all node values).
    totalWeight = widget.nodes.fold(0.0, (sum, node) => sum + node.value);

    if (totalWeight == 0 || widget.nodes.isEmpty) {
      // No nodes → return empty widget.
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rectangleMap = <Treemap, Rect>{};

        // Compute treemap layout within available constraints.
        _squarify(
          widget.nodes,
          Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight),
          rectangleMap,
        );

        // Build treemap tiles.
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: widget.nodes.asMap().entries.map((entry) {
            final index = entry.key;
            final node = entry.value;
            final rect = rectangleMap[node];
            if (rect == null) return const SizedBox.shrink();

            final builtTile = _buildTile(node: node, rect: rect, index: index);

            // Wrap tile if [tileWrapper] is provided.
            return Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child:
                  widget.tileWrapper?.call(
                    context,
                    builtTile,
                    node,
                    index,
                    rect,
                  ) ??
                  builtTile,
            );
          }).toList(),
        );
      },
    );
  }

  /// Recursive squarified treemap layout algorithm.
  ///
  /// Splits rectangles into sub-rectangles based on node weights,
  /// attempting to keep aspect ratios close to `1:1`.
  void _squarify(
    List<Treemap> nodes,
    Rect rect,
    Map<Treemap, Rect> rectangleMap,
  ) {
    if (nodes.isEmpty || rect.width <= 0 || rect.height <= 0) return;

    // Base case: single node → fill the entire rect.
    if (nodes.length == 1) {
      rectangleMap[nodes.first] = rect;
      return;
    }

    final horizontal = (rect.width / rect.height) >= 1.0;

    // Total adjusted weight (enforcing minTileRatio).
    final sumWeights = nodes.fold(
      0.0,
      (sum, node) => sum + _adjustedWeight(node, rect),
    );

    // Find optimal split index.
    int splitIndex = _findBestSplit(nodes, rect, sumWeights);

    // Split into two groups.
    final firstGroup = nodes.sublist(0, splitIndex);
    final secondGroup = nodes.sublist(splitIndex);

    // Weight of the first group.
    final double firstWeight = firstGroup.fold(
      0.0,
      (sum, node) => sum + _adjustedWeight(node, rect),
    );

    final double ratio = firstWeight / sumWeights;

    // Split rect horizontally or vertically.
    Rect rect1, rect2;
    if (horizontal) {
      double splitWidth = rect.width * ratio;
      splitWidth = min(splitWidth, rect.width);
      rect1 = Rect.fromLTWH(rect.left, rect.top, splitWidth, rect.height);
      rect2 = Rect.fromLTWH(
        rect.left + splitWidth,
        rect.top,
        rect.width - splitWidth,
        rect.height,
      );
    } else {
      double splitHeight = rect.height * ratio;
      splitHeight = min(splitHeight, rect.height);
      rect1 = Rect.fromLTWH(rect.left, rect.top, rect.width, splitHeight);
      rect2 = Rect.fromLTWH(
        rect.left,
        rect.top + splitHeight,
        rect.width,
        rect.height - splitHeight,
      );
    }

    // Recurse into sub-rectangles.
    _squarify(firstGroup, rect1, rectangleMap);
    _squarify(secondGroup, rect2, rectangleMap);
  }

  /// Returns adjusted node weight considering [minTileRatio].
  double _adjustedWeight(Treemap node, Rect rect) {
    double rawVal = node.value.abs();
    double rectArea = rect.width * rect.height;
    if (rectArea == 0) return rawVal;

    // Ensure node does not shrink below minimum ratio.
    double minWeight = totalWeight * widget.minTileRatio;
    return max(rawVal, minWeight);
  }

  /// Finds the best index to split the node list
  /// to minimize poor aspect ratios.
  int _findBestSplit(List<Treemap> nodes, Rect rect, double sumWeights) {
    if (nodes.length <= 2) return 1;

    final horizontal = (rect.width / rect.height) >= 1.0;
    int bestIndex = 1;
    double bestAspect = double.infinity;

    for (int i = 1; i < nodes.length; i++) {
      final firstGroup = nodes.sublist(0, i);
      final secondGroup = nodes.sublist(i);

      final firstWeight = firstGroup.fold(
        0.0,
        (sum, node) => sum + _adjustedWeight(node, rect),
      );
      final secondWeight = secondGroup.fold(
        0.0,
        (sum, node) => sum + _adjustedWeight(node, rect),
      );

      double splitDimension = horizontal
          ? rect.width * (firstWeight / sumWeights)
          : rect.height * (firstWeight / sumWeights);

      // Skip invalid splits.
      if (splitDimension < 0) continue;
      if ((rect.width - splitDimension) < 0 &&
          (rect.height - splitDimension) < 0) {
        continue;
      }

      // Evaluate aspect ratios of both groups.
      final aspect1 = _aspectRatio(firstWeight, rect, sumWeights, horizontal);
      final aspect2 = _aspectRatio(secondWeight, rect, sumWeights, horizontal);
      final worstAspect = max(aspect1, aspect2);

      // Apply penalty for uneven splits.
      double penalty = horizontal
          ? (i / nodes.length)
          : ((nodes.length - i) / nodes.length);
      final adjustedAspect = worstAspect * (1 + penalty * 0.5);

      if (adjustedAspect < bestAspect) {
        bestAspect = adjustedAspect;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  /// Computes aspect ratio of a group’s rectangle.
  double _aspectRatio(
    double groupWeight,
    Rect rect,
    double totalWeight,
    bool horizontal,
  ) {
    if (groupWeight == 0 || totalWeight == 0) return double.infinity;

    final areaRatio = groupWeight / totalWeight;
    double length = horizontal
        ? rect.width * areaRatio
        : rect.height * areaRatio;
    double breadth = horizontal ? rect.height : rect.width;

    if (length == 0 || breadth == 0) return double.infinity;

    double aspect = max(length / breadth, breadth / length);

    // Penalize extreme ratios more strongly.
    return aspect * (aspect > 2 ? 1.5 : 1.0);
  }

  /// Builds a single treemap tile.
  ///
  /// If [tileBuilder] is provided, it is used.
  /// Otherwise, a default container with label and value is rendered.
  Widget _buildTile({
    required Treemap node,
    required Rect rect,
    required int index,
  }) {
    if (widget.tileBuilder != null) {
      return Container(
        width: rect.width,
        height: rect.height,
        decoration: BoxDecoration(color: node.color, border: widget.border),
        padding: widget.tilePadding,
        alignment: Alignment.center,
        child: FittedBox(
          child: widget.tileBuilder!(context, node, index, rect),
        ),
      );
    }

    return Container(
      width: rect.width,
      height: rect.height,
      decoration: BoxDecoration(color: node.color, border: widget.border),
      padding: widget.tilePadding,
      alignment: Alignment.center,
      child: FittedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showLabel && (node.label != null))
              Text(
                node.label!,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style:
                    widget.labelStyle ??
                    const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
              ),
            if (widget.showValue)
              Text(
                node.value.toString(),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style:
                    widget.valueStyle ??
                    const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
