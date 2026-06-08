import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import '../../../../controller/firebase_services/firebase_services.dart';
import '../../../../resources/components/custom_text_field.dart';
import '../../../resources/routes/routes_names.dart';
import '../../widgets/botton/round_botton.dart';

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

final FirebaseServices firebaseServices = Get.find<FirebaseServices>();

class _RegistrationState extends State<Registration> {
  final formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  PhoneNumber phoneNumber = PhoneNumber(isoCode: 'PK');

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String _normalizedPhone() {
    return phoneNumber.phoneNumber ?? phoneController.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF08111F),
              Color(0xFF102A43),
              Color(0xFF0F766E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                const SizedBox(height: 40),

                /// LOGO
                Container(
                  height: 95,
                  width: 95,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.45),
                        blurRadius: 40,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Image.asset(
                      "assets/app_icon/app_icon.png",
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                /// TITLE
                const Text(
                  "Create Account",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 10),
//
                Text(
                  "Start your IELTS preparation journey with AI",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 35),

                /// GLASS CARD
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),

                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        /// NAME
                        CustomTextField(
                          controller: nameController,
                          hintText: "Full Name",
                          validator: validateName,
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: Color(0xFF2DD4BF),
                          ),
                        ),

                        const SizedBox(height: 18),

                        /// EMAIL
                        CustomTextField(
                          controller: emailController,
                          hintText: "Email Address",
                          validator: validateEmail,
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: Color(0xFF2DD4BF),
                          ),
                        ),

                        const SizedBox(height: 18),

                        /// PASSWORD
                        Obx(
                          () => CustomTextField(
                            controller: passwordController,
                            obscureText:
                                !firebaseServices.isPasswordVisibleR.value,
                            hintText: "Create Password",
                            validator: validatePassword,
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Color(0xFF2DD4BF),
                            ),
                            suffixIcon: IconButton(
                              onPressed:
                                  firebaseServices.togglePasswordVisibility,
                              icon: Icon(
                                firebaseServices.isPasswordVisibleR.value
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        /// CONFIRM PASSWORD
                        Obx(
                          () => CustomTextField(
                            controller: confirmPasswordController,
                            obscureText:
                                !firebaseServices.isPasswordVisibleR.value,
                            hintText: "Confirm Password",
                            validator: validateConfirmPassword,
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Color(0xFF2DD4BF),
                            ),
                            suffixIcon: IconButton(
                              onPressed:
                                  firebaseServices.togglePasswordVisibility,
                              icon: Icon(
                                firebaseServices.isPasswordVisibleR.value
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        /// BUTTON
                        Obx(
                          () => RoundButton(
                            title: "Create Account",
                            isLoading:
                                firebaseServices.loadingRegistration.value,
                            onPress: () {
                              if (!formKey.currentState!.validate()) return;

                              firebaseServices.registration(
                                email: emailController.text.trim(),
                                password: passwordController.text,
                                fullName: nameController.text.trim(),
                                phone: _normalizedPhone(),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Row(
                        //   children: [
                        //     Expanded(
                        //       child: Divider(
                        //         color: Colors.white.withOpacity(0.12),
                        //       ),
                        //     ),
                        //     Padding(
                        //       padding:
                        //           const EdgeInsets.symmetric(horizontal: 12),
                        //       child: Text(
                        //         "OR",
                        //         style: TextStyle(
                        //           color: Colors.white.withOpacity(0.55),
                        //         ),
                        //       ),
                        //     ),
                        //     Expanded(
                        //       child: Divider(
                        //         color: Colors.white.withOpacity(0.12),
                        //       ),
                        //     ),
                        //   ],
                        // ),

                        const SizedBox(height: 25),

                        /// GOOGLE BUTTON
                        // socialButton(
                        //   "Continue with Google",
                        //   "assets/images/google1.png",
                        //   () async {
                        //     await firebaseServices.loginWithGoogle();
                        //   },
                        // ),

                        const SizedBox(height: 28),

                        /// LOGIN
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  Get.toNamed(RoutesName.login),
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                  color: Color(0xFF2DD4BF),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 47),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget socialButton(
      String title,
      String icon,
      VoidCallback onPressed,
      ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(icon, height: 22),
            const SizedBox(width: 12),
            const Text(
              "Continue with Google",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// VALIDATORS

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email required";
    return value.contains("@") ? null : "Invalid email";
  }

  String? validateName(String? value) {
    if (value == null || value.isEmpty) return "Name required";
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return "Minimum 6 characters";
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Confirm password required";
    }

    if (value != passwordController.text) {
      return "Passwords do not match";
    }

    return null;
  }
}