import 'package:flutter/material.dart';
import 'package:fyproject/view/home/home_Screen.dart';
import '../services/firebase_service.dart';

class AuthController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  final FirebaseService _firebaseService = FirebaseService();

  Future<void> login(BuildContext context) async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    isLoading = true;

    await Future.delayed(Duration(seconds: 2)); // temp

    isLoading = false;

    Navigator.push(context, MaterialPageRoute(builder: ( context) => HomeScreen()));
  }

  Future<void> googleLogin(BuildContext context) async {
    isLoading = true;

    final user = await _firebaseService.signInWithGoogle();

    isLoading = false;

    if (user != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google sign-in failed")),
      );
    }
  }
}
