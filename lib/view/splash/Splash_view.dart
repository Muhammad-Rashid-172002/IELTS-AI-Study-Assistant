import 'package:flutter/material.dart';
import 'package:fyproject/Controller/splash_controller.dart';
import 'package:fyproject/utils/app_colors.dart';
import 'package:fyproject/view/onboarding/onboarding_screen.dart';

class SplashView extends StatefulWidget {
  const SplashView({Key? key}) : super(key: key);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  final SplashController controller = SplashController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    controller.startSplashTimer(context, const OnboardingView());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // dark blue
              Color(0xFF1E293B),
              Color(0xFF334155), // slate blue
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glass Logo Box
                  Container(
                    padding: const EdgeInsets.all(35),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 25,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded, // AI theme icon
                      size: 90,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // App Name
                  Text(
                    "IELTS AI Study Assistant",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    "Smarter Practice. Faster Learning.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 45),

                  // Loading Indicator
                  const SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
