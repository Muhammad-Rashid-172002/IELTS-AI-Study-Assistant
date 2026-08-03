import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/speaking_admin_repository.dart';
import '../domain/speaking_admin_test.dart';

class SpeakingTestPreviewScreen extends StatefulWidget {
  final String testId;

  const SpeakingTestPreviewScreen({
    super.key,
    required this.testId,
  });

  @override
  State<SpeakingTestPreviewScreen> createState() =>
      _SpeakingTestPreviewScreenState();
}

class _SpeakingTestPreviewScreenState
    extends State<SpeakingTestPreviewScreen> {
  final _repository = SpeakingAdminRepository();
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(String url) async {
    if (url.isEmpty) return;

    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }

    await _player.setUrl(url);
    setState(() => _playing = true);
    await _player.play();

    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Speaking Test Preview',
      subtitle: 'Review questions, cue cards, model audio and guidance',
      body: StreamBuilder<SpeakingAdminTest?>(
        stream: _repository.watchTest(widget.testId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorView(
              message: 'Speaking test load nahi hua.',
            );
          }

          if (!snapshot.hasData) {
            return const LoadingView();
          }

          final test = snapshot.data;
          if (test == null) {
            return const ErrorView(
              message: 'Speaking test not found.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              _hero(test),
              if (test.modelAudioUrl.isNotEmpty) ...[
                const SizedBox(height: 14),
                _section(
                  'Model Audio',
                  Icons.multitrack_audio_rounded,
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          test.modelAudioStatus == 'ready'
                              ? 'Model audio is ready for shadowing and comparison.'
                              : 'Model audio status: ${test.modelAudioStatus}',
                          style: const TextStyle(
                            color: AdminColors.textMuted,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            _toggleAudio(test.modelAudioUrl),
                        icon: Icon(
                          _playing
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(_playing ? 'Stop' : 'Play'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ...test.parts.map((part) {
                final questions = part['questions'] is List
                    ? List<Map<String, dynamic>>.from(
                        (part['questions'] as List).map(
                          (item) => Map<String, dynamic>.from(
                            item as Map,
                          ),
                        ),
                      )
                    : <Map<String, dynamic>>[];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _section(
                    'Part ${part['part'] ?? '-'} • ${part['title'] ?? ''}',
                    Icons.question_answer_outlined,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (part['instructions'] ?? '').toString(),
                          style: const TextStyle(
                            color: AdminColors.textMuted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Preparation: ${part['preparationSeconds'] ?? 0}s • '
                          'Speaking: ${part['speakingSeconds'] ?? 0}s',
                          style: const TextStyle(
                            color: AdminColors.cyan,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...questions.map((question) {
                          final followUps =
                              question['followUpQuestions'] is List
                                  ? List<dynamic>.from(
                                      question['followUpQuestions'],
                                    )
                                  : <dynamic>[];
                          final guide = question['answerGuide'] is List
                              ? List<dynamic>.from(
                                  question['answerGuide'],
                                )
                              : <dynamic>[];

                          return _QuestionTile(
                            number:
                                (question['number'] ?? '').toString(),
                            question:
                                (question['question'] ?? '').toString(),
                            followUps: followUps
                                .map((e) => e.toString())
                                .toList(),
                            guide:
                                guide.map((e) => e.toString()).toList(),
                            modelAnswer:
                                (question['modelAnswer'] ?? '')
                                    .toString(),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
              if (test.dailyChallenge.isNotEmpty) ...[
                _section(
                  'Daily Challenge',
                  Icons.local_fire_department_outlined,
                  _MapView(data: test.dailyChallenge),
                ),
                const SizedBox(height: 14),
              ],
              if (test.pronunciationPractice.isNotEmpty) ...[
                _section(
                  'Pronunciation Practice',
                  Icons.record_voice_over_outlined,
                  _MapView(data: test.pronunciationPractice),
                ),
                const SizedBox(height: 14),
              ],
              if (test.fluencyTraining.isNotEmpty) ...[
                _section(
                  'Fluency Training',
                  Icons.speed_rounded,
                  _MapView(data: test.fluencyTraining),
                ),
                const SizedBox(height: 14),
              ],
              _section(
                'Evaluation Focus',
                Icons.analytics_outlined,
                _StringList(items: test.evaluationFocus),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  if (test.status != 'published')
                    FilledButton.icon(
                      onPressed: () => _repository.updateStatus(
                        id: test.id,
                        status: 'published',
                      ),
                      icon: const Icon(Icons.public_rounded),
                      label: const Text('Publish'),
                    ),
                  if (test.status == 'published')
                    OutlinedButton.icon(
                      onPressed: () => _repository.updateStatus(
                        id: test.id,
                        status: 'archived',
                      ),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archive'),
                    ),
                  if (test.status == 'archived')
                    OutlinedButton.icon(
                      onPressed: () => _repository.updateStatus(
                        id: test.id,
                        status: 'draft',
                      ),
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restore Draft'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _repository.duplicateTest(test.id),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Duplicate'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _repository.deleteTest(test.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                    ),
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

  Widget _hero(SpeakingAdminTest test) {
    final color = switch (test.status) {
      'published' => AdminColors.success,
      'archived' => AdminColors.violet,
      _ => AdminColors.cyan,
    };

    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.primary.withOpacity(.20),
            AdminColors.cyan.withOpacity(.08),
            AdminColors.violet.withOpacity(.14),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AdminColors.cyan.withOpacity(.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            test.status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            test.title,
            style: const TextStyle(
              color: AdminColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            test.description,
            style: const TextStyle(
              color: AdminColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${test.modeLabel} • ${test.accent} • '
            '${test.difficulty} • ${test.totalQuestions} questions • '
            '${test.durationLabel}',
            style: const TextStyle(
              color: AdminColors.cyan,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AdminColors.text,
                    fontWeight: FontWeight.w900,
                  ),
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

class _QuestionTile extends StatelessWidget {
  final String number;
  final String question;
  final List<String> followUps;
  final List<String> guide;
  final String modelAnswer;

  const _QuestionTile({
    required this.number,
    required this.question,
    required this.followUps,
    required this.guide,
    required this.modelAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question $number',
            style: const TextStyle(
              color: AdminColors.cyan,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            question,
            style: const TextStyle(
              color: AdminColors.text,
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
          ),
          if (guide.isNotEmpty) ...[
            const SizedBox(height: 9),
            ...guide.map(
              (item) => Text(
                '• $item',
                style: const TextStyle(
                  color: AdminColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (followUps.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              'AI Follow-ups: ${followUps.join(' • ')}',
              style: const TextStyle(
                color: AdminColors.violet,
                fontSize: 10.5,
              ),
            ),
          ],
          if (modelAnswer.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              'Model Answer:\n$modelAnswer',
              style: const TextStyle(
                color: AdminColors.textMuted,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StringList extends StatelessWidget {
  final List<String> items;

  const _StringList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(color: AdminColors.textMuted),
      );
    }

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AdminColors.cyan,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MapView extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MapView({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(color: AdminColors.textMuted),
      );
    }

    return Column(
      children: data.entries.map((entry) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: const TextStyle(
                  color: AdminColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                entry.value is List
                    ? (entry.value as List)
                        .map((e) => '• $e')
                        .join('\n')
                    : entry.value.toString(),
                style: const TextStyle(
                  color: AdminColors.textMuted,
                  height: 1.45,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
