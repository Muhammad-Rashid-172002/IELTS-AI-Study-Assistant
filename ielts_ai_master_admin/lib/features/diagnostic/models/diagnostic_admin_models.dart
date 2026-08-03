import 'package:cloud_firestore/cloud_firestore.dart';

class DiagnosticQuestionModel {
  final String id;
  final String type;
  final String prompt;
  final String instruction;
  final Map<String, String> options;
  final List<String> acceptedAnswers;

  const DiagnosticQuestionModel({
    required this.id,
    required this.type,
    required this.prompt,
    required this.instruction,
    required this.options,
    required this.acceptedAnswers,
  });

  factory DiagnosticQuestionModel.empty() {
    return const DiagnosticQuestionModel(
      id: '',
      type: 'multiple_choice',
      prompt: '',
      instruction: '',
      options: {
        'A': '',
        'B': '',
        'C': '',
        'D': '',
      },
      acceptedAnswers: [],
    );
  }

  factory DiagnosticQuestionModel.fromMap(Map<String, dynamic> data) {
    final options = <String, String>{};

    if (data['options'] is Map) {
      for (final entry in (data['options'] as Map).entries) {
        options[entry.key.toString()] = entry.value.toString();
      }
    }

    return DiagnosticQuestionModel(
      id: (data['id'] ?? data['questionId'] ?? '').toString(),
      type: (data['type'] ?? 'multiple_choice').toString(),
      prompt: (data['prompt'] ?? data['question'] ?? '').toString(),
      instruction: (data['instruction'] ?? '').toString(),
      options: options,
      acceptedAnswers: data['acceptedAnswers'] is List
          ? (data['acceptedAnswers'] as List)
              .map((item) => item.toString())
              .toList()
          : [
              if (data['answer'] != null)
                data['answer'].toString(),
            ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'prompt': prompt,
      'instruction': instruction,
      'options': options,
      'acceptedAnswers': acceptedAnswers,
    };
  }

  DiagnosticQuestionModel copyWith({
    String? id,
    String? type,
    String? prompt,
    String? instruction,
    Map<String, String>? options,
    List<String>? acceptedAnswers,
  }) {
    return DiagnosticQuestionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      instruction: instruction ?? this.instruction,
      options: options ?? this.options,
      acceptedAnswers: acceptedAnswers ?? this.acceptedAnswers,
    );
  }
}

class SpeakingPromptModel {
  final String part;
  final String prompt;
  final String duration;

  const SpeakingPromptModel({
    required this.part,
    required this.prompt,
    required this.duration,
  });

  factory SpeakingPromptModel.empty() {
    return const SpeakingPromptModel(
      part: 'Part 1',
      prompt: '',
      duration: '30–45 seconds',
    );
  }

  factory SpeakingPromptModel.fromMap(Map<String, dynamic> data) {
    return SpeakingPromptModel(
      part: (data['part'] ?? 'Part 1').toString(),
      prompt: (data['prompt'] ?? '').toString(),
      duration: (data['duration'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'part': part,
        'prompt': prompt,
        'duration': duration,
      };

  SpeakingPromptModel copyWith({
    String? part,
    String? prompt,
    String? duration,
  }) {
    return SpeakingPromptModel(
      part: part ?? this.part,
      prompt: prompt ?? this.prompt,
      duration: duration ?? this.duration,
    );
  }
}

class DiagnosticTestAdminModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final String ieltsType;
  final int totalDurationMinutes;
  final String listeningTitle;
  final String listeningAudioUrl;
  final List<DiagnosticQuestionModel> listeningQuestions;
  final String readingPassageTitle;
  final String readingPassage;
  final List<DiagnosticQuestionModel> readingQuestions;
  final String writingTaskType;
  final String writingPrompt;
  final int writingMinimumWords;
  final int writingRecommendedMinutes;
  final List<SpeakingPromptModel> speakingPrompts;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final int generationProgress;
  final String generationStep;
  final String generationError;
  final String generationJobId;

  const DiagnosticTestAdminModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.ieltsType,
    required this.totalDurationMinutes,
    required this.listeningTitle,
    required this.listeningAudioUrl,
    required this.listeningQuestions,
    required this.readingPassageTitle,
    required this.readingPassage,
    required this.readingQuestions,
    required this.writingTaskType,
    required this.writingPrompt,
    required this.writingMinimumWords,
    required this.writingRecommendedMinutes,
    required this.speakingPrompts,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.generationProgress,
    required this.generationStep,
    required this.generationError,
    required this.generationJobId,
  });

