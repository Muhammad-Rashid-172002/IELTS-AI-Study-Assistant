import 'package:flutter/material.dart';
import 'package:fyproject/resources/components/custom_text_field.dart';
import 'package:fyproject/resources/components/custom_text_field_email.dart';
import 'package:fyproject/screens/pages/home/home.dart';
import 'package:fyproject/screens/pages/login/forgot_Password/forgot_password.dart';
import 'package:fyproject/screens/pages/registration/registration.dart';
import 'package:fyproject/screens/widgets/botton/round_botton.dart';
import 'package:fyproject/screens/widgets/botton/round_botton2.dart';


class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  bool isPasswordVisible = false;

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
              /// LOGO
              Image.asset(
                'assets/images/ai.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),

              /// TITLE
              Text(
                'HELLO, WELCOME BACK',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: size.height * 0.03),

              /// FORM
              Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// EMAIL LABEL
                    Text(
                      'Email Address',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomTextFieldEmail(
                      controller: emailController,
                      hintText: 'Enter your email',
                      validator: validateEmail, focusNode: emailFocus, 
                    ),
                    const SizedBox(height: 16),

                    /// PASSWORD LABEL
                    Text(
                      'Password',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomTextField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      hintText: 'Enter your password',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            isPasswordVisible = !isPasswordVisible;
                          });
                        },
                        icon: Icon(
                          isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      validator: validatePassword,
                      prefixIcon: Icon(Icons.lock),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ForgotPasswordPage(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot password?',
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

              /// LOGIN BUTTON (UI only)
              RoundButton(
                width: double.infinity,
                height: isTablet ? 65 : 55,
                title: 'Login',
                loading: false,
                onPress: () {
                  if (formKey.currentState!.validate()) {
                    // Navigate to Home screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const Home()),
                    );
                  }
                },
              ),
              SizedBox(height: size.height * 0.03),

              /// OR DIVIDER
              Row(
                children: [
                  Expanded(
                    child: Divider(color: theme.colorScheme.outlineVariant),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('OR'),
                  ),
                  Expanded(
                    child: Divider(color: theme.colorScheme.outlineVariant),
                  ),
                ],
              ),
              SizedBox(height: size.height * 0.03),

              /// GOOGLE SIGN-IN BUTTON (UI only)
              RoundButton2(
                width: double.infinity,
                height: isTablet ? 65 : 55,
                loading: false,
                onPress: () {
                  // UI only, no backend
                },
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
              ),
              SizedBox(height: size.height * 0.04),

              /// SIGNUP TEXT
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: theme.textTheme.bodyMedium,
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const Registration()));
                    },
                    child: Text(
                      'Signup',
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

  /// VALIDATORS
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Email is required";
    final emailRegex = RegExp(r'^[\w\.-]+@[a-zA-Z\d\.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) return "Enter a valid email";
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required";
    if (value.length < 6) return "Password must be at least 6 characters";
    return null;
  }
}
