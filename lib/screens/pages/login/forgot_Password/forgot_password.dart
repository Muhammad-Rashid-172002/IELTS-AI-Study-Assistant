import 'package:flutter/material.dart';
import 'package:fyproject/controller/firebase_services/firebase_services.dart';
import 'package:get/get.dart';
import 'package:fyproject/resources/components/custom_text_field.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controller (MVC)
  final FirebaseServices firebaseServices = Get.find<FirebaseServices>();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void passwordReset() {
    if (!_formKey.currentState!.validate()) return;

    firebaseServices.sendPasswordResetEmail(
      emailController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reset Password"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                Text(
                  "Forgot your password?",
                  style: theme.textTheme.headlineMedium,
                ),

                const SizedBox(height: 10),

                Text(
                  "Enter your email and we’ll send you a password reset link.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 32),

                // EMAIL FIELD
                CustomTextField(
                  controller: emailController,
                  hintText: "Email Address",
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter your email";
                    }
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                      return "Enter a valid email";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                // RESET BUTTON (Obx for loading)
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: firebaseServices.isResetLoading.value
                          ? null
                          : passwordReset,
                      child: firebaseServices.isResetLoading.value
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Send Reset Link"),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
