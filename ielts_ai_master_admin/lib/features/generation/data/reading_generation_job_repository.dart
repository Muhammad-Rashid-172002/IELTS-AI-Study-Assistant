import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReadingGenerationJobRepository {
  ReadingGenerationJobRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReadingJobs({
    int limit = 100,
  }) {
    return _firestore
        .collection('generation_jobs')
        .where('contentType', isEqualTo: 'reading')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<String> createReadingJob({
    required String ieltsType,
    required String mode,
    required String difficulty,
    required int passageCount,
    required int questionCount,
    required int requestedCount,
    String? questionType,
    String? title,
    String? description,
    int? durationSeconds,
    int? estimatedWords,
    int? qualityTarget,
  }) async {
    final validationError = validateReadingJob(
      ieltsType: ieltsType,
      mode: mode,
      difficulty: difficulty,
      passageCount: passageCount,
      questionCount: questionCount,
      requestedCount: requestedCount,
      questionType: questionType,
    );

    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('Admin session expired. Please sign in again.');
    }

    final normalizedTitle = title?.trim() ?? '';
    final normalizedDescription = description?.trim() ?? '';
    final normalizedQuestionType = questionType?.trim();

    final jobRef = _firestore.collection('generation_jobs').doc();

    await jobRef.set({
      'contentType': 'reading',
      'ieltsType': ieltsType,
      'mode': mode,
      'difficulty': difficulty,
      'passageCount': passageCount,
      'questionCount': questionCount,
      'requestedCount': requestedCount,
      'questionType':
          normalizedQuestionType == null || normalizedQuestionType.isEmpty
          ? null
          : normalizedQuestionType,
      'title': normalizedTitle.isEmpty ? null : normalizedTitle,
      'description': normalizedDescription.isEmpty
          ? null
          : normalizedDescription,
      'durationSeconds': durationSeconds,
      'estimatedWords': estimatedWords,
      'qualityTarget': qualityTarget,
      'generatedCount': 0,
      'failedCount': 0,
      'status': 'queued',
      'createdBy': currentUser.uid,
      'createdByEmail': currentUser.email,
      'schemaVersion': 2,
      'source': 'admin_panel',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return jobRef.id;
  }

  String? validateReadingJob({
    required String ieltsType,
    required String mode,
    required String difficulty,
    required int passageCount,
    required int questionCount,
    required int requestedCount,
    String? questionType,
  }) {
    const allowedIeltsTypes = {'Academic', 'General Training'};

    const allowedModes = {
      'academic',
      'general',
      'passage',
      'question_type',
      'timed',
      'full',
      'speed',
      'exam',
    };

    const allowedDifficulties = {
      'Foundation',
      'Intermediate',
      'Upper Intermediate',
      'Advanced',
      'Expert',
    };

    const allowedQuestionTypes = {
      'Multiple choice',
      'True / False / Not Given',
      'Yes / No / Not Given',
      'Matching headings',
      'Matching information',
      'Matching features',
      'Sentence endings',
      'Summary completion',
      'Sentence completion',
      'Note completion',
      'Table completion',
      'Flowchart completion',
      'Diagram labels',
      'Short answers',
    };

    if (!allowedIeltsTypes.contains(ieltsType)) {
      return 'IELTS type must be Academic or General Training.';
    }

    if (!allowedModes.contains(mode)) {
      return 'Unsupported Reading mode: $mode.';
    }

    if (!allowedDifficulties.contains(difficulty)) {
      return 'Unsupported Reading difficulty: $difficulty.';
    }

    if (passageCount < 1 || passageCount > 3) {
      return 'Passage count must be between 1 and 3.';
    }

    if (questionCount < 5 || questionCount > 40) {
      return 'Question count must be between 5 and 40.';
    }

    if (requestedCount < 1 || requestedCount > 5) {
      return 'Number of requested tests must be between 1 and 5.';
    }

    final fullMode = {'academic', 'general', 'full', 'exam'}.contains(mode);

    if (fullMode && (passageCount != 3 || questionCount != 40)) {
      return 'Full Reading modes require 3 passages and 40 questions.';
    }

    if (mode == 'question_type') {
      final normalized = questionType?.trim() ?? '';

      if (normalized.isEmpty) {
        return 'Question Type Practice requires a question type.';
      }

      if (!allowedQuestionTypes.contains(normalized)) {
        return 'Unsupported Reading question type: $normalized.';
      }
    }

    return null;
  }

  Future<void> retryFailedJob(String jobId) async {
    final sourceRef = _firestore.collection('generation_jobs').doc(jobId);
    final source = await sourceRef.get();

    if (!source.exists) {
      throw StateError('Generation job not found.');
    }

    final data = source.data()!;
    if (data['contentType'] != 'reading') {
      throw StateError('Only Reading jobs can be retried here.');
    }

    await _firestore.collection('generation_jobs').add({
      ...data,
      'status': 'queued',
      'generatedCount': 0,
      'failedCount': 0,
      'lastError': FieldValue.delete(),
      'errorMessage': FieldValue.delete(),
      'errors': <String>[],
      'createdTestIds': <String>[],
      'retriedFromJobId': jobId,
      'createdBy': _auth.currentUser?.uid,
      'createdByEmail': _auth.currentUser?.email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'startedAt': null,
      'completedAt': null,
    });
  }
}
