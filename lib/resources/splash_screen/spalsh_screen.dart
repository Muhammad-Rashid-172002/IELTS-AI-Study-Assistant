import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../splash_services/splash_services.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen>
    with TickerProviderStateMixin {
  final SplashService splashService = SplashService();

  late final AnimationController _introController;
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  late final AnimationController _dotsController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _logoSlide;

  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;

  late final Animation<double> _bottomFade;
  late final Animation<double> _pulseAnimation;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    _logoFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.68, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
          ),
        );

    _titleFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.30, 0.72, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.28, 0.75, curve: Curves.easeOutCubic),
          ),
        );

    _bottomFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.58, 1.0, curve: Curves.easeOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _introController.forward();

    _navigationTimer = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) {
        splashService.isLogin(context);
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _introController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isSmallScreen = screenSize.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF06101C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _background(),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isSmallScreen ? 14 : 24,
              ),
              child: Column(
                children: [
                  const Spacer(),

                  FadeTransition(
                    opacity: _logoFade,
                    child: SlideTransition(
                      position: _logoSlide,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: _logoSection(isSmallScreen: isSmallScreen),
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 26 : 36),

                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: _titleSection(),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 28 : 42),

                  FadeTransition(
                    opacity: _bottomFade,
                    child: _loadingSection(),
                  ),

                  const Spacer(),

                  FadeTransition(
                    opacity: _bottomFade,
                    child: _bottomBranding(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _background() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF06101C), Color(0xFF0B1C2E), Color(0xFF0B3B3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),

        Positioned(
          top: -140,
          right: -110,
          child: _glowOrb(color: const Color(0xFF2DD4BF), size: 300),
        ),

        Positioned(
          bottom: -150,
          left: -110,
          child: _glowOrb(color: const Color(0xFF38BDF8), size: 320),
        ),

        Positioned(
          top: 180,
          left: -70,
          child: _glowOrb(
            color: const Color(0xFF8B5CF6),
            size: 170,
            opacity: 0.08,
          ),
        ),

        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _GridPainter())),
        ),

        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.1, -0.15),
                  radius: 1.1,
                  colors: [Colors.white.withOpacity(0.035), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _logoSection({required bool isSmallScreen}) {
    final logoSize = isSmallScreen ? 128.0 : 154.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _rotationController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: SizedBox(
            height: logoSize + 70,
            width: logoSize + 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: Container(
                    height: logoSize + 62,
                    width: logoSize + 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF5EEAD4).withOpacity(0.18),
                        width: 1.2,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Transform.translate(
                        offset: const Offset(0, -4),
                        child: Container(
                          height: 8,
                          width: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF5EEAD4),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF2DD4BF),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Container(
                  height: logoSize + 38,
                  width: logoSize + 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2DD4BF).withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                Container(
                  height: logoSize,
                  width: logoSize,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(38),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.16),
                        Colors.white.withOpacity(0.055),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.34),
                        blurRadius: 42,
                        spreadRadius: 4,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(31),
                    child: Image.asset(
                      'assets/app_icon/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _titleSection() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFD5FFFA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds);
          },
          child: const Text(
            'IELTS AI Master',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Your intelligent path to IELTS success',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.62),
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.15,
          ),
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2DD4BF).withOpacity(0.18),
                const Color(0xFF38BDF8).withOpacity(0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF5EEAD4).withOpacity(0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14B8A6).withOpacity(0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 17,
                color: Color(0xFF5EEAD4),
              ),
              SizedBox(width: 9),
              Text(
                'Prepare  •  Practice  •  Achieve',
                style: TextStyle(
                  color: Color(0xFFD5FFFA),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loadingSection() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _dotsController,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final progress = (_dotsController.value + (index * 0.23)) % 1.0;

                final scale = 0.75 + (math.sin(progress * math.pi) * 0.35);

                final opacity = 0.35 + (math.sin(progress * math.pi) * 0.65);

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    height: 9,
                    width: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF5EEAD4).withOpacity(opacity),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF2DD4BF,
                          ).withOpacity(opacity * 0.6),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),

        const SizedBox(height: 16),

        Text(
          'Preparing your personalized learning experience',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.52),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _bottomBranding() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 1,
            color: Colors.white.withOpacity(0.14),
          ),

          const SizedBox(height: 13),

          Text(
            'POWERED BY ARTIFICIAL INTELLIGENCE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.34),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.35,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Rashid Apps',
            style: TextStyle(
              color: const Color(0xFF5EEAD4).withOpacity(0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb({
    required Color color,
    required double size,
    double opacity = 0.14,
  }) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity * 1.8),
            blurRadius: 110,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.022)
      ..strokeWidth = 0.7;

    const spacing = 42.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
