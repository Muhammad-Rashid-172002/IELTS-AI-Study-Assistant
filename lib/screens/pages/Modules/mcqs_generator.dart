import 'package:flutter/material.dart';

class McqsGenerator extends StatefulWidget {
  const McqsGenerator({super.key});

  @override
  State<McqsGenerator> createState() => _McqsGeneratorState();
}

class _McqsGeneratorState extends State<McqsGenerator> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MCQ Generator"),
      ),
      body: Center(
        child: Text("This is the MCQ generator page."),
      ),
    );
  }
}