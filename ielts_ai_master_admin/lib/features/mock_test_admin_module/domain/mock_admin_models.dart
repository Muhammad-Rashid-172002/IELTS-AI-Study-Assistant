import 'package:cloud_firestore/cloud_firestore.dart';

enum MockAdminTrack { academic, generalTraining }

enum MockAdminScope { fullMock, singleSkill }

enum MockAdminMode { practice, exam, computerDelivered }

enum MockAdminSkill { listening, reading, writing, speaking }

extension MockAdminTrackX on MockAdminTrack {
  String get value => switch (this) {
        MockAdminTrack.academic => 'academic',
        MockAdminTrack.generalTraining => 'general_training',
      };

  String get label => switch (this) {
        MockAdminTrack.academic => 'Academic',
        MockAdminTrack.generalTraining => 'General Training',
      };
}

extension MockAdminScopeX on MockAdminScope {
  String get value => switch (this) {
        MockAdminScope.fullMock => 'full_mock',
        MockAdminScope.singleSkill => 'single_skill',
      };

  String get label => switch (this) {
        MockAdminScope.fullMock => 'Full Mock',
        MockAdminScope.singleSkill => 'Single Skill',
      };
}

extension MockAdminModeX on MockAdminMode {
  String get value => switch (this) {
        MockAdminMode.practice => 'practice',
        MockAdminMode.exam => 'exam',
        MockAdminMode.computerDelivered => 'computer_delivered',
      };

  String get label => switch (this) {
        MockAdminMode.practice => 'Practice Mode',
        MockAdminMode.exam => 'Exam Mode',
        MockAdminMode.computerDelivered =>
          'Computer-delivered Simulation',
      };
}

extension MockAdminSkillX on MockAdminSkill {
  String get value => switch (this) {
        MockAdminSkill.listening => 'listening',
        MockAdminSkill.reading => 'reading',
        MockAdminSkill.writing => 'writing',
        MockAdminSkill.speaking => 'speaking',
      };

  String get label => switch (this) {
        MockAdminSkill.listening => 'Listening',
        MockAdminSkill.reading => 'Reading',
        MockAdminSkill.writing => 'Writing',
        MockAdminSkill.speaking => 'Speaking',
      };

  int get targetCount => switch (this) {
        MockAdminSkill.listening => 40,
        MockAdminSkill.reading => 40,
        MockAdminSkill.writing => 2,
        MockAdminSkill.speaking => 3,
      };

  int get durationMinutes => switch (this) {
        MockAdminSkill.listening => 30,
        MockAdminSkill.reading => 60,
        MockAdminSkill.writing => 60,
        MockAdminSkill.speaking => 14,
      };
}


class MockAdminTest {
  final String id;
  final String title;
  final String description;
  final MockAdminTrack track;
  final MockAdminScope scope;
  final MockAdminMode mode;
  final String difficulty;
  final String status;
  final bool isPublished;
  final bool isFeatured;
  final bool isReady;
  final List<MockAdminSkill> skills;
  final int totalDurationMinutes;
  final int totalQuestions;
  final int totalRequired;
  final int totalGenerated;
  final int totalFailed;
  final double generationProgress;
  final Map<String, int> requiredBySkill;
  final Map<String, int> generatedBySkill;
  final Map<String, int> failedBySkill;
  final int attemptCount;
  final double averageBand;
  final double completionRate;
  final String generationError;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? readyAt;
  final DateTime? publishedAt;

  const MockAdminTest({
    required this.id,
    required this.title,
    required this.description,
    required this.track,
    required this.scope,
    required this.mode,
    required this.difficulty,
    required this.status,
    required this.isPublished,
    required this.isFeatured,
    required this.isReady,
    required this.skills,
    required this.totalDurationMinutes,
    required this.totalQuestions,
    required this.totalRequired,
    required this.totalGenerated,
    required this.totalFailed,
    required this.generationProgress,
    required this.requiredBySkill,
    required this.generatedBySkill,
    required this.failedBySkill,
    required this.attemptCount,
    required this.averageBand,
    required this.completionRate,
    required this.generationError,
    required this.createdAt,
    required this.updatedAt,
    required this.readyAt,
    required this.publishedAt,
  });

  factory MockAdminTest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    final trackValue = (data['track'] ?? 'academic').toString();
    final scopeValue = (data['scope'] ?? 'full_mock').toString();
    final modeValue =
        (data['mode'] ?? 'computer_delivered').toString();
    final skills = _skills(data['skills']);

    final requiredBySkill = _intMap(
      data['requiredBySkill'],
      fallback: {
        for (final skill in skills) skill.value: skill.targetCount,
      },
    );
    final generatedBySkill = _intMap(data['generatedBySkill']);
    final failedBySkill = _intMap(data['failedBySkill']);

    final totalRequired = _int(
      data['totalRequired'],
      requiredBySkill.values.fold(0, (a, b) => a + b),
    );
    final totalGenerated = _int(
      data['totalGenerated'],
      generatedBySkill.values.fold(0, (a, b) => a + b),
    );

