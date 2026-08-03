import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../data/writing_admin_repository.dart';

class CreateWritingGenerationJobSheet extends StatefulWidget {
  const CreateWritingGenerationJobSheet({super.key});

  @override
  State<CreateWritingGenerationJobSheet> createState() =>
      _CreateWritingGenerationJobSheetState();
}

class _CreateWritingGenerationJobSheetState
    extends State<CreateWritingGenerationJobSheet> {
  final _repository = WritingAdminRepository();

  String _category = 'academic_task_1';
  String _taskType = 'Line graph';
  String _difficulty = 'Intermediate';
  int _count = 1;
  bool _loading = false;

  static const taskTypes = <String, List<String>>{
    'academic_task_1': [
      'Line graph',
      'Bar chart',
      'Pie chart',
      'Table',
      'Map',
      'Process diagram',
      'Mixed charts',
    ],
    'general_task_1': [
      'Formal letter',
      'Semi-formal letter',
      'Informal letter',
    ],
    'task_2': [
      'Opinion essay',
      'Discussion essay',
      'Advantages/disadvantages',
      'Problem/solution',
      'Two-part question',
      'Direct question essay',
    ],
  };

  String get categoryLabel => switch (_category) {
        'academic_task_1' => 'Academic Task 1',
        'general_task_1' => 'General Training Task 1',
        'task_2' => 'Writing Task 2',
        _ => _category,
      };

  String get summary => switch (_category) {
        'academic_task_1' =>
          '150+ words, visual data, overview, comparisons and Band 8 model answer.',
        'general_task_1' =>
          '150+ words, realistic letter situation, three bullet points and suitable tone.',
        'task_2' =>
          '250+ words, essay planning, vocabulary, lesson and Band 8 model answer.',
        _ => '',
      };

  Future<void> _create() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      await _repository.createWritingJob(
        taskCategory: _category,
        taskType: _taskType,
        difficulty: _difficulty,
        requestedCount: _count,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Writing AI job queued successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Writing job create nahi hua: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setCategory(String value) {
    setState(() {
      _category = value;
      _taskType = taskTypes[value]!.first;
    });
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
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 22),
                _sectionTitle(
                  'Writing category',
                  'Choose the IELTS Writing module.',
                ),
                const SizedBox(height: 12),
                _categoryGrid(),
                const SizedBox(height: 14),
                _infoPanel(),
                const SizedBox(height: 22),
                _sectionTitle(
                  'Task type',
                  'Select a supported IELTS question format.',
                ),
                const SizedBox(height: 12),
                _taskTypeGrid(),
                const SizedBox(height: 22),
                _sectionTitle(
                  'Difficulty',
                  'Choose the expected language level.',
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 18),
                _sectionTitle(
                  'Generation quantity',
                  'Generate small batches to reduce quota failures.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 9,
                  children: [1, 2, 3, 5]
                      .map(
                        (count) => ChoiceChip(
                          selected: _count == count,
                          label: Text('$count'),
                          onSelected: _loading
                              ? null
                              : (_) => setState(() => _count = count),
                        ),
                      )
                      .toList(),
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
                          ? 'Creating Writing Job...'
                          : 'Create Writing AI Job',
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

  Widget _header() {
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
            Icons.edit_note_rounded,
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
                'Create AI Writing Content',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Generate questions, lessons, vocabulary, checklists and Band 8 answers.',
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

  Widget _categoryGrid() {
    const options = [
      (
        'academic_task_1',
        'Academic Task 1',
        'Charts, tables, maps and processes',
        Icons.insights_rounded
      ),
      (
        'general_task_1',
        'General Training Task 1',
        'Formal, semi-formal and informal letters',
        Icons.mail_outline_rounded
      ),
      (
        'task_2',
        'Writing Task 2',
        'Opinion, discussion and problem essays',
        Icons.article_outlined
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620 ? 1 : 3;
        final spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: options.map((option) {
            final selected = _category == option.$1;
            return SizedBox(
              width: width,
              child: InkWell(
                onTap: _loading ? null : () => _setCategory(option.$1),
                borderRadius: BorderRadius.circular(17),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: selected
                        ? AdminColors.primary.withOpacity(.16)
                        : AdminColors.surface,
                    borderRadius: BorderRadius.circular(17),
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
                        option.$4,
                        color: selected
                            ? AdminColors.cyan
                            : AdminColors.textMuted,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        option.$2,
                        style: const TextStyle(
                          color: AdminColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        option.$3,
                        style: const TextStyle(
                          color: AdminColors.textMuted,
                          fontSize: 9.5,
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

  Widget _taskTypeGrid() {
    final items = taskTypes[_category]!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 2 : 3;
        final spacing = 9.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((type) {
            final selected = _taskType == type;
            return SizedBox(
              width: width,
              child: InkWell(
                onTap: _loading
                    ? null
                    : () => setState(() => _taskType = type),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 70),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AdminColors.cyan.withOpacity(.10)
                        : AdminColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AdminColors.cyan
                          : AdminColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        color: selected
                            ? AdminColors.cyan
                            : AdminColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          type,
                          style: const TextStyle(
                            color: AdminColors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AdminColors.cyan,
                          size: 17,
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
        border:
            Border.all(color: AdminColors.cyan.withOpacity(.22)),
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
              summary,
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
            '$categoryLabel • $_taskType • $_difficulty • $_count task(s)',
            style: const TextStyle(
              color: AdminColors.cyan,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
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
