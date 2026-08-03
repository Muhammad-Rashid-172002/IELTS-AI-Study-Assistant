import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/writing_admin_task.dart';

class WritingAdminRepository {
  WritingAdminRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<WritingAdminTask>> watchTasks({
    String status = 'all',
    String category = 'all',
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('writing_tasks');

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    if (category != 'all') {
      query = query.where('taskCategory', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      final tasks =
          snapshot.docs.map(WritingAdminTask.fromDocument).toList();
      tasks.sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return tasks;
    });
  }

  Stream<WritingAdminTask?> watchTask(String id) {
    return _firestore
        .collection('writing_tasks')
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? WritingAdminTask.fromDocument(doc) : null,
        );
  }

  Future<void> createWritingJob({
    required String taskCategory,
    required String taskType,
    required String difficulty,
    required int requestedCount,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Admin account is not signed in.');
    }

    await _firestore.collection('generation_jobs').add({
      'contentType': 'writing',
      'taskCategory': taskCategory,
      'taskType': taskType,
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
    return _firestore.collection('writing_tasks').doc(id).set({
      'status': status,
      'isPublished': status == 'published',
      'publishedAt':
          status == 'published' ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> duplicateTask(String id) async {
    final source =
        await _firestore.collection('writing_tasks').doc(id).get();

    if (!source.exists) throw StateError('Writing task not found.');

    final data = Map<String, dynamic>.from(source.data()!);
    data
      ..remove('taskId')
      ..remove('publishedAt')
      ..['title'] = '${data['title'] ?? 'Writing Task'} Copy'
      ..['status'] = 'draft'
      ..['isPublished'] = false
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    final copy = await _firestore.collection('writing_tasks').add(data);
    await copy.set({'taskId': copy.id}, SetOptions(merge: true));
    return copy.id;
  }

  Future<void> deleteTask(String id) {
    return _firestore.collection('writing_tasks').doc(id).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSubmissions() {
    return _firestore
        .collection('writing_submissions')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }
}
