import 'package:flutter/material.dart';
import 'package:fyproject/screens/forgot_password/forgot_password.dart';
import 'package:get/get.dart';

import '../../../../controller/firebase_services/firebase_services.dart';
import '../../../../resources/components/custom_text_field.dart';
import '../../../resources/routes/routes_names.dart';
import '../../widgets/botton/round_botton.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

final FirebaseServices firebaseServices = Get.find<FirebaseServices>();

class _LoginState extends State<Login> {
  final formKey2 = GlobalKey<FormState>();
  final TextEditingController emailControllerL = TextEditingController();
  final TextEditingController passwordControllerL = TextEditingController();

  @override
  void dispose() {
    emailControllerL.dispose();
    passwordControllerL.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF08111F), Color(0xFF102A43), Color(0xFF0F766E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                const SizedBox(height: 45),

                Container(
                  height: 95,
                  width: 95,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.10),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
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
                    child: Image.asset("assets/app_icon/app_icon.png"),
                  ),
                ),

                const SizedBox(height: 26),

                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Continue your IELTS preparation journey",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 35),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Form(
                    key: formKey2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Email Address",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 10),

                        CustomTextField(
                          controller: emailControllerL,
                          hintText: "Enter your email",
                          keyboardType: TextInputType.emailAddress,
                          validator: validateEmail,
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: Color(0xFF2DD4BF),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          "Password",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Obx(
                          () => CustomTextField(
                            controller: passwordControllerL,
                            obscureText:
                                !firebaseServices.isPasswordVisibleL.value,
                            hintText: "Enter your password",
                            validator: validatePassword,
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Color(0xFF2DD4BF),
                            ),
                            suffixIcon: IconButton(
                              onPressed:
                                  firebaseServices.togglePasswordVisibilityL,
                              icon: Icon(
                                firebaseServices.isPasswordVisibleL.value
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPassword(),
                                ),
                              );
                            },
                            child: const Text(
                              "Forgot password?",
                              style: TextStyle(
                                color: Color(0xFF2DD4BF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Obx(
                          () => RoundButton(
                            title: "Login",
                            isLoading: firebaseServices.loadingLoginL.value,
                            onPress: () {
                              if (formKey2.currentState!.validate()) {
                                firebaseServices.login(
                                  email: emailControllerL.text.trim(),
                                  password: passwordControllerL.text.trim(),
                                );
                              }
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
                        //       padding: const EdgeInsets.symmetric(
                        //         horizontal: 12,
                        //       ),
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

                        const SizedBox(height: 24),

                        // socialButton(
                        //   "Continue with Google",
                        //   "assets/images/google1.png",
                        //   () async {
                        //     await firebaseServices.loginWithGoogle();
                        //   },
                        // ),

                        const SizedBox(height: 28),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Get.toNamed(RoutesName.register),
                              child: const Text(
                                "Sign Up",
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

                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget socialButton(String title, String icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(icon, height: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email is required";

    final emailRegex = RegExp(r'^[\w\.-]+@[a-zA-Z\d\.-]+\.[a-zA-Z]{2,}$');

    if (!emailRegex.hasMatch(value)) return "Enter a valid email";
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required";
    if (value.length < 6) return "Minimum 6 characters";
    return null;
  }
}
