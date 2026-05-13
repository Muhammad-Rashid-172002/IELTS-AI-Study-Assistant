import 'dart:convert';

import 'package:flutter_gemini/flutter_gemini.dart';

class AIService {
  Map<String, dynamic> _safeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return {};
    }
  }

  static final Gemini gemini = Gemini.instance;

  // Clean latex / symbols
  String _clean(String s) {
    return s
        .replaceAll("\$", "")
        .replaceAll("\\", "")
        .replaceAll("```json", "")
        .replaceAll("```", "")
        .trim();
  }

  static bool _isRequestRunning = false;

  Future<T> _safeCall<T>(Future<T> Function() fn) async {
    // prevent parallel requests
    if (_isRequestRunning) {
      throw Exception("Please wait. Previous request still running.");
    }

    _isRequestRunning = true;

    int attempts = 0;

    try {
      while (attempts < 3) {
        try {
          // SMALL DELAY between requests
          await Future.delayed(const Duration(seconds: 2));

          return await fn().timeout(const Duration(seconds: 30));
        } catch (e) {
          print("GEMINI ERROR: $e");

          final error = e.toString();

          // RATE LIMIT
          if (error.contains("429")) {
            attempts++;

            final wait = Duration(seconds: attempts * 15);

            print("Retrying after $wait");

            await Future.delayed(wait);

            continue;
          }

          // SERVER ERRORS
          if (error.contains("500") || error.contains("503")) {
            attempts++;

            await Future.delayed(Duration(seconds: attempts * 10));

            continue;
          }

          // INTERNET
          if (error.contains("SocketException")) {
            throw Exception("No internet connection");
          }

          // TIMEOUT
          if (error.contains("TimeoutException")) {
            throw Exception("Request timeout");
          }

          rethrow;
        }
      }

      throw Exception("Gemini API limit exceeded. Try again later.");
    } finally {
      _isRequestRunning = false;
    }
  }

  // ---------------- TEXT SUMMARIZER ----------------
//   Future<String> summarizeText(
//     String text, {
//     String length = "Medium",
//     bool bullets = false,
//   }) async {
//     final prompt =
//         """
// Summarize the following text in plain English.

// Rules:
// - No LaTeX or \$ symbols.
// - Length: $length
// - Bullet Points: $bullets

// TEXT:
// $text
// """;

//     final res = await _safeCall(() => gemini.text(prompt));
//     return _clean(res?.output ?? "No summary generated.");
//   }

  // ---------------- IMAGE SUMMARIZER ----------------
  // Future<String> summarizeImage(File imageFile) async {
  //   final bytes = await imageFile.readAsBytes();

  //   final response = await _safeCall(
  //     () => gemini.textAndImage(
  //       text: "Summarize the image using plain English only.",
  //       images: [bytes],
  //     ),
  //   );

  //   return _clean(response?.output ?? "No image summary.");
  // }

  // ---------------- MCQ GENERATOR ----------------
//   Future<Map<String, dynamic>> generateMCQ(
//     String text,
//     String difficulty,
//     String focus,
//   ) async {
//     final prompt =
//         """
// Generate ONE MCQ based on this study material.

// Difficulty: $difficulty
// Focus: $focus

// Return ONLY this JSON format:

// {
//   "question": "",
//   "options": ["", "", "", ""],
//   "answer": ""
// }

// TEXT:
// $text
// """;

//     final res = await _safeCall(() => gemini.text(prompt));
//     final raw = res?.output ?? "{}";

//     try {
//       return jsonDecode(raw);
//     } catch (e) {
//       return {
//         "question": "MCQ generation failed.",
//         "options": ["-", "-", "-", "-"],
//         "answer": "-",
//       };
//     }
//   }

  // ---------------- MATH SOLVER ----------------
//   Future<String> solveMath(String query) async {
//     final prompt =
//         """
// Solve this math problem step-by-step.

// Rules:
// - No LaTeX
// - No \$ symbols
// - Explain clearly like a teacher
// - End with: "Answer: <final>"

// Problem:
// $query
// """;