    return MockAdminTest(
      id: doc.id,
      title: (data['title'] ?? 'Untitled Mock Test').toString(),
      description: (data['description'] ?? '').toString(),
      track: trackValue == 'general_training'
          ? MockAdminTrack.generalTraining
          : MockAdminTrack.academic,
      scope: scopeValue == 'single_skill'
          ? MockAdminScope.singleSkill
          : MockAdminScope.fullMock,
      mode: switch (modeValue) {
        'practice' => MockAdminMode.practice,
        'exam' => MockAdminMode.exam,
        _ => MockAdminMode.computerDelivered,
      },
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      status: (data['status'] ?? 'draft').toString(),
      isPublished: data['isPublished'] == true,
      isFeatured: data['isFeatured'] == true,
      isReady: data['isReady'] == true,
      skills: skills,
      totalDurationMinutes:
          _int(data['totalDurationMinutes'], 164),
      totalQuestions: _int(data['totalQuestions'], totalRequired),
      totalRequired: totalRequired,
      totalGenerated: totalGenerated,
      totalFailed: _int(
        data['totalFailed'],
        failedBySkill.values.fold(0, (a, b) => a + b),
      ),
      generationProgress: _double(
        data['generationProgress'],
        totalRequired == 0
            ? 0
            : (totalGenerated / totalRequired * 100),
      ),
      requiredBySkill: requiredBySkill,
      generatedBySkill: generatedBySkill,
      failedBySkill: failedBySkill,
      attemptCount: _int(data['attemptCount']),
      averageBand: _double(data['averageBand']),
      completionRate: _double(data['completionRate']),
      generationError: (data['generationError'] ?? '').toString(),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      readyAt: _date(data['readyAt']),
      publishedAt: _date(data['publishedAt']),
    );
  }

  int requiredFor(MockAdminSkill skill) =>
      requiredBySkill[skill.value] ?? skill.targetCount;

  int generatedFor(MockAdminSkill skill) =>
      generatedBySkill[skill.value] ?? 0;

  int failedFor(MockAdminSkill skill) =>
      failedBySkill[skill.value] ?? 0;

  bool skillComplete(MockAdminSkill skill) =>
      generatedFor(skill) >= requiredFor(skill);

  bool get canPublish => isReady && !isPublished;

  static List<MockAdminSkill> _skills(dynamic value) {
    if (value is! List) return MockAdminSkill.values;

    return value.map((item) {
      return switch (item.toString()) {
        'listening' => MockAdminSkill.listening,
        'reading' => MockAdminSkill.reading,
        'writing' => MockAdminSkill.writing,
        'speaking' => MockAdminSkill.speaking,
        _ => MockAdminSkill.listening,
      };
    }).toSet().toList();
  }

  static Map<String, int> _intMap(
    dynamic value, {
    Map<String, int> fallback = const {},
  }) {
    if (value is! Map) return Map<String, int>.from(fallback);

    return Map<String, dynamic>.from(value).map(
      (key, raw) => MapEntry(key, _int(raw)),
    );
  }

  static int _int(dynamic value, [int fallback = 0]) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _double(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _date(dynamic value) {
    return value is Timestamp ? value.toDate() : null;
  }
}

class MockAdminQuestion {
  final String id;
  final MockAdminTrack track;
  final MockAdminSkill skill;
  final int number;
  final String sectionId;
  final String type;
  final String prompt;
  final String passage;
  final String audioUrl;
  final List<String> options;
  final List<String> correctAnswers;
  final int marks;
  final String difficulty;
  final String status;
  final Map<String, dynamic> metadata;

  const MockAdminQuestion({
    required this.id,
    required this.track,
    required this.skill,
    required this.number,
    required this.sectionId,
    required this.type,
    required this.prompt,
    required this.passage,
    required this.audioUrl,
    required this.options,
    required this.correctAnswers,
    required this.marks,
    required this.difficulty,
    required this.status,
    required this.metadata,
  });

  factory MockAdminQuestion.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required MockAdminTrack track,
    required MockAdminSkill skill,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};

    return MockAdminQuestion(
      id: doc.id,
      track: track,
      skill: skill,
      number: _int(data['number']),
      sectionId: (data['sectionId'] ?? '').toString(),
      type: (data['type'] ?? 'short_answer').toString(),
      prompt: (data['prompt'] ?? '').toString(),
      passage: (data['passage'] ?? '').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
      options: _strings(data['options']),
      correctAnswers: _strings(data['correctAnswers']),
      marks: _int(data['marks'], 1),
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      status: (data['status'] ?? 'draft').toString(),
      metadata: data['metadata'] is Map
          ? Map<String, dynamic>.from(data['metadata'])
          : const {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'number': number,
      'sectionId': sectionId.trim(),
      'type': type,
      'prompt': prompt.trim(),
      'passage': passage.trim(),
      'audioUrl': audioUrl.trim(),
      'options': options,
      'correctAnswers': correctAnswers,
      'marks': marks,
      'difficulty': difficulty,
      'status': status,
      'metadata': metadata,
    };
  }

  static int _int(dynamic value, [int fallback = 0]) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }
}
