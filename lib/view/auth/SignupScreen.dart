import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fyproject/view/auth/SigninScreen.dart';
import 'package:fyproject/view/home/home_Screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';



// 🎨 IELTS AI STUDY Theme Colors
const kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const kButtonColor = Color(0xFF6C63FF); // Purple AI color
const kTextColor = Colors.white70;


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  File? _profileImage;


  // -------------------------------------------------------------------------
  // 🔐 Email Signup
  // -------------------------------------------------------------------------
  Future<void> _signUpWithEmail() async {
    if (_formKey.currentState!.validate()) {
      if (passwordController.text != confirmPasswordController.text) {
        _showSnack("Passwords do not match");
        return;
      }

      setState(() => _isLoading = true);

      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
        );

        String? imageUrl;
        if (_profileImage != null) {
          final ref = FirebaseStorage.instance
              .ref()
              .child("user_images")
              .child("${userCredential.user!.uid}.jpg");

          await ref.putFile(_profileImage!);
          imageUrl = await ref.getDownloadURL();
        }

        await FirebaseFirestore.instance
            .collection("users")
            .doc(userCredential.user!.uid)
            .set({
          "name": nameController.text.trim(),
          "email": emailController.text.trim(),
          "imageUrl": imageUrl ?? "",
          "createdAt": Timestamp.now(),
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );

      } on FirebaseAuthException catch (e) {
        _showSnack(e.message ?? "Signup failed");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // -------------------------------------------------------------------------
  // 🔵 Google Sign-in
  // -------------------------------------------------------------------------


Future<void> _signInWithGoogle() async {
  setState(() => _isLoading = true);

  try {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email'],
    );

    // Open Google Sign-In popup
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      setState(() => _isLoading = false);
      return; // User cancelled
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Firebase login
    final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    // Save to Firestore
    await FirebaseFirestore.instance
        .collection("users")
        .doc(userCredential.user!.uid)
        .set({
      "name": googleUser.displayName ?? "Student",
      "email": googleUser.email,
      "imageUrl": googleUser.photoUrl,
      "createdAt": Timestamp.now(),
    }, SetOptions(merge: true));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Google Sign-in failed: $e")),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

// -------------------------------------------------------------------------
  // Snackbar
  // -------------------------------------------------------------------------
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF203A43),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }


  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kPrimaryGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [

                    // ---------------------------------------------------------
                    // 🧭 Header
                    // ---------------------------------------------------------
                    Text(
                      "IELTS AI Study",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Practice • Evaluate • Improve with AI",
                      style: GoogleFonts.roboto(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ---------------------------------------------------------
                    // 🧾 Input Fields
                    // ---------------------------------------------------------
                    _buildInputField("Full Name", Icons.person, nameController),
                    const SizedBox(height: 15),

                    _buildInputField("Email", Icons.email, emailController),
                    const SizedBox(height: 15),

                    _buildInputField(
                      "Password",
                      Icons.lock,
                      passwordController,
                      obscure: !_passwordVisible,
                      toggleVisibility: () {
                        setState(() => _passwordVisible = !_passwordVisible);
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildInputField(
                      "Confirm Password",
                      Icons.lock_outline,
                      confirmPasswordController,
                      obscure: !_confirmPasswordVisible,
                      toggleVisibility: () {
                        setState(() => _confirmPasswordVisible =
                            !_confirmPasswordVisible);
                      },
                    ),
                    const SizedBox(height: 25),

                    
                    // 🚀 Signup Button
     
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signUpWithEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonColor,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isLoading
                          ? const SpinKitFadingCircle(
                              color: Colors.white, size: 26)
                          : const Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),
                    const Text("or continue with",
                        style: TextStyle(color: Colors.white60)),
                    const SizedBox(height: 16),

                    // ---------------------------------------------------------
                    // 🌐 Google Button
                    // ---------------------------------------------------------
                    GestureDetector(
                      onTap: _isLoading ? null : _signInWithGoogle,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white60),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset("assets/images/google.png", height: 24),
                            const SizedBox(width: 10),
                            const Text(
                              "Sign-in with Google",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ---------------------------------------------------------
                    // Already Account?
                    // ---------------------------------------------------------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?",
                            style: TextStyle(color: Colors.white70)),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SigninScreen()),
                          ),
                          child: const Text(
                            "Sign In",
                            style: TextStyle(
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
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ✏ Custom Input Field Widget
  // -------------------------------------------------------------------------
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
      validator: (value) =>
      (value == null || value.isEmpty) ? "Enter $label" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
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
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: kButtonColor),
        ),
      ),
    );
  }
}
