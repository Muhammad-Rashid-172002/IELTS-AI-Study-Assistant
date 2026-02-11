import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/registration/registration.dart';


class SplashService {
  void startSplash(BuildContext context) {
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Registration()),
      );
    });
  }
}