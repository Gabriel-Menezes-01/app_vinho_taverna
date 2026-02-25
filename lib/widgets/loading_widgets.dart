import 'package:flutter/material.dart';

class LoadingFadeSwitcher extends StatelessWidget {
  final bool isLoading;
  final Widget loading;
  final Widget child;
  final Duration duration;

  const LoadingFadeSwitcher({
    super.key,
    required this.isLoading,
    required this.loading,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (widget, animation) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final scale = Tween<double>(begin: 0.98, end: 1.0).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: widget),
        );
      },
      child: isLoading
          ? KeyedSubtree(key: const ValueKey('loading'), child: loading)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}

class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration period;
  final Color baseColor;
  final Color highlightColor;

  const Shimmer({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1200),
    this.baseColor = const Color(0xFFE5E7EB),
    this.highlightColor = const Color(0xFFF3F4F6),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerSlideTransform extends GradientTransform {
  final double offsetX;

  const _ShimmerSlideTransform(this.offsetX);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(offsetX, 0.0, 0.0);
  }
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

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
          shaderCallback: (bounds) {
            final width = bounds.width;
            final dx = (width * 2) * _controller.value - width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.2, 0.5, 0.8],
              transform: _ShimmerSlideTransform(dx),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: borderRadius,
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  const ListSkeleton({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 110,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return ShimmerBox(height: itemHeight);
        },
      ),
    );
  }
}

class FormSkeleton extends StatelessWidget {
  final EdgeInsets padding;

  const FormSkeleton({
    super.key,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            ShimmerBox(height: 48),
            SizedBox(height: 16),
            ShimmerBox(height: 48),
            SizedBox(height: 16),
            ShimmerBox(height: 48),
            SizedBox(height: 16),
            ShimmerBox(height: 48),
            SizedBox(height: 16),
            ShimmerBox(height: 96),
            SizedBox(height: 16),
            ShimmerBox(height: 48),
            SizedBox(height: 24),
            ShimmerBox(height: 56),
          ],
        ),
      ),
    );
  }
}
