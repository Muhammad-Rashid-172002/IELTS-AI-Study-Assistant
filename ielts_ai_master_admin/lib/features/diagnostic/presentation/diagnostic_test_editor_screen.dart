import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/diagnostic_admin_repository.dart';
import '../models/diagnostic_admin_models.dart';
import '../widgets/diagnostic_admin_widgets.dart';
import 'diagnostic_question_editor.dart';

class DiagnosticTestEditorScreen extends StatefulWidget {
  final DiagnosticTestAdminModel? test;

  const DiagnosticTestEditorScreen({
    super.key,
    this.test,
  });

  @override
  State<DiagnosticTestEditorScreen> createState() =>
      _DiagnosticTestEditorScreenState();
}

class _DiagnosticTestEditorScreenState
    extends State<DiagnosticTestEditorScreen> {
  final _repository = DiagnosticAdminRepository();

  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _duration;
  late final TextEditingController _listeningTitle;
  late final TextEditingController _readingTitle;
  late final TextEditingController _readingPassage;
  late final TextEditingController _writingPrompt;
  late final TextEditingController _writingWords;
  late final TextEditingController _writingMinutes;

  late String _ieltsType;
  late String _writingTaskType;
  late List<DiagnosticQuestionModel> _listeningQuestions;
  late List<DiagnosticQuestionModel> _readingQuestions;
  late List<SpeakingPromptModel> _speakingPrompts;

  String _audioUrl = '';
  bool _saving = false;
  bool _uploading = false;
  String? _testId;

  @override
  void initState() {
    super.initState();

    final test = widget.test ?? DiagnosticTestAdminModel.empty();

    _testId = test.id.isEmpty ? null : test.id;
    _title = TextEditingController(text: test.title);
    _description =
        TextEditingController(text: test.description);
    _duration = TextEditingController(
      text: '${test.totalDurationMinutes}',
    );
    _listeningTitle =
        TextEditingController(text: test.listeningTitle);
    _readingTitle =
        TextEditingController(text: test.readingPassageTitle);
    _readingPassage =
        TextEditingController(text: test.readingPassage);
    _writingPrompt =
        TextEditingController(text: test.writingPrompt);
    _writingWords = TextEditingController(
      text: '${test.writingMinimumWords}',
    );
    _writingMinutes = TextEditingController(
      text: '${test.writingRecommendedMinutes}',
    );

    _ieltsType = test.ieltsType;
    _writingTaskType = test.writingTaskType;
    _listeningQuestions = [...test.listeningQuestions];
    _readingQuestions = [...test.readingQuestions];
    _speakingPrompts = [...test.speakingPrompts];
    _audioUrl = test.listeningAudioUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    _listeningTitle.dispose();
    _readingTitle.dispose();
    _readingPassage.dispose();
    _writingPrompt.dispose();
    _writingWords.dispose();
    _writingMinutes.dispose();
    super.dispose();
  }

  DiagnosticTestAdminModel _buildModel({
    String status = 'draft',
  }) {
    return DiagnosticTestAdminModel(
      id: _testId ?? '',
      title: _title.text.trim(),
      description: _description.text.trim(),
      status: status,
      ieltsType: _ieltsType,
      totalDurationMinutes:
          int.tryParse(_duration.text.trim()) ?? 30,
      listeningTitle: _listeningTitle.text.trim(),
      listeningAudioUrl: _audioUrl,
      listeningQuestions: _listeningQuestions,
      readingPassageTitle: _readingTitle.text.trim(),
      readingPassage: _readingPassage.text.trim(),
      readingQuestions: _readingQuestions,
      writingTaskType: _writingTaskType,
      writingPrompt: _writingPrompt.text.trim(),
      writingMinimumWords:
          int.tryParse(_writingWords.text.trim()) ?? 150,
      writingRecommendedMinutes:
          int.tryParse(_writingMinutes.text.trim()) ?? 20,
      speakingPrompts: _speakingPrompts,
      createdAt: widget.test?.createdAt,
      updatedAt: widget.test?.updatedAt,
      publishedAt: widget.test?.publishedAt,
      generationProgress: widget.test?.generationProgress ?? 0,
      generationStep: widget.test?.generationStep ?? '',
      generationError: widget.test?.generationError ?? '',
      generationJobId: widget.test?.generationJobId ?? '',
    );
  }

  Future<void> _saveDraft() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final model = _buildModel();

      if (_testId == null) {
        _testId = await _repository.createDraft(model);
      } else {
        await _repository.updateTest(model);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostic draft saved.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    if (_testId == null) {
      await _saveDraft();
    }

    final model = _buildModel(status: 'published');
    final issues = model.validationIssues;

    if (issues.isNotEmpty) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Publish Yet'),
          content: Text(
            issues.map((item) => '• $item').join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _repository.publishTest(
        model.copyWithId(_testId!),
      );

      if (!mounted) return;

      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadAudio() async {
    if (_testId == null) {
      await _saveDraft();
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return;
    }

    final file = result.files.single;
    final Uint8List bytes = file.bytes!;

    setState(() => _uploading = true);

    try {
      final url = await _repository.uploadListeningAudio(
        testId: _testId!,
        bytes: bytes,
        fileName: file.name,
        contentType: _contentType(file.extension),
      );

      setState(() => _audioUrl = url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editQuestion({
    required bool listening,
    DiagnosticQuestionModel? existing,
    int? index,
  }) async {
    final result = await showDialog<DiagnosticQuestionModel>(
      context: context,
      builder: (_) => DiagnosticQuestionEditor(
        initial: existing ?? DiagnosticQuestionModel.empty(),
      ),
    );

    if (result == null) return;

    setState(() {
      final list =
          listening ? _listeningQuestions : _readingQuestions;

      if (index == null) {
        list.add(result);
      } else {
        list[index] = result;
      }
    });
  }

  void _addSpeakingPrompt() {
    setState(() {
      _speakingPrompts.add(SpeakingPromptModel.empty());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DiagnosticAdminColors.background,
      appBar: AppBar(
        backgroundColor: DiagnosticAdminColors.background,
        title: Text(
          _testId == null
              ? 'Create Diagnostic Test'
              : 'Edit Diagnostic Test',
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Draft'),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _publish,
              icon: const Icon(Icons.publish_rounded),
              label: const Text('Publish'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          _generalSection(),
          const SizedBox(height: 16),
          _listeningSection(),
          const SizedBox(height: 16),
          _readingSection(),
          const SizedBox(height: 16),
          _writingSection(),
          const SizedBox(height: 16),
          _speakingSection(),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _generalSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: diagnosticPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiagnosticSectionHeader(
            title: 'Test Configuration',
            subtitle:
                'Basic information, track and total duration.',
            icon: Icons.tune_rounded,
            color: DiagnosticAdminColors.cyan,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Test Title',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 650;

              final fields = [
                DropdownButtonFormField<String>(
                  value: _ieltsType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'IELTS Type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Academic',
                      child: Text('Academic'),
                    ),
                    DropdownMenuItem(
                      value: 'General Training',
                      child: Text('General Training'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _ieltsType = value);
                    }
                  },
                ),
                TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                  ),
                ),
              ];

              if (narrow) {
                return Column(
                  children: [
                    fields[0],
                    const SizedBox(height: 12),
                    fields[1],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 12),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _listeningSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: diagnosticPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiagnosticSectionHeader(
            title: 'Listening',
            subtitle:
                'Upload real audio and create objective questions.',
            icon: Icons.headphones_rounded,
            color: DiagnosticAdminColors.cyan,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _listeningTitle,
            decoration: const InputDecoration(
              labelText: 'Listening Title',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _audioUrl.isEmpty
                      ? 'No audio uploaded'
                      : 'Listening audio uploaded successfully',
                  style: TextStyle(
                    color: _audioUrl.isEmpty
                        ? DiagnosticAdminColors.muted
                        : DiagnosticAdminColors.green,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _uploading ? null : _uploadAudio,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: Text(
                  _audioUrl.isEmpty
                      ? 'Upload Audio'
                      : 'Replace Audio',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _questionList(
            title: 'Listening Questions',
            questions: _listeningQuestions,
            listening: true,
          ),
        ],
      ),
    );
  }

  Widget _readingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: diagnosticPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiagnosticSectionHeader(
            title: 'Reading',
            subtitle:
                'Create the passage and IELTS-style question set.',
            icon: Icons.menu_book_rounded,
            color: DiagnosticAdminColors.blue,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _readingTitle,
            decoration: const InputDecoration(
              labelText: 'Passage Title',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _readingPassage,
            minLines: 10,
            maxLines: 24,
            decoration: const InputDecoration(
              labelText: 'Reading Passage',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          _questionList(
            title: 'Reading Questions',
            questions: _readingQuestions,
            listening: false,
          ),
        ],
      ),
    );
  }

  Widget _writingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: diagnosticPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiagnosticSectionHeader(
            title: 'Writing',
            subtitle:
                'Set the task that the AI evaluator will score.',
            icon: Icons.edit_note_rounded,
            color: DiagnosticAdminColors.violet,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _writingTaskType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Task Type',
            ),
            items: const [
              DropdownMenuItem(
                value: 'Academic Task 1',
                child: Text('Academic Task 1'),
              ),
              DropdownMenuItem(
                value: 'General Training Task 1',
                child: Text('General Training Task 1'),
              ),
              DropdownMenuItem(
                value: 'Writing Task 2',
                child: Text('Writing Task 2'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _writingTaskType = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _writingPrompt,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Writing Prompt',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _writingWords,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Words',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _writingMinutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Recommended Minutes',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _speakingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: diagnosticPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiagnosticSectionHeader(
            title: 'Speaking',
            subtitle:
                'Create prompts for the recorded Speaking assessment.',
            icon: Icons.mic_rounded,
            color: DiagnosticAdminColors.orange,
          ),
          const SizedBox(height: 18),
          ...List.generate(_speakingPrompts.length, (index) {
            final prompt = _speakingPrompts[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DiagnosticAdminColors.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: DiagnosticAdminColors.border,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: prompt.part,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Part',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Part 1',
                              child: Text('Part 1'),
                            ),
                            DropdownMenuItem(
                              value: 'Part 2',
                              child: Text('Part 2'),
                            ),
                            DropdownMenuItem(
                              value: 'Part 3',
                              child: Text('Part 3'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _speakingPrompts[index] =
                                    prompt.copyWith(part: value);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: prompt.duration,
                          decoration: const InputDecoration(
                            labelText: 'Duration',
                          ),
                          onChanged: (value) {
                            _speakingPrompts[index] =
                                prompt.copyWith(duration: value);
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _speakingPrompts.removeAt(index);
                          });
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: DiagnosticAdminColors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: prompt.prompt,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Speaking Prompt',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (value) {
                      _speakingPrompts[index] =
                          prompt.copyWith(prompt: value);
                    },
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: _addSpeakingPrompt,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Speaking Prompt'),
          ),
        ],
      ),
    );
  }

  Widget _questionList({
    required String title,
    required List<DiagnosticQuestionModel> questions,
    required bool listening,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              '$title (${questions.length})',
              style: const TextStyle(
                color: DiagnosticAdminColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _editQuestion(
                listening: listening,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Question'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (questions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: DiagnosticAdminColors.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No questions added yet.',
              style: TextStyle(
                color: DiagnosticAdminColors.muted,
              ),
            ),
          )
        else
          ...List.generate(questions.length, (index) {
            final question = questions[index];

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text('${index + 1}'),
              ),
              title: Text(
                question.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(question.type),
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: () => _editQuestion(
                      listening: listening,
                      existing: question,
                      index: index,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => questions.removeAt(index));
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: DiagnosticAdminColors.red,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  static String _contentType(String? extension) {
    return switch (extension?.toLowerCase()) {
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => 'audio/mpeg',
    };
  }
}

extension on DiagnosticTestAdminModel {
  DiagnosticTestAdminModel copyWithId(String id) {
    return DiagnosticTestAdminModel(
      id: id,
      title: title,
      description: description,
      status: status,
      ieltsType: ieltsType,
      totalDurationMinutes: totalDurationMinutes,
      listeningTitle: listeningTitle,
      listeningAudioUrl: listeningAudioUrl,
      listeningQuestions: listeningQuestions,
      readingPassageTitle: readingPassageTitle,
      readingPassage: readingPassage,
      readingQuestions: readingQuestions,
      writingTaskType: writingTaskType,
      writingPrompt: writingPrompt,
      writingMinimumWords: writingMinimumWords,
      writingRecommendedMinutes: writingRecommendedMinutes,
      speakingPrompts: speakingPrompts,
      createdAt: createdAt,
      updatedAt: updatedAt,
      publishedAt: publishedAt,
      generationProgress: generationProgress,
      generationStep: generationStep,
      generationError: generationError,
      generationJobId: generationJobId,
    );
  }
}
