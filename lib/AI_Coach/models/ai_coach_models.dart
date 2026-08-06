import 'package:cloud_firestore/cloud_firestore.dart';

class AiCoachMessage {
  final String id;
  final String role;
  final String text;
  final DateTime createdAt;
  final String intent;
  final List<String> suggestions;

  const AiCoachMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.intent = '',
    this.suggestions = const [],
  });

  bool get isUser => role == 'user';

  factory AiCoachMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return AiCoachMessage(
      id: doc.id,
      role: (data['role'] ?? 'assistant').toString(),
      text: (data['text'] ?? '').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      intent: (data['intent'] ?? '').toString(),
      suggestions: data['suggestions'] is List
          ? (data['suggestions'] as List)
                .map((item) => item.toString())
                .toList()
          : const [],
    );
  }
}

class AiCoachProfile {
  final double overallBand;
  final double targetBand;
  final int streak;
  final String weakestSkill;
  final String strongestSkill;
  final Map<String, double> skillBands;
  final Map<String, dynamic> weakQuestionTypes;
  final int completedLessons;
  final int completedPractice;
  final int completedMocks;

  const AiCoachProfile({
    required this.overallBand,
    required this.targetBand,
    required this.streak,
    required this.weakestSkill,
    required this.strongestSkill,
    required this.skillBands,
    required this.weakQuestionTypes,
    required this.completedLessons,
    required this.completedPractice,
    required this.completedMocks,
  });

  factory AiCoachProfile.fromMap(Map<String, dynamic> data) {
    return AiCoachProfile(
      overallBand: _double(data['overallBand']),
      targetBand: _double(data['targetBand'], 7),
      streak: _int(data['streak']),
      weakestSkill: (data['weakestSkill'] ?? 'Reading').toString(),
      strongestSkill: (data['strongestSkill'] ?? 'Listening').toString(),
      skillBands: data['skillBands'] is Map
          ? Map<String, dynamic>.from(
              data['skillBands'],
            ).map((key, value) => MapEntry(key, _double(value)))
          : const {},
      weakQuestionTypes: data['weakQuestionTypes'] is Map
          ? Map<String, dynamic>.from(data['weakQuestionTypes'])
          : const {},
      completedLessons: _int(data['completedLessons']),
      completedPractice: _int(data['completedPractice']),
      completedMocks: _int(data['completedMocks']),
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
}
