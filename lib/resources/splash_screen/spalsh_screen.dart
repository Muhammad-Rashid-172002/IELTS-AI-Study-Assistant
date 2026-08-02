import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/Language_selection_screen/language_selection_screen.dart';
import 'package:fyproject/resources/bottom_navigation_bar/botton_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _glowController;
  late final AnimationController _rotationController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _contentSlide;
  late final Animation<double> _contentOpacity;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _logoScale = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
    );

    _logoOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _contentSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _contentOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.40, 1.0, curve: Curves.easeOut),
    );

    _entranceController.forward();

    _navigationTimer = Timer(const Duration(seconds: 4), _openNextScreen);
  }

  void _openNextScreen() {
    if (!mounted) return;

   // final user = FirebaseAuth.instance.currentUser;

    final Widget nextScreen = FirebaseAuth.instance.currentUser != null
        ? const IELTSMainNavigation()
        : const LanguageSelectionScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, animation, secondaryAnimation) {
          return nextScreen;
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          final scaleAnimation = Tween<double>(begin: 0.97, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entranceController.dispose();
    _glowController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _PremiumBackground()),

          Positioned.fill(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ParticlePainter(
                    progress: _rotationController.value,
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                children: [
                  const Spacer(),

                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _entranceController,
                      _glowController,
                    ]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: _PremiumLogo(
                            glowProgress: _glowController.value,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 34),

                  AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _contentOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _contentSlide.value),
                          child: child,
                        ),
                      );
                    },
                    child: const Column(
                      children: [
                        _AppTitle(),
                        SizedBox(height: 12),
                        _Tagline(),
                        SizedBox(height: 24),
                        _FeatureBadge(),
                      ],
                    ),
                  ),

                  const Spacer(),

                  AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _contentOpacity.value,
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        const _PremiumLoadingIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Preparing your intelligent learning experience',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.25,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'VERSION 1.0.0',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.32),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF040A13),
                Color(0xFF07111F),
                Color(0xFF09182A),
                Color(0xFF07111F),
              ],
              stops: [0.0, 0.32, 0.68, 1.0],
            ),
          ),
        ),

        Positioned(
          top: -170,
          right: -130,
          child: _GlowOrb(
            size: 360,
            color: const Color(0xFF2563EB).withValues(alpha: 0.18),
          ),
        ),

        Positioned(
          left: -170,
          bottom: -150,
          child: _GlowOrb(
            size: 380,
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
          ),
        ),

        Positioned(
          top: 280,
          left: -100,
          child: _GlowOrb(
            size: 260,
            color: const Color(0xFF06B6D4).withValues(alpha: 0.10),
          ),
        ),

        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.25),
                radius: 1.05,
                colors: [
                  Colors.transparent,
                  const Color(0xFF02060D).withValues(alpha: 0.38),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _PremiumLogo extends StatelessWidget {
  final double glowProgress;

  const _PremiumLogo({required this.glowProgress});

  @override
  Widget build(BuildContext context) {
    final glowStrength = 0.22 + (glowProgress * 0.20);
    final glowBlur = 28 + (glowProgress * 16);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF06B6D4).withValues(alpha: glowStrength),
                const Color(0xFF2563EB).withValues(alpha: glowStrength * 0.45),
                Colors.transparent,
              ],
            ),
          ),
        ),

        Container(
          width: 132,
          height: 132,
          padding: const EdgeInsets.all(1.4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(38),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF60A5FA), Color(0xFF06B6D4), Color(0xFF8B5CF6)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withValues(alpha: glowStrength),
                blurRadius: glowBlur,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(
                  0xFF8B5CF6,
                ).withValues(alpha: glowStrength * 0.65),
                blurRadius: glowBlur + 8,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36.5),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF13263D),
                  Color(0xFF091523),
                  Color(0xFF0A1526),
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 12,
                  left: 18,
                  right: 18,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.09),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                const _BookAIIcon(),

                Positioned(
                  top: 21,
                  right: 22,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF67E8F9),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF22D3EE,
                          ).withValues(alpha: 0.85),
                          blurRadius: 14,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BookAIIcon extends StatelessWidget {
  const _BookAIIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 4,
            child: Container(
              width: 70,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(13),
                  bottomRight: Radius.circular(13),
                ),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 8,
            bottom: 9,
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-0.18),
              alignment: Alignment.center,
              child: Container(
                width: 30,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(7),
                    bottomLeft: Radius.circular(8),
                    topRight: Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 9, 5, 7),
                  child: Column(
                    children: [
                      _bookLine(18),
                      const SizedBox(height: 4),
                      _bookLine(14),
                      const SizedBox(height: 4),
                      _bookLine(17),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            right: 8,
            bottom: 9,
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(0.18),
              alignment: Alignment.center,
              child: Container(
                width: 30,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(7),
                    bottomRight: Radius.circular(8),
                    topLeft: Radius.circular(3),
                    bottomLeft: Radius.circular(3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 9, 8, 7),
                  child: Column(
                    children: [
                      _bookLine(18),
                      const SizedBox(height: 4),
                      _bookLine(14),
                      const SizedBox(height: 4),
                      _bookLine(17),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 0,
            child: Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF67E8F9), Color(0xFF8B5CF6)],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.58),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bookLine(double width) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: 2,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'IELTS AI',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 5),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [Color(0xFF60A5FA), Color(0xFF22D3EE), Color(0xFFA78BFA)],
            ).createShader(bounds);
          },
          child: const Text(
            'MASTER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 29,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: 5,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your Personal AI IELTS Coach',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.68),
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.45,
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22D3EE),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'ADAPTIVE  •  INTELLIGENT  •  PERSONALIZED',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.85,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumLoadingIndicator extends StatefulWidget {
  const _PremiumLoadingIndicator();

  @override
  State<_PremiumLoadingIndicator> createState() =>
      _PremiumLoadingIndicatorState();
}

class _PremiumLoadingIndicatorState extends State<_PremiumLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 5,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Align(
                alignment: Alignment((_controller.value * 2) - 1, 0),
                child: Container(
                  width: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF22D3EE),
                        Color(0xFF8B5CF6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;

  _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    const particles = [
      Offset(0.12, 0.18),
      Offset(0.83, 0.16),
      Offset(0.91, 0.42),
      Offset(0.13, 0.65),
      Offset(0.78, 0.72),
      Offset(0.24, 0.86),
      Offset(0.66, 0.29),
      Offset(0.38, 0.12),
    ];

    for (int index = 0; index < particles.length; index++) {
      final base = particles[index];
      final angle = (progress * math.pi * 2) + (index * 0.75);

      final movementX = math.sin(angle) * 5;
      final movementY = math.cos(angle) * 7;

      final x = (base.dx * size.width) + movementX;
      final y = (base.dy * size.height) + movementY;

      final opacity = 0.08 + ((math.sin(angle) + 1) * 0.045);

      paint.color = index.isEven
          ? const Color(0xFF38BDF8).withValues(alpha: opacity)
          : const Color(0xFFA78BFA).withValues(alpha: opacity);

      canvas.drawCircle(Offset(x, y), index % 3 == 0 ? 2.1 : 1.3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
