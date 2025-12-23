import 'package:flutter/material.dart';

/// 👤 Modern Name Text Field (IELTS Style)
class CustomTextFieldName extends StatelessWidget {
  const CustomTextFieldName({
    super.key,
    required this.controller,
    required this.hintText,
    this.validator,
  });
// -- Parameters --
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
// BUILD
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: TextInputType.name,
        textCapitalization: TextCapitalization.words,
        style: theme.textTheme.bodyLarge,
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration(
          hintText: hintText,

          // ICON
          prefixIcon: Icon(
            Icons.person_outline,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),

          filled: true,
          fillColor: theme.colorScheme.surface,

          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),

          // MODERN BORDERS
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
        ),
      ),
    );
  }
}
