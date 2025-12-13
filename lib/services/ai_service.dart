//
//
//
//
//
//
//
//
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter_gemini/flutter_gemini.dart';
//
// class AIService {
//   final gemini = Gemini.instance;
//
//   // Helper - clean latex / symbols
//   String _clean(String s) {
//     return s
//         .replaceAll("\$", "")
//         .replaceAll("\$", "")
//         .replaceAll("\\(", "")
//         .replaceAll("\\)", "")
//         .replaceAll("\\", "")
//         .trim();
//   }
//
//   // ---------------- TEXT SUMMARIZER ----------------
//   Future<String> summarizeText(
//       String text, {
//         String length = "Medium",
//         bool bullets = false,
//       }) async {
//     final prompt = """
// Summarize the following text.
//
// Rules:
// - No LaTeX or \$ symbols.
// - Use only plain English.
// - Length: $length
// - Bullet Points: $bullets
//
// TEXT:
// $text
// """;
//
//     final res = await gemini.text(prompt);
//     return _clean(res?.output ?? "No summary generated.");
//   }
//
//   // ---------------- IMAGE SUMMARIZER ----------------
//   Future<String> summarizeImage(File imageFile) async {
//     final bytes = await imageFile.readAsBytes();
//     final response = await gemini.textAndImage(
//       text: "Summarize what is shown in this image using plain text only.",
//       images: [bytes],
//     );
//
//     return _clean(response?.output ?? "No image summary.");
//   }
//
//   // ---------------- MCQ GENERATOR ----------------
//   Future<Map<String, dynamic>> generateMCQ(
//       String text,
//       String difficulty,
//       String focus,
//       ) async {
//     final prompt = """
// Generate ONE MCQ based on this study material.
//
// Difficulty: $difficulty
// Focus: $focus
//
// Return ONLY valid JSON in this exact format:
//
// {
//   "question": "",
//   "options": ["", "", "", ""],
//   "answer": ""
// }
//
// TEXT:
// $text
// """;
//
//     final res = await gemini.text(prompt);
//     final raw = res?.output ?? "{}";
//
//     try {
//       return jsonDecode(raw);
//     } catch (e) {
//       return {
//         "question": "MCQ generation failed.",
//         "options": ["-", "-", "-", "-"],
//         "answer": "-"
//       };
//     }
//   }
//
//
//
//   Future<String> solveMath(String query) async {
//     final prompt = """
// Solve this math problem step-by-step.
//
// Rules:
// - NO LaTeX
// - NO \$ symbols
// - Explain like a teacher
// - End with: "Answer: <final>"
//
// Problem:
// $query
// """;
//
//     final res = await gemini.text(prompt);
//     return _clean(res?.output ?? "No solution generated.");
//   }
//
//   // ---------------- FEEDBACK ----------------
// //   Future<String> feedback(String text) async {
// //     final prompt = """
// // You are an expert English instructor.
// // Give constructive, helpful study feedback for the following student work.
// //
// // Rules:
// // - No LaTeX
// // - No symbols like \$
// // - Use simple, clear English
// // - Organize feedback into short sections
// // - Include: strengths, weaknesses, and improvements
// // - Tone: friendly and encouraging
// //
// // TEXT:
// // $text
// // """;
// //
// //     final res = await gemini.text(prompt);
// //     return _clean(res?.output ?? "No feedback generated.");
// //   }
//   Future<String> feedback(String text, String category) async {
//     final prompt = """
// Provide detailed and helpful feedback for the following text.
//
// Category: $category
//
// Rules:
// - No LaTeX or \$ symbols
// - Be constructive and easy to understand
// - Give specific suggestions for improvement
// - Keep tone friendly and educational
//
// TEXT:
// $text
// """;
//
//     final res = await gemini.text(prompt);
//     return _clean(res?.output ?? "No feedback generated.");
//   }
//
//
//   // Future<String> feedback(String text) async {
//   //   final res = await gemini.text(
//   //       "Give helpful study feedback for this text:\n$text");
//   //   return _clean(res?.output ?? "No feedback generated.");
//   // }
// }



import 'dart:convert';
import 'dart:io';
import 'package:flutter_gemini/flutter_gemini.dart';

class AIService {
  final gemini = Gemini.instance;

  // Clean latex / symbols
  String _clean(String s) {
    return s
        .replaceAll("\$", "")
        .replaceAll("\\", "")
        .trim();
  }

  // UNIVERSAL SAFE CALL WITH RETRY (fixes 429)
  Future<T> _safeCall<T>(Future<T> Function() fn) async {
    int attempts = 0;

    while (attempts < 5) {
      try {
        return await fn();
      } catch (e) {
        final error = e.toString();

        // Handle rate limit 429
        if (error.contains("429")) {
          attempts++;
          print("⚠ Gemini rate limited. Retrying in ${attempts * 2}s...");
          await Future.delayed(Duration(seconds: attempts * 2));
          continue;
        }

        // Other errors → rethrow
        rethrow;
      }
    }

    throw Exception("Gemini overloaded. Please try again later.");
  }

  // ---------------- TEXT SUMMARIZER ----------------
  Future<String> summarizeText(
      String text, {
        String length = "Medium",
        bool bullets = false,
      }) async {
    final prompt = """
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
    final prompt = """
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
        "answer": "-"
      };
    }
  }

  // ---------------- MATH SOLVER ----------------
  Future<String> solveMath(String query) async {
    final prompt = """
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
    final prompt = """
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
}
