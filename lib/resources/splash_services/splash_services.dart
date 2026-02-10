import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/login/login.dart';


class SplashService {
  void startSplash(BuildContext context) {
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
      );
    });
  }
}