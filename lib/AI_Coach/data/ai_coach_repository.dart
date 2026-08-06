import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ai_coach_models.dart';

class AiCoachRepository {
  AiCoachRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  static const String _conversationId = 'default';

  static const String _professionalResponseInstruction = r'''
You are IELTS AI Coach, a premium and professional IELTS tutor.

RESPONSE STYLE RULES:

1. Never use Markdown heading symbols such as #, ## or ###.
2. Never use Markdown bold or italic symbols such as **, __ or *.
3. Never wrap the response in code blocks.
4. Never display raw JSON to the learner.
5. Keep the response clean, concise, supportive and easy to scan.
6. Do not write one very long paragraph.
7. Divide the response into short sections with clear plain-text titles.
8. Use the bullet character "•" for bullet points.
9. Use numbered steps only where an ordered process is needed.
10. Avoid unnecessary repetition and generic motivational filler.
11. Use British English because this is an IELTS learning application.
12. Base recommendations on the learner's real progress whenever profile
    information is available.
13. Never claim that a band score is official. Use terms such as
    "estimated band" or "likely band".
14. End with one practical next action.

Preferred response format:

TITLE
A short, useful title

OVERVIEW
A brief 1-2 sentence answer

KEY POINTS
• First important point
• Second important point
• Third important point

COACH TIP
One personalised IELTS improvement tip

NEXT STEP
One clear action the learner should take now

For a speaking cue card, use:

SPEAKING CUE CARD
Topic sentence

YOU SHOULD SAY
• Point one
• Point two
• Point three
• Point four

BAND IMPROVEMENT TIPS
• Tip one
• Tip two
• Tip three

PRACTICE STEPS
1. Prepare for one minute.
2. Speak for one to two minutes.
3. Review fluency, vocabulary and grammar.

NEXT STEP
Ask the learner to send their answer for evaluation.

Return plain text only.
''';

  User get _currentUser {
    final user = _auth.currentUser;

    if (user == null) {
      throw const AiCoachException(
        'Please sign in to use the IELTS AI Coach.',
        code: 'not-authenticated',
      );
    }

    return user;
  }

  String get _uid => _currentUser.uid;

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _userRef.collection('ai_coach_messages');

  DocumentReference<Map<String, dynamic>> get _coachProfileRef =>
      _userRef.collection('ai_coach').doc('profile');

