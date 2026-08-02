import 'package:flutter/material.dart';

class Practicescreen extends StatefulWidget {
  const Practicescreen({super.key});

  @override
  State<Practicescreen> createState() => _PracticescreenState();
}

class _PracticescreenState extends State<Practicescreen> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("Practice Screen"),
    );
  }
}