import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyproject/view/onboarding/onboarding_screen.dart';

class SplashController {
  void startSplashTimer(BuildContext context, Widget nextScreen) {
    Timer(Duration(seconds: 3), () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OnboardingView()),
      );
    });
  }
}
