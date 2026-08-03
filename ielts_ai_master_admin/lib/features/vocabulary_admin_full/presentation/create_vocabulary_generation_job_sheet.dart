import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../data/vocabulary_admin_repository.dart';

class CreateVocabularyGenerationJobSheet extends StatefulWidget {
  const CreateVocabularyGenerationJobSheet({super.key});

  @override
  State<CreateVocabularyGenerationJobSheet> createState() =>
      _CreateVocabularyGenerationJobSheetState();
}

class _CreateVocabularyGenerationJobSheetState
    extends State<CreateVocabularyGenerationJobSheet> {
  final _repository = VocabularyAdminRepository();
  final _topicController =
      TextEditingController(text: 'General IELTS');

  String _category = 'academic';
  String _band = 'Band 7';
  String _difficulty = 'Intermediate';
  String _translationLanguage = 'Urdu';
  int _count = 10;
  bool _publishImmediately = false;
  bool _loading = false;

  static const categories = {
    'academic': (
      'Academic Vocabulary',
      Icons.school_outlined,
      'Formal words for essays, passages and lectures'
    ),
    'topic': (
      'Topic Vocabulary',
      Icons.category_outlined,
      'Vocabulary for a selected IELTS topic'
    ),
    'band_5': (
      'Band 5 Words',
      Icons.filter_5_outlined,
      'Foundation and accessible words'
    ),
    'band_6': (
      'Band 6 Words',
      Icons.filter_6_outlined,
      'Flexible upper-intermediate words'
    ),
    'band_7': (
      'Band 7 Words',
      Icons.filter_7_outlined,
      'Precise and less common words'
    ),
    'band_8_9': (
      'Band 8–9 Words',
      Icons.workspace_premium_outlined,
      'Advanced vocabulary with nuance'
    ),
    'collocations': (
      'Collocations',
      Icons.hub_outlined,
      'Natural word combinations'
    ),
    'phrasal_verbs': (
      'Phrasal Verbs',
      Icons.alt_route_rounded,
      'Useful multi-word verbs'
    ),
    'synonyms': (
      'Synonyms',
      Icons.compare_arrows_rounded,
      'Paraphrasing and nuance'
    ),
    'spelling': (
      'Spelling Mistakes',
      Icons.spellcheck_rounded,
      'Frequently misspelled IELTS words'
    ),
  };

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await _repository.createGenerationJob(
        category: _category,
        band: _band,
        topic: _topicController.text,
        difficulty: _difficulty,
        translationLanguage: _translationLanguage,
        count: _count,
        publishImmediately: _publishImmediately,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vocabulary AI generation job queued.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vocabulary job create nahi hua: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = categories[_category]!;

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
              children: [
                _header(context),
                const SizedBox(height: 22),
                const _SectionHeading(
                  title: 'Vocabulary category',
                  subtitle:
                      'Choose the exact IELTS vocabulary group to generate.',
                ),
                const SizedBox(height: 12),
                _categoryGrid(),
                const SizedBox(height: 14),
                _InfoPanel(
                  icon: selected.$2,
                  title: selected.$1,
                  text: selected.$3,
                ),
                const SizedBox(height: 22),
                const _SectionHeading(
                  title: 'Generation settings',
                  subtitle: 'Set band, topic, difficulty and translation.',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;

                    final fields = [
                      DropdownButtonFormField<String>(
                        value: _band,
                        decoration:
                            const InputDecoration(labelText: 'IELTS Band'),
                        items: const [
                          'Band 5',
                          'Band 6',
                          'Band 7',
                          'Band 8',
                          'Band 8-9',
                          'Band 9',
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
                            setState(() => _band = value);
                          }
                        },
                      ),
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
                    ];

                    if (compact) {
                      return Column(
                        children: [
                          fields[0],
                          const SizedBox(height: 10),
                          fields[1],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 10),
                        Expanded(child: fields[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    labelText: 'IELTS Topic',
                    hintText:
                        'Environment, Education, Technology, Health...',
                    prefixIcon: Icon(Icons.topic_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _translationLanguage,
                  decoration:
                      const InputDecoration(labelText: 'Translation Language'),
                  items: const [
                    'Urdu',
                    'Pashto',
                    'Arabic',
                    'Hindi',
                    'Bengali',
                    'No Translation',
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
                      setState(() => _translationLanguage = value);
                    }
                  },
                ),
                const SizedBox(height: 20),
                const _SectionHeading(
                  title: 'Number of words',
                  subtitle:
                      'Small batches are more reliable and easier to review.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [5, 10, 20, 30, 50].map((count) {
                    return ChoiceChip(
                      selected: _count == count,
                      label: Text('$count'),
                      onSelected: (_) => setState(() => _count = count),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _publishImmediately,
                  onChanged: (value) {
                    setState(() => _publishImmediately = value);
                  },
                  title: const Text(
                    'Publish immediately',
                    style: TextStyle(
                      color: AdminColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    'Recommended off: review AI-generated words before publishing.',
                    style: TextStyle(color: AdminColors.textMuted),
                  ),
                ),
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
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _loading
                          ? 'Creating Vocabulary Job...'
                          : 'Create Vocabulary AI Job',
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
            Icons.translate_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate IELTS Vocabulary',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Create meanings, translations, examples, synonyms, collocations and spelling guidance.',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520
            ? 2
            : constraints.maxWidth < 760
                ? 3
                : 4;
        const spacing = 9.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: categories.entries.map((entry) {
            final selected = _category == entry.key;

            return SizedBox(
              width: width,
              child: InkWell(
                onTap: () => setState(() => _category = entry.key),
                borderRadius: BorderRadius.circular(15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 105,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: selected
                        ? AdminColors.primary.withOpacity(.16)
                        : AdminColors.surface,
                    borderRadius: BorderRadius.circular(15),
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
                        entry.value.$2,
                        color: selected
                            ? AdminColors.cyan
                            : AdminColors.textMuted,
                      ),
                      const Spacer(),
                      Text(
                        entry.value.$1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AdminColors.text,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
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

  Widget _preview() {
    final category = categories[_category]!;

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
            '${category.$1} • $_band • $_difficulty • $_count words',
            style: const TextStyle(
              color: AdminColors.cyan,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Topic: ${_topicController.text.trim().isEmpty ? 'General IELTS' : _topicController.text.trim()} • '
            'Translation: $_translationLanguage • '
            '${_publishImmediately ? 'Publish immediately' : 'Save as draft'}',
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

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, color: AdminColors.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title — $text',
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
}
