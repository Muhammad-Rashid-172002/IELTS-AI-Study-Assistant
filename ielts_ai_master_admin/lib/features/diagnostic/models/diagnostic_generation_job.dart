import 'package:cloud_firestore/cloud_firestore.dart';

class DiagnosticGenerationJob {
  final String id;
  final String testId;
  final String status;
  final String ieltsType;
  final String difficulty;
  final String topic;
  final int progress;
  final String currentStep;
  final String error;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const DiagnosticGenerationJob({
    required this.id,
    required this.testId,
    required this.status,
    required this.ieltsType,
    required this.difficulty,
    required this.topic,
    required this.progress,
    required this.currentStep,
    required this.error,
    required this.createdAt,
    required this.completedAt,
  });

  bool get isRunning => status == 'queued' || status == 'generating';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory DiagnosticGenerationJob.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return DiagnosticGenerationJob(
      id: doc.id,
      testId: (data['testId'] ?? '').toString(),
      status: (data['status'] ?? 'queued').toString(),
      ieltsType: (data['ieltsType'] ?? 'Academic').toString(),
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      topic: (data['topic'] ?? '').toString(),
      progress: _int(data['progress']),
      currentStep: (data['currentStep'] ?? 'Queued').toString(),
      error: (data['error'] ?? '').toString(),
      createdAt: _date(data['createdAt']),
      completedAt: _date(data['completedAt']),
    );
  }

  static int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
