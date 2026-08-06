import 'package:cloud_firestore/cloud_firestore.dart';

class ListeningAdminTest {
  final String id;
  final String title;
  final String description;
  final String status;
  final String ieltsType;
  final String mode;
  final int section;
  final String questionType;
  final String difficulty;
  final String accent;
  final int durationSeconds;
  final int questionCount;
  final double qualityScore;
  final String transcript;
  final String audioUrl;
  final String audioStatus;
  final int audioDurationSeconds;
  final List<Map<String, dynamic>> questions;

  const ListeningAdminTest({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.ieltsType,
    required this.mode,
    required this.section,
    required this.questionType,
    required this.difficulty,
    required this.accent,
    required this.durationSeconds,
    required this.questionCount,
    required this.qualityScore,
    required this.transcript,
    required this.questions,
    required this.audioUrl,
    required this.audioStatus,
    required this.audioDurationSeconds,
  });

  factory ListeningAdminTest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawQuestions = data['questions'] is List
        ? List<dynamic>.from(data['questions'])
        : <dynamic>[];

    return ListeningAdminTest(
      id: doc.id,
      title: (data['title'] ?? 'Untitled Listening Test').toString(),
      description: (data['description'] ?? '').toString(),
      status: (data['status'] ?? 'draft').toString(),
      ieltsType: (data['ieltsType'] ?? 'Academic').toString(),
      mode: (data['mode'] ?? 'section').toString(),
      section: _toInt(data['section']),
      questionType: (data['questionType'] ?? 'Mixed').toString(),
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      accent: (data['accent'] ?? 'British').toString(),
      durationSeconds: _toInt(data['durationSeconds']),
      questionCount: rawQuestions.length,
      qualityScore: _toDouble(data['qualityScore']),
      transcript: (data['transcript'] ?? '').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
      audioStatus: (data['audioStatus'] ?? 'pending').toString(),
      audioDurationSeconds: _toInt(data['audioDurationSeconds']),
      questions: rawQuestions
          .map(
            (e) => e is Map<String, dynamic>
                ? e
                : Map<String, dynamic>.from(e as Map),
          )
          .toList(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
