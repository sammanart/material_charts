import 'dart:math';
import 'package:flutter/material.dart';

/// A model class representing a **single node in a Treemap**.
///
/// Each [Treemap] has:
/// - a numeric [value] that determines its area in the treemap,
/// - an optional [label] for display,
/// - an optional [parent] for hierarchical structure (Plotly-style),
/// - and a [color] used for its rectangle.
///
/// If [color] is not provided, a **default light color** is assigned.
///
/// # Hierarchical Structure (Plotly-compatible)
///
/// To create a hierarchical treemap like Plotly:
/// - Set [parent] to an empty string ("") or null for root nodes
/// - Set [parent] to the label of the parent node for child nodes
///
/// Example:
/// ```dart
/// [
///   Treemap(value: 100, label: "Root", parent: ""),
///   Treemap(value: 50, label: "Child1", parent: "Root"),
///   Treemap(value: 50, label: "Child2", parent: "Root"),
/// ]
/// ```
class Treemap {
  /// The numeric value of this node.
  ///
  /// Determines the area of the tile in the treemap layout.
  double value;

  /// Optional label displayed inside the tile.
  ///
  /// Can be `null` if you don't want a label.
  String? label;

  /// Optional parent label for hierarchical structure (Plotly-compatible).
  ///
  /// - Empty string ("") or null indicates this is a root node
  /// - Non-empty string indicates the label of the parent node
  /// - Used to build parent-child relationships in the treemap
  String? parent;

  /// The fill color of the treemap tile.
  ///
  /// If not specified, a default light color is generated.
  Color color;

  /// Creates a [Treemap] node.
  ///
  /// - [value] must be non-negative.
  /// - [label] is optional.
  /// - [parent] is optional; empty string or null for root nodes.
  /// - [color] is optional; if omitted, a default light color is assigned.
  Treemap({
    required this.value,
    this.label,
    this.parent,
    Color? color,
  }) : color = color ?? _getRandomColor();

  /// Generates a random **light color**.
  ///
  /// Ensures that text (usually black) remains visible
  /// by keeping RGB values in the 150–255 range.
  static Color _getRandomColor() {
    final Random random = Random();

    // Generate values in the lighter RGB range (150–255).
    int r = 150 + random.nextInt(106); // 150–255
    int g = 150 + random.nextInt(106); // 150–255
    int b = 150 + random.nextInt(106); // 150–255

    return Color.fromARGB(255, r, g, b);
  }

  /// Check if this is a root node (no parent or empty parent).
  bool get isRoot => parent == null || parent == '';

  /// Get parent hierarchy level (0 for root).
  int get hierarchyLevel {
    if (isRoot) return 0;
    // In a flat list representation, we can't determine depth without full tree
    // This would be calculated during tree building
    return 0;
  }
}

