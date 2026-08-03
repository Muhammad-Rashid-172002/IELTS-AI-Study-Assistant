import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../data/speaking_admin_repository.dart';

class CreateSpeakingGenerationJobSheet extends StatefulWidget {
  const CreateSpeakingGenerationJobSheet({super.key});

  @override
  State<CreateSpeakingGenerationJobSheet> createState() =>
      _CreateSpeakingGenerationJobSheetState();
}

class _CreateSpeakingGenerationJobSheetState
    extends State<CreateSpeakingGenerationJobSheet> {
  final _repository = SpeakingAdminRepository();

  String _mode = 'part_1';
  int _part = 1;
  String _accent = 'British';
  String _difficulty = 'Intermediate';
  int _count = 1;
  bool _loading = false;

  static const modes = [
    _ModeOption(
      value: 'ai_partner',
      title: 'AI Speaking Partner',
      subtitle: 'Adaptive questions and follow-ups',
      icon: Icons.smart_toy_outlined,
      part: 0,
    ),
    _ModeOption(
      value: 'full_test',
      title: 'Full Speaking Test',
      subtitle: 'Parts 1, 2 and 3',
      icon: Icons.assignment_turned_in_outlined,
      part: 0,
    ),
    _ModeOption(
      value: 'part_1',
      title: 'Part 1 Practice',
      subtitle: 'Familiar questions',
      icon: Icons.looks_one_outlined,
      part: 1,
    ),
    _ModeOption(
      value: 'part_2',
      title: 'Part 2 Cue Cards',
      subtitle: 'Preparation and 2-minute talk',
      icon: Icons.looks_two_outlined,
      part: 2,
    ),
    _ModeOption(
      value: 'part_3',
      title: 'Part 3 Discussion',
      subtitle: 'Abstract follow-up questions',
      icon: Icons.looks_3_outlined,
      part: 3,
    ),
    _ModeOption(
      value: 'pronunciation',
      title: 'Pronunciation Practice',
      subtitle: 'Stress, intonation and clarity',
      icon: Icons.record_voice_over_outlined,
      part: 0,
    ),
    _ModeOption(
      value: 'fluency',
      title: 'Fluency Training',
      subtitle: 'Reduce pauses and fillers',
      icon: Icons.speed_rounded,
      part: 0,
    ),
    _ModeOption(
      value: 'daily_challenge',
      title: 'Daily Speaking Challenge',
      subtitle: 'Focused 60-second activity',
      icon: Icons.local_fire_department_outlined,
      part: 0,
    ),
  ];

  String get _modeLabel =>
      modes.firstWhere((item) => item.value == _mode).title;

  String get _summary => switch (_mode) {
        'full_test' =>
          'Creates a complete Speaking test with Parts 1, 2 and 3, model answers and AI follow-ups.',
        'part_1' =>
          'Creates familiar introduction questions for 4–5 minutes of practice.',
        'part_2' =>
          'Creates one cue card with 1-minute preparation and up to 2-minute speaking time.',
        'part_3' =>
          'Creates deeper follow-up questions for 4–5 minutes of discussion.',
        'pronunciation' =>
          'Creates word stress, intonation, shadowing and repeat-and-compare practice.',
        'fluency' =>
          'Creates timed speaking drills focused on pauses, fillers and linking phrases.',
        'daily_challenge' =>
          'Creates a focused daily 60-second speaking challenge.',
        _ =>
          'Creates an adaptive AI speaking partner with follow-up questions and model guidance.',
      };

  void _selectMode(_ModeOption option) {
    setState(() {
      _mode = option.value;
      _part = option.part;
      if (_mode == 'full_test') _count = 1;
    });
  }

  Future<void> _create() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await _repository.createSpeakingJob(
        mode: _mode,
        part: _part,
        accent: _accent,
        difficulty: _difficulty,
        requestedCount: _count,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speaking AI generation job queued.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speaking job create nahi hua: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                const SizedBox(height: 22),
                _sectionTitle(
                  'Speaking mode',
                  'Choose the activity that will appear in the user app.',
                ),
                const SizedBox(height: 12),
                _modeGrid(),
                const SizedBox(height: 14),
                _infoPanel(),
                const SizedBox(height: 22),
                _sectionTitle(
                  'Voice and difficulty',
                  'Set examiner accent and speaking level.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _accent,
                        decoration:
                            const InputDecoration(labelText: 'Accent'),
                        items: const [
                          'British',
                          'American',
                          'Australian',
                          'Canadian',
                          'New Zealand',
                          'Mixed',
                        ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: _loading
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _accent = value);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _difficulty,
                        decoration:
                            const InputDecoration(labelText: 'Difficulty'),
                        items: const [
                          'Foundation',
                          'Intermediate',
                          'Upper Intermediate',
                          'Advanced',
                          'Expert',
                        ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: _loading
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _difficulty = value);
                                }
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _sectionTitle(
                  'Number of tests',
                  'Generate small batches to reduce Gemini quota failures.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [1, 2, 3, 5].map((count) {
                    final disabled = _mode == 'full_test' && count > 1;
                    return Opacity(
                      opacity: disabled ? .35 : 1,
                      child: ChoiceChip(
                        selected: _count == count,
                        label: Text('$count'),
                        onSelected: _loading || disabled
                            ? null
                            : (_) => setState(() => _count = count),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                _preview(),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _create,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _loading
                          ? 'Creating Speaking Job...'
                          : 'Create Speaking AI Job',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AdminColors.cyan, AdminColors.violet],
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.mic_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create AI Speaking Content',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Generate questions, cue cards, model answers, pronunciation and fluency practice.',
                style: TextStyle(
                  color: AdminColors.textMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _modeGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 2 : 3;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: modes.map((option) {
            final selected = _mode == option.value;

            return SizedBox(
              width: width,
              child: InkWell(
                onTap:
                    _loading ? null : () => _selectMode(option),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 118,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AdminColors.primary.withOpacity(.14)
                        : AdminColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? AdminColors.primary
                          : AdminColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        option.icon,
                        color: selected
                            ? AdminColors.cyan
                            : AdminColors.textMuted,
                      ),
                      const Spacer(),
                      Text(
                        option.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AdminColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AdminColors.textMuted,
                          fontSize: 9.4,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _infoPanel() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AdminColors.cyan.withOpacity(.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AdminColors.cyan.withOpacity(.22),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AdminColors.cyan,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _summary,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 10.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generation Preview',
            style: TextStyle(
              color: AdminColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$_modeLabel • $_accent • $_difficulty • $_count test(s)',
            style: const TextStyle(
              color: AdminColors.cyan,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _summary,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 10.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AdminColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: AdminColors.textMuted,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _ModeOption {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final int part;

  const _ModeOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.part,
  });
}
