import 'dart:async';
import 'dart:convert';
import 'package:flutter_gemini/flutter_gemini.dart';

class AIService {
  static final Gemini gemini = Gemini.instance;
  static bool _isRequestRunning = false;

  String _clean(String text) {
    return text
        .replaceAll("```json", "")
        .replaceAll("```", "")
        .replaceAll(r"$", "")
        .replaceAll("\\", "")
        .trim();
  }

  String _extractJson(String raw) {
    raw = raw.replaceAll("```json", "").replaceAll("```", "").trim();

    final startObj = raw.indexOf("{");
    final endObj = raw.lastIndexOf("}");

    if (startObj != -1 && endObj != -1 && endObj > startObj) {
      return raw.substring(startObj, endObj + 1);
    }

    return raw;
  }

  Map<String, dynamic> _safeJson(String raw) {
    try {
      return jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
    } catch (e) {
      print("JSON PARSE ERROR: $e");
      print("RAW RESPONSE: $raw");
      return {};
    }
  }

  Future<T> _safeCall<T>(Future<T> Function() request) async {
    if (_isRequestRunning) {
      throw Exception("Please wait. Previous AI request is still running.");
    }

    _isRequestRunning = true;

    int attempts = 0;

    try {
      while (attempts < 3) {
        try {
          await Future.delayed(const Duration(milliseconds: 800));
          return await request().timeout(const Duration(seconds: 45));
        } catch (e) {
          attempts++;
          final error = e.toString();

          print("GEMINI ERROR: $error");

          if (error.contains("429")) {
            await Future.delayed(Duration(seconds: attempts * 12));
            continue;
          }

          if (error.contains("500") || error.contains("503")) {
            await Future.delayed(Duration(seconds: attempts * 8));
            continue;
          }

          if (error.contains("SocketException")) {
            throw Exception("No internet connection.");
          }

          if (error.contains("TimeoutException")) {
            throw Exception("AI request timeout. Try again.");
          }

          rethrow;
        }
      }

      throw Exception("AI limit exceeded. Please try again later.");
    } finally {
      _isRequestRunning = false;
    }
  }

  Future<String> _text(String prompt) async {
    final res = await _safeCall(() => gemini.text(prompt));
    return _clean(res?.output ?? "");
  }

  Future<Map<String, dynamic>> _json(String prompt) async {
    final res = await _safeCall(() => gemini.text(prompt));
    return _safeJson(res?.output ?? "{}");
  }

  // =========================================================
  // IELTS HOME / DIAGNOSTIC
  // =========================================================

  Future<Map<String, dynamic>> generateStudyPlan({
    required String targetBand,
    required String currentLevel,
    required int days,
  }) async {
    final prompt = """
You are a professional IELTS coach.

Create a personalized IELTS study plan.

Return ONLY valid JSON:
{
  "target_band": "$targetBand",
  "current_level": "$currentLevel",
  "duration_days": $days,
  "daily_time": "",
  "focus_areas": ["", "", ""],
  "weekly_plan": [
    {
      "week": 1,
      "reading": "",
      "listening": "",
      "writing": "",
      "speaking": ""
    }
  ],
  "tips": ["", "", ""]
}

Rules:
- Real IELTS preparation style
- Practical and simple
- No markdown
""";

    return _json(prompt);
  }

  // =========================================================
  // IELTS READING
  // =========================================================

  Future<Map<String, dynamic>> generateReadingTest({
    String level = "Band 6 to 7",
  }) async {
    final prompt = """
You are an IELTS Academic Reading test writer.

Create ONE IELTS Reading passage and questions.

Return ONLY valid JSON:
{
  "title": "",
  "passage": "",
  "time_limit_minutes": 20,
  "questions": [
    {
      "id": 1,
      "type": "mcq",
      "question": "",
      "options": ["A", "B", "C", "D"],
      "answer": "",
      "explanation": ""
    },
    {
      "id": 2,
      "type": "true_false_not_given",
      "question": "",
      "options": ["True", "False", "Not Given"],
      "answer": "",
      "explanation": ""
    }
  ]
}

Rules:
- Passage must be 500 to 700 words
- Include 5 MCQs
- Include 5 True False Not Given questions
- Academic IELTS style
- Level: $level
- No markdown
""";

    return _json(prompt);
  }

