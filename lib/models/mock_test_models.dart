import 'package:cloud_firestore/cloud_firestore.dart';

enum MockTrack { academic, generalTraining }

enum MockScope { fullMock, singleSkill }

enum MockMode { practice, exam, computerDelivered }

enum MockSkill { listening, reading, writing, speaking }

enum MockQuestionStatus { unanswered, answered, flagged }

extension MockTrackX on MockTrack {
  String get value => switch (this) {
    MockTrack.academic => 'academic',
    MockTrack.generalTraining => 'general_training',
  };

  String get label => switch (this) {
    MockTrack.academic => 'Academic',
    MockTrack.generalTraining => 'General Training',
  };
}

extension MockScopeX on MockScope {
  String get value => switch (this) {
    MockScope.fullMock => 'full_mock',
    MockScope.singleSkill => 'single_skill',
  };

  String get label => switch (this) {
    MockScope.fullMock => 'Full Mock',
    MockScope.singleSkill => 'Single Skill Mock',
  };
}

extension MockModeX on MockMode {
  String get value => switch (this) {
    MockMode.practice => 'practice',
    MockMode.exam => 'exam',
    MockMode.computerDelivered => 'computer_delivered',
  };

  String get label => switch (this) {
    MockMode.practice => 'Practice Mode',
    MockMode.exam => 'Exam Mode',
    MockMode.computerDelivered => 'Computer-delivered Simulation',
  };
}

extension MockSkillX on MockSkill {
  String get value => switch (this) {
    MockSkill.listening => 'listening',
    MockSkill.reading => 'reading',
    MockSkill.writing => 'writing',
    MockSkill.speaking => 'speaking',
  };

  String get label => switch (this) {
    MockSkill.listening => 'Listening',
    MockSkill.reading => 'Reading',
    MockSkill.writing => 'Writing',
    MockSkill.speaking => 'Speaking',
  };

  int get durationMinutes => switch (this) {
    MockSkill.listening => 30,
    MockSkill.reading => 60,
    MockSkill.writing => 60,
    MockSkill.speaking => 14,
  };

  int get questionCount => switch (this) {
    MockSkill.listening => 40,
    MockSkill.reading => 40,
    MockSkill.writing => 2,
    MockSkill.speaking => 3,
  };
}

class MockTestConfig {
  final String mockTestId;
  final String mockTitle;
  final MockTrack track;
  final MockScope scope;
  final MockMode mode;
  final MockSkill? singleSkill;
  final String difficulty;
  final DateTime testDate;
  final double targetBand;
  final int cycleNumber;
  final int cycleTotalTests;

  const MockTestConfig({
    this.mockTestId = '',
    this.mockTitle = '',
    required this.track,
    required this.scope,
    required this.mode,
    required this.singleSkill,
    required this.difficulty,
    required this.testDate,
    required this.targetBand,
    this.cycleNumber = 1,
    this.cycleTotalTests = 1,
  });

  List<MockSkill> get skills {
    if (scope == MockScope.fullMock) {
      return MockSkill.values;
    }

    return [singleSkill ?? MockSkill.listening];
  }

  int get totalDurationMinutes {
    return skills.fold(0, (total, skill) => total + skill.durationMinutes);
  }

  Map<String, dynamic> toMap() {
    return {
      'mockTestId': mockTestId,
      'mockTitle': mockTitle,
      'track': track.value,
      'scope': scope.value,
      'mode': mode.value,
      'singleSkill': singleSkill?.value,
      'difficulty': difficulty,
      'testDate': Timestamp.fromDate(testDate),
      'targetBand': targetBand,
      'cycleNumber': cycleNumber,
      'cycleTotalTests': cycleTotalTests,
      'skills': skills.map((skill) => skill.value).toList(),
      'totalDurationMinutes': totalDurationMinutes,
    };
  }
}

class PublishedMockTest {
  final String id;
  final String title;
  final String description;
  final MockTrack track;
  final MockScope scope;
  final MockMode mode;
  final String difficulty;
  final List<MockSkill> skills;
  final int totalDurationMinutes;
  final int totalQuestions;

  const PublishedMockTest({
    required this.id,
    required this.title,
    required this.description,
    required this.track,
    required this.scope,
    required this.mode,
    required this.difficulty,
    required this.skills,
    required this.totalDurationMinutes,
    required this.totalQuestions,
  });

  factory PublishedMockTest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    MockSkill parseSkill(String value) => switch (value) {
      'reading' => MockSkill.reading,
      'writing' => MockSkill.writing,
      'speaking' => MockSkill.speaking,
      _ => MockSkill.listening,
    };

    final skills = data['skills'] is List
        ? (data['skills'] as List)
              .map((value) => parseSkill(value.toString()))
              .toSet()
              .toList()
        : MockSkill.values;

