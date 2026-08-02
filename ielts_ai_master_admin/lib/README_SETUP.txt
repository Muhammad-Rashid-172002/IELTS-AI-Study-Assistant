IELTS AI MASTER ADMIN — LIB SETUP

1. Create project:
   flutter create ielts_ai_master_admin

2. Replace its lib folder with this lib folder.

3. Add packages:
   flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage

4. Configure Firebase:
   dart pub global activate flutterfire_cli
   flutterfire configure

5. Use the SAME Firebase project as the user app.

6. In Firestore add admin permission:
   users/{ADMIN_UID}
     role: "admin"
     isAdmin: true

7. Run:
   flutter run -d chrome

IMPORTANT:
- Generate with AI currently creates generation_jobs documents.
- Gemini generation must be implemented in Firebase Cloud Functions/backend.
- Never put Gemini API keys directly inside Flutter.
