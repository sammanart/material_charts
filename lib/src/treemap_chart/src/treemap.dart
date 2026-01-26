import 'dart:math';
import 'package:flutter/material.dart';

/// A model class representing a **single node in a Treemap**.
///
/// Each [Treemap] has:
/// - a numeric [value] that determines its area in the treemap,
/// - an optional [label] for display,
/// - and a [color] used for its rectangle.
///
/// If [color] is not provided, a **random light color** is automatically assigned.
class Treemap {
  /// The numeric value of this node.
  ///
  /// Determines the area of the tile in the treemap layout.
  double value;

  /// Optional label displayed inside the tile.
  ///
  /// Can be `null` if you don't want a label.
  String? label;

  /// The fill color of the treemap tile.
  ///
  /// If not specified, a random pastel-like color is generated.
  Color color;

  /// Creates a [Treemap] node.
  ///
  /// - [value] must be non-negative.
  /// - [label] is optional.
  /// - [color] is optional; if omitted, a random light color is assigned.
  Treemap({required this.value, this.label, Color? color})
    : color = color ?? _getRandomColor();

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
}
