import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';

class SpeakingAnalyticsScreen extends StatelessWidget {
  const SpeakingAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Speaking Analytics',
      subtitle: 'Attempts, average bands and common speaking weaknesses',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('speaking_submissions')
            .where('status', isEqualTo: 'completed')
            .limit(500)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingView();

          final docs = snapshot.data!.docs;
          final reports = docs
              .map((doc) => doc.data()['report'])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

          final averageBand = _average(
            reports.map((report) => _double(report['overallBand'])),
          );
          final fluency = _criterionAverage(
            reports,
            'fluencyAndCoherence',
          );
          final lexical = _criterionAverage(
            reports,
            'lexicalResource',
          );
          final grammar = _criterionAverage(
            reports,
            'grammaticalRangeAndAccuracy',
          );
          final pronunciation = _criterionAverage(
            reports,
            'pronunciation',
          );
          final averageSpeed = _average(
            reports.map(
              (report) => _double(report['speakingSpeedWpm']),
            ),
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 6
                      : constraints.maxWidth >= 620
                          ? 3
                          : 2;
                  const spacing = 11.0;
                  final width =
                      (constraints.maxWidth -
                              spacing * (columns - 1)) /
                          columns;

                  final items = [
                    ('Attempts', docs.length.toDouble(), ''),
                    ('Overall Band', averageBand, ''),
                    ('Fluency', fluency, ''),
                    ('Vocabulary', lexical, ''),
                    ('Grammar', grammar, ''),
                    ('Pronunciation', pronunciation, ''),
                  ];

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: items.map((item) {
                      return SizedBox(
                        width: width,
                        child: _MetricCard(
                          title: item.$1,
                          value: item.$1 == 'Attempts'
                              ? item.$2.toInt().toString()
                              : item.$2.toStringAsFixed(1),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              _InfoPanel(
                title: 'Average Speaking Speed',
                value: '${averageSpeed.toStringAsFixed(0)} WPM',
                icon: Icons.speed_rounded,
              ),
              const SizedBox(height: 12),
              const _InfoPanel(
                title: 'Analytics Note',
                value:
                    'These values are estimated educational metrics calculated from completed AI speaking reports.',
                icon: Icons.info_outline_rounded,
              ),
            ],
          );
        },
      ),
    );
  }

  static double _criterionAverage(
    List<Map<String, dynamic>> reports,
    String key,
  ) {
    return _average(
      reports.map((report) {
        final criterion = report[key];
        if (criterion is! Map) return 0;
        return _double(criterion['band']);
      }),
    );
  }

  static double _average(Iterable<double> values) {
    final filtered = values.where((value) => value > 0).toList();
    if (filtered.isEmpty) return 0;
    return filtered.reduce((a, b) => a + b) / filtered.length;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AdminColors.cyan,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoPanel({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
            backgroundColor: AdminColors.cyan.withOpacity(.12),
            child: Icon(icon, color: AdminColors.cyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AdminColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
