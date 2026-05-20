import 'dart:async';
import 'package:flutter/material.dart';
import '../splash_services/splash_services.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

final SplashService splashService = SplashService();

class _SplashscreenState extends State<Splashscreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        splashService.isLogin(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF08111F),
              Color(0xFF102A43),
              Color(0xFF0F766E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -70,
              child: _glowCircle(const Color(0xFF2DD4BF), 220),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: _glowCircle(const Color(0xFF38BDF8), 240),
            ),

            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF14B8A6).withOpacity(0.45),
                                blurRadius: 45,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/app_icon/app_icon.png',
                            height: 125,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      const Text(
                        "IELTS Master",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                          ),
                        ),
                        child: const Text(
                          "Prepare • Practice • Succeed",
                          style: TextStyle(
                            color: Color(0xFFCCFBF1),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 45),

                      const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          color: Color(0xFF2DD4BF),
                          strokeWidth: 3,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        "Building your IELTS journey...",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 26,
              left: 0,
              right: 0,
              child: Text(
                "AI Powered IELTS Preparation",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCircle(Color color, double size) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 90,
            spreadRadius: 25,
          ),
        ],
      ),
    );
  }
}