import 'package:flutter/material.dart';

class MathsSolver extends StatefulWidget {
  const MathsSolver({super.key});

  @override
  State<MathsSolver> createState() => _MathsSolverState();
}

class _MathsSolverState extends State<MathsSolver> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
        title: Text("Math Solver"),
      ),
      body: Center(
        child: Text("This is the Math solver page."),
      ),
    );
  }
}