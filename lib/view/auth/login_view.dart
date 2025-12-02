import 'package:expanse_tracker_app/Screens/Auth_moduls/ForgotPassword.dart';
import 'package:expanse_tracker_app/Screens/Auth_moduls/signupscreen.dart';
import 'package:expanse_tracker_app/Screens/HomeScreen/homescreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 🎨 App Colors
const kButtonPrimary = Color(0xFF6C63FF);
const kAppBarColor = Color(0xFF5A55DA);
const kButtonPrimaryText = Colors.white;
const kCardTextColor = Colors.black87;
const kCardColor = Colors.white;
const kBodyTextColor = Colors.grey;
const kButtonColor = Color(0xFF6C63FF); // 🔧 added missing constant

// 🌈 Modern Gradient Background
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
  bool _passwordVisible = false; // ✅ fixed naming mismatch
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } on FirebaseAuthException catch (e) {
        String errorMsg = "Login failed";
        if (e.code == 'user-not-found')
          errorMsg = "User not found";
        else if (e.code == 'wrong-password')
          errorMsg = "Wrong password";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: const TextStyle(
                color: Colors.white,
              ), // White text for contrast
            ),
            backgroundColor: const Color(0xFF203A43), // Dark background color
            behavior:
                SnackBarBehavior.floating, // Floating for better visibility
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
          ),
        );
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
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Google Sign-In failed: $e",
            style: const TextStyle(
              color: Colors.white, // White text for readability
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: const Color(
            0xFF2C5364,
          ), // Dark bluish-gray background
          behavior: SnackBarBehavior.floating, // Floating for modern look
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        ),
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
                  // 🧭 Heading
                  Text(
                    "Welcome Back 👋",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Sign in to continue managing your finances smartly.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 🧾 Glassmorphic Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
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
                            toggleVisibility: () {
                              setState(
                                () => _passwordVisible = !_passwordVisible,
                              );
                            },
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
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 🚀 Sign In Button
                          GestureDetector(
                            onTap: _isLoading ? null : _signInWithEmail,
                            child: Container(
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: const LinearGradient(
                                  colors: [kButtonPrimary, kAppBarColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kButtonPrimary.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SpinKitCircle(
                                        color: Colors.white,
                                        size: 32,
                                      )
                                    : Text(
                                        "Sign In",
                                        style: GoogleFonts.poppins(
                                          color: kButtonPrimaryText,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          // 🔘 Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey[300])),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  "or",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey[300])),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 🌐 Google Sign-In
                          GestureDetector(
                            onTap: _isLoading ? null : _signInWithGoogle,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: kButtonPrimary),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset("assets/google.png", height: 24),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Sign in with Google",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 📝 Sign Up Option
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don’t have an account? ",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignupScreen(),
                                  ),
                                ),
                                child: Text(
                                  "Sign Up",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
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

  // ✏️ Custom Input Field
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
          borderSide: const BorderSide(color: kButtonColor),
        ),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Enter $label' : null,
    );
  }
}