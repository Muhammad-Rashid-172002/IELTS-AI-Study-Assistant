class PlatformLinks {
  PlatformLinks._();

  static const privacyPolicy = 'https://ielts-ai-privacy.vercel.app/';
  static const termsOfService = 'https://ielts-ai-master-terms.vercel.app/terms';
  static const privacyPolicyVersion = '2026-08-v2.4.0';
  static const termsVersion = '2026-08';

  // Used only when a historical certificate document has no stored URL.
  // Existing printed QR destinations must continue to resolve.
  static const legacyVerificationOrigin =
      'https://ielts-ai-study-assistant.web.app/verify';

  static const practiceCredentialDisclaimer =
      'Practice credential only — not an official IELTS result or Test '
      'Report Form (TRF). IELTS AI Master is an independent preparation '
      'platform and is not endorsed by or affiliated with IELTS, the British '
      'Council, IDP or Cambridge.';

  static const aiProcessingNotice =
      'Your response is sent to our AI processing service to create '
      'educational feedback and an estimated practice band.';

  static const audioProcessingNotice =
      'Speaking recordings are uploaded for transcription and AI feedback. '
      'Review the Privacy Policy for the current storage and retention terms.';
}
