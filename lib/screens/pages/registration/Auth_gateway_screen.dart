import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fyproject/resources/bottom_navigation_bar/botton_navigation.dart';
import 'package:fyproject/screens/pages/9-step%20premium%20profile%20setup%20wizard/initial_profile_setup.dart';

enum AuthMode { createAccount, signIn }

final FirebaseFunctions _authEmailFunctions = FirebaseFunctions.instanceFor(
  region: 'us-central1',
);

Future<void> _sendCustomVerificationEmail() async {
  final callable = _authEmailFunctions.httpsCallable(
    'sendCustomVerificationEmail',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );

  await callable.call<void>();
}

Future<void> _sendCustomPasswordResetEmail(String email) async {
  final callable = _authEmailFunctions.httpsCallable(
    'sendCustomPasswordResetEmail',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );

  await callable.call<void>({'email': email.trim().toLowerCase()});
}

String _functionsErrorMessage(
  FirebaseFunctionsException error, {
  required String fallback,
}) {
  final message = error.message?.trim();
  if (message != null && message.isNotEmpty) return message;
  return fallback;
}

class AuthenticationGatewayScreen extends StatefulWidget {
  final AuthMode initialMode;

  const AuthenticationGatewayScreen({
    super.key,
    this.initialMode = AuthMode.createAccount,
  });

  @override
  State<AuthenticationGatewayScreen> createState() =>
      _AuthenticationGatewayScreenState();
}

class _AuthenticationGatewayScreenState
    extends State<AuthenticationGatewayScreen> {
  late AuthMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 940;
                final authPanel = Column(
                  children: [
                    _TopBar(
                      title: _mode == AuthMode.createAccount
                          ? 'Create your account'
                          : 'Welcome back',
                      subtitle: _mode == AuthMode.createAccount
                          ? 'Your personalized IELTS plan starts here.'
                          : 'Sign in to continue your learning journey.',
                      onBack: () => Navigator.maybePop(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: _AuthModeSelector(
                        mode: _mode,
                        onChanged: (mode) => setState(() => _mode = mode),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _buildActiveForm()),
                  ],
                );

                if (!isWide) return authPanel;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Row(
                      children: [
                        const Expanded(flex: 11, child: _AuthStoryPanel()),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 9,
                          child: Container(
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: AuthColors.panel.withOpacity(.78),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: AuthColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.28),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: authPanel,
                          ),
                        ),
                      ],
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

  Widget _buildActiveForm() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(.035, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _mode == AuthMode.createAccount
          ? CreateAccountForm(
              key: const ValueKey('create'),
              onOpenSignIn: () => setState(() => _mode = AuthMode.signIn),
            )
          : SignInForm(
              key: const ValueKey('signin'),
              onOpenCreateAccount: () =>
                  setState(() => _mode = AuthMode.createAccount),
            ),
    );
  }
}

class CreateAccountForm extends StatefulWidget {
  final VoidCallback onOpenSignIn;

  const CreateAccountForm({super.key, required this.onOpenSignIn});

  @override
  State<CreateAccountForm> createState() => _CreateAccountFormState();
}

