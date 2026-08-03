import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/mock_admin_repository.dart';
import '../domain/mock_admin_models.dart';
import 'create_mock_question_job_sheet.dart';

class MockQuestionBankScreen extends StatefulWidget {
  const MockQuestionBankScreen({super.key});

  @override
  State<MockQuestionBankScreen> createState() =>
      _MockQuestionBankScreenState();
}

class _MockQuestionBankScreenState
    extends State<MockQuestionBankScreen> {
  final _repository = MockAdminRepository();

  MockAdminTrack _track = MockAdminTrack.academic;
  MockAdminSkill _skill = MockAdminSkill.listening;
  String _status = 'all';

  void _openGenerator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surface,
      builder: (_) => const CreateMockQuestionJobSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Mock Question Bank',
      subtitle:
          'Manage reusable Listening, Reading, Writing and Speaking content',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGenerator,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Generate Questions'),
      ),
      body: Column(
        children: [
          _filters(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Only published questions are available in the user app.',
                    style: TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final questions = await _repository
                        .watchQuestions(
                          track: _track,
                          skill: _skill,
                          status: _status,
                        )
                        .first;

                    await _repository.bulkUpdateQuestionStatus(
                      track: _track,
                      skill: _skill,
                      ids: questions.map((question) => question.id),
                      status: 'published',
                    );
                  },
                  icon: const Icon(Icons.public_rounded),
                  label: const Text('Publish Visible'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MockAdminQuestion>>(
              stream: _repository.watchQuestions(
                track: _track,
                skill: _skill,
                status: _status,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LoadingView();

                final questions = snapshot.data!;

                if (questions.isEmpty) {
                  return const Center(
                    child: Text(
                      'No questions found for this filter.',
                      style: TextStyle(
                        color: AdminColors.textMuted,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  itemCount: questions.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final question = questions[index];

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AdminColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AdminColors.border,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AdminColors.cyan.withOpacity(.12),
                            child: Text(
                              '${question.number}',
                              style: const TextStyle(
                                color: AdminColors.cyan,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  question.prompt,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AdminColors.text,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    _Tag(
                                      question.type.replaceAll(
                                        '_',
                                        ' ',
                                      ),
                                    ),
                                    _Tag(question.sectionId),
                                    _Tag(question.difficulty),
                                    _Tag(question.status),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'publish') {
                                await _repository.updateQuestionStatus(
                                  track: question.track,
                                  skill: question.skill,
                                  id: question.id,
                                  status: 'published',
                                );
                              } else if (action == 'archive') {
                                await _repository.updateQuestionStatus(
                                  track: question.track,
                                  skill: question.skill,
                                  id: question.id,
                                  status: 'archived',
                                );
                              } else if (action == 'draft') {
                                await _repository.updateQuestionStatus(
                                  track: question.track,
                                  skill: question.skill,
                                  id: question.id,
                                  status: 'draft',
                                );
                              } else if (action == 'delete') {
                                await _repository.deleteQuestion(
                                  track: question.track,
                                  skill: question.skill,
                                  id: question.id,
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              if (question.status != 'published')
                                const PopupMenuItem(
                                  value: 'publish',
                                  child: Text('Publish'),
                                ),
                              if (question.status == 'published')
                                const PopupMenuItem(
                                  value: 'archive',
                                  child: Text('Archive'),
                                ),
                              if (question.status == 'archived')
                                const PopupMenuItem(
                                  value: 'draft',
                                  child: Text('Restore Draft'),
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

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<MockAdminTrack>(
              value: _track,
              decoration:
                  const InputDecoration(labelText: 'IELTS Track'),
              items: MockAdminTrack.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _track = value);
                }
              },
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<MockAdminSkill>(
              value: _skill,
              decoration:
                  const InputDecoration(labelText: 'Skill'),
              items: MockAdminSkill.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _skill = value);
                }
              },
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: _status,
              decoration:
                  const InputDecoration(labelText: 'Status'),
              items: const {
                'all': 'All',
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
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String value;

  const _Tag(this.value);

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: AdminColors.textMuted,
          fontSize: 8.8,
        ),
      ),
    );
  }
}
