import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/writing_admin_repository.dart';

class WritingSubmissionsScreen extends StatelessWidget {
  const WritingSubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = WritingAdminRepository();

    return AdminScaffold(
      title: 'Writing Student Results',
      subtitle: 'Review submissions, bands and weak areas',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repository.watchSubmissions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingView();

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No writing submissions yet.',
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
              final data = docs[index].data();
              final report = data['report'] is Map
                  ? Map<String, dynamic>.from(data['report'])
                  : const <String, dynamic>{};
              final band = _asDouble(report['overallBand']);
              final status =
                  (data['status'] ?? 'queued').toString();

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
                                    'Writing Submission')
                                .toString(),
                            style: const TextStyle(
                              color: AdminColors.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${data['taskType'] ?? ''} • '
                            '${data['wordCount'] ?? 0} words • $status',
                            style: const TextStyle(
                              color: AdminColors.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
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
      'Task Type: ${data['taskType'] ?? '-'}',
      'Mode: ${data['mode'] ?? '-'}',
      'Word Count: ${data['wordCount'] ?? 0}',
      'Status: ${data['status'] ?? '-'}',
      '',
      'Overall Band: ${report['overallBand'] ?? '-'}',
      'Summary: ${report['summary'] ?? '-'}',
      '',
      'Task Achievement / Response:',
      _criterion(report['taskAchievement']),
      '',
      'Coherence and Cohesion:',
      _criterion(report['coherenceAndCohesion']),
      '',
      'Lexical Resource:',
      _criterion(report['lexicalResource']),
      '',
      'Grammatical Range and Accuracy:',
      _criterion(report['grammaticalRangeAndAccuracy']),
      '',
      'Action Plan:',
      _list(report['actionPlan']),
    ].join('\n');

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: Text(
          (data['title'] ?? 'Writing Report').toString(),
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
