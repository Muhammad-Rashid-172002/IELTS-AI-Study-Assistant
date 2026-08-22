import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpAndSupportScreen extends StatefulWidget {
  const HelpAndSupportScreen({super.key});

  @override
  State<HelpAndSupportScreen> createState() => _HelpAndSupportScreenState();
}

class _HelpAndSupportScreenState extends State<HelpAndSupportScreen> {
  static const String _supportEmail = 'muhammadrashid172002@gmail.com';
  static const String _privacyPolicyUrl =
      'https://your-domain.com/privacy-policy';
  static const String _termsUrl = 'https://your-domain.com/terms';

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _faqSectionKey = GlobalKey();

  String _searchQuery = '';
  int? _expandedFaqIndex;

  final List<_FaqItem> _faqs = const [
    _FaqItem(
      question: 'How does IELTS AI Master evaluate my answers?',
      answer:
          'IELTS AI Master analyses your response using IELTS-focused assessment criteria. Writing feedback covers task response, coherence, vocabulary and grammar, while speaking feedback focuses on fluency, pronunciation, vocabulary and grammatical accuracy.',
      category: 'AI Feedback',
    ),
    _FaqItem(
      question: 'Is my progress saved automatically?',
      answer:
          'Yes. When you are signed in, completed practice sessions, test results and progress information are securely saved to your account and synchronized across supported devices.',
      category: 'Account',
    ),
    _FaqItem(
      question: 'How can I improve my estimated band score?',
      answer:
          'Practise consistently, review the detailed feedback after every attempt, focus on weak skill areas and complete full mock tests under realistic time limits.',
      category: 'Learning',
    ),
    _FaqItem(
      question: 'Why is the AI response taking longer than expected?',
      answer:
          'AI feedback can occasionally take longer because of internet speed, server demand or the length of your answer. Keep the app open and check that your internet connection is stable.',
      category: 'Technical',
    ),
    _FaqItem(
      question: 'How do I reset my password?',
      answer:
          'Open the Sign In screen, select “Forgot Password?”, enter your registered email address and follow the password reset link sent to your inbox.',
      category: 'Account',
    ),
    _FaqItem(
      question: 'Can I use the app without an internet connection?',
      answer:
          'Some interface content may remain visible, but AI evaluation, cloud synchronization and most dynamic learning features require an active internet connection.',
      category: 'Technical',
    ),
    _FaqItem(
      question: 'How do I report incorrect AI feedback?',
      answer:
          'Use the “Report a problem” option on this screen. Include the module name, what happened and any relevant details so the issue can be reviewed accurately.',
      category: 'AI Feedback',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_FaqItem> get _filteredFaqs {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _faqs;

    return _faqs.where((faq) {
      return faq.question.toLowerCase().contains(query) ||
          faq.answer.toLowerCase().contains(query) ||
          faq.category.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Unable to open this link.', isError: true);
    }
  }

  Future<void> _sendSupportEmail({
    String subject = 'IELTS AI Master Support',
    String body = '',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {'subject': subject, if (body.isNotEmpty) 'body': body},
    );

    if (!await launchUrl(uri)) {
      await Clipboard.setData(const ClipboardData(text: _supportEmail));

      if (!mounted) return;
      _showMessage('Support email copied: $_supportEmail', isError: false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? SupportColors.error
              : SupportColors.success,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  void _openReportProblemSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportProblemSheet(
        onSubmit: (subject, description) async {
          Navigator.of(context).pop();

          final emailBody =
              'Issue category: $subject\n\n'
              'Description:\n$description\n\n'
              'App: IELTS AI Master\n'
              'Platform: ${Theme.of(context).platform.name}';

          await _sendSupportEmail(
            subject: 'IELTS AI Master Issue: $subject',
            body: emailBody,
          );
        },
      ),
    );
  }

  void _openFaqs() {
    final faqContext = _faqSectionKey.currentContext;
    if (faqContext == null) return;

    Scrollable.ensureVisible(
      faqContext,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupportColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _SupportBackground()),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildTopBar()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeroSection(),
                      const SizedBox(height: 22),
                      _buildQuickSupportGrid(),
                      const SizedBox(height: 28),
                      _buildFaqSection(),
                      const SizedBox(height: 28),
                      _buildStillNeedHelpCard(),
                      const SizedBox(height: 20),
                      _buildLegalAndAppInfo(),
                      const SizedBox(height: 16),
                      const _SecurityFooter(),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              backgroundColor: SupportColors.surface.withOpacity(0.92),
              foregroundColor: SupportColors.primaryText,
              side: BorderSide(color: Colors.white.withOpacity(0.07)),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & Support',
                  style: TextStyle(
                    color: SupportColors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'We are here to help you succeed',
                  style: TextStyle(
                    color: SupportColors.mutedText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              gradient: SupportColors.primaryGradient,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: SupportColors.cyan.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13233A), Color(0xFF0D1B2D), Color(0xFF101A31)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: SupportColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: SupportColors.cyan.withOpacity(0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'How can we help?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SupportColors.primaryText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search common questions or contact our support team for assistance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SupportColors.secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 19),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _expandedFaqIndex = null;
              });
            },
            style: const TextStyle(
              color: SupportColors.primaryText,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: SupportColors.cyan,
            decoration: InputDecoration(
              hintText: 'Search help articles and questions',
              hintStyle: const TextStyle(
                color: SupportColors.subtleText,
                fontSize: 12.5,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: SupportColors.mutedText,
                size: 21,
              ),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _expandedFaqIndex = null;
                        });
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: SupportColors.mutedText,
                        size: 19,
                      ),
                    ),
              filled: true,
              fillColor: SupportColors.background.withOpacity(0.75),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 17,
              ),
              border: _inputBorder(SupportColors.border),
              enabledBorder: _inputBorder(SupportColors.border),
              focusedBorder: _inputBorder(SupportColors.cyan, width: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSupportGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Quick support',
          subtitle: 'Choose the type of help you need',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _SupportActionCard(
                    icon: Icons.help_outline_rounded,
                    title: 'FAQs',
                    subtitle: 'Find quick answers',
                    accent: SupportColors.cyan,
                    onTap: _openFaqs,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _SupportActionCard(
                    icon: Icons.bug_report_outlined,
                    title: 'Report issue',
                    subtitle: 'Tell us what happened',
                    accent: SupportColors.violet,
                    onTap: _openReportProblemSheet,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _SupportActionCard(
                    icon: Icons.mail_outline_rounded,
                    title: 'Email support',
                    subtitle: 'Contact our team',
                    accent: SupportColors.green,
                    onTap: () => _sendSupportEmail(),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _SupportActionCard(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy',
                    subtitle: 'Review data handling',
                    accent: SupportColors.orange,
                    onTap: () => _launchExternalUrl(_privacyPolicyUrl),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFaqSection() {
    final filteredFaqs = _filteredFaqs;

    return Container(
      key: _faqSectionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: 'Frequently asked questions',
            subtitle: _searchQuery.isEmpty
                ? 'Helpful answers for common questions'
                : '${filteredFaqs.length} result${filteredFaqs.length == 1 ? '' : 's'} found',
          ),
          const SizedBox(height: 14),
          if (filteredFaqs.isEmpty)
            _buildEmptySearchState()
          else
            Container(
              decoration: BoxDecoration(
                color: SupportColors.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: ListView.separated(
                itemCount: filteredFaqs.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 18,
                  endIndent: 18,
                  color: Colors.white.withOpacity(0.055),
                ),
                itemBuilder: (context, index) {
                  final faq = filteredFaqs[index];
                  final isExpanded = _expandedFaqIndex == index;

                  return _FaqTile(
                    faq: faq,
                    isExpanded: isExpanded,
                    onTap: () {
                      setState(() {
                        _expandedFaqIndex = isExpanded ? null : index;
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: SupportColors.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: SupportColors.cyan, size: 34),
          SizedBox(height: 14),
          Text(
            'No matching answers found',
            style: TextStyle(
              color: SupportColors.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try different keywords or contact our support team.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SupportColors.mutedText,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStillNeedHelpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17345B), Color(0xFF12304A), Color(0xFF27204A)],
        ),
        border: Border.all(color: SupportColors.cyan.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SupportAvatar(),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Still need help?',
                      style: TextStyle(
                        color: SupportColors.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Send us the details and our support team will help you resolve the issue.',
                      style: TextStyle(
                        color: SupportColors.secondaryText,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: SupportColors.primaryGradient,
                borderRadius: BorderRadius.circular(17),
              ),
              child: ElevatedButton.icon(
                onPressed: _openReportProblemSheet,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
                label: const Text(
                  'Contact Support',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule_rounded,
                color: SupportColors.mutedText,
                size: 14,
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Typical response time: within 24–48 hours',
                  style: TextStyle(
                    color: SupportColors.mutedText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegalAndAppInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Information',
          subtitle: 'Legal documents and app details',
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: SupportColors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            children: [
              _InfoTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'Learn how your information is protected',
                onTap: () => _launchExternalUrl(_privacyPolicyUrl),
              ),
              _infoDivider(),
              _InfoTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Review the terms for using IELTS AI Master',
                onTap: () => _launchExternalUrl(_termsUrl),
              ),
              _infoDivider(),
              const _InfoTile(
                icon: Icons.info_outline_rounded,
                title: 'App version',
                subtitle: 'IELTS AI Master • Version 1.0.0',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoDivider() {
    return Divider(
      height: 1,
      indent: 64,
      endIndent: 18,
      color: Colors.white.withOpacity(0.055),
    );
  }
}

class _SupportActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _SupportActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SupportColors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 21),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.north_east_rounded,
                    color: accent.withOpacity(0.8),
                    size: 17,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  color: SupportColors.primaryText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: SupportColors.mutedText,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _FaqItem faq;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FaqTile({
    required this.faq,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 16, 15, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: SupportColors.cyan.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.question_mark_rounded,
                    color: SupportColors.cyan,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        faq.question,
                        style: const TextStyle(
                          color: SupportColors.primaryText,
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isExpanded) ...[
                        const SizedBox(height: 9),
                        Text(
                          faq.answer,
                          style: const TextStyle(
                            color: SupportColors.mutedText,
                            fontSize: 11.5,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: SupportColors.blue.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            faq.category,
                            style: const TextStyle(
                              color: SupportColors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 220),
                  turns: isExpanded ? 0.5 : 0,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: SupportColors.mutedText,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SupportColors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: SupportColors.cyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: SupportColors.primaryText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: SupportColors.mutedText,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: SupportColors.subtleText,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportProblemSheet extends StatefulWidget {
  final Future<void> Function(String subject, String description) onSubmit;

  const _ReportProblemSheet({required this.onSubmit});

  @override
  State<_ReportProblemSheet> createState() => _ReportProblemSheetState();
}

class _ReportProblemSheetState extends State<_ReportProblemSheet> {
  final TextEditingController _descriptionController = TextEditingController();

  String _category = 'Technical issue';
  bool _isSubmitting = false;

  final List<String> _categories = const [
    'Technical issue',
    'Account problem',
    'Payment or subscription',
    'Incorrect AI feedback',
    'Feature request',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();

    if (description.length < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least 15 characters.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(_category, description);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B1726),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            22 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: SupportColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  _SheetIcon(),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report a problem',
                          style: TextStyle(
                            color: SupportColors.primaryText,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Share enough detail so we can investigate.',
                          style: TextStyle(
                            color: SupportColors.mutedText,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 21),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: SupportColors.surface,
                iconEnabledColor: SupportColors.cyan,
                style: const TextStyle(
                  color: SupportColors.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Issue category',
                  labelStyle: const TextStyle(
                    color: SupportColors.mutedText,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.category_outlined,
                    color: SupportColors.mutedText,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: SupportColors.surface,
                  border: _inputBorder(SupportColors.border),
                  enabledBorder: _inputBorder(SupportColors.border),
                  focusedBorder: _inputBorder(SupportColors.cyan, width: 1.3),
                ),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 13),
              TextField(
                controller: _descriptionController,
                minLines: 5,
                maxLines: 7,
                maxLength: 800,
                style: const TextStyle(
                  color: SupportColors.primaryText,
                  fontSize: 13,
                  height: 1.45,
                ),
                cursorColor: SupportColors.cyan,
                decoration: InputDecoration(
                  labelText: 'Describe the problem',
                  hintText:
                      'What were you doing, what happened and what did you expect?',
                  alignLabelWithHint: true,
                  labelStyle: const TextStyle(
                    color: SupportColors.mutedText,
                    fontSize: 12,
                  ),
                  hintStyle: const TextStyle(
                    color: SupportColors.subtleText,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                  filled: true,
                  fillColor: SupportColors.surface,
                  border: _inputBorder(SupportColors.border),
                  enabledBorder: _inputBorder(SupportColors.border),
                  focusedBorder: _inputBorder(SupportColors.cyan, width: 1.3),
                ),
              ),
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: SupportColors.primaryGradient,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 19),
                    label: Text(
                      _isSubmitting ? 'Opening email...' : 'Submit Report',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            gradient: SupportColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: SupportColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: SupportColors.mutedText,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupportAvatar extends StatelessWidget {
  const _SupportAvatar();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: SupportColors.primaryGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: SupportColors.green,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF17345B), width: 3),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetIcon extends StatelessWidget {
  const _SheetIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: SupportColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.bug_report_outlined,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _SecurityFooter extends StatelessWidget {
  const _SecurityFooter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          color: SupportColors.subtleText,
          size: 13,
        ),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Secure support • Your information stays protected',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SupportColors.subtleText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportBackground extends StatelessWidget {
  const _SupportBackground();

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
              stops: [0, 0.35, 0.72, 1],
            ),
          ),
        ),
        const Positioned(
          top: -170,
          right: -130,
          child: _GlowOrb(size: 360, color: Color(0x252563EB)),
        ),
        const Positioned(
          top: 420,
          left: -180,
          child: _GlowOrb(size: 340, color: Color(0x1406B6D4)),
        ),
        const Positioned(
          bottom: -190,
          right: -150,
          child: _GlowOrb(size: 400, color: Color(0x148B5CF6)),
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

class _FaqItem {
  final String question;
  final String answer;
  final String category;

  const _FaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

class SupportColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF101C2E);
  static const primaryText = Color(0xFFF8FAFC);
  static const secondaryText = Color(0xFFCBD5E1);
  static const mutedText = Color(0xFF94A3B8);
  static const subtleText = Color(0xFF64748B);
  static const border = Color(0xFF26364A);

  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF34D399);
  static const orange = Color(0xFFF59E0B);
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFDC2626);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
}
