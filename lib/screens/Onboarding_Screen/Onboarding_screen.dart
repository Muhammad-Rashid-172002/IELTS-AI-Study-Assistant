import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/registration/registration.dart';

class PremiumOnboardingScreen extends StatefulWidget {
  const PremiumOnboardingScreen({super.key});

  @override
  State<PremiumOnboardingScreen> createState() =>
      _PremiumOnboardingScreenState();
}

class _PremiumOnboardingScreenState extends State<PremiumOnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _backgroundController;

  int _currentPage = 0;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      title: 'Personalized Learning',
      description: 'Study according to your current level and target band.',
      eyebrow: 'BUILT AROUND YOU',
      icon: Icons.auto_awesome_rounded,
      type: _OnboardingVisualType.personalized,
    ),
    _OnboardingData(
      title: 'Complete IELTS Preparation',
      description:
          'Practice Listening, Reading, Writing and Speaking in one app.',
      eyebrow: 'ALL FOUR SKILLS',
      icon: Icons.grid_view_rounded,
      type: _OnboardingVisualType.modules,
    ),
    _OnboardingData(
      title: 'AI-Powered Feedback',
      description:
          'Receive instant band estimates, corrections and improvement tips.',
      eyebrow: 'SMARTER IMPROVEMENT',
      icon: Icons.psychology_alt_rounded,
      type: _OnboardingVisualType.feedback,
    ),
    _OnboardingData(
      title: 'Realistic Mock Tests',
      description:
          'Experience Academic and General Training mock tests under real exam conditions.',
      eyebrow: 'EXAM-READY',
      icon: Icons.timer_outlined,
      type: _OnboardingVisualType.mock,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _nextPage() {
    if (_isLastPage) {
      _openNextScreen();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  void _openNextScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, animation, secondaryAnimation) {
          return const RegistrationScreen();
        },
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          final slide =
              Tween<Offset>(
                begin: const Offset(0.06, 0),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: Stack(
        children: [
          const Positioned.fill(child: _OnboardingBackground()),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _FloatingParticlesPainter(
                    progress: _backgroundController.value,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final page = _pages[index];

                      return _OnboardingPage(
                        data: page,
                        pageIndex: index,
                        currentPage: _currentPage,
                      );
                    },
                  ),
                ),
                _buildBottomSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 6),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2563EB),
                  Color(0xFF06B6D4),
                  Color(0xFF8B5CF6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.18),
                  blurRadius: 18,
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
                  letterSpacing: 2.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _isLastPage ? 0 : 1,
            child: IgnorePointer(
              ignoring: _isLastPage,
              child: TextButton(
                onPressed: _skip,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF07111F).withOpacity(0.94),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(
                    _pages.length,
                    (index) => _PageIndicator(isActive: index == _currentPage),
                  ),
                ),
              ),
              Text(
                '${_currentPage + 1} / ${_pages.length}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2563EB),
                    Color(0xFF06B6D4),
                    Color(0xFF7C3AED),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Row(
                    key: ValueKey<bool>(_isLastPage),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLastPage ? 'Get Started' : 'Continue',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Icon(
                        _isLastPage
                            ? Icons.rocket_launch_rounded
                            : Icons.arrow_forward_rounded,
                        size: 21,
                      ),
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
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final int pageIndex;
  final int currentPage;

  const _OnboardingPage({
    required this.data,
    required this.pageIndex,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    final isVisible = pageIndex == currentPage;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 420),
      opacity: isVisible ? 1 : 0.45,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
        scale: isVisible ? 1 : 0.96,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Column(
            children: [
              const SizedBox(height: 4),
              _OnboardingVisual(type: data.type),
              const SizedBox(height: 32),
              _EyebrowLabel(text: data.eyebrow, icon: data.icon),
              const SizedBox(height: 14),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 29,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.75,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14.5,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EyebrowLabel extends StatelessWidget {
  final String text;
  final IconData icon;

  const _EyebrowLabel({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2236).withOpacity(0.92),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF67E8F9), size: 14),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFBAE6FD),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  final _OnboardingVisualType type;

  const _OnboardingVisual({required this.type});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.08,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: const Color(0xFF0C1828).withOpacity(0.84),
          border: Border.all(color: Colors.white.withOpacity(0.075)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.08),
              blurRadius: 34,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _VisualGrid()),
            if (type == _OnboardingVisualType.personalized)
              const _PersonalizedVisual(),
            if (type == _OnboardingVisualType.modules) const _ModulesVisual(),
            if (type == _OnboardingVisualType.feedback) const _FeedbackVisual(),
            if (type == _OnboardingVisualType.mock) const _MockVisual(),
          ],
        ),
      ),
    );
  }
}

