import 'package:flutter/material.dart';
import 'package:fyproject/screens/forgot_password/forgot_password.dart';
import 'package:get/get.dart';
import '../../../../controller/firebase_services/firebase_services.dart';
import '../../../../resources/components/custom_text_field.dart';
import '../../../resources/routes/routes_names.dart';


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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB), // WHITE BASE APP THEME
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [

                /// LOGO (LIGHT PREMIUM)
                Container(
                  height: 85,
                  width: 85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xff6A11CB), Color(0xff2575FC)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: const Icon(Icons.track_changes,
                      color: Colors.white, size: 38),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Continue your IELTS preparation",
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),

                const SizedBox(height: 25),

                /// CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Form(
                    key: formKey2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        const Text("Email",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),

                        CustomTextField(
                          controller: emailControllerL,
                          hintText: 'Enter your email',
                          validator: validateEmail,
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),

                        const SizedBox(height: 18),

                        const Text("Password",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),

                        Obx(() => CustomTextField(
                              controller: passwordControllerL,
                              obscureText: !firebaseServices.isPasswordVisibleL.value,
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: firebaseServices.togglePasswordVisibilityL,
                                icon: Icon(
                                  firebaseServices.isPasswordVisibleL.value
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                              validator: validatePassword,
                            )),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ForgotPassword(),
                                ),
                              );
                            },
                            child: const Text(
                              "Forgot password?",
                              style: TextStyle(color: Colors.purple),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        /// LOGIN BUTTON
                        Obx(() => GestureDetector(
                              onTap: () {
                                if (formKey2.currentState!.validate()) {
                                  firebaseServices.login(
                                    email: emailControllerL.text.trim(),
                                    password: passwordControllerL.text.trim(),
                                  );
                                }
                              },
                              child: Container(
                                height: 55,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xff6A11CB), Color(0xff2575FC)],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    )
                                  ],
                                ),
                                child: Center(
                                  child: firebaseServices.loadingLoginL.value
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text(
                                          "Login",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                            )),

                        const SizedBox(height: 18),

                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text("or continue"),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: 18),

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

                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            GestureDetector(
                              onTap: () => Get.toNamed(RoutesName.register),
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: Colors.blue,
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