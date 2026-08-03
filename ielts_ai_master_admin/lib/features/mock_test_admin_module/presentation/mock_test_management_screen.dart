import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/mock_admin_repository.dart';
import '../domain/mock_admin_models.dart';
import 'create_mock_test_sheet.dart';
import 'mock_question_bank_screen.dart';
import 'mock_test_analytics_screen.dart';

class MockTestManagementScreen extends StatefulWidget {
  const MockTestManagementScreen({super.key});

  @override
  State<MockTestManagementScreen> createState() =>
      _MockTestManagementScreenState();
}

class _MockTestManagementScreenState extends State<MockTestManagementScreen> {
  final _repository = MockAdminRepository();

  String _status = 'all';
  String _track = 'all';
  String _mode = 'all';
  String _query = '';

  void _openCreate() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .96,
      ),
      builder: (_) => const CreateMockTestSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Mock Test Management',
      subtitle: 'Create, publish and monitor complete IELTS mock simulations',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Create Mock Test'),
      ),
      body: Column(
        children: [
          _toolbar(),
          Expanded(
            child: StreamBuilder<List<MockAdminTest>>(
              stream: _repository.watchTests(
                status: _status,
                track: _track,
                mode: _mode,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ErrorView(
                    message:
                        'Mock tests load nahi huay. Firestore rules/index check karein.',
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingView();
                }

                final tests = snapshot.data!.where((test) {
                  if (_query.isEmpty) return true;

                  final text = [
                    test.title,
                    test.description,
                    test.track.label,
                    test.mode.label,
                    test.difficulty,
                  ].join(' ').toLowerCase();

                  return text.contains(_query);
                }).toList();

                if (tests.isEmpty) {
                  return _EmptyState(onCreate: _openCreate);
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
                        (constraints.maxWidth - 40 - spacing * (columns - 1)) /
                        columns;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                      children: [
                        Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: tests.map((test) {
                            return SizedBox(
                              width: width,
                              child: _MockCard(
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

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1180;

          final search = SizedBox(
            width: compact ? double.infinity : 310,
            child: TextField(
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
              decoration: const InputDecoration(
                hintText: 'Search mock tests...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          );

          final controls = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filter(
                width: 150,
                label: 'Status',
                value: _status,
                items: const {
                  'all': 'All',
                  'draft': 'Draft',
                  'generating': 'Generating',
                  'ready': 'Ready for Review',
                  'generation_failed': 'Generation Failed',
                  'published': 'Published',
                  'archived': 'Archived',
                },
                onChanged: (value) => setState(() => _status = value),
              ),
              _filter(
                width: 180,
                label: 'Track',
                value: _track,
                items: const {
                  'all': 'All Tracks',
                  'academic': 'Academic',
                  'general_training': 'General Training',
                },
                onChanged: (value) => setState(() => _track = value),
              ),
              _filter(
                width: 220,
                label: 'Mode',
                value: _mode,
                items: const {
                  'all': 'All Modes',
                  'practice': 'Practice',
                  'exam': 'Exam',
                  'computer_delivered': 'Computer-delivered',
                },
                onChanged: (value) => setState(() => _mode = value),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MockQuestionBankScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Question Bank'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MockTestAnalyticsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Analytics'),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [search, const SizedBox(height: 10), controls],
            );
          }

          return Row(
            children: [
              search,
              const Spacer(),
              Flexible(child: controls),
            ],
          );
        },
      ),
    );
  }

  Widget _filter({
    required double width,
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        menuMaxHeight: 360,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        selectedItemBuilder: (context) {
          return items.entries.map((entry) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList();
        },
        items: items.entries
            .map(
              (entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }
}

class _MockCard extends StatelessWidget {
  final MockAdminTest test;
  final MockAdminRepository repository;

  const _MockCard({required this.test, required this.repository});

  @override
  Widget build(BuildContext context) {
    final color = switch (test.status) {
      'published' => AdminColors.success,
      'ready' => AdminColors.success,
      'generating' => AdminColors.cyan,
      'generation_failed' => AdminColors.warning,
      'archived' => AdminColors.violet,
      _ => AdminColors.textMuted,
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.fact_check_outlined, color: color),
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
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _InfoChip(test.track.label),
              _InfoChip(test.scope.label),
              _InfoChip(test.mode.label),
              _InfoChip(test.difficulty),
              _InfoChip('${test.totalQuestions} items'),
              _InfoChip('${test.totalDurationMinutes} min'),
            ],
          ),
          const SizedBox(height: 14),
          _GenerationProgress(test: test),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(label: 'Attempts', value: '${test.attemptCount}'),
              const SizedBox(width: 14),
              _Metric(
                label: 'Avg Band',
                value: test.averageBand.toStringAsFixed(1),
              ),
              const SizedBox(width: 14),
              _Metric(
                label: 'Complete',
                value: '${test.completionRate.toStringAsFixed(0)}%',
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (action) async {
                  try {
                    if (action == 'publish') {
                      await repository.publishMockTest(test.id);
                    } else if (action == 'retry') {
                      await repository.retryIncompleteSkills(test);
                    } else if (action == 'archive') {
                      await repository.archiveMockTest(test.id);
                    } else if (action == 'restore_ready') {
                      await repository.restoreReadyMockTest(test.id);
                    } else if (action == 'feature') {
                      await repository.updateFeatured(
                        id: test.id,
                        featured: !test.isFeatured,
                      );
                    } else if (action == 'duplicate') {
                      await repository.duplicateTest(test.id);
                    } else if (action == 'delete') {
                      await repository.deleteTest(test.id);
                    }
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error.toString()),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  if (test.canPublish)
                    const PopupMenuItem(
                      value: 'publish',
                      child: Text('Review Complete — Publish'),
                    ),
                  if (test.status == 'generation_failed' ||
                      (test.status == 'generating' &&
                          test.totalFailed > 0))
                    const PopupMenuItem(
                      value: 'retry',
                      child: Text('Retry Missing Skills'),
                    ),
                  if (test.status == 'published')
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive'),
                    ),
                  if (test.status == 'archived' && test.isReady)
                    const PopupMenuItem(
                      value: 'restore_ready',
                      child: Text('Restore to Ready'),
                    ),
                  PopupMenuItem(
                    value: 'feature',
                    child: Text(
                      test.isFeatured
                          ? 'Remove Featured'
                          : 'Mark Featured',
                    ),
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


class _GenerationProgress extends StatelessWidget {
  final MockAdminTest test;

  const _GenerationProgress({
    required this.test,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (test.generationProgress / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AdminColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Generation Progress',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${test.totalGenerated}/${test.totalRequired} '
                '(${test.generationProgress.toStringAsFixed(0)}%)',
                style: const TextStyle(
                  color: AdminColors.cyan,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: test.skills.map((skill) {
              return _SkillProgressChip(
                label: skill.label,
                generated: test.generatedFor(skill),
                required: test.requiredFor(skill),
                failed: test.failedFor(skill),
                complete: test.skillComplete(skill),
              );
            }).toList(),
          ),
          if (test.generationError.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              test.generationError,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminColors.warning,
                fontSize: 9,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillProgressChip extends StatelessWidget {
  final String label;
  final int generated;
  final int required;
  final int failed;
  final bool complete;

  const _SkillProgressChip({
    required this.label,
    required this.generated,
    required this.required,
    required this.failed,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? AdminColors.success
        : failed > 0
            ? AdminColors.warning
            : AdminColors.cyan;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete
                ? Icons.check_circle_rounded
                : failed > 0
                    ? Icons.error_outline_rounded
                    : Icons.hourglass_top_rounded,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            '$label $generated/$required',
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AdminColors.cyan,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AdminColors.textMuted, fontSize: 8.5),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AdminColors.textMuted, fontSize: 8.7),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
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
              Icons.fact_check_outlined,
              color: AdminColors.cyan,
              size: 54,
            ),
            const SizedBox(height: 15),
            const Text(
              'No Mock Tests Found',
              style: TextStyle(
                color: AdminColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first Academic or General Training mock test configuration.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Create Mock Test'),
            ),
          ],
        ),
      ),
    );
  }
}
