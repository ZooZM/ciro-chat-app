import 'package:flutter/material.dart';

/// A solid placeholder block — the shape [Shimmer] sweeps its highlight
/// across. Compose these into a layout that mirrors a real screen's content
/// to build that screen's own loading skeleton.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 6,
    this.color = const Color(0xFFBDBDBD),
  })  : _circle = false,
        _size = null;

  const SkeletonBox.circle({
    super.key,
    required double size,
    this.color = const Color(0xFFBDBDBD),
  })  : _circle = true,
        _size = size,
        width = null,
        height = 0,
        borderRadius = 0;

  final double? width;
  final double height;
  final double borderRadius;
  final Color color;
  final bool _circle;
  final double? _size;

  @override
  Widget build(BuildContext context) {
    if (_circle) {
      return DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: SizedBox(width: _size, height: _size),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}
