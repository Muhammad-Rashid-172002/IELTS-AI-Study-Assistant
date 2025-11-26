import 'package:flutter/material.dart';
import 'package:fyproject/Controller/signup_controller.dart';
import 'package:fyproject/view/home/home_Screen.dart';
import 'package:fyproject/widgets/app_button.dart';
import 'package:fyproject/widgets/app_input_field.dart';
import 'package:fyproject/widgets/app_snackbar.dart';
import 'package:fyproject/widgets/google_button.dart';

class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView>
    with SingleTickerProviderStateMixin {
  final SignUpController _controller = SignUpController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Simulate Google signup
  Future<void> _googleSignUp() async {
    AppSnackBar.show(
      context,
      "Google Sign Up clicked",
      type: SnackBarType.info,
    );
    await Future.delayed(Duration(seconds: 2));

    // Simulate successful signup
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );

    AppSnackBar.show(
      context,
      "Signed up with Google!",
      type: SnackBarType.success,
    );
  }

  // Validation functions
  bool _validateEmail(String email) {
    if (email.isEmpty) return false;
    final regex = RegExp(r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$");
    return regex.hasMatch(email);
  }

  bool _validatePassword(String password) {
    return password.isNotEmpty && password.length >= 6;
  }

  bool _validateName(String name) {
    return name.isNotEmpty && name.length >= 3;
  }

  void _handleSignUp() {
    final name = _controller.nameController.text.trim();
    final email = _controller.emailController.text.trim();
    final password = _controller.passwordController.text;

    if (!_validateName(name)) {
      AppSnackBar.show(
        context,
        "Name must be at least 3 characters",
        type: SnackBarType.error,
      );
      return;
    }

    if (!_validateEmail(email)) {
      AppSnackBar.show(
        context,
        "Please enter a valid email",
        type: SnackBarType.error,
      );
      return;
    }

    if (!_validatePassword(password)) {
      AppSnackBar.show(
        context,
        "Password must be at least 6 characters",
        type: SnackBarType.error,
      );
      return;
    }

    // Call controller signup method (or Firebase / API)
    _controller.signUp(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff4F46E5), Color(0xff3730A3), Colors.black87],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Text(
                    "Create Account",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 40),

                  // Name Input
                  AppInputField(
                    hint: "Full Name",
                    controller: _controller.nameController,
                    icon: Icons.person,
                  ),
                  SizedBox(height: 20),

                  // Email Input
                  AppInputField(
                    hint: "Email",
                    controller: _controller.emailController,
                    icon: Icons.email,
                  ),
                  SizedBox(height: 20),

                  // Password Input
                  AppInputField(
                    hint: "Password",
                    controller: _controller.passwordController,
                    isPassword: true,
                    icon: Icons.lock,
                  ),
                  SizedBox(height: 30),

                  // Sign Up Button
                  AppButton(
                    text: "Sign Up",
                    onPressed: _handleSignUp,
                    backgroundColor: Colors.white,
                    textColor: Color(0xff4F46E5),
                  ),

                  SizedBox(height: 20),

                  // OR separator
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white54)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "OR",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white54)),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Google signup button
                  GoogleButton(onPressed: _googleSignUp),

                  SizedBox(height: 20),

                  // Login Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(color: Colors.white70),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Go back to login
                        },
                        child: Text(
                          "Login",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
