import 'package:flutter/material.dart';

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

  bool _sending = false;

  static const _suggestedPrompts = <String>[
    'What should I practice today?',
    'Why is my answer wrong?',
    'Create a Band 7 writing plan.',
    'Give me a speaking cue card.',
    'Explain True/False/Not Given.',
    'Make a 30-day study plan.',
    'Review my progress.',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? value]) async {
    final message = (value ?? _controller.text).trim();
    if (message.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await _repository.sendMessage(message);
      await Future<void>.delayed(
        const Duration(milliseconds: 250),
      );

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI Coach response failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: CoachColors.surface,
            title: const Text(
              'Clear conversation?',
              style: TextStyle(color: CoachColors.text),
            ),
            content: const Text(
              'Your AI Coach messages will be removed. Progress data will remain safe.',
              style: TextStyle(
                color: CoachColors.secondary,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await _repository.clearConversation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoachColors.background,
      appBar: AppBar(
        backgroundColor: CoachColors.background,
        title: const Text('AI Coach'),
        actions: [
          IconButton(
            tooltip: 'Refresh progress',
            onPressed: _repository.refreshProfile,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _clearConversation();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clear',
                child: Text('Clear conversation'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _profileSummary(),
            _promptChips(),
            Expanded(child: _conversation()),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _profileSummary() {
    return StreamBuilder<AiCoachProfile>(
      stream: _repository.watchCoachProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data ??
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
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress-aware IELTS Coach',
                          style: TextStyle(
                            color: CoachColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Recommendations are based on your real performance.',
                          style: TextStyle(
                            color: CoachColors.secondary,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _BandBadge(
                    label: 'Band',
                    value: profile.overallBand,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: 'Target',
                      value:
                          profile.targetBand.toStringAsFixed(1),
                      icon: Icons.flag_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Weakest',
                      value: profile.weakestSkill,
                      icon: Icons.trending_down_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Streak',
                      value: '${profile.streak} days',
                      icon:
                          Icons.local_fire_department_rounded,
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
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _suggestedPrompts[index];

          return ActionChip(
            label: Text(prompt),
            avatar: const Icon(
              Icons.auto_awesome_rounded,
              size: 16,
            ),
            onPressed: () => _send(prompt),
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

        if (messages.isEmpty) {
          return const _EmptyConversation();
        }

        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          itemCount: messages.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final message = messages[index];
            return _MessageBubble(message: message);
          },
        );
      },
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: CoachColors.surface,
        border: Border(
          top: BorderSide(color: CoachColors.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              cursorColor: CoachColors.cyan,
              style: const TextStyle(
                color: CoachColors.text,
              ),
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Ask about your IELTS progress...',
                filled: true,
                fillColor: CoachColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: CoachColors.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: CoachColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: CoachColors.cyan,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            height: 50,
            child: FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiCoachMessage message;

  const _MessageBubble({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(
                    colors: [
                      CoachColors.blue,
                      CoachColors.violet,
                    ],
                  )
                : null,
            color: isUser ? null : CoachColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft:
                  Radius.circular(isUser ? 18 : 5),
              bottomRight:
                  Radius.circular(isUser ? 5 : 18),
            ),
            border: isUser
                ? null
                : Border.all(color: CoachColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const Row(
                  children: [
                    Icon(
                      Icons.psychology_alt_rounded,
                      color: CoachColors.cyan,
                      size: 16,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'AI Coach',
                      style: TextStyle(
                        color: CoachColors.cyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
              ],
              SelectableText(
                message.text,
                style: const TextStyle(
                  color: CoachColors.text,
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
              if (message.suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: message.suggestions
                      .map(
                        (suggestion) => _SmallSuggestion(
                          label: suggestion,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallSuggestion extends StatelessWidget {
  final String label;

  const _SmallSuggestion({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: CoachColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CoachColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: CoachColors.secondary,
          fontSize: 8.5,
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CoachAvatar(size: 74),
            SizedBox(height: 15),
            Text(
              'Your Personal IELTS Coach',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CoachColors.text,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ask what to study today, why an answer was wrong, or request a personalized study plan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CoachColors.secondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachAvatar extends StatelessWidget {
  final double size;

  const _CoachAvatar({
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            CoachColors.cyan,
            CoachColors.blue,
            CoachColors.violet,
          ],
        ),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(
        Icons.psychology_alt_rounded,
        color: Colors.white,
        size: size * .55,
      ),
    );
  }
}

class _BandBadge extends StatelessWidget {
  final String label;
  final double value;

  const _BandBadge({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: CoachColors.cyan.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CoachColors.cyan.withOpacity(.30),
        ),
      ),
      child: Column(
        children: [
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(
              color: CoachColors.cyan,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: CoachColors.muted,
              fontSize: 8,
            ),
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

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: CoachColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CoachColors.border),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: CoachColors.cyan,
            size: 16,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CoachColors.text,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: CoachColors.muted,
              fontSize: 7.8,
            ),
          ),
        ],
      ),
    );
  }
}

class CoachColors {
  static const background = Color(0xFF08111F);
  static const surface = Color(0xFF111C2E);
  static const border = Color(0xFF25344C);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
  static const cyan = Color(0xFF06B6D4);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF8B5CF6);
}

BoxDecoration _heroDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        CoachColors.surface,
        CoachColors.cyan.withOpacity(.10),
        CoachColors.violet.withOpacity(.08),
      ],
    ),
    borderRadius: BorderRadius.circular(21),
    border: Border.all(
      color: CoachColors.cyan.withOpacity(.23),
    ),
  );
}
