// import 'dart:convert';
// import 'package:fyproject/config/keys.dart';
// import 'package:http/http.dart' as http;


// class GeminiService {
//   final String apiKey = AppKeys.geminiApiKey; // Your API key

//   Future<WordMeaning> getMeaning(String word) async {
//     final prompt = """
// Return ONLY JSON:

// {
//  "word": "$word",
//  "meaning": "",
//  "urdu": "",
//  "synonyms": [],
//  "antonyms": [],
//  "examples": [],
//  "pronunciation": ""
// }

// Explain the word '$word' for IELTS student.
// """;

//     final url =
//         "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey";

//     final response = await http.post(
//       Uri.parse(url),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({
//         "contents": [
//           {
//             "parts": [
//               {"text": prompt}
//             ]
//           }
//         ]
//       }),
//     );

//     final data = jsonDecode(response.body);

//     final text =
//         data["candidates"][0]["content"]["parts"][0]["text"];

//     final cleanJson = jsonDecode(text);

//     return WordMeaning.fromJson(cleanJson);
//   }
// }