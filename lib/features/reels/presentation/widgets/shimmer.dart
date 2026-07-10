import 'package:flutter/material.dart';

/// Reusable shimmer sweep effect — animates a moving highlight gradient
/// across [child] on a loop via [ShaderMask], so any screen's loading state
/// can be built as a shaped skeleton (see [SkeletonBox]) instead of a bare
/// spinner, without pulling in a third-party shimmer package.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
            stops: const [0.35, 0.5, 0.65],
            begin: Alignment(-1 - _controller.value * 2, 0),
            end: Alignment(1 - _controller.value * 2, 0),
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
