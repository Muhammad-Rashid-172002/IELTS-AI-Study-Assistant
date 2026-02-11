import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/home/home.dart';
import 'package:fyproject/screens/pages/login/login.dart';
import 'package:fyproject/screens/widgets/botton/round_botton.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import '../../../resources/components/custom_text_field.dart';
import '../../../resources/components/custom_text_field_email.dart';
import '../../../resources/components/custom_text_field_name.dart';

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {
  final formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
       final FocusNode emailFocus = FocusNode();

  PhoneNumber phoneNumber = PhoneNumber(isoCode: 'PK');
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    emailFocus.dispose();   
    super.dispose();
  }

  String _normalizedPhone() =>
      phoneNumber.phoneNumber ?? phoneController.text.trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.06,
            vertical: height * 0.02,
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Logo
                Center(
                  child: Image.asset(
                    'assets/images/ai.png',
                    height: 95,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),

                /// Title
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

                /// Name
                buildLabel("Full Name", theme),
                CustomTextFieldName(
                  controller: nameController,
                  hintText: "Enter full name",
                  validator: validateName,
                ),
                SizedBox(height: height * 0.02),

                /// Email
                buildLabel("Email Address", theme),
                CustomTextFieldEmail(
                  controller: emailController,
                  hintText: "Enter Email",
                  focusNode: emailFocus, // ✅ pass here
                ),
                SizedBox(height: height * 0.02),

                /// Phone
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

                /// Password
                buildLabel("Password", theme),
                CustomTextField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  hintText: "Enter password",
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => isPasswordVisible = !isPasswordVisible),
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  validator: validatePassword,
                  prefixIcon: Icon(Icons.lock),
                ),
                SizedBox(height: height * 0.02),

                /// Confirm Password
                buildLabel("Confirm Password", theme),
                CustomTextField(
                  controller: confirmPasswordController,
                  obscureText: !isConfirmPasswordVisible,
                  hintText: "Confirm password",
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () =>
                          isConfirmPasswordVisible = !isConfirmPasswordVisible,
                    ),
                    icon: Icon(
                      isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  validator: (v) =>
                      validateConfirmPassword(v, passwordController.text),
                  prefixIcon: Icon(Icons.lock),
                ),
                SizedBox(height: height * 0.03),

                /// Register button
                RoundButton(
                  width: double.infinity,
                  height: 55,
                  title: "Get Started",
                  loading: false,
                  onPress: () {
                    if (!formKey.currentState!.validate()) return;

                    final normalized = _normalizedPhone();
                    if (normalized.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Phone number is required"),
                        ),
                      );
                      return;
                    }

                    // Navigate to Home screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const Home()),
                    );
                  },
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("Already have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Login(),
                          ),
                        );
                      },
                      child: Text("Login"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email is required";
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(value) ? null : "Enter a valid email";
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return "Name is required";
    if (value.trim().length < 3) return "Minimum 3 characters required";
    if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(value.trim()))
      return "Only alphabets and spaces allowed";
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required";
    if (value.length < 6) return "Minimum 6 characters required";
    return null;
  }

  String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return "Confirm password is required";
    if (value != password) return "Passwords do not match";
    return null;
  }
}
