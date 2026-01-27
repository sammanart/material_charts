import 'dart:math';

import 'package:flutter/material.dart';

import './treemap.dart';

/// Plotly-compatible branchvalues modes
enum BranchValuesMode { remainder, total }

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

  /// Controls how parent/child areas are computed.
  ///
  /// - [BranchValuesMode.remainder] (default): children occupy a portion of the
  ///   parent equal to sum(children)/parent.value; leftover is implicit remainder.
  /// - [BranchValuesMode.total]: children are normalized to fill the parent area.
  final BranchValuesMode branchValuesMode;

  /// Optional inset for nested rendering; if > 0, children are laid out inside
  /// the parent rect with this padding on all sides, making nesting visually
  /// obvious. When 0, children touch the parent edges.
  final double nestedPadding;

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
    this.branchValuesMode = BranchValuesMode.remainder,
    this.nestedPadding = 0.0,
  });

  @override
  State<FlutterTreemap> createState() => _FlutterTreemapState();
}

/// Tree node for hierarchical treemap layout.
class _TreeNode {
  final Treemap data;
  final List<_TreeNode> children = [];
  late double calculatedValue;

  _TreeNode(this.data) {
    // For leaf nodes, use the node value
    // For parent nodes, sum of children will be calculated
    calculatedValue = data.value;
  }

  void calculateValue() {
    if (children.isEmpty) {
      calculatedValue = data.value;
    } else {
      calculatedValue = children.fold(0.0, (sum, child) {
        child.calculateValue();
        return sum + child.calculatedValue;
      });
    }
  }

  bool get isLeaf => children.isEmpty;

  double get ownValue => data.value.abs();
}

class _FlutterTreemapState extends State<FlutterTreemap> {
  double totalWeight = 0;

  /// Build a hierarchical tree from flat node list (Plotly-style).
  ///
  /// Nodes with parent == "" or null are treated as roots.
  /// Returns a list of root nodes with their children properly nested.
  List<_TreeNode> _buildHierarchy(List<Treemap> nodes) {
    // Create a map of label -> TreeNode for easy lookup
    final nodeMap = <String?, _TreeNode>{};
    for (final node in nodes) {
      nodeMap[node.label] = _TreeNode(node);
    }

    // Build parent-child relationships
    for (final node in nodes) {
      if (!node.isRoot && node.parent != null && node.label != null) {
        final parentNode = nodeMap[node.parent];
        final childNode = nodeMap[node.label];
        if (parentNode != null && childNode != null) {
          parentNode.children.add(childNode);
        }
      }
    }

    // Calculate values for all nodes (for parent nodes, sum of children)
    for (final treeNode in nodeMap.values) {
      treeNode.calculateValue();
    }

    // Return only root nodes
    return nodeMap.values.where((node) => node.data.isRoot).toList();
  }

  /// Check if the node list is hierarchical (has parent relationships).
  bool _isHierarchical(List<Treemap> nodes) {
    // Hierarchical if any node has a non-null, non-empty parent
    return nodes.any((node) => node.parent != null && node.parent != '');
  }

  /// Flatten tree to display list (depth-first traversal).
  List<_TreeNode> _flattenTree(List<_TreeNode> roots) {
    final result = <_TreeNode>[];
    for (final root in roots) {
      _flattenTreeNode(root, result);
    }
    return result;
  }

