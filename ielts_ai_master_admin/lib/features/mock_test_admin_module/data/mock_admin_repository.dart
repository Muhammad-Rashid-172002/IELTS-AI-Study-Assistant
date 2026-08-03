import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/mock_admin_models.dart';

class MockAdminRepository {
  MockAdminRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<MockAdminTest>> watchTests({
    String status = 'all',
    String track = 'all',
    String mode = 'all',
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('mock_tests');

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    if (track != 'all') {
      query = query.where('track', isEqualTo: track);
    }
    if (mode != 'all') {
      query = query.where('mode', isEqualTo: mode);
    }

    return query.snapshots().map((snapshot) {
      final tests =
          snapshot.docs.map(MockAdminTest.fromDocument).toList();

      tests.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return tests;
    });
  }

  Stream<MockAdminTest?> watchTest(String id) {
    return _firestore
        .collection('mock_tests')
        .doc(id)
        .snapshots()
        .map(
          (doc) => doc.exists ? MockAdminTest.fromDocument(doc) : null,
        );
  }

  Future<String> createMockTest({
    required String title,
    required String description,
    required MockAdminTrack track,
    required MockAdminScope scope,
    required MockAdminMode mode,
    required String difficulty,
    required List<MockAdminSkill> skills,
    required bool autoGenerateQuestionBank,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Admin is not signed in.');
    }

    final totalDuration = skills.fold<int>(
      0,
      (total, skill) => total + skill.durationMinutes,
    );

    final requiredBySkill = <String, int>{
      for (final skill in skills) skill.value: skill.targetCount,
    };
    final zeroBySkill = <String, int>{
      for (final skill in skills) skill.value: 0,
    };

    final totalRequired = requiredBySkill.values.fold<int>(
      0,
      (total, count) => total + count,
    );

    final ref = _firestore.collection('mock_tests').doc();

    await ref.set({
      'mockTestId': ref.id,
      'title': title.trim(),
      'description': description.trim(),
      'track': track.value,
      'scope': scope.value,
      'mode': mode.value,
      'difficulty': difficulty,
      'skills': skills.map((skill) => skill.value).toList(),
      'totalDurationMinutes': totalDuration,
      'totalQuestions': totalRequired,

      // Generation lifecycle
      'status': autoGenerateQuestionBank ? 'generating' : 'draft',
      'isReady': false,
      'isPublished': false,
      'requiredBySkill': requiredBySkill,
      'generatedBySkill': zeroBySkill,
      'failedBySkill': zeroBySkill,
      'jobStatusBySkill': {
        for (final skill in skills)
          skill.value:
              autoGenerateQuestionBank ? 'queued' : 'not_started',
      },
      'totalRequired': totalRequired,
      'totalGenerated': 0,
      'totalFailed': 0,
      'generationProgress': 0,
      'generationError': '',

      'isFeatured': false,
      'attemptCount': 0,
      'averageBand': 0,
      'completionRate': 0,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'readyAt': null,
      'publishedAt': null,
    });

    if (autoGenerateQuestionBank) {
      for (final skill in skills) {
        await createGenerationJob(
          track: track,
          skill: skill,
          difficulty: difficulty,
          questionType: _defaultQuestionType(skill),
          count: skill.targetCount,
          publishImmediately: false,
          mockTestId: ref.id,
        );
      }
    }

    return ref.id;
  }

  String _defaultQuestionType(MockAdminSkill skill) {
    return switch (skill) {
      MockAdminSkill.listening => 'mixed',
      MockAdminSkill.reading => 'mixed',
      MockAdminSkill.writing => 'mixed',
      MockAdminSkill.speaking => 'mixed',
    };
  }

  Future<void> publishMockTest(String id) async {
    final mockRef = _firestore.collection('mock_tests').doc(id);
    final snapshot = await mockRef.get();

    if (!snapshot.exists) {
      throw StateError('Mock test not found.');
    }

    final mock = MockAdminTest.fromDocument(snapshot);
    if (!mock.isReady) {
      throw StateError(
        'Mock test is not ready. Complete all required question banks first.',
      );
    }

    for (final skill in mock.skills) {
      final questionSnapshot = await _firestore
          .collection('mock_test_bank')
          .doc(mock.track.value)
          .collection(skill.value)
          .where('mockTestId', isEqualTo: id)
          .get();

      final matching = questionSnapshot.docs.where((doc) {
        return (doc.data()['difficulty'] ?? '').toString() ==
            mock.difficulty;
      }).toList();

      if (matching.length < mock.requiredFor(skill)) {
        throw StateError(
          '${skill.label} is incomplete. '
          'Required ${mock.requiredFor(skill)}, found ${matching.length}.',
        );
      }

      for (var start = 0; start < matching.length; start += 400) {
        final end = (start + 400).clamp(0, matching.length);
        final batch = _firestore.batch();

        for (final doc in matching.sublist(start, end)) {
          batch.set(
            doc.reference,
            {
              'status': 'published',
              'isPublished': true,
              'publishedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
      }
    }

    await mockRef.set({
      'status': 'published',
      'isPublished': true,
      'publishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> archiveMockTest(String id) async {
    final mockRef = _firestore.collection('mock_tests').doc(id);
    final snapshot = await mockRef.get();
    if (!snapshot.exists) return;

    final mock = MockAdminTest.fromDocument(snapshot);

    for (final skill in mock.skills) {
      final questions = await _firestore
          .collection('mock_test_bank')
          .doc(mock.track.value)
          .collection(skill.value)
          .where('mockTestId', isEqualTo: id)
          .get();

      for (var start = 0; start < questions.docs.length; start += 400) {
        final end = (start + 400).clamp(0, questions.docs.length);
        final batch = _firestore.batch();

        for (final doc in questions.docs.sublist(start, end)) {
          batch.set(
            doc.reference,
            {
              'status': 'archived',
              'isPublished': false,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    }

    await mockRef.set({
      'status': 'archived',
      'isPublished': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> restoreReadyMockTest(String id) {
    return _firestore.collection('mock_tests').doc(id).set({
      'status': 'ready',
      'isPublished': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> retryIncompleteSkills(MockAdminTest mock) async {
    for (final skill in mock.skills) {
      final missing = mock.requiredFor(skill) - mock.generatedFor(skill);
      if (missing <= 0) continue;

      await createGenerationJob(
        track: mock.track,
        skill: skill,
        difficulty: mock.difficulty,
        questionType: _defaultQuestionType(skill),
        count: missing,
        publishImmediately: false,
        mockTestId: mock.id,
      );
    }

    await _firestore.collection('mock_tests').doc(mock.id).set({
      'status': 'generating',
      'isReady': false,
      'generationError': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateFeatured({
    required String id,
    required bool featured,
  }) {
    return _firestore.collection('mock_tests').doc(id).set({
      'isFeatured': featured,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> duplicateTest(String id) async {
    final source = await _firestore.collection('mock_tests').doc(id).get();
    if (!source.exists) {
      throw StateError('Mock test not found.');
    }

    final data = Map<String, dynamic>.from(source.data()!);

    data
      ..remove('mockTestId')
      ..remove('publishedAt')
      ..['title'] = '${data['title'] ?? 'Mock Test'} Copy'
      ..['status'] = 'draft'
      ..['isReady'] = false
      ..['isPublished'] = false
      ..['isFeatured'] = false
      ..['attemptCount'] = 0
      ..['averageBand'] = 0
      ..['completionRate'] = 0
      ..['totalGenerated'] = 0
      ..['totalFailed'] = 0
      ..['generationProgress'] = 0
      ..['generationError'] = ''
      ..['generatedBySkill'] = {
        for (final skill in MockAdminTest.fromDocument(source).skills)
          skill.value: 0,
      }
      ..['failedBySkill'] = {
        for (final skill in MockAdminTest.fromDocument(source).skills)
          skill.value: 0,
      }
      ..['jobStatusBySkill'] = {
        for (final skill in MockAdminTest.fromDocument(source).skills)
          skill.value: 'not_started',
      }
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    final copy = await _firestore.collection('mock_tests').add(data);
    await copy.set({'mockTestId': copy.id}, SetOptions(merge: true));
    return copy.id;
  }

  Future<void> deleteTest(String id) {
    return _firestore.collection('mock_tests').doc(id).delete();
  }

  Stream<List<MockAdminQuestion>> watchQuestions({
    required MockAdminTrack track,
    required MockAdminSkill skill,
    String status = 'all',
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('mock_test_bank')
        .doc(track.value)
        .collection(skill.value);

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) {
      final questions = snapshot.docs
          .map(
            (doc) => MockAdminQuestion.fromDocument(
              doc,
              track: track,
              skill: skill,
            ),
          )
          .toList();

      questions.sort((a, b) => a.number.compareTo(b.number));
      return questions;
    });
  }

  Future<String> createQuestion({
    required MockAdminQuestion question,
  }) async {
    final ref = _firestore
        .collection('mock_test_bank')
        .doc(question.track.value)
        .collection(question.skill.value)
        .doc();

    await ref.set({
      ...question.toFirestore(),
      'questionId': ref.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> updateQuestion({
    required MockAdminQuestion question,
  }) {
    return _firestore
        .collection('mock_test_bank')
        .doc(question.track.value)
        .collection(question.skill.value)
        .doc(question.id)
        .set({
      ...question.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteQuestion({
    required MockAdminTrack track,
    required MockAdminSkill skill,
    required String id,
  }) {
    return _firestore
        .collection('mock_test_bank')
        .doc(track.value)
        .collection(skill.value)
        .doc(id)
        .delete();
  }

  Future<void> createGenerationJob({
    required MockAdminTrack track,
    required MockAdminSkill skill,
    required String difficulty,
    required String questionType,
    required int count,
    bool publishImmediately = false,
    String? mockTestId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Admin is not signed in.');

    await _firestore.collection('generation_jobs').add({
      'contentType': 'mock_test',
      'track': track.value,
      'skill': skill.value,
      'difficulty': difficulty,
      'questionType': questionType,
      'requestedCount': count,
      'publishImmediately': publishImmediately,
      'mockTestId': mockTestId,
      'generatedCount': 0,
      'failedCount': 0,
      'status': 'queued',
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateQuestionStatus({
    required MockAdminTrack track,
    required MockAdminSkill skill,
    required String id,
    required String status,
  }) {
    return _firestore
        .collection('mock_test_bank')
        .doc(track.value)
        .collection(skill.value)
        .doc(id)
        .set({
      'status': status,
      'isPublished': status == 'published',
      'publishedAt':
          status == 'published' ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> bulkUpdateQuestionStatus({
    required MockAdminTrack track,
    required MockAdminSkill skill,
    required Iterable<String> ids,
    required String status,
  }) async {
    final all = ids.toList();

    for (var start = 0; start < all.length; start += 400) {
      final end = (start + 400).clamp(0, all.length);
      final batch = _firestore.batch();

      for (final id in all.sublist(start, end)) {
        final ref = _firestore
            .collection('mock_test_bank')
            .doc(track.value)
            .collection(skill.value)
            .doc(id);

        batch.set(
          ref,
          {
            'status': status,
            'isPublished': status == 'published',
            'publishedAt': status == 'published'
                ? FieldValue.serverTimestamp()
                : null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAttempts() {
    return _firestore
        .collectionGroup('mock_attempts')
        .orderBy('startedAt', descending: true)
        .limit(200)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchEvaluationJobs() {
    return _firestore
        .collection('mock_evaluation_jobs')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }
}
