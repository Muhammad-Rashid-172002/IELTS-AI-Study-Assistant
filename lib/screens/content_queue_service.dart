import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyproject/offline/offline_content_service.dart';

/// Shared production queue logic for admin-published learning content.
///
/// A completed item is never returned as the next item. When every currently
/// published item is completed, the caller receives an empty result and can
/// show an "all completed" state until an administrator publishes new content.
class ContentQueueService {
  ContentQueueService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get uid => _auth.currentUser?.uid;

  Future<Set<String>> completedIds(String module) async {
    final userId = uid;
    if (userId == null) return <String>{};

    final ids = <String>{
      ...OfflineContentService.instance.completedIds(module),
    };
    final userRef = _db.collection('users').doc(userId);

    Future<void> readUserCollection(
      String collection,
      List<String> fields,
    ) async {
      try {
        final snapshot = await userRef.collection(collection).limit(500).get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          for (final field in fields) {
            final value = data[field]?.toString().trim() ?? '';
            if (value.isNotEmpty) ids.add(value);
          }
        }
      } catch (_) {
        // A missing legacy collection must not break the module.
      }
    }

    Future<void> readTopLevelCollection(
      String collection,
      List<String> fields,
    ) async {
      try {
        final snapshot = await _db
            .collection(collection)
            .where('userId', isEqualTo: userId)
            .limit(500)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().toLowerCase();
          if (status.isNotEmpty &&
              !{
                'completed',
                'evaluated',
                'ready',
                'submitted',
              }.contains(status)) {
            continue;
          }
          for (final field in fields) {
            final value = data[field]?.toString().trim() ?? '';
            if (value.isNotEmpty) ids.add(value);
          }
        }
      } catch (_) {
        // Optional compatibility lookup.
      }
    }

    switch (module) {
      case 'writing':
        await readUserCollection('writing_results', ['taskId', 'testId']);
        await readTopLevelCollection('writing_submissions', [
          'taskId',
          'testId',
        ]);
        break;
      case 'reading':
        await readUserCollection('reading_results', ['testId']);
        break;
      case 'listening':
        await readUserCollection('listening_results', ['testId']);
        break;
      case 'speaking':
        await readUserCollection('speaking_results', [
          'testId',
          'speakingTestId',
        ]);
        await readUserCollection('speaking', ['testId', 'speakingTestId']);
        await readTopLevelCollection('speaking_submissions', [
          'testId',
          'speakingTestId',
        ]);
        break;
      case 'mock_test':
        await readUserCollection('mock_attempts', ['mockTestId', 'testId']);
        await readTopLevelCollection('mock_attempts', ['mockTestId', 'testId']);
        break;
    }

    return ids;
  }

  Future<Set<String>> completedVocabularyIds() async {
    final userId = uid;
    if (userId == null) return <String>{};

    final localIds = OfflineContentService.instance.completedIds('vocabulary');
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('vocabulary_progress')
          .limit(1000)
          .get();

      return <String>{
        ...localIds,
        ...snapshot.docs
            .where((doc) {
              final status = (doc.data()['status'] ?? '')
                  .toString()
                  .toLowerCase();
              return status == 'learned' || status == 'mastered';
            })
            .map((doc) => doc.id),
      };
    } catch (_) {
      return localIds;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> sortPublished(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final docs = documents.toList();
    docs.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aOrder = _number(aData['order'] ?? aData['sequence'] ?? 999999);
      final bOrder = _number(bData['order'] ?? bData['sequence'] ?? 999999);
      final orderCompare = aOrder.compareTo(bOrder);
      if (orderCompare != 0) return orderCompare;

      final aDate = _date(aData['publishedAt'] ?? aData['createdAt']);
      final bDate = _date(bData['publishedAt'] ?? bData['createdAt']);
      return aDate.compareTo(bDate);
    });
    return docs;
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 999999;
  }

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(2100);
    return DateTime(2100);
  }
}
