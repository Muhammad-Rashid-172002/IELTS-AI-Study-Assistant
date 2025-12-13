
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:intl_phone_number_input/intl_phone_number_input.dart';
// import '../../../../controller/firebase_services/firebase_services.dart';
// import '../../../../resources/components/custom_text_field.dart';
// import '../../../../resources/components/custom_text_field_email.dart';
// import '../../../../resources/components/custom_text_field_name.dart';
// import '../../../../resources/routes/routes.dart';
// import '../../widgets/botton/round_botton.dart';
// import '../../widgets/botton/round_botton2.dart';
//
// class Registration extends StatefulWidget {
//   const Registration({super.key});
//
//   @override
//   State<Registration> createState() => _RegistrationState();
// }
//
// final FirebaseServices firebaseServices = Get.find<FirebaseServices>();
//
// class _RegistrationState extends State<Registration> {
//   final formKey = GlobalKey<FormState>();
//
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   final TextEditingController confirmPasswordController = TextEditingController();
//
//   PhoneNumber phoneNumber = PhoneNumber(isoCode: 'PK'); // default country
//   bool phoneValid = false;
//
//   @override
//   void dispose() {
//     emailController.dispose();
//     nameController.dispose();
//     phoneController.dispose();
//     passwordController.dispose();
//     confirmPasswordController.dispose();
//     super.dispose();
//   }
//
//   String _normalizedPhone() {
//     // prefer the PhoneNumber instance (gives E.164); fallback to raw input
//     return phoneNumber.phoneNumber ?? phoneController.text.trim();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final height = MediaQuery.of(context).size.height;
//     final width = MediaQuery.of(context).size.width;
//
//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: EdgeInsets.symmetric(horizontal: width * 0.06, vertical: height * 0.02),
//           child: Form(
//             key: formKey,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Logo
//                 Center(
//                   child: Image.asset(
//                     'assets/images/splash2.png',
//                     height: 100,
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//
//                 // Header
//                 Center(
//                   child: Text(
//                     'Create An Account'.tr,
//                     style: theme.textTheme.headlineMedium?.copyWith(
//                       color: theme.colorScheme.onSurface,
//                       fontSize: width * 0.065,
//                     ),
//                   ),
//                 ),
//
//                 const SizedBox(height: 18),
//
//                 // Name
//                 buildLabel('Full Name'.tr, theme),
//                 CustomTextFieldName(
//                   controller: nameController,
//                   hintText: 'Enter full name'.tr,
//                   validator: validateName,
//                 ),
//
//                 SizedBox(height: height * 0.02),
//
//                 // Email
//                 buildLabel('Email Address'.tr, theme),
//                 CustomTextFieldEmail(
//                   controller: emailController,
//                   hintText: 'Enter email'.tr,
//                   validator: validateEmail,
//                 ),
//
//                 SizedBox(height: height * 0.02),
//
//                 // Phone (intl)
//                 buildLabel('Phone Number'.tr, theme),
//                 InternationalPhoneNumberInput(
//                   onInputChanged: (PhoneNumber number) {
//                     phoneNumber = number; // store current number
//                   },
//                   onInputValidated: (bool value) {
//                     firebaseServices.setPhoneValid(value); // reactive, no setState
//                   },
//                   selectorConfig: const SelectorConfig(
//                     selectorType: PhoneInputSelectorType.DROPDOWN,
//                   ),
//                   ignoreBlank: false,
//                   autoValidateMode: AutovalidateMode.disabled, // optional, reduces rebuilds
//                   selectorTextStyle: TextStyle(color: theme.colorScheme.onSurface),
//                   textFieldController: phoneController,
//                   initialValue: phoneNumber,
//                   formatInput: true,
//                   inputDecoration: InputDecoration(
//                     hintText: '+92 3xx xxxxxxx',
//                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
//                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                   ),
//                   keyboardType: TextInputType.phone,
//                 ),
//
//
//                 SizedBox(height: height * 0.02),
//
//                 // Password
//                 buildLabel('Password'.tr, theme),
//                 Obx(() => CustomTextField(
//                   controller: passwordController,
//                   obscureText: !firebaseServices.isPasswordVisibleR.value,
//                   hintText: 'Enter password'.tr,
//                   suffixIcon: IconButton(
//                     onPressed: firebaseServices.togglePasswordVisibility,
//                     icon: Icon(
//                       firebaseServices.isPasswordVisibleR.value ? Icons.visibility : Icons.visibility_off,
//                       color: theme.colorScheme.primary,
//                     ),
//                   ),
//                   validator: validatePassword,
//                 )),
//
//                 SizedBox(height: height * 0.02),
//
//                 // Confirm password
//                 buildLabel('Confirm Password'.tr, theme),
//                 Obx(() => CustomTextField(
//                   controller: confirmPasswordController,
//                   obscureText: !firebaseServices.isPasswordVisibleRE.value,
//                   hintText: 'Confirm password'.tr,
//                   suffixIcon: IconButton(
//                     onPressed: firebaseServices.toggleConfirmPasswordVisibility,
//                     icon: Icon(
//                       firebaseServices.isPasswordVisibleRE.value ? Icons.visibility : Icons.visibility_off,
//                       color: theme.colorScheme.primary,
//                     ),
//                   ),
//                   validator: (val) => validateConfirmPassword(val, passwordController.text),
//                 )),
//
//                 SizedBox(height: height * 0.03),
//
//                 // Register button
//                 Obx(() => RoundButton(
//                   width: double.infinity,
//                   height: 55,
//                   loading: firebaseServices.loadingRegistration.value,
//                   title: 'Get Started'.tr,
//                   onPress: () {
//                     // Basic form validate + phone validity
//                     if (!formKey.currentState!.validate()) return;
//
//                     final normalized = _normalizedPhone();
//                     if (normalized.isEmpty) {
//                       Get.snackbar("Error".tr, "Phone number is required".tr);
//                       return;
//                     }
//
//                     // optional: ensure phone has '+' at start (best to rely on intl lib output)
//                     final phoneToSave = normalized.startsWith('+') ? normalized : '+$normalized';
//
//                     firebaseServices.registration(
//                       email: emailController.text.trim(),
//                       password: passwordController.text,
//                       fullName: nameController.text.trim(),
//                       phone: phoneToSave,
//                     );
//                   },
//                   buttonColor: AppColor.gold,
//                   textColor: AppColor.whiteCream,
//                 )),
//
//                 SizedBox(height: height * 0.02),
//
//                 // Divider OR
//                 Row(
//                   children: [
//                     Expanded(child: Divider(color: theme.colorScheme.surface)),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                       child: Text("OR".tr, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
//                     ),
//                     Expanded(child: Divider(color: theme.colorScheme.surface)),
//                   ],
//                 ),
//
//                 SizedBox(height: height * 0.03),
//
//                 // Google sign-in button (keeps your previous RoundButton2)
//                 Obx(() => RoundButton2(
//                   width: double.infinity,
//                   height: 55,
//                   loading: firebaseServices.loadingGoogleL.value,
//                   title: '',
//                   onPress: () async {
//                     await firebaseServices.loginWithGoogle();
//                   },
//                   textColor: theme.colorScheme.onSurface,
//                   borderColor: theme.colorScheme.surface,
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Image.asset('assets/images/googlelogo.png', height: 30),
//                       const SizedBox(width: 10),
//                       Text(
//                         'Continue with Google'.tr,
//                         style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
//                       ),
//                     ],
//                   ),
//                 )),
//
//                 SizedBox(height: height * 0.025),
//
//                 // Already have account
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text("Already have an account?".tr),
//                     TextButton(
//                       onPressed: () => Get.toNamed(RoutesName.loginScreen),
//                       child: Text('Login'.tr, style: TextStyle(color: AppColor.gold, fontWeight: FontWeight.bold)),
//                     )
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // -------------------------
//   // Validators
//   // -------------------------
//   Widget buildLabel(String label, ThemeData theme) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 6.0),
//       child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
//     );
//   }
//
//   String? validateEmail(String? value) {
//     if (value == null || value.isEmpty) return "Email is required".tr;
//     final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
//     if (!emailRegex.hasMatch(value)) return "Enter a valid email".tr;
//     return null;
//   }
//
//   String? validateName(String? value) {
//     if (value == null || value.trim().isEmpty) return "Name is required".tr;
//     if (value.trim().length < 3) return "Name must be at least 3 characters".tr;
//     if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(value.trim())) return "Only alphabets and spaces are allowed".tr;
//     return null;
//   }
//
//   String? validatePhone(String? value) {
//     if (value == null || value.isEmpty) return "Phone number is required".tr;
//     // we rely on intl_phone_number_input, so minimal check here
//     return null;
//   }
//
//   String? validatePassword(String? value) {
//     if (value == null || value.isEmpty) return "Password is required".tr;
//     if (value.length < 6) return "Password must be at least 6 characters".tr;
//     return null;
//   }
//
//   String? validateConfirmPassword(String? value, String password) {
//     if (value == null || value.isEmpty) return 'Confirm Password is required'.tr;
//     if (value != password) {
//       Get.snackbar("Error".tr, "Passwords do not match".tr, backgroundColor: AppColor.error, colorText: Colors.white);
//       return "Passwords do not match".tr;
//     }
//     return null;
//   }
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../../../controller/firebase_services/firebase_services.dart';
import '../../../../resources/components/custom_text_field.dart';
import '../../../../resources/components/custom_text_field_email.dart';
import '../../../../resources/components/custom_text_field_name.dart';
import '../../../../resources/routes/routes.dart';
import '../../../resources/routes/routes_names.dart';
import '../../widgets/botton/round_botton.dart';
import '../../widgets/botton/round_botton2.dart';

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

