import 'package:flutter/material.dart';
import 'package:fyproject/view/home/home_Screen.dart';
import 'package:fyproject/widgets/app_snackbar.dart';


class AuthController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> login(BuildContext context) async {
    // Check if fields are empty
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      AppSnackBar.show(
        context,
        "Please fill all fields",
        type: SnackBarType.error,
      );
      return;
    }

    // Start loading
    isLoading = true;

    // Simulate login delay (replace with Firebase Auth later)
    await Future.delayed(Duration(seconds: 2));

    // Stop loading
    isLoading = false;

    // Navigate to HomeScreen after successful login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );

    // Optional: show success message
    AppSnackBar.show(
      context,
      "Login Successful!",
      type: SnackBarType.success,
    );
  }
}
