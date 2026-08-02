import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../data/generation_job_repository.dart';

class CreateGenerationJobSheet extends StatefulWidget {
  const CreateGenerationJobSheet({super.key});

  @override
  State<CreateGenerationJobSheet> createState() =>
      _CreateGenerationJobSheetState();
}

class _CreateGenerationJobSheetState
    extends State<CreateGenerationJobSheet> {
  final _repository = GenerationJobRepository();

  String _ieltsType = 'Academic';
  int _section = 1;
  String _questionType = 'Form completion';
  String _difficulty = 'Intermediate';
  String _accent = 'British';
  String _mode = 'practice';
  int _count = 5;
  bool _loading = false;

  Future<void> _create() async {
    setState(() => _loading = true);

    try {
      await _repository.createListeningJob(
        ieltsType: _ieltsType,
        section: _section,
        questionType: _questionType,
        difficulty: _difficulty,
        accent: _accent,
        mode: _mode,
        count: _count,
      );

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              'Create AI Generation Job',
              style: TextStyle(
                color: AdminColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _drop<String>(
              'IELTS Type',
              _ieltsType,
              const ['Academic', 'General Training'],
              (value) => setState(() => _ieltsType = value),
            ),
            _drop<int>(
              'Section',
              _section,
              const [1, 2, 3, 4],
              (value) => setState(() => _section = value),
            ),
            _drop<String>(
              'Question Type',
              _questionType,
              const [
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
              ],
              (value) => setState(() => _questionType = value),
            ),
            _drop<String>(
              'Difficulty',
              _difficulty,
              const [
                'Foundation',
                'Intermediate',
                'Upper Intermediate',
                'Advanced',
                'Expert',
              ],
              (value) => setState(() => _difficulty = value),
            ),
            _drop<String>(
              'Accent',
              _accent,
              const [
                'British',
                'Australian',
                'Canadian',
                'New Zealand',
                'American',
                'Mixed',
              ],
              (value) => setState(() => _accent = value),
            ),
            _drop<String>(
              'Mode',
              _mode,
              const [
                'practice',
                'learning',
                'timed',
                'exam',
                'full',
                'accent',
              ],
              (value) => setState(() => _mode = value),
            ),
            _drop<int>(
              'Number of Tests',
              _count,
              const [1, 5, 10, 20, 50],
              (value) => setState(() => _count = value),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _loading ? null : _create,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: const Text('Create Job'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drop<T>(
    String label,
    T value,
    List<T> items,
    ValueChanged<T> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(item.toString()),
              ),
            )
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }
}
