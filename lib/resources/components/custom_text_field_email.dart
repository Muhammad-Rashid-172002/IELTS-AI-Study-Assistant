import 'package:flutter/material.dart';

/// ✉️ Modern Email Text Field (IELTS Style)
class CustomTextFieldEmail extends StatelessWidget {
  const CustomTextFieldEmail({
    super.key,
    required this.controller,
    required this.hintText,
    this.validator,
    this.suffixIcon,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        validator: validator,
        enabled: enabled,
        keyboardType: TextInputType.emailAddress,
        style: theme.textTheme.bodyLarge,
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration(
          hintText: hintText,

          // FIXED EMAIL ICON
          prefixIcon: Icon(
            Icons.email_outlined,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),

          suffixIcon: suffixIcon,

          filled: true,
          fillColor: theme.colorScheme.surface,
//
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.4,
            ),
          ),

          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),

          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.4),
          ),
        ),
      ),
    );
  }
}
