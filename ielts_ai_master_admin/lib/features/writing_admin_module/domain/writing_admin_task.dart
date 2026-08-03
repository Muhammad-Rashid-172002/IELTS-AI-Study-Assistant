import 'package:cloud_firestore/cloud_firestore.dart';

class WritingAdminTask {
  final String id;
  final String title;
  final String description;
  final String taskQuestion;
  final String taskCategory;
  final String taskType;
  final String difficulty;
  final int minimumWords;
  final int durationSeconds;
  final String status;
  final double qualityScore;
  final String band8ModelAnswer;
  final List<String> checklist;
  final List<String> planningPoints;
  final List<Map<String, dynamic>> usefulVocabulary;
  final Map<String, dynamic> visualData;
  final Map<String, dynamic> lesson;
  final DateTime? createdAt;

  const WritingAdminTask({
    required this.id,
    required this.title,
    required this.description,
    required this.taskQuestion,
    required this.taskCategory,
    required this.taskType,
    required this.difficulty,
    required this.minimumWords,
    required this.durationSeconds,
    required this.status,
    required this.qualityScore,
    required this.band8ModelAnswer,
    required this.checklist,
    required this.planningPoints,
    required this.usefulVocabulary,
    required this.visualData,
    required this.lesson,
    required this.createdAt,
  });

  factory WritingAdminTask.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return WritingAdminTask(
      id: doc.id,
      title: (data['title'] ?? 'Untitled Writing Task').toString(),
      description: (data['description'] ?? '').toString(),
      taskQuestion: (data['taskQuestion'] ?? '').toString(),
      taskCategory: (data['taskCategory'] ?? 'task_2').toString(),
      taskType: (data['taskType'] ?? 'Opinion essay').toString(),
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      minimumWords: _asInt(data['minimumWords'], 250),
      durationSeconds: _asInt(data['durationSeconds'], 2400),
      status: (data['status'] ?? 'draft').toString(),
      qualityScore: _asDouble(data['qualityScore']),
      band8ModelAnswer: (data['band8ModelAnswer'] ?? '').toString(),
      checklist: _stringList(data['checklist']),
      planningPoints: _stringList(data['planningPoints']),
      usefulVocabulary: _mapList(data['usefulVocabulary']),
      visualData: _map(data['visualData']),
      lesson: _map(data['lesson']),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  String get categoryLabel => switch (taskCategory) {
        'academic_task_1' => 'Academic Task 1',
        'general_task_1' => 'General Training Task 1',
        'task_2' => 'Writing Task 2',
        _ => taskCategory,
      };

  String get durationLabel => '${durationSeconds ~/ 60} min';

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
    return value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
  }
}
