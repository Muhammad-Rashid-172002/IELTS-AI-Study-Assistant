
import 'dart:convert';
import 'dart:io';
import 'package:flutter_gemini/flutter_gemini.dart';

class AIService {
  Map<String, dynamic> _safeJson(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return {};
  }
}
  final gemini = Gemini.instance;

  // Clean latex / symbols
String _clean(String s) {
  return s
      .replaceAll("\$", "")
      .replaceAll("\\", "")
      .replaceAll("```json", "")
      .replaceAll("```", "")
      .trim();
}

// UNIVERSAL SAFE CALL WITH RETRY (fixes 429)
Future<T> _safeCall<T>(Future<T> Function() fn) async {
  int attempts = 0;

  while (attempts < 5) {
    try {
      return await fn().timeout(Duration(seconds: 20));
    } catch (e) {
      final error = e.toString();

      if (error.contains("429")) {
        attempts++;
        await Future.delayed(Duration(seconds: attempts * 2));
        continue;
      }

      rethrow;
    }
  }

  throw Exception("Server busy. Try again.");
}

// ---------------- TEXT SUMMARIZER ----------------
Future<String> summarizeText(
  String text, {
  String length = "Medium",
  bool bullets = false,
  }) async {
    final prompt =
        """
Summarize the following text in plain English.

Rules:
- No LaTeX or \$ symbols.
- Length: $length
- Bullet Points: $bullets

TEXT:
$text
""";

    final res = await _safeCall(() => gemini.text(prompt));
    return _clean(res?.output ?? "No summary generated.");
  }

  // ---------------- IMAGE SUMMARIZER ----------------
  Future<String> summarizeImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();

    final response = await _safeCall(
      () => gemini.textAndImage(
        text: "Summarize the image using plain English only.",
        images: [bytes],
      ),
    );

    return _clean(response?.output ?? "No image summary.");
  }

  // ---------------- MCQ GENERATOR ----------------
  Future<Map<String, dynamic>> generateMCQ(
    String text,
    String difficulty,
    String focus,
  ) async {
    final prompt =
        """
Generate ONE MCQ based on this study material.

Difficulty: $difficulty
Focus: $focus

Return ONLY this JSON format:

{
  "question": "",
  "options": ["", "", "", ""],
  "answer": ""
}

TEXT:
$text
""";

    final res = await _safeCall(() => gemini.text(prompt));
    final raw = res?.output ?? "{}";

    try {
      return jsonDecode(raw);
    } catch (e) {
      return {
        "question": "MCQ generation failed.",
        "options": ["-", "-", "-", "-"],
        "answer": "-",
      };
    }
  }

  // ---------------- MATH SOLVER ----------------
  Future<String> solveMath(String query) async {
    final prompt =
        """
Solve this math problem step-by-step.

Rules:
- No LaTeX
- No \$ symbols
- Explain clearly like a teacher
- End with: "Answer: <final>"

Problem:
$query
""";

    final res = await _safeCall(() => gemini.text(prompt));
    return _clean(res?.output ?? "No solution generated.");
  }

  // ---------------- FEEDBACK generator ----------------
  Future<String> feedback(String text, String category) async {
    final prompt =
        """
You are an expert English instructor.
Give detailed feedback for the following text.

Category: $category

Rules:
- No LaTeX or \$ symbols
- Simple, clear English
- Friendly tone
- Include strengths, weaknesses, improvements

TEXT:
$text
""";

    final res = await _safeCall(() => gemini.text(prompt));
    return _clean(res?.output ?? "No feedback generated.");
  }

  // ---------------- READING QUESTIONS GENERATOR ----------------
  Future<Map<String, dynamic>> generateReadingQuestions(
  String passage,
) async {
  final prompt = """
You are an IELTS Reading examiner.

Create:
- 2 MCQs
- 2 True/False/Not Given

Return ONLY JSON:

{
  "mcqs": [
    {
      "question": "",
      "options": ["", "", "", ""],
      "answer": ""
    }
  ],
  "true_false": [
    {
      "statement": "",
      "answer": "True/False/Not Given"
    }
  ]
}

PASSAGE:
$passage
""";

  final res = await _safeCall(() => gemini.text(prompt));
  return _safeJson(res?.output ?? "{}");
}

// ---------------- reading 
Future<String> checkReadingAnswer(
  String question,
  String userAnswer,
  String correctAnswer,
) async {
  final prompt = """
Check the user's answer.

Question: $question
User Answer: $userAnswer
Correct Answer: $correctAnswer

Explain briefly if correct or not.

Rules:
- Simple English
- No symbols
""";

  final res = await _safeCall(() => gemini.text(prompt));
  return _clean(res?.output ?? "No explanation.");
}

// Writing Evaluation (Band Score)

Future<Map<String, dynamic>> evaluateWriting(
  String text,
  String taskType,
) async {
  final prompt = """
You are an IELTS examiner.

Evaluate this Writing Task $taskType.

Return ONLY JSON:

{
  "band": "",
  "task_response": "",
  "coherence": "",
  "lexical": "",
  "grammar": "",
  "improvement": ""
}

Essay:
$text
""";

  final res = await _safeCall(() => gemini.text(prompt));
  return _safeJson(res?.output ?? "{}");
}
// Writing Ideas Generator
Future<String> generateWritingIdeas(String topic) async {
  final prompt = """
Give ideas for IELTS essay.

Topic:
$topic

Provide:
- 3 main ideas
- examples

Simple English only.
""";

  final res = await _safeCall(() => gemini.text(prompt));
  return _clean(res?.output ?? "No ideas.");
}
//Improve Writing
Future<String> improveWriting(String text) async {
  final prompt = """
Improve this IELTS essay.

Rules:
- Better vocabulary
- Better grammar
- Keep meaning same
- No symbols

Essay:
$text
""";

  final res = await _safeCall(() => gemini.text(prompt));
  return _clean(res?.output ?? "No improvement.");
}

Future<Map<String, dynamic>> generateReadingTest() async {
  final prompt = """
You are an IELTS Reading examiner.

Generate a reading test.

Return ONLY JSON:

{
  "passage": "",
  "questions": [
    {
      "question": "",
      "options": ["", "", "", ""],
      "answer": 0
    }
  ]
}

Rules:
- 1 short passage (120-180 words)
- 5 MCQs
- answer must be index (0,1,2,3)
- No explanation
""";

  final res = await _safeCall(() => gemini.text(prompt));

  try {
    return jsonDecode(res?.output ?? "{}");
  } catch (e) {
    return {};
  }
}
//. 
Future<Map<String, dynamic>> generateVocabulary(String topic) async {
  final prompt = """
Generate IELTS vocabulary words for topic: $topic

Return ONLY JSON:

{
  "words": [
    {
      "word": "",
      "meaning": "",
      "example": "",
      "type": "writing/speaking/reading/listening"
    }
  ]
}

Rules:
- 10 IELTS-level words
- simple English
- no extra text
""";

  final res = await _safeCall(() => gemini.text(prompt));

  try {
    return jsonDecode(res?.output ?? "{}");
  } catch (e) {
    return {};
  }
}

}