  void _flattenTreeNode(_TreeNode node, List<_TreeNode> result) {
    result.add(node);
    for (final child in node.children) {
      _flattenTreeNode(child, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if data is hierarchical and build tree if needed
    final isHierarchical = _isHierarchical(widget.nodes);
    final List<_TreeNode> treeNodes = isHierarchical
        ? _buildHierarchy(widget.nodes)
        : widget.nodes.map((n) => _TreeNode(n)).toList();

    // Compute total weight from root nodes (use own values for sibling sizing)
    totalWeight = treeNodes.fold(0.0, (sum, node) => sum + node.ownValue);

    if (totalWeight == 0 || widget.nodes.isEmpty) {
      // No nodes → return empty widget.
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rectangleMap = <_TreeNode, Rect>{};

        // Compute treemap layout for root nodes
        _squarifyNodes(
          treeNodes,
          Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight),
          rectangleMap,
        );

        // Flatten tree to get display order (depth-first)
        final displayNodes = _flattenTree(treeNodes);

        // Build treemap tiles.
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: displayNodes.asMap().entries.map((entry) {
            final index = entry.key;
            final treeNode = entry.value;
            final node = treeNode.data;
            final rect = rectangleMap[treeNode];
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

  /// Recursive squarified treemap layout algorithm for hierarchical nodes.
  ///
  /// Splits rectangles into sub-rectangles based on node weights,
  /// attempting to keep aspect ratios close to `1:1`.
  /// For parent nodes with children, recursively layouts children within the parent's rectangle.
  void _squarifyNodes(
    List<_TreeNode> nodes,
    Rect rect,
    Map<_TreeNode, Rect> rectangleMap,
  ) {
    if (nodes.isEmpty || rect.width <= 0 || rect.height <= 0) return;

    // Base case: single node
    if (nodes.length == 1) {
      final node = nodes.first;
      rectangleMap[node] = rect;

      // If node has children, recursively layout them within this rectangle
      if (node.children.isNotEmpty && !node.isLeaf) {
        final childrenSum = node.children.fold(0.0, (s, c) => s + c.ownValue);
        if (childrenSum > 0) {
          if (widget.branchValuesMode == BranchValuesMode.total) {
            // Children fill the full parent rectangle; sizes normalized automatically
            final childRect = _deflate(rect);
            _squarifyNodes(node.children, childRect, rectangleMap);
          } else {
            // remainder: children occupy a portion of the parent's area
            final parentValue = node.ownValue;
            if (parentValue > 0) {
              final ratio = (childrenSum / parentValue).clamp(0.0, 1.0);
              if (ratio > 0) {
                final horizontal = rect.width >= rect.height;
                Rect childRect = horizontal
                    ? Rect.fromLTWH(
                        rect.left,
                        rect.top,
                        rect.width * ratio,
                        rect.height,
                      )
                    : Rect.fromLTWH(
                        rect.left,
                        rect.top,
                        rect.width,
                        rect.height * ratio,
                      );
                childRect = _deflate(childRect);
                _squarifyNodes(node.children, childRect, rectangleMap);
              }
            }
          }
        }
      }
      return;
    }

    final horizontal = (rect.width / rect.height) >= 1.0;

    // Local total (raw sum) for this group
    final localRawSum = nodes.fold(0.0, (sum, n) => sum + n.ownValue);
    // Total adjusted weight (enforcing minTileRatio) using local sum
    final sumWeights = nodes.fold(
      0.0,
      (sum, node) => sum + _adjustedWeight(node, localRawSum),
    );

    // Find optimal split index.
    int splitIndex = _findBestSplitNodes(nodes, rect, sumWeights, localRawSum);

    // Split into two groups.
    final firstGroup = nodes.sublist(0, splitIndex);
    final secondGroup = nodes.sublist(splitIndex);

    // Weight of the first group.
    final double firstWeight = firstGroup.fold(
      0.0,
      (sum, node) => sum + _adjustedWeight(node, localRawSum),
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
    _squarifyNodes(firstGroup, rect1, rectangleMap);
    _squarifyNodes(secondGroup, rect2, rectangleMap);
  }

  /// Returns adjusted node weight considering [minTileRatio].
  double _adjustedWeight(_TreeNode node, double localTotal) {
    final double rawVal = node.ownValue;
    // Ensure node does not shrink below minimum ratio relative to local group
    final double minWeight = localTotal * widget.minTileRatio;
    return max(rawVal, minWeight);
  }

  /// Finds the best index to split the node list
  /// to minimize poor aspect ratios.
  int _findBestSplitNodes(
    List<_TreeNode> nodes,
    Rect rect,
    double sumWeights,
    double localRawSum,
  ) {
    if (nodes.length <= 2) return 1;

    final horizontal = (rect.width / rect.height) >= 1.0;
    int bestIndex = 1;
    double bestAspect = double.infinity;

    for (int i = 1; i < nodes.length; i++) {
      final firstGroup = nodes.sublist(0, i);
      final secondGroup = nodes.sublist(i);

      final firstWeight = firstGroup.fold(
        0.0,
        (sum, node) => sum + _adjustedWeight(node, localRawSum),
      );
      final secondWeight = secondGroup.fold(
        0.0,
        (sum, node) => sum + _adjustedWeight(node, localRawSum),
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
      final aspect1 = _aspectRatioNode(firstWeight, rect, sumWeights, horizontal);
      final aspect2 = _aspectRatioNode(secondWeight, rect, sumWeights, horizontal);
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
  double _aspectRatioNode(
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

  Rect _deflate(Rect rect) {
    final inset = widget.nestedPadding;
    if (inset <= 0) return rect;
    final w = rect.width - inset * 2;
    final h = rect.height - inset * 2;
    if (w <= 0 || h <= 0) return rect;
    return Rect.fromLTWH(rect.left + inset, rect.top + inset, w, h);
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
