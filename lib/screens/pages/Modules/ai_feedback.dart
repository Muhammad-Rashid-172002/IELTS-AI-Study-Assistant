import 'package:flutter/material.dart';

class AiFeedback extends StatefulWidget {
  const AiFeedback({super.key});

  @override
  State<AiFeedback> createState() => _AiFeedbackState();
}

class _AiFeedbackState extends State<AiFeedback> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AI Feedback"),
      ),
      body: Center(
        child: Text("This is the AI feedback page."),
      ),
    );
  }
}