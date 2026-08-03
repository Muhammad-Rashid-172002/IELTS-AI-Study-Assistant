IELTS AI COACH MODULE

FILES
models/ai_coach_models.dart
data/ai_coach_repository.dart
presentation/ai_coach_screen.dart
functions/ai_coach_functions.js

WHAT IT DOES

- Progress-aware AI Coach
- Reads Listening, Reading, Writing, Speaking and Mock Test results
- Detects weakest and strongest skills
- Detects weak question types
- Daily study recommendations
- Wrong-answer explanation
- Writing plan
- Speaking cue cards
- True/False/Not Given explanation
- 30-day study plan
- Progress review
- Vocabulary practice
- Motivation
- Exam strategy
- Weekly report
- Suggested prompts
- Firestore conversation history
- Real user profile summary
- Gemini fallback models

RECOMMENDED FLUTTER PATHS

lib/features/ai_coach/models/ai_coach_models.dart
lib/features/ai_coach/data/ai_coach_repository.dart
lib/features/ai_coach/presentation/ai_coach_screen.dart

OPEN SCREEN

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const AiCoachScreen(),
  ),
);

REQUIRED PACKAGE

firebase_functions

Add if missing:

firebase_functions: ^latest-compatible-version

BACKEND INTEGRATION

Copy the functions from:

functions/ai_coach_functions.js

into your existing functions/index.js.

Make sure these imports already exist or add them:

const {onCall, HttpsError} =
  require("firebase-functions/v2/https");

const {defineSecret} =
  require("firebase-functions/params");

const {getFirestore, FieldValue} =
  require("firebase-admin/firestore");

DEPLOY

firebase deploy --only \
functions:askAiCoach,functions:refreshAiCoachProfile

FIRESTORE

users/{uid}/ai_coach/profile

users/{uid}/ai_coach_messages/{messageId}

DATA READ BY COACH

users/{uid}
users/{uid}/listening_results
users/{uid}/reading_results
users/{uid}/writing_results
users/{uid}/speaking
users/{uid}/mock_attempts
users/{uid}/lesson_progress

IMPORTANT

Your collection field names may differ.
Update averageBand() and collectWeakTypes() in the backend if your result
documents use different names.

The AI Coach is designed as a progress-aware coach, not a normal chatbot.
