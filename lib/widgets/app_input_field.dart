import 'package:flutter/material.dart';

enum InputType { text, email, password }

class AppInputField extends StatefulWidget {
  final String hint;
  final TextEditingController controller;
  final bool isPassword;
  final IconData? icon;
  final InputType inputType;

  const AppInputField({
    super.key,
    required this.hint,
    required this.controller,
    this.isPassword = false,
    this.icon,
    this.inputType = InputType.text,
  });

  @override
  State<AppInputField> createState() => _AppInputFieldState();
}

class _AppInputFieldState extends State<AppInputField> {
  bool _obscure = true;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _errorText != null
                  ? Colors.redAccent
                  : Colors.white.withOpacity(0.25),
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
            keyboardType: widget.inputType == InputType.email
                ? TextInputType.emailAddress
                : TextInputType.text,
            onChanged: (_) => setState(() => _errorText = null),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 18),

              // prefix icon
              prefixIcon: widget.icon != null
                  ? Icon(widget.icon, color: Colors.white70)
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
        ),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              _errorText!,
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
      ],
    );
  }

  /// Validate the input and return true if valid
  bool validate() {
    String value = widget.controller.text.trim();

    if (value.isEmpty) {
      _errorText = "${widget.hint} cannot be empty";
      setState(() {});
      return false;
    }

    if (widget.inputType == InputType.email) {
      // basic email regex
      final emailRegex =
          RegExp(r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$");
      if (!emailRegex.hasMatch(value)) {
        _errorText = "Enter a valid email";
        setState(() {});
        return false;
      }
    }

    if (widget.isPassword) {
      // password validation: min 6 chars
      if (value.length < 6) {
        _errorText = "Password must be at least 6 characters";
        setState(() {});
        return false;
      }
    }

    // username validation (if text)
    if (widget.inputType == InputType.text && value.length < 3) {
      _errorText = "Must be at least 3 characters";
      setState(() {});
      return false;
    }

    _errorText = null;
    setState(() {});
    return true;
  }
}
