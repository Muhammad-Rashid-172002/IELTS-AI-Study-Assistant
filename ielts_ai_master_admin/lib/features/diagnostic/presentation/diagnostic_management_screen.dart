import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/diagnostic_admin_repository.dart';
import '../models/diagnostic_admin_models.dart';
import '../widgets/diagnostic_admin_widgets.dart';
import 'diagnostic_test_editor_screen.dart';
import 'diagnostic_ai_generation_dialog.dart';
import 'diagnostic_generation_jobs_panel.dart';

class DiagnosticManagementScreen extends StatefulWidget {
  const DiagnosticManagementScreen({super.key});

  @override
  State<DiagnosticManagementScreen> createState() =>
      _DiagnosticManagementScreenState();
}

class _DiagnosticManagementScreenState
    extends State<DiagnosticManagementScreen> {
  final _repository = DiagnosticAdminRepository();

  String _search = '';
  String _status = 'all';
  String _track = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DiagnosticAdminColors.background,
      appBar: AppBar(
        backgroundColor: DiagnosticAdminColors.background,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diagnostic Tests'),
            Text(
              'Create, validate and publish four-skill assessments',
              style: TextStyle(
                color: DiagnosticAdminColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Manual Draft'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAiGenerator,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Generate with AI'),
      ),
      body: StreamBuilder<List<DiagnosticTestAdminModel>>(
        stream: _repository.watchTests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(
                  color: DiagnosticAdminColors.red,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final tests = snapshot.data!;
          final filtered = tests.where((test) {
            final searchMatch = _search.isEmpty ||
                test.title.toLowerCase().contains(
                      _search.toLowerCase(),
                    );

            final statusMatch =
                _status == 'all' || test.status == _status;

            final trackMatch =
                _track == 'all' || test.ieltsType == _track;

            return searchMatch && statusMatch && trackMatch;
          }).toList();

          final published = tests
              .where((test) => test.status == 'published')
              .length;
          final drafts = tests
              .where((test) => test.status == 'draft')
              .length;
          final archived = tests
              .where((test) => test.status == 'archived')
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 100),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth >= 900 ? 4 : 2;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth -
                              gap * (columns - 1)) /
                          columns;

                  final cards = [
                    DiagnosticMetricCard(
                      title: 'Total Tests',
                      value: '${tests.length}',
                      icon: Icons.fact_check_outlined,
                      color: DiagnosticAdminColors.cyan,
                    ),
                    DiagnosticMetricCard(
                      title: 'Published',
                      value: '$published',
                      icon: Icons.public_rounded,
                      color: DiagnosticAdminColors.green,
                    ),
                    DiagnosticMetricCard(
                      title: 'Drafts',
                      value: '$drafts',
                      icon: Icons.edit_document,
                      color: DiagnosticAdminColors.orange,
                    ),
                    DiagnosticMetricCard(
                      title: 'Archived',
                      value: '$archived',
                      icon: Icons.archive_outlined,
                      color: DiagnosticAdminColors.violet,
                    ),
                  ];

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: cards
                        .map(
                          (card) => SizedBox(
                            width: width,
                            child: card,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 18),
              _filters(),
              const SizedBox(height: 18),
              const DiagnosticGenerationJobsPanel(),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                _emptyState()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth >= 1100 ? 3 : 2;
                    final actualColumns =
                        constraints.maxWidth < 720 ? 1 : columns;
                    const gap = 14.0;
                    final width =
                        (constraints.maxWidth -
                                gap * (actualColumns - 1)) /
                            actualColumns;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: filtered.map((test) {
                        return SizedBox(
                          width: width,
                          child: _DiagnosticTestCard(
                            test: test,
                            onEdit: () => _openEditor(test),
                            onPublish: () =>
                                _repository.publishTest(test),
                            onUnpublish: () =>
                                _repository.unpublishTest(test.id),
                            onArchive: () =>
                                _repository.archiveTest(test.id),
                            onDelete: () => _delete(test),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: diagnosticPanel(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 780;

          final search = TextField(
            decoration: const InputDecoration(
              hintText: 'Search diagnostic tests...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _search = value),
          );

          final status = DropdownButtonFormField<String>(
            value: _status,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Status',
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All Statuses'),
              ),
              DropdownMenuItem(
                value: 'draft',
                child: Text('Draft'),
              ),
              DropdownMenuItem(
                value: 'published',
                child: Text('Published'),
              ),
              DropdownMenuItem(
                value: 'archived',
                child: Text('Archived'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _status = value);
            },
          );

          final track = DropdownButtonFormField<String>(
            value: _track,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'IELTS Type',
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All Tracks'),
              ),
              DropdownMenuItem(
                value: 'Academic',
                child: Text('Academic'),
              ),
              DropdownMenuItem(
                value: 'General Training',
                child: Text('General Training'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _track = value);
            },
          );

          if (narrow) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                status,
                const SizedBox(height: 10),
                track,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 2, child: search),
              const SizedBox(width: 10),
              Expanded(child: status),
              const SizedBox(width: 10),
              Expanded(child: track),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(38),
      decoration: diagnosticPanel(),
      child: const Column(
        children: [
          Icon(
            Icons.fact_check_outlined,
            color: DiagnosticAdminColors.cyan,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'No diagnostic tests found',
            style: TextStyle(
              color: DiagnosticAdminColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Create your first Academic or General Training diagnostic assessment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: DiagnosticAdminColors.muted,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _openAiGenerator() async {
    final testId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DiagnosticAiGenerationDialog(),
    );

    if (!mounted || testId == null || testId.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('diagnostic_tests')
        .doc(testId)
        .get();

    if (!mounted || !snapshot.exists) return;

    await _openEditor(
      DiagnosticTestAdminModel.fromDocument(snapshot),
    );
  }

  Future<void> _openEditor([
    DiagnosticTestAdminModel? test,
  ]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiagnosticTestEditorScreen(test: test),
      ),
    );
  }

  Future<void> _delete(
    DiagnosticTestAdminModel test,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete diagnostic test?'),
            content: Text(
              '"${test.title}" will be permanently deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: DiagnosticAdminColors.red,
                ),
                onPressed: () =>
                    Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await _repository.deleteTest(test.id);
    }
  }
}

class _DiagnosticTestCard extends StatelessWidget {
  final DiagnosticTestAdminModel test;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _DiagnosticTestCard({
    required this.test,
    required this.onEdit,
    required this.onPublish,
    required this.onUnpublish,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: diagnosticPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    DiagnosticAdminColors.cyan.withOpacity(.12),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: DiagnosticAdminColors.cyan,
                ),
              ),
              const Spacer(),
              DiagnosticStatusChip(status: test.status),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'publish':
                      onPublish();
                      break;
                    case 'unpublish':
                      onUnpublish();
                      break;
                    case 'archive':
                      onArchive();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  if (test.status != 'published')
                    const PopupMenuItem(
                      value: 'publish',
                      child: Text('Publish'),
                    ),
                  if (test.status == 'published')
                    const PopupMenuItem(
                      value: 'unpublish',
                      child: Text('Move to Draft'),
                    ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            test.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: DiagnosticAdminColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            test.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: DiagnosticAdminColors.muted,
              fontSize: 10,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _Tag(test.ieltsType),
              _Tag('${test.totalDurationMinutes} min'),
              _Tag('${test.totalQuestions} objective questions'),
              _Tag('${test.speakingPrompts.length} speaking prompts'),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _readiness(test),
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 8),
          Text(
            test.status == 'generating'
                ? (test.generationStep.isEmpty
                    ? 'AI generation in progress'
                    : test.generationStep)
                : test.generationError.isNotEmpty
                    ? test.generationError
                    : test.isReadyToPublish
                        ? 'Ready to publish'
                        : '${test.validationIssues.length} setup items remaining',
            style: TextStyle(
              color: test.generationError.isNotEmpty
                  ? DiagnosticAdminColors.red
                  : test.status == 'generating'
                      ? DiagnosticAdminColors.cyan
                      : test.isReadyToPublish
                          ? DiagnosticAdminColors.green
                          : DiagnosticAdminColors.orange,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  double _readiness(DiagnosticTestAdminModel test) {
    const total = 7;
    final complete = [
      test.title.trim().isNotEmpty,
      test.listeningAudioUrl.trim().isNotEmpty,
      test.listeningQuestions.isNotEmpty,
      test.readingPassage.trim().isNotEmpty,
      test.readingQuestions.isNotEmpty,
      test.writingPrompt.trim().isNotEmpty,
      test.speakingPrompts.isNotEmpty,
    ].where((item) => item).length;

    return complete / total;
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: DiagnosticAdminColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DiagnosticAdminColors.border,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: DiagnosticAdminColors.muted,
          fontSize: 8.5,
        ),
      ),
    );
  }
}
