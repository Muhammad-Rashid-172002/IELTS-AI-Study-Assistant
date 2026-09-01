# Firebase mobile registration release gate

The production Firebase project remains `ielts-ai-study-assistant`.

Release identifiers are:

- Android application ID: `com.rashidapps.ieltsaimaster`
- iOS bundle ID: `com.rashidapps.ieltsaimaster`

Mobile startup deliberately uses the Firebase-generated native configuration
files rather than hard-coded Dart mobile app IDs. This prevents stale FlutterFire
metadata from silently overriding the native registration.

Before a release, an authorized operator must:

1. Reauthenticate the Firebase CLI and list the registered apps in the named
   project.
2. Confirm there is exactly one intended production Android registration for
   the Android application ID and one intended production iOS registration for
   the iOS bundle ID.
3. Download fresh `google-services.json` and `GoogleService-Info.plist` files
   from those exact registrations. Do not manually edit or infer app IDs.
4. Confirm OAuth clients, SHA-1/SHA-256 signing certificates and Auth authorized
   domains against the same production registrations.
5. Run `dart run tool/validate_firebase_mobile_config.dart` from the repository
   root. A non-zero result blocks release.

The current iOS plist is intentionally not treated as verified because its
bundle identifier does not match the Xcode release bundle. It must be replaced
from Firebase Console before iOS release validation.
