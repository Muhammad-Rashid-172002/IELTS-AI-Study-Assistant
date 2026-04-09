import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fyproject/config/keys.dart';

class IELTSService {
  final String apiKey = AppKeys.geminiApiKey; // Your API key

  /// Fetch IELTS questions from AI
  Future<List<dynamic>> getQuestions({required String section}) async {
    final response = await http.post(
      Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey",
      ),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Return ONLY JSON. Create 2 IELTS $section MCQs in this format: [{\"question\":\"\",\"options\":[\"\",\"\",\"\"],\"answer\":0}]"
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("AI API error: ${response.statusCode}");
    }

    final data = jsonDecode(response.body);

    String text = data["candidates"][0]["content"]["parts"][0]["text"];

    // Clean JSON
    text = text.substring(text.indexOf('['), text.lastIndexOf(']') + 1);

    return jsonDecode(text);
  }
}