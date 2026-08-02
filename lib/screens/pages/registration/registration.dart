import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/registration/Auth_gateway_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  void _openPreview(String title, IconData icon) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, animation, secondaryAnimation) {
          return AuthenticationGatewayScreen(
            initialMode: AuthMode.createAccount,
          );
        },
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          final slide =
              Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  void _showGuestAccessSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return const _GuestAccessSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: Stack(
        children: [
          const Positioned.fill(child: _WelcomeBackground()),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _AmbientParticlesPainter(
                    progress: _ambientController.value,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _entranceController,
                curve: Curves.easeOut,
              ),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.035),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _entranceController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                  child: Column(
                    children: [
                      _buildTopBrand(),
                      const SizedBox(height: 28),
                      const _HeroSection(),
                      const SizedBox(height: 24),
                      _buildPrimaryActions(),
                      const SizedBox(height: 14),
                      _buildSocialActions(),
                      const SizedBox(height: 16),
                      _buildGuestAction(),
                      const SizedBox(height: 18),
                      const _TrustFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBrand() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF8B5CF6)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withOpacity(0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IELTS AI',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 15,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'MASTER',
              style: TextStyle(
                color: Color(0xFF67E8F9),
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF101F31).withOpacity(0.9),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: const Color(0xFF38BDF8).withOpacity(0.16),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.language_rounded, color: Color(0xFF67E8F9), size: 14),
              SizedBox(width: 6),
              Text(
                'English',
                style: TextStyle(
                  color: Color(0xFFBAE6FD),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActions() {
    return Column(
      children: [
        _GradientActionButton(
          title: 'Create Account',
          subtitle: 'Start your personalized IELTS journey',
          icon: Icons.person_add_alt_1_rounded,
          onTap: () =>
              _openPreview('Create Account', Icons.person_add_alt_1_rounded),
        ),
        const SizedBox(height: 12),
        _OutlineActionButton(
          title: 'Sign In',
          subtitle: 'Continue from your saved progress',
          icon: Icons.login_rounded,
          onTap: () => _openPreview('Sign In', Icons.login_rounded),
        ),
      ],
    );
  }

  Widget _buildSocialActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.white.withOpacity(0.08),
                thickness: 1,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or continue with',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.white.withOpacity(0.08),
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                title: 'Google',
                icon: Icons.g_mobiledata_rounded,
                onTap: () => _openPreview(
                  'Continue with Google',
                  Icons.g_mobiledata_rounded,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                title: 'Apple',
                icon: Icons.apple_rounded,
                onTap: () =>
                    _openPreview('Continue with Apple', Icons.apple_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGuestAction() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showGuestAccessSheet,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1D2D).withOpacity(0.9),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.18),
            ),
          ),
          child: const Row(
            children: [
              _GuestIcon(),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore as Guest',
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Preview the app with limited access',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFFA78BFA),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1827).withOpacity(0.86),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.075)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.07),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const _AdvancedPreviewCard(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Reach your target band\nwith intelligent preparation',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 29,
            height: 1.16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Personalized lessons, realistic mock tests and AI feedback for every IELTS skill.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            height: 1.55,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _AdvancedPreviewCard extends StatelessWidget {
  const _AdvancedPreviewCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 235,
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: _previewDecoration(),
              child: const Row(
                children: [
                  _BandRing(),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your IELTS Readiness',
                          style: TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'AI-powered progress toward Band 7.0',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10.5,
                          ),
                        ),
                        SizedBox(height: 10),
                        _MiniProgressBar(),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF67E8F9),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 106,
            left: 0,
            child: _SkillPreviewCard(
              icon: Icons.headphones_rounded,
              title: 'Listening',
              band: '6.5',
              accent: Color(0xFF22D3EE),
            ),
          ),
          const Positioned(
            top: 106,
            right: 0,
            child: _SkillPreviewCard(
              icon: Icons.edit_note_rounded,
              title: 'Writing',
              band: '5.5',
              accent: Color(0xFFA78BFA),
            ),
          ),
          Positioned(
            left: 58,
            right: 58,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1D4ED8),
                    Color(0xFF0891B2),
                    Color(0xFF6D28D9),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.psychology_alt_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Personal AI Coach',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BandRing extends StatelessWidget {
  const _BandRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFF2563EB),
            Color(0xFF06B6D4),
            Color(0xFF8B5CF6),
            Color(0xFF2563EB),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withOpacity(0.18),
            blurRadius: 16,
          ),
        ],
      ),
      child: Container(
        width: 53,
        height: 53,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2B),
          shape: BoxShape.circle,
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '64%',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 16,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Ready',
              style: TextStyle(
                color: Color(0xFF67E8F9),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: const LinearProgressIndicator(
        value: 0.64,
        minHeight: 6,
        backgroundColor: Color(0xFF1E293B),
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
      ),
    );
  }
}

