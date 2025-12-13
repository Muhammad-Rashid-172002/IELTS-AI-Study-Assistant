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
import 'package:get/get_core/src/get_main.dart';

import '../routes/routes.dart';
import '../routes/routes_names.dart';

class SplashService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  void isLogin(BuildContext context) {

    try {
      final User? user = _auth.currentUser;

      Timer(const Duration(seconds: 2), () {
        if (user != null) {
          Get.offAllNamed(RoutesName.home);
        } else {
          Get.offAllNamed(RoutesName.login);
        }
      });
    } catch (e) {
      Get.snackbar("Error", "Authentication check failed: $e",
          snackPosition: SnackPosition.BOTTOM);
      Timer(const Duration(seconds: 4), () {
        Get.offNamed(RoutesName.login);
      });
    }
  }
}