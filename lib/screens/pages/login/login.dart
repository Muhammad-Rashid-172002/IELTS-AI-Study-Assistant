//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../../../../controller/firebase_services/firebase_services.dart';
// import '../../../../resources/components/custom_text_field.dart';
// import '../../../../resources/components/custom_text_field_email.dart';
// import '../../../../resources/routes/routes.dart';
// import '../../../resources/routes/routes_names.dart';
// import '../../widgets/botton/round_botton.dart';
// import '../../widgets/botton/round_botton2.dart';
//
// class Login extends StatefulWidget {
//   const Login({super.key});
//
//   @override
//   State<Login> createState() => _LoginState();
// }
//
// final FirebaseServices firebaseServices = Get.find<FirebaseServices>();
//
// class _LoginState extends State<Login> {
//   final formKey2 = GlobalKey<FormState>();
//   final TextEditingController emailControllerL = TextEditingController();
//   final TextEditingController passwordControllerL = TextEditingController();
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context); // ✅ Access current theme
//     final size = MediaQuery.of(context).size;
//     final isTablet = size.width > 600;
//
//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       body: SafeArea(
//         child: LayoutBuilder(
//           builder: (context, constraints) {
//             final maxWidth = constraints.maxWidth > 500 ? 450.0 : double.infinity;
//             return Center(
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.symmetric(
//                   horizontal: isTablet ? size.width * 0.2 : 20,
//                   vertical: 24,
//                 ),
//                 child: ConstrainedBox(
//                   constraints: BoxConstraints(maxWidth: maxWidth),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Center(
//                         child: Image.asset(
//                           'assets/images/splash2.png',
//                           height: 120,
//                           fit: BoxFit.contain,
//                         ),
//                       ),
//                       Text(
//                         'HELLO, WELCOME BACK'.tr,
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: isTablet ? 36 : 28,
//                           color: theme.colorScheme.onSurface, // ✅ Theme adaptive
//                         ),
//                       ),
//                       SizedBox(height: size.height * 0.03),
//
//                       /// 🧾 Form Section
//                       Form(
//                         key: formKey2,
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Email Address'.tr,
//                               style: TextStyle(
//                                 fontSize: isTablet ? 20 : 16,
//                                 fontWeight: FontWeight.w500,
//                                 color: theme.colorScheme.onSurface,
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             CustomTextFieldEmail(
//                               controller: emailControllerL,
//                               hintText: 'Enter your email'.tr,
//                               validator: validateEmail,
//                             ),
//                             const SizedBox(height: 12),
//                             Text(
//                               'Password'.tr,
//                               style: TextStyle(
//                                 fontSize: isTablet ? 20 : 16,
//                                 fontWeight: FontWeight.w500,
//                                 color: theme.colorScheme.onSurface,
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Obx(() {
//                               return CustomTextField(
//                                 controller: passwordControllerL,
//                                 obscureText: !firebaseServices.isPasswordVisibleL.value,
//                                 hintText: 'Enter your password'.tr,
//                                 suffixIcon: IconButton(
//                                   onPressed: firebaseServices.togglePasswordVisibilityL,
//                                   icon: Icon(
//                                     firebaseServices.isPasswordVisibleL.value
//                                         ? Icons.visibility
//                                         : Icons.visibility_off_outlined,
//                                     color: theme.colorScheme.primary,
//                                   ),
//                                 ),
//                                 validator: validatePassword,
//                               );
//                             }),
//                             Align(
//                               alignment: Alignment.centerRight,
//                               child: TextButton(
//                                 onPressed: () {
//                                   // Get.toNamed(RoutesName.forgotPassword);
//                                 },
//                                 child: Text(
//                                   'Forgot password?'.tr,
//                                   style: TextStyle(
//                                     fontSize: isTablet ? 18 : 15,
//                                     color: theme.colorScheme.primary, // ✅ Adaptive color
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//
//                       /// 🔹 Login Button
//                       Obx(() {
//                         return RoundButton(
//                           width: double.infinity,
//                           height: isTablet ? 65 : 55,
//                           title: 'Login'.tr,
//                           loading: firebaseServices.loadingLoginL.value,
//                           onPress: () {
//                             if (formKey2.currentState!.validate()) {
//                               firebaseServices.login(
//                                 email: emailControllerL.text.trim(),
//                                 password: passwordControllerL.text.trim(),
//                               );
//                             }
//                           },
//                           buttonColor: theme.colorScheme.primary,
//                           textColor: theme.colorScheme.onPrimary,
//                         );
//                       }),
//                       SizedBox(height: size.height * 0.03),
//
//                       /// OR Divider
//                       Row(
//                         children: [
//                           Expanded(child: Divider(color: theme.dividerColor)),
//                           Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 10),
//                             child: Text('OR'.tr, style: TextStyle(color: theme.colorScheme.onSurface)),
//                           ),
//                           Expanded(child: Divider(color: theme.dividerColor)),
//                         ],
//                       ),
//                       SizedBox(height: size.height * 0.03),
//
//                       /// 🟢 Google Sign-In Button
//                       Obx(() {
//                         return RoundButton2(
//                           width: double.infinity,
//                           height: isTablet ? 65 : 55,
//                           loading: firebaseServices.loadingGoogleL.value,
//                           title: '',
//                           onPress: () async {
//                             await firebaseServices.loginWithGoogle();
//                           },
//                           textColor: theme.colorScheme.onSurface,
//                           borderColor: theme.colorScheme.surface,
//                           child: Image.asset(
//                             'assets/images/googlelogo.png',
//                             height: isTablet ? 50 : 40,
//                           ),
//                         );
//                       }),
//                       SizedBox(height: size.height * 0.04),
//
//                       /// 🧭 Signup Link
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Text(
//                             "Don't have an account?".tr,
//                             style: TextStyle(
//                               fontSize: isTablet ? 18 : 15,
//                               color: theme.colorScheme.onSurface,
//                             ),
//                           ),
//                           InkWell(
//                             onTap: () => Get.toNamed(RoutesName.register),
//                             child: Text(
//                               'Signup'.tr,
//                               style: TextStyle(
//                                 color: theme.colorScheme.primary,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: isTablet ? 18 : 15,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: size.height * 0.02),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//   // ✅ Email Validator
//   String? validateEmail(String? value) {
//     if (value == null || value.isEmpty) return "Email is required".tr;
//     final emailRegex = RegExp(r'^[\w\.-]+@[a-zA-Z\d\.-]+\.[a-zA-Z]{2,}$');
//     if (!emailRegex.hasMatch(value)) return "Enter a valid email".tr;
//     return null;
//   }
//
//   // ✅ Password Validator
//   String? validatePassword(String? value) {
//     if (value == null || value.isEmpty) return "Password is required".tr;
//     if (value.length < 6) return "Password must be at least 6 characters".tr;
//     return null;
//   }
// }


import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../controller/firebase_services/firebase_services.dart';
import '../../../../resources/components/custom_text_field.dart';
import '../../../../resources/components/custom_text_field_email.dart';
import '../../../../resources/routes/routes.dart';
import '../../../resources/routes/routes_names.dart';
import '../../widgets/botton/round_botton.dart';
import '../../widgets/botton/round_botton2.dart';

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
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? size.width * 0.18 : 22,
            vertical: 28,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              /// --------------------------
              /// LOGO
              /// --------------------------
              Image.asset(
                'assets/images/ai.png',
                height: 120,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 12),

              /// --------------------------
              /// TITLE
              /// --------------------------
              Text(
                'HELLO, WELCOME BACK'.tr,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),

              SizedBox(height: size.height * 0.03),

              /// --------------------------
              /// FORM
              /// --------------------------
              Form(
                key: formKey2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// EMAIL LABEL
                    Text(
                      'Email Address'.tr,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),

                    CustomTextFieldEmail(
                      controller: emailControllerL,
                      hintText: 'Enter your email'.tr,
                      validator: validateEmail,
                    ),

                    const SizedBox(height: 16),

                    /// PASSWORD LABEL
                    Text(
                      'Password'.tr,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Obx(() => CustomTextField(
                      controller: passwordControllerL,
                      obscureText: !firebaseServices.isPasswordVisibleL.value,
                      hintText: 'Enter your password'.tr,
                      suffixIcon: IconButton(
                        onPressed: firebaseServices.togglePasswordVisibilityL,
                        icon: Icon(
                          firebaseServices.isPasswordVisibleL.value
                              ? Icons.visibility
                              : Icons.visibility_off_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      validator: validatePassword,
                    )),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          'Forgot password?'.tr,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// --------------------------
              /// LOGIN BUTTON
              /// --------------------------
              Obx(() => RoundButton(
                width: double.infinity,
                height: isTablet ? 65 : 55,
                title: 'Login'.tr,
                loading: firebaseServices.loadingLoginL.value,
                onPress: () {
                  if (formKey2.currentState!.validate()) {
                    firebaseServices.login(
                      email: emailControllerL.text.trim(),
                      password: passwordControllerL.text.trim(),
                    );
                  }
                },
              )),

              SizedBox(height: size.height * 0.03),

              /// --------------------------
              /// OR DIVIDER
              /// --------------------------
              Row(
                children: [
                  Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'OR'.tr,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                ],
              ),

              SizedBox(height: size.height * 0.03),

              /// --------------------------
              /// GOOGLE SIGN-IN BUTTON
              /// --------------------------
              Obx(() => RoundButton2(
                width: double.infinity,
                height: isTablet ? 65 : 55,
                loading: firebaseServices.loadingGoogleL.value,
                onPress: firebaseServices.loginWithGoogle,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/google1.png',
                      height: isTablet ? 46 : 36,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              )),

              SizedBox(height: size.height * 0.04),

              /// --------------------------
              /// SIGNUP TEXT
              /// --------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?".tr,
                    style: theme.textTheme.bodyMedium,
                  ),
                  InkWell(
                    onTap: () => Get.toNamed(RoutesName.register),
                    child: Text(
                      'Signup'.tr,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: size.height * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  /// --------------------------
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
}
