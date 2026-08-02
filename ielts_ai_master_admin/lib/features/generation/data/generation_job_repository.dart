import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GenerationJobRepository {
  GenerationJobRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchJobs() {
    return _firestore
        .collection('generation_jobs')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> createListeningJob({
    required String ieltsType,
    required int section,
    required String questionType,
    required String difficulty,
    required String accent,
    required String mode,
    required int count,
  }) {
    return _firestore.collection('generation_jobs').add({
      'contentType': 'listening',
      'ieltsType': ieltsType,
      'section': section,
      'questionType': questionType,
      'difficulty': difficulty,
      'accent': accent,
      'mode': mode,
      'requestedCount': count,
      'generatedCount': 0,
      'failedCount': 0,
      'status': 'queued',
      'createdBy': _auth.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
