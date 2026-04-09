import 'dart:convert';

import 'package:fyproject/config/keys.dart';
import 'package:http/http.dart' as http;

/// Model for an IELTS question
class IELTSQuestion {
  final String question;
  final List<String> options;
  final int answer; // index of correct option

  IELTSQuestion({
    required this.question,
    required this.options,
    required this.answer,
  });

  factory IELTSQuestion.fromJson(Map<String, dynamic> json) {
    return IELTSQuestion(
      question: json['question'] ?? "",
      options: List<String>.from(json['options'] ?? []),
      answer: json['answer'] ?? 0,
    );
  }
}

class IELTSController {
  final String geminiApiKey = AppKeys.geminiApiKey;

  /// Generate IELTS Questions for a given skill
  /// skill = "Listening", "Reading", "Writing", "Speaking"
  Future<List<IELTSQuestion>> getQuestions(String skill) async {
    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey",
      );

      /// Prompt tailored to IELTS
      final prompt = """
Return ONLY JSON. Create 2 $skill IELTS questions.
- For Listening/Reading, use multiple-choice format: [{ "question": "...", "options": ["", "", ""], "answer": 0 }]
- For Writing/Speaking, return 2 task prompts in the same JSON format: [{ "question": "...", "options": [], "answer": 0 }]
""";

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contents": [
            {
              "text": prompt,
              "type": "text",
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("API Error: ${response.statusCode}");
      }

      final data = jsonDecode(response.body);

      if (data["candidates"] == null || data["candidates"].isEmpty) {
        throw Exception("No candidates returned by AI");
      }

      String text = data["candidates"][0]["content"]["parts"][0]["text"];

      /// Clean JSON from text
      text = text.substring(
        text.indexOf('['),
        text.lastIndexOf(']') + 1,
      );

      final List<dynamic> jsonList = jsonDecode(text);

      return jsonList.map((e) => IELTSQuestion.fromJson(e)).toList();
    } catch (e) {
      throw Exception("AI Error: $e");
    }
  }
}