import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/writing_admin_repository.dart';
import '../domain/writing_admin_task.dart';

class WritingTaskPreviewScreen extends StatelessWidget {
  final String taskId;

  const WritingTaskPreviewScreen({
    super.key,
    required this.taskId,
  });

  @override
  Widget build(BuildContext context) {
    final repository = WritingAdminRepository();

    return AdminScaffold(
      title: 'Writing Task Preview',
      subtitle: 'Review task, guidance and Band 8 model answer',
      body: StreamBuilder<WritingAdminTask?>(
        stream: repository.watchTask(taskId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorView(
              message: 'Writing task load nahi hua.',
            );
          }
          if (!snapshot.hasData) return const LoadingView();

          final task = snapshot.data;
          if (task == null) {
            return const ErrorView(
              message: 'Writing task not found.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              _hero(task),
              const SizedBox(height: 14),
              _section(
                'Task Question',
                Icons.help_outline_rounded,
                SelectableText(
                  task.taskQuestion,
                  style: const TextStyle(
                    color: AdminColors.text,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (task.visualData.isNotEmpty) ...[
                const SizedBox(height: 14),
                _section(
                  'Visual Data',
                  Icons.insights_rounded,
                  _MapView(data: task.visualData),
                ),
              ],
              const SizedBox(height: 14),
              _section(
                'Task Checklist',
                Icons.checklist_rounded,
                _StringList(items: task.checklist),
              ),
              const SizedBox(height: 14),
              _section(
                'Planning Points',
                Icons.schema_outlined,
                _StringList(items: task.planningPoints),
              ),
              const SizedBox(height: 14),
              _section(
                'Useful Vocabulary',
                Icons.translate_rounded,
                task.usefulVocabulary.isEmpty
                    ? const Text(
                        'No vocabulary available.',
                        style:
                            TextStyle(color: AdminColors.textMuted),
                      )
                    : Column(
                        children: task.usefulVocabulary.map((item) {
                          return _Tile(
                            title:
                                (item['word'] ?? '').toString(),
                            body:
                                '${item['meaning'] ?? ''}\n${item['example'] ?? ''}',
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 14),
              _section(
                'Band 8 Model Answer',
                Icons.star_outline_rounded,
                SelectableText(
                  task.band8ModelAnswer.isEmpty
                      ? 'No model answer available.'
                      : task.band8ModelAnswer,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    height: 1.7,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _section(
                'Writing Lesson',
                Icons.school_outlined,
                _MapView(data: task.lesson),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  if (task.status != 'published')
                    FilledButton.icon(
                      onPressed: () => repository.updateStatus(
                        id: task.id,
                        status: 'published',
                      ),
                      icon: const Icon(Icons.public_rounded),
                      label: const Text('Publish'),
                    ),
                  if (task.status == 'published')
                    OutlinedButton.icon(
                      onPressed: () => repository.updateStatus(
                        id: task.id,
                        status: 'archived',
                      ),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archive'),
                    ),
                  if (task.status == 'archived')
                    OutlinedButton.icon(
                      onPressed: () => repository.updateStatus(
                        id: task.id,
                        status: 'draft',
                      ),
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restore'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        repository.duplicateTask(task.id),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Duplicate'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await repository.deleteTask(task.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                    ),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hero(WritingAdminTask task) {
    final color = switch (task.status) {
      'published' => AdminColors.success,
      'archived' => AdminColors.violet,
      _ => AdminColors.cyan,
    };

    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.primary.withOpacity(.20),
            AdminColors.cyan.withOpacity(.08),
            AdminColors.violet.withOpacity(.14),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AdminColors.cyan.withOpacity(.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            style: const TextStyle(
              color: AdminColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            task.description,
            style: const TextStyle(
              color: AdminColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${task.categoryLabel} • ${task.taskType} • '
            '${task.difficulty} • ${task.minimumWords}+ words • '
            '${task.durationLabel}',
            style: const TextStyle(
              color: AdminColors.cyan,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    IconData icon,
    Widget child,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AdminColors.cyan),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: AdminColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _StringList extends StatelessWidget {
  final List<String> items;

  const _StringList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(color: AdminColors.textMuted),
      );
    }

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AdminColors.cyan,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MapView extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MapView({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(color: AdminColors.textMuted),
      );
    }

    return Column(
      children: data.entries.map((entry) {
        return _Tile(
          title: entry.key,
          body: entry.value is List
              ? (entry.value as List)
                  .map((e) => '• $e')
                  .join('\n')
              : entry.value.toString(),
        );
      }).toList(),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final String body;

  const _Tile({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AdminColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              color: AdminColors.textMuted,
              height: 1.45,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
