import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/vocabulary_admin_word.dart';

class VocabularyAdminRepository {
  VocabularyAdminRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<VocabularyAdminWord>> watchWords({
    String status = 'all',
    String category = 'all',
    String band = 'all',
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('vocabulary_words');

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    if (category != 'all') {
      query = query.where('category', isEqualTo: category);
    }
    if (band != 'all') {
      query = query.where('band', isEqualTo: band);
    }

    return query.snapshots().map((snapshot) {
      final words =
          snapshot.docs.map(VocabularyAdminWord.fromDocument).toList();

      words.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return words;
    });
  }

  Stream<VocabularyAdminWord?> watchWord(String id) {
    return _firestore
        .collection('vocabulary_words')
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? VocabularyAdminWord.fromDocument(doc) : null,
        );
  }

  Future<void> createGenerationJob({
    required String category,
    required String band,
    required String topic,
    required String difficulty,
    required String translationLanguage,
    required int count,
    required bool publishImmediately,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Admin account is not signed in.');
    }

    await _firestore.collection('generation_jobs').add({
      'contentType': 'vocabulary',
      'category': category,
      'band': band,
      'topic': topic.trim().isEmpty ? 'General IELTS' : topic.trim(),
      'difficulty': difficulty,
      'translationLanguage': translationLanguage,
      'requestedCount': count,
      'generatedCount': 0,
      'failedCount': 0,
      'publishImmediately': publishImmediately,
      'status': 'queued',
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> createManualWord(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Admin account is not signed in.');

    final ref = _firestore.collection('vocabulary_words').doc();

    await ref.set({
      ...data,
      'wordId': ref.id,
      'normalizedWord':
          (data['word'] ?? '').toString().trim().toLowerCase(),
      'status': data['status'] ?? 'draft',
      'isPublished': data['status'] == 'published',
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'savedCount': 0,
      'learnedCount': 0,
      'masteredCount': 0,
      'reviewCount': 0,
      'averageAccuracy': 0,
    });

    return ref.id;
  }

  Future<void> updateWord({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return _firestore.collection('vocabulary_words').doc(id).set({
      ...data,
      'normalizedWord':
          (data['word'] ?? '').toString().trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateStatus({
    required String id,
    required String status,
  }) {
    return _firestore.collection('vocabulary_words').doc(id).set({
      'status': status,
      'isPublished': status == 'published',
      'publishedAt':
          status == 'published' ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> duplicateWord(String id) async {
    final source =
        await _firestore.collection('vocabulary_words').doc(id).get();

    if (!source.exists) throw StateError('Vocabulary word not found.');

    final data = Map<String, dynamic>.from(source.data()!);

    data
      ..remove('wordId')
      ..remove('publishedAt')
      ..['word'] = '${data['word'] ?? 'Word'} Copy'
      ..['normalizedWord'] =
          '${data['word'] ?? 'word'} copy'.toLowerCase()
      ..['status'] = 'draft'
      ..['isPublished'] = false
      ..['savedCount'] = 0
      ..['learnedCount'] = 0
      ..['masteredCount'] = 0
      ..['reviewCount'] = 0
      ..['averageAccuracy'] = 0
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    final copy = await _firestore.collection('vocabulary_words').add(data);
    await copy.set({'wordId': copy.id}, SetOptions(merge: true));
    return copy.id;
  }

  Future<void> deleteWord(String id) {
    return _firestore.collection('vocabulary_words').doc(id).delete();
  }

  Future<void> bulkUpdateStatus(
    Iterable<String> ids,
    String status,
  ) async {
    final chunks = <List<String>>[];
    final all = ids.toList();

    for (var index = 0; index < all.length; index += 400) {
      chunks.add(all.sublist(index, (index + 400).clamp(0, all.length)));
    }

    for (final chunk in chunks) {
      final batch = _firestore.batch();

      for (final id in chunk) {
        final ref = _firestore.collection('vocabulary_words').doc(id);
        batch.set(
          ref,
          {
            'status': status,
            'isPublished': status == 'published',
            'publishedAt':
                status == 'published' ? FieldValue.serverTimestamp() : null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchVocabularyJobs() {
    return _firestore
        .collection('generation_jobs')
        .where('contentType', isEqualTo: 'vocabulary')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllProgress() {
    return _firestore
        .collectionGroup('vocabulary_progress')
        .limit(1000)
        .snapshots();
  }
}
