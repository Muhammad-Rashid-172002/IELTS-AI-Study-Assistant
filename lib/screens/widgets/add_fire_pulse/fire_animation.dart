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

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
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
    return ScaleTransition(
      scale: _scale,
      child: const CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white54,
        child: Icon(
          Icons.local_fire_department,
          color: Colors.deepOrange,
          size: 22,
        ),
      ),
    );
  }
}
