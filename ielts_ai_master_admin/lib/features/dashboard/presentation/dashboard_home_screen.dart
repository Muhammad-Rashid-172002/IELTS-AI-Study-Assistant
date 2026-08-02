import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';

class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Dashboard',
      subtitle: 'Live content and platform overview',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('listening_tests')
            .snapshots(),
        builder: (context, testSnapshot) {
          if (!testSnapshot.hasData) {
            return const LoadingView();
          }

          final docs = testSnapshot.data!.docs;
          final published =
              docs.where((doc) => doc.data()['status'] == 'published').length;
          final drafts =
              docs.where((doc) => doc.data()['status'] == 'draft').length;
          final archived =
              docs.where((doc) => doc.data()['status'] == 'archived').length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AdminColors.primary.withOpacity(.25),
                      AdminColors.cyan.withOpacity(.1),
                      AdminColors.violet.withOpacity(.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AdminColors.cyan.withOpacity(.18),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: AdminColors.cyan,
                      size: 46,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'AI background generation, validation, publishing and inventory control.',
                        style: TextStyle(
                          color: AdminColors.text,
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cardWidth = width >= 900
                      ? (width - 36) / 4
                      : width >= 600
                          ? (width - 12) / 2
                          : width;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        width: cardWidth,
                        title: 'Published',
                        value: '$published',
                        icon: Icons.public_rounded,
                        color: AdminColors.success,
                      ),
                      _MetricCard(
                        width: cardWidth,
                        title: 'Drafts',
                        value: '$drafts',
                        icon: Icons.edit_document,
                        color: AdminColors.cyan,
                      ),
                      _MetricCard(
                        width: cardWidth,
                        title: 'Archived',
                        value: '$archived',
                        icon: Icons.archive_outlined,
                        color: AdminColors.violet,
                      ),
                      _MetricCard(
                        width: cardWidth,
                        title: 'Total Tests',
                        value: '${docs.length}',
                        icon: Icons.library_books_outlined,
                        color: AdminColors.warning,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const _RecentJobsPanel(),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(.13),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AdminColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentJobsPanel extends StatelessWidget {
  const _RecentJobsPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('generation_jobs')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent AI Generation Jobs',
                  style: TextStyle(
                    color: AdminColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const Text(
                    'No generation jobs yet.',
                    style: TextStyle(color: AdminColors.textMuted),
                  )
                else
                  ...docs.map((doc) {
                    final data = doc.data();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AdminColors.cyan,
                      ),
                      title: Text(
                        '${data['questionType'] ?? 'Listening'} • Section ${data['section'] ?? '-'}',
                      ),
                      subtitle: Text(
                        '${data['requestedCount'] ?? 0} requested',
                      ),
                      trailing: Text(
                        (data['status'] ?? 'queued').toString(),
                        style: const TextStyle(
                          color: AdminColors.textMuted,
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
