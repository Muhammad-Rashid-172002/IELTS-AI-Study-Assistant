import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/auth_config.dart';
import '../../resources/bottom_navigation_bar/botton_navigation.dart';
import '../../services/startup_access_policy.dart';
import '../../services/mobile_release_policy.dart';
import '../Onboarding_Screen/Onboarding_screen.dart';
import '../pages/9-step premium profile setup wizard/diagnotics_intro_screen.dart';
import '../pages/9-step premium profile setup wizard/initial_profile_setup.dart';
import '../pages/registration/email_verification_screen.dart';
import '../pages/personalized_study_plan/personalized_study_plan-screen.dart';

class CanonicalStartupGate extends StatefulWidget {
  const CanonicalStartupGate({super.key});

  @override
  State<CanonicalStartupGate> createState() => _CanonicalStartupGateState();
}

class _CanonicalStartupGateState extends State<CanonicalStartupGate> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MobileReleasePolicyService _releasePolicyService =
      MobileReleasePolicyService();

  bool _loading = true;
  String _message = 'Refreshing your secure session…';
  String _updateStoreUrl = '';
  bool _updateRequired = false;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _updateRequired = false;
        _updateStoreUrl = '';
        _message = 'Refreshing your secure session…';
      });
    }

    try {
      final releasePolicy = await _releasePolicyService.check();
      if (releasePolicy.updateRequired) {
        _holdUpdate(releasePolicy);
        return;
      }
    } catch (error) {
      debugPrint('Mobile release policy check unavailable: $error');
    }

    var user = _auth.currentUser;
    if (user == null) {
      _open(const PremiumOnboardingScreen());
      return;
    }

    var offline = false;
    try {
      await user.reload();
      user = _auth.currentUser;
      await user?.getIdToken(true);
    } catch (_) {
      offline = true;
    }

    if (user == null) {
      _open(const PremiumOnboardingScreen());
      return;
    }

    Map<String, dynamic> profile = const {};
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      profile = snapshot.data() ?? const {};
    } catch (_) {
      offline = true;
      try {
        final cached = await _firestore
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache));
        profile = cached.data() ?? const {};
      } catch (_) {
        profile = const {};
      }
    }

    final destination = StartupAccessPolicy.decide(
      signedIn: true,
      emailVerified: user.emailVerified,
      profile: profile,
      offline: offline,
      requireEmailVerification: AuthConfig.requireEmailVerification,
    );

    switch (destination) {
      case StartupDestination.onboarding:
        _open(const PremiumOnboardingScreen());
        return;
      case StartupDestination.profileSetup:
        _open(const InitialProfileSetupScreen());
        return;
      case StartupDestination.diagnostic:
        _open(
          DiagnosticIntroScreen(
            ieltsType: (profile['ieltsType'] ?? 'Academic').toString(),
            targetBand: _number(profile['targetBand'], 7),
          ),
        );
        return;
      case StartupDestination.studyPlan:
        _open(const PersonalizedStudyPlanScreen());
        return;
      case StartupDestination.main:
        _open(const IELTSMainNavigation());
        return;
      case StartupDestination.blocked:
        await _auth.signOut();
        _hold(
          'This account is suspended. Contact support if you believe this is a mistake.',
        );
        return;
      case StartupDestination.verifyEmail:
        _open(
          EmailVerificationScreen(
            email: user.email ?? '',
            initialEmailSent: false,
          ),
        );
        return;
      case StartupDestination.offlineUnavailable:
        _hold(
          'Connect to the internet so we can safely confirm your account and onboarding status.',
        );
        return;
    }
  }

  void _open(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => screen),
      (_) => false,
    );
  }

  void _hold(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = message;
    });
  }

  void _holdUpdate(MobileReleasePolicy policy) {
    if (!mounted) return;
    final version = policy.minimumVersion.isEmpty
        ? ''
        : ' Version ${policy.minimumVersion} or later is required.';
    setState(() {
      _loading = false;
      _updateRequired = true;
      _updateStoreUrl = policy.storeUrl;
      _message = policy.message.isEmpty
          ? 'A newer app version is required to continue securely.$version'
          : '${policy.message}$version';
    });
  }

  Future<void> _openStore() async {
    final uri = Uri.tryParse(_updateStoreUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The store link is not configured. Contact support.'),
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    _open(const PremiumOnboardingScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _loading ? 'Securing your session' : 'Action required',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF9FB0C5),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (_loading)
                    const CircularProgressIndicator()
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _updateRequired ? _openStore : _evaluate,
                        icon: Icon(
                          _updateRequired
                              ? Icons.system_update_alt_rounded
                              : Icons.refresh_rounded,
                        ),
                        label: Text(
                          _updateRequired ? 'Update app' : 'Retry secure check',
                        ),
                      ),
                    ),
                    if (!_updateRequired)
                      TextButton(
                        onPressed: _signOut,
                        child: const Text('Sign out'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _number(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
