import 'package:flutter/material.dart';

class TextSummarizer extends StatefulWidget {
  const TextSummarizer({super.key});

  @override
  State<TextSummarizer> createState() => _TextSummarizerState();
}

class _TextSummarizerState extends State<TextSummarizer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Text Summarization")),
      body: Center(child: Text("This is the text summarization page.")),
    );
  }
}
