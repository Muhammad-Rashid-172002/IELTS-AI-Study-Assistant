// auth controller

import 'package:flutter/material.dart';

class AuthController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> login(BuildContext context) async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields")),
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
