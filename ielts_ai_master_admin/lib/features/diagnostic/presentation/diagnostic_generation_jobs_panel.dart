import 'package:flutter/material.dart';

import '../data/diagnostic_admin_repository.dart';
import '../models/diagnostic_generation_job.dart';
import '../widgets/diagnostic_admin_widgets.dart';

class DiagnosticGenerationJobsPanel extends StatelessWidget {
  const DiagnosticGenerationJobsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = DiagnosticAdminRepository();

    return StreamBuilder<List<DiagnosticGenerationJob>>(
      stream: repository.watchGenerationJobs(limit: 8),
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? const [];
        if (jobs.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: diagnosticPanel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: DiagnosticAdminColors.cyan,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'Recent AI Generation Jobs',
                    style: TextStyle(
                      color: DiagnosticAdminColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...jobs.map(
                (job) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      _statusIcon(job),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${job.ieltsType} • ${job.difficulty}',
                              style: const TextStyle(
                                color: DiagnosticAdminColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              job.isFailed ? job.error : job.currentStep,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: DiagnosticAdminColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: LinearProgressIndicator(
                          value: job.progress.clamp(0, 100) / 100,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${job.progress.clamp(0, 100)}%',
                        style: const TextStyle(
                          color: DiagnosticAdminColors.cyan,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusIcon(DiagnosticGenerationJob job) {
    final color = job.isCompleted
        ? DiagnosticAdminColors.green
        : job.isFailed
            ? DiagnosticAdminColors.red
            : DiagnosticAdminColors.cyan;

    return CircleAvatar(
      radius: 17,
      backgroundColor: color.withOpacity(.12),
      child: Icon(
        job.isCompleted
            ? Icons.check_rounded
            : job.isFailed
                ? Icons.error_outline_rounded
                : Icons.auto_awesome_rounded,
        color: color,
        size: 18,
      ),
    );
  }
}
