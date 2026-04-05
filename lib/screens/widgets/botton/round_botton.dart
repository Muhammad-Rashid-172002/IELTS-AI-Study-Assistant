import 'package:flutter/material.dart';

class RoundButton extends StatelessWidget {
  final bool loading;
  final String title;
  final VoidCallback onPress;
  final double height, width;

  const RoundButton({
    super.key,
    this.loading = false,
    required this.title,
    required this.onPress,
    this.width = double.infinity,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: loading ? null : onPress,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),

          /// 🔥 Premium Gradient (Blue → Purple)
          gradient: const LinearGradient(
            colors: [
              Color(0xff4A00E0), // Deep Purple Blue
              Color(0xff8E2DE2), // Neon Purple
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),

          /// 🔥 Soft Glow Shadow
          boxShadow: [
            BoxShadow(
              color: Color(0xff8E2DE2).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),

        child: Center(
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}