import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/profile_model.dart';

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  User get user {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('User is not signed in.');
    }

    return currentUser;
  }

  Stream<ProfileModel> watchProfile() {
    final currentUser = user;
    final userRef = _db.collection('users').doc(currentUser.uid);

    return userRef.snapshots().asyncMap((document) async {
      final results = await Future.wait<Object>([
        _safeCount('saved_tests'),
        _safeCount('saved_words'),
        _safeCount('certificates'),
        _safeCountWhere('lesson_progress', 'completed', true),
        _safeCountWhere('mock_attempts', 'status', 'completed'),
        _safeSkillBands(),
      ]);

      final skillBands = results[5] as Map<String, double>;
      final completedBands = skillBands.entries
          .where((entry) => entry.value > 0 && entry.value <= 9)
          .toList();

      final completedSkillCount = completedBands.length;
      final missingSkills = skillBands.entries
          .where((entry) => entry.value <= 0 || entry.value > 9)
          .map((entry) => entry.key)
          .toList();

      final provisionalBand = completedBands.isEmpty
          ? 0.0
          : _roundToNearestHalf(
              completedBands
                      .map((entry) => entry.value)
                      .reduce((first, second) => first + second) /
                  completedBands.length,
            );

      final hasCompleteOverallBand = completedSkillCount == 4;
      final rawUserData = document.data() ?? <String, dynamic>{};

      final targetBands = rawUserData['targetBands'] is Map
          ? Map<String, dynamic>.from(rawUserData['targetBands'] as Map)
          : <String, dynamic>{};

      final resolvedTargetBand = _asDouble(
        targetBands['overall'] ?? rawUserData['targetBand'],
        fallback: 7.0,
      ).clamp(0.5, 9.0).toDouble();

      final userData = <String, dynamic>{
        ...rawUserData,
        'targetBand': resolvedTargetBand,
        'targetBands': {...targetBands, 'overall': resolvedTargetBand},
        'estimatedBand': provisionalBand,
        'currentBand': provisionalBand,
        'overallBand': provisionalBand,
        'completedSkillCount': completedSkillCount,
        'missingSkills': missingSkills,
        'bandStatus': hasCompleteOverallBand
            ? 'complete'
            : completedSkillCount > 0
            ? 'provisional'
            : 'not_started',
      };

      await _syncCalculatedProfileFields(
        userRef: userRef,
        existingData: rawUserData,
        targetBand: resolvedTargetBand,
        provisionalBand: provisionalBand,
        completedSkillCount: completedSkillCount,
        missingSkills: missingSkills,
        hasCompleteOverallBand: hasCompleteOverallBand,
      );

      return ProfileModel.fromMap(
        uid: currentUser.uid,
        email: currentUser.email ?? '',
        data: userData,
        counts: {
          'savedTests': results[0] as int,
          'savedWords': results[1] as int,
          'certificates': results[2] as int,
          'completedLessons': results[3] as int,
          'completedMocks': results[4] as int,
        },
        skillBands: skillBands,
      );
    });
  }

  Future<void> _syncCalculatedProfileFields({
    required DocumentReference<Map<String, dynamic>> userRef,
    required Map<String, dynamic> existingData,
    required double targetBand,
    required double provisionalBand,
    required int completedSkillCount,
    required List<String> missingSkills,
    required bool hasCompleteOverallBand,
  }) async {
    final existingTargetBands = existingData['targetBands'] is Map
        ? Map<String, dynamic>.from(existingData['targetBands'] as Map)
        : <String, dynamic>{};

    final existingMissingSkills = _asStringList(existingData['missingSkills']);

    final bandStatus = hasCompleteOverallBand
        ? 'complete'
        : completedSkillCount > 0
        ? 'provisional'
        : 'not_started';

    final needsSync =
        _asDouble(existingData['targetBand']) != targetBand ||
        _asDouble(existingTargetBands['overall']) != targetBand ||
        _asDouble(existingData['estimatedBand']) != provisionalBand ||
        _asDouble(existingData['currentBand']) != provisionalBand ||
        _asDouble(existingData['overallBand']) != provisionalBand ||
        _asInt(existingData['completedSkillCount']) != completedSkillCount ||
        !_sameStringList(existingMissingSkills, missingSkills) ||
        existingData['bandStatus'] != bandStatus;

    if (!needsSync) return;

    await userRef.set({
      'targetBand': targetBand,
      'targetBands': {...existingTargetBands, 'overall': targetBand},
      'estimatedBand': provisionalBand,
      'currentBand': provisionalBand,
      'overallBand': provisionalBand,
      'completedSkillCount': completedSkillCount,
      'missingSkills': missingSkills,
      'bandStatus': bandStatus,
      'bandUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProfile({
    required String name,
    required String ieltsType,
    required double targetBand,
    required DateTime? examDate,
    required String educationLevel,
  }) {
    return _db.collection('users').doc(user.uid).set({
      'name': name.trim(),
      'ieltsType': ieltsType,
      'targetBand': targetBand,
      'targetBands': {'overall': targetBand},
      'examDate': examDate == null ? null : Timestamp.fromDate(examDate),
      'educationLevel': educationLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updatePreferences({
    required String language,
    required String appearance,
    required bool notificationsEnabled,
    required bool dailyReminderEnabled,
    required String reminderTime,
  }) {
    return _db.collection('users').doc(user.uid).set({
      'language': language,
      'appearance': appearance,
      'notificationsEnabled': notificationsEnabled,
      'dailyReminderEnabled': dailyReminderEnabled,
      'reminderTime': reminderTime,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> exportJson() async {
    final userRef = _db.collection('users').doc(user.uid);
    final profile = await userRef.get();

    const collectionNames = [
      'listening_results',
      'reading_results',
      'writing_results',
      'speaking_results',
      'mock_attempts',
      'lesson_progress',
      'saved_tests',
      'saved_words',
      'certificates',
      'ai_coach_messages',
      'ai_coach',
    ];

    final data = <String, dynamic>{};

    for (final collectionName in collectionNames) {
      final snapshot = await userRef.collection(collectionName).get();

      data[collectionName] = snapshot.docs
          .map((document) => {'id': document.id, ..._safeMap(document.data())})
          .toList();
    }

    return const JsonEncoder.withIndent('  ').convert({
      'exportedAt': DateTime.now().toIso8601String(),
      'uid': user.uid,
      'email': user.email,
      'profile': _safeMap(profile.data() ?? {}),
      'data': data,
    });
  }

  Future<void> sendPasswordReset() async {
    final email = user.email;

    if (email == null || email.isEmpty) {
      throw StateError('No email is linked with this account.');
    }

    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() async {
    final currentUser = user;
    final userRef = _db.collection('users').doc(currentUser.uid);

    const collectionNames = [
      'listening_results',
      'reading_results',
      'writing_results',
      'speaking_results',
      'mock_attempts',
      'lesson_progress',
      'saved_tests',
      'saved_words',
      'certificates',
      'ai_coach_messages',
      'ai_coach',
      'study_sessions',
      'studyPlans',
      'diagnosticResults',
    ];

    for (final collectionName in collectionNames) {
      await _deleteCollectionInBatches(userRef.collection(collectionName));
    }

    await userRef.delete();
    await currentUser.delete();
  }

  Future<void> _deleteCollectionInBatches(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const batchSize = 400;

    while (true) {
      final snapshot = await collection.limit(batchSize).get();

      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      await batch.commit();

      if (snapshot.docs.length < batchSize) return;
    }
  }

  Future<int> _safeCount(String name) async {
    try {
      return await _count(name);
    } on FirebaseException {
      return 0;
    }
  }

  Future<int> _safeCountWhere(String name, String field, dynamic value) async {
    try {
      return await _countWhere(name, field, value);
    } on FirebaseException {
      return 0;
    }
  }

  Future<Map<String, double>> _safeSkillBands() async {
    try {
      return await _skillBands();
    } on FirebaseException {
      return const {'Listening': 0, 'Reading': 0, 'Writing': 0, 'Speaking': 0};
    }
  }

  Future<int> _count(String name) async {
    final result = await _db
        .collection('users')
        .doc(user.uid)
        .collection(name)
        .count()
        .get();

    return result.count ?? 0;
  }

  Future<int> _countWhere(String name, String field, dynamic value) async {
    final result = await _db
        .collection('users')
        .doc(user.uid)
        .collection(name)
        .where(field, isEqualTo: value)
        .count()
        .get();

    return result.count ?? 0;
  }

  Future<Map<String, double>> _skillBands() async {
    const collections = {
      'Listening': 'listening_results',
      'Reading': 'reading_results',
      'Writing': 'writing_results',
      'Speaking': 'speaking_results',
    };

    final entries = await Future.wait(
      collections.entries.map((entry) async {
        final snapshot = await _db
            .collection('users')
            .doc(user.uid)
            .collection(entry.value)
            .limit(100)
            .get();

        if (snapshot.docs.isEmpty) {
          return MapEntry(entry.key, 0.0);
        }

        final documents = [...snapshot.docs]
          ..sort(
            (first, second) =>
                _resultDate(second.data()).compareTo(_resultDate(first.data())),
          );

        return MapEntry(
          entry.key,
          _roundToNearestHalf(_band(documents.first.data()).clamp(0.0, 9.0)),
        );
      }),
    );

    return Map<String, double>.fromEntries(entries);
  }

  double _band(Map<String, dynamic> data) {
    dynamic value =
        data['band'] ??
        data['overallBand'] ??
        data['estimatedBand'] ??
        data['scoreBand'];

    if (value is num) {
      return value.toDouble();
    }

    final result = data['result'];

    if (result is Map) {
      value =
          result['overallBand'] ?? result['band'] ?? result['estimatedBand'];

      if (value is num) {
        return value.toDouble();
      }
    }

    return double.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static Map<String, dynamic> _safeMap(Map<String, dynamic> source) {
    dynamic safe(dynamic value) {
      if (value is Timestamp) {
        return value.toDate().toIso8601String();
      }

      if (value is DateTime) {
        return value.toIso8601String();
      }

      if (value is Map) {
        return value.map((key, item) => MapEntry(key.toString(), safe(item)));
      }

      if (value is Iterable) {
        return value.map(safe).toList();
      }

      return value;
    }

    return source.map((key, value) => MapEntry(key, safe(value)));
  }

  DateTime _resultDate(Map<String, dynamic> data) {
    for (final key in const [
      'completedAt',
      'timestamp',
      'createdAt',
      'updatedAt',
      'submittedAt',
    ]) {
      final value = data[key];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        final parsed = DateTime.tryParse(value);

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString().trim() ?? '') ?? fallback;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! Iterable) {
      return const [];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static bool _sameStringList(List<String> first, List<String> second) {
    if (first.length != second.length) return false;

    final firstSorted = [...first]..sort();
    final secondSorted = [...second]..sort();

    for (var index = 0; index < firstSorted.length; index++) {
      if (firstSorted[index] != secondSorted[index]) {
        return false;
      }
    }

    return true;
  }

  static double _roundToNearestHalf(double value) {
    if (value <= 0) return 0;

    return (value * 2).round() / 2;
  }
}
