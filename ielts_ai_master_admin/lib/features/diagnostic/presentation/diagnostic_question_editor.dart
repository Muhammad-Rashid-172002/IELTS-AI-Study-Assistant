import 'package:flutter/material.dart';

import '../models/diagnostic_admin_models.dart';
import '../widgets/diagnostic_admin_widgets.dart';

class DiagnosticQuestionEditor extends StatefulWidget {
  final DiagnosticQuestionModel initial;

  const DiagnosticQuestionEditor({
    super.key,
    required this.initial,
  });

  @override
  State<DiagnosticQuestionEditor> createState() =>
      _DiagnosticQuestionEditorState();
}

class _DiagnosticQuestionEditorState
    extends State<DiagnosticQuestionEditor> {
  late final TextEditingController _prompt;
  late final TextEditingController _instruction;
  late final TextEditingController _answers;
  late final Map<String, TextEditingController> _options;
  late String _type;

  bool get _isChoice => {
        'multiple_choice',
        'true_false_not_given',
        'yes_no_not_given',
      }.contains(_type);

  @override
  void initState() {
    super.initState();

    _prompt =
        TextEditingController(text: widget.initial.prompt);
    _instruction =
        TextEditingController(text: widget.initial.instruction);
    _answers = TextEditingController(
      text: widget.initial.acceptedAnswers.join(', '),
    );
    _type = widget.initial.type;

    _options = {
      for (final key in ['A', 'B', 'C', 'D'])
        key: TextEditingController(
          text: widget.initial.options[key] ?? '',
        ),
    };
  }

  @override
  void dispose() {
    _prompt.dispose();
    _instruction.dispose();
    _answers.dispose();

    for (final controller in _options.values) {
      controller.dispose();
    }

    super.dispose();
  }

  void _save() {
    if (_prompt.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question prompt is required.'),
        ),
      );
      return;
    }

    final options = <String, String>{};

    if (_isChoice) {
      for (final entry in _options.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          options[entry.key] = entry.value.text.trim();
        }
      }
    }

    Navigator.pop(
      context,
      widget.initial.copyWith(
        id: widget.initial.id.isEmpty
            ? DateTime.now().microsecondsSinceEpoch.toString()
            : widget.initial.id,
        type: _type,
        prompt: _prompt.text.trim(),
        instruction: _instruction.text.trim(),
        options: options,
        acceptedAnswers: _answers.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DiagnosticAdminColors.surface,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(22),
          children: [
            const Text(
              'Question Editor',
              style: TextStyle(
                color: DiagnosticAdminColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Question Type',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'multiple_choice',
                  child: Text('Multiple Choice'),
                ),
                DropdownMenuItem(
                  value: 'true_false_not_given',
                  child: Text('True / False / Not Given'),
                ),
                DropdownMenuItem(
                  value: 'yes_no_not_given',
                  child: Text('Yes / No / Not Given'),
                ),
                DropdownMenuItem(
                  value: 'sentence_completion',
                  child: Text('Sentence Completion'),
                ),
                DropdownMenuItem(
                  value: 'short_answer',
                  child: Text('Short Answer'),
                ),
                DropdownMenuItem(
                  value: 'form_completion',
                  child: Text('Form Completion'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            const SizedBox(height: 13),
            TextField(
              controller: _instruction,
              decoration: const InputDecoration(
                labelText: 'Instruction',
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: _prompt,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Question Prompt',
                alignLabelWithHint: true,
              ),
            ),
            if (_isChoice) ...[
              const SizedBox(height: 13),
              ..._options.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: 'Option ${entry.key}',
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 3),
            TextField(
              controller: _answers,
              decoration: const InputDecoration(
                labelText: 'Accepted Answers',
                hintText:
                    'Use commas for alternatives, e.g. Wednesday, Wed',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Question'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
