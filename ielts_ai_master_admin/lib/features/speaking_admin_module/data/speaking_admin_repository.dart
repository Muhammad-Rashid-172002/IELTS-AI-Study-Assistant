import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/speaking_admin_test.dart';

class SpeakingAdminRepository {
  SpeakingAdminRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<SpeakingAdminTest>> watchTests({
    String status = 'all',
    String mode = 'all',
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('speaking_tests');

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    if (mode != 'all') {
      query = query.where('mode', isEqualTo: mode);
    }

    return query.snapshots().map((snapshot) {
      final tests =
          snapshot.docs.map(SpeakingAdminTest.fromDocument).toList();

      tests.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return tests;
    });
  }

  Stream<SpeakingAdminTest?> watchTest(String id) {
    return _firestore
        .collection('speaking_tests')
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? SpeakingAdminTest.fromDocument(doc) : null,
        );
  }

  Future<void> createSpeakingJob({
    required String mode,
    required int part,
    required String accent,
    required String difficulty,
    required int requestedCount,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Admin account is not signed in.');
    }

    await _firestore.collection('generation_jobs').add({
      'contentType': 'speaking',
      'mode': mode,
      'part': part,
      'accent': accent,
      'difficulty': difficulty,
      'requestedCount': requestedCount,
      'generatedCount': 0,
      'failedCount': 0,
      'status': 'queued',
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStatus({
    required String id,
    required String status,
  }) {
    return _firestore.collection('speaking_tests').doc(id).set({
      'status': status,
      'isPublished': status == 'published',
      'publishedAt':
          status == 'published' ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateFeatured({
    required String id,
    required bool featured,
  }) {
    return _firestore.collection('speaking_tests').doc(id).set({
      'isFeatured': featured,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> duplicateTest(String id) async {
    final source =
        await _firestore.collection('speaking_tests').doc(id).get();

    if (!source.exists) {
      throw StateError('Speaking test not found.');
    }

    final data = Map<String, dynamic>.from(source.data()!);

    data
      ..remove('testId')
      ..remove('publishedAt')
      ..['title'] = '${data['title'] ?? 'Speaking Test'} Copy'
      ..['status'] = 'draft'
      ..['isPublished'] = false
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    final copy = await _firestore.collection('speaking_tests').add(data);
    await copy.set({'testId': copy.id}, SetOptions(merge: true));
    return copy.id;
  }

  Future<void> deleteTest(String id) {
    return _firestore.collection('speaking_tests').doc(id).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSubmissions() {
    return _firestore
        .collection('speaking_submissions')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSpeakingJobs() {
    return _firestore
        .collection('generation_jobs')
        .where('contentType', isEqualTo: 'speaking')
        .snapshots();
  }
}
