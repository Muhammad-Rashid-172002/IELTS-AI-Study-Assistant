import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyproject/resources/app_theme/theme.dart';
import 'package:fyproject/resources/routes/routes_names.dart';
import 'package:url_launcher/url_launcher.dart';

const emailVerificationResendCooldown = Duration(seconds: 60);
const emailVerificationSupportEmail = 'support@korvenzatech.com';

String emailVerificationAuthErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'network-request-failed' =>
      'No internet connection. Check your network and try again.',
    'too-many-requests' =>
      'Too many requests were made. Please wait before trying again.',
    'user-not-found' || 'invalid-user-token' || 'user-token-expired' =>
      'Your verification session has expired. Sign in again to continue.',
    'user-disabled' =>
      'This account is currently unavailable. Contact support for help.',
    'requires-recent-login' =>
      'For security, please sign in again before continuing.',
    'operation-not-allowed' =>
      'Email verification is temporarily unavailable. Contact support if this continues.',
    _ =>
      'Email verification could not be completed right now. Please try again.',
  };
}

Uri buildEmailVerificationSupportUri(String? registeredEmail) {
  final email = registeredEmail?.trim() ?? '';
  final accountLine = email.isEmpty
      ? 'Registered email: Not available'
      : 'Registered email: $email';
  return Uri(
    scheme: 'mailto',
    path: emailVerificationSupportEmail,
    queryParameters: {
      'subject': 'IELTS AI Master - Email Verification Help',
      'body':
          'Hello IELTS AI Master Support,\n\n'
          'I need help verifying my email address.\n'
          '$accountLine\n\n'
          'Please help me complete email verification.\n\nThank you.',
    },
  );
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.initialEmailSent = true,
  });

  final String email;
  final bool initialEmailSent;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isSending = false;
  bool _isChangingEmail = false;
  bool _isOpeningSupport = false;
  int _secondsUntilResend = 0;
  DateTime? _cooldownEndsAt;
  Timer? _cooldownTimer;

  bool get _busy =>
      _isChecking || _isSending || _isChangingEmail || _isOpeningSupport;

  String get _registeredEmail {
    final current = FirebaseAuth.instance.currentUser?.email?.trim();
    return current?.isNotEmpty == true ? current! : widget.email.trim();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialEmailSent) {
      _startCooldown(notify: false);
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown({bool notify = true}) {
    _cooldownTimer?.cancel();
    _cooldownEndsAt = DateTime.now().add(emailVerificationResendCooldown);
    _secondsUntilResend = emailVerificationResendCooldown.inSeconds;
    if (notify && mounted) setState(() {});

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining =
          (_cooldownEndsAt!.difference(DateTime.now()).inMilliseconds / 1000)
              .ceil();
      if (remaining <= 0) {
        timer.cancel();
        setState(() => _secondsUntilResend = 0);
      } else if (remaining != _secondsUntilResend) {
        setState(() => _secondsUntilResend = remaining);
      }
    });
  }

  Future<void> _checkVerification() async {
    if (_busy) return;
    setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage(
          'Your session could not be found. Sign in again to continue.',
          isError: true,
        );
        return;
      }

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) {
        _showMessage(
          'Your session has expired. Sign in again to continue.',
          isError: true,
        );
        return;
      }

      if (!refreshedUser.emailVerified) {
        _showMessage(
          'Your email is not verified yet. Open the latest verification link, then check again.',
          isError: false,
        );
        return;
      }

      await _completeVerifiedUser(refreshedUser);
    } on FirebaseAuthException catch (error) {
      _showMessage(emailVerificationAuthErrorMessage(error), isError: true);
    } on FirebaseException catch (error) {
      _showMessage(
        error.code == 'unavailable'
            ? 'No internet connection. Check your network and try again.'
            : 'Your email is verified, but your account could not be refreshed. Please try again.',
        isError: true,
      );
    } catch (_) {
      _showMessage(
        'Verification status could not be checked right now. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _completeVerifiedUser(User user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'emailVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    _showMessage('Email verified successfully. Continuing…', isError: false);
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RoutesName.startup, (_) => false);
  }

  Future<void> _resendVerification() async {
    if (_busy || _secondsUntilResend > 0) return;
    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage(
          'Your session could not be found. Sign in again to request another email.',
          isError: true,
        );
        return;
      }

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) {
        _showMessage(
          'Your session has expired. Sign in again to request another email.',
          isError: true,
        );
        return;
      }

      if (refreshedUser.emailVerified) {
        await _completeVerifiedUser(refreshedUser);
        return;
      }

      await refreshedUser.sendEmailVerification();
      if (!mounted) return;
      _startCooldown();
      _showMessage(
        'Verification email sent. Check your inbox and Spam/Junk folder.',
        isError: false,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'too-many-requests' && mounted) {
        _startCooldown();
      }
      _showMessage(emailVerificationAuthErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage(
        'Verification email could not be sent right now. Check your connection and try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _changeEmailAddress() async {
    if (_busy) return;
    setState(() => _isChangingEmail = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.emailVerified == true) {
        _showMessage(
          'This email is already verified. Check your status to continue.',
          isError: false,
        );
        return;
      }

      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Change email address?'),
              content: const Text(
                'You will be signed out and returned to the existing account '
                'registration screen. Your current account and data will not be deleted.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Sign out & change email'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RoutesName.register, (_) => false);
    } on FirebaseAuthException catch (error) {
      _showMessage(emailVerificationAuthErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage(
        'The account could not be changed right now. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isChangingEmail = false);
    }
  }

  Future<void> _contactSupport() async {
    if (_busy) return;
    setState(() => _isOpeningSupport = true);
    try {
      final uri = buildEmailVerificationSupportUri(_registeredEmail);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Clipboard.setData(
          const ClipboardData(text: emailVerificationSupportEmail),
        );
        _showMessage(
          'No email app was available. Support email copied: $emailVerificationSupportEmail',
          isError: false,
        );
      }
    } catch (_) {
      await Clipboard.setData(
        const ClipboardData(text: emailVerificationSupportEmail),
      );
      _showMessage(
        'Support email copied: $emailVerificationSupportEmail',
        isError: false,
      );
    } finally {
      if (mounted) setState(() => _isOpeningSupport = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? AppTheme.danger : AppTheme.surfaceHigh,
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return EmailVerificationRecoveryView(
      email: _registeredEmail,
      initialEmailSent: widget.initialEmailSent,
      secondsUntilResend: _secondsUntilResend,
      isChecking: _isChecking,
      isSending: _isSending,
      isChangingEmail: _isChangingEmail,
      isOpeningSupport: _isOpeningSupport,
      onCheckVerification: _checkVerification,
      onResend: _resendVerification,
      onChangeEmail: _changeEmailAddress,
      onContactSupport: _contactSupport,
    );
  }
}

class EmailVerificationRecoveryView extends StatelessWidget {
  const EmailVerificationRecoveryView({
    super.key,
    required this.email,
    required this.initialEmailSent,
    required this.secondsUntilResend,
    required this.isChecking,
    required this.isSending,
    required this.isChangingEmail,
    required this.isOpeningSupport,
    required this.onCheckVerification,
    required this.onResend,
    required this.onChangeEmail,
    required this.onContactSupport,
  });

  final String email;
  final bool initialEmailSent;
  final int secondsUntilResend;
  final bool isChecking;
  final bool isSending;
  final bool isChangingEmail;
  final bool isOpeningSupport;
  final VoidCallback onCheckVerification;
  final VoidCallback onResend;
  final VoidCallback onChangeEmail;
  final VoidCallback onContactSupport;

  bool get _busy =>
      isChecking || isSending || isChangingEmail || isOpeningSupport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _VerificationBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 380
                    ? 14.0
                    : 22.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    18,
                    horizontalPadding,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(
                          constraints.maxWidth < 380 ? 18 : 24,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: .96),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .28),
                              blurRadius: 36,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _header(),
                            const SizedBox(height: 20),
                            _emailCard(),
                            const SizedBox(height: 12),
                            const _DeliveryTipCard(),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _busy ? null : onCheckVerification,
                                icon: isChecking
                                    ? const _ButtonSpinner()
                                    : const Icon(Icons.verified_rounded),
                                label: Text(
                                  isChecking
                                      ? 'Checking verification…'
                                      : "I've Verified My Email",
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _busy || secondsUntilResend > 0
                                    ? null
                                    : onResend,
                                icon: isSending
                                    ? const _ButtonSpinner()
                                    : const Icon(Icons.refresh_rounded),
                                label: Text(_resendLabel),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: _busy ? null : onChangeEmail,
                                icon: isChangingEmail
                                    ? const _ButtonSpinner()
                                    : const Icon(Icons.alternate_email_rounded),
                                label: const Text('Change Email Address'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Divider(color: Colors.white.withValues(alpha: .08)),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: _busy ? null : onContactSupport,
                                icon: isOpeningSupport
                                    ? const _ButtonSpinner()
                                    : const Icon(Icons.support_agent_rounded),
                                label: const Text('Need Help? Contact Support'),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'We will open your email app with the support address and account details pre-filled.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String get _resendLabel {
    if (isSending) return 'Sending verification email…';
    if (secondsUntilResend > 0) {
      return 'Resend available in ${secondsUntilResend}s';
    }
    return 'Resend Verification Email';
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.blue, AppTheme.cyan, AppTheme.violet],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.cyan.withValues(alpha: .18),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'ONE SECURE STEP',
          style: TextStyle(
            color: AppTheme.cyan,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Verify Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.text,
            fontSize: 25,
            height: 1.15,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          initialEmailSent
              ? 'Open the verification link we sent to finish setting up your account.'
              : 'Your account is ready. Request a new verification email to continue.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _emailCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cyan.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.cyan.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.alternate_email_rounded,
              color: AppTheme.cyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verification sent to',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  email.isEmpty ? 'Email unavailable' : email,
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTipCard extends StatelessWidget {
  const _DeliveryTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.violet.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.violet.withValues(alpha: .18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inbox_rounded, color: AppTheme.violet, size: 22),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              "Didn't receive the email? Check your Spam/Junk folder and make sure your inbox has available storage.",
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _VerificationBackground extends StatelessWidget {
  const _VerificationBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050B14), AppTheme.background, Color(0xFF09182A)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -100, right: -90, child: _Glow(color: AppTheme.cyan)),
          Positioned(
            bottom: -130,
            left: -100,
            child: _Glow(color: AppTheme.violet),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: .13), Colors.transparent],
        ),
      ),
    );
  }
}
