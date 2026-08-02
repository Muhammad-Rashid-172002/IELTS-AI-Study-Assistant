import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/listening_admin_test.dart';

class ListeningAdminRepository {
  ListeningAdminRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<ListeningAdminTest>> watchTests({
    String status = 'all',
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('listening_tests');

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ListeningAdminTest.fromDocument)
              .toList(),
        );
  }

  Stream<ListeningAdminTest?> watchTest(String id) {
    return _firestore
        .collection('listening_tests')
        .doc(id)
        .snapshots()
        .map(
          (doc) => doc.exists
              ? ListeningAdminTest.fromDocument(doc)
              : null,
        );
  }

  Future<void> updateStatus({
    required String id,
    required String status,
  }) {
    return _firestore.collection('listening_tests').doc(id).set({
      'status': status,
      'isPublished': status == 'published',
      'publishedAt':
          status == 'published' ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteTest(String id) {
    return _firestore.collection('listening_tests').doc(id).delete();
  }
}
