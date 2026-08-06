import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/listening_admin_repository.dart';
import '../domain/listening_admin_test.dart';
import 'create_listening_generation_job_sheet.dart';
import 'listening_test_preview_screen.dart';

class ListeningManagementScreen extends StatefulWidget {
  const ListeningManagementScreen({super.key});

  @override
  State<ListeningManagementScreen> createState() =>
      _ListeningManagementScreenState();
}

class _ListeningManagementScreenState
    extends State<ListeningManagementScreen> {
  final _repository = ListeningAdminRepository();
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Listening Management',
      subtitle: 'Generate, preview, publish and archive tests',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const CreateListeningGenerationJobSheet(),
        ),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Generate with AI'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              children: [
                for (final item
                    in const ['all', 'draft', 'published', 'archived'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item.toUpperCase()),
                      selected: _status == item,
                      onSelected: (_) {
                        setState(() => _status = item);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ListeningAdminTest>>(
              stream: _repository.watchTests(status: _status),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(
                    message:
                        'Listening tests load nahi huay. Firestore rules/index check karein.',
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingView();
                }

                final tests = snapshot.data!;

                if (tests.isEmpty) {
                  return const ErrorView(
                    message:
                        'Koi listening test nahi hai. Generate with AI se pehla job create karein.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                  itemCount: tests.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final test = tests[index];

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x2222D3EE),
                          child: Icon(
                            Icons.headphones_rounded,
                            color: AdminColors.cyan,
                          ),
                        ),
                        title: Text(
                          test.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${_modeLabel(test.mode, test.section)} • ${test.questionType} • ${test.questionCount} questions',
                          ),
                        ),
                        trailing: StatusBadge(status: test.status),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ListeningTestPreviewScreen(
                              testId: test.id,
                            ),
                          ),
                        ),
                      ),
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
}

String _modeLabel(String mode, int section) {
  switch (mode.toLowerCase()) {
    case 'timed': return 'Timed Listening';
    case 'exam': case 'full': return 'Full Test • Section $section';
    case 'accent': return 'Accent Training • Section $section';
    case 'learning': return 'Learning Mode • Section $section';
    case 'question_type': return 'Question Type Practice';
    default: return 'Section $section';
  }
}
