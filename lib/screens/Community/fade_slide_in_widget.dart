import 'package:flutter/material.dart';

/// Fades and slides its [child] upward into place on mount.
///
/// Give each instance in a list/column an increasing [index] to stagger
/// their entrances relative to one another (e.g. form sections appearing
/// one after another, or feed cards revealing as they scroll into view).
/// The stagger delay wraps every [maxStaggerSteps] so items far down a
/// long list don't sit invisible for an unreasonable amount of time.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration stepDelay;
  final int maxStaggerSteps;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 320),
    this.stepDelay = const Duration(milliseconds: 35),
    this.maxStaggerSteps = 12,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _fade = curved;
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(curved);

    final step = widget.index % widget.maxStaggerSteps;
    final delay = widget.stepDelay * step;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
