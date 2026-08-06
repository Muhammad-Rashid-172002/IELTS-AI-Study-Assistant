import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';

class CreateListeningGenerationJobSheet extends StatefulWidget {
  const CreateListeningGenerationJobSheet({super.key});

  @override
  State<CreateListeningGenerationJobSheet> createState() =>
      _CreateListeningGenerationJobSheetState();
}

class _CreateListeningGenerationJobSheetState
    extends State<CreateListeningGenerationJobSheet> {
  static const _modes = <_ListeningModeOption>[
    _ListeningModeOption(
      key: 'section',
      title: 'Section Practice',
      subtitle: 'Create Section 1, 2, 3 or 4 practice',
      icon: Icons.headphones_rounded,
      badge: 'SECTION',
    ),
    _ListeningModeOption(
      key: 'timed',
      title: 'Timed Listening',
      subtitle: 'Practice with a controlled timer',
      icon: Icons.timer_outlined,
      badge: 'TIMED',
    ),
    _ListeningModeOption(
      key: 'full',
      title: 'Full Listening Test',
      subtitle: 'Generate all four sections • 40 questions',
      icon: Icons.assignment_outlined,
      badge: 'FULL TEST',
    ),
    _ListeningModeOption(
      key: 'accent',
      title: 'Accent Training',
      subtitle: 'British, Australian, American and more',
      icon: Icons.record_voice_over_rounded,
      badge: 'ACCENT',
    ),
    _ListeningModeOption(
      key: 'learning',
      title: 'Learning Mode',
      subtitle: 'Replay, transcript and speed control',
      icon: Icons.school_outlined,
      badge: 'LEARNING',
    ),
    _ListeningModeOption(
      key: 'question_type',
      title: 'Question Type Practice',
      subtitle: 'Focused IELTS listening question format',
      icon: Icons.fact_check_outlined,
      badge: 'FOCUSED',
    ),
  ];

  static const _questionTypes = <String>[
    'Form completion',
    'Note completion',
    'Table completion',
    'Flowchart completion',
    'Summary completion',
    'Multiple choice',
    'Matching',
    'Map labelling',
    'Diagram labelling',
    'Sentence completion',
    'Short answers',
  ];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _ieltsType = 'Academic';
  String _mode = 'section';
  int _section = 1;
  String _questionType = 'Form completion';
  String _difficulty = 'Intermediate';
  String _accent = 'British';
  int _questionCount = 10;
  int _durationMinutes = 10;
  int _requestedCount = 1;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isFull => _mode == 'full';
  bool get _showSection => !_isFull;
  bool get _showDuration => _mode == 'timed' || _mode == 'learning';
  bool get _showAccent => true;

  List<String> get _allowedQuestionTypes {
    switch (_section) {
      case 1:
        return const [
          'Form completion',
          'Note completion',
          'Table completion',
          'Multiple choice',
          'Short answers',
          'Sentence completion',
        ];
      case 2:
        return const [
          'Multiple choice',
          'Matching',
          'Map labelling',
          'Diagram labelling',
          'Note completion',
          'Table completion',
          'Short answers',
        ];
      case 3:
        return const [
          'Multiple choice',
          'Matching',
          'Note completion',
          'Table completion',
          'Flowchart completion',
          'Summary completion',
          'Sentence completion',
        ];
      case 4:
        return const [
          'Note completion',
          'Table completion',
          'Flowchart completion',
          'Summary completion',
          'Sentence completion',
          'Short answers',
          'Multiple choice',
        ];
      default:
        return _questionTypes;
    }
  }

  void _selectSection(int section) {
    setState(() {
      _section = section;
      if (!_allowedQuestionTypes.contains(_questionType)) {
        _questionType = _allowedQuestionTypes.first;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final batch = firestore.batch();
      final createdJobs = <DocumentReference<Map<String, dynamic>>>[];

      if (_isFull) {
        // The production Cloud Function validates one section per job.
        // Four exam jobs are queued and the student app combines Sections 1–4.
        final fullGroupId = 'full_${DateTime.now().microsecondsSinceEpoch}';
        for (int section = 1; section <= 4; section++) {
          final ref = firestore.collection('generation_jobs').doc();
          createdJobs.add(ref);
          batch.set(
            ref,
            _jobData(
              section: section,
              mode: 'exam',
              questionType: _defaultTypeForSection(section),
              questionCount: 10,
              requestedCount: 1,
              uid: uid,
              fullGroupId: fullGroupId,
            ),
          );
        }
      } else {
        final ref = firestore.collection('generation_jobs').doc();
        createdJobs.add(ref);
        batch.set(
          ref,
          _jobData(
            section: _section,
            mode: _firestoreMode,
            questionType: _questionType,
            questionCount: _questionCount,
            requestedCount: _requestedCount,
            uid: uid,
          ),
        );
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _isFull
                ? 'Full Listening Test queued as Sections 1, 2, 3 and 4.'
                : '${_selectedMode.title} generation job queued successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Listening generation job create nahi hua: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _firestoreMode {
    switch (_mode) {
      case 'section':
        return 'section';
      case 'timed':
        return 'timed';
      case 'accent':
        return 'accent';
      case 'learning':
        return 'learning';
      case 'question_type':
        return 'question_type';
      default:
        return 'section';
    }
  }

  Map<String, dynamic> _jobData({
    required int section,
    required String mode,
    required String questionType,
    required int questionCount,
    required int requestedCount,
    required String? uid,
    String? fullGroupId,
  }) {
    return <String, dynamic>{
      'contentType': 'listening',
      'ieltsType': _ieltsType,
      'section': section,
      'questionType': questionType,
      'difficulty': _difficulty,
      'accent': _accent,
      'mode': mode,
      'questionCount': questionCount,
      'durationSeconds': _durationMinutes * 60,
      'requestedCount': requestedCount,
      'generatedCount': 0,
      'failedCount': 0,
      'status': 'queued',
      'customTitle': _titleController.text.trim(),
      'customDescription': _descriptionController.text.trim(),
      'allowReplay': mode == 'learning' || mode == 'accent',
      'allowSpeedControl': mode == 'learning' || mode == 'accent',
      'showTranscript': mode == 'learning' || mode == 'accent',
      'showExplanations': mode == 'learning',
      'timerEnabled': mode == 'timed' || mode == 'exam',
      if (fullGroupId != null) 'fullTestGroupId': fullGroupId,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String _defaultTypeForSection(int section) {
    switch (section) {
      case 1:
        return 'Form completion';
      case 2:
        return 'Map labelling';
      case 3:
        return 'Multiple choice';
      case 4:
        return 'Note completion';
      default:
        return 'Multiple choice';
    }
  }

  _ListeningModeOption get _selectedMode =>
      _modes.firstWhere((item) => item.key == _mode);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 760;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isWide ? 760 : double.infinity,
          maxHeight: MediaQuery.sizeOf(context).height * .94,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _SheetHeader(onClose: () => Navigator.pop(context)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _StatsRow(),
                      const SizedBox(height: 22),
                      _SectionLabel(
                        title: 'IELTS Listening type',
                        subtitle: 'Choose the test audience and context.',
                      ),
                      const SizedBox(height: 10),
                      _TwoChoiceRow(
                        firstTitle: 'Academic',
                        firstSubtitle: 'University and study contexts',
                        firstIcon: Icons.school_outlined,
                        secondTitle: 'General Training',
                        secondSubtitle: 'Daily, workplace and social contexts',
                        secondIcon: Icons.work_outline_rounded,
                        selected: _ieltsType,
                        onSelected: (value) =>
                            setState(() => _ieltsType = value),
                      ),
                      const SizedBox(height: 22),
                      _SectionLabel(
                        title: 'Listening mode',
                        subtitle:
                            'Names match the practice cards in the student app.',
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _modes.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 3 : 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: isWide ? 1.42 : 1.15,
                        ),
                        itemBuilder: (_, index) {
                          final option = _modes[index];
                          return _ModeCard(
                            option: option,
                            selected: option.key == _mode,
                            onTap: () => setState(() {
                              _mode = option.key;
                              if (_isFull) {
                                _questionCount = 40;
                                _durationMinutes = 40;
                                _requestedCount = 1;
                              } else {
                                _questionCount = 10;
                              }
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _SelectedModeNotice(option: _selectedMode),
                      if (_showSection) ...[
                        const SizedBox(height: 22),
                        _SectionLabel(
                          title: 'Listening section',
                          subtitle:
                              'Create exactly the card the student will open.',
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: List.generate(4, (index) {
                            final value = index + 1;
                            return _SelectPill(
                              label: 'Section $value',
                              selected: _section == value,
                              onTap: () => _selectSection(value),
                            );
                          }),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _SectionLabel(
                        title: 'Difficulty and accent',
                        subtitle: 'Control vocabulary, pace and pronunciation.',
                      ),
                      const SizedBox(height: 10),
                      _DropdownRow(
                        first: _DropdownField<String>(
                          label: 'Difficulty',
                          value: _difficulty,
                          items: const [
                            'Foundation',
                            'Intermediate',
                            'Upper Intermediate',
                            'Advanced',
                          ],
                          onChanged: (value) =>
                              setState(() => _difficulty = value),
                        ),
                        second: _DropdownField<String>(
                          label: 'Accent',
                          value: _accent,
                          items: const [
                            'British',
                            'Australian',
                            'American',
                            'Canadian',
                            'Mixed',
                          ],
                          onChanged: (value) =>
                              setState(() => _accent = value),
                        ),
                      ),
                      if (!_isFull) ...[
                        const SizedBox(height: 22),
                        _SectionLabel(
                          title: 'Question format',
                          subtitle:
                              'Only formats supported by the selected section are shown.',
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _questionType,
                          dropdownColor: const Color(0xFF16243A),
                          decoration: _inputDecoration(
                            'Primary question type',
                            Icons.fact_check_outlined,
                          ),
                          items: _allowedQuestionTypes
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _questionType = value);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 22),
                      _SectionLabel(
                        title: 'Generation settings',
                        subtitle:
                            _isFull
                                ? 'Four linked 10-question section jobs will be created.'
                                : 'Choose questions and number of tests to generate.',
                      ),
                      const SizedBox(height: 10),
                      if (_isFull)
                        const _FullTestStructureCard()
                      else
                        _DropdownRow(
                          first: _DropdownField<int>(
                            label: 'Questions',
                            value: _questionCount,
                            items: const [5, 10, 15, 20],
                            labelBuilder: (value) => '$value questions',
                            onChanged: (value) =>
                                setState(() => _questionCount = value),
                          ),
                          second: _DropdownField<int>(
                            label: 'Tests',
                            value: _requestedCount,
                            items: const [1, 2, 3, 5],
                            labelBuilder: (value) => '$value test${value == 1 ? '' : 's'}',
                            onChanged: (value) =>
                                setState(() => _requestedCount = value),
                          ),
                        ),
                      if (_showDuration && !_isFull) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _durationMinutes,
                          dropdownColor: const Color(0xFF16243A),
                          decoration: _inputDecoration(
                            'Student timer',
                            Icons.timer_outlined,
                          ),
                          items: const [5, 10, 15, 20, 30, 40]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text('$value minutes'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _durationMinutes = value);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 22),
                      _SectionLabel(
                        title: 'Optional metadata',
                        subtitle:
                            'Leave empty to let AI create the title and description.',
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _titleController,
                        decoration: _inputDecoration(
                          'Custom title (optional)',
                          Icons.title_rounded,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: _inputDecoration(
                          'Description (optional)',
                          Icons.description_outlined,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _LivePreview(
                        ieltsType: _ieltsType,
                        mode: _selectedMode.title,
                        section: _isFull ? 'Sections 1–4' : 'Section $_section',
                        difficulty: _difficulty,
                        accent: _accent,
                        questionType:
                            _isFull ? 'Section-appropriate mix' : _questionType,
                        questions: _isFull ? 40 : _questionCount,
                        tests: _isFull ? 1 : _requestedCount,
                        durationMinutes: _isFull ? 40 : _durationMinutes,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            _submitting
                                ? 'Creating job...'
                                : _isFull
                                    ? 'Generate Full Listening Test'
                                    : 'Generate ${_selectedMode.title}',
                          ),
                        ),
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
  }
}

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 19),
    filled: true,
    fillColor: const Color(0xFF122036),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFF2A3B55)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFF2A3B55)),
    ),
  );
}

class _ListeningModeOption {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;

  const _ListeningModeOption({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
  });
}

class _SheetHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _SheetHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16C7E8), Color(0xFF6D5DFB)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.headphones_rounded, color: Colors.white),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create AI Listening Content',
                  style: TextStyle(
                    color: AdminColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Generate validated IELTS listening audio, transcripts and questions.',
                  style: TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatCard(value: '8', label: 'Practice modes')),
        SizedBox(width: 8),
        Expanded(child: _StatCard(value: '11', label: 'Question types')),
        SizedBox(width: 8),
        Expanded(child: _StatCard(value: 'AI', label: 'Audio + transcript')),
        SizedBox(width: 8),
        Expanded(child: _StatCard(value: 'Draft', label: 'Publish safely')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13243A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF2B4261)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AdminColors.cyan,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AdminColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: AdminColors.textMuted, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final _ListeningModeOption option;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF203762) : const Color(0xFF132239),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? const Color(0xFF2F70FF) : const Color(0xFF29405E),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(option.icon, color: selected ? AdminColors.cyan : AdminColors.textMuted),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    option.badge,
                    style: const TextStyle(color: AdminColors.textMuted, fontSize: 7, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(option.title, style: const TextStyle(color: AdminColors.text, fontWeight: FontWeight.w900, fontSize: 12)),
            const SizedBox(height: 4),
            Text(option.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AdminColors.textMuted, fontSize: 8.5, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _SelectedModeNotice extends StatelessWidget {
  final _ListeningModeOption option;
  const _SelectedModeNotice({required this.option});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF172642),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D4B78)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_outlined, color: AdminColors.cyan, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${option.title}: ${option.subtitle}',
              style: const TextStyle(color: AdminColors.textMuted, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF1D4ED8),
      side: BorderSide(color: selected ? const Color(0xFF60A5FA) : const Color(0xFF2B405D)),
    );
  }
}

class _TwoChoiceRow extends StatelessWidget {
  final String firstTitle;
  final String firstSubtitle;
  final IconData firstIcon;
  final String secondTitle;
  final String secondSubtitle;
  final IconData secondIcon;
  final String selected;
  final ValueChanged<String> onSelected;

  const _TwoChoiceRow({
    required this.firstTitle,
    required this.firstSubtitle,
    required this.firstIcon,
    required this.secondTitle,
    required this.secondSubtitle,
    required this.secondIcon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ChoiceCard(title: firstTitle, subtitle: firstSubtitle, icon: firstIcon, selected: selected == firstTitle, onTap: () => onSelected(firstTitle))),
        const SizedBox(width: 10),
        Expanded(child: _ChoiceCard(title: secondTitle, subtitle: secondSubtitle, icon: secondIcon, selected: selected == secondTitle, onTap: () => onSelected(secondTitle))),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceCard({required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E3158) : const Color(0xFF132239),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? const Color(0xFF2F70FF) : const Color(0xFF2A405E)),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AdminColors.cyan : AdminColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AdminColors.text, fontSize: 11.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AdminColors.textMuted, fontSize: 8.5)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: AdminColors.cyan, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final Widget first;
  final Widget second;
  const _DropdownRow({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(children: [first, const SizedBox(height: 10), second]);
        }
        return Row(children: [Expanded(child: first), const SizedBox(width: 10), Expanded(child: second)]);
      },
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelBuilder;

  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged, this.labelBuilder});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: const Color(0xFF16243A),
      decoration: _inputDecoration(label, Icons.tune_rounded),
      items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text(labelBuilder?.call(item) ?? item.toString()))).toList(),
      onChanged: (item) {
        if (item != null) onChanged(item);
      },
    );
  }
}

