import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ielts_ai_master_admin/features/content_qa/data/content_qa_service.dart';

import '../domain/listening_admin_test.dart';

class ListeningAdminRepository {
  ListeningAdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final ContentQaService _qa = ContentQaService();

  Stream<List<ListeningAdminTest>> watchTests({String status = 'all'}) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      'listening_tests',
    );

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ListeningAdminTest.fromDocument).toList(),
        );
  }

  Stream<ListeningAdminTest?> watchTest(String id) {
    return _firestore
        .collection('listening_tests')
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? ListeningAdminTest.fromDocument(doc) : null);
  }

  Future<void> updateStatus({
    required String id,
    required String status,
  }) async {
    await _qa.changeStatus(documentPath: 'listening_tests/$id', status: status);
  }

  Future<void> deleteTest(String id) {
    return _firestore.collection('listening_tests').doc(id).delete();
  }
}
