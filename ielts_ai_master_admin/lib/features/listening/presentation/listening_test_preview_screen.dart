import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/listening_admin_repository.dart';
import '../domain/listening_admin_test.dart';

class ListeningTestPreviewScreen extends StatelessWidget {
  final String testId;

  const ListeningTestPreviewScreen({
    super.key,
    required this.testId,
  });

  @override
  Widget build(BuildContext context) {
    final repository = ListeningAdminRepository();

    return AdminScaffold(
      title: 'Listening Test Preview',
      body: StreamBuilder<ListeningAdminTest?>(
        stream: repository.watchTest(testId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorView(message: 'Test load nahi hua.');
          }

          if (!snapshot.hasData) {
            return const LoadingView();
          }

          final test = snapshot.data;
          if (test == null) {
            return const ErrorView(message: 'Test not found.');
          }

          final audioReady =
              test.audioStatus.toLowerCase() == 'ready' &&
              test.audioUrl.trim().isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(status: test.status),
                      const SizedBox(height: 12),
                      Text(
                        test.title,
                        style: const TextStyle(
                          color: AdminColors.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        test.description,
                        style: const TextStyle(
                          color: AdminColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(_previewModeLabel(test.mode, test.section)),
                          _InfoChip(test.ieltsType),
                          _InfoChip(test.questionType),
                          _InfoChip(test.difficulty),
                          _InfoChip(test.accent),
                          _InfoChip(
                            'Quality ${test.qualityScore.toStringAsFixed(0)}%',
                          ),
                          _InfoChip(
                            audioReady ? 'Audio Ready' : 'Audio Pending',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Listening Audio',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _AudioPlayerCard(
                audioUrl: test.audioUrl,
                audioStatus: test.audioStatus,
                expectedDurationSeconds: test.audioDurationSeconds,
              ),
              const SizedBox(height: 16),
              const Text(
                'Transcript',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    test.transcript.isEmpty
                        ? 'No transcript available.'
                        : test.transcript,
                    style: const TextStyle(
                      color: AdminColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Questions (${test.questionCount})',
                style: const TextStyle(
                  color: AdminColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(
                test.questions.length,
                (index) {
                  final question = test.questions[index];
                  final options = question['options'] is List
                      ? List<dynamic>.from(question['options'])
                      : <dynamic>[];
                  final acceptedAnswers =
                      question['acceptedAnswers'] is List
                          ? List<dynamic>.from(
                              question['acceptedAnswers'],
                            )
                          : <dynamic>[];
                  final keywords = question['keywords'] is List
                      ? List<dynamic>.from(question['keywords'])
                      : <dynamic>[];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question ${index + 1}',
                              style: const TextStyle(
                                color: AdminColors.cyan,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (question['prompt'] ?? '').toString(),
                              style: const TextStyle(
                                color: AdminColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (options.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...options.map(
                                (option) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• $option',
                                    style: const TextStyle(
                                      color: AdminColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              'Answer: ${question['correctAnswer'] ?? ''}',
                              style: const TextStyle(
                                color: AdminColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (acceptedAnswers.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Accepted: ${acceptedAnswers.join(', ')}',
                                style: const TextStyle(
                                  color: AdminColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if ((question['explanation'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Explanation: ${question['explanation']}',
                                style: const TextStyle(
                                  color: AdminColors.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            if (keywords.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: keywords
                                    .map(
                                      (keyword) => Chip(
                                        visualDensity:
                                            VisualDensity.compact,
                                        label: Text(
                                          keyword.toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (!audioReady)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminColors.warning.withOpacity(.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AdminColors.warning.withOpacity(.35),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AdminColors.warning,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Audio ready hone ke baad test publish karein.',
                          style: TextStyle(
                            color: AdminColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (test.status != 'published')
                    FilledButton.icon(
                      onPressed: audioReady
                          ? () async {
                              final confirmed =
                                  await _confirmPublish(context);
                              if (!confirmed) return;

                              await repository.updateStatus(
                                id: test.id,
                                status: 'published',
                              );

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Listening test published successfully.',
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.public_rounded),
                      label: const Text('Publish'),
                    ),
                  if (test.status == 'published')
                    FilledButton.icon(
                      onPressed: () => repository.updateStatus(
                        id: test.id,
                        status: 'archived',
                      ),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archive'),
                    ),
                  if (test.status == 'archived')
                    FilledButton.icon(
                      onPressed: () => repository.updateStatus(
                        id: test.id,
                        status: 'draft',
                      ),
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restore Draft'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await _confirmDelete(context);
                      if (!confirmed) return;

                      await repository.deleteTest(test.id);

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmPublish(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Publish Listening Test?'),
              content: const Text(
                'Publish hone ke baad ye test users ko available ho jayega.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Publish'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete Test?'),
              content: const Text('Ye action undo nahi ho sakta.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

class _AudioPlayerCard extends StatefulWidget {
  final String audioUrl;
  final String audioStatus;
  final int expectedDurationSeconds;

  const _AudioPlayerCard({
    required this.audioUrl,
    required this.audioStatus,
    required this.expectedDurationSeconds,
  });

  @override
  State<_AudioPlayerCard> createState() =>
      _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<_AudioPlayerCard> {
  final AudioPlayer _player = AudioPlayer();

  String? _loadedUrl;
  String? _errorMessage;
  bool _loading = false;

  bool get _hasAudio =>
      widget.audioStatus.toLowerCase() == 'ready' &&
      widget.audioUrl.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  @override
  void didUpdateWidget(covariant _AudioPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.audioUrl != widget.audioUrl ||
        oldWidget.audioStatus != widget.audioStatus) {
      _loadAudio();
    }
  }

  Future<void> _loadAudio() async {
    if (!_hasAudio) {
      await _player.stop();

      if (!mounted) return;

      setState(() {
        _loadedUrl = null;
        _loading = false;
        _errorMessage = null;
      });
      return;
    }

    if (_loadedUrl == widget.audioUrl) return;

    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      await _player.setUrl(widget.audioUrl);

      if (!mounted) return;

      setState(() {
        _loadedUrl = widget.audioUrl;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Audio load nahi hui: $error';
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAudio) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0x22F59E0B),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  color: AdminColors.warning,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Audio not ready',
                      style: TextStyle(
                        color: AdminColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${widget.audioStatus.isEmpty ? 'pending' : widget.audioStatus}',
                      style: const TextStyle(
                        color: AdminColors.textMuted,
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

    if (_errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AdminColors.danger,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AdminColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loadAudio,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final state = snapshot.data;
                    final playing = state?.playing ?? false;
                    final processingState = state?.processingState;

                    final busy = _loading ||
                        processingState == ProcessingState.loading ||
                        processingState == ProcessingState.buffering;

                    if (busy) {
                      return const SizedBox(
                        width: 48,
                        height: 48,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        ),
                      );
                    }

                    if (processingState == ProcessingState.completed) {
                      return IconButton.filled(
                        onPressed: () async {
                          await _player.seek(Duration.zero);
                          await _player.play();
                        },
                        icon: const Icon(Icons.replay_rounded),
                      );
                    }

                    return IconButton.filled(
                      onPressed: () async {
                        if (playing) {
                          await _player.pause();
                        } else {
                          await _player.play();
                        }
                      },
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generated Listening Audio',
                        style: TextStyle(
                          color: AdminColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Google Cloud Text-to-Speech',
                        style: TextStyle(
                          color: AdminColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Stop',
                  onPressed: () async {
                    await _player.stop();
                    await _player.seek(Duration.zero);
                  },
                  icon: const Icon(Icons.stop_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;

                return StreamBuilder<Duration?>(
                  stream: _player.durationStream,
                  builder: (context, durationSnapshot) {
                    final fallbackDuration = Duration(
                      seconds: widget.expectedDurationSeconds,
                    );

                    final duration = durationSnapshot.data ??
                        (fallbackDuration > Duration.zero
                            ? fallbackDuration
                            : Duration.zero);

                    final maxMilliseconds = duration.inMilliseconds <= 0
                        ? 1.0
                        : duration.inMilliseconds.toDouble();

                    final value = position.inMilliseconds
                        .clamp(0, maxMilliseconds.toInt())
                        .toDouble();

                    return Column(
                      children: [
                        Slider(
                          min: 0,
                          max: maxMilliseconds,
                          value: value,
                          onChanged: duration <= Duration.zero
                              ? null
                              : (newValue) {
                                  _player.seek(
                                    Duration(
                                      milliseconds: newValue.round(),
                                    ),
                                  );
                                },
                        ),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(
                                color: AdminColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                color: AdminColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }
}

class _InfoChip extends StatelessWidget {
  final String text;

  const _InfoChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(text));
  }
}

String _previewModeLabel(String mode, int section) {
  switch (mode.toLowerCase()) {
    case 'timed': return 'Timed Listening';
    case 'exam': case 'full': return 'Full Test • Section $section';
    case 'accent': return 'Accent Training';
    case 'learning': return 'Learning Mode';
    case 'question_type': return 'Question Type Practice';
    default: return 'Section $section';
  }
}
