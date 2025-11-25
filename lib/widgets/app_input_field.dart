import 'package:flutter/material.dart';

class AppInputField extends StatefulWidget {
  final String hint;
  final TextEditingController controller;
  final bool isPassword;
  final IconData? icon;

  const AppInputField({
    super.key,
    required this.hint,
    required this.controller,
    this.isPassword = false,
    this.icon,
  });

  @override
  State<AppInputField> createState() => _AppInputFieldState();
}

class _AppInputFieldState extends State<AppInputField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.isPassword ? _obscure : false,
        style: TextStyle(color: Colors.white),

        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,

          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 18),

          // prefix icon
          prefixIcon: widget.icon != null
              ? Icon(
                  widget.icon,
                  color: Colors.white70,
                )
              : null,

          // password eye icon
          suffixIcon: widget.isPassword
              ? GestureDetector(
                  onTap: () {
                    setState(() => _obscure = !_obscure);
                  },
                  child: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