class _SkillPreviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String band;
  final Color accent;

  const _SkillPreviewCard({
    required this.icon,
    required this.title,
    required this.band,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 137,
      height: 92,
      padding: const EdgeInsets.all(13),
      decoration: _previewDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const Spacer(),
              Text(
                band,
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFDDEAFE),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF101C2E).withOpacity(0.9),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2A3F),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: const Color(0xFF67E8F9), size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF94A3B8),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _SocialButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF101C2E).withOpacity(0.9),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withOpacity(0.075)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFF8FAFC), size: 24),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestIcon extends StatelessWidget {
  const _GuestIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.visibility_outlined,
        color: Color(0xFFA78BFA),
        size: 21,
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF64748B),
              size: 13,
            ),
            SizedBox(width: 6),
            Text(
              'Secure sign-in • Your data stays protected',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 9.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            text: 'By continuing, you agree to our ',
            children: const [
              TextSpan(
                text: 'Terms',
                style: TextStyle(
                  color: Color(0xFF67E8F9),
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(
                  color: Color(0xFF67E8F9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 9.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _GuestAccessSheet extends StatelessWidget {
  const _GuestAccessSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        22 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1726),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6D28D9),
                  Color(0xFF8B5CF6),
                  Color(0xFF06B6D4),
                ],
              ),
            ),
            child: const Icon(
              Icons.visibility_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'Guest Access',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore selected features before creating an account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const _GuestFeatureRow(
            icon: Icons.play_lesson_outlined,
            title: 'One sample lesson',
            enabled: true,
          ),
          const _GuestFeatureRow(
            icon: Icons.quiz_outlined,
            title: 'One mini test',
            enabled: true,
          ),
          const _GuestFeatureRow(
            icon: Icons.auto_awesome_rounded,
            title: 'Limited AI feedback',
            enabled: true,
          ),
          const _GuestFeatureRow(
            icon: Icons.cloud_off_outlined,
            title: 'Progress is not saved to the cloud',
            enabled: false,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2563EB),
                    Color(0xFF06B6D4),
                    Color(0xFF7C3AED),
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AuthenticationGatewayScreen(
                        initialMode: AuthMode.createAccount,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: const Text(
                  'Continue as Guest',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF94A3B8),
            ),
            child: const Text(
              'Not now',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool enabled;

  const _GuestFeatureRow({
    required this.icon,
    required this.title,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? const Color(0xFF34D399) : const Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF101F31),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.11),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              enabled ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: accent,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBackground extends StatelessWidget {
  const _WelcomeBackground();

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
                Color(0xFF040A13),
                Color(0xFF07111F),
                Color(0xFF09182A),
                Color(0xFF07111F),
              ],
              stops: [0, 0.34, 0.72, 1],
            ),
          ),
        ),
        const Positioned(
          top: -150,
          right: -120,
          child: _GlowOrb(size: 340, color: Color(0x2A2563EB)),
        ),
        const Positioned(
          top: 340,
          left: -160,
          child: _GlowOrb(size: 320, color: Color(0x1606B6D4)),
        ),
        const Positioned(
          bottom: -180,
          right: -150,
          child: _GlowOrb(size: 390, color: Color(0x168B5CF6)),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

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

class _AmbientParticlesPainter extends CustomPainter {
  final double progress;

  _AmbientParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    const points = [
      Offset(0.09, 0.16),
      Offset(0.87, 0.12),
      Offset(0.92, 0.36),
      Offset(0.12, 0.54),
      Offset(0.83, 0.72),
      Offset(0.18, 0.84),
      Offset(0.63, 0.25),
      Offset(0.54, 0.92),
    ];

    for (int index = 0; index < points.length; index++) {
      final point = points[index];
      final angle = (progress * math.pi * 2) + (index * 0.78);

      final x = (point.dx * size.width) + (math.sin(angle) * 4.5);
      final y = (point.dy * size.height) + (math.cos(angle) * 6.5);

      final opacity = 0.04 + ((math.sin(angle) + 1) * 0.035);

      paint.color = index.isEven
          ? const Color(0xFF38BDF8).withOpacity(opacity)
          : const Color(0xFFA78BFA).withOpacity(opacity);

      canvas.drawCircle(Offset(x, y), index % 3 == 0 ? 1.8 : 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

BoxDecoration _previewDecoration() {
  return BoxDecoration(
    color: const Color(0xFF101F31).withOpacity(0.94),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.07)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.12),
        blurRadius: 14,
        offset: const Offset(0, 7),
      ),
    ],
  );
}
