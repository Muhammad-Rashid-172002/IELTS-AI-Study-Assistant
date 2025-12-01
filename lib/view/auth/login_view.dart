import 'package:flutter/material.dart';
import 'package:fyproject/Controller/auth_controller.dart';
import 'package:fyproject/view/auth/forgot_password.dart';
import 'package:fyproject/view/auth/signup_view.dart';
import 'package:fyproject/view/home/home_Screen.dart';
import 'package:fyproject/widgets/app_button.dart';
import 'package:fyproject/widgets/app_input_field.dart';
import 'package:fyproject/widgets/app_snackbar.dart';
import 'package:fyproject/widgets/google_button.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final AuthController controller = AuthController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Controllers with validation wrapper
  late AppInputField emailField;
  late AppInputField passwordField;

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

    // Initialize input fields
    emailField = AppInputField(
      hint: "Email",
      controller: controller.emailController,
      icon: Icons.email_rounded,
      inputType: InputType.email,
    );

    passwordField = AppInputField(
      hint: "Password",
      controller: controller.passwordController,
      icon: Icons.lock_rounded,
      isPassword: true,
      inputType: InputType.password,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Simulate Google login
  Future<void> _googleLogin() async {
    AppSnackBar.show(context, "Google login clicked", type: SnackBarType.info);
    await Future.delayed(Duration(seconds: 2));

    // Simulate successful login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );

    AppSnackBar.show(
      context,
      "Logged in with Google!",
      type: SnackBarType.success,
    );
  }

  // Validate inputs
  bool _validateEmail(String email) {
    if (email.isEmpty) return false;
    final regex = RegExp(r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$");
    return regex.hasMatch(email);
  }

  bool _validatePassword(String password) {
    return password.isNotEmpty && password.length >= 6;
  }

  bool _validateInputs() {
    bool emailValid = _validateEmail(controller.emailController.text.trim());
    bool passwordValid = _validatePassword(
      controller.passwordController.text.trim(),
    );
    return emailValid && passwordValid;
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
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(25),
                margin: EdgeInsets.symmetric(horizontal: 25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Login to continue",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    SizedBox(height: 30),

                    // Email field with validation
                    emailField,
                    SizedBox(height: 20),

                    // Password field with validation
                    passwordField,
                    SizedBox(height: 30),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ForgotPassword(),
                          ),
                        );
                      },
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    // Login button
                    controller.isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : AppButton(
                            text: "Login",
                            onPressed: () async {
                              if (_validateInputs()) {
                                setState(() {});
                                await controller.login(context);
                                setState(() {});
                              } else {
                                AppSnackBar.show(
                                  context,
                                  "Please fix the errors above",
                                  type: SnackBarType.error,
                                );
                              }
                            },
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

                    // Google login button
                    GoogleButton(onPressed: _googleLogin),

                    SizedBox(height: 20),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUpView()),
                        );
                      },
                      child: Text(
                        "Don't have an account? Sign up",
                        style: TextStyle(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                    SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
