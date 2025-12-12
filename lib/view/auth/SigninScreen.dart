import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fyproject/view/auth/forgot_password.dart';
import 'package:fyproject/view/auth/SignupScreen.dart';
import 'package:fyproject/view/home/home_Screen.dart';
import 'package:fyproject/resources/app_button.dart';
import 'package:fyproject/resources/app_snackbar.dart';
import 'package:fyproject/resources/google_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

const kButtonPrimary = Color(0xFF6C63FF);
const kAppBarColor = Color(0xFF5A55DA);

// Background Gradient
const kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _passwordVisible = false;
  bool _isLoading = false;

  // 🔐 Email Sign-In
  Future<void> _signInWithEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        AppSnackBar.show(
          context,
          "Login Successful 🎉",
          type: SnackBarType.success,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } on FirebaseAuthException catch (e) {
        String errorMsg = "Login failed";
        if (e.code == 'user-not-found') errorMsg = "User not found";
        if (e.code == 'wrong-password') errorMsg = "Wrong password";

        AppSnackBar.show(context, errorMsg, type: SnackBarType.error);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🌐 Google Sign-In
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await GoogleSignIn().signOut();
      final googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      AppSnackBar.show(
        context,
        "Google Login Successful 🎉",
        type: SnackBarType.success,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      AppSnackBar.show(
        context,
        "Google Sign-In failed",
        type: SnackBarType.error,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kPrimaryGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "IELTS AI Study 📘",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    "Boost your IELTS preparation with smart AI guidance.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Glass card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildInputField(
                            "Email",
                            Icons.email,
                            emailController,
                          ),
                          const SizedBox(height: 15),

                          _buildInputField(
                            "Password",
                            Icons.lock,
                            passwordController,
                            obscure: !_passwordVisible,
                            toggleVisibility: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                          ),

                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ForgotPassword(),
                                ),
                              ),
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // SIGN IN BUTTON
                          _isLoading
                              ? const SpinKitCircle(
                                  color: Colors.white,
                                  size: 45,
                                )
                              : AppButton(
                                  text: "Continue Learning",
                                  onPressed: _signInWithEmail,
                                  backgroundColor: kButtonPrimary,
                                  textColor: Colors.white,
                                ),

                          const SizedBox(height: 25),

                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white30)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  "or",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white30)),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // GOOGLE BUTTON
                          GoogleButton(onPressed: _signInWithGoogle),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "New to IELTS AI Study? ",
                                style: TextStyle(color: Colors.white70),
                              ),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignupScreen(),
                                  ),
                                ),
                                child: Text(
                                  "Create Account",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // CUSTOM INPUT FIELD
  Widget _buildInputField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool obscure = false,
    VoidCallback? toggleVisibility,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: toggleVisibility != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: toggleVisibility,
              )
            : null,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: kButtonPrimary),
        ),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Enter $label' : null,
    );
  }
}
