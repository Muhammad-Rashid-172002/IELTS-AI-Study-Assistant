import 'dart:async';

import 'package:flutter/material.dart';

import '../data/diagnostic_admin_repository.dart';
import '../models/diagnostic_generation_job.dart';
import '../widgets/diagnostic_admin_widgets.dart';

class DiagnosticAiGenerationDialog extends StatefulWidget {
  const DiagnosticAiGenerationDialog({super.key});

  @override
  State<DiagnosticAiGenerationDialog> createState() =>
      _DiagnosticAiGenerationDialogState();
}

class _DiagnosticAiGenerationDialogState
    extends State<DiagnosticAiGenerationDialog> {
  final _repository = DiagnosticAdminRepository();
  final _title = TextEditingController(
    text: 'Academic Diagnostic Test',
  );
  final _topic = TextEditingController(
    text: 'Education, technology and everyday life',
  );

  String _ieltsType = 'Academic';
  String _difficulty = 'Intermediate';
  String _writingTaskType = 'Academic Task 1';
  int _listeningQuestions = 10;
  int _readingQuestions = 10;
  int _speakingPrompts = 3;
  int _duration = 30;
  bool _starting = false;
  String? _jobId;
  String? _testId;
  StreamSubscription<DiagnosticGenerationJob?>? _subscription;
  DiagnosticGenerationJob? _job;

  @override
  void dispose() {
    _subscription?.cancel();
    _title.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;

    if (_title.text.trim().isEmpty || _topic.text.trim().isEmpty) {
      _message('Title and topic are required.');
      return;
    }

    setState(() => _starting = true);

    try {
      final result = await _repository.generateWithAi(
        title: _title.text,
        ieltsType: _ieltsType,
        difficulty: _difficulty,
        topic: _topic.text,
        listeningQuestionCount: _listeningQuestions,
        readingQuestionCount: _readingQuestions,
        writingTaskType: _writingTaskType,
        speakingPromptCount: _speakingPrompts,
        durationMinutes: _duration,
      );

      _jobId = result.jobId;
      _testId = result.testId;
      await _subscription?.cancel();
      _subscription = _repository
          .watchGenerationJob(result.jobId)
          .listen((job) {
        if (!mounted) return;
        setState(() => _job = job);
      });
    } catch (error) {
      if (mounted) _message('AI generation failed to start: $error');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;

    return Dialog(
      backgroundColor: DiagnosticAdminColors.surface,
      insetPadding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: job == null ? _setup() : _progress(job),
        ),
      ),
    );
  }

  Widget _setup() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0x1F22D3EE),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: DiagnosticAdminColors.cyan,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generate Diagnostic with AI',
                      style: TextStyle(
                        color: DiagnosticAdminColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Gemini creates Listening, Reading, Writing and Speaking content. Admin reviews before publishing.',
                      style: TextStyle(
                        color: DiagnosticAdminColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Test Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topic,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Theme / Topic Guidance',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 620;
              final fields = [
                _dropdown(
                  label: 'IELTS Type',
                  value: _ieltsType,
                  values: const ['Academic', 'General Training'],
                  onChanged: (value) {
                    setState(() {
                      _ieltsType = value;
                      _writingTaskType = value == 'Academic'
                          ? 'Academic Task 1'
                          : 'General Training Task 1';
                    });
                  },
                ),
                _dropdown(
                  label: 'Difficulty',
                  value: _difficulty,
                  values: const ['Foundation', 'Intermediate', 'Advanced'],
                  onChanged: (value) =>
                      setState(() => _difficulty = value),
                ),
              ];

              return narrow
                  ? Column(
                      children: [
                        fields[0],
                        const SizedBox(height: 12),
                        fields[1],
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 12),
                        Expanded(child: fields[1]),
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Writing Task',
            value: _writingTaskType,
            values: _ieltsType == 'Academic'
                ? const ['Academic Task 1', 'Writing Task 2']
                : const ['General Training Task 1', 'Writing Task 2'],
            onChanged: (value) =>
                setState(() => _writingTaskType = value),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _numberField('Listening Questions', _listeningQuestions,
                  (v) => _listeningQuestions = v, 5, 40),
              _numberField('Reading Questions', _readingQuestions,
                  (v) => _readingQuestions = v, 5, 40),
              _numberField('Speaking Prompts', _speakingPrompts,
                  (v) => _speakingPrompts = v, 1, 8),
              _numberField('Duration (min)', _duration,
                  (v) => _duration = v, 15, 90),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: _starting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _starting ? null : _start,
                icon: _starting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generate with AI'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progress(DiagnosticGenerationJob job) {
    final failed = job.isFailed;
    final completed = job.isCompleted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          completed
              ? Icons.check_circle_rounded
              : failed
                  ? Icons.error_rounded
                  : Icons.auto_awesome_rounded,
          color: completed
              ? DiagnosticAdminColors.green
              : failed
                  ? DiagnosticAdminColors.red
                  : DiagnosticAdminColors.cyan,
          size: 56,
        ),
        const SizedBox(height: 14),
        Text(
          completed
              ? 'Diagnostic Generated'
              : failed
                  ? 'Generation Failed'
                  : 'AI is Building the Test',
          style: const TextStyle(
            color: DiagnosticAdminColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          failed ? job.error : job.currentStep,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: failed
                ? DiagnosticAdminColors.red
                : DiagnosticAdminColors.muted,
          ),
        ),
        const SizedBox(height: 18),
        LinearProgressIndicator(
          value: job.progress.clamp(0, 100) / 100,
          minHeight: 9,
          borderRadius: BorderRadius.circular(20),
        ),
        const SizedBox(height: 8),
        Text(
          '${job.progress.clamp(0, 100)}%',
          style: const TextStyle(
            color: DiagnosticAdminColors.cyan,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (failed)
              OutlinedButton.icon(
                onPressed: () async {
                  if (_jobId != null) {
                    await _repository.retryAiGeneration(_jobId!);
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            if (failed) const SizedBox(width: 10),
            FilledButton(
              onPressed: completed || failed
                  ? () => Navigator.pop(context, _testId)
                  : null,
              child: Text(completed ? 'Review Test' : 'Close'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: values.contains(value) ? value : values.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (item) {
        if (item != null) onChanged(item);
      },
    );
  }

  Widget _numberField(
    String label,
    int value,
    ValueChanged<int> onChanged,
    int minimum,
    int maximum,
  ) {
    return SizedBox(
      width: 160,
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null) {
            onChanged(parsed.clamp(minimum, maximum));
          }
        },
      ),
    );
  }
}
