import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';

class MockTestAnalyticsScreen extends StatelessWidget {
  const MockTestAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Mock Test Analytics',
      subtitle:
          'Attempts, completion, bands and evaluation status',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collectionGroup('mock_attempts')
            .limit(500)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingView();

          final docs = snapshot.data!.docs;
          final completed = docs
              .where((doc) => doc.data()['status'] == 'completed')
              .length;
          final submitted = docs
              .where((doc) => doc.data()['status'] == 'submitted')
              .length;
          final inProgress = docs
              .where((doc) => doc.data()['status'] == 'in_progress')
              .length;

          final bands = docs.map((doc) {
            final result = doc.data()['result'];
            if (result is! Map) return 0.0;
            final value = result['overallBand'];
            if (value is num) return value.toDouble();
            return double.tryParse(value?.toString() ?? '') ?? 0;
          }).where((value) => value > 0).toList();

          final averageBand = bands.isEmpty
              ? 0.0
              : bands.reduce((a, b) => a + b) / bands.length;

          final completionRate = docs.isEmpty
              ? 0.0
              : completed / docs.length * 100;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 5
                      : constraints.maxWidth >= 620
                          ? 3
                          : 2;
                  const spacing = 10.0;
                  final width =
                      (constraints.maxWidth -
                              spacing * (columns - 1)) /
                          columns;

                  final items = [
                    (
                      'Total Attempts',
                      docs.length.toDouble(),
                      Icons.assignment_outlined
                    ),
                    (
                      'Completed',
                      completed.toDouble(),
                      Icons.check_circle_outline_rounded
                    ),
                    (
                      'Submitted',
                      submitted.toDouble(),
                      Icons.pending_actions_outlined
                    ),
                    (
                      'In Progress',
                      inProgress.toDouble(),
                      Icons.play_circle_outline_rounded
                    ),
                    (
                      'Average Band',
                      averageBand,
                      Icons.insights_rounded
                    ),
                  ];

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: items.map((item) {
                      return SizedBox(
                        width: width,
                        child: _MetricCard(
                          title: item.$1,
                          value: item.$1 == 'Average Band'
                              ? item.$2.toStringAsFixed(1)
                              : item.$2.toInt().toString(),
                          icon: item.$3,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Completion Rate',
                      style: TextStyle(
                        color: AdminColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: completionRate / 100,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${completionRate.toStringAsFixed(1)}% of attempts completed',
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AdminColors.cyan,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 9.5,
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