    return PublishedMockTest(
      id: doc.id,
      title: (data['title'] ?? 'IELTS Mock Test').toString(),
      description: (data['description'] ?? '').toString(),
      track: data['track'] == 'general_training'
          ? MockTrack.generalTraining
          : MockTrack.academic,
      scope: data['scope'] == 'single_skill'
          ? MockScope.singleSkill
          : MockScope.fullMock,
      mode: switch ((data['mode'] ?? '').toString()) {
        'practice' => MockMode.practice,
        'exam' => MockMode.exam,
        _ => MockMode.computerDelivered,
      },
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      skills: skills,
      totalDurationMinutes:
          (data['totalDurationMinutes'] as num?)?.round() ?? 164,
      totalQuestions: (data['totalQuestions'] as num?)?.round() ?? 85,
    );
  }
}

class MockQuestion {
  final String id;
  final MockSkill skill;
  final String sectionId;
  final int number;
  final String type;
  final String prompt;
  final String passage;
  final String audioUrl;
  final List<String> options;
  final List<String> correctAnswers;
  final int marks;
  final Map<String, dynamic> metadata;

  const MockQuestion({
    required this.id,
    required this.skill,
    required this.sectionId,
    required this.number,
    required this.type,
    required this.prompt,
    required this.passage,
    required this.audioUrl,
    required this.options,
    required this.correctAnswers,
    required this.marks,
    required this.metadata,
  });

  factory MockQuestion.fromMap(
    Map<String, dynamic> data, {
    required String id,
    required MockSkill skill,
  }) {
    return MockQuestion(
      id: id,
      skill: skill,
      sectionId: (data['sectionId'] ?? '').toString(),
      number: _asInt(data['number']),
      type: (data['type'] ?? 'short_answer').toString(),
      prompt: (data['prompt'] ?? '').toString(),
      passage: (data['passage'] ?? '').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
      options: _strings(data['options']),
      correctAnswers: _strings(data['correctAnswers']),
      marks: _asInt(data['marks'], 1),
      metadata: data['metadata'] is Map
          ? Map<String, dynamic>.from(data['metadata'])
          : const {},
    );
  }

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }
}

class MockAnswer {
  final String questionId;
  final dynamic value;
  final bool flagged;
  final DateTime updatedAt;

  const MockAnswer({
    required this.questionId,
    required this.value,
    required this.flagged,
    required this.updatedAt,
  });

  bool get isAnswered {
    if (value == null) return false;
    if (value is String) return value.toString().trim().isNotEmpty;
    if (value is List) return (value as List).isNotEmpty;
    return true;
  }

  MockAnswer copyWith({dynamic value, bool? flagged, DateTime? updatedAt}) {
    return MockAnswer(
      questionId: questionId,
      value: value ?? this.value,
      flagged: flagged ?? this.flagged,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'value': value,
      'flagged': flagged,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class MockSkillResult {
  final MockSkill skill;
  final double band;
  final int rawScore;
  final int totalMarks;
  final double accuracy;
  final int timeSpentSeconds;
  final Map<String, dynamic> criteria;
  final Map<String, double> questionTypeAccuracy;

  const MockSkillResult({
    required this.skill,
    required this.band,
    required this.rawScore,
    required this.totalMarks,
    required this.accuracy,
    required this.timeSpentSeconds,
    required this.criteria,
    required this.questionTypeAccuracy,
  });

  factory MockSkillResult.fromMap(Map<String, dynamic> data, MockSkill skill) {
    return MockSkillResult(
      skill: skill,
      band: _asDouble(data['band']),
      rawScore: _asInt(data['rawScore']),
      totalMarks: _asInt(data['totalMarks']),
      accuracy: _asDouble(data['accuracy']),
      timeSpentSeconds: _asInt(data['timeSpentSeconds']),
      criteria: data['criteria'] is Map
          ? Map<String, dynamic>.from(data['criteria'])
          : const {},
      questionTypeAccuracy: data['questionTypeAccuracy'] is Map
          ? Map<String, dynamic>.from(
              data['questionTypeAccuracy'],
            ).map((key, value) => MapEntry(key, _asDouble(value)))
          : const {},
    );
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class MockFinalResult {
  final String attemptId;
  final double overallBand;
  final double targetBand;
  final double targetGap;
  final List<MockSkillResult> skillResults;
  final List<String> strengths;
  final List<String> weaknesses;
  final DateTime suggestedNextMockDate;
  final List<Map<String, dynamic>> sevenDayPlan;

  const MockFinalResult({
    required this.attemptId,
    required this.overallBand,
    required this.targetBand,
    required this.targetGap,
    required this.skillResults,
    required this.strengths,
    required this.weaknesses,
    required this.suggestedNextMockDate,
    required this.sevenDayPlan,
  });
}
