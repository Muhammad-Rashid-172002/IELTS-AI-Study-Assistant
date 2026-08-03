import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/diagnostic_admin_models.dart';
import '../models/diagnostic_generation_job.dart';

class DiagnosticAdminRepository {
  DiagnosticAdminRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _tests =>
      _firestore.collection('diagnostic_tests');

  CollectionReference<Map<String, dynamic>> get _generationJobs =>
      _firestore.collection('diagnostic_generation_jobs');

  Stream<List<DiagnosticGenerationJob>> watchGenerationJobs({
    int limit = 20,
  }) {
    return _generationJobs
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(DiagnosticGenerationJob.fromDocument)
              .toList(),
        );
  }

  Stream<DiagnosticGenerationJob?> watchGenerationJob(String jobId) {
    return _generationJobs.doc(jobId).snapshots().map(
          (doc) => doc.exists
              ? DiagnosticGenerationJob.fromDocument(doc)
              : null,
        );
  }

  Future<({String jobId, String testId})> generateWithAi({
    required String title,
    required String ieltsType,
    required String difficulty,
    required String topic,
    required int listeningQuestionCount,
    required int readingQuestionCount,
    required String writingTaskType,
    required int speakingPromptCount,
    required int durationMinutes,
  }) async {
    final callable =
        _functions.httpsCallable('createDiagnosticGenerationJob');

    final response = await callable.call({
      'title': title.trim(),
      'ieltsType': ieltsType,
      'difficulty': difficulty,
      'topic': topic.trim(),
      'listeningQuestionCount': listeningQuestionCount,
      'readingQuestionCount': readingQuestionCount,
      'writingTaskType': writingTaskType,
      'speakingPromptCount': speakingPromptCount,
      'durationMinutes': durationMinutes,
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    final jobId = (data['jobId'] ?? '').toString();
    final testId = (data['testId'] ?? '').toString();

    if (jobId.isEmpty || testId.isEmpty) {
      throw StateError('AI generation did not return valid IDs.');
    }

    return (jobId: jobId, testId: testId);
  }

  Future<void> retryAiGeneration(String jobId) async {
    final callable =
        _functions.httpsCallable('retryDiagnosticGenerationJob');
    await callable.call({'jobId': jobId});
  }


  Stream<List<DiagnosticTestAdminModel>> watchTests() {
    return _tests
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(DiagnosticTestAdminModel.fromDocument)
              .toList(),
        );
  }

  Future<String> createDraft(
    DiagnosticTestAdminModel model,
  ) async {
    final ref = _tests.doc();

    await ref.set({
      ...model.toFirestoreMap(),
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> updateTest(
    DiagnosticTestAdminModel model,
  ) async {
    if (model.id.isEmpty) {
      throw StateError('Diagnostic test ID is missing.');
    }

    await _tests.doc(model.id).set({
      ...model.toFirestoreMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> publishTest(
    DiagnosticTestAdminModel model,
  ) async {
    if (!model.isReadyToPublish) {
      throw StateError(
        model.validationIssues.join('\n'),
      );
    }

    await _tests.doc(model.id).set({
      ...model.toFirestoreMap(),
      'status': 'published',
      'publishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unpublishTest(String testId) async {
    await _tests.doc(testId).set({
      'status': 'draft',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> archiveTest(String testId) async {
    await _tests.doc(testId).set({
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteTest(String testId) async {
    await _tests.doc(testId).delete();
  }

  Future<String> uploadListeningAudio({
    required String testId,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'audio/mpeg',
  }) async {
    final safeName = fileName.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );

    final ref = _storage.ref(
      'diagnostic_audio/$testId/$safeName',
    );

    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );

    return ref.getDownloadURL();
  }
}
