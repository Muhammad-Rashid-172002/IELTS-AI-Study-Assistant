import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../data/mock_admin_repository.dart';
import '../domain/mock_admin_models.dart';

class CreateMockTestSheet extends StatefulWidget {
  const CreateMockTestSheet({super.key});

  @override
  State<CreateMockTestSheet> createState() => _CreateMockTestSheetState();
}

class _CreateMockTestSheetState extends State<CreateMockTestSheet> {
  final MockAdminRepository _repository = MockAdminRepository();

  final TextEditingController _title = TextEditingController(
    text: 'IELTS Full Mock Test',
  );

  final TextEditingController _description = TextEditingController(
    text:
        'Complete IELTS simulation with Listening, Reading, Writing and Speaking.',
  );

  MockAdminTrack _track = MockAdminTrack.academic;
  MockAdminScope _scope = MockAdminScope.fullMock;
  MockAdminMode _mode = MockAdminMode.computerDelivered;
  MockAdminSkill _singleSkill = MockAdminSkill.listening;

  String _difficulty = 'Intermediate';
  bool _autoGenerateQuestionBank = true;
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  List<MockAdminSkill> get _skills {
    if (_scope == MockAdminScope.fullMock) {
      return MockAdminSkill.values;
    }

    return <MockAdminSkill>[_singleSkill];
  }

  Future<void> _create() async {
    if (_loading) return;

    final String title = _title.text.trim();
    final String description = _description.text.trim();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (title.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Mock title is required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _repository.createMockTest(
        title: title,
        description: description,
        track: _track,
        scope: _scope,
        mode: _mode,
        difficulty: _difficulty,
        skills: _skills,
        autoGenerateQuestionBank: _autoGenerateQuestionBank,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Mock test created successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Mock test could not be created: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _header(context),
                const SizedBox(height: 22),
                TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Mock Test Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionHeading(
                  title: 'IELTS Track',
                  subtitle: 'Choose Academic or General Training.',
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _OptionCard(
                        selected: _track == MockAdminTrack.academic,
                        icon: Icons.school_outlined,
                        title: 'Academic',
                        subtitle: 'Study and professional registration',
                        onTap: () {
                          setState(() => _track = MockAdminTrack.academic);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OptionCard(
                        selected: _track == MockAdminTrack.generalTraining,
                        icon: Icons.work_outline_rounded,
                        title: 'General Training',
                        subtitle: 'Migration, work and daily life',
                        onTap: () {
                          setState(
                            () => _track = MockAdminTrack.generalTraining,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _SectionHeading(
                  title: 'Mock Scope',
                  subtitle: 'Full test or a single IELTS skill.',
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _OptionCard(
                        selected: _scope == MockAdminScope.fullMock,
                        icon: Icons.dashboard_customize_outlined,
                        title: 'Full Mock',
                        subtitle: 'All four IELTS skills',
                        onTap: () {
                          setState(() => _scope = MockAdminScope.fullMock);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OptionCard(
                        selected: _scope == MockAdminScope.singleSkill,
                        icon: Icons.center_focus_strong_outlined,
                        title: 'Single Skill',
                        subtitle: 'One selected module',
                        onTap: () {
                          setState(() => _scope = MockAdminScope.singleSkill);
                        },
                      ),
                    ),
                  ],
                ),
                if (_scope == MockAdminScope.singleSkill) ...<Widget>[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MockAdminSkill.values.map((skill) {
                      return ChoiceChip(
                        selected: _singleSkill == skill,
                        label: Text(skill.label),
                        onSelected: (_) {
                          setState(() => _singleSkill = skill);
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                const _SectionHeading(
                  title: 'Simulation Mode',
                  subtitle:
                      'Control the learner experience and exam restrictions.',
                ),
                const SizedBox(height: 10),
                ...MockAdminMode.values.map((mode) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: RadioListTile<MockAdminMode>(
                      value: mode,
                      groupValue: _mode,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (MockAdminMode? value) {
                        if (value != null) {
                          setState(() => _mode = value);
                        }
                      },
                      title: Text(
                        mode.label,
                        style: const TextStyle(
                          color: AdminColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items:
                      const <String>[
                        'Foundation',
                        'Intermediate',
                        'Upper Intermediate',
                        'Advanced',
                        'Expert',
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _difficulty = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _autoGenerateQuestionBank,
                  onChanged: (bool value) {
                    setState(() => _autoGenerateQuestionBank = value);
                  },
                  title: const Text(
                    'Generate question bank automatically',
                    style: TextStyle(
                      color: AdminColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    'Queues Listening, Reading, Writing and Speaking content for the selected mock.',
                    style: TextStyle(color: AdminColors.textMuted),
                  ),
                ),
                const SizedBox(height: 6),
                const _GenerationNotice(),
                const SizedBox(height: 14),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_task_rounded),
                    label: Text(
                      _loading ? 'Creating Mock Test...' : 'Create Mock Test',
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
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[AdminColors.cyan, AdminColors.violet],
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.fact_check_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Create IELTS Mock Test',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Build a publishable mock configuration for the user app.',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _preview() {
    final int duration = _skills.fold<int>(
      0,
      (int total, MockAdminSkill skill) => total + skill.durationMinutes,
    );

    final int questions = _skills.fold<int>(
      0,
      (int total, MockAdminSkill skill) => total + skill.targetCount,
    );

    final String generationStatus = _autoGenerateQuestionBank
        ? 'Status: Generating → Ready → Review → Publish.'
        : 'Saved as draft without generation jobs.';

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
        children: <Widget>[
          const Text(
            'Mock Preview',
            style: TextStyle(
              color: AdminColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${_track.label} • ${_scope.label} • ${_mode.label}',
            style: const TextStyle(
              color: AdminColors.cyan,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_skills.map((MockAdminSkill skill) => skill.label).join(' • ')}\n'
            '$questions questions/tasks/parts • $duration minutes • $_difficulty\n'
            '$generationStatus',
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
}

class _GenerationNotice extends StatelessWidget {
  const _GenerationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: AdminColors.cyan, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Questions are generated as drafts. Review the completed mock before publishing.',
              style: TextStyle(
                color: AdminColors.textMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 125,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? AdminColors.primary.withOpacity(0.15)
              : AdminColors.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? AdminColors.primary : AdminColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              color: selected ? AdminColors.cyan : AdminColors.textMuted,
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: AdminColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AdminColors.textMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
          style: const TextStyle(color: AdminColors.textMuted, fontSize: 10.5),
        ),
      ],
    );
  }
}