class _FullTestStructureCard extends StatelessWidget {
  const _FullTestStructureCard();

  @override
  Widget build(BuildContext context) {
    const data = [
      ('Section 1', 'Form completion', 'Social conversation'),
      ('Section 2', 'Map labelling', 'Social monologue'),
      ('Section 3', 'Multiple choice', 'Academic discussion'),
      ('Section 4', 'Note completion', 'Academic lecture'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13243A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A4262)),
      ),
      child: Column(
        children: data.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AdminColors.success, size: 18),
              const SizedBox(width: 9),
              SizedBox(width: 72, child: Text(entry.$1, style: const TextStyle(color: AdminColors.text, fontWeight: FontWeight.w800, fontSize: 10.5))),
              Expanded(child: Text('${entry.$2} • ${entry.$3}', style: const TextStyle(color: AdminColors.textMuted, fontSize: 9.5))),
              const Text('10 Q', style: TextStyle(color: AdminColors.cyan, fontWeight: FontWeight.w900, fontSize: 9.5)),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  final String ieltsType;
  final String mode;
  final String section;
  final String difficulty;
  final String accent;
  final String questionType;
  final int questions;
  final int tests;
  final int durationMinutes;

  const _LivePreview({required this.ieltsType, required this.mode, required this.section, required this.difficulty, required this.accent, required this.questionType, required this.questions, required this.tests, required this.durationMinutes});