  Stream<List<AiCoachMessage>> watchMessages() {
    if (_auth.currentUser == null) {
      return Stream<List<AiCoachMessage>>.value(const []);
    }

    return _messagesRef
        .orderBy('createdAt', descending: false)
        .limitToLast(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AiCoachMessage.fromDocument)
              .toList(growable: false),
        )
        .handleError((Object error, StackTrace stackTrace) {
          throw AiCoachException.from(error);
        });
  }

  Stream<AiCoachProfile> watchCoachProfile() {
    if (_auth.currentUser == null) {
      return Stream<AiCoachProfile>.value(
        const AiCoachProfile(
          overallBand: 0,
          targetBand: 7,
          streak: 0,
          weakestSkill: 'Reading',
          strongestSkill: 'Listening',
          skillBands: {},
          weakQuestionTypes: {},
          completedLessons: 0,
          completedPractice: 0,
          completedMocks: 0,
        ),
      );
    }

    return _coachProfileRef
        .snapshots()
        .map((document) {
          return AiCoachProfile.fromMap(
            document.data() ?? const <String, dynamic>{},
          );
        })
        .handleError((Object error, StackTrace stackTrace) {
          throw AiCoachException.from(error);
        });
  }

  Future<void> sendMessage(String message) async {
    final trimmedMessage = message.trim();

    if (trimmedMessage.isEmpty) {
      throw const AiCoachException(
        'Please enter a message before sending.',
        code: 'empty-message',
      );
    }

    if (trimmedMessage.length > 3000) {
      throw const AiCoachException(
        'Your message is too long. Please keep it under 3000 characters.',
        code: 'message-too-long',
      );
    }

    final user = _currentUser;
    final messageReference = _messagesRef.doc();

    await messageReference.set({
      'messageId': messageReference.id,
      'conversationId': _conversationId,
      'role': 'user',
      'text': trimmedMessage,
      'status': 'sending',
      'authUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      final callable = _functions.httpsCallable(
        'askAiCoach',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'message': trimmedMessage,
        'messageId': messageReference.id,
        'conversationId': _conversationId,
        'responseInstruction': _professionalResponseInstruction,
        'responseFormat': 'professional_plain_text',
        'language': 'en-GB',
        'client': 'flutter',
        'clientVersion': 1,
      });

      final response = result.data;
      final success = response['success'] != false;

      if (!success) {
        throw AiCoachException(
          (response['message'] ?? 'The AI Coach could not generate a response.')
              .toString(),
          code: (response['code'] ?? 'backend-response-failed').toString(),
        );
      }

      await messageReference.set({
        'status': 'sent',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on TimeoutException {
      await _markMessageFailed(
        messageReference,
        code: 'timeout',
        message: 'The AI Coach took too long to respond.',
      );

      throw const AiCoachException(
        'The AI Coach is taking longer than expected. Please try again.',
        code: 'timeout',
      );
    } on FirebaseFunctionsException catch (error) {
      await _markMessageFailed(
        messageReference,
        code: error.code,
        message: error.message ?? 'Cloud Function request failed.',
      );

      throw AiCoachException(_functionsErrorMessage(error), code: error.code);
    } on FirebaseException catch (error) {
      await _markMessageFailed(
        messageReference,
        code: error.code,
        message: error.message ?? 'Firebase request failed.',
      );

      throw AiCoachException(_firebaseErrorMessage(error), code: error.code);
    } on AiCoachException {
      rethrow;
    } catch (error) {
      await _markMessageFailed(
        messageReference,
        code: 'unknown',
        message: error.toString(),
      );

      throw const AiCoachException(
        'The AI Coach could not respond. Please try again.',
        code: 'unknown',
      );
    }
  }

  Future<void> _markMessageFailed(
    DocumentReference<Map<String, dynamic>> messageReference, {
    required String code,
    required String message,
  }) async {
    try {
      await messageReference.set({
        'status': 'failed',
        'errorCode': code,
        'errorMessage': message,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> retryMessage({
    required String messageId,
    required String text,
  }) async {
    final oldReference = _messagesRef.doc(messageId);

    try {
      await oldReference.delete();
    } catch (_) {}

    await sendMessage(text);
  }

  Future<void> clearConversation() async {
    _currentUser;

    const batchSize = 400;

    while (true) {
      final snapshot = await _messagesRef.limit(batchSize).get();

      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      await batch.commit();

      if (snapshot.docs.length < batchSize) break;
    }

    await _userRef.set({
      'aiCoachConversationClearedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> refreshProfile() async {
    _currentUser;

    try {
      final callable = _functions.httpsCallable(
        'refreshAiCoachProfile',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );

      await callable.call<Map<String, dynamic>>({
        'conversationId': _conversationId,
        'language': 'en-GB',
        'client': 'flutter',
      });
    } on FirebaseFunctionsException catch (error) {
      throw AiCoachException(_functionsErrorMessage(error), code: error.code);
    } on FirebaseException catch (error) {
      throw AiCoachException(_firebaseErrorMessage(error), code: error.code);
    } catch (_) {
      throw const AiCoachException(
        'Your AI Coach profile could not be refreshed.',
        code: 'profile-refresh-failed',
      );
    }
  }

  String _functionsErrorMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Please sign in again to continue.';
      case 'permission-denied':
        return 'You do not have permission to use this feature.';
      case 'resource-exhausted':
        return 'The AI Coach is busy right now. Please try again shortly.';
      case 'deadline-exceeded':
        return 'The AI Coach took too long to respond.';
      case 'unavailable':
        return 'The AI Coach service is temporarily unavailable.';
      case 'invalid-argument':
        return error.message ?? 'Your request could not be processed.';
      default:
        return error.message ?? 'The AI Coach could not complete your request.';
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to access this conversation.';
      case 'unavailable':
        return 'Please check your internet connection and try again.';
      case 'cancelled':
        return 'The request was cancelled.';
      default:
        return error.message ?? 'A Firebase error occurred.';
    }
  }
}

class AiCoachException implements Exception {
  final String message;
  final String code;

  const AiCoachException(this.message, {this.code = 'ai-coach-error'});

  factory AiCoachException.from(Object error) {
    if (error is AiCoachException) return error;

    if (error is FirebaseFunctionsException) {
      return AiCoachException(
        error.message ?? 'The AI Coach service returned an error.',
        code: error.code,
      );
    }

    if (error is FirebaseException) {
      return AiCoachException(
        error.message ?? 'A Firebase error occurred.',
        code: error.code,
      );
    }

    return const AiCoachException(
      'Something went wrong while loading the AI Coach.',
      code: 'unknown',
    );
  }

  @override
  String toString() => message;
}
