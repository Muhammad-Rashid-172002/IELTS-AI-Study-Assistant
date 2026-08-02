import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/generation_job_repository.dart';

class GenerationJobsScreen extends StatelessWidget {
  const GenerationJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = GenerationJobRepository();

    return AdminScaffold(
      title: 'AI Generation Jobs',
      subtitle: 'Background Gemini generation queue',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repository.watchJobs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingView();
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('No generation jobs yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: Text(
                    '${data['questionType'] ?? 'Listening'} • Section ${data['section'] ?? '-'}',
                  ),
                  subtitle: Text(
                    'Requested ${data['requestedCount'] ?? 0} • Generated ${data['generatedCount'] ?? 0} • Failed ${data['failedCount'] ?? 0}',
                  ),
                  trailing: StatusBadge(
                    status: (data['status'] ?? 'queued').toString(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
