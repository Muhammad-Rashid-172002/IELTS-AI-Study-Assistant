/// Central switches for the authentication flow.
class AuthConfig {
  AuthConfig._();

  /// When `true`, email/password users get a verification email on
  /// registration and must verify before entering the app
  /// (EmailVerificationScreen gate on sign-up, sign-in and startup).
  ///
  /// TEMPORARILY DISABLED: set back to `true` to re-enable email
  /// verification. No other code changes are needed.
  static const bool requireEmailVerification = false;
}