  Future<Map<String, dynamic>> checkReadingAnswers({
    required List<Map<String, dynamic>> questions,
    required Map<String, String> userAnswers,
  }) async {
    final prompt = """
You are an IELTS Reading examiner.

Check the user's answers.

Questions:
${jsonEncode(questions)}

User Answers:
${jsonEncode(userAnswers)}

Return ONLY valid JSON:
{
  "score": 0,
  "total": 0,
  "estimated_band": "",
  "results": [
    {
      "id": 1,
      "correct": true,
      "user_answer": "",
      "correct_answer": "",
      "explanation": ""
    }
  ],
  "advice": ""
}

Rules:
- Be accurate
- Simple English
- No markdown
""";

    return _json(prompt);
  }

  // =========================================================
  // IELTS LISTENING
  // =========================================================

  Future<Map<String, dynamic>> generateListeningTest({
    String section = "Section 1",
  }) async {
    final prompt = """
You are an IELTS Listening test writer.

Create IELTS Listening $section.

Return ONLY valid JSON:
{
  "section": "$section",
  "title": "",
  "audio_script": "",
  "time_limit_minutes": 10,
  "questions": [
    {
      "id": 1,
      "type": "mcq",
      "question": "",
      "options": ["A", "B", "C", "D"],
      "answer": "",
      "explanation": ""
    }
  ]
}

Rules:
- Make the audio script natural
- Section 1 should be daily conversation
- Section 2 should be monologue
- Section 3 should be academic conversation
- Section 4 should be academic lecture
- Create 10 questions
- Mix MCQ and fill in the blank
- No markdown
""";

    return _json(prompt);
  }

  Future<Map<String, dynamic>> checkListeningAnswers({
    required List<Map<String, dynamic>> questions,
    required Map<String, String> userAnswers,
  }) async {
    final prompt = """
You are an IELTS Listening examiner.

Check answers.

Questions:
${jsonEncode(questions)}

User Answers:
${jsonEncode(userAnswers)}

Return ONLY valid JSON:
{
  "score": 0,
  "total": 0,
  "estimated_band": "",
  "results": [
    {
      "id": 1,
      "correct": true,
      "user_answer": "",
      "correct_answer": "",
      "explanation": ""
    }
  ],
  "advice": ""
}
""";

    return _json(prompt);
  }

  // =========================================================
  // IELTS WRITING
  // =========================================================qwqfg

Future<String> generateWritingTopic(String taskType) async {
  final prompt = """
You are an IELTS examiner.

Generate ONE real IELTS Academic Writing Task $taskType question.

Rules:
- If Task 1, generate ONE of these: line graph, bar chart, pie chart, table, process diagram, or map
- If Task 2, generate opinion, discussion, advantage disadvantage, or problem solution essay
- Task 1 must require at least 150 words
- Task 2 must require at least 250 words
- Only return the question
- No explanation
""";

  return _text(prompt);
  
}
  Future<Map<String, dynamic>> evaluateWriting({
    required String text,
    required String taskType,
  }) async {
    final prompt = """
You are a certified IELTS Writing examiner.

Evaluate this IELTS Writing Task $taskType answer using official IELTS band descriptors.

Return ONLY valid JSON:
{
  "overall_band": "",
  "task_achievement": {
    "band": "",
    "feedback": ""
  },
  "coherence_cohesion": {
    "band": "",
    "feedback": ""
  },
  "lexical_resource": {
    "band": "",
    "feedback": ""
  },
  "grammar": {
    "band": "",
    "feedback": ""
  },
  "mistakes": ["", "", ""],
  "improved_version": "",
  "examiner_advice": ""
}

Rules:
- Be strict
- Give realistic band score from 0 to 9
- Do not give high band easily
- Mention grammar and vocabulary problems
- Simple English
- No markdown

Candidate Answer:
$text
""";

    return _json(prompt);
  }

  Future<String> generateWritingIdeas(String topic) async {
    final prompt = """
You are an IELTS Writing coach.

Give ideas for this IELTS essay topic:

$topic

Include:
1. Introduction idea
2. Main idea 1
3. Main idea 2
4. Example
5. Conclusion idea

Rules:
- Simple English
- IELTS style
- No markdown table
""";

    return _text(prompt);
  }

  Future<String> improveWriting(String text) async {
    final prompt = """
Improve this IELTS writing answer.

Rules:
- Keep the original meaning
- Improve grammar
- Improve vocabulary
- Improve coherence
- Make it Band 7 style
- No markdown

Answer:
$text
""";

    return _text(prompt);
  }

  // =========================================================
  // IELTS SPEAKING
  // =========================================================

