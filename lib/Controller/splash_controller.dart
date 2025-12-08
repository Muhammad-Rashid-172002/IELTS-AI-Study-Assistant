import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyproject/view/onboarding/onboarding_screen.dart';
import 'package:fyproject/view/home/home_Screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashController {
  void startSplashTimer(BuildContext context) async {
    Timer(const Duration(seconds: 3), () async {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      bool isFirstTime = prefs.getBool("isFirstTime") ?? true;

      if (isFirstTime) {
        // First Time User → Show Onboarding
        prefs.setBool("isFirstTime", false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingView()),
        );
      } else {
        // Already Logged Before → Go to Home Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }
}