  factory DiagnosticTestAdminModel.empty() {
    return const DiagnosticTestAdminModel(
      id: '',
      title: 'Academic Diagnostic Test',
      description: 'Four-skill IELTS diagnostic assessment.',
      status: 'draft',
      ieltsType: 'Academic',
      totalDurationMinutes: 30,
      listeningTitle: 'Listening Recording',
      listeningAudioUrl: '',
      listeningQuestions: [],
      readingPassageTitle: 'Reading Passage',
      readingPassage: '',
      readingQuestions: [],
      writingTaskType: 'Academic Task 1',
      writingPrompt: '',
      writingMinimumWords: 150,
      writingRecommendedMinutes: 20,
      speakingPrompts: [],
      createdAt: null,
      updatedAt: null,
      publishedAt: null,
      generationProgress: 0,
      generationStep: '',
      generationError: '',
      generationJobId: '',
    );
  }

  factory DiagnosticTestAdminModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final listening = data['listening'] is Map
        ? Map<String, dynamic>.from(data['listening'])
        : <String, dynamic>{};
    final reading = data['reading'] is Map
        ? Map<String, dynamic>.from(data['reading'])
        : <String, dynamic>{};
    final writing = data['writing'] is Map
        ? Map<String, dynamic>.from(data['writing'])
        : <String, dynamic>{};
    final speaking = data['speaking'] is Map
        ? Map<String, dynamic>.from(data['speaking'])
        : <String, dynamic>{};

    return DiagnosticTestAdminModel(
      id: doc.id,
      title: (data['title'] ?? 'Diagnostic Test').toString(),
      description: (data['description'] ?? '').toString(),
      status: (data['status'] ?? 'draft').toString(),
      ieltsType: (data['ieltsType'] ?? 'Academic').toString(),
      totalDurationMinutes:
          _int(data['totalDurationMinutes'], 30),
      listeningTitle:
          (listening['title'] ?? 'Listening Recording').toString(),
      listeningAudioUrl:
          (listening['audioUrl'] ?? '').toString(),
      listeningQuestions: _questionList(listening['questions']),
      readingPassageTitle:
          (reading['passageTitle'] ?? 'Reading Passage').toString(),
      readingPassage: (reading['passage'] ?? '').toString(),
      readingQuestions: _questionList(reading['questions']),
      writingTaskType:
          (writing['taskType'] ?? 'Academic Task 1').toString(),
      writingPrompt: (writing['prompt'] ?? '').toString(),
      writingMinimumWords:
          _int(writing['minimumWords'], 150),
      writingRecommendedMinutes:
          _int(writing['recommendedMinutes'], 20),
      speakingPrompts: speaking['prompts'] is List
          ? (speaking['prompts'] as List)
              .whereType<Map>()
              .map(
                (item) => SpeakingPromptModel.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      publishedAt: _date(data['publishedAt']),
      generationProgress: _int(data['generationProgress']),
      generationStep: (data['generationStep'] ?? '').toString(),
      generationError: (data['generationError'] ?? '').toString(),
      generationJobId: (data['generationJobId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'ieltsType': ieltsType,
      'totalDurationMinutes': totalDurationMinutes,
      'listening': {
        'title': listeningTitle,
        'audioUrl': listeningAudioUrl,
        'questions':
            listeningQuestions.map((item) => item.toMap()).toList(),
      },
      'reading': {
        'passageTitle': readingPassageTitle,
        'passage': readingPassage,
        'questions':
            readingQuestions.map((item) => item.toMap()).toList(),
      },
      'writing': {
        'taskType': writingTaskType,
        'prompt': writingPrompt,
        'minimumWords': writingMinimumWords,
        'recommendedMinutes': writingRecommendedMinutes,
      },
      'speaking': {
        'prompts':
            speakingPrompts.map((item) => item.toMap()).toList(),
      },
    };
  }

  int get totalQuestions =>
      listeningQuestions.length + readingQuestions.length;

  bool get isReadyToPublish {
    return title.trim().isNotEmpty &&
        listeningAudioUrl.trim().isNotEmpty &&
        listeningQuestions.isNotEmpty &&
        readingPassage.trim().isNotEmpty &&
        readingQuestions.isNotEmpty &&
        writingPrompt.trim().isNotEmpty &&
        speakingPrompts.isNotEmpty;
  }

  List<String> get validationIssues {
    final issues = <String>[];

    if (title.trim().isEmpty) issues.add('Test title is missing.');
    if (listeningAudioUrl.trim().isEmpty) {
      issues.add('Listening audio is missing.');
    }
    if (listeningQuestions.isEmpty) {
      issues.add('Listening questions are missing.');
    }
    if (readingPassage.trim().isEmpty) {
      issues.add('Reading passage is missing.');
    }
    if (readingQuestions.isEmpty) {
      issues.add('Reading questions are missing.');
    }
    if (writingPrompt.trim().isEmpty) {
      issues.add('Writing task prompt is missing.');
    }
    if (speakingPrompts.isEmpty) {
      issues.add('Speaking prompts are missing.');
    }

    return issues;
  }

  static List<DiagnosticQuestionModel> _questionList(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map(
          (item) => DiagnosticQuestionModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  static int _int(dynamic value, [int fallback = 0]) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
