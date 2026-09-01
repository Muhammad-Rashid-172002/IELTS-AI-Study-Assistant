import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/mock_admin_repository.dart';
import '../domain/mock_admin_models.dart';
import 'create_mock_question_job_sheet.dart';
import 'mock_question_details_dialog.dart';
import 'mock_question_editor_dialog.dart';

class MockQuestionBankScreen extends StatefulWidget {
  const MockQuestionBankScreen({super.key});

  @override
  State<MockQuestionBankScreen> createState() => _MockQuestionBankScreenState();
}

class _MockQuestionBankScreenState extends State<MockQuestionBankScreen> {
  final _repository = MockAdminRepository();

  MockAdminTrack _track = MockAdminTrack.academic;
  MockAdminSkill _skill = MockAdminSkill.listening;
  String _status = 'all';
  bool _busy = false;

  void _openGenerator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surface,
      builder: (_) => const CreateMockQuestionJobSheet(),
    );
  }

  Future<void> _openDetails(
    MockAdminQuestion question,
    int displayPosition,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => MockQuestionDetailsDialog(
        question: question,
        displayPosition: displayPosition,
        linkedMock: _repository.loadLinkedMockTest(question),
        qaHistory: _repository.watchQuestionQaHistory(question),
        onEdit: question.status == 'archived'
            ? null
            : () {
                Navigator.pop(dialogContext);
                _editQuestion(question);
              },
        onAdvanceQa: _nextQaState(question.status) == null
            ? null
            : () {
                Navigator.pop(dialogContext);
                _advanceQa(question);
              },
      ),
    );
  }

  Future<void> _editQuestion(MockAdminQuestion question) async {
    final edited = await showDialog<MockAdminQuestion>(
      context: context,
      builder: (_) => MockQuestionEditorDialog(question: question),
    );
    if (edited == null || !mounted) return;

    if (question.status != 'draft') {
      final confirmed = await _confirm(
        title: 'Return question to Draft?',
        message: question.status == 'published'
            ? 'This is a published question. Saving the edit will immediately '
                  'remove it from learner question loading and reset it to Draft. '
                  'It must pass validation and approval before publication again.'
            : 'Saving this edit resets the existing QA approval to Draft. '
                  'The question must pass validation and approval again.',
        confirmLabel: 'Return to Draft & Save',
        danger: question.status == 'published',
      );
      if (!confirmed) return;
    }

    await _runBusy(() async {
      if (question.status != 'draft') {
        final reset = await _repository.transitionQuestionQa(
          question: question,
          targetState: 'draft',
        );
        if (!reset.success) throw StateError(reset.errors.join('\n'));
      }
      await _repository.updateQuestion(question: edited);
      _notify(
        question.status == 'draft'
            ? 'Question changes saved.'
            : 'Question saved as Draft. Complete QA before republishing.',
      );
    });
  }

  Future<void> _advanceQa(MockAdminQuestion question) async {
    final next = _nextQaState(question.status);
    if (next == null) return;

    String? sourceType;
    String? sourceReference;
    String? copyrightStatus;

    if (next == 'validation_passed' &&
        (question.sourceType.isEmpty || question.sourceReference.isEmpty)) {
      final provenance = await _requestProvenance(question);
      if (provenance == null) return;
      sourceType = provenance.$1;
      sourceReference = provenance.$2;
    }

    if (next == 'approved') {
      copyrightStatus = await _requestCopyrightStatus(question.sourceType);
      if (copyrightStatus == null) return;
    }

    if (next == 'published') {
      final confirmed = await _confirm(
        title: 'Publish this question?',
        message:
            'This approved question will become eligible for learner mock '
            'tests. Confirm that its prompt, options, answer key, explanation '
            'and any audio have been previewed.',
        confirmLabel: 'Publish question',
      );
      if (!confirmed) return;
    }

    await _runBusy(() async {
      final result = await _repository.transitionQuestionQa(
        question: question,
        targetState: next,
        sourceType: sourceType,
        sourceReference: sourceReference,
        copyrightStatus: copyrightStatus,
      );
      if (!result.success) throw StateError(result.errors.join('\n'));
      _notify('Question moved to ${_pretty(result.state)}.');
    });
  }

  Future<void> _archiveQuestion(MockAdminQuestion question) async {
    final linked = question.mockTestId.isNotEmpty;
    final confirmed = await _confirm(
      title: 'Archive this question?',
      message:
          'Archived questions remain in the admin bank but are excluded '
          'from learner loading.${linked ? ' This question is linked to mock ${question.mockTestId}; verify the mock still has enough published questions.' : ''}',
      confirmLabel: 'Archive question',
      danger: true,
    );
    if (!confirmed) return;

    await _runBusy(() async {
      await _repository.updateQuestionStatus(
        track: question.track,
        skill: question.skill,
        id: question.id,
        status: 'archived',
      );
      _notify('Question archived and excluded from learner loading.');
    });
  }

  Future<void> _restoreDraft(MockAdminQuestion question) async {
    final confirmed = await _confirm(
      title: 'Restore as Draft?',
      message:
          'The question will return to Draft and remain unavailable to '
          'learners until the QA workflow is completed.',
      confirmLabel: 'Restore Draft',
    );
    if (!confirmed) return;
    await _runBusy(() async {
      await _repository.updateQuestionStatus(
        track: question.track,
        skill: question.skill,
        id: question.id,
        status: 'draft',
      );
      _notify('Question restored as Draft.');
    });
  }

  Future<void> _deleteQuestion(MockAdminQuestion question) async {
    final relationship = question.mockTestId.isEmpty
        ? ''
        : ' It is linked to mock ${question.mockTestId}.';
    final confirmed = await _confirm(
      title: 'Permanently delete question?',
      message:
          'This cannot be undone.$relationship Archive is safer when the '
          'question may be referenced by an existing mock.',
      confirmLabel: 'Delete permanently',
      danger: true,
    );
    if (!confirmed) return;
    await _runBusy(() async {
      await _repository.deleteQuestion(
        track: question.track,
        skill: question.skill,
        id: question.id,
      );
      _notify('Question permanently deleted.');
    });
  }

  Future<void> _publishApprovedVisible(
    List<MockAdminQuestion> questions,
  ) async {
    final approved = questions
        .where((question) => question.status == 'approved')
        .toList();
    if (approved.isEmpty) {
      _notify('No QA-approved questions are visible in this filter.');
      return;
    }
    final confirmed = await _confirm(
      title: 'Publish ${approved.length} approved question(s)?',
      message:
          'Only questions already in the Approved state will be published. '
          'Draft and validation-pending questions will be left unchanged.',
      confirmLabel: 'Publish approved',
    );
    if (!confirmed) return;

    await _runBusy(() async {
      await _repository.bulkUpdateQuestionStatus(
        track: _track,
        skill: _skill,
        ids: approved.map((question) => question.id),
        status: 'published',
      );
      _notify('${approved.length} approved question(s) published.');
    });
  }

  Future<void> _handleAction(
    String action,
    MockAdminQuestion question,
    int displayPosition,
  ) async {
    switch (action) {
      case 'preview':
      case 'qa_details':
        await _openDetails(question, displayPosition);
        return;
      case 'edit':
        await _editQuestion(question);
        return;
      case 'advance_qa':
        await _advanceQa(question);
        return;
      case 'archive':
        await _archiveQuestion(question);
        return;
      case 'restore':
        await _restoreDraft(question);
        return;
      case 'delete':
        await _deleteQuestion(question);
        return;
    }
  }

  Future<(String, String)?> _requestProvenance(
    MockAdminQuestion question,
  ) async {
    var sourceType = question.sourceType.isNotEmpty
        ? question.sourceType
        : question.generatedBy.isNotEmpty
        ? 'ai_generated'
        : 'admin_authored';
    final reference = TextEditingController(
      text: question.sourceReference.isNotEmpty
          ? question.sourceReference
          : question.generationJobId,
    );
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add source and provenance'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: sourceType,
                    decoration: const InputDecoration(labelText: 'Source type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'admin_authored',
                        child: Text('Admin-authored original'),
                      ),
                      DropdownMenuItem(
                        value: 'licensed',
                        child: Text('Licensed source'),
                      ),
                      DropdownMenuItem(
                        value: 'public_domain',
                        child: Text('Public-domain source'),
                      ),
                      DropdownMenuItem(
                        value: 'ai_generated',
                        child: Text('AI-generated draft'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => sourceType = value ?? sourceType),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'Source reference',
                      hintText: 'Internal brief, licence record, URL or job ID',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = reference.text.trim();
                if (value.isNotEmpty) {
                  Navigator.pop(dialogContext, (sourceType, value));
                }
              },
              child: const Text('Run validation'),
            ),
          ],
        ),
      ),
    );
    reference.dispose();
    return result;
  }

  Future<String?> _requestCopyrightStatus(String sourceType) {
    final options = switch (sourceType) {
      'licensed' => const [('licensed_use_verified', 'Licensed use verified')],
      'public_domain' => const [
        ('public_domain_verified', 'Public-domain status verified'),
      ],
      'ai_generated' => const [
        ('ai_generated_reviewed', 'AI-generated draft reviewed'),
      ],
      _ => const [('original_content_reviewed', 'Original content reviewed')],
    };
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm rights review'),
        content: const Text(
          'Approval records the rights/source review against the existing QA '
          'workflow. Select the applicable confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          for (final option in options)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, option.$1),
              child: Text(option.$2),
            ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: danger
                    ? FilledButton.styleFrom(
                        backgroundColor: AdminColors.danger,
                      )
                    : null,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _notify(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AdminColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Mock Question Bank',
      subtitle: 'Inspect, edit and QA reusable IELTS assessment content',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _openGenerator,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Generate Questions'),
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: StreamBuilder<List<MockAdminQuestion>>(
              stream: _repository.watchQuestions(
                track: _track,
                skill: _skill,
                status: _status,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _friendlyError(snapshot.error!),
                        style: const TextStyle(color: AdminColors.danger),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) return const LoadingView();
                final questions = snapshot.data!;

                return Column(
                  children: [
                    _availabilityNotice(questions),
                    Expanded(
                      child: questions.isEmpty
                          ? const Center(
                              child: Text(
                                'No questions found for this filter.',
                                style: TextStyle(color: AdminColors.textMuted),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                8,
                                20,
                                110,
                              ),
                              itemCount: questions.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _questionRow(questions[index], index + 1),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityNotice(List<MockAdminQuestion> questions) {
    final approved = questions
        .where((question) => question.status == 'approved')
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth >= 720
                      ? constraints.maxWidth - 250
                      : constraints.maxWidth,
                ),
                child: const Text(
                  'Only Published questions are available in the learner app. '
                  'Archived questions remain excluded.',
                  style: TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy || approved == 0
                    ? null
                    : () => _publishApprovedVisible(questions),
                icon: const Icon(Icons.public_rounded),
                label: Text('Publish approved ($approved)'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _questionRow(MockAdminQuestion question, int displayPosition) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminColors.cyan.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Q$displayPosition',
              style: const TextStyle(
                color: AdminColors.cyan,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openDetails(question, displayPosition),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.prompt.trim().isEmpty
                          ? 'Untitled question'
                          : question.prompt,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminColors.text,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _Tag(_pretty(question.type)),
                        _Tag(question.sectionLabel),
                        _Tag(question.difficulty),
                        _Tag(_pretty(question.status)),
                        if (question.mockTestId.isNotEmpty)
                          const _Tag('Linked to mock'),
                        if (question.skill == MockAdminSkill.listening &&
                            (question.audioUrl.isNotEmpty ||
                                question.audioStoragePath.isNotEmpty))
                          const _Tag('Audio ready'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            tooltip: 'Question actions',
            onSelected: (action) =>
                _handleAction(action, question, displayPosition),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'preview',
                child: _MenuItem(
                  icon: Icons.visibility_outlined,
                  label: 'View details / preview',
                ),
              ),
              const PopupMenuItem(
                value: 'qa_details',
                child: _MenuItem(icon: Icons.rule_rounded, label: 'QA details'),
              ),
              if (question.status != 'archived')
                const PopupMenuItem(
                  value: 'edit',
                  child: _MenuItem(icon: Icons.edit_outlined, label: 'Edit'),
                ),
              if (_nextQaState(question.status) != null)
                PopupMenuItem(
                  value: 'advance_qa',
                  child: _MenuItem(
                    icon: Icons.arrow_forward_rounded,
                    label: _nextQaAction(question.status),
                  ),
                ),
              const PopupMenuDivider(),
              if (question.status == 'archived')
                const PopupMenuItem(
                  value: 'restore',
                  child: _MenuItem(
                    icon: Icons.restore_rounded,
                    label: 'Restore as Draft',
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'archive',
                  child: _MenuItem(
                    icon: Icons.archive_outlined,
                    label: 'Archive',
                    color: AdminColors.warning,
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: _MenuItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: AdminColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          return Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 190,
                child: DropdownButtonFormField<MockAdminTrack>(
                  initialValue: _track,
                  decoration: const InputDecoration(labelText: 'IELTS Track'),
                  items: MockAdminTrack.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _track = value);
                  },
                ),
              ),
              SizedBox(
                width: compact ? constraints.maxWidth : 170,
                child: DropdownButtonFormField<MockAdminSkill>(
                  initialValue: _skill,
                  decoration: const InputDecoration(labelText: 'Skill'),
                  items: MockAdminSkill.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _skill = value);
                  },
                ),
              ),
              SizedBox(
                width: compact ? constraints.maxWidth : 190,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'QA status'),
                  items:
                      const {
                            'all': 'All',
                            'draft': 'Draft',
                            'validation_passed': 'Validation Passed',
                            'approved': 'Approved',
                            'published': 'Published',
                            'archived': 'Archived',
                          }.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String? _nextQaState(String status) => switch (status) {
    'draft' => 'validation_passed',
    'validation_passed' => 'approved',
    'approved' => 'published',
    _ => null,
  };

  static String _nextQaAction(String status) => switch (status) {
    'draft' => 'Run validation',
    'validation_passed' => 'Approve',
    'approved' => 'Publish',
    _ => 'Advance QA',
  };

  static String _pretty(String value) => value
      .replaceAll(RegExp(r'[_\-.]+'), ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  static String _friendlyError(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}

class _Tag extends StatelessWidget {
  const _Tag(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: AdminColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.color = AdminColors.text,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Flexible(
          child: Text(label, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