class _PersonalizedVisual extends StatelessWidget {
  const _PersonalizedVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 2,
          top: 6,
          child: _MiniLabel(
            icon: Icons.route_rounded,
            label: 'AI Learning Path',
          ),
        ),
        Positioned(
          top: 54,
          left: 2,
          right: 2,
          child: Container(
            height: 104,
            padding: const EdgeInsets.all(14),
            decoration: _visualCardDecoration(),
            child: CustomPaint(painter: _ProgressGraphPainter()),
          ),
        ),
        Positioned(
          left: 2,
          right: 2,
          bottom: 4,
          child: Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Current Band',
                  value: '5.5',
                  subtitle: 'Improving',
                  icon: Icons.insights_rounded,
                  accent: const Color(0xFF22D3EE),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Target Band',
                  value: '7.0',
                  subtitle: '12-week plan',
                  icon: Icons.flag_rounded,
                  accent: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 13,
          top: 69,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.55),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.25),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModulesVisual extends StatelessWidget {
  const _ModulesVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: Row(
            children: [
              Expanded(
                child: _ModuleCard(
                  icon: Icons.headphones_rounded,
                  title: 'Listening',
                  band: '6.5',
                  accent: Color(0xFF22D3EE),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ModuleCard(
                  icon: Icons.menu_book_rounded,
                  title: 'Reading',
                  band: '6.0',
                  accent: Color(0xFF60A5FA),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        const Expanded(
          child: Row(
            children: [
              Expanded(
                child: _ModuleCard(
                  icon: Icons.edit_note_rounded,
                  title: 'Writing',
                  band: '5.5',
                  accent: Color(0xFFA78BFA),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ModuleCard(
                  icon: Icons.mic_rounded,
                  title: 'Speaking',
                  band: '6.0',
                  accent: Color(0xFF34D399),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: _visualCardDecoration(),
          child: const Row(
            children: [
              _CircleProgress(value: '64%'),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Overall Readiness',
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'All four skills in one personalized journey.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF67E8F9),
                size: 19,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeedbackVisual extends StatelessWidget {
  const _FeedbackVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _visualCardDecoration(),
          child: const Row(
            children: [
              _BandCircle(band: '6.5'),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Writing Evaluation',
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    _ScoreBar(
                      label: 'Task Response',
                      value: 0.72,
                      accent: Color(0xFF22D3EE),
                    ),
                    SizedBox(height: 7),
                    _ScoreBar(
                      label: 'Grammar',
                      value: 0.61,
                      accent: Color(0xFF8B5CF6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _visualCardDecoration(),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            color: Color(0xFF34D399),
                            size: 18,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'Speaking',
                            style: TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      _Waveform(),
                      Spacer(),
                      Text(
                        'Fluency improved',
                        style: TextStyle(
                          color: Color(0xFF6EE7B7),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _visualCardDecoration(),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_fix_high_rounded,
                            color: Color(0xFF67E8F9),
                            size: 18,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'AI Insight',
                            style: TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Improve paragraph linking and reduce repeated vocabulary.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          height: 1.45,
                        ),
                      ),
                      Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            color: Color(0xFF34D399),
                            size: 16,
                          ),
                          SizedBox(width: 5),
                          Text(
                            '+0.5 band',
                            style: TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MockVisual extends StatelessWidget {
  const _MockVisual();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const designHeight = 310.0;

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth,
              height: designHeight,
              child: Column(
                children: [
                  // Top section
                  SizedBox(
                    height: 90,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: _visualCardDecoration(),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FULL MOCK TEST',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFF67E8F9),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Academic',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFFF8FAFC),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Real exam simulation',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 88,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1D4ED8), Color(0xFF0891B2)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF06B6D4,
                                ).withOpacity(0.18),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                color: Colors.white,
                                size: 21,
                              ),
                              SizedBox(height: 4),
                              Text(
                                '59:42',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Remaining',
                                maxLines: 1,
                                style: TextStyle(
                                  color: Color(0xFFBAE6FD),
                                  fontSize: 8.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Question navigation
                  SizedBox(
                    height: 120,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: _visualCardDecoration(),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Question Navigation',
                            style: TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 10),
                          Expanded(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: _QuestionPalette(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Result section
                  SizedBox(
                    height: 80,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: _visualCardDecoration(),
                      child: const Row(
                        children: [
                          _ResponsiveBandCircle(band: '7.0'),
                          SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Mock Test Result',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFFF8FAFC),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Detailed score, timing and skill analysis.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 9.5,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.analytics_outlined,
                            color: Color(0xFF67E8F9),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResponsiveBandCircle extends StatelessWidget {
  final String band;

  const _ResponsiveBandCircle({required this.band});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
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
            blurRadius: 14,
          ),
        ],
      ),
      child: Container(
        width: 43,
        height: 43,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2B),
          shape: BoxShape.circle,
        ),
        child: Text(
          band,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String band;
  final Color accent;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.band,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // height: 91,  remove this
      padding: const EdgeInsets.all(11),
      decoration: _visualCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const Spacer(),
              Text(
                band,
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 93,
      padding: const EdgeInsets.all(13),
      decoration: _visualCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              color: accent,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF12253A),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF67E8F9), size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFBAE6FD),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BandCircle extends StatelessWidget {
  final String band;

  const _BandCircle({required this.band});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
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
        width: 51,
        height: 51,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2B),
          shape: BoxShape.circle,
        ),
        child: Text(
          band,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CircleProgress extends StatelessWidget {
  final String value;

  const _CircleProgress({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [Color(0xFF22D3EE), Color(0xFF2563EB), Color(0xFF8B5CF6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22D3EE).withOpacity(0.17),
            blurRadius: 14,
          ),
        ],
      ),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2B),
          shape: BoxShape.circle,
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final Color accent;

  const _ScoreBar({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 69,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 8.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform();

  @override
  Widget build(BuildContext context) {
    const heights = [12.0, 22.0, 15.0, 29.0, 18.0, 34.0, 21.0, 27.0];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: heights.map((height) {
        return Container(
          width: 4,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFF2563EB), Color(0xFF22D3EE)],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuestionPalette extends StatelessWidget {
  const _QuestionPalette();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 7.0;
        const itemCountPerRow = 5;

        final itemWidth =
            (constraints.maxWidth - (spacing * (itemCountPerRow - 1))) /
            itemCountPerRow;

        final itemSize = itemWidth.clamp(27.0, 34.0);

        return Wrap(
          spacing: spacing,
          runSpacing: 7,
          children: List.generate(10, (index) {
            final number = index + 1;
            final isAnswered = number <= 5;
            final isCurrent = number == 6;
            final isFlagged = number == 8;

            Color background = const Color(0xFF16263A);
            Color border = Colors.white.withOpacity(0.07);
            Color textColor = const Color(0xFF94A3B8);

            if (isAnswered) {
              background = const Color(0xFF0F766E).withOpacity(0.34);
              border = const Color(0xFF34D399).withOpacity(0.35);
              textColor = const Color(0xFF6EE7B7);
            }

            if (isCurrent) {
              background = const Color(0xFF2563EB);
              border = const Color(0xFF60A5FA);
              textColor = Colors.white;
            }

            if (isFlagged) {
              background = const Color(0xFF78350F).withOpacity(0.45);
              border = const Color(0xFFF59E0B).withOpacity(0.45);
              textColor = const Color(0xFFFCD34D);
            }

            return SizedBox(
              width: itemWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: itemSize,
                  height: itemSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _VisualGrid extends StatelessWidget {
  const _VisualGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.018)
      ..strokeWidth = 1;

    const spacing = 24.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProgressGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..strokeWidth = 1;

    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = [
      Offset(0, size.height * 0.78),
      Offset(size.width * 0.18, size.height * 0.70),
      Offset(size.width * 0.38, size.height * 0.57),
      Offset(size.width * 0.57, size.height * 0.62),
      Offset(size.width * 0.76, size.height * 0.38),
      Offset(size.width, size.height * 0.20),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final middleX = (current.dx + next.dx) / 2;

      path.cubicTo(middleX, current.dy, middleX, next.dy, next.dx, next.dy);
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF22D3EE).withOpacity(0.12);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF22D3EE), Color(0xFF8B5CF6)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF67E8F9);

    for (final point in points) {
      canvas.drawCircle(point, 3.4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PageIndicator extends StatelessWidget {
  final bool isActive;

  const _PageIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      width: isActive ? 28 : 8,
      height: 8,
      margin: const EdgeInsets.only(right: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isActive
            ? const LinearGradient(
                colors: [
                  Color(0xFF2563EB),
                  Color(0xFF22D3EE),
                  Color(0xFF8B5CF6),
                ],
              )
            : null,
        color: isActive ? null : const Color(0xFF334155),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF22D3EE).withOpacity(0.22),
                  blurRadius: 9,
                ),
              ]
            : null,
      ),
    );
  }
}

class _OnboardingBackground extends StatelessWidget {
  const _OnboardingBackground();

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
          child: _BackgroundGlow(size: 340, color: Color(0x2B2563EB)),
        ),
        const Positioned(
          top: 260,
          left: -150,
          child: _BackgroundGlow(size: 310, color: Color(0x1706B6D4)),
        ),
        const Positioned(
          bottom: -170,
          right: -140,
          child: _BackgroundGlow(size: 370, color: Color(0x168B5CF6)),
        ),
      ],
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _BackgroundGlow({required this.size, required this.color});

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

class _FloatingParticlesPainter extends CustomPainter {
  final double progress;

  _FloatingParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    const positions = [
      Offset(0.08, 0.18),
      Offset(0.86, 0.13),
      Offset(0.91, 0.38),
      Offset(0.13, 0.55),
      Offset(0.83, 0.73),
      Offset(0.19, 0.84),
      Offset(0.63, 0.24),
      Offset(0.54, 0.92),
    ];

    for (int index = 0; index < positions.length; index++) {
      final position = positions[index];
      final angle = (progress * math.pi * 2) + (index * 0.78);

      final x = (position.dx * size.width) + (math.sin(angle) * 4.5);
      final y = (position.dy * size.height) + (math.cos(angle) * 6.5);

      final opacity = 0.04 + ((math.sin(angle) + 1) * 0.035);

      paint.color = index.isEven
          ? const Color(0xFF38BDF8).withOpacity(opacity)
          : const Color(0xFFA78BFA).withOpacity(opacity);

      canvas.drawCircle(Offset(x, y), index % 3 == 0 ? 1.8 : 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

BoxDecoration _visualCardDecoration() {
  return BoxDecoration(
    color: const Color(0xFF101F31).withOpacity(0.92),
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

enum _OnboardingVisualType { personalized, modules, feedback, mock }

class _OnboardingData {
  final String title;
  final String description;
  final String eyebrow;
  final IconData icon;
  final _OnboardingVisualType type;

  const _OnboardingData({
    required this.title,
    required this.description,
    required this.eyebrow,
    required this.icon,
    required this.type,
  });
}
