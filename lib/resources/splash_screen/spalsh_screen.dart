import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final AnimationController _particleController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _configureSystemUi();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _particleController = AnimationController(
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

    _contentOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );

    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.20), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _entranceController.forward();

    _navigationTimer = Timer(const Duration(seconds: 4), _openNextScreen);
  }

  Future<void> _configureSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Color(0xFF040A13),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  void _openNextScreen() {
    if (!mounted) return;

    final Widget nextScreen = FirebaseAuth.instance.currentUser != null
        ? const IELTSMainNavigation()
        : const LanguageSelectionScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          final scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
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
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040A13),
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _PremiumBackground(),

            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ParticlePainter(
                    progress: _particleController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            SafeArea(
              minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final screenHeight = constraints.maxHeight;

                  final logoSize = math
                      .min(screenWidth * 0.42, screenHeight * 0.21)
                      .clamp(128.0, 210.0);

                  final compactHeight = screenHeight < 650;

                  return Column(
                    children: [
                      SizedBox(
                        height: compactHeight ? 10 : screenHeight * 0.055,
                      ),

                      Expanded(
                        flex: compactHeight ? 5 : 6,
                        child: Center(
                          child: AnimatedBuilder(
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
                                    size: logoSize,
                                    glowProgress: _glowController.value,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      FadeTransition(
                        opacity: _contentOpacity,
                        child: SlideTransition(
                          position: _contentSlide,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _AppTitle(),
                              SizedBox(height: 12),
                              _Tagline(),
                              SizedBox(height: 20),
                              _FeatureBadge(),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      const _PremiumLoadingIndicator(),
                      const SizedBox(height: 18),

                      Text(
                        'Preparing your intelligent learning experience',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: compactHeight ? 11.5 : 13,
                          height: 1.35,
                          letterSpacing: 0.15,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Text(
                      //   'VERSION 1.0.0',
                      //   textAlign: TextAlign.center,
                      //   style: TextStyle(
                      //     color: Colors.white.withValues(alpha: 0.34),
                      //     fontSize: compactHeight ? 11 : 12,
                      //     fontWeight: FontWeight.w500,
                      //     letterSpacing: 2.4,
                      //   ),
                      // ),
                      SizedBox(
                        height: compactHeight ? 12 : screenHeight * 0.045,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
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
          child: DecoratedBox(
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
  final double size;
  final double glowProgress;

  const _PremiumLogo({required this.size, required this.glowProgress});

  @override
  Widget build(BuildContext context) {
    final glowStrength = 0.22 + (glowProgress * 0.20);
    final glowBlur = 28 + (glowProgress * 16);

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF06B6D4).withValues(alpha: glowStrength),
                  const Color(
                    0xFF2563EB,
                  ).withValues(alpha: glowStrength * 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          Container(
            width: size * 0.78,
            height: size * 0.78,
            padding: EdgeInsets.all(size * 0.008),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF60A5FA),
                  Color(0xFF06B6D4),
                  Color(0xFF8B5CF6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF06B6D4,
                  ).withValues(alpha: glowStrength),
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
                borderRadius: BorderRadius.circular(size * 0.19),
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
                    top: size * 0.08,
                    left: size * 0.11,
                    right: size * 0.11,
                    child: Container(
                      height: size * 0.18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size * 0.12),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.09),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  _BookAIIcon(size: size * 0.49),

                  Positioned(
                    top: size * 0.13,
                    right: size * 0.14,
                    child: Container(
                      width: size * 0.055,
                      height: size * 0.055,
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
      ),
    );
  }
}

class _BookAIIcon extends StatelessWidget {
  final double size;

  const _BookAIIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: size * 0.05,
            child: Container(
              width: size * 0.90,
              height: size * 0.58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size * 0.10),
                  topRight: Radius.circular(size * 0.10),
                  bottomLeft: Radius.circular(size * 0.17),
                  bottomRight: Radius.circular(size * 0.17),
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
            left: size * 0.10,
            bottom: size * 0.11,
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-0.18),
              alignment: Alignment.center,
              child: _BookPage(
                width: size * 0.38,
                height: size * 0.46,
                leftPage: true,
              ),
            ),
          ),

          Positioned(
            right: size * 0.10,
            bottom: size * 0.11,
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(0.18),
              alignment: Alignment.center,
              child: _BookPage(
                width: size * 0.38,
                height: size * 0.46,
                leftPage: false,
              ),
            ),
          ),

          Positioned(
            top: 0,
            child: Container(
              width: size * 0.40,
              height: size * 0.40,
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
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: size * 0.22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookPage extends StatelessWidget {
  final double width;
  final double height;
  final bool leftPage;

  const _BookPage({
    required this.width,
    required this.height,
    required this.leftPage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(leftPage ? width * 0.22 : width * 0.10),
          bottomLeft: Radius.circular(leftPage ? width * 0.25 : width * 0.10),
          topRight: Radius.circular(leftPage ? width * 0.10 : width * 0.22),
          bottomRight: Radius.circular(leftPage ? width * 0.10 : width * 0.25),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          width * 0.22,
          height * 0.25,
          width * 0.16,
          height * 0.16,
        ),
        child: Column(
          children: [
            _bookLine(width * 0.58),
            SizedBox(height: height * 0.10),
            _bookLine(width * 0.45),
            SizedBox(height: height * 0.10),
            _bookLine(width * 0.55),
          ],
        ),
      ),
    );
  }

  Widget _bookLine(double lineWidth) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: lineWidth,
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
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = (width * 0.075).clamp(26.0, 35.0);
    final masterSize = (width * 0.064).clamp(22.0, 30.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'IELTS AI',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFF8FAFC),
            fontSize: titleSize,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 6),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [Color(0xFF60A5FA), Color(0xFF22D3EE), Color(0xFFA78BFA)],
            ).createShader(bounds);
          },
          child: Text(
            'MASTER',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: masterSize,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: 4.5,
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
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
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
                letterSpacing: 0.80,
              ),
            ),
          ],
        ),
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
      width: 84,
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
                  width: 28,
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
