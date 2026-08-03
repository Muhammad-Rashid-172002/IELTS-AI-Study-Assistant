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
    final value = _auth.currentUser;
    if (value == null) throw StateError('User is not signed in.');
    return value;
  }

  Stream<ProfileModel> watchProfile() {
    final current = user;

    return _db.collection('users').doc(current.uid).snapshots().asyncMap((
      doc,
    ) async {
      final counts = await Future.wait([
        _count('saved_tests'),
        _count('saved_words'),
        _count('certificates'),
        _countWhere('lesson_progress', 'completed', true),
        _countWhere('mock_attempts', 'status', 'completed'),
      ]);

      final skillBands = await _skillBands();

      final availableBands = skillBands.values
          .where((band) => band > 0 && band <= 9)
          .toList();

      final calculatedBand = availableBands.isEmpty
          ? 0.0
          : availableBands.reduce((first, second) => first + second) /
                availableBands.length;

      final normalizedBand = double.parse(calculatedBand.toStringAsFixed(1));

      final userData = <String, dynamic>{
        ...?doc.data(),

        // Repository-calculated value always wins.
        'estimatedBand': normalizedBand,
        'currentBand': normalizedBand,
        'overallBand': normalizedBand,
      };

      if (normalizedBand > 0) {
        await doc.reference.set({
          'estimatedBand': normalizedBand,
          'currentBand': normalizedBand,
          'overallBand': normalizedBand,
          'bandUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return ProfileModel.fromMap(
        uid: current.uid,
        email: current.email ?? '',
        data: userData,
        counts: {
          'savedTests': counts[0],
          'savedWords': counts[1],
          'certificates': counts[2],
          'completedLessons': counts[3],
          'completedMocks': counts[4],
        },
        skillBands: skillBands,
      );
    });
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
    final names = [
      'listening_results',
      'reading_results',
      'writing_results',
      'speaking',
      'mock_attempts',
      'lesson_progress',
      'saved_tests',
      'saved_words',
      'certificates',
      'ai_coach_messages',
    ];

    final data = <String, dynamic>{};
    for (final name in names) {
      final snapshot = await userRef.collection(name).get();
      data[name] = snapshot.docs
          .map((doc) => {'id': doc.id, ..._safeMap(doc.data())})
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
    final ref = _db.collection('users').doc(user.uid);
    final names = [
      'listening_results',
      'reading_results',
      'writing_results',
      'speaking',
      'mock_attempts',
      'lesson_progress',
      'saved_tests',
      'saved_words',
      'certificates',
      'ai_coach_messages',
      'ai_coach',
    ];

    for (final name in names) {
      while (true) {
        final snapshot = await ref.collection(name).limit(400).get();
        if (snapshot.docs.isEmpty) break;

        final batch = _db.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (snapshot.docs.length < 400) break;
      }
    }

    await ref.delete();
    await user.delete();
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
    final collections = {
      'Listening': 'listening_results',
      'Reading': 'reading_results',
      'Writing': 'writing_results',
      'Speaking': 'speaking_results',
    };

    final result = <String, double>{};

    for (final entry in collections.entries) {
      final snapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection(entry.value)
          .limit(100)
          .get();

      if (snapshot.docs.isEmpty) {
        result[entry.key] = 0.0;
        continue;
      }

      final documents = [...snapshot.docs]
        ..sort(
          (first, second) =>
              _resultDate(second.data()).compareTo(_resultDate(first.data())),
        );

      result[entry.key] = _band(documents.first.data());
    }

    return result;
  }

  double _band(Map<String, dynamic> data) {
    dynamic value =
        data['band'] ??
        data['overallBand'] ??
        data['estimatedBand'] ??
        data['scoreBand'];

    if (value is num) return value.toDouble();

    final result = data['result'];
    if (result is Map) {
      value = result['overallBand'] ?? result['band'];
      if (value is num) return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _safeMap(Map<String, dynamic> source) {
    dynamic safe(dynamic value) {
      if (value is Timestamp) return value.toDate().toIso8601String();
      if (value is DateTime) return value.toIso8601String();
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), safe(v)));
      }
      if (value is Iterable) return value.map(safe).toList();
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
}
