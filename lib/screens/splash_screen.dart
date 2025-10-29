import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _bgController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotation;

  Timer? _transitionTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.14).chain(CurveTween(curve: Curves.easeOutBack)), weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.14, end: 0.98).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
    ]).animate(_logoController);

    _logoRotation = Tween<double>(begin: -0.05, end: 0.05)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(CurvedAnimation(parent: _logoController, curve: const Interval(0.6, 1.0)));

    _logoController.forward();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _transitionTimer = Timer(const Duration(milliseconds: 2200), () {
      _navigateToNext();
    });
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _logoController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _navigateToNext() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 480),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        final scale = Tween<double>(begin: 0.98, end: 1.0).animate(fade);
        return FadeTransition(opacity: fade, child: ScaleTransition(scale: scale, child: child));
      },
    ));
  }

  Widget _shimmerTitle(BuildContext context) {
    final theme = Theme.of(context);
    final base = (theme.textTheme.headlineMedium ?? const TextStyle(fontSize: 28))
        .copyWith(fontWeight: FontWeight.w800, color: Colors.deepOrange[900]);

    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final double slide = (_bgController.value * 2) - 1;
            return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              colors: [Colors.white.withAlpha((0.95 * 255).round()), Colors.yellow.withAlpha((0.9 * 255).round()), Colors.white.withAlpha((0.95 * 255).round())],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1 - slide, 0),
              end: Alignment(1 - slide, 0),
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Text('Doughminant', style: base),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (disableAnimations && !_navigated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToNext());
    }

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _transitionTimer?.cancel();
          _navigateToNext();
        },
        child: AnimatedBuilder(
          animation: _bgController,
          builder: (context, child) {
            final t = _bgController.value;
            final hue = (t * 40) % 360;
            final color1 = HSLColor.fromAHSL(1, hue, 0.75, 0.66).toColor();
            final color2 = HSLColor.fromAHSL(1, (hue + 30) % 360, 0.88, 0.55).toColor();

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.4 + sin(t * pi * 2) * 0.15, -0.6 + cos(t * pi * 2) * 0.15),
                  radius: 1.1,
                  colors: [color1, color2],
                ),
              ),
              child: Stack(
                children: [
                  CustomPaint(painter: _BlobsPainter(progress: t), size: Size.infinite),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _logoController,
                          builder: (context, child) {
                            final scale = _logoScale.value;
                            final rot = (_logoRotation.value) * (pi / 2);
                            return Transform.rotate(
                              angle: rot,
                              child: Transform.scale(scale: scale, child: child),
                            );
                          },
                          child: const Text('🍕', style: TextStyle(fontSize: 118)),
                        ),
                        const SizedBox(height: 18),
                        _shimmerTitle(context),
                        const SizedBox(height: 8),
                        Text('Pizza ordering made easy', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.brown[800])),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BlobsPainter extends CustomPainter {
  final double progress;
  _BlobsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    final blobs = [
      _BlobConfig(offset: Offset(w * 0.15, h * 0.25), baseR: min(w, h) * 0.22, hue: 24),
      _BlobConfig(offset: Offset(w * 0.8, h * 0.2), baseR: min(w, h) * 0.18, hue: 10),
      _BlobConfig(offset: Offset(w * 0.65, h * 0.72), baseR: min(w, h) * 0.28, hue: 40),
    ];

    for (var i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final phase = (progress + i * 0.2) % 1.0;
      final dx = sin(phase * pi * 2 + i) * (w * 0.02);
      final dy = cos(phase * pi * 2 + i) * (h * 0.02);
      final center = b.offset.translate(dx, dy);
      final radius = b.baseR * (0.9 + 0.15 * sin(phase * pi * 2));

  final color = HSLColor.fromAHSL(1.0, b.hue.toDouble(), 0.9, 0.6).toColor().withAlpha(((0.22 + i * 0.06) * 255).round());
  paint.color = color;
      final path = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
      canvas.drawPath(path, paint);
    }

    // Small pepperoni-like particles for playful motion
    final particleCount = 8;
    for (var p = 0; p < particleCount; p++) {
      final phase = (progress + p * 0.13) % 1.0;
      final x = (w * 0.2) + (sin(phase * pi * 2 + p) * w * 0.35);
      final y = (h * 0.55) - (phase * h * 0.35);
      final pr = min(w, h) * (0.02 + 0.01 * sin(phase * pi * 2 + p));
  final pc = HSLColor.fromAHSL(1.0, 4, 0.87, 0.45).toColor().withAlpha(((0.85 - phase * 0.6) * 255).round());
      paint.color = pc;
      canvas.drawCircle(Offset(x, y), pr, paint);
      // little darker center
  paint.color = Colors.brown.withAlpha(((0.25 * (1 - phase)) * 255).round());
      canvas.drawCircle(Offset(x, y), pr * 0.45, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlobsPainter oldDelegate) => oldDelegate.progress != progress;
}

class _BlobConfig {
  final Offset offset;
  final double baseR;
  final int hue;
  _BlobConfig({required this.offset, required this.baseR, required this.hue});
}
