// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../routes/routes.dart';
// import '../routes/routes_names.dart';
//
// class SplashService {
//   void startSplashTimer() {
//     Timer(const Duration(seconds: 2), () {
//       Get.offAllNamed(RoutesName.home);
//     });
//   }
// }

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes_names.dart';

class SplashService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  void isLogin(BuildContext context) {
    try {
      final User? user = _auth.currentUser;

      Timer(const Duration(milliseconds: 1400), () {
        if (user != null) {
          Get.offAllNamed(RoutesName.home);
        } else {
          Get.offAllNamed(RoutesName.onboarding);
        }
      });
    } catch (e) {
      debugPrint('Splash authentication check failed: $e');
      Get.snackbar(
        'Connection check paused',
        'We could not confirm your session. Continue to get started.',
        snackPosition: SnackPosition.BOTTOM,
      );
      Timer(const Duration(milliseconds: 1600), () {
        Get.offNamed(RoutesName.onboarding);
      });
    }
  }
}