class _CreateAccountFormState extends State<CreateAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _country = 'Pakistan';
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final List<String> _countries = const [
    'Pakistan',
    'United Kingdom',
    'Australia',
    'Canada',
    'United States',
    'New Zealand',
    'United Arab Emirates',
    'Saudi Arabia',
    'India',
    'Bangladesh',
    'China',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      _showMessage(
        'Please accept the Terms and Privacy Policy.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-created',
          message: 'Account could not be created.',
        );
      }

      await user.updateDisplayName(_nameController.text.trim());

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'country': _country,
        'role': 'student',
        'authProvider': 'password',
        'emailVerified': user.emailVerified,
        'phoneVerified': false,
        'termsAccepted': true,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'profileCompleted': false,
        'diagnosticCompleted': false,
        'ieltsType': null,
        'educationLevel': null,
        'currentBand': null,
        'targetBand': null,
        'accountStatus': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _recordLoginEvent(user: user, method: 'password_registration');

      var verificationEmailSent = true;

      try {
        await _sendCustomVerificationEmail();
      } on FirebaseFunctionsException {
        verificationEmailSent = false;
      } catch (_) {
        verificationEmailSent = false;
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: user.email ?? _emailController.text.trim(),
            initialEmailSent: verificationEmailSent,
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage(
        'Something went wrong while creating your account.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    if (_isLoading || _isGoogleLoading) return;

    FocusScope.of(context).unfocus();
    setState(() => _isGoogleLoading = true);

    try {
      final credential = await _signInWithGoogle();
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'google-user-missing',
          message: 'Google account could not be loaded.',
        );
      }

      await _upsertGoogleUser(
        user,
        isNewUser: credential.additionalUserInfo?.isNewUser == true,
      );
      await _recordLoginEvent(user: user, method: 'google');

      if (!mounted) return;
      await _routeAuthenticatedUser(context, user);
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _showMessage('Google sign-in could not be completed.', isError: true);
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage('Google sign-in could not be completed.', isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _recordLoginEvent({
    required User user,
    required String method,
  }) async {
    final eventRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('loginEvents')
        .doc();

    await eventRef.set({
      'method': method,
      'platform': defaultTargetPlatform.name,
      'isWeb': kIsWeb,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'successful',
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: _AuthFormSurface(
              eyebrow: 'NEW LEARNER',
              title: 'Build your IELTS profile',
              description:
                  'A few secure details now unlock your adaptive study path.',
              child: Column(
                children: [
                  const _SecurityBanner(),
                  const SizedBox(height: 18),
                  _AuthTextField(
                    controller: _nameController,
                    label: 'Full name',
                    hint: 'Enter your full name',
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'Enter your complete name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 13),
                  _AuthTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'name@example.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 13),
                  _AuthTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Minimum 8 characters',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AuthColors.mutedText,
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 13),
                  _AuthTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm password',
                    hint: 'Re-enter your password',
                    icon: Icons.verified_user_outlined,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        );
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AuthColors.mutedText,
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 13),
                  _CountrySelector(
                    value: _country,
                    countries: _countries,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _country = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  _TermsCheckbox(
                    value: _acceptedTerms,
                    onChanged: (value) {
                      setState(() => _acceptedTerms = value ?? false);
                    },
                  ),
                  const SizedBox(height: 18),
                  _PrimaryAuthButton(
                    title: 'Create Account',
                    icon: Icons.arrow_forward_rounded,
                    isLoading: _isLoading,
                    onPressed: _isGoogleLoading ? null : _createAccount,
                  ),
                  const SizedBox(height: 18),
                  const _OrDivider(),
                  const SizedBox(height: 18),
                  _GoogleAuthButton(
                    title: 'Continue with Google',
                    isLoading: _isGoogleLoading,
                    onPressed: _isLoading ? null : _continueWithGoogle,
                  ),
                  const SizedBox(height: 20),
                  _ModeSwitchText(
                    normalText: 'Already have an account? ',
                    actionText: 'Sign In',
                    onTap: widget.onOpenSignIn,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? AuthColors.error : AuthColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }
}

class SignInForm extends StatefulWidget {
  final VoidCallback onOpenCreateAccount;

  const SignInForm({super.key, required this.onOpenCreateAccount});

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  DateTime? _lastAttemptAt;
  int _localFailedAttempts = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _canAttemptLogin() {
    if (_localFailedAttempts < 5 || _lastAttemptAt == null) {
      return true;
    }

    return DateTime.now().difference(_lastAttemptAt!) >
        const Duration(seconds: 30);
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!_canAttemptLogin()) {
      _showMessage('Too many attempts. Please wait 30 seconds.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _lastAttemptAt = DateTime.now();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) return;

      _localFailedAttempts = 0;

      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'emailVerified': user.emailVerified,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _recordSession(user, 'password');

      if (!mounted) return;

      if (!user.emailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: user.email ?? _emailController.text.trim(),
            ),
          ),
        );
        return;
      }

      await _routeAuthenticatedUser(context, user);
    } on FirebaseAuthException catch (error) {
      _localFailedAttempts += 1;
      await _recordFailedAttempt(error.code);
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage('Sign-in could not be completed.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    if (_isLoading || _isGoogleLoading) return;

    FocusScope.of(context).unfocus();
    setState(() => _isGoogleLoading = true);

    try {
      final credential = await _signInWithGoogle();
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'google-user-missing',
          message: 'Google account could not be loaded.',
        );
      }

      _localFailedAttempts = 0;
      await _upsertGoogleUser(
        user,
        isNewUser: credential.additionalUserInfo?.isNewUser == true,
      );
      await _recordSession(user, 'google');

      if (!mounted) return;
      await _routeAuthenticatedUser(context, user);
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _showMessage('Google sign-in could not be completed.', isError: true);
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (_) {
      _showMessage('Google sign-in could not be completed.', isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _recordSession(User user, String method) async {
    final sessionRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('deviceSessions')
        .doc();

    await sessionRef.set({
      'sessionId': sessionRef.id,
      'method': method,
      'platform': defaultTargetPlatform.name,
      'isWeb': kIsWeb,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    });

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('loginEvents')
        .add({
          'method': method,
          'platform': defaultTargetPlatform.name,
          'isWeb': kIsWeb,
          'status': 'successful',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _recordFailedAttempt(String errorCode) async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    await _firestore.collection('securityEvents').add({
      'type': 'failed_login',
      'email': email,
      'errorCode': errorCode,
      'platform': defaultTargetPlatform.name,
      'isWeb': kIsWeb,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _showForgotPassword() async {
    FocusScope.of(context).unfocus();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return _ForgotPasswordSheet(initialEmail: _emailController.text.trim());
      },
    );

    if (!mounted || result == null) return;

    _showMessage('Password reset email sent to $result.', isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: _AuthFormSurface(
              eyebrow: 'MEMBER ACCESS',
              title: 'Continue where you left off',
              description:
                  'Your plan, practice history and feedback are ready for you.',
              child: Column(
                children: [
                  const _SecurityBanner(),
                  const SizedBox(height: 18),
                  _AuthTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'name@example.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 13),
                  _AuthTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signIn(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AuthColors.mutedText,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPassword,
                      style: TextButton.styleFrom(
                        foregroundColor: AuthColors.cyan,
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  _PrimaryAuthButton(
                    title: 'Sign In',
                    icon: Icons.login_rounded,
                    isLoading: _isLoading,
                    onPressed: _isGoogleLoading ? null : _signIn,
                  ),
                  const SizedBox(height: 18),
                  const _OrDivider(),
                  const SizedBox(height: 18),
                  _GoogleAuthButton(
                    title: 'Continue with Google',
                    isLoading: _isGoogleLoading,
                    onPressed: _isLoading ? null : _continueWithGoogle,
                  ),
                  const SizedBox(height: 20),
                  _ModeSwitchText(
                    normalText: 'New to IELTS AI Master? ',
                    actionText: 'Create Account',
                    onTap: widget.onOpenCreateAccount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? AuthColors.error : AuthColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final bool initialEmailSent;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.initialEmailSent = true,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isSending = false;
  int _secondsUntilResend = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _secondsUntilResend = 30);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() => _secondsUntilResend = 0);
      } else {
        setState(() => _secondsUntilResend -= 1);
      }
    });
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);

    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user?.emailVerified == true) {
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set(
          {'emailVerified': true, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );

        if (!mounted) return;

        await _routeAuthenticatedUser(context, user);
      } else {
        _message('Email is not verified yet.');
      }
    } catch (_) {
      _message('Could not check verification status.');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_secondsUntilResend > 0) return;

    setState(() => _isSending = true);

    try {
      await _sendCustomVerificationEmail();
      _startResendTimer();
      _message('Verification email sent again.');
    } on FirebaseFunctionsException catch (error) {
      _message(
        _functionsErrorMessage(
          error,
          fallback: 'Verification email could not be sent right now.',
        ),
      );
    } catch (_) {
      _message('Verification email could not be sent right now.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const AuthenticationGatewayScreen(initialMode: AuthMode.signIn),
      ),
      (_) => false,
    );
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return _AuthStatusScaffold(
      eyebrow: 'ONE SECURE STEP',
      title: 'Verify your email',
      description: widget.initialEmailSent
          ? 'Open the secure link we sent to finish setting up your account.'
          : 'Your account is ready. Request a new verification email to continue.',
      icon: Icons.mark_email_read_rounded,
      child: Column(
        children: [
          _AuthNoticeCard(
            icon: Icons.alternate_email_rounded,
            title: 'Verification sent to',
            message: widget.email,
            accent: AuthColors.cyan,
          ),
          const SizedBox(height: 12),
          const _AuthNoticeCard(
            icon: Icons.inbox_rounded,
            title: 'Can’t find the email?',
            message:
                'Check Spam or Junk, then add IELTS AI Master to your trusted senders.',
            accent: AuthColors.violet,
          ),
          const SizedBox(height: 20),
          _PrimaryAuthButton(
            title: 'I’ve verified my email',
            icon: Icons.verified_rounded,
            isLoading: _isChecking,
            onPressed: _checkVerification,
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _isSending || _secondsUntilResend > 0
                  ? null
                  : _resendVerification,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 19),
              label: Text(
                _secondsUntilResend > 0
                    ? 'Resend available in ${_secondsUntilResend}s'
                    : 'Resend verification email',
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Use another account'),
          ),
        ],
      ),
    );
  }
}

Future<UserCredential> _signInWithGoogle() async {
  if (kIsWeb) {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    return FirebaseAuth.instance.signInWithPopup(provider);
  }

  final googleSignIn = GoogleSignIn.instance;
  await googleSignIn.initialize();
  final googleUser = await googleSignIn.authenticate();
  final googleAuth = googleUser.authentication;
  final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
  return FirebaseAuth.instance.signInWithCredential(credential);
}

Future<void> _upsertGoogleUser(User user, {required bool isNewUser}) async {
  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final existing = await userRef.get();

  final data = <String, dynamic>{
    'uid': user.uid,
    'fullName': user.displayName ?? '',
    'email': user.email?.trim().toLowerCase(),
    'photoUrl': user.photoURL,
    'authProvider': 'google',
    'emailVerified': user.emailVerified,
    'phoneVerified': user.phoneNumber != null,
    'updatedAt': FieldValue.serverTimestamp(),
    'lastLoginAt': FieldValue.serverTimestamp(),
  };

  if (!existing.exists || isNewUser) {
    data.addAll({
      'profileCompleted': false,
      'diagnosticCompleted': false,
      'role': 'student',
      'accountStatus': 'active',
      'ieltsType': null,
      'educationLevel': null,
      'currentBand': null,
      'targetBand': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  await userRef.set(data, SetOptions(merge: true));
}

Future<void> _routeAuthenticatedUser(BuildContext context, User user) async {
  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  var snapshot = await userRef.get();

  // Firebase Auth account exists, but an older user may not have a Firestore
  // profile document. Create a safe starter profile for that case.
  if (!snapshot.exists) {
    await userRef.set({
      'uid': user.uid,
      'fullName': user.displayName ?? '',
      'email': user.email?.trim().toLowerCase(),
      'role': 'student',
      'authProvider':
          user.providerData.any(
            (provider) => provider.providerId == 'google.com',
          )
          ? 'google'
          : 'password',
      'emailVerified': user.emailVerified,
      'phoneVerified': user.phoneNumber != null,
      'profileCompleted': false,
      'diagnosticCompleted': false,
      'accountStatus': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    snapshot = await userRef.get();
  }

  final data = snapshot.data() ?? <String, dynamic>{};
  final accountStatus = (data['accountStatus'] ?? 'active')
      .toString()
      .toLowerCase();
  final profileCompleted = data['profileCompleted'] == true;

  if (accountStatus == 'disabled' ||
      accountStatus == 'blocked' ||
      accountStatus == 'suspended') {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AuthColors.error,
        content: Text('This account is currently unavailable.'),
      ),
    );
    return;
  }

  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => profileCompleted
          ? const IELTSMainNavigation()
          : const InitialProfileSetupScreen(),
    ),
    (_) => false,
  );
}

/// Optional phone verification screen.
/// Open it after registration/profile setup when phone verification is needed.
class OptionalPhoneVerificationScreen extends StatefulWidget {
  const OptionalPhoneVerificationScreen({super.key});

  @override
  State<OptionalPhoneVerificationScreen> createState() =>
      _OptionalPhoneVerificationScreenState();
}

class _OptionalPhoneVerificationScreenState
    extends State<OptionalPhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  String? _verificationId;
  bool _sendingCode = false;
  bool _verifyingCode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();

    if (!phone.startsWith('+') || phone.length < 8) {
      _message('Use international format, for example +923001234567.');
      return;
    }

    setState(() => _sendingCode = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await _linkCredential(credential);
      },
      verificationFailed: (error) {
        _message(_authErrorMessage(error));
        if (mounted) setState(() => _sendingCode = false);
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;

        setState(() {
          _verificationId = verificationId;
          _sendingCode = false;
        });

        _message('Verification code sent.');
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
        if (mounted) setState(() => _sendingCode = false);
      },
    );
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null || _codeController.text.trim().length < 6) {
      _message('Enter the 6-digit verification code.');
      return;
    }

    setState(() => _verifyingCode = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );

      await _linkCredential(credential);
    } on FirebaseAuthException catch (error) {
      _message(_authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  Future<void> _linkCredential(PhoneAuthCredential credential) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _message('Sign in first before linking a phone number.');
      return;
    }

    try {
      await user.linkWithCredential(credential);
      await user.reload();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': FirebaseAuth.instance.currentUser?.phoneNumber,
        'phoneVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _message('Phone number verified successfully.');
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      _message(_authErrorMessage(error));
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return _AuthStatusScaffold(
      eyebrow: 'OPTIONAL SECURITY',
      title: _verificationId == null
          ? 'Protect your account'
          : 'Enter your security code',
      description: _verificationId == null
          ? 'Add a verified number for stronger recovery and important account alerts.'
          : 'We sent a 6-digit code to ${_phoneController.text.trim()}.',
      icon: _verificationId == null
          ? Icons.phonelink_lock_rounded
          : Icons.sms_rounded,
      showBackButton: true,
      child: Column(
        children: [
          _AuthTextField(
            controller: _phoneController,
            label: 'Phone number',
            hint: '+92 300 1234567',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          if (_verificationId != null) ...[
            const SizedBox(height: 14),
            _AuthTextField(
              controller: _codeController,
              label: 'Verification code',
              hint: 'Enter the 6-digit code',
              icon: Icons.password_rounded,
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 14),
          const _AuthNoticeCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Private by design',
            message:
                'Your number is used only for security and account recovery.',
            accent: AuthColors.success,
          ),
          const SizedBox(height: 20),
          _PrimaryAuthButton(
            title: _verificationId == null
                ? 'Send verification code'
                : 'Verify phone number',
            icon: Icons.arrow_forward_rounded,
            isLoading: _sendingCode || _verifyingCode,
            onPressed: _verificationId == null ? _sendCode : _verifyCode,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const InitialProfileSetupScreen(),
              ),
            ),
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }
}

class AuthenticatedPreviewScreen extends StatelessWidget {
  final User user;

  const AuthenticatedPreviewScreen({super.key, required this.user});

  Future<void> _logoutCurrentDevice(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const AuthenticationGatewayScreen(initialMode: AuthMode.signIn),
      ),
      (_) => false,
    );
  }

  Future<void> _requestLogoutFromAllDevices(BuildContext context) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'logoutAllRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Logout-all request saved. Token revocation must be completed by a secure Admin SDK backend.',
        ),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const AuthenticationGatewayScreen(initialMode: AuthMode.signIn),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AuthStatusScaffold(
      eyebrow: 'ACCOUNT SECURITY',
      title: user.displayName?.trim().isNotEmpty == true
          ? 'Hi, ${user.displayName!.trim().split(' ').first}'
          : 'Your account',
      description:
          'Review your verified identity and choose how you want to continue.',
      icon: Icons.person_rounded,
      avatarUrl: user.photoURL,
      child: Column(
        children: [
          _AuthNoticeCard(
            icon: Icons.alternate_email_rounded,
            title: 'Signed in as',
            message: user.email ?? 'No email available',
            accent: AuthColors.cyan,
          ),
          const SizedBox(height: 12),
          _AuthNoticeCard(
            icon: user.emailVerified
                ? Icons.verified_rounded
                : Icons.gpp_maybe_rounded,
            title: user.emailVerified
                ? 'Email verified'
                : 'Verification needed',
            message: user.emailVerified
                ? 'Your primary identity is protected and verified.'
                : 'Verify your email to protect all account features.',
            accent: user.emailVerified
                ? AuthColors.success
                : AuthColors.warning,
          ),
          const SizedBox(height: 20),
          _PrimaryAuthButton(
            title: 'Add phone security',
            icon: Icons.phonelink_lock_rounded,
            isLoading: false,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OptionalPhoneVerificationScreen(),
              ),
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => _logoutCurrentDevice(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out on this device'),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _requestLogoutFromAllDevices(context),
            icon: const Icon(Icons.phonelink_erase_rounded, size: 18),
            label: const Text('Sign out everywhere'),
            style: TextButton.styleFrom(foregroundColor: AuthColors.error),
          ),
        ],
      ),
    );
  }
}

class _AuthStoryPanel extends StatelessWidget {
  const _AuthStoryPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 34, 34, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AuthBrand(),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AuthColors.cyan.withOpacity(.08),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AuthColors.cyan.withOpacity(.18)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AuthColors.cyan,
                  size: 15,
                ),
                SizedBox(width: 7),
                Text(
                  'YOUR BAND. YOUR PLAN. YOUR PACE.',
                  style: TextStyle(
                    color: AuthColors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Prepare with clarity.\nImprove with purpose.',
            style: TextStyle(
              color: AuthColors.mainText,
              fontSize: 42,
              height: 1.06,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 520,
            child: Text(
              'One intelligent workspace for IELTS practice, AI feedback, progress and a plan that adapts as you improve.',
              style: TextStyle(
                color: AuthColors.mutedText,
                fontSize: 15,
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _AuthJourneyCard(),
          const Spacer(),
          const Wrap(
            spacing: 22,
            runSpacing: 12,
            children: [
              _AuthTrustItem(Icons.lock_outline_rounded, 'Secure sign-in'),
              _AuthTrustItem(Icons.cloud_done_outlined, 'Cloud synced'),
              _AuthTrustItem(Icons.psychology_alt_outlined, 'AI guided'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: AuthColors.gradient,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: AuthColors.cyan.withOpacity(.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.auto_stories_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IELTS AI',
              style: TextStyle(
                color: AuthColors.mainText,
                fontSize: 15,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'MASTER',
              style: TextStyle(
                color: AuthColors.cyan,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuthJourneyCard extends StatelessWidget {
  const _AuthJourneyCard();

  @override
  Widget build(BuildContext context) {
    const skills = [
      (Icons.headphones_rounded, 'Listening', AuthColors.cyan),
      (Icons.menu_book_rounded, 'Reading', AuthColors.blue),
      (Icons.edit_note_rounded, 'Writing', AuthColors.violet),
      (Icons.mic_rounded, 'Speaking', AuthColors.success),
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AuthColors.panel.withOpacity(.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AuthColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route_rounded, color: AuthColors.cyan, size: 19),
              SizedBox(width: 8),
              Text(
                'Your adaptive journey',
                style: TextStyle(
                  color: AuthColors.mainText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Spacer(),
              _AuthMiniBadge('BAND 7.0'),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: skills
                .map(
                  (skill) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: skill == skills.last ? 0 : 8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: skill.$3.withOpacity(.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: skill.$3.withOpacity(.14)),
                        ),
                        child: Column(
                          children: [
                            Icon(skill.$1, color: skill.$3, size: 19),
                            const SizedBox(height: 6),
                            Text(
                              skill.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AuthColors.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AuthMiniBadge extends StatelessWidget {
  final String label;

  const _AuthMiniBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AuthColors.cyan.withOpacity(.09),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AuthColors.cyan,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }
}

class _AuthTrustItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AuthTrustItem(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AuthColors.cyan, size: 17),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: AuthColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AuthModeSelector extends StatelessWidget {
  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  const _AuthModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AuthColors.surface.withOpacity(.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.border),
      ),
      child: Row(
        children: AuthMode.values.map((item) {
          final selected = item == mode;
          final title = item == AuthMode.createAccount
              ? 'Create account'
              : 'Sign in';

          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onChanged(item),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: selected
                        ? AuthColors.surfaceElevated
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: AuthColors.cyan.withOpacity(.18))
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(.16),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? AuthColors.mainText
                          : AuthColors.mutedText,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AuthFormSurface extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  const _AuthFormSurface({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 22),
      decoration: BoxDecoration(
        color: AuthColors.panel.withOpacity(.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AuthColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: AuthColors.cyan,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AuthColors.mainText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: AuthColors.mutedText,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _AuthStatusScaffold extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final String? avatarUrl;
  final bool showBackButton;
  final Widget child;

  const _AuthStatusScaffold({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
    this.avatarUrl,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusCard = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          decoration: _panelDecoration(),
          child: Column(
            children: [
              if (showBackButton)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: avatarUrl == null ? AuthColors.gradient : null,
                  color: avatarUrl == null ? null : AuthColors.surfaceElevated,
                  image: avatarUrl == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(avatarUrl!),
                          fit: BoxFit.cover,
                        ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(.10)),
                  boxShadow: [
                    BoxShadow(
                      color: AuthColors.cyan.withOpacity(.18),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: avatarUrl == null
                    ? Icon(icon, color: Colors.white, size: 34)
                    : null,
              ),
              const SizedBox(height: 18),
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AuthColors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AuthColors.mainText,
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.55,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AuthColors.mutedText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AuthColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 940) return statusCard;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1260),
                    child: Row(
                      children: [
                        const Expanded(child: _AuthStoryPanel()),
                        Expanded(child: statusCard),
                      ],
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
}

class _AuthNoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  const _AuthNoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(.065),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: accent.withOpacity(.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AuthColors.mainText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AuthColors.mutedText,
                    fontSize: 11.5,
                    height: 1.4,
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

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 22, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: AuthColors.surfaceElevated,
              foregroundColor: AuthColors.mainText,
              side: const BorderSide(color: AuthColors.border),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AuthColors.mainText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AuthColors.mutedText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _AuthMiniBadge('SECURE'),
        ],
      ),
    );
  }
}

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuthColors.cyan.withOpacity(.055),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AuthColors.cyan.withOpacity(.14)),
      ),
      child: const Row(
        children: [
          _SecurityIcon(),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure account access',
                  style: TextStyle(
                    color: AuthColors.mainText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Encrypted sign-in, verified email and protected cloud progress.',
                  style: TextStyle(
                    color: AuthColors.mutedText,
                    fontSize: 11.5,
                    height: 1.4,
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

class _SecurityIcon extends StatelessWidget {
  const _SecurityIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AuthColors.cyan.withOpacity(.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(
        Icons.shield_outlined,
        color: AuthColors.cyan,
        size: 21,
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: const TextStyle(
              color: AuthColors.secondaryText,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .15,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          cursorColor: AuthColors.cyan,
          style: const TextStyle(
            color: AuthColors.mainText,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AuthColors.subtleText,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AuthColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AuthColors.cyan, size: 18),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 54),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AuthColors.surface.withOpacity(.88),
            contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            border: _fieldBorder(AuthColors.border),
            enabledBorder: _fieldBorder(AuthColors.border),
            focusedBorder: _fieldBorder(AuthColors.cyan, width: 1.4),
            errorBorder: _fieldBorder(AuthColors.error),
            focusedErrorBorder: _fieldBorder(AuthColors.error, width: 1.4),
          ),
        ),
      ],
    );
  }
}

class _CountrySelector extends StatelessWidget {
  final String value;
  final List<String> countries;
  final ValueChanged<String?> onChanged;

  const _CountrySelector({
    required this.value,
    required this.countries,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            'Country',
            style: TextStyle(
              color: AuthColors.secondaryText,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: AuthColors.surfaceElevated,
          iconEnabledColor: AuthColors.cyan,
          style: const TextStyle(
            color: AuthColors.mainText,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsets.all(16),
              child: Icon(
                Icons.public_rounded,
                color: AuthColors.cyan,
                size: 19,
              ),
            ),
            filled: true,
            fillColor: AuthColors.surface.withOpacity(.88),
            border: _fieldBorder(AuthColors.border),
            enabledBorder: _fieldBorder(AuthColors.border),
            focusedBorder: _fieldBorder(AuthColors.cyan, width: 1.4),
          ),
          items: countries.map((country) {
            return DropdownMenuItem(value: country, child: Text(country));
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _TermsCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 12, 8),
      decoration: BoxDecoration(
        color: AuthColors.surface.withOpacity(.56),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AuthColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AuthColors.cyan,
            checkColor: AuthColors.background,
            side: const BorderSide(color: AuthColors.mutedText),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text.rich(
                TextSpan(
                  text: 'I agree to the ',
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: AuthColors.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: AuthColors.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: '.'),
                  ],
                ),
                style: TextStyle(
                  color: AuthColors.mutedText,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimaryAuthButton({
    required this.title,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final visuallyActive = isLoading || onPressed != null;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: visuallyActive
              ? AuthColors.gradient
              : const LinearGradient(
                  colors: [AuthColors.surfaceElevated, AuthColors.surface],
                ),
          boxShadow: visuallyActive
              ? [
                  BoxShadow(
                    color: AuthColors.blue.withOpacity(.24),
                    blurRadius: 22,
                    offset: const Offset(0, 11),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(icon, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.09))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 13),
          child: Text(
            'OR',
            style: TextStyle(
              color: AuthColors.subtleText,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.09))),
      ],
    );
  }
}

class _GoogleAuthButton extends StatelessWidget {
  final String title;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleAuthButton({
    required this.title,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AuthColors.mainText,
          backgroundColor: Colors.white.withOpacity(0.035),
          disabledForegroundColor: AuthColors.mutedText,
          side: BorderSide(color: Colors.white.withOpacity(0.11)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: AuthColors.cyan,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 29,
                    height: 29,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ModeSwitchText extends StatelessWidget {
  final String normalText;
  final String actionText;
  final VoidCallback onTap;

  const _ModeSwitchText({
    required this.normalText,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            normalText,
            textAlign: TextAlign.right,
            style: const TextStyle(color: AuthColors.mutedText, fontSize: 11.5),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            minimumSize: const Size(44, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionText,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF030812),
                Color(0xFF07111F),
                Color(0xFF091728),
                Color(0xFF06101D),
              ],
              stops: [0, 0.35, 0.72, 1],
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _AuthGridPainter())),
        ),
        const Positioned(
          top: -160,
          right: -130,
          child: _GlowCircle(size: 350, color: Color(0x2B2563EB)),
        ),
        const Positioned(
          top: 360,
          left: -170,
          child: _GlowCircle(size: 330, color: Color(0x1706B6D4)),
        ),
        const Positioned(
          bottom: -180,
          right: -150,
          child: _GlowCircle(size: 390, color: Color(0x178B5CF6)),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

class _AuthGridPainter extends CustomPainter {
  const _AuthGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.018)
      ..strokeWidth = 1;

    const gap = 42.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuthGridPainter oldDelegate) => false;
}

class AuthColors {
  static const background = Color(0xFF06101D);
  static const panel = Color(0xFF0C1727);
  static const surface = Color(0xFF101D2F);
  static const surfaceElevated = Color(0xFF17283D);
  static const mainText = Color(0xFFF8FAFC);
  static const secondaryText = Color(0xFFCBD5E1);
  static const mutedText = Color(0xFF94A3B8);
  static const subtleText = Color(0xFF64748B);
  static const border = Color(0xFF22344A);
  static const blue = Color(0xFF4F7CFF);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFFA78BFA);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFFB7185);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F7CFF), Color(0xFF22D3EE)],
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(17),
    borderSide: BorderSide(color: color, width: width),
  );
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AuthColors.panel.withOpacity(.94),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: AuthColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.26),
        blurRadius: 36,
        offset: const Offset(0, 18),
      ),
    ],
  );
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  final emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  if (!emailPattern.hasMatch(email)) {
    return 'Enter a valid email address.';
  }

  return null;
}

String? _validatePassword(String? value) {
  final password = value ?? '';

  if (password.length < 8) {
    return 'Password must contain at least 8 characters.';
  }

  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Add at least one uppercase letter.';
  }

  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Add at least one lowercase letter.';
  }

  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Add at least one number.';
  }

  return null;
}

String _authErrorMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'email-already-in-use':
      return 'An account already exists with this email.';
    case 'invalid-email':
      return 'The email address is invalid.';
    case 'weak-password':
      return 'Please choose a stronger password.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'The email or password is incorrect.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'Check your internet connection and try again.';
    case 'operation-not-allowed':
      return 'This sign-in method is not enabled in Firebase.';
    case 'account-exists-with-different-credential':
      return 'This email is already connected to another sign-in method.';
    case 'credential-already-in-use':
      return 'This phone number or credential is already in use.';
    case 'invalid-phone-number':
      return 'Enter a valid phone number with country code.';
    case 'invalid-verification-code':
      return 'The verification code is incorrect.';
    case 'session-expired':
      return 'The verification session expired. Request a new code.';
    case 'popup-closed-by-user':
      return 'The sign-in window was closed.';
    default:
      return error.message ?? 'Authentication failed. Please try again.';
  }
}

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordSheet({required this.initialEmail});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController _emailController;

  bool _sending = false;

  @override
  void initState() {
    super.initState();

    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();

    final validationError = _validateEmail(email);

    if (validationError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(validationError),
          ),
        );

      return;
    }

    setState(() => _sending = true);

    try {
      await _sendCustomPasswordResetEmail(email);

      if (!mounted) return;

      FocusScope.of(context).unfocus();
      Navigator.of(context).pop(email);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AuthColors.error,
            content: Text(
              _functionsErrorMessage(
                error,
                fallback: 'Password reset email could not be sent right now.',
              ),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AuthColors.error,
            content: Text('Password reset email could not be sent.'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
              decoration: BoxDecoration(
                color: AuthColors.panel,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(color: AuthColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.32),
                    blurRadius: 36,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AuthColors.border,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      _ResetIcon(),
                      SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reset your password',
                              style: TextStyle(
                                color: AuthColors.mainText,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'We’ll send a secure recovery link to your inbox.',
                              style: TextStyle(
                                color: AuthColors.mutedText,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AuthTextField(
                    controller: _emailController,
                    label: 'Account email',
                    hint: 'name@example.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_sending) _sendReset();
                    },
                  ),
                  const SizedBox(height: 13),
                  const _AuthNoticeCard(
                    icon: Icons.schedule_rounded,
                    title: 'Link expires automatically',
                    message:
                        'For your security, use the newest recovery email you receive.',
                    accent: AuthColors.violet,
                  ),
                  const SizedBox(height: 18),
                  _PrimaryAuthButton(
                    title: 'Send recovery link',
                    icon: Icons.arrow_forward_rounded,
                    isLoading: _sending,
                    onPressed: _sending ? null : _sendReset,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetIcon extends StatelessWidget {
  const _ResetIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: AuthColors.gradient,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Icon(
        Icons.lock_reset_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}
