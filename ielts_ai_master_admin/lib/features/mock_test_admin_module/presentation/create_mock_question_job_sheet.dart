import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../data/mock_admin_repository.dart';
import '../domain/mock_admin_models.dart';

class CreateMockQuestionJobSheet extends StatefulWidget {
  const CreateMockQuestionJobSheet({super.key});

  @override
  State<CreateMockQuestionJobSheet> createState() =>
      _CreateMockQuestionJobSheetState();
}

class _CreateMockQuestionJobSheetState
    extends State<CreateMockQuestionJobSheet> {
  final _repository = MockAdminRepository();

  MockAdminTrack _track = MockAdminTrack.academic;
  MockAdminSkill _skill = MockAdminSkill.listening;
  String _difficulty = 'Intermediate';
  String _questionType = 'multiple_choice';
  int _count = 10;
  bool _publishImmediately = true;
  bool _loading = false;

  Future<void> _create() async {
    setState(() => _loading = true);

    try {
      await _repository.createGenerationJob(
        track: _track,
        skill: _skill,
        difficulty: _difficulty,
        questionType: _questionType,
        count: _count,
        publishImmediately: _publishImmediately,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mock question generation job queued.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generation job create nahi hua: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _questionTypes {
    return switch (_skill) {
      MockAdminSkill.listening => const [
          'multiple_choice',
          'form_completion',
          'note_completion',
          'table_completion',
          'map_labelling',
          'sentence_completion',
          'short_answer',
        ],
      MockAdminSkill.reading => const [
          'multiple_choice',
          'true_false_not_given',
          'yes_no_not_given',
          'matching_headings',
          'matching_information',
          'summary_completion',
          'sentence_completion',
          'short_answer',
        ],
      MockAdminSkill.writing => const [
          'writing_task_1',
          'writing_task_2',
        ],
      MockAdminSkill.speaking => const [
          'speaking_part_1',
          'speaking_part_2',
          'speaking_part_3',
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_questionTypes.contains(_questionType)) {
      _questionType = _questionTypes.first;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Generate Mock Questions',
                  style: TextStyle(
                    color: AdminColors.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Queue AI question generation for the central mock question bank.',
                  style: TextStyle(
                    color: AdminColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<MockAdminTrack>(
                  value: _track,
                  decoration:
                      const InputDecoration(labelText: 'IELTS Track'),
                  items: MockAdminTrack.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _track = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<MockAdminSkill>(
                  value: _skill,
                  decoration:
                      const InputDecoration(labelText: 'Skill'),
                  items: MockAdminSkill.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _skill = value;
                        _questionType = _questionTypes.first;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _questionType,
                  decoration:
                      const InputDecoration(labelText: 'Question Type'),
                  items: _questionTypes
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value.replaceAll('_', ' '),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _questionType = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
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
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _difficulty = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 5, 10, 20, 40].map((count) {
                    return ChoiceChip(
                      selected: _count == count,
                      label: Text('$count'),
                      onSelected: (_) => setState(() => _count = count),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _publishImmediately,
                  onChanged: (value) {
                    setState(() => _publishImmediately = value);
                  },
                  title: const Text(
                    'Publish generated questions',
                    style: TextStyle(
                      color: AdminColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    'Keep enabled so the mobile mock can load these questions immediately.',
                    style: TextStyle(color: AdminColors.textMuted),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _create,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _loading
                          ? 'Creating Job...'
                          : 'Create Generation Job',
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
}