  @override
  Widget build(BuildContext context) {
    final entries = <String, String>{
      'IELTS type': ieltsType,
      'Mode': mode,
      'Section': section,
      'Difficulty': difficulty,
      'Accent': accent,
      'Question type': questionType,
      'Structure': '$questions questions • $durationMinutes minutes',
      'Tests': '$tests',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13243A),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF2A4262)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.visibility_outlined, color: AdminColors.cyan, size: 19), SizedBox(width: 8), Text('Live Generation Preview', style: TextStyle(color: AdminColors.text, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 13),
          ...entries.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(children: [SizedBox(width: 105, child: Text(entry.key, style: const TextStyle(color: AdminColors.textMuted, fontSize: 9.5))), Expanded(child: Text(entry.value, style: const TextStyle(color: AdminColors.text, fontSize: 9.5, fontWeight: FontWeight.w800)))]),
          )),
          const SizedBox(height: 8),
          const Text('AI quality target: 97%', style: TextStyle(color: AdminColors.text, fontWeight: FontWeight.w800, fontSize: 10)),
          const SizedBox(height: 7),
          const LinearProgressIndicator(value: .97, minHeight: 5, borderRadius: BorderRadius.all(Radius.circular(20)), color: AdminColors.success, backgroundColor: Color(0xFF263A55)),
        ],
      ),
    );
  }
}
