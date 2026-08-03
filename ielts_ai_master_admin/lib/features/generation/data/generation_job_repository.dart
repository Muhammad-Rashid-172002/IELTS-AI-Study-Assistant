import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReadingGenerationJobRepository {
  ReadingGenerationJobRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const Set<String> supportedQuestionTypes = {
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

  static const Set<String> supportedModes = {
    'academic',
    'general',
    'passage',
    'question_type',
    'timed',
    'full',
    'speed',
    'exam',
  };

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
    final normalizedMode = _normalizeMode(mode);
    final normalizedQuestionType =
        _normalizeQuestionType(questionType);

    final validationError = validateReadingJob(
      ieltsType: ieltsType,
      mode: normalizedMode,
      difficulty: difficulty,
      passageCount: passageCount,
      questionCount: questionCount,
      requestedCount: requestedCount,
      questionType: normalizedQuestionType,
    );

    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError(
        'Admin session expired. Please sign in again.',
      );
    }

    final normalizedTitle = title?.trim() ?? '';
    final normalizedDescription = description?.trim() ?? '';
    final questionTypeKey = normalizedQuestionType == null
        ? null
        : _questionTypeKey(normalizedQuestionType);

    final jobRef =
        _firestore.collection('generation_jobs').doc();

    await jobRef.set({
      'contentType': 'reading',
      'ieltsType': ieltsType,
      'mode': normalizedMode,
      'difficulty': difficulty,
      'passageCount': passageCount,
      'questionCount': questionCount,
      'requestedCount': requestedCount,

      // Both fields are saved so the Cloud Function and student app can use
      // the same canonical IELTS Reading question-type value.
      'questionType': normalizedQuestionType,
      'primaryQuestionType': normalizedQuestionType,
      'questionTypeKey': questionTypeKey,
      'questionTypes': normalizedQuestionType == null
          ? <String>[]
          : <String>[normalizedQuestionType],
      'questionTypeKeys': questionTypeKey == null
          ? <String>[]
          : <String>[questionTypeKey],

      'title': normalizedTitle.isEmpty ? null : normalizedTitle,
      'description':
          normalizedDescription.isEmpty
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
      'schemaVersion': 3,
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
    const allowedIeltsTypes = {
      'Academic',
      'General Training',
    };

    const allowedDifficulties = {
      'Foundation',
      'Intermediate',
      'Upper Intermediate',
      'Advanced',
      'Expert',
    };

    final normalizedMode = _normalizeMode(mode);
    final normalizedQuestionType =
        _normalizeQuestionType(questionType);

    if (!allowedIeltsTypes.contains(ieltsType)) {
      return 'IELTS type must be Academic or General Training.';
    }

    if (!supportedModes.contains(normalizedMode)) {
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

    final fullMode = {
      'academic',
      'general',
      'full',
      'exam',
    }.contains(normalizedMode);

    if (fullMode &&
        (passageCount != 3 || questionCount != 40)) {
      return 'Full Reading modes require 3 passages and 40 questions.';
    }

    if (normalizedMode == 'question_type') {
      if (normalizedQuestionType == null) {
        return 'Question Type Practice requires a question type.';
      }

      if (!supportedQuestionTypes.contains(
        normalizedQuestionType,
      )) {
        return 'Unsupported Reading question type: '
            '$normalizedQuestionType.';
      }
    }

    if (normalizedQuestionType != null &&
        !supportedQuestionTypes.contains(
          normalizedQuestionType,
        )) {
      return 'Unsupported Reading question type: '
          '$normalizedQuestionType.';
    }

    return null;
  }

  Future<void> retryFailedJob(String jobId) async {
    final sourceRef =
        _firestore.collection('generation_jobs').doc(jobId);
    final source = await sourceRef.get();

    if (!source.exists) {
      throw StateError('Generation job not found.');
    }

    final data = source.data()!;
    if (data['contentType'] != 'reading') {
      throw StateError(
        'Only Reading jobs can be retried here.',
      );
    }

    final normalizedQuestionType = _normalizeQuestionType(
      (data['questionType'] ??
              data['primaryQuestionType'])
          ?.toString(),
    );
    final questionTypeKey = normalizedQuestionType == null
        ? null
        : _questionTypeKey(normalizedQuestionType);

    await _firestore.collection('generation_jobs').add({
      ...data,
      'mode': _normalizeMode(
        (data['mode'] ?? 'passage').toString(),
      ),
      'questionType': normalizedQuestionType,
      'primaryQuestionType': normalizedQuestionType,
      'questionTypeKey': questionTypeKey,
      'questionTypes': normalizedQuestionType == null
          ? <String>[]
          : <String>[normalizedQuestionType],
      'questionTypeKeys': questionTypeKey == null
          ? <String>[]
          : <String>[questionTypeKey],
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
      'schemaVersion': 3,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'startedAt': null,
      'completedAt': null,
    });
  }

  String _normalizeMode(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');

    const aliases = {
      'academic_reading': 'academic',
      'general_training': 'general',
      'general_training_reading': 'general',
      'passage_practice': 'passage',
      'question_type_practice': 'question_type',
      'timed_reading': 'timed',
      'full_reading_test': 'full',
      'speed_reading': 'speed',
      'speed_reading_exercise': 'speed',
      'strict_exam_mode': 'exam',
    };

    return aliases[normalized] ?? normalized;
  }

  String? _normalizeQuestionType(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;

    final normalized = input
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const aliases = {
      'multiple choice': 'Multiple choice',
      'true false not given':
          'True / False / Not Given',
      'true / false / not given':
          'True / False / Not Given',
      'yes no not given':
          'Yes / No / Not Given',
      'yes / no / not given':
          'Yes / No / Not Given',
      'matching headings': 'Matching headings',
      'matching information': 'Matching information',
      'matching features': 'Matching features',
      'sentence endings': 'Sentence endings',
      'summary completion': 'Summary completion',
      'sentence completion': 'Sentence completion',
      'note completion': 'Note completion',
      'table completion': 'Table completion',
      'flowchart completion':
          'Flowchart completion',
      'flow chart completion':
          'Flowchart completion',
      'diagram labels': 'Diagram labels',
      'diagram labelling': 'Diagram labels',
      'diagram labeling': 'Diagram labels',
      'short answers': 'Short answers',
      'short answer': 'Short answers',
    };

    return aliases[normalized] ?? input;
  }

  String _questionTypeKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
