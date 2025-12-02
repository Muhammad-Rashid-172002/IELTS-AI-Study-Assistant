import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fyproject/view/auth/login_view.dart';
import 'package:fyproject/view/home/home_Screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';


// 🌈 Theme Colors
const kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF141E30), Color(0xFF243B55)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kButtonColor = Color(0xFF6C63FF);
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
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  File? _profileImage;

  // // 🖼️ Pick Image
  // Future<void> _pickImage() async {
  //   final pickedFile = await ImagePicker().pickImage(
  //     source: ImageSource.gallery,
  //     imageQuality: 70,
  //   );
  //   if (pickedFile != null) {
  //     setState(() => _profileImage = File(pickedFile.path));
  //   }
  // }

  // 🔐 Email Signup
  Future<void> _signUpWithEmail() async {
    if (_formKey.currentState!.validate()) {
      if (passwordController.text != confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Passwords do not match",
              style: TextStyle(
                color: Colors.white, // White text for contrast
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Color(
              0xFF2C5364,
            ), // Dark bluish-gray (matches your theme)
            behavior: SnackBarBehavior.floating, // Modern floating style
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
          ),
        );

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
              .child('user_images')
              .child('${userCredential.user!.uid}.jpg');
          await ref.putFile(_profileImage!);
          imageUrl = await ref.getDownloadURL();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'name': nameController.text.trim(),
              'email': emailController.text.trim(),
              'imageUrl': imageUrl ?? '',
              'createdAt': Timestamp.now(),
            });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ?? 'Signup failed',
              style: const TextStyle(
                color: Colors.white, // White text for readability
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFF203A43), // Dark blue-gray tone
            behavior: SnackBarBehavior.floating, // Modern floating effect
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

  // 🔵 Google Sign-In
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

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'name': googleUser.displayName ?? 'User',
              'email': googleUser.email,
              'imageUrl': googleUser.photoUrl ?? '',
              'createdAt': Timestamp.now(),
            });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Google Sign-In failed: $e",
            style: const TextStyle(
              color: Colors.white, // White for contrast
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF0F2027), // Dark gradient tone base
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
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 🧭 Header
                    Text(
                      "Join BillSnap AI",
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Smart expense tracking with AI",
                      style: GoogleFonts.roboto(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 🖼️ Profile Image Picker
                    // GestureDetector(
                    //   onTap: _pickImage,
                    //   child: CircleAvatar(
                    //     radius: 45,
                    //     backgroundColor: Colors.white24,
                    //     backgroundImage: _profileImage != null
                    //         ? FileImage(_profileImage!)
                    //         : null,
                    //     child: _profileImage == null
                    //         ? const Icon(
                    //             Icons.camera_alt,
                    //             color: Colors.white70,
                    //             size: 32,
                    //           )
                    //         : null,
                    //   ),
                    // ),
                    // const SizedBox(height: 20),

                    // 🧾 Fields
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
                        setState(
                          () => _confirmPasswordVisible =
                              !_confirmPasswordVisible,
                        );
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
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const SpinKitFadingCircle(
                              color: Colors.white,
                              size: 28,
                            )
                          : Text(
                              "Create Account",
                              style: GoogleFonts.roboto(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "or continue with",
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 16),

                    // 🌐 Google Button
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

                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account?",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SigninScreen(),
                            ),
                          ),
                          child: Text(
                            "Sign In",
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

  // 🌐 Google Social Button
}