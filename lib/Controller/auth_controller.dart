// auth controller

import 'package:flutter/material.dart';

class AuthController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> login(BuildContext context) async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please fill all fields",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          backgroundColor: Color(0xff4F46E5), // deep purple to match your theme
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: Duration(seconds: 2),
          animation: CurvedAnimation(
            parent: AnimationController(
              vsync: Scaffold.of(context),
              duration: Duration(milliseconds: 300),
            )..forward(),
            curve: Curves.easeInOut,
          ),
        ),
      );
      return;
    }

    isLoading = true;

    // TODO: Firebase login (later add karenge)
    await Future.delayed(Duration(seconds: 2));

    isLoading = false;

    // After login success → go to home screen
    Navigator.pushReplacementNamed(context, '/home');
  }
}
