import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';

class IELTSService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Fetch IELTS questions from AI
  Future<List<dynamic>> getQuestions({required String section}) async {
    final response = await _functions.httpsCallable('legacyAiAssist').call({
      'purpose': 'question_generation',
      'prompt':
          'Return ONLY JSON. Create 2 IELTS $section MCQs in this format: '
          '[{"question":"","options":["","",""],"answer":0}]',
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    String text = (data['text'] ?? '').toString();

    // Clean JSON
    text = text.substring(text.indexOf('['), text.lastIndexOf(']') + 1);

    return jsonDecode(text);
  }
}
