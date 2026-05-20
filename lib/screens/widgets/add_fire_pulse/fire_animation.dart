import 'package:flutter/material.dart';

class FirePulseIcon extends StatefulWidget {
  const FirePulseIcon({super.key});

  @override
  State<FirePulseIcon> createState() => _FirePulseIconState();
}

class _FirePulseIconState extends State<FirePulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 1,
      end: 1.12,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _glow = Tween<double>(
      begin: 10,
      end: 26,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return ScaleTransition(
          scale: _scale,
          child: Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFB800),
                  Color(0xFFFF7A00),
                  Color(0xFFFF3D00),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.5,
              ),

              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFFF7A00,
                  ).withOpacity(0.55),
                  blurRadius: _glow.value,
                  spreadRadius: 2,
                ),
              ],
            ),

            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),

                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}