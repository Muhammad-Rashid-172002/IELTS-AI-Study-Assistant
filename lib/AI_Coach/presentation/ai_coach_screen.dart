import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/registration/Auth_gateway_screen.dart';

import '../data/ai_coach_repository.dart';
import '../models/ai_coach_models.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _repository = AiCoachRepository();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  bool _sending = false;

  static const _suggestedPrompts = <_PromptItem>[
    _PromptItem(
      'Practice today',
      'What should I practice today?',
      Icons.today_rounded,
    ),
    _PromptItem(
      'Writing plan',
      'Create a Band 7 writing plan.',
      Icons.edit_note_rounded,
    ),
    _PromptItem(
      'Speaking cue card',
      'Give me a speaking cue card.',
      Icons.mic_none_rounded,
    ),
    _PromptItem(
      'TFNG help',
      'Explain True/False/Not Given.',
      Icons.fact_check_outlined,
    ),
    _PromptItem(
      '30-day plan',
      'Make a 30-day study plan.',
      Icons.calendar_month_outlined,
    ),
    _PromptItem(
      'Review progress',
      'Review my progress.',
      Icons.analytics_outlined,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send([String? value]) async {
    final message = (value ?? _controller.text).trim();
    if (message.isEmpty || _sending) return;

    FocusScope.of(context).unfocus();

    setState(() => _sending = true);
    _controller.clear();

    try {
      await _repository.sendMessage(message);

      if (!mounted) return;

      await Future<void>.delayed(const Duration(milliseconds: 160));
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'AI Coach response could not be generated. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: CoachColors.danger,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _clearConversation() async {
    final confirmed =
        await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => const _ClearConversationSheet(),
        ) ??
        false;

    if (!confirmed) return;

    await _repository.clearConversation();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Conversation cleared successfully.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: CoachColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _LoginRequiredView();
    }

    return Scaffold(
      backgroundColor: CoachColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _CoachBackground()),
          SafeArea(
            child: Column(
              children: [
                _PremiumAppBar(
                  onRefresh: _repository.refreshProfile,
                  onClear: _clearConversation,
                ),
                Expanded(
                  child: Column(
                    children: [
                      _profileSummary(),
                      _promptChips(),
                      Expanded(child: _conversation()),
                      _composer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileSummary() {
    return StreamBuilder<AiCoachProfile>(
      stream: _repository.watchCoachProfile(),
      builder: (context, snapshot) {
        final profile =
            snapshot.data ??
            const AiCoachProfile(
              overallBand: 0,
              targetBand: 7,
              streak: 0,
              weakestSkill: 'Reading',
              strongestSkill: 'Listening',
              skillBands: {},
              weakQuestionTypes: {},
              completedLessons: 0,
              completedPractice: 0,
              completedMocks: 0,
            );

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: const EdgeInsets.all(17),
          decoration: _heroDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  const _CoachAvatar(),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'IELTS AI Coach',
                              style: TextStyle(
                                color: CoachColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.3,
                              ),
                            ),
                            SizedBox(width: 7),
                            _OnlineBadge(),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Personalized from your real IELTS performance',
                          style: TextStyle(
                            color: CoachColors.secondary,
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _BandBadge(label: 'Current', value: profile.overallBand),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: 'Target',
                      value: profile.targetBand.toStringAsFixed(1),
                      icon: Icons.flag_outlined,
                      accent: CoachColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Focus',
                      value: profile.weakestSkill,
                      icon: Icons.center_focus_strong_rounded,
                      accent: CoachColors.violet,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Streak',
                      value: '${profile.streak} days',
                      icon: Icons.local_fire_department_rounded,
                      accent: CoachColors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _promptChips() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _suggestedPrompts[index];

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _sending ? null : () => _send(prompt.message),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: CoachColors.surface.withOpacity(.88),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CoachColors.border.withOpacity(.9)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(prompt.icon, color: CoachColors.cyan, size: 16),
                    const SizedBox(width: 7),
                    Text(
                      prompt.label,
                      style: const TextStyle(
                        color: CoachColors.secondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _conversation() {
    return StreamBuilder<List<AiCoachMessage>>(
      stream: _repository.watchMessages(),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? const [];

        if (messages.isNotEmpty) {
          _scrollToBottom();
        }

        if (messages.isEmpty && !_sending) {
          return _EmptyConversation(onPromptTap: (prompt) => _send(prompt));
        }

        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 17, 16, 22),
          itemCount: messages.length + (_sending ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (_sending && index == messages.length) {
              return const _TypingMessageBubble();
            }

            return _MessageBubble(message: messages[index]);
          },
        );
      },
    );
  }

  Widget _composer() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        12 + MediaQuery.paddingOf(context).bottom * .15,
      ),
      decoration: BoxDecoration(
        color: CoachColors.surface.withOpacity(.97),
        border: const Border(top: BorderSide(color: CoachColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.22),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: CoachColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? CoachColors.cyan
                      : CoachColors.border,
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                cursorColor: CoachColors.cyan,
                style: const TextStyle(
                  color: CoachColors.text,
                  fontSize: 13.5,
                  height: 1.4,
                ),
                textInputAction: TextInputAction.newline,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Ask your IELTS AI Coach...',
                  hintStyle: TextStyle(
                    color: CoachColors.muted,
                    fontSize: 12.5,
                  ),
                  prefixIcon: Icon(
                    Icons.auto_awesome_rounded,
                    color: CoachColors.cyan,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: _sending
                  ? null
                  : const LinearGradient(
                      colors: [
                        CoachColors.blue,
                        CoachColors.cyan,
                        CoachColors.violet,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: _sending ? CoachColors.surfaceLight : null,
              borderRadius: BorderRadius.circular(17),
              boxShadow: _sending
                  ? null
                  : [
                      BoxShadow(
                        color: CoachColors.blue.withOpacity(.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _sending ? null : _send,
                borderRadius: BorderRadius.circular(17),
                child: Center(
                  child: _sending
                      ? const _CompactTypingIndicator()
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 23,
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

class _PremiumAppBar extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onClear;

  const _PremiumAppBar({required this.onRefresh, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: CoachColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CoachColors.border),
            ),
            child: const Icon(
              Icons.psychology_alt_rounded,
              color: CoachColors.cyan,
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Coach',
                  style: TextStyle(
                    color: CoachColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your private IELTS study assistant',
                  style: TextStyle(color: CoachColors.muted, fontSize: 9.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh progress',
            onPressed: onRefresh,
            style: IconButton.styleFrom(
              backgroundColor: CoachColors.surface,
              foregroundColor: CoachColors.secondary,
            ),
            icon: const Icon(Icons.sync_rounded, size: 20),
          ),
          PopupMenuButton<String>(
            color: CoachColors.surfaceLight,
            iconColor: CoachColors.secondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'clear') onClear();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_sweep_outlined,
                      color: CoachColors.danger,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Clear conversation',
                      style: TextStyle(color: CoachColors.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiCoachMessage message;

  const _MessageBubble({required this.message});

  static const Set<String> _sectionHeadings = {
    'TITLE',
    'OVERVIEW',
    'KEY POINTS',
    'COACH TIP',
    'NEXT STEP',
    'SPEAKING CUE CARD',
    'YOU SHOULD SAY',
    'BAND IMPROVEMENT TIPS',
    'PRACTICE STEPS',
    'QUESTION',
    'TOPIC',
    'WRITING PLAN',
    'STUDY PLAN',
    'MODEL ANSWER',
    'ESTIMATED BAND',
    'STRENGTHS',
    'AREAS TO IMPROVE',
    'IMPROVEMENT PLAN',
  };

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[const _MessageAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .79,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? const LinearGradient(
                          colors: [CoachColors.blue, CoachColors.violet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isUser ? null : CoachColors.surface.withOpacity(.96),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 20),
                  ),
                  border: isUser ? null : Border.all(color: CoachColors.border),
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
                    if (!isUser) ...[
                      const Row(
                        children: [
                          Text(
                            'IELTS AI COACH',
                            style: TextStyle(
                              color: CoachColors.cyan,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.verified_rounded,
                            color: CoachColors.cyan,
                            size: 13,
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                    ],

                    isUser
                        ? SelectableText(
                            message.text,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.5,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : _buildFormattedAiMessage(message.text),

                    if (message.suggestions.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: message.suggestions
                            .map(
                              (suggestion) =>
                                  _SmallSuggestion(label: suggestion),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedAiMessage(String text) {
    final lines = text.split('\n');
    final spans = <TextSpan>[];

    for (var index = 0; index < lines.length; index++) {
      final originalLine = lines[index];
      final trimmedLine = originalLine.trim();
      final upperCaseLine = trimmedLine.toUpperCase();

      if (trimmedLine.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      final isSectionHeading = _sectionHeadings.contains(upperCaseLine);
      final isColonHeading = _isShortColonHeading(trimmedLine);
      final isBullet = trimmedLine.startsWith('•');
      final isNumberedStep = RegExp(r'^\d+\.\s').hasMatch(trimmedLine);

      if (isSectionHeading) {
        spans.add(
          TextSpan(
            text: '$trimmedLine\n',
            style: const TextStyle(
              color: CoachColors.cyan,
              fontSize: 15,
              height: 1.8,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
        );
      } else if (isColonHeading) {
        spans.add(
          TextSpan(
            text: '$trimmedLine\n',
            style: const TextStyle(
              color: CoachColors.text,
              fontSize: 14,
              height: 1.65,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      } else if (isBullet) {
        spans.add(
          TextSpan(
            text: '$trimmedLine\n',
            style: const TextStyle(
              color: CoachColors.secondary,
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } else if (isNumberedStep) {
        spans.add(
          TextSpan(
            text: '$trimmedLine\n',
            style: const TextStyle(
              color: CoachColors.secondary,
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$originalLine\n',
            style: const TextStyle(
              color: CoachColors.text,
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.start,
    );
  }

  bool _isShortColonHeading(String line) {
    if (!line.endsWith(':')) return false;

    final withoutColon = line.substring(0, line.length - 1).trim();
    final wordCount = withoutColon.split(RegExp(r'\s+')).length;

    return wordCount <= 5 && withoutColon.length <= 45;
  }
}

class _TypingMessageBubble extends StatelessWidget {
  const _TypingMessageBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [_MessageAvatar(), SizedBox(width: 8), _TypingCard()],
      ),
    );
  }
}

class _TypingCard extends StatelessWidget {
  const _TypingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CoachColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: CoachColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedTypingDots(),
          SizedBox(width: 9),
          Text(
            'AI Coach is typing',
            style: TextStyle(
              color: CoachColors.secondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTypingDots extends StatefulWidget {
  const _AnimatedTypingDots();

  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_animationController.value - index * .18) % 1.0;
            final rise = phase < .5 ? phase * 2 : (1 - phase) * 2;

            return Transform.translate(
              offset: Offset(0, -3 * rise),
              child: Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.only(right: index == 2 ? 0 : 4),
                decoration: BoxDecoration(
                  color: Color.lerp(CoachColors.muted, CoachColors.cyan, rise),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CompactTypingIndicator extends StatelessWidget {
  const _CompactTypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const _AnimatedTypingDots();
  }
}

class _EmptyConversation extends StatelessWidget {
  final ValueChanged<String> onPromptTap;

  const _EmptyConversation({required this.onPromptTap});

  @override
  Widget build(BuildContext context) {
    const starterPrompts = [
      'Build my study plan',
      'Analyse my weakest skill',
      'Give me a speaking topic',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      child: Column(
        children: [
          const _CoachHeroMark(),
          const SizedBox(height: 21),
          const Text(
            'Study smarter with your\npersonal IELTS AI Coach',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CoachColors.text,
              fontSize: 23,
              height: 1.18,
              fontWeight: FontWeight.w900,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 11),
          const Text(
            'Ask questions, understand mistakes, create study plans and receive guidance based on your real progress.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CoachColors.secondary,
              fontSize: 12,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          ...starterPrompts.map(
            (prompt) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onPromptTap(prompt),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: CoachColors.surface.withOpacity(.78),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CoachColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: CoachColors.cyan,
                          size: 18,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            prompt,
                            style: const TextStyle(
                              color: CoachColors.secondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: CoachColors.muted,
                          size: 18,
                        ),
                      ],
                    ),
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

class _CoachHeroMark extends StatelessWidget {
  const _CoachHeroMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(29),
              gradient: const LinearGradient(
                colors: [
                  CoachColors.blue,
                  CoachColors.cyan,
                  CoachColors.violet,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: CoachColors.cyan.withOpacity(.25),
                  blurRadius: 35,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_alt_rounded,
              color: Colors.white,
              size: 45,
            ),
          ),
          const Positioned(right: 4, top: 5, child: _Spark(size: 25)),
          const Positioned(left: 3, bottom: 8, child: _Spark(size: 18)),
        ],
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  final double size;

  const _Spark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CoachColors.surfaceLight,
        borderRadius: BorderRadius.circular(size * .35),
        border: Border.all(color: CoachColors.cyan.withOpacity(.35)),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: CoachColors.cyan,
        size: size * .55,
      ),
    );
  }
}

class _LoginRequiredView extends StatelessWidget {
  const _LoginRequiredView();

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const AuthenticationGatewayScreen(initialMode: AuthMode.signIn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoachColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _CoachBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: CoachColors.surface.withOpacity(.93),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.28),
                        blurRadius: 35,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const _CoachHeroMark(),
                      const SizedBox(height: 22),
                      const Text(
                        'Please Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CoachColors.text,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sign in to chat with your personal IELTS AI Coach and receive guidance based on your progress.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CoachColors.secondary,
                          fontSize: 12.5,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _LoginFeature(
                        icon: Icons.psychology_alt_outlined,
                        text: 'Personalized AI recommendations',
                      ),
                      const SizedBox(height: 9),
                      const _LoginFeature(
                        icon: Icons.insights_outlined,
                        text: 'Progress-aware study guidance',
                      ),
                      const SizedBox(height: 9),
                      const _LoginFeature(
                        icon: Icons.history_rounded,
                        text: 'Secure conversation history',
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                CoachColors.blue,
                                CoachColors.cyan,
                                CoachColors.violet,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: CoachColors.blue.withOpacity(.30),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => _openLogin(context),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text(
                              'Login to Continue',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),
                      const Text(
                        'Your profile and learning data remain protected.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CoachColors.muted,
                          fontSize: 9.5,
                        ),
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

class _LoginFeature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LoginFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: CoachColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CoachColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: CoachColors.cyan, size: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: CoachColors.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: CoachColors.green,
            size: 17,
          ),
        ],
      ),
    );
  }
}

class _ClearConversationSheet extends StatelessWidget {
  const _ClearConversationSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        22 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: CoachColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: CoachColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: CoachColors.danger.withOpacity(.10),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.delete_sweep_outlined,
              color: CoachColors.danger,
              size: 29,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Clear conversation?',
            style: TextStyle(
              color: CoachColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your AI Coach messages will be removed. Your profile and progress data will remain safe.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CoachColors.secondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CoachColors.secondary,
                    side: const BorderSide(color: CoachColors.border),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: CoachColors.danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallSuggestion extends StatelessWidget {
  final String label;

  const _SmallSuggestion({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: CoachColors.background.withOpacity(.72),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: CoachColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: CoachColors.secondary,
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CoachAvatar extends StatelessWidget {
  final double size;

  const _CoachAvatar({this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CoachColors.cyan, CoachColors.blue, CoachColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * .32),
        boxShadow: [
          BoxShadow(color: CoachColors.cyan.withOpacity(.18), blurRadius: 18),
        ],
      ),
      child: Icon(
        Icons.psychology_alt_rounded,
        color: Colors.white,
        size: size * .54,
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CoachColors.cyan, CoachColors.violet],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 15,
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: CoachColors.green.withOpacity(.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: CoachColors.green.withOpacity(.24)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: CoachColors.green, size: 6),
          SizedBox(width: 4),
          Text(
            'ONLINE',
            style: TextStyle(
              color: CoachColors.green,
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BandBadge extends StatelessWidget {
  final String label;
  final double value;

  const _BandBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: CoachColors.cyan.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CoachColors.cyan.withOpacity(.28)),
      ),
      child: Column(
        children: [
          Text(
            value > 0 ? value.toStringAsFixed(1) : '—',
            style: const TextStyle(
              color: CoachColors.cyan,
              fontSize: 19,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: CoachColors.muted, fontSize: 7.5),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      decoration: BoxDecoration(
        color: CoachColors.background.withOpacity(.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CoachColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CoachColors.text,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: CoachColors.muted, fontSize: 7.8),
          ),
        ],
      ),
    );
  }
}

class _CoachBackground extends StatelessWidget {
  const _CoachBackground();

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
                CoachColors.background,
                Color(0xFF0A1728),
                CoachColors.background,
              ],
              stops: [0, .34, .72, 1],
            ),
          ),
        ),
        const Positioned(
          top: -150,
          right: -130,
          child: _Glow(size: 350, color: Color(0x292563EB)),
        ),
        const Positioned(
          top: 310,
          left: -170,
          child: _Glow(size: 330, color: Color(0x1506B6D4)),
        ),
        const Positioned(
          bottom: -170,
          right: -150,
          child: _Glow(size: 380, color: Color(0x168B5CF6)),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

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

class _PromptItem {
  final String label;
  final String message;
  final IconData icon;

  const _PromptItem(this.label, this.message, this.icon);
}

class CoachColors {
  static const background = Color(0xFF08111F);
  static const surface = Color(0xFF111C2E);
  static const surfaceLight = Color(0xFF182A40);
  static const border = Color(0xFF25344C);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
  static const cyan = Color(0xFF06B6D4);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF34D399);
  static const orange = Color(0xFFF97316);
  static const danger = Color(0xFFEF4444);
}

BoxDecoration _heroDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        CoachColors.surface.withOpacity(.98),
        CoachColors.cyan.withOpacity(.09),
        CoachColors.violet.withOpacity(.08),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: CoachColors.cyan.withOpacity(.20)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.16),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ],
  );
}
