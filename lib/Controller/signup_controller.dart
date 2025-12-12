import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/resources/app_snackbar.dart';


class SignUpController {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  void signUp(BuildContext context) {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      AppSnackBar.show(context, "Please fill all fields", type: SnackBarType.error);
      return;
    }

    // Here you can add Firebase or API sign-up logic

    AppSnackBar.show(context, "Account created successfully!", type: SnackBarType.success);

    // Clear fields after signup
    nameController.clear();
    emailController.clear();
    passwordController.clear();
  }
}