//     final res = await _safeCall(() => gemini.text(prompt));
//     return _clean(res?.output ?? "No solution generated.");
//   }

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
  Future<Map<String, dynamic>> generateReadingQuestions(String passage) async {
    final prompt =
        """
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
    final prompt =
        """
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
    final prompt =
        """
You are a certified IELTS Writing Examiner.

Strictly evaluate this essay using official IELTS band descriptors.

Give realistic band score (0-9) with decimals like 6.5, 7.0 etc.

Return ONLY JSON:

{
  "band": "",
  "task_response": "",
  "coherence": "",
  "lexical": "",
  "grammar": "",
  "improvement": ""
}

Evaluation Rules:
- Be strict (do not give high band easily)
- Mention mistakes clearly
- Give short but useful feedback
- No symbols, no markdown

Essay:
$text
""";

    final res = await _safeCall(() => gemini.text(prompt));
    return _safeJson(res?.output ?? "{}");
  }

  // Writing Ideas Generator
  Future<String> generateWritingIdeas(String topic) async {
    final prompt =
        """
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
    final prompt =
        """
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
Generate IELTS Reading test.

Return ONLY valid JSON:

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
- 1 passage
- 5 MCQs
- no markdown
""";

    try {
      final res = await _safeCall(() => gemini.text(prompt));

      final data = _parseJson(res?.output ?? "{}");

      if (data["questions"] == null) {
        throw Exception("Invalid AI response");
      }

      return data;
    } catch (e) {
      print("READING ERROR: $e");

      return {"passage": "", "questions": []};
    }
  }

  Map<String, dynamic> _parseJson(String raw) {
    try {
      raw = raw.replaceAll("```json", "").replaceAll("```", "").trim();

      return jsonDecode(raw);
    } catch (e) {
      print("JSON PARSE ERROR: $e");
      return {};
    }
  }

  //.
  Future<Map<String, dynamic>> generateVocabulary(String topic) async {
    final prompt =
        """
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
      return _parseJson(res?.output ?? "{}");
    } catch (e) {
      return {};
    }
  }

  Future<String> generateWritingTopic(String taskType) async {
    final prompt =
        """
You are an IELTS examiner.

Generate ONE IELTS Writing Task $taskType topic.

Rules:
- Task 1 = chart/graph
- Task 2 = opinion/discussion essay
- No explanation
- Only topic text
""";

    final res = await _safeCall(() => gemini.text(prompt));
    return _clean(res?.output ?? "Failed to load topic");
  }

  Future<Map<String, dynamic>> generateSpeakingTopic() async {
    final prompt = """
You are an IELTS Speaking examiner.

Generate ONE IELTS Speaking Part 2 cue card.

Return ONLY JSON:

{
  "topic": "",
  "points": [
    "",
    "",
    "",
    ""
  ]
}

Rules:
- Real IELTS style
- Simple English
- No explanation
""";

    final res = await _safeCall(() => gemini.text(prompt));
    return _safeJson(res?.output ?? "{}");
  }

  Future<Map<String, dynamic>> evaluateSpeaking(
    String transcript,
    int duration,
  ) async {
    final prompt =
        """
You are a certified IELTS Speaking Examiner.

Evaluate the candidate based on official IELTS criteria:

- Fluency and Coherence
- Lexical Resource
- Grammatical Range and Accuracy
- Pronunciation

Give a realistic band score (0–9).

Return ONLY JSON:

{
  "band": "",
  "fluency": "",
  "lexical": "",
  "grammar": "",
  "pronunciation": "",
  "improvement": ""
}

Rules:
- Be strict
- No symbols
- Simple English
- Short feedback

Transcript:
$transcript

Speaking Duration: $duration seconds
""";

    final res = await _safeCall(() => gemini.text(prompt));
    return _safeJson(res?.output ?? "{}");
  }

  Future<List<String>> generateFollowUpQuestions(String topic) async {
    final prompt =
        """
You are an IELTS examiner.

Generate 3 Part 3 follow-up questions based on this topic:

$topic

Return ONLY JSON:

{
  "questions": ["", "", ""]
}
""";

    final res = await _safeCall(() => gemini.text(prompt));
    final data = _safeJson(res?.output ?? "{}");

    return List<String>.from(data["questions"] ?? []);
  }

  // ---------------- LISTENING TEST GENERATOR ----------------
  Future<String> generateListeningTest() async {
    final prompt = """
Create IELTS Listening Section 1.

Format:

TRANSCRIPT:
Customer: ...
Receptionist: ...

QUESTIONS:
1. ...
A) ...
B) ...
C) ...
D) ...
ANSWER: A

Rules:
- natural English
- short
- no JSON
""";

    try {
      final res = await _safeCall(() => gemini.text(prompt));

      return _clean(res?.output ?? "");
    } catch (e) {
      print("LISTENING ERROR: $e");
      return "Failed to generate listening test.";
    }
  }
}