final FirebaseServices firebaseServices = Get.find<FirebaseServices>();

class _RegistrationState extends State<Registration> {
  final formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

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
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: width * 0.06, vertical: height * 0.02),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// --------------------------
                /// LOGO
                /// --------------------------
                Center(
                  child: Image.asset(
                    'assets/images/ai.png',
                    height: 95,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 12),

                /// --------------------------
                /// TITLE
                /// --------------------------
                Center(
                  child: Text(
                    "Create An Account",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                /// --------------------------
                /// NAME FIELD
                /// --------------------------
                buildLabel("Full Name", theme),
                CustomTextFieldName(
                  controller: nameController,
                  hintText: "Enter full name",
                  validator: validateName,
                ),

                SizedBox(height: height * 0.02),

                /// --------------------------
                /// EMAIL FIELD
                /// --------------------------
                buildLabel("Email Address", theme),
                CustomTextFieldEmail(
                  controller: emailController,
                  hintText: "Enter email",
                  validator: validateEmail,
                ),

                SizedBox(height: height * 0.02),

                /// --------------------------
                /// PHONE FIELD
                /// --------------------------
                buildLabel("Phone Number", theme),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: InternationalPhoneNumberInput(
                    onInputChanged: (number) => phoneNumber = number,
                    onInputValidated: firebaseServices.setPhoneValid,
                    selectorConfig: const SelectorConfig(
                      selectorType: PhoneInputSelectorType.DROPDOWN,
                    ),
                    ignoreBlank: false,
                    autoValidateMode: AutovalidateMode.disabled,
                    textFieldController: phoneController,
                    initialValue: phoneNumber,
                    formatInput: true,
                    inputDecoration: const InputDecoration(
                      hintText: "+92 3xx xxxxxxx",
                      border: InputBorder.none,
                    ),
                  ),
                ),

                SizedBox(height: height * 0.02),

                /// --------------------------
                /// PASSWORD FIELD
                /// --------------------------
                buildLabel("Password", theme),
                Obx(() => CustomTextField(
                  controller: passwordController,
                  obscureText: !firebaseServices.isPasswordVisibleR.value,
                  hintText: "Enter password",
                  suffixIcon: IconButton(
                    onPressed: firebaseServices.togglePasswordVisibility,
                    icon: Icon(
                      firebaseServices.isPasswordVisibleR.value
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  validator: validatePassword,
                )),

                SizedBox(height: height * 0.02),

                /// --------------------------
                /// CONFIRM PASSWORD FIELD
                /// --------------------------
                buildLabel("Confirm Password", theme),
                Obx(() => CustomTextField(
                  controller: confirmPasswordController,
                  obscureText: !firebaseServices.isPasswordVisibleRE.value,
                  hintText: "Confirm password",
                  suffixIcon: IconButton(
                    onPressed: firebaseServices.toggleConfirmPasswordVisibility,
                    icon: Icon(
                      firebaseServices.isPasswordVisibleRE.value
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  validator: (v) => validateConfirmPassword(v, passwordController.text),
                )),

                SizedBox(height: height * 0.03),

                /// --------------------------
                /// REGISTER BUTTON
                /// --------------------------
                Obx(
                      () => RoundButton(
                    width: double.infinity,
                    height: 55,
                    loading: firebaseServices.loadingRegistration.value,
                    title: "Get Started",
                    onPress: () {
                      if (!formKey.currentState!.validate()) return;

                      final normalized = _normalizedPhone();
                      if (normalized.isEmpty) {
                        Get.snackbar("Error", "Phone number is required");
                        return;
                      }

                      final phoneToSave =
                      normalized.startsWith("+") ? normalized : "+$normalized";

                      firebaseServices.registration(
                        email: emailController.text.trim(),
                        password: passwordController.text,
                        fullName: nameController.text.trim(),
                        phone: phoneToSave,
                      );
                    },
                  ),
                ),

                // SizedBox(height: height * 0.02),
                //
                // /// --------------------------
                // /// OR DIVIDER
                // /// --------------------------
                // Row(
                //   children: [
                //     Expanded(
                //         child: Divider(color: theme.colorScheme.outlineVariant)),
                //     Padding(
                //       padding: const EdgeInsets.symmetric(horizontal: 8.0),
                //       child: Text(
                //         "OR",
                //         style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                //       ),
                //     ),
                //     Expanded(
                //         child: Divider(color: theme.colorScheme.outlineVariant)),
                //   ],
                // ),

                SizedBox(height: height * 0.025),

                /// --------------------------
                /// LOGIN NAVIGATION
                /// --------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already have an account?",
                        style: theme.textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Get.toNamed(RoutesName.login),
                      child: Text(
                        "Login",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// --------------------------
  /// LABEL WIDGET
  /// --------------------------
  Widget buildLabel(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  /// --------------------------
  /// VALIDATORS
  /// --------------------------
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email is required";
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(value) ? null : "Enter a valid email";
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return "Name is required";
    if (value.trim().length < 3) return "Minimum 3 characters required";
    if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(value.trim())) {
      return "Only alphabets and spaces allowed";
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required";
    if (value.length < 6) return "Minimum 6 characters required";
    return null;
  }

  String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return "Confirm password is required";
    if (value != password) {
      Get.snackbar("Error", "Passwords do not match",
          backgroundColor: Colors.red, colorText: Colors.white);
      return "Passwords do not match";
    }
    return null;
  }
}
