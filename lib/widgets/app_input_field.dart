import 'package:flutter/material.dart';

enum InputType { text, email, password }

class AppInputField extends StatefulWidget {
  final String hint;
  final TextEditingController controller;
  final IconData? icon;
  final InputType inputType;

  const AppInputField({
    super.key,
    required this.hint,
    required this.controller,
    this.icon,
    this.inputType = InputType.text,
  });

  @override
  State<AppInputField> createState() => _AppInputFieldState();
}

class _AppInputFieldState extends State<AppInputField> {
  bool _obscure = true;
  String? _errorText;

  bool get isPassword => widget.inputType == InputType.password;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _errorText == null
                  ? Colors.white.withOpacity(0.25)
                  : Colors.redAccent,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: isPassword ? _obscure : false,
            cursorColor: Colors.white,
            style: const TextStyle(color: Colors.white),

            keyboardType: widget.inputType == InputType.email
                ? TextInputType.emailAddress
                : TextInputType.text,

            onChanged: (_) {
              setState(() => _errorText = null);
            },

            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: Colors.white70),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 18,
              ),

              // prefix icon
              prefixIcon: widget.icon != null
                  ? Icon(widget.icon, color: Colors.white70)
                  : null,

              // password eye toggle
              suffixIcon: isPassword
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
        ),

        /// Error text display
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text(
              _errorText!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
      ],
    );
  }

  /// Validate the input field
  bool validate() {
    String value = widget.controller.text.trim();

    // Empty check
    if (value.isEmpty) {
      _errorText = "${widget.hint} cannot be empty";
      setState(() {});
      return false;
    }

    // Email validation
    if (widget.inputType == InputType.email) {
      final emailRegex = RegExp(
        r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$",
      );

      if (!emailRegex.hasMatch(value)) {
        _errorText = "Enter a valid email";
        setState(() {});
        return false;
      }
    }

    // Password validation
    if (widget.inputType == InputType.password) {
      if (value.length < 6) {
        _errorText = "Password must be at least 6 characters";
        setState(() {});
        return false;
      }
    }

    // Basic text minimum characters
    if (widget.inputType == InputType.text && value.length < 3) {
      _errorText = "Enter at least 3 characters";
      setState(() {});
      return false;
    }

    _errorText = null;
    setState(() {});
    return true;
  }
}