  Future<Map<String, dynamic>> generateSpeakingTest() async {
    final prompt = """
You are an IELTS Speaking examiner.

Create a complete IELTS Speaking test.

Return ONLY valid JSON:
{
  "part1": {
    "topic": "",
    "questions": ["", "", "", ""]
  },
  "part2": {
    "cue_card": "",
    "points": ["", "", "", ""],
    "preparation_time_seconds": 60,
    "speaking_time_minutes": 2
  },
  "part3": {
    "questions": ["", "", "", ""]
  }
}

Rules:
- Real IELTS style
- Natural questions
- No markdown
""";

    return _json(prompt);
  }

  Future<Map<String, dynamic>> generateSpeakingTopic() async {
    final prompt = """
You are an IELTS Speaking examiner.

Generate ONE IELTS Speaking Part 2 cue card.

Return ONLY valid JSON:
{
  "topic": "",
  "points": ["", "", "", ""],
  "follow_up_questions": ["", "", ""]
}

Rules:
- Real IELTS style
- No markdown
""";

    return _json(prompt);
  }

  Future<Map<String, dynamic>> evaluateSpeaking({
    required String transcript,
    required int durationSeconds,
  }) async {
    final prompt = """
You are a certified IELTS Speaking examiner.

Evaluate this speaking transcript.

Return ONLY valid JSON:
{
  "overall_band": "",
  "fluency_coherence": {
    "band": "",
    "feedback": ""
  },
  "lexical_resource": {
    "band": "",
    "feedback": ""
  },
  "grammar": {
    "band": "",
    "feedback": ""
  },
  "pronunciation": {
    "band": "",
    "feedback": ""
  },
  "mistakes": ["", "", ""],
  "better_answer": "",
  "examiner_advice": ""
}

Rules:
- Be strict
- Realistic IELTS band
- Duration: $durationSeconds seconds
- Simple English
- No markdown

Transcript:
$transcript
""";

    return _json(prompt);
  }

  Future<List<String>> generateFollowUpQuestions(String topic) async {
    final prompt = """
Generate 5 IELTS Speaking Part 3 follow-up questions.

Topic:
$topic

Return ONLY valid JSON:
{
  "questions": ["", "", "", "", ""]
}
""";

    final data = await _json(prompt);
    return List<String>.from(data["questions"] ?? []);
  }

  // =========================================================
  // VOCABULARY / GRAMMAR
  // =========================================================

  Future<Map<String, dynamic>> generateVocabulary(String topic) async {
    final prompt = """
Generate IELTS vocabulary for topic: $topic

Return ONLY valid JSON:
{
  "topic": "$topic",
  "words": [
    {
      "word": "",
      "meaning": "",
      "example": "",
      "synonyms": ["", ""],
      "use_for": "writing/speaking"
    }
  ]
}

Rules:
- 15 IELTS-level words
- Simple meanings
- Good examples
- No markdown
""";

    return _json(prompt);
  }

  Future<Map<String, dynamic>> checkGrammar(String text) async {
    final prompt = """
You are an IELTS grammar checker.

Check this text.

Return ONLY valid JSON:
{
  "corrected_text": "",
  "mistakes": [
    {
      "wrong": "",
      "correct": "",
      "reason": ""
    }
  ],
  "grammar_score": "",
  "advice": ""
}

Text:
$text
""";

    return _json(prompt);
  }

  Future<String> feedback(String text, String category) async {
    final prompt = """
You are an expert IELTS English instructor.

Give detailed feedback.

Category: $category

Text:
$text

Include:
- Strengths
- Weaknesses
- Band improvement tips
- Better version if needed

Rules:
- Friendly tone
- Simple English
- No markdown table
""";

    return _text(prompt);
  }

  // =========================================================
  // MOCK TEST RESULT
  // =========================================================

  Future<Map<String, dynamic>> calculateOverallBand({
    required double listening,
    required double reading,
    required double writing,
    required double speaking,
  }) async {
    final average = (listening + reading + writing + speaking) / 4;

    double roundedBand;
    final decimal = average - average.floor();

    if (decimal < 0.25) {
      roundedBand = average.floorToDouble();
    } else if (decimal < 0.75) {
      roundedBand = average.floor() + 0.5;
    } else {
      roundedBand = average.ceilToDouble();
    }

    return {
      "listening": listening,
      "reading": reading,
      "writing": writing,
      "speaking": speaking,
      "average": average.toStringAsFixed(2),
      "overall_band": roundedBand.toStringAsFixed(1),
    };
  }
}