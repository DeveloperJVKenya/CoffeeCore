import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Splash screen: a single 7-second choreographed animation that tells the
/// app's motto as a three-act story — a seed is Sown, grows into the lush,
/// ripe-berried coffee plant that is Safeguarded, then beans rise and Soar —
/// ending with a deliberately long hold on the full tagline and app name.
/// `AuthGate` (see main.dart) displays this widget for exactly
/// [totalDurationSeconds] before routing by auth state, so the two must be
/// kept in sync.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Kept in sync with the `Future.delayed` in `AuthGate` (main.dart).
  static const int totalDurationSeconds = 7;

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _totalDuration =
      Duration(seconds: SplashScreen.totalDurationSeconds);

  late final AnimationController _controller;

  // ── Act I: Sow (seed drops onto an invisible ground, then a quick
  // dust-splash reaction plays at the impact point) — 0% to ~20% ──
  late final Animation<double> _seedDrop;
  late final Animation<double> _seedOpacity;
  late final Animation<double> _splashProgress;

  // ── Act II: Safeguard (plant pops/zooms in from the impact point) ─
  // ~19% to ~40%
  late final Animation<double> _plantScale;
  late final Animation<double> _plantOpacity;
  late final Animation<double> _glowPulse;

  // ── Act III: Soar (beans rise away from the anchored plant) ───
  // ~55% to ~80%
  late final Animation<double> _riseProgress;

  // Remaining ~80% to 100% is a deliberate calm hold on the finished scene.

  // ── Text reveals, one per motto word ──────────────────────────
  late final Animation<double> _titleOpacity;
  late final Animation<double> _sowWordOpacity;
  late final Animation<double> _safeguardWordOpacity;
  late final Animation<double> _soarWordOpacity;

  static const List<_BeanSpec> _beans = <_BeanSpec>[
    _BeanSpec(dx: -70, delay: 0.00, riseHeight: 170, size: 14),
    _BeanSpec(dx: -34, delay: 0.08, riseHeight: 210, size: 10),
    _BeanSpec(dx: 0, delay: 0.03, riseHeight: 230, size: 16),
    _BeanSpec(dx: 34, delay: 0.11, riseHeight: 200, size: 11),
    _BeanSpec(dx: 70, delay: 0.05, riseHeight: 180, size: 13),
  ];

  /// Fan-shaped directions the dust-splash specks kick outward in when the
  /// seed lands (upward/outward, not straight down into the invisible
  /// ground).
  static const List<Offset> _dustDirections = <Offset>[
    Offset(-1.0, -0.4),
    Offset(-0.6, -0.9),
    Offset(-0.2, -1.0),
    Offset(0.2, -1.0),
    Offset(0.6, -0.9),
    Offset(1.0, -0.4),
  ];

  Animation<double> _interval(double begin, double end,
      {Curve curve = Curves.easeInOut}) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: curve),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: _totalDuration, vsync: this);

    _titleOpacity = _interval(0.0, 0.10);

    // Act I: Sow
    _seedDrop = Tween<double>(begin: -1.0, end: 0.0).animate(
      _interval(0.04, 0.19, curve: Curves.bounceOut),
    );
    _seedOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      _interval(0.19, 0.24),
    );
    // Fast dust-splash reaction right as the seed touches down.
    _splashProgress = _interval(0.18, 0.29, curve: Curves.easeOut);

    // Act II: Safeguard — the plant pops/zooms from the impact point.
    _plantScale = _interval(0.19, 0.36, curve: Curves.elasticOut);
    _plantOpacity = _interval(0.19, 0.28);
    _glowPulse = _interval(0.40, 0.62, curve: Curves.easeInOut);

    // Act III: Soar
    _riseProgress = _interval(0.54, 0.80, curve: Curves.easeOut);

    // Tagline, staggered across acts, complete well before the final hold.
    _sowWordOpacity = _interval(0.07, 0.17);
    _safeguardWordOpacity = _interval(0.32, 0.42);
    _soarWordOpacity = _interval(0.56, 0.68);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final Color topColor = Color.lerp(
            const Color(0xFF241207),
            const Color(0xFF4A2F1A),
            _controller.value.clamp(0.0, 1.0),
          )!;
          final Color bottomColor = Color.lerp(
            const Color(0xFF1B2A16),
            const Color(0xFF2E7D32),
            _controller.value.clamp(0.0, 1.0),
          )!;

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[topColor, bottomColor],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Opacity(
                    opacity: _titleOpacity.value,
                    child: const Text(
                      'CoffeeCore',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: math.min(screenSize.height * 0.42, 340),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        ..._buildRisingBeans(),
                        _buildGlow(),
                        _buildGrowingPlant(),
                        _buildSeed(),
                        _buildDustSplash(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildTagline(),
                  const SizedBox(height: 36),
                  _buildProgressDots(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// A quick, code-drawn dust-splash reaction at the seed's landing point —
  /// the ground itself stays invisible/transparent so it never visually
  /// clashes with the real plant photo that pops in afterwards.
  Widget _buildDustSplash() {
    final double t = _splashProgress.value.clamp(0.0, 1.0);
    if (t <= 0.0) return const SizedBox.shrink();
    final double opacity = (1 - t).clamp(0.0, 1.0);
    final double radius = 30 * t;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: _dustDirections.map((Offset dir) {
          return Transform.translate(
            offset: Offset(dir.dx * radius, dir.dy * radius * 0.6),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 7 - 3 * t,
                height: 7 - 3 * t,
                decoration: const BoxDecoration(
                  color: Color(0xFF6D4C41),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSeed() {
    if (_seedOpacity.value <= 0.0) return const SizedBox.shrink();
    final double dy = _seedDrop.value * 140;
    return Transform.translate(
      offset: Offset(0, dy),
      child: Opacity(
        opacity: _seedOpacity.value.clamp(0.0, 1.0),
        child: Container(
          width: 16,
          height: 20,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF6D4C41),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  /// Builds the growing coffee plant: the real
  /// `lushcoffeeplantwithripeberries` asset scaling and fading in from the
  /// sown seed. The trunk stays anchored to the soil the whole time — only
  /// the beans rise away from it during Act III, the plant itself never
  /// lifts off the ground.
  Widget _buildGrowingPlant() {
    final double opacity = _plantOpacity.value.clamp(0.0, 1.0);
    if (opacity <= 0.0) return const SizedBox.shrink();

    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    const double displayHeight = 240;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        // No upper clamp: elasticOut deliberately overshoots past 1.0 for a
        // punchy pop-in bounce before settling at full size.
        scale: math.max(0.0, 0.35 + 0.65 * _plantScale.value),
        alignment: Alignment.bottomCenter,
        child: Image.asset(
          'assets/lushcoffeeplantwithripeberries.png',
          height: displayHeight,
          cacheHeight: (displayHeight * devicePixelRatio).round(),
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }

  Widget _buildGlow() {
    final double t = _glowPulse.value;
    if (t <= 0.0) return const SizedBox.shrink();
    final double pulse = 0.85 + 0.15 * math.sin(t * math.pi * 3);
    return Opacity(
      opacity: (t * (1 - t) * 4).clamp(0.0, 1.0) * 0.8 + (t > 0 ? 0.15 : 0),
      child: Transform.scale(
        scale: pulse,
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF81C784).withValues(alpha: 0.6),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRisingBeans() {
    return _beans.map((bean) {
      final double local =
          ((_riseProgress.value - bean.delay) / (1 - bean.delay))
              .clamp(0.0, 1.0);
      if (local <= 0.0) return const SizedBox.shrink();
      final double dy = -bean.riseHeight * local - 60;
      final double opacity = local < 0.15
          ? local / 0.15
          : (1 - ((local - 0.15) / 0.85)).clamp(0.0, 1.0);
      return Transform.translate(
        offset: Offset(bean.dx, dy),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scaleX: 0.68,
            child: Container(
              width: bean.size,
              height: bean.size * 1.3,
              decoration: BoxDecoration(
                color: const Color(0xFF4A2F1A),
                borderRadius: BorderRadius.circular(bean.size),
                border: Border.all(color: const Color(0xFF2E1A0F), width: 1),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTagline() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _mottoWord('Sow', _sowWordOpacity.value),
        _mottoSeparator(math.max(
            _sowWordOpacity.value, _safeguardWordOpacity.value > 0 ? 1 : 0)),
        _mottoWord('Safeguard', _safeguardWordOpacity.value),
        _mottoSeparator(_safeguardWordOpacity.value > 0.9
            ? _soarWordOpacity.value.clamp(0.0, 1.0)
            : 0),
        _mottoWord('Soar', _soarWordOpacity.value),
      ],
    );
  }

  Widget _mottoWord(String word, double opacity) {
    final double clamped = opacity.clamp(0.0, 1.0);
    return Opacity(
      opacity: clamped,
      child: Transform.translate(
        offset: Offset(0, (1 - clamped) * 8),
        child: Text(
          word,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _mottoSeparator(double opacity) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          ',',
          style: TextStyle(fontSize: 24, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (index) {
        final double phase = (_controller.value * 3 - index) % 3;
        final double scale =
            0.6 + 0.4 * math.sin(phase.clamp(0.0, 1.0) * math.pi);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Transform.scale(
            scale: scale.clamp(0.6, 1.0),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white70,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BeanSpec {
  final double dx;
  final double delay;
  final double riseHeight;
  final double size;

  const _BeanSpec({
    required this.dx,
    required this.delay,
    required this.riseHeight,
    required this.size,
  });
}
