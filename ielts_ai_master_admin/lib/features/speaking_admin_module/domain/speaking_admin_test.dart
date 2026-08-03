import 'package:cloud_firestore/cloud_firestore.dart';

class SpeakingAdminTest {
  final String id;
  final String title;
  final String description;
  final String mode;
  final String accent;
  final String difficulty;
  final String status;
  final bool isPublished;
  final double qualityScore;
  final int estimatedDurationSeconds;
  final List<Map<String, dynamic>> parts;
  final Map<String, dynamic> dailyChallenge;
  final Map<String, dynamic> pronunciationPractice;
  final Map<String, dynamic> fluencyTraining;
  final List<String> evaluationFocus;
  final String modelAudioUrl;
  final String modelAudioStoragePath;
  final String modelAudioStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SpeakingAdminTest({
    required this.id,
    required this.title,
    required this.description,
    required this.mode,
    required this.accent,
    required this.difficulty,
    required this.status,
    required this.isPublished,
    required this.qualityScore,
    required this.estimatedDurationSeconds,
    required this.parts,
    required this.dailyChallenge,
    required this.pronunciationPractice,
    required this.fluencyTraining,
    required this.evaluationFocus,
    required this.modelAudioUrl,
    required this.modelAudioStoragePath,
    required this.modelAudioStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SpeakingAdminTest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return SpeakingAdminTest(
      id: doc.id,
      title: (data['title'] ?? 'Untitled Speaking Test').toString(),
      description: (data['description'] ?? '').toString(),
      mode: (data['mode'] ?? 'part_1').toString(),
      accent: (data['accent'] ?? 'British').toString(),
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      status: (data['status'] ?? 'draft').toString(),
      isPublished: data['isPublished'] == true,
      qualityScore: _asDouble(data['qualityScore']),
      estimatedDurationSeconds:
          _asInt(data['estimatedDurationSeconds'], 600),
      parts: _mapList(data['parts']),
      dailyChallenge: _map(data['dailyChallenge']),
      pronunciationPractice: _map(data['pronunciationPractice']),
      fluencyTraining: _map(data['fluencyTraining']),
      evaluationFocus: _stringList(data['evaluationFocus']),
      modelAudioUrl: (data['modelAudioUrl'] ?? '').toString(),
      modelAudioStoragePath:
          (data['modelAudioStoragePath'] ?? '').toString(),
      modelAudioStatus:
          (data['modelAudioStatus'] ?? 'not_requested').toString(),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  String get modeLabel => switch (mode) {
        'ai_partner' => 'AI Speaking Partner',
        'full_test' => 'Full Speaking Test',
        'part_1' => 'Part 1 Practice',
        'part_2' => 'Part 2 Cue Cards',
        'part_3' => 'Part 3 Discussion',
        'pronunciation' => 'Pronunciation Practice',
        'fluency' => 'Fluency Training',
        'daily_challenge' => 'Daily Speaking Challenge',
        _ => mode,
      };

  String get durationLabel => '${estimatedDurationSeconds ~/ 60} min';

  int get totalQuestions {
    var total = 0;
    for (final part in parts) {
      final questions = part['questions'];
      if (questions is List) total += questions.length;
    }
    return total;
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
