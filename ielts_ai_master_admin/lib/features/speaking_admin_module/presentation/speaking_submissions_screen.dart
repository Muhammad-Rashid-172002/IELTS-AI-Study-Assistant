import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/speaking_admin_repository.dart';

class SpeakingSubmissionsScreen extends StatefulWidget {
  const SpeakingSubmissionsScreen({super.key});

  @override
  State<SpeakingSubmissionsScreen> createState() =>
      _SpeakingSubmissionsScreenState();
}

class _SpeakingSubmissionsScreenState
    extends State<SpeakingSubmissionsScreen> {
  final _repository = SpeakingAdminRepository();
  final _player = AudioPlayer();

  String? _playingId;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(
    String submissionId,
    String url,
  ) async {
    if (url.isEmpty) return;

    if (_playingId == submissionId) {
      await _player.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }

    await _player.setUrl(url);
    setState(() => _playingId = submissionId);
    await _player.play();

    if (mounted) setState(() => _playingId = null);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Speaking Student Results',
      subtitle: 'Review recordings, bands and pronunciation feedback',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repository.watchSubmissions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingView();
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No speaking submissions yet.',
                style: TextStyle(color: AdminColors.textMuted),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 11),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final report = data['report'] is Map
                  ? Map<String, dynamic>.from(data['report'])
                  : const <String, dynamic>{};

              final band = _asDouble(report['overallBand']);
              final audioUrl = (data['audioUrl'] ?? '').toString();
              final status = (data['status'] ?? 'queued').toString();
              final isPlaying = _playingId == doc.id;

              return Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AdminColors.cyan.withOpacity(.12),
                      child: Text(
                        band > 0 ? band.toStringAsFixed(1) : '—',
                        style: const TextStyle(
                          color: AdminColors.cyan,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            (data['title'] ??
                                    'Speaking Submission')
                                .toString(),
                            style: const TextStyle(
                              color: AdminColors.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Part ${data['part'] ?? '-'} • '
                            '${data['durationSeconds'] ?? 0}s • $status',
                            style: const TextStyle(
                              color: AdminColors.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Play recording',
                      onPressed: audioUrl.isEmpty
                          ? null
                          : () => _toggleAudio(doc.id, audioUrl),
                      icon: Icon(
                        isPlaying
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showReport(context, data, report),
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 17,
                      ),
                      label: const Text('View Report'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showReport(
    BuildContext context,
    Map<String, dynamic> data,
    Map<String, dynamic> report,
  ) {
    final text = [
      'User ID: ${data['userId'] ?? '-'}',
      'Mode: ${data['mode'] ?? '-'}',
      'Part: ${data['part'] ?? '-'}',
      'Question: ${data['questionText'] ?? '-'}',
      'Duration: ${data['durationSeconds'] ?? 0}s',
      'Status: ${data['status'] ?? '-'}',
      '',
      'Overall Band: ${report['overallBand'] ?? '-'}',
      'Summary: ${report['summary'] ?? '-'}',
      '',
      'Fluency and Coherence:',
      _criterion(report['fluencyAndCoherence']),
      '',
      'Lexical Resource:',
      _criterion(report['lexicalResource']),
      '',
      'Grammatical Range and Accuracy:',
      _criterion(report['grammaticalRangeAndAccuracy']),
      '',
      'Pronunciation:',
      _criterion(report['pronunciation']),
      '',
      'Speaking Speed: ${report['speakingSpeedWpm'] ?? '-'} WPM',
      'Pause Count: ${report['pauseCount'] ?? '-'}',
      '',
      'Suggested Improvements:',
      _list(report['suggestedImprovements']),
      '',
      'Action Plan:',
      _list(report['actionPlan']),
      '',
      'Transcript:',
      (report['transcript'] ?? '-').toString(),
    ].join('\n');

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: Text(
          (data['title'] ?? 'Speaking Report').toString(),
          style: const TextStyle(color: AdminColors.text),
        ),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(
                color: AdminColors.textMuted,
                height: 1.55,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _criterion(dynamic value) {
    if (value is! Map) return '-';

    final map = Map<String, dynamic>.from(value);
    return 'Band ${map['band'] ?? '-'}\n${map['feedback'] ?? '-'}';
  }

  String _list(dynamic value) {
    if (value is! List) return '-';
    return value.map((e) => '• $e').join('\n');
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
