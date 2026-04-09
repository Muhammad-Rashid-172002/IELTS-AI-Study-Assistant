
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../controller/firebase_services/firebase_services.dart';
import '../../../../resources/components/custom_text_field.dart';
import '../../../../resources/components/custom_text_field_email.dart';
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
//  final size = MediaQuery.of(context).size;

  return Scaffold(
    backgroundColor: const Color(0xffF5F5F7),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [

              /// LOGO
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff4A5DF9), Color(0xff9C27B0)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.track_changes,
                    color: Colors.white, size: 40),
              ),

              const SizedBox(height: 20),

              /// TITLE
              const Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Continue your IELTS preparation",
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),

              const SizedBox(height: 30),

              /// CARD CONTAINER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),

                child: Form(
                  key: formKey2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// EMAIL
                      const Text("Email",
                          style: TextStyle(fontWeight: FontWeight.w600)),

                      const SizedBox(height: 8),

                      CustomTextFieldEmail(
                        controller: emailControllerL,
                        hintText: 'Enter your email',
                        validator: validateEmail,
                      ),

                      const SizedBox(height: 18),

                      /// PASSWORD
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

                      /// FORGOT PASSWORD
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            "Forgot password?",
                            style: TextStyle(color: Colors.purple),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      /// LOGIN BUTTON (GRADIENT)
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
                              colors: [
                                Color(0xff3F5EFb),
                                Color(0xff9C27B0)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: firebaseServices.loadingLoginL.value
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    "Log In",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      )),

                      const SizedBox(height: 20),

                      /// OR DIVIDER
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("or continue with"),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// GOOGLE + APPLE
                      Row(
                        children: [
                          Expanded(
                            child: socialButton(
                                "Google", "assets/images/google1.png"),
                          ),
                          const SizedBox(width: 10),
                        
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// SIGNUP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? "),
                          GestureDetector(
                            onTap: () =>
                                Get.toNamed(RoutesName.register),
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold),
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

/// SOCIAL BUTTON
Widget socialButton(String title, String icon) {
  return Container(
    height: 50,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(icon, height: 24),
        const SizedBox(width: 8),
        Text(title),
      ],
    ),
  );
}  /// --------------------------
  /// VALIDATORS
  /// --------------------------
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email is required".tr;
    final emailRegex = RegExp(r'^[\w\.-]+@[a-zA-Z\d\.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) return "Enter a valid email".tr;
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required".tr;
    if (value.length < 6) return "Password must be at least 6 characters".tr;
    return null;
  }
}//
