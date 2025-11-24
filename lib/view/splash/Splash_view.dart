import 'package:flutter/material.dart';
import 'package:fyproject/Controller/splash_controller.dart';
import 'package:fyproject/utils/app_colors.dart';
import 'package:fyproject/view/onboarding/onboarding_screen.dart';

class SplashView extends StatefulWidget {
  const SplashView({Key? key}) : super(key: key);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  final SplashController controller = SplashController();

  @override
  void initState() {
    super.initState();
    // Start timer to navigate to Login Screen
    controller.startSplashTimer(context, OnboardingView());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              "IELTS AI Study Assistant",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
  }
}
