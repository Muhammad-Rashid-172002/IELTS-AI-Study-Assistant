import 'dart:async';
import 'package:flutter/material.dart';

class SplashController {
  void startSplashTimer(BuildContext context, Widget nextScreen) {
    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    });
  }
}
