import 'package:flutter/material.dart';

class AppButton extends StatefulWidget {
//  final String title;
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  const AppButton({

    super.key,
   // required this.title,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.96);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutQuint,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapCancel: () => setState(() => _scale = 1.0),
        onTapUp: _onTapUp,
        onTap: widget.onPressed,

        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),

            gradient: widget.backgroundColor != null
                ? LinearGradient(
                    colors: [
                      widget.backgroundColor!.withOpacity(0.9),
                      widget.backgroundColor!,
                    ],
                  )
                : const LinearGradient(
                    colors: [
                      Color(0xFF2563EB), // Deep IELTS Blue
                      Color(0xFF4F8EF7), // Soft Sky Blue
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),

            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.25),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],

            border: Border.all(
              color: Colors.white.withOpacity(0.20),
              width: 1.2,
            ),

            // Glassmorphism effect
            color: Colors.white.withOpacity(0.1),
            backgroundBlendMode: BlendMode.overlay,
          ),

          child: Center(
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: widget.textColor ?? Colors.white,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
