import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AboutColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _AboutBackground()),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildTopBar(context)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeroCard(),
                      const SizedBox(height: 24),
                      _buildAboutSection(),
                      const SizedBox(height: 24),
                      _buildFeaturesSection(),
                      const SizedBox(height: 24),
                      _buildDeveloperSection(),
                      const SizedBox(height: 24),
                      _buildAppInformation(),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              backgroundColor: AboutColors.surface.withOpacity(.92),
              foregroundColor: AboutColors.text,
              side: BorderSide(color: Colors.white.withOpacity(.07)),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About IELTS AI Master',
                  style: TextStyle(
                    color: AboutColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Learn more about the app',
                  style: TextStyle(color: AboutColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AboutColors.gradient,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF18365B), Color(0xFF10263D), Color(0xFF241D46)],
        ),
        border: Border.all(color: Colors.white.withOpacity(.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.24),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          BoxShadow(color: AboutColors.cyan.withOpacity(.07), blurRadius: 30),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: AboutColors.gradient,
              boxShadow: [
                BoxShadow(
                  color: AboutColors.cyan.withOpacity(.22),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 19),
          const Text(
            'IELTS AI Master',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AboutColors.text,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'AI-Powered IELTS Learning Platform',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AboutColors.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            alignment: WrapAlignment.center,
            children: const [
              _HeroBadge(
                icon: Icons.verified_rounded,
                label: 'Version 1.1.2+7',
              ),
              _HeroBadge(icon: Icons.flutter_dash_rounded, label: 'Flutter'),
              _HeroBadge(
                icon: Icons.auto_awesome_rounded,
                label: 'Powered by AI',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return const _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.menu_book_rounded,
            title: 'About the App',
            subtitle: 'Built to support smarter IELTS preparation',
          ),
          SizedBox(height: 16),
          Text(
            'IELTS AI Master is an AI-powered IELTS preparation platform designed to help learners improve their Listening, Reading, Writing and Speaking skills.',
            style: TextStyle(
              color: AboutColors.secondary,
              fontSize: 12.5,
              height: 1.65,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'The app provides intelligent practice, personalized feedback, realistic mock tests and clear progress insights to make preparation more focused and effective.',
            style: TextStyle(
              color: AboutColors.muted,
              fontSize: 12.2,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    const features = [
      _FeatureData(
        icon: Icons.edit_note_rounded,
        title: 'AI Writing Evaluation',
        accent: AboutColors.cyan,
      ),
      _FeatureData(
        icon: Icons.mic_rounded,
        title: 'Speaking Practice',
        accent: AboutColors.violet,
      ),
      _FeatureData(
        icon: Icons.headphones_rounded,
        title: 'Listening Practice',
        accent: AboutColors.orange,
      ),
      _FeatureData(
        icon: Icons.auto_stories_rounded,
        title: 'Reading Practice',
        accent: AboutColors.green,
      ),
      _FeatureData(
        icon: Icons.analytics_outlined,
        title: 'Progress Analytics',
        accent: AboutColors.blue,
      ),
      _FeatureData(
        icon: Icons.workspace_premium_rounded,
        title: 'Certificates',
        accent: AboutColors.pink,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: Icons.auto_awesome_rounded,
          title: 'Core Features',
          subtitle: 'Everything needed for complete IELTS practice',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: features
                  .map(
                    (feature) => SizedBox(
                      width: width,
                      child: _FeatureCard(feature: feature),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDeveloperSection() {
    return const _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeveloperLogo(),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Developed by',
                  style: TextStyle(
                    color: AboutColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Rashid Apps',
                  style: TextStyle(
                    color: AboutColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Software Engineer & Flutter Developer',
                  style: TextStyle(
                    color: AboutColors.secondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Focused on building modern, reliable and intelligent mobile applications.',
                  style: TextStyle(
                    color: AboutColors.muted,
                    fontSize: 10.8,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInformation() {
    return const _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.memory_rounded,
            title: 'App Information',
            subtitle: 'Technical and release details',
          ),
          SizedBox(height: 16),
          _InformationRow(label: 'Version', value: '1.1.2+7'),
          _Divider(),
          _InformationRow(label: 'Build', value: '1.0.0+7'),
          _Divider(),
          _InformationRow(label: 'Platform', value: 'Flutter + Firebase'),
          _Divider(),
          _InformationRow(
            label: 'Artificial Intelligence',
            value: 'Google Gemini',
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.07),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AboutColors.cyan, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AboutColors.secondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AboutColors.cyan.withOpacity(.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AboutColors.cyan, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AboutColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AboutColors.muted,
                  fontSize: 10.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _FeatureData feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AboutColors.surface.withOpacity(.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: feature.accent.withOpacity(.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(feature.icon, color: feature.accent, size: 21),
          ),
          const SizedBox(height: 14),
          Text(
            feature.title,
            style: const TextStyle(
              color: AboutColors.text,
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperLogo extends StatelessWidget {
  const _DeveloperLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: AboutColors.gradient,
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: AboutColors.blue.withOpacity(.20),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: const Icon(Icons.code_rounded, color: Colors.white, size: 28),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AboutColors.muted, fontSize: 11.5),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AboutColors.text,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AboutColors.surface.withOpacity(.91),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white.withOpacity(.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: indent,
      endIndent: 16,
      color: Colors.white.withOpacity(.055),
    );
  }
}

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.title,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final Color accent;
}

class _AboutBackground extends StatelessWidget {
  const _AboutBackground();

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
                Color(0xFF030914),
                Color(0xFF07111F),
                Color(0xFF09182A),
                Color(0xFF07111F),
              ],
            ),
          ),
        ),
        const Positioned(
          top: -170,
          right: -135,
          child: _GlowOrb(size: 370, color: Color(0x282563EB)),
        ),
        const Positioned(
          top: 430,
          left: -180,
          child: _GlowOrb(size: 350, color: Color(0x1506B6D4)),
        ),
        const Positioned(
          bottom: -190,
          right: -150,
          child: _GlowOrb(size: 410, color: Color(0x158B5CF6)),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

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

class AboutColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF101C2E);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
  static const subtle = Color(0xFF64748B);

  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF34D399);
  static const orange = Color(0xFFF59E0B);
  static const pink = Color(0xFFF472B6);

  static const gradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}
