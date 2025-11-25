import 'package:flutter/material.dart';
import '../../controller/auth_controller.dart';
import '../../widgets/app_input_field.dart';
import '../../widgets/app_button.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final AuthController controller = AuthController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Welcome Back",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text("Login to continue"),
            SizedBox(height: 30),

            AppInputField(
              hint: "Email",
              controller: controller.emailController,
            ),
            SizedBox(height: 20),

            AppInputField(
              hint: "Password",
              controller: controller.passwordController,
              isPassword: true,
            ),
            SizedBox(height: 30),

            controller.isLoading
                ? CircularProgressIndicator()
                : AppButton(
                    text: "Login",
                    onPressed: () async {
                      setState(() {});
                      await controller.login(context);
                      setState(() {});
                    },
                  ),

            SizedBox(height: 20),

            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/signup');
              },
              child: Text(
                "Don't have an account? Sign up",
                style: TextStyle(color: Colors.blueAccent),
              ),
            )
          ],
        ),
      ),
    );
  }
}
