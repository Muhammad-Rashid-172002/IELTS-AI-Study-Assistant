import 'package:flutter/material.dart';

class RoundButton extends StatelessWidget {
  final bool isLoading;
  final String title;
  final VoidCallback onPress;
  final double height;
  final double width;

  const RoundButton({
    super.key,
    required this.title,
    required this.onPress,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onPress,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isLoading
                ? [
                    const Color(0xFF64748B),
                    const Color(0xFF475569),
                  ]
                : [
                    const Color(0xFF2DD4BF),
                    const Color(0xFF14B8A6),
                    const Color(0xFF0F766E),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14B8A6).withOpacity(0.45),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 23,
                  width: 23,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.6,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}