import 'package:flutter/material.dart';

class GoogleButton extends StatefulWidget {
  final VoidCallback onPressed;

  const GoogleButton({super.key, required this.onPressed});

  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  double _elevationOffset = 5;

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.94;
      _elevationOffset = 2;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
      _elevationOffset = 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: () => setState(() {
          _scale = 1.0;
          _elevationOffset = 5;
        }),
        onTap: widget.onPressed,
        child: Container(
          height: 55,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(14),

            // border stroke
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.2,
            ),

            // shadow
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 14,
                offset: Offset(0, _elevationOffset),
              ),
            ],
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // google icon
              Image.asset("assets/images/google.png", height: 26),

              const SizedBox(width: 14),

              // text
              Text(
                "Continue with Google",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
