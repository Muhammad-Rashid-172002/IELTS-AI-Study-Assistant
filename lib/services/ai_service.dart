import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';

class AIService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
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
    } catch (_) {
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
          return await request().timeout(const Duration(seconds: 90));
        } catch (e) {
          attempts++;
          final error = e.toString();

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
    final output = await _callProxy(prompt: prompt, purpose: 'coach_text');
    return _clean(output);
  }

  Future<Map<String, dynamic>> _json(String prompt) async {
    final output = await _callProxy(prompt: prompt, purpose: 'coach_json');
    return _safeJson(output);
  }

  Future<String> _callProxy({
    required String prompt,
    required String purpose,
    String? imageBase64,
    String? imageMimeType,
  }) async {
    return _safeCall(() async {
      final response = await _functions.httpsCallable('legacyAiAssist').call({
        'purpose': purpose,
        'prompt': prompt,
        if (imageBase64 != null) 'imageBase64': imageBase64,
        if (imageMimeType != null) 'imageMimeType': imageMimeType,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      return (data['text'] ?? '').toString();
    });
  }

  // =========================================================
  // IELTS HOME / DIAGNOSTIC
  // =========================================================

  Future<Map<String, dynamic>> generateStudyPlan({
    required String targetBand,
    required String currentLevel,
    required int days,
  }) async {
    final prompt =
        """
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
- Original IELTS-style preparation content
- Practical and simple
- No markdown
""";

    return _json(prompt);
  }

  // =========================================================
  // IELTS READING
  // =========================================================

  Future<Map<String, dynamic>> generateReadingTest() async {
    final prompt = """
You are an IELTS Academic Reading examiner.

Generate ONE realistic IELTS Academic Reading passage and mixed questions.

Return ONLY valid JSON:
{
  "title": "",
  "passage": "",
  "questions": [
    {
      "type": "multiple_choice",
      "question": "",
      "options": ["A", "B", "C", "D"],
      "answer": "",
      "explanation": ""
    },
    {
      "type": "true_false_not_given",
      "question": "",
      "options": ["True", "False", "Not Given"],
      "answer": "",
      "explanation": ""
    },
    {
      "type": "yes_no_not_given",
      "question": "",
      "options": ["Yes", "No", "Not Given"],
      "answer": "",
      "explanation": ""
    },
    {
      "type": "sentence_completion",
      "question": "",
      "answer": "",
      "explanation": ""
    },
    {
      "type": "short_answer",
      "question": "",
      "answer": "",
      "explanation": ""
    }
  ]
}

Rules:
- Passage 600 to 900 words
- Academic IELTS style
- Create 10 questions total
- Mix question types
- MCQ must have options
- True False Not Given must have options
- Yes No Not Given must have options
- Completion and short answer have no options
- No markdown
""";

    return _json(prompt);
  }

  Future<Map<String, dynamic>> checkReadingAnswers({
    required List<Map<String, dynamic>> questions,
    required Map<String, String> userAnswers,
  }) async {
    final prompt =
        """
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

  Future<Map<String, dynamic>> generateListeningTest() async {
    final prompt = """
You are an independent IELTS listening practice-content writer.

Create an original IELTS-style Listening practice test.

Return ONLY valid JSON:

{
  "part1": {
    "title": "",
    "audio_script": "",
    "questions": [
      {
        "type": "form_completion",
        "question": "",
        "answer": ""
      }
    ]
  },

  "part2": {
    "title": "",
    "audio_script": "",
    "questions": [
      {
        "type": "multiple_choice",
        "question": "",
        "options": ["A", "B", "C"],
        "answer": ""
      }
    ]
  },

  "part3": {
    "title": "",
    "audio_script": "",
    "questions": [
      {
        "type": "matching",
        "question": "",
        "options": ["A", "B", "C"],
        "answer": ""
      }
    ]
  },

  "part4": {
    "title": "",
    "audio_script": "",
    "questions": [
      {
        "type": "note_completion",
        "question": "",
        "answer": ""
      }
    ]
  }
}

Rules:
- IELTS-style listening format without copying published test content
- British English
- Natural conversations
- Include different IELTS question types
- Use realistic names and places
- No markdown
""";

    return _json(prompt);
  }

  Future<Map<String, dynamic>> checkListeningAnswers({
    required List<Map<String, dynamic>> questions,
    required Map<String, String> userAnswers,
  }) async {
    final prompt =
        """
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
  // =========================================================

  Future<String> generateWritingTopic(String taskType) async {
    final prompt =
        """
You are an independent IELTS practice-content writer.

Generate ONE original IELTS-style Academic Writing Task $taskType practice question.

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
    final isTask1 = taskType == "1";

    final prompt =
        """
You are an independent IELTS writing practice evaluator.

Use the publicly described IELTS Writing assessment criteria as a reference.

Strictly evaluate this IELTS Writing Task $taskType response.

${isTask1 ? """
TASK 1 CRITERIA:
1. Task Achievement
2. Coherence and Cohesion
3. Lexical Resource
4. Grammatical Range and Accuracy
""" : """
TASK 2 CRITERIA:
1. Task Response
2. Coherence and Cohesion
3. Lexical Resource
4. Grammatical Range and Accuracy
"""}

IMPORTANT RULES:
- Be a strict practice evaluator
- Give realistic IELTS band scores
- Do NOT give high bands easily
- Penalize grammar mistakes
- Penalize weak vocabulary
- Penalize missing overview in Task 1
- Penalize weak opinion/development in Task 2
- Penalize essays below required word count
- Mention specific weaknesses
- Mention strengths
- Give actionable improvement tips
- Use IELTS-style feedback
- Detect repetitive vocabulary
- Detect unnatural or AI-like writing
- Mention if ideas are underdeveloped
- Mention if examples are weak
- Mention if paragraphing is weak
- Suggest advanced academic vocabulary
- Suggest better linking words
- Return short but useful feedback
- Return ONLY valid JSON
- Do NOT use markdown
- Do NOT add explanation outside JSON

Return ONLY valid JSON in this exact structure:

{
  "overall_band": "6.5",

  "band_summary": "",

  "${isTask1 ? "task_achievement" : "task_response"}": {
    "band": "6.0",
    "feedback": ""
  },

  "coherence_cohesion": {
    "band": "6.0",
    "feedback": ""
  },

  "lexical_resource": {
    "band": "6.0",
    "feedback": ""
  },

  "grammar": {
    "band": "6.0",
    "feedback": ""
  },

  "strengths": [
    "",
    ""
  ],

  "mistakes": [
    "",
    "",
    ""
  ],

  "vocabulary_suggestions": [
    {
      "basic": "",
      "advanced": ""
    },
    {
      "basic": "",
      "advanced": ""
    }
  ],

  "linking_words_suggestions": [
    "",
    "",
    ""
  ],

  "grammar_mistakes_count": "0",

  "naturalness_score": "0",

  "cefr_level": "",

  "time_management": "",

  "improved_version": "",

  "examiner_advice": "",

  "final_tips": [
    "",
    ""
  ]
}

Candidate Response:
$text
""";

    return _json(prompt);
  }

  Future<String> generateWritingIdeas(String topic) async {
    final prompt =
        """
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
    final prompt =
        """
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

  Future<Map<String, dynamic>> analyzeWritingTask1Image(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await _callProxy(
      purpose: 'writing_visual_analysis',
      prompt: """
You are an IELTS Writing Task 1 examiner.

Analyze the uploaded chart/graph/table/map/process image.

Return ONLY valid JSON:

{
  "main_trends":"",
  "highest_value":"",
  "lowest_value":"",
  "overview":"",
  "band9_sample":""
}
""",
      imageBase64: base64Image,
      imageMimeType: 'image/jpeg',
    );
    return _safeJson(response);
  }

  // =========================================================
  // IELTS SPEAKING
  // =========================================================
  Future<Map<String, dynamic>> generateSpeakingTest() async {
    final prompt = """
You are an independent IELTS speaking practice-content writer.

Create a complete IELTS Speaking test.

Return ONLY valid JSON:
{
  "part1": {
    "topic": "",
    "questions": ["", "", "", "", ""]
  },
  "part2": {
    "cue_card": "",
    "points": ["", "", "", ""],
    "preparation_time_seconds": 60,
    "speaking_time_minutes": 2
  },
  "part3": {
    "questions": ["", "", "", "", ""]
  }
}

Rules:
- Original IELTS-style Speaking practice format
- Part 1 must be simple personal questions
- Part 2 must be a cue card with 4 bullet points
- Part 3 must be deeper discussion questions related to Part 2
- Natural examiner language
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
  "follow_up_questions": ["", "", "", ""]
}

Rules:
- Original IELTS-style Part 2 practice cue card
- Topic should be common IELTS topic
- Points must start with: what, when/where, why, how
- Follow-up questions should be IELTS Part 3 style
- No markdown
""";

    return _json(prompt);
  }

  Future<Map<String, dynamic>> evaluateSpeaking({
    required String transcript,
    required int durationSeconds,
  }) async {
    final prompt =
        """
You are an independent IELTS speaking practice evaluator.

Use the publicly described IELTS Speaking assessment criteria as a reference.

Evaluate the candidate based on these 4 criteria:
1. Fluency and Coherence
2. Lexical Resource
3. Grammatical Range and Accuracy
4. Pronunciation

Important:
- Be strict and realistic
- Do not give high bands easily
- Penalize very short answers
- Penalize repetition, hesitation, weak vocabulary, grammar mistakes
- If transcript is too short, band should be low
- Mention strengths and weaknesses
- Give actionable improvement advice
- Since this is transcript-based, pronunciation must be estimated from clarity, naturalness, and speech flow
- Mention that pronunciation is estimated
- Suggest how to improve fluency
- Suggest how to improve pronunciation
- Give a better improved sample answer
- Detect unnatural or robotic speaking style
- Return ONLY valid JSON
- Do NOT use markdown
- Do NOT add explanation outside JSON

Return ONLY valid JSON in this exact structure:
{
  "overall_band": "6.0",

  "fluency_coherence": {
    "band": "6.0",
    "feedback": ""
  },

  "lexical_resource": {
    "band": "6.0",
    "feedback": ""
  },

  "grammar": {
    "band": "6.0",
    "feedback": ""
  },

  "pronunciation": {
    "band": "6.0",
    "feedback": ""
  },

  "strengths": "",
  "mistakes": "",
  "pronunciation_tips": "",
  "fluency_tips": "",
  "improved_answer": "",
  "examiner_advice": ""
}

Speaking duration: $durationSeconds seconds

Candidate transcript:
$transcript
""";

    return _json(prompt);
  }

  Future<List<String>> generateFollowUpQuestions(String topic) async {
    final prompt =
        """
You are an IELTS Speaking examiner.

Generate 5 IELTS Speaking Part 3 follow-up questions.

Topic:
$topic

Return ONLY valid JSON:
{
  "questions": ["", "", "", "", ""]
}

Rules:
- Questions should be deeper and opinion-based
- Use an original IELTS-style Part 3 discussion format
- No markdown
""";

    final data = await _json(prompt);
    return List<String>.from(data["questions"] ?? []);
  }
  // =========================================================
  // VOCABULARY / GRAMMAR
  // =========================================================

  Future<Map<String, dynamic>> generateVocabulary(String topic) async {
    final prompt =
        """
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
    final prompt =
        """
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
    final prompt =
        """
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
