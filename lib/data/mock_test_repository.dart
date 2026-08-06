import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/mock_test_models.dart';

class MockTestRepository {
  MockTestRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<PublishedMockTest>> watchPublishedMockTests() {
    return _firestore
        .collection('mock_tests')
        .where('status', isEqualTo: 'published')
        .snapshots()
        .map((snapshot) {
          final tests = snapshot.docs
              .map(PublishedMockTest.fromDocument)
              .toList();

          tests.sort((a, b) => a.title.compareTo(b.title));
          return tests;
        });
  }

  Future<String> createAttempt(MockTestConfig config) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User is not signed in.');
    }

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mock_attempts')
        .doc();

    await ref.set({
      'attemptId': ref.id,
      'userId': user.uid,
      'config': config.toMap(),
      'status': 'in_progress',
      'currentSkill': config.skills.first.value,
      'currentQuestionIndex': 0,
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'submittedAt': null,
      'internetRecoveryEnabled': true,
      'autoSaveEnabled': true,
    });

    return ref.id;
  }

  Future<List<MockQuestion>> loadQuestions({
    required MockTestConfig config,
    required MockSkill skill,
  }) async {
    final requiredCount = skill.questionCount;

    final snapshot = await _firestore
        .collection('mock_test_bank')
        .doc(config.track.value)
        .collection(skill.value)
        .where('status', isEqualTo: 'published')
        .get();

    final matchingDocs = config.mockTestId.isEmpty
        ? snapshot.docs
        : snapshot.docs.where((doc) {
            return (doc.data()['mockTestId'] ?? '').toString() ==
                config.mockTestId;
          }).toList();

    final allPublished = matchingDocs.map((doc) {
      return MockQuestion.fromMap(doc.data(), id: doc.id, skill: skill);
    }).toList();

    final exactDifficulty = matchingDocs
        .where((doc) {
          return (doc.data()['difficulty'] ?? '').toString() ==
              config.difficulty;
        })
        .map((doc) {
          return MockQuestion.fromMap(doc.data(), id: doc.id, skill: skill);
        })
        .toList();

    final source = exactDifficulty.length >= requiredCount
        ? exactDifficulty
        : allPublished;

    source.sort((a, b) => a.number.compareTo(b.number));

    if (source.length < requiredCount) {
      throw StateError(
        'Not enough published ${skill.label} questions. '
        'Required: $requiredCount, available: ${source.length}. '
        'Open Admin → Mock Tests → Question Bank, generate and publish '
        '${skill.label} questions for ${config.track.label}.',
      );
    }

    return source.take(requiredCount).toList();
  }

  Future<void> saveAnswer({
    required String attemptId,
    required MockSkill skill,
    required MockAnswer answer,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final attemptRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mock_attempts')
        .doc(attemptId);

    await attemptRef
        .collection('answers')
        .doc('${skill.value}_${answer.questionId}')
        .set({
          ...answer.toMap(),
          'skill': skill.value,
          'attemptId': attemptId,
        }, SetOptions(merge: true));

    await attemptRef.set({
      'updatedAt': FieldValue.serverTimestamp(),
      'currentSkill': skill.value,
    }, SetOptions(merge: true));
  }

  Future<void> saveCheckpoint({
    required String attemptId,
    required MockSkill skill,
    required int questionIndex,
    required int remainingSeconds,
    required Map<String, int> skillTimeSpent,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mock_attempts')
        .doc(attemptId)
        .set({
          'currentSkill': skill.value,
          'currentQuestionIndex': questionIndex,
          'remainingSeconds': remainingSeconds,
          'skillTimeSpent': skillTimeSpent,
          'lastCheckpointAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> loadAttempt(String attemptId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mock_attempts')
        .doc(attemptId)
        .get();

    return doc.data();
  }

  Future<List<MockAnswer>> loadAnswers(String attemptId) async {
    final user = _auth.currentUser;
    if (user == null) return const [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mock_attempts')
        .doc(attemptId)
        .collection('answers')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return MockAnswer(
        questionId: (data['questionId'] ?? '').toString(),
        value: data['value'],
        flagged: data['flagged'] == true,
        updatedAt: data['updatedAt'] is Timestamp
            ? (data['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    }).toList();
  }

  Future<void> submitAttempt({
    required String attemptId,
    required bool autoSubmitted,
    required Map<String, int> skillTimeSpent,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final attemptRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mock_attempts')
        .doc(attemptId);

    await attemptRef.set({
      'status': 'submitted',
      'autoSubmitted': autoSubmitted,
      'skillTimeSpent': skillTimeSpent,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore.collection('mock_evaluation_jobs').add({
      'attemptId': attemptId,
      'userId': user.uid,
      'status': 'queued',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchAttempt(
    String attemptId,
  ) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mock_attempts')
        .doc(attemptId)
        .snapshots();
  }

  Future<MockFinalResult?> loadFinalResult(String attemptId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mock_attempts')
        .doc(attemptId)
        .get();

    final data = doc.data();
    if (data == null || data['result'] is! Map) return null;

    final result = Map<String, dynamic>.from(data['result']);
    final skillsMap = result['skills'] is Map
        ? Map<String, dynamic>.from(result['skills'])
        : <String, dynamic>{};

    final skillResults = <MockSkillResult>[];

    for (final skill in MockSkill.values) {
      final raw = skillsMap[skill.value];
      if (raw is Map) {
        skillResults.add(
          MockSkillResult.fromMap(Map<String, dynamic>.from(raw), skill),
        );
      }
    }

    return MockFinalResult(
      attemptId: attemptId,
      overallBand: _double(result['overallBand']),
      targetBand: _double(result['targetBand']),
      targetGap: _double(result['targetGap']),
      skillResults: skillResults,
      strengths: _strings(result['strengths']),
      weaknesses: _strings(result['weaknesses']),
      suggestedNextMockDate: result['suggestedNextMockDate'] is Timestamp
          ? (result['suggestedNextMockDate'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 7)),
      sevenDayPlan: result['sevenDayPlan'] is List
          ? (result['sevenDayPlan'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const [],
    );
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }
}
