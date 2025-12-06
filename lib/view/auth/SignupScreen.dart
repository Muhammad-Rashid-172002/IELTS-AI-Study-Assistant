import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fyproject/view/auth/SigninScreen.dart';
import 'package:fyproject/view/home/home_Screen.dart';
import 'package:fyproject/widgets/app_button.dart';
import 'package:fyproject/widgets/app_input_field.dart';
import 'package:fyproject/widgets/app_snackbar.dart';
import 'package:fyproject/widgets/google_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

const kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
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
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  File? _profileImage;

  // EMAIL SIGNUP
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (passwordController.text.trim() != confirmController.text.trim()) {
      AppSnackBar.show(context, "Passwords do not match",
          type: SnackBarType.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Upload Image If Available
      String? imageUrl;
      if (_profileImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child("user_images")
            .child("${user.user!.uid}.jpg");

        await ref.putFile(_profileImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // Save User Data
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.user!.uid)
          .set({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "imageUrl": imageUrl ?? "",
        "createdAt": Timestamp.now(),
      });

      AppSnackBar.show(context, "Account Created Successfully 🎉",
          type: SnackBarType.success);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      AppSnackBar.show(context, e.toString(), type: SnackBarType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // GOOGLE SIGN-IN
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCredential.user!.uid)
          .set({
        "name": googleUser.displayName ?? "",
        "email": googleUser.email,
        "imageUrl": googleUser.photoUrl ?? "",
        "createdAt": Timestamp.now(),
      }, SetOptions(merge: true));

      AppSnackBar.show(context, "Google Login Successful 🎉",
          type: SnackBarType.success);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      AppSnackBar.show(context, "Google Sign-in Failed",
          type: SnackBarType.error);
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
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text("IELTS AI Study",
                      style: GoogleFonts.poppins(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // FULL NAME
                  AppInputField(
                    controller: nameController,
                    hintText: "Full Name",
                    icon: Icons.person,
                    validator: (v) =>
                        v!.isEmpty ? "Enter Full Name" : null,
                  ),
                  const SizedBox(height: 16),

                  // EMAIL
                  AppInputField(
                    controller: emailController,
                    hintText: "Email",
                    icon: Icons.email,
                    validator: (v) => v!.isEmpty ? "Enter Email" : null,
                  ),
                  const SizedBox(height: 16),

                  // PASSWORD
                  AppInputField(
                    controller: passwordController,
                    hintText: "Password",
                    icon: Icons.lock,
                    isPassword: true,
                    validator: (v) => v!.isEmpty ? "Enter Password" : null,
                  ),
                  const SizedBox(height: 16),

                  // CONFIRM PASSWORD
                  AppInputField(
                    controller: confirmController,
                    hintText: "Confirm Password",
                    icon: Icons.lock_outline,
                    isPassword: true,
                    validator: (v) =>
                        v!.isEmpty ? "Enter Confirm Password" : null,
                  ),
                  const SizedBox(height: 25),

                  // SIGN-UP BUTTON
                  _isLoading
                      ? const SpinKitCircle(color: Colors.white, size: 40)
                      : AppButton(
                          text: "Create Account",
                          onPressed: _signUp,
                          backgroundColor: kButtonColor,
                          textColor: Colors.white,
                        ),

                  const SizedBox(height: 25),

                  // OR
                  const Text("or continue with",
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 14),

                  // GOOGLE BUTTON
                  GoogleButton(onPressed: _signInWithGoogle),

                  const SizedBox(height: 20),

                  // SIGN IN LINK
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
                          style:
                              TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
