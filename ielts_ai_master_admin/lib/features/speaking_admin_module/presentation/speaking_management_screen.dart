import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/speaking_admin_repository.dart';
import '../domain/speaking_admin_test.dart';
import 'create_speaking_generation_job_sheet.dart';
import 'speaking_submissions_screen.dart';
import 'speaking_test_preview_screen.dart';

class SpeakingManagementScreen extends StatefulWidget {
  const SpeakingManagementScreen({super.key});

  @override
  State<SpeakingManagementScreen> createState() =>
      _SpeakingManagementScreenState();
}

class _SpeakingManagementScreenState
    extends State<SpeakingManagementScreen> {
  final _repository = SpeakingAdminRepository();

  String _status = 'all';
  String _mode = 'all';
  String _search = '';

  void _openGenerator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .96,
      ),
      builder: (_) => const CreateSpeakingGenerationJobSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Speaking Management',
      subtitle:
          'Generate, review, publish and monitor IELTS Speaking content',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGenerator,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Generate Speaking'),
      ),
      body: Column(
        children: [
          _generationHealthBanner(),
          _toolbar(),
          Expanded(
            child: StreamBuilder<List<SpeakingAdminTest>>(
              stream: _repository.watchTests(
                status: _status,
                mode: _mode,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ErrorView(
                    message:
                        'Speaking tests load nahi huay. Firestore rules/index check karein.',
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingView();
                }

                final tests = snapshot.data!.where((test) {
                  if (_search.isEmpty) return true;

                  return test.title.toLowerCase().contains(_search) ||
                      test.modeLabel.toLowerCase().contains(_search) ||
                      test.accent.toLowerCase().contains(_search);
                }).toList();

                if (tests.isEmpty) {
                  return _EmptyState(onGenerate: _openGenerator);
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1250
                        ? 3
                        : constraints.maxWidth >= 760
                            ? 2
                            : 1;
                    const spacing = 12.0;
                    final width =
                        (constraints.maxWidth -
                                40 -
                                spacing * (columns - 1)) /
                            columns;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        110,
                      ),
                      children: [
                        Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: tests.map((test) {
                            return SizedBox(
                              width: width,
                              child: _SpeakingTestCard(
                                test: test,
                                repository: _repository,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _generationHealthBanner() {
    return StreamBuilder(
      stream: _repository.watchSpeakingJobs(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        var queued = 0;
        var generating = 0;
        var completed = 0;
        var failed = 0;

        for (final doc in docs) {
          switch ((doc.data()['status'] ?? '').toString()) {
            case 'queued':
              queued++;
              break;
            case 'generating':
              generating++;
              break;
            case 'completed':
              completed++;
              break;
            case 'failed':
              failed++;
              break;
          }
        }

        final active = queued + generating;
        final tone = failed > 0 ? AdminColors.primary : AdminColors.success;

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AdminColors.surface,
                tone.withOpacity(.07),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tone.withOpacity(.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  active > 0
                      ? Icons.auto_awesome_rounded
                      : Icons.verified_rounded,
                  color: tone,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active > 0
                          ? '$active speaking generation job${active == 1 ? '' : 's'} active'
                          : 'Speaking generation system ready',
                      style: const TextStyle(
                        color: AdminColors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Queued $queued  •  Generating $generating  •  Completed $completed  •  Failed $failed',
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (active == 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.success.withOpacity(.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    'VALIDATION FIXED',
                    style: TextStyle(
                      color: AdminColors.success,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 940;

          final search = SizedBox(
            width: compact ? double.infinity : 310,
            child: TextField(
              onChanged: (value) {
                setState(() => _search = value.trim().toLowerCase());
              },
              decoration: const InputDecoration(
                hintText: 'Search speaking tests...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          );

          final filters = Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _status,
                  decoration:
                      const InputDecoration(labelText: 'Status'),
                  items: const {
                    'all': 'All Status',
                    'draft': 'Draft',
                    'published': 'Published',
                    'archived': 'Archived',
                  }
                      .entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _mode,
                  decoration:
                      const InputDecoration(labelText: 'Mode'),
                  items: const {
                    'all': 'All Modes',
                    'ai_partner': 'AI Speaking Partner',
                    'full_test': 'Full Speaking Test',
                    'part_1': 'Part 1',
                    'part_2': 'Part 2',
                    'part_3': 'Part 3',
                    'pronunciation': 'Pronunciation',
                    'fluency': 'Fluency',
                    'daily_challenge': 'Daily Challenge',
                  }
                      .entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _mode = value);
                    }
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const SpeakingSubmissionsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Student Results'),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                filters,
              ],
            );
          }

          return Row(
            children: [
              search,
              const Spacer(),
              filters,
            ],
          );
        },
      ),
    );
  }
}

class _SpeakingTestCard extends StatelessWidget {
  final SpeakingAdminTest test;
  final SpeakingAdminRepository repository;

  const _SpeakingTestCard({
    required this.test,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (test.status) {
      'published' => AdminColors.success,
      'archived' => AdminColors.violet,
      _ => AdminColors.cyan,
    };

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.mic_rounded, color: color),
              ),
              const Spacer(),
              _StatusPill(label: test.status, color: color),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            test.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            test.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 10.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _InfoChip(test.modeLabel),
              _InfoChip(test.accent),
              _InfoChip(test.difficulty),
              _InfoChip('${test.totalQuestions} questions'),
              _InfoChip(test.durationLabel),
              _InfoChip('Audio ${test.modelAudioStatus}'),
              if (test.qualityScore > 0)
                _InfoChip(
                  'Quality ${test.qualityScore.toStringAsFixed(0)}%',
                ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SpeakingTestPreviewScreen(
                          testId: test.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 17,
                  ),
                  label: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'publish') {
                    await repository.updateStatus(
                      id: test.id,
                      status: 'published',
                    );
                  } else if (action == 'archive') {
                    await repository.updateStatus(
                      id: test.id,
                      status: 'archived',
                    );
                  } else if (action == 'restore') {
                    await repository.updateStatus(
                      id: test.id,
                      status: 'draft',
                    );
                  } else if (action == 'feature') {
                    await repository.updateFeatured(
                      id: test.id,
                      featured: true,
                    );
                  } else if (action == 'duplicate') {
                    await repository.duplicateTest(test.id);
                  } else if (action == 'delete') {
                    await repository.deleteTest(test.id);
                  }
                },
                itemBuilder: (context) => [
                  if (test.status != 'published')
                    const PopupMenuItem(
                      value: 'publish',
                      child: Text('Publish'),
                    ),
                  if (test.status == 'published')
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive'),
                    ),
                  if (test.status == 'archived')
                    const PopupMenuItem(
                      value: 'restore',
                      child: Text('Restore Draft'),
                    ),
                  const PopupMenuItem(
                    value: 'feature',
                    child: Text('Mark Featured'),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AdminColors.textMuted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onGenerate;

  const _EmptyState({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mic_rounded,
              color: AdminColors.cyan,
              size: 52,
            ),
            const SizedBox(height: 15),
            const Text(
              'No Speaking Tests Found',
              style: TextStyle(
                color: AdminColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate an IELTS Speaking activity, review it and publish it for users.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AdminColors.textMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate Speaking'),
            ),
          ],
        ),
      ),
    );
  }
}
