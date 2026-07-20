import 'package:flutter/material.dart';

/// Shared CoffeeCore tokens for the Direct Message surfaces.
class CoffeeCoreDm {
  CoffeeCoreDm._();

  static const Color canvas = Color(0xFFF5F0EE);
  static const Color espresso = Color(0xFF3E2723);
  static const Color mocha = Color(0xFF5D4037);
  static const Color brew = Color(0xFF6D4C41);
  static const Color latte = Color(0xFF8D6E63);
  static const Color accent = Color(0xFFA1785C);

  static const double cardRadius = 24;
  static const double bubbleRadius = 20;
}

/// Tactile ink splash + gentle spring-back scale for tap targets.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? splashColor;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius =
        const BorderRadius.all(Radius.circular(CoffeeCoreDm.cardRadius)),
    this.splashColor,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  double _scale = 1.0;

  void _setPressed(bool pressed) =>
      setState(() => _scale = pressed ? 0.94 : 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        child: InkWell(
          borderRadius: widget.borderRadius,
          splashColor: (widget.splashColor ?? CoffeeCoreDm.mocha)
              .withValues(alpha: 0.18),
          highlightColor: (widget.splashColor ?? CoffeeCoreDm.mocha)
              .withValues(alpha: 0.08),
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: widget.child,
        ),
      ),
    );
  }
}
