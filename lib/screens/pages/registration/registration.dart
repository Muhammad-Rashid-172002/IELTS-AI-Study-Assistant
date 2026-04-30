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
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        /// 🔥 Background Gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xfff3f4f8), Color(0xffe9e9f2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),

                /// 🔥 LOGO ICON
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xff4A00E0), Color(0xff8E2DE2)],
                    ),
                  ),
                  child: const Icon(
                    Icons.gps_fixed,
                    color: Colors.white,
                    size: 35,
                  ),
                ),

                const SizedBox(height: 20),

                /// TITLE
                const Text(
                  "Create Account",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Start your IELTS journey today",
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 30),

                /// 🔥 CARD CONTAINER
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
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
                          hintText: "Enter your name",
                          validator: validateName,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),

                        const SizedBox(height: 16),

                        /// EMAIL
                        CustomTextField(
                          controller: emailController,
                          hintText: "Enter your email",
                          validator: validateEmail,
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),

                        const SizedBox(height: 16),

                        /// PASSWORD
                        Obx(
                          () => CustomTextField(
                            controller: passwordController,
                            obscureText:
                                !firebaseServices.isPasswordVisibleR.value,
                            hintText: "Create a password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed:
                                  firebaseServices.togglePasswordVisibility,
                              icon: Icon(
                                firebaseServices.isPasswordVisibleR.value
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                            validator: validatePassword,
                          ),
                        ),
                        SizedBox(height: height * 0.02),
                        Obx(
                          () => CustomTextField(
                            controller: confirmPasswordController,
                            obscureText:
                                !firebaseServices.isPasswordVisibleR.value,
                            hintText: "Confirm password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed:
                                  firebaseServices.togglePasswordVisibility,
                              icon: Icon(
                                firebaseServices.isPasswordVisibleR.value
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                            validator: validateConfirmPassword,
                          ),
                        ),

                        const SizedBox(height: 25),

                        /// BUTTON
                        Obx(
                          () => RoundButton(
                            loading: firebaseServices.loadingRegistration.value,
                            title: "Sign Up",
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

                        const SizedBox(height: 20),

                        /// DIVIDER
                        Row(
                          children: const [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text("or continue with"),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: 20),

                        /// SOCIAL BUTTONS
                        Row(
                          children: [
                            Expanded(
                              child: socialButton(
                                "Google",
                                "assets/images/google1.png",
                                () async {
                                  await firebaseServices.loginWithGoogle();
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        /// LOGIN
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account? "),
                            GestureDetector(
                              onTap: () => Get.toNamed(RoutesName.login),
                              child: const Text(
                                "Log In",
                                style: TextStyle(
                                  color: Color(0xff8E2DE2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔘 SOCIAL BUTTON
  Widget socialButton(String title, String icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(icon, height: 22),
            const SizedBox(width: 8),
            Text(title),
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
    if (value == null || value.length < 6) return "Min 6 chars";
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return "Confirm password required";
    if (value != passwordController.text) return "Passwords do not match";
    return null;
  }
}
