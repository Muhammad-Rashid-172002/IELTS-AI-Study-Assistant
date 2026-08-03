import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/writing_admin_repository.dart';
import '../domain/writing_admin_task.dart';
import 'create_writing_generation_job_sheet.dart';
import 'writing_submissions_screen.dart';
import 'writing_task_preview_screen.dart';

class WritingManagementScreen extends StatefulWidget {
  const WritingManagementScreen({super.key});

  @override
  State<WritingManagementScreen> createState() =>
      _WritingManagementScreenState();
}

class _WritingManagementScreenState
    extends State<WritingManagementScreen> {
  final _repository = WritingAdminRepository();

  String _status = 'all';
  String _category = 'all';
  String _search = '';

  void _openGenerator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .96,
      ),
      builder: (_) => const CreateWritingGenerationJobSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Writing Management',
      subtitle:
          'Generate, review, publish and monitor IELTS Writing content',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGenerator,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Generate Writing'),
      ),
      body: Column(
        children: [
          _toolbar(),
          Expanded(
            child: StreamBuilder<List<WritingAdminTask>>(
              stream: _repository.watchTasks(
                status: _status,
                category: _category,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ErrorView(
                    message:
                        'Writing tasks load nahi huay. Firestore rules/index check karein.',
                  );
                }
                if (!snapshot.hasData) return const LoadingView();

                final tasks = snapshot.data!.where((task) {
                  if (_search.isEmpty) return true;
                  return task.title.toLowerCase().contains(_search) ||
                      task.taskType.toLowerCase().contains(_search) ||
                      task.categoryLabel
                          .toLowerCase()
                          .contains(_search);
                }).toList();

                if (tasks.isEmpty) {
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
                          children: tasks.map((task) {
                            return SizedBox(
                              width: width,
                              child: _WritingTaskCard(
                                task: task,
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
          final compact = constraints.maxWidth < 900;

          final search = SizedBox(
            width: compact ? double.infinity : 310,
            child: TextField(
              onChanged: (value) {
                setState(() => _search = value.trim().toLowerCase());
              },
              decoration: const InputDecoration(
                hintText: 'Search writing tasks...',
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
                  value: _category,
                  decoration:
                      const InputDecoration(labelText: 'Category'),
                  items: const {
                    'all': 'All Categories',
                    'academic_task_1': 'Academic Task 1',
                    'general_task_1': 'General Task 1',
                    'task_2': 'Writing Task 2',
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
                      setState(() => _category = value);
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
                          const WritingSubmissionsScreen(),
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

class _WritingTaskCard extends StatelessWidget {
  final WritingAdminTask task;
  final WritingAdminRepository repository;

  const _WritingTaskCard({
    required this.task,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (task.status) {
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
                child: Icon(Icons.edit_note_rounded, color: color),
              ),
              const Spacer(),
              _StatusPill(label: task.status, color: color),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            task.title,
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
            task.description.isEmpty
                ? task.taskQuestion
                : task.description,
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
              _InfoChip(task.categoryLabel),
              _InfoChip(task.taskType),
              _InfoChip(task.difficulty),
              _InfoChip('${task.minimumWords}+ words'),
              _InfoChip(task.durationLabel),
              if (task.qualityScore > 0)
                _InfoChip(
                  'Quality ${task.qualityScore.toStringAsFixed(0)}%',
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
                        builder: (_) => WritingTaskPreviewScreen(
                          taskId: task.id,
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
                      id: task.id,
                      status: 'published',
                    );
                  } else if (action == 'archive') {
                    await repository.updateStatus(
                      id: task.id,
                      status: 'archived',
                    );
                  } else if (action == 'restore') {
                    await repository.updateStatus(
                      id: task.id,
                      status: 'draft',
                    );
                  } else if (action == 'duplicate') {
                    await repository.duplicateTask(task.id);
                  } else if (action == 'delete') {
                    await repository.deleteTask(task.id);
                  }
                },
                itemBuilder: (context) => [
                  if (task.status != 'published')
                    const PopupMenuItem(
                      value: 'publish',
                      child: Text('Publish'),
                    ),
                  if (task.status == 'published')
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive'),
                    ),
                  if (task.status == 'archived')
                    const PopupMenuItem(
                      value: 'restore',
                      child: Text('Restore Draft'),
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
              Icons.edit_note_rounded,
              color: AdminColors.cyan,
              size: 52,
            ),
            const SizedBox(height: 15),
            const Text(
              'No Writing Tasks Found',
              style: TextStyle(
                color: AdminColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate an IELTS Writing task, review it and publish it for users.',
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
              label: const Text('Generate Writing'),
            ),
          ],
        ),
      ),
    );
  }
}
