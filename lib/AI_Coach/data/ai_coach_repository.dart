import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ai_coach_models.dart';

class AiCoachRepository {
  AiCoachRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User is not signed in.');
    }
    return user.uid;
  }

  Stream<List<AiCoachMessage>> watchMessages() {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('ai_coach_messages')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AiCoachMessage.fromDocument)
              .toList(),
        );
  }

  Stream<AiCoachProfile> watchCoachProfile() {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('ai_coach')
        .doc('profile')
        .snapshots()
        .map(
          (doc) => AiCoachProfile.fromMap(
            doc.data() ?? const {},
          ),
        );
  }

  Future<void> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final messageRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('ai_coach_messages')
        .doc();

    await messageRef.set({
      'messageId': messageRef.id,
      'role': 'user',
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final callable = _functions.httpsCallable('askAiCoach');

    await callable.call({
      'message': trimmed,
      'conversationId': 'default',
    });
  }

  Future<void> clearConversation() async {
    final collection = _firestore
        .collection('users')
        .doc(_uid)
        .collection('ai_coach_messages');

    final snapshot = await collection.get();

    for (var start = 0; start < snapshot.docs.length; start += 400) {
      final end = (start + 400).clamp(0, snapshot.docs.length);
      final batch = _firestore.batch();

      for (final doc in snapshot.docs.sublist(start, end)) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }

  Future<void> refreshProfile() async {
    final callable = _functions.httpsCallable(
      'refreshAiCoachProfile',
    );
    await callable.call();
  }
}
