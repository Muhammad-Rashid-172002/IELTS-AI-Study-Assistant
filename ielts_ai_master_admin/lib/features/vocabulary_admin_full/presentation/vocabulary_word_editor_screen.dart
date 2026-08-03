import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../data/vocabulary_admin_repository.dart';
import '../domain/vocabulary_admin_word.dart';

class VocabularyWordEditorScreen extends StatefulWidget {
  final VocabularyAdminWord? existing;

  const VocabularyWordEditorScreen({
    super.key,
    this.existing,
  });

  @override
  State<VocabularyWordEditorScreen> createState() =>
      _VocabularyWordEditorScreenState();
}

class _VocabularyWordEditorScreenState
    extends State<VocabularyWordEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = VocabularyAdminRepository();

  late final TextEditingController _word;
  late final TextEditingController _meaning;
  late final TextEditingController _translation;
  late final TextEditingController _pronunciation;
  late final TextEditingController _ipa;
  late final TextEditingController _partOfSpeech;
  late final TextEditingController _example;
  late final TextEditingController _synonyms;
  late final TextEditingController _antonyms;
  late final TextEditingController _collocations;
  late final TextEditingController _topic;
  late final TextEditingController _commonMistake;
  late final TextEditingController _spellingTip;
  late final TextEditingController _usageNote;
  late final TextEditingController _wordFamily;

  String _category = 'academic';
  String _band = 'Band 7';
  String _difficulty = 'Intermediate';
  String _register = 'neutral';
  String _status = 'draft';
  final Set<String> _modules = {
    'Listening',
    'Reading',
    'Writing',
    'Speaking',
  };
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final word = widget.existing;

    _word = TextEditingController(text: word?.word ?? '');
    _meaning = TextEditingController(text: word?.meaning ?? '');
    _translation = TextEditingController(text: word?.translation ?? '');
    _pronunciation =
        TextEditingController(text: word?.pronunciation ?? '');
    _ipa = TextEditingController(text: word?.ipa ?? '');
    _partOfSpeech =
        TextEditingController(text: word?.partOfSpeech ?? '');
    _example = TextEditingController(text: word?.exampleSentence ?? '');
    _synonyms = TextEditingController(
      text: word?.synonyms.join(', ') ?? '',
    );
    _antonyms = TextEditingController(
      text: word?.antonyms.join(', ') ?? '',
    );
    _collocations = TextEditingController(
      text: word?.collocations.join(', ') ?? '',
    );
    _topic = TextEditingController(text: word?.topic ?? 'General IELTS');
    _commonMistake =
        TextEditingController(text: word?.commonMistake ?? '');
    _spellingTip =
        TextEditingController(text: word?.spellingTip ?? '');
    _usageNote = TextEditingController(text: word?.usageNote ?? '');
    _wordFamily = TextEditingController(
      text: word?.wordFamily.join(', ') ?? '',
    );

    if (word != null) {
      _category = word.category;
      _band = word.band;
      _difficulty = word.difficulty;
      _register = word.register;
      _status = word.status;
      _modules
        ..clear()
        ..addAll(word.modules);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _word,
      _meaning,
      _translation,
      _pronunciation,
      _ipa,
      _partOfSpeech,
      _example,
      _synonyms,
      _antonyms,
      _collocations,
      _topic,
      _commonMistake,
      _spellingTip,
      _usageNote,
      _wordFamily,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _csv(TextEditingController controller) {
    return controller.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'word': _word.text.trim(),
      'meaning': _meaning.text.trim(),
      'translation': _translation.text.trim(),
      'pronunciation': _pronunciation.text.trim(),
      'ipa': _ipa.text.trim(),
      'partOfSpeech': _partOfSpeech.text.trim(),
      'exampleSentence': _example.text.trim(),
      'synonyms': _csv(_synonyms),
      'antonyms': _csv(_antonyms),
      'collocations': _csv(_collocations),
      'topic': _topic.text.trim(),
      'category': _category,
      'band': _band,
      'difficulty': _difficulty,
      'commonMistake': _commonMistake.text.trim(),
      'spellingTip': _spellingTip.text.trim(),
      'usageNote': _usageNote.text.trim(),
      'wordFamily': _csv(_wordFamily),
      'register': _register,
      'modules': _modules.toList(),
      'status': _status,
      'isPublished': _status == 'published',
    };

    try {
      if (_editing) {
        await _repository.updateWord(
          id: widget.existing!.id,
          data: data,
        );
      } else {
        await _repository.createManualWord(data);
      }

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editing
                ? 'Vocabulary word updated.'
                : 'Vocabulary word created.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Word save nahi hua: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: _editing ? 'Edit Vocabulary Word' : 'Create Vocabulary Word',
      subtitle:
          'Manage meaning, translation, pronunciation, usage and IELTS metadata',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            _hero(),
            const SizedBox(height: 14),
            _section(
              'Core Word Information',
              Icons.translate_rounded,
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;

                  return Column(
                    children: [
                      _responsiveRow(
                        compact,
                        _field(
                          controller: _word,
                          label: 'Word',
                          required: true,
                        ),
                        _field(
                          controller: _partOfSpeech,
                          label: 'Part of Speech',
                          required: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _responsiveRow(
                        compact,
                        _field(
                          controller: _pronunciation,
                          label: 'Pronunciation',
                        ),
                        _field(
                          controller: _ipa,
                          label: 'IPA',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _meaning,
                        label: 'Meaning',
                        required: true,
                        lines: 3,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _translation,
                        label: 'Translation',
                        lines: 2,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _example,
                        label: 'Example Sentence',
                        required: true,
                        lines: 3,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _section(
              'IELTS Classification',
              Icons.tune_rounded,
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final dropdowns = [
                    _dropdown(
                      label: 'Category',
                      value: _category,
                      values: const {
                        'academic': 'Academic Vocabulary',
                        'topic': 'Topic Vocabulary',
                        'band_5': 'Band 5 Words',
                        'band_6': 'Band 6 Words',
                        'band_7': 'Band 7 Words',
                        'band_8_9': 'Band 8–9 Words',
                        'collocations': 'Collocations',
                        'phrasal_verbs': 'Phrasal Verbs',
                        'synonyms': 'Synonyms',
                        'spelling': 'Spelling Mistakes',
                      },
                      onChanged: (value) =>
                          setState(() => _category = value),
                    ),
                    _dropdown(
                      label: 'Band',
                      value: _band,
                      values: const {
                        'Band 5': 'Band 5',
                        'Band 6': 'Band 6',
                        'Band 7': 'Band 7',
                        'Band 8': 'Band 8',
                        'Band 8-9': 'Band 8–9',
                        'Band 9': 'Band 9',
                      },
                      onChanged: (value) =>
                          setState(() => _band = value),
                    ),
                    _dropdown(
                      label: 'Difficulty',
                      value: _difficulty,
                      values: const {
                        'Foundation': 'Foundation',
                        'Intermediate': 'Intermediate',
                        'Upper Intermediate': 'Upper Intermediate',
                        'Advanced': 'Advanced',
                        'Expert': 'Expert',
                      },
                      onChanged: (value) =>
                          setState(() => _difficulty = value),
                    ),
                    _dropdown(
                      label: 'Register',
                      value: _register,
                      values: const {
                        'formal': 'Formal',
                        'neutral': 'Neutral',
                        'informal': 'Informal',
                      },
                      onChanged: (value) =>
                          setState(() => _register = value),
                    ),
                  ];

                  if (compact) {
                    return Column(
                      children: [
                        for (var index = 0;
                            index < dropdowns.length;
                            index++) ...[
                          dropdowns[index],
                          if (index != dropdowns.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: dropdowns[0]),
                          const SizedBox(width: 10),
                          Expanded(child: dropdowns[1]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: dropdowns[2]),
                          const SizedBox(width: 10),
                          Expanded(child: dropdowns[3]),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _section(
              'Vocabulary Relationships',
              Icons.hub_outlined,
              Column(
                children: [
                  _field(
                    controller: _synonyms,
                    label: 'Synonyms (comma separated)',
                    lines: 2,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _antonyms,
                    label: 'Antonyms (comma separated)',
                    lines: 2,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _collocations,
                    label: 'Collocations (comma separated)',
                    lines: 2,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _wordFamily,
                    label: 'Word Family (comma separated)',
                    lines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _section(
              'Learning Guidance',
              Icons.lightbulb_outline_rounded,
              Column(
                children: [
                  _field(
                    controller: _topic,
                    label: 'IELTS Topic',
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _usageNote,
                    label: 'Usage Note',
                    lines: 3,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _commonMistake,
                    label: 'Common Mistake',
                    lines: 2,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _spellingTip,
                    label: 'Spelling Tip',
                    lines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _section(
              'IELTS Modules',
              Icons.apps_rounded,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final module in const [
                    'Listening',
                    'Reading',
                    'Writing',
                    'Speaking',
                  ])
                    FilterChip(
                      selected: _modules.contains(module),
                      label: Text(module),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _modules.add(module);
                          } else {
                            _modules.remove(module);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _section(
              'Publishing',
              Icons.public_rounded,
              _dropdown(
                label: 'Status',
                value: _status,
                values: const {
                  'draft': 'Draft',
                  'published': 'Published',
                  'archived': 'Archived',
                },
                onChanged: (value) => setState(() => _status = value),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : _editing
                          ? 'Update Vocabulary Word'
                          : 'Create Vocabulary Word',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.primary.withOpacity(.20),
            AdminColors.cyan.withOpacity(.08),
            AdminColors.violet.withOpacity(.13),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: AdminColors.cyan.withOpacity(.18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_rounded,
            color: AdminColors.cyan,
            size: 38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _editing
                  ? 'Edit every detail shown on the learner vocabulary card.'
                  : 'Create a complete IELTS vocabulary card manually.',
              style: const TextStyle(
                color: AdminColors.text,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    IconData icon,
    Widget child,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AdminColors.cyan),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: AdminColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _responsiveRow(
    bool compact,
    Widget first,
    Widget second,
  ) {
    if (compact) {
      return Column(
        children: [
          first,
          const SizedBox(height: 10),
          second,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool required = false,
    int lines = 1,
  }) {
    return TextFormField(
      controller: controller,
      minLines: lines,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: values.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: (newValue) {
        if (newValue != null) onChanged(newValue);
      },
    );
  }
}
