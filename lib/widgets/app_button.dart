import 'package:flutter/material.dart';

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  const AppButton({
    super.key,
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
    setState(() => _scale = 0.94);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapCancel: () => setState(() => _scale = 1.0),
        onTapUp: _onTapUp,
        onTap: widget.onPressed,
        child: Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.backgroundColor != null
                  ? [
                      widget.backgroundColor!,
                      widget.backgroundColor!,
                    ]
                  : const [
                      Color(0xff6366F1),
                      Color(0xff4F46E5),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: Offset(0, 4),
              )
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.textColor ?? Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
