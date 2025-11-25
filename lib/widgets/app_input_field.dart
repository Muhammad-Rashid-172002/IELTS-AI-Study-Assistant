import 'package:flutter/material.dart';

class AppInputField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final bool isPassword;

  const AppInputField({
    super.key,
    required this.hint,
    required this.controller,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      ),
    );
  }
}
