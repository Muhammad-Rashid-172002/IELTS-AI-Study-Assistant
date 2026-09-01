import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../domain/mock_admin_models.dart';

class MockQuestionEditorDialog extends StatefulWidget {
  const MockQuestionEditorDialog({super.key, required this.question});

  final MockAdminQuestion question;

  @override
  State<MockQuestionEditorDialog> createState() =>
      _MockQuestionEditorDialogState();
}

class _MockQuestionEditorDialogState extends State<MockQuestionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _section;
  late final TextEditingController _type;
  late final TextEditingController _prompt;
  late final TextEditingController _passage;
  late final TextEditingController _transcript;
  late final TextEditingController _options;
  late final TextEditingController _answers;
  late final TextEditingController _explanation;
  late final TextEditingController _wordLimit;
  late final TextEditingController _instructions;
  late final TextEditingController _audioUrl;
  late final TextEditingController _audioStoragePath;
  late final TextEditingController _audioDuration;
  late final TextEditingController _marks;
  late final TextEditingController _taskType;
  late final TextEditingController _part;
  late final TextEditingController _cueCard;
  late final TextEditingController _preparationSeconds;
  late final TextEditingController _speakingSeconds;
  late final TextEditingController _topic;
  late String _difficulty;

  @override
  void initState() {
    super.initState();
    final question = widget.question;
    _number = TextEditingController(text: '${question.number}');
    _section = TextEditingController(text: question.sectionId);
    _type = TextEditingController(text: question.type);
    _prompt = TextEditingController(text: question.prompt);
    _passage = TextEditingController(text: question.passage);
    _transcript = TextEditingController(text: question.transcript);
    _options = TextEditingController(text: question.options.join('\n'));
    _answers = TextEditingController(text: question.correctAnswers.join('\n'));
    _explanation = TextEditingController(text: question.explanation);
    _wordLimit = TextEditingController(text: question.wordLimit);
    _instructions = TextEditingController(text: question.instructions);
    _audioUrl = TextEditingController(text: question.audioUrl);
    _audioStoragePath = TextEditingController(text: question.audioStoragePath);
    _audioDuration = TextEditingController(
      text: question.audioDurationSeconds == 0
          ? ''
          : '${question.audioDurationSeconds}',
    );
    _marks = TextEditingController(text: '${question.marks}');
    _taskType = TextEditingController(text: question.taskType);
    _part = TextEditingController(
      text: question.part == 0 ? '' : '${question.part}',
    );
    _cueCard = TextEditingController(text: question.cueCard);
    _preparationSeconds = TextEditingController(
      text: question.preparationSeconds == 0
          ? ''
          : '${question.preparationSeconds}',
    );
    _speakingSeconds = TextEditingController(
      text: question.speakingSeconds == 0 ? '' : '${question.speakingSeconds}',
    );
    _topic = TextEditingController(
      text: (question.metadata['topic'] ?? '').toString(),
    );
    _difficulty = question.difficulty;
  }

  @override
  void dispose() {
    for (final controller in [
      _number,
      _section,
      _type,
      _prompt,
      _passage,
      _transcript,
      _options,
      _answers,
      _explanation,
      _wordLimit,
      _instructions,
      _audioUrl,
      _audioStoragePath,
      _audioDuration,
      _marks,
      _taskType,
      _part,
      _cueCard,
      _preparationSeconds,
      _speakingSeconds,
      _topic,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requiresDraftReset = widget.question.status != 'draft';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      backgroundColor: AdminColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 900),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AdminColors.cyan),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Edit mock question',
                      style: TextStyle(
                        color: AdminColors.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (requiresDraftReset) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AdminColors.warning.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AdminColors.warning.withValues(alpha: .5),
                            ),
                          ),
                          child: const Text(
                            'Saving changes will first return this question to Draft. '
                            'It will be excluded from learner loading until it passes '
                            'validation, approval and publication again.',
                            style: TextStyle(
                              color: AdminColors.warning,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _sectionTitle('Identity & classification'),
                      _responsiveFields([
                        _readOnly('IELTS track', widget.question.track.label),
                        _readOnly('Skill', widget.question.skill.label),
                        _field(
                          controller: _number,
                          label: 'Question number',
                          keyboardType: TextInputType.number,
                          validator: _positiveInteger,
                        ),
                        _field(
                          controller: _section,
                          label: 'Section / part ID',
                          hint: 'section_1',
                          validator: _required,
                        ),
                        _field(
                          controller: _type,
                          label: 'Question type',
                          validator: _required,
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _difficulty,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Difficulty',
                          ),
                          items:
                              const [
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
                        _field(
                          controller: _marks,
                          label: 'Marks',
                          keyboardType: TextInputType.number,
                          validator: _positiveInteger,
                        ),
                        _field(controller: _topic, label: 'Topic'),
                      ]),
                      const SizedBox(height: 18),
                      _sectionTitle('Question content'),
                      _field(
                        controller: _prompt,
                        label: 'Full prompt',
                        maxLines: 5,
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _instructions,
                        label: 'Instructions',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _passage,
                        label: 'Passage / context',
                        maxLines: 8,
                      ),
                      if (widget.question.skill ==
                          MockAdminSkill.listening) ...[
                        const SizedBox(height: 12),
                        _field(
                          controller: _transcript,
                          label: 'Listening transcript',
                          maxLines: 8,
                        ),
                      ],
                      const SizedBox(height: 18),
                      _sectionTitle('Answers & feedback'),
                      _responsiveFields([
                        _field(
                          controller: _options,
                          label: 'Options — one per line',
                          maxLines: 6,
                          validator: _optionsValidator,
                        ),
                        _field(
                          controller: _answers,
                          label: 'Accepted answers — one per line',
                          maxLines: 6,
                          validator: _answersValidator,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _field(
                        controller: _explanation,
                        label: 'Explanation / rationale',
                        maxLines: 5,
                      ),
                      const SizedBox(height: 12),
                      _field(controller: _wordLimit, label: 'Word limit'),
                      if (widget.question.skill ==
                          MockAdminSkill.listening) ...[
                        const SizedBox(height: 18),
                        _sectionTitle('Listening audio'),
                        _responsiveFields([
                          _field(controller: _audioUrl, label: 'Audio URL'),
                          _field(
                            controller: _audioStoragePath,
                            label: 'Storage reference',
                          ),
                          _field(
                            controller: _audioDuration,
                            label: 'Duration in seconds',
                            keyboardType: TextInputType.number,
                            validator: _optionalNonNegativeInteger,
                          ),
                        ]),
                      ],
                      if (widget.question.skill == MockAdminSkill.writing) ...[
                        const SizedBox(height: 18),
                        _sectionTitle('Writing assessment metadata'),
                        _field(
                          controller: _taskType,
                          label: 'Writing task type',
                          validator: _required,
                        ),
                      ],
                      if (widget.question.skill == MockAdminSkill.speaking) ...[
                        const SizedBox(height: 18),
                        _sectionTitle('Speaking part & cue card'),
                        _responsiveFields([
                          _field(
                            controller: _part,
                            label: 'Speaking part (1–3)',
                            keyboardType: TextInputType.number,
                            validator: _speakingPart,
                          ),
                          _field(
                            controller: _preparationSeconds,
                            label: 'Preparation seconds',
                            keyboardType: TextInputType.number,
                            validator: _optionalNonNegativeInteger,
                          ),
                          _field(
                            controller: _speakingSeconds,
                            label: 'Speaking seconds',
                            keyboardType: TextInputType.number,
                            validator: _optionalNonNegativeInteger,
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _field(
                          controller: _cueCard,
                          label: 'Cue-card information',
                          maxLines: 6,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      requiresDraftReset ? 'Save as draft' : 'Save changes',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AdminColors.text,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _responsiveFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 680
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }

  Widget _readOnly(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value, style: const TextStyle(color: AdminColors.textMuted)),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final metadata = Map<String, dynamic>.from(widget.question.metadata);
    _setMetadata(metadata, 'topic', _topic.text.trim());
    _setMetadata(metadata, 'taskType', _taskType.text.trim());
    _setMetadata(metadata, 'part', int.tryParse(_part.text.trim()) ?? 0);
    _setMetadata(metadata, 'cueCard', _cueCard.text.trim());
    _setMetadata(
      metadata,
      'preparationSeconds',
      int.tryParse(_preparationSeconds.text.trim()) ?? 0,
    );
    _setMetadata(
      metadata,
      'speakingSeconds',
      int.tryParse(_speakingSeconds.text.trim()) ?? 0,
    );

    Navigator.pop(
      context,
      widget.question.copyWith(
        number: int.parse(_number.text.trim()),
        sectionId: _section.text.trim(),
        type: _type.text.trim(),
        prompt: _prompt.text.trim(),
        passage: _passage.text.trim(),
        transcript: _transcript.text.trim(),
        options: _lines(_options.text),
        correctAnswers: _lines(_answers.text),
        explanation: _explanation.text.trim(),
        wordLimit: _wordLimit.text.trim(),
        instructions: _instructions.text.trim(),
        audioUrl: _audioUrl.text.trim(),
        audioStoragePath: _audioStoragePath.text.trim(),
        audioDurationSeconds: int.tryParse(_audioDuration.text.trim()) ?? 0,
        marks: int.parse(_marks.text.trim()),
        difficulty: _difficulty,
        status: 'draft',
        metadata: metadata,
      ),
    );
  }

  static void _setMetadata(
    Map<String, dynamic> metadata,
    String key,
    dynamic value,
  ) {
    final empty = value == null || value == '' || value == 0;
    if (empty) {
      metadata.remove(key);
    } else {
      metadata[key] = value;
    }
  }

  static List<String> _lines(String value) => value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  static String? _positiveInteger(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < 1
        ? 'Enter a positive whole number'
        : null;
  }

  static String? _optionalNonNegativeInteger(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = int.tryParse(value.trim());
    return number == null || number < 0
        ? 'Enter zero or a positive number'
        : null;
  }

  static String? _speakingPart(String? value) {
    final part = int.tryParse(value?.trim() ?? '');
    return part == null || part < 1 || part > 3 ? 'Enter 1, 2 or 3' : null;
  }

  String? _optionsValidator(String? value) {
    final type = _type.text.trim().toLowerCase();
    final selectable =
        type.contains('multiple_choice') ||
        type.contains('multiple choice') ||
        type.contains('multiple_select') ||
        type.contains('multiple select');
    if (selectable && _lines(value ?? '').length < 2) {
      return 'Selectable questions require at least two options';
    }
    return null;
  }

  String? _answersValidator(String? value) {
    final objective =
        widget.question.skill == MockAdminSkill.listening ||
        widget.question.skill == MockAdminSkill.reading;
    if (objective && _lines(value ?? '').isEmpty) {
      return 'Listening and Reading questions require an accepted answer';
    }
    return null;
  }
}
