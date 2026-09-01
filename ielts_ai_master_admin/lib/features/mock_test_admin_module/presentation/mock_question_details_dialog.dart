import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/admin_theme.dart';
import '../domain/mock_admin_models.dart';

class MockQuestionDetailsDialog extends StatelessWidget {
  const MockQuestionDetailsDialog({
    super.key,
    required this.question,
    required this.displayPosition,
    required this.linkedMock,
    required this.qaHistory,
    required this.onEdit,
    required this.onAdvanceQa,
  });

  final MockAdminQuestion question;
  final int displayPosition;
  final Future<MockAdminTest?> linkedMock;
  final Stream<List<MockQuestionQaEvent>> qaHistory;
  final VoidCallback? onEdit;
  final VoidCallback? onAdvanceQa;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      backgroundColor: AdminColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 900),
        child: Column(
          children: [
            _header(context),
            if (onEdit != null || onAdvanceQa != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (onEdit != null)
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit question'),
                      ),
                    if (onAdvanceQa != null)
                      FilledButton.icon(
                        onPressed: onAdvanceQa,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(_nextQaLabel(question.status)),
                      ),
                  ],
                ),
              ),
            const Divider(height: 1, color: AdminColors.border),
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuestionQaTimeline(status: question.status),
                      const SizedBox(height: 16),
                      _overview(),
                      const SizedBox(height: 16),
                      _textSection('Full prompt', question.prompt),
                      if (question.instructions.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _textSection('Instructions', question.instructions),
                      ],
                      if (question.passage.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _textSection(
                          question.skill == MockAdminSkill.reading
                              ? 'Reading passage'
                              : 'Passage / context',
                          question.passage,
                        ),
                      ],
                      if (question.transcript.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _textSection(
                          'Listening transcript',
                          question.transcript,
                        ),
                      ],
                      if (question.skill == MockAdminSkill.listening) ...[
                        const SizedBox(height: 12),
                        QuestionAudioPreview(
                          audioUrl: question.audioUrl,
                          storagePath: question.audioStoragePath,
                          expectedDurationSeconds:
                              question.audioDurationSeconds,
                        ),
                      ],
                      if (question.options.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _options(),
                      ],
                      const SizedBox(height: 12),
                      _answerReview(),
                      if (_hasSkillMetadata) ...[
                        const SizedBox(height: 12),
                        _skillMetadata(),
                      ],
                      const SizedBox(height: 12),
                      _provenance(),
                      const SizedBox(height: 12),
                      _relationship(),
                      const SizedBox(height: 12),
                      _auditHistory(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
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
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Question preview & QA details',
                  style: TextStyle(
                    color: AdminColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${question.track.label} • ${question.skill.label} • ${question.sectionLabel}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _overview() {
    return _Panel(
      title: 'Question overview',
      icon: Icons.fact_check_outlined,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Fact(label: 'IELTS track', value: question.track.label),
          _Fact(label: 'Skill', value: question.skill.label),
          _Fact(label: 'Section / part', value: question.sectionLabel),
          _Fact(label: 'Stored number', value: '${question.number}'),
          _Fact(label: 'Question type', value: _pretty(question.type)),
          _Fact(label: 'Difficulty', value: question.difficulty),
          _Fact(label: 'Status', value: _pretty(question.status)),
          _Fact(label: 'Marks', value: '${question.marks}'),
          if (question.wordLimit.trim().isNotEmpty)
            _Fact(label: 'Word limit', value: question.wordLimit),
          if (question.qualityScore > 0)
            _Fact(
              label: 'Generation quality',
              value: '${question.qualityScore.round()}/100',
            ),
        ],
      ),
    );
  }

  Widget _textSection(String title, String value) {
    return _Panel(
      title: title,
      icon: Icons.subject_rounded,
      child: SelectableText(
        value.trim().isEmpty ? 'Not stored' : value.trim(),
        style: const TextStyle(
          color: AdminColors.text,
          fontSize: 14,
          height: 1.65,
        ),
      ),
    );
  }

  Widget _options() {
    return _Panel(
      title: 'Answer options',
      icon: Icons.format_list_bulleted_rounded,
      child: Column(
        children: [
          for (var index = 0; index < question.options.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == question.options.length - 1 ? 0 : 8,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Text(
                  '${String.fromCharCode(65 + index)}. ${question.options[index]}',
                  style: const TextStyle(color: AdminColors.text, height: 1.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _answerReview() {
    return _Panel(
      title: 'Answer key & rationale',
      icon: Icons.verified_outlined,
      accent: AdminColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accepted answer(s)',
            style: TextStyle(
              color: AdminColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          if (question.correctAnswers.isEmpty)
            Text(
              question.skill == MockAdminSkill.writing ||
                      question.skill == MockAdminSkill.speaking
                  ? 'AI-evaluated response — no fixed answer key.'
                  : 'No accepted answer is stored.',
              style: const TextStyle(color: AdminColors.text, height: 1.5),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: question.correctAnswers
                  .map(
                    (answer) => Chip(
                      avatar: const Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: AdminColors.success,
                      ),
                      label: Text(answer),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 14),
          const Text(
            'Explanation / rationale',
            style: TextStyle(
              color: AdminColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          SelectableText(
            question.explanation.trim().isEmpty
                ? 'No explanation is stored.'
                : question.explanation.trim(),
            style: const TextStyle(color: AdminColors.text, height: 1.55),
          ),
        ],
      ),
    );
  }

  bool get _hasSkillMetadata =>
      question.metadata.isNotEmpty ||
      question.taskType.isNotEmpty ||
      question.part > 0 ||
      question.cueCard.isNotEmpty;

  Widget _skillMetadata() {
    final explicitKeys = {
      'taskType',
      'part',
      'cueCard',
      'cue_card',
      'preparationSeconds',
      'speakingSeconds',
    };
    final extras = question.metadata.entries
        .where((entry) => !explicitKeys.contains(entry.key))
        .where(
          (entry) => entry.value != null && entry.value.toString().isNotEmpty,
        )
        .toList();

    return _Panel(
      title: question.skill == MockAdminSkill.writing
          ? 'Writing assessment metadata'
          : question.skill == MockAdminSkill.speaking
          ? 'Speaking part & cue card'
          : 'Assessment metadata',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (question.taskType.isNotEmpty)
                _Fact(label: 'Task type', value: question.taskType),
              if (question.part > 0)
                _Fact(label: 'Speaking part', value: 'Part ${question.part}'),
              if (question.preparationSeconds > 0)
                _Fact(
                  label: 'Preparation',
                  value: '${question.preparationSeconds}s',
                ),
              if (question.speakingSeconds > 0)
                _Fact(
                  label: 'Speaking time',
                  value: '${question.speakingSeconds}s',
                ),
              for (final entry in extras)
                _Fact(
                  label: _pretty(entry.key),
                  value: _metadataValue(entry.value),
                ),
            ],
          ),
          if (question.cueCard.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Cue card',
              style: TextStyle(
                color: AdminColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              question.cueCard,
              style: const TextStyle(color: AdminColors.text, height: 1.55),
            ),
          ],
        ],
      ),
    );
  }

  Widget _provenance() {
    return _Panel(
      title: 'Provenance & record metadata',
      icon: Icons.manage_search_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Fact(
                label: 'Source type',
                value: _valueOrMissing(question.sourceType),
              ),
              _Fact(
                label: 'Source reference',
                value: _valueOrMissing(question.sourceReference),
              ),
              _Fact(
                label: 'Rights review',
                value: _valueOrMissing(question.copyrightStatus),
              ),
              _Fact(
                label: 'Validation',
                value: _valueOrMissing(question.validationStatus),
              ),
              _Fact(label: 'Created', value: _date(question.createdAt)),
              _Fact(label: 'Updated', value: _date(question.updatedAt)),
              _Fact(label: 'Validated', value: _date(question.validatedAt)),
              _Fact(label: 'Approved', value: _date(question.approvedAt)),
              _Fact(label: 'Published', value: _date(question.publishedAt)),
              if (question.createdBy.isNotEmpty)
                _Fact(label: 'Created by', value: question.createdBy),
              if (question.validatedBy.isNotEmpty)
                _Fact(label: 'Validated by', value: question.validatedBy),
              if (question.approvedBy.isNotEmpty)
                _Fact(label: 'Approved by', value: question.approvedBy),
              if (question.publishedBy.isNotEmpty)
                _Fact(label: 'Published by', value: question.publishedBy),
              if (question.generatedBy.isNotEmpty)
                _Fact(label: 'Generated by', value: question.generatedBy),
              if (question.generatedModel.isNotEmpty)
                _Fact(
                  label: 'Generation model',
                  value: question.generatedModel,
                ),
              if (question.generationJobId.isNotEmpty)
                _Fact(label: 'Generation job', value: question.generationJobId),
            ],
          ),
          if (question.validationErrors.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Validation issues',
              style: TextStyle(
                color: AdminColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            for (final error in question.validationErrors)
              Text(
                '• $error',
                style: const TextStyle(color: AdminColors.text, height: 1.5),
              ),
          ],
        ],
      ),
    );
  }

  Widget _relationship() {
    return _Panel(
      title: 'Published mock relationship',
      icon: Icons.account_tree_outlined,
      child: FutureBuilder<MockAdminTest?>(
        future: linkedMock,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          if (question.mockTestId.isEmpty) {
            return const Text(
              'This question is not linked to a specific mock test.',
              style: TextStyle(color: AdminColors.textMuted),
            );
          }
          final mock = snapshot.data;
          if (mock == null) {
            return Text(
              'Mock reference: ${question.mockTestId} (record unavailable)',
              style: const TextStyle(color: AdminColors.warning),
            );
          }
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Fact(label: 'Mock test', value: mock.title),
              _Fact(label: 'Mock status', value: _pretty(mock.status)),
              _Fact(
                label: 'Student availability',
                value: mock.isPublished || mock.status == 'published'
                    ? 'Published mock'
                    : 'Not published',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _auditHistory() {
    return _Panel(
      title: 'QA audit history',
      icon: Icons.history_rounded,
      child: StreamBuilder<List<MockQuestionQaEvent>>(
        stream: qaHistory,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          final events = snapshot.data!;
          if (events.isEmpty) {
            return const Text(
              'No QA transition events are stored for this question yet.',
              style: TextStyle(color: AdminColors.textMuted),
            );
          }
          return Column(
            children: events.take(12).map((event) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: AdminColors.cyan,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_pretty(event.action)} • '
                        '${_pretty(event.fromState)} → ${_pretty(event.toState)}\n'
                        '${_date(event.createdAt)}'
                        '${event.adminEmail.isEmpty ? '' : ' • ${event.adminEmail}'}',
                        style: const TextStyle(
                          color: AdminColors.text,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  static String _valueOrMissing(String value) =>
      value.trim().isEmpty ? 'Not stored' : _pretty(value);

  static String _nextQaLabel(String status) => switch (status) {
    'draft' => 'Run validation',
    'validation_passed' => 'Approve question',
    'approved' => 'Publish question',
    _ => 'Advance QA',
  };

  static String _pretty(String value) {
    if (value.trim().isEmpty) return 'Not stored';
    return value
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static String _metadataValue(dynamic value) {
    if (value is Iterable) return value.join(', ');
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(', ');
    }
    return value.toString();
  }

  static String _date(DateTime? value) {
    if (value == null) return 'Not stored';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class QuestionQaTimeline extends StatelessWidget {
  const QuestionQaTimeline({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    const states = [
      ('draft', 'Draft'),
      ('validation_passed', 'Validation passed'),
      ('approved', 'Approved'),
      ('published', 'Published'),
    ];
    final current = states.indexWhere((entry) => entry.$1 == status);

    return _Panel(
      title: 'QA state',
      icon: Icons.rule_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status == 'archived')
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Archived — excluded from learner question loading.',
                style: TextStyle(
                  color: AdminColors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var index = 0; index < states.length; index++) ...[
                _QaStep(
                  label: states[index].$2,
                  complete: current >= index,
                  active: current == index,
                ),
                if (index < states.length - 1)
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: AdminColors.textMuted,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class QuestionAudioPreview extends StatefulWidget {
  const QuestionAudioPreview({
    super.key,
    required this.audioUrl,
    required this.storagePath,
    required this.expectedDurationSeconds,
  });

  final String audioUrl;
  final String storagePath;
  final int expectedDurationSeconds;

  @override
  State<QuestionAudioPreview> createState() => _QuestionAudioPreviewState();
}

class _QuestionAudioPreviewState extends State<QuestionAudioPreview> {
  final AudioPlayer _player = AudioPlayer();
  String? _resolvedUrl;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  Future<void> _resolveUrl() async {
    final directUrl = widget.audioUrl.trim();
    if (directUrl.isNotEmpty) {
      _resolvedUrl = directUrl;
      return;
    }
    final path = widget.storagePath.trim();
    if (path.isEmpty) return;
    try {
      final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
      if (mounted) setState(() => _resolvedUrl = url);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to resolve audio: $error');
    }
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    final url = _resolvedUrl;
    if (url == null || url.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_player.audioSource == null) await _player.setUrl(url);
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      unawaited(_player.play());
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to play audio: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasReference =
        widget.audioUrl.trim().isNotEmpty ||
        widget.storagePath.trim().isNotEmpty;
    return _Panel(
      title: 'Listening audio preview',
      icon: Icons.graphic_eq_rounded,
      accent: AdminColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing == true;
                  return FilledButton.icon(
                    onPressed: !hasReference || _loading || _resolvedUrl == null
                        ? null
                        : _toggle,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                    label: Text(playing ? 'Pause audio' : 'Play audio'),
                  );
                },
              ),
              StreamBuilder<Duration?>(
                stream: _player.durationStream,
                builder: (context, snapshot) {
                  final duration =
                      snapshot.data ??
                      Duration(seconds: widget.expectedDurationSeconds);
                  return Text(
                    'Duration ${_duration(duration)}',
                    style: const TextStyle(color: AdminColors.textMuted),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final duration =
                  _player.duration ??
                  Duration(seconds: widget.expectedDurationSeconds);
              final max = duration.inMilliseconds
                  .toDouble()
                  .clamp(1, double.infinity)
                  .toDouble();
              final value = (snapshot.data?.inMilliseconds.toDouble() ?? 0)
                  .clamp(0, max)
                  .toDouble();
              return Slider(
                value: value,
                max: max,
                onChanged: _player.audioSource == null
                    ? null
                    : (milliseconds) => _player.seek(
                        Duration(milliseconds: milliseconds.round()),
                      ),
              );
            },
          ),
          if (!hasReference)
            const Text(
              'No audio URL or Storage reference is stored.',
              style: TextStyle(color: AdminColors.warning),
            ),
          if (widget.audioUrl.trim().isNotEmpty)
            _ReferenceLine(label: 'Audio URL', value: widget.audioUrl),
          if (widget.storagePath.trim().isNotEmpty)
            _ReferenceLine(label: 'Storage path', value: widget.storagePath),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AdminColors.danger)),
          ],
        ],
      ),
    );
  }

  static String _duration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.accent = AdminColors.cyan,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 9,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(icon, size: 19, color: accent),
              Text(
                title,
                style: const TextStyle(
                  color: AdminColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 145, maxWidth: 310),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AdminColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: AdminColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QaStep extends StatelessWidget {
  const _QaStep({
    required this.label,
    required this.complete,
    required this.active,
  });

  final String label;
  final bool complete;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AdminColors.success : AdminColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: .13) : AdminColors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: active ? color : AdminColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(
                color: complete ? AdminColors.text : AdminColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceLine extends StatelessWidget {
  const _ReferenceLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: SelectableText(
        '$label: $value',
        style: const TextStyle(color: AdminColors.textMuted, fontSize: 11),
      ),
    );
  }
}
