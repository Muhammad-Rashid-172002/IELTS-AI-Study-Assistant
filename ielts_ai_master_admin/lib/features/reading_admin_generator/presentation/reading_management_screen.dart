import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ielts_ai_master_admin/features/reading_admin_generator/create_generation_job_sheet.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';

class ReadingManagementScreen extends StatefulWidget {
  const ReadingManagementScreen({super.key});

  @override
  State<ReadingManagementScreen> createState() =>
      _ReadingManagementScreenState();
}

class _ReadingManagementScreenState extends State<ReadingManagementScreen> {
  String _filter = 'all';

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'reading_tests',
    );

    if (_filter != 'all') {
      query = query.where('status', isEqualTo: _filter);
    }

    return query;
  }

  Future<void> _updateStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('reading_tests').doc(id).set({
      'status': status,
      'isPublished': status == 'published',
      'publishedAt': status == 'published'
          ? FieldValue.serverTimestamp()
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _delete(String id) async {
    await FirebaseFirestore.instance
        .collection('reading_tests')
        .doc(id)
        .delete();
  }

  void _openGenerator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .94,
      ),
      builder: (_) => const CreateReadingGenerationJobSheet(),
    );
  }

  void _openPreview(String testId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingTestPreviewScreen(testId: testId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Reading Management',
      subtitle: 'Generate, review, publish and archive reading tests',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGenerator,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Generate Reading'),
      ),
      body: Column(
        children: [
          _FilterBar(
            selected: _filter,
            onSelected: (value) {
              setState(() => _filter = value);
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LoadingView();
                }

                if (snapshot.hasError) {
                  return const _MessageView(
                    icon: Icons.error_outline_rounded,
                    title: 'Reading tests could not be loaded',
                    subtitle: 'Check Firestore rules or the required index.',
                  );
                }

                final docs = [...snapshot.data!.docs];

                docs.sort((a, b) {
                  final aDate = a.data()['createdAt'];
                  final bDate = b.data()['createdAt'];
                  final aMillis = aDate is Timestamp
                      ? aDate.millisecondsSinceEpoch
                      : 0;
                  final bMillis = bDate is Timestamp
                      ? bDate.millisecondsSinceEpoch
                      : 0;
                  return bMillis.compareTo(aMillis);
                });

                if (docs.isEmpty) {
                  return _MessageView(
                    icon: Icons.menu_book_outlined,
                    title: 'No reading tests found',
                    subtitle: 'Generate your first AI Reading test.',
                    actionLabel: 'Generate Reading',
                    onAction: _openGenerator,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 11),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    return _ReadingTestCard(
                      id: doc.id,
                      data: data,
                      onOpen: () => _openPreview(doc.id),
                      onPublish: () => _updateStatus(doc.id, 'published'),
                      onArchive: () => _updateStatus(doc.id, 'archived'),
                      onRestore: () => _updateStatus(doc.id, 'draft'),
                      onDelete: () => _delete(doc.id),
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

class ReadingTestPreviewScreen extends StatefulWidget {
  final String testId;

  const ReadingTestPreviewScreen({super.key, required this.testId});

  @override
  State<ReadingTestPreviewScreen> createState() =>
      _ReadingTestPreviewScreenState();
}

class _ReadingTestPreviewScreenState extends State<ReadingTestPreviewScreen> {
  int _selectedPassageIndex = 0;

  Future<void> _updateStatus(String status) {
    return FirebaseFirestore.instance
        .collection('reading_tests')
        .doc(widget.testId)
        .set({
          'status': status,
          'isPublished': status == 'published',
          'publishedAt': status == 'published'
              ? FieldValue.serverTimestamp()
              : null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _delete() async {
    await FirebaseFirestore.instance
        .collection('reading_tests')
        .doc(widget.testId)
        .delete();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Reading Test Preview',
      subtitle: 'Review passages, questions, answers and explanations',
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reading_tests')
            .doc(widget.testId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingView();
          }

          if (snapshot.hasError) {
            return const _MessageView(
              icon: Icons.error_outline_rounded,
              title: 'Reading test could not be loaded',
              subtitle: 'Check Firestore permissions and try again.',
            );
          }

          final document = snapshot.data!;
          if (!document.exists) {
            return const _MessageView(
              icon: Icons.find_in_page_outlined,
              title: 'Reading test not found',
              subtitle: 'This document may have been deleted.',
            );
          }

          final data = document.data() ?? {};
          final passages = _mapList(data['passages']);
          final questions = _mapList(data['questions']);

          if (_selectedPassageIndex >= passages.length && passages.isNotEmpty) {
            _selectedPassageIndex = passages.length - 1;
          }

          final selectedPassageNumber = passages.isEmpty
              ? 1
              : _asInt(
                  passages[_selectedPassageIndex]['passageNumber'],
                  fallback: _selectedPassageIndex + 1,
                );

          final passageQuestions = questions.where((question) {
            return _asInt(question['passageNumber'], fallback: 1) ==
                selectedPassageNumber;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              _PreviewHeaderCard(
                data: data,
                passageCount: passages.length,
                questionCount: questions.length,
              ),
              if (_stringList(data['validationWarnings']).isNotEmpty) ...[
                const SizedBox(height: 12),
                _ValidationWarningCard(
                  warnings: _stringList(data['validationWarnings']),
                ),
              ],
              const SizedBox(height: 16),
              if (passages.isNotEmpty) ...[
                _PassageSelector(
                  passages: passages,
                  selectedIndex: _selectedPassageIndex,
                  onSelected: (index) {
                    setState(() => _selectedPassageIndex = index);
                  },
                ),
                const SizedBox(height: 16),
                _PassagePreviewCard(passage: passages[_selectedPassageIndex]),
              ] else
                const _MessageCard(
                  icon: Icons.article_outlined,
                  title: 'No passages found',
                  subtitle:
                      'The generated document does not contain a passages array.',
                ),
              const SizedBox(height: 18),
              _SectionHeading(
                title: 'Questions & Answers',
                subtitle: passageQuestions.isEmpty
                    ? 'No questions are linked to this passage.'
                    : '${passageQuestions.length} question(s) for Passage $selectedPassageNumber',
              ),
              const SizedBox(height: 10),
              if (passageQuestions.isEmpty)
                const _MessageCard(
                  icon: Icons.quiz_outlined,
                  title: 'No linked questions',
                  subtitle:
                      'Check passageNumber inside the generated questions.',
                )
              else
                ...passageQuestions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _QuestionAnswerCard(
                      question: entry.value,
                      fallbackNumber: entry.key + 1,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _PreviewActions(
                status: (data['status'] ?? 'draft').toString(),
                onPublish: () => _updateStatus('published'),
                onArchive: () => _updateStatus('archived'),
                onRestore: () => _updateStatus('draft'),
                onDelete: () => _confirmDelete(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: const Text(
          'Delete Reading Test?',
          style: TextStyle(color: AdminColors.text),
        ),
        content: const Text(
          'This reading test, all passages and questions will be permanently deleted.',
          style: TextStyle(color: AdminColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _delete();
    }
  }
}

class _ValidationWarningCard extends StatelessWidget {
  final List<String> warnings;

  const _ValidationWarningCard({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AdminColors.warning.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.warning.withOpacity(.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AdminColors.warning),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin review recommended',
                  style: TextStyle(
                    color: AdminColors.warning,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                ...warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $warning',
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHeaderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int passageCount;
  final int questionCount;

  const _PreviewHeaderCard({
    required this.data,
    required this.passageCount,
    required this.questionCount,
  });

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'Untitled Reading Test').toString();
    final description = (data['description'] ?? '').toString();
    final status = (data['status'] ?? 'draft').toString();
    final ieltsType = (data['ieltsType'] ?? 'Academic').toString();
    final mode = (data['mode'] ?? 'passage').toString();
    final difficulty = (data['difficulty'] ?? 'Intermediate').toString();
    final durationSeconds = _asInt(data['durationSeconds'], fallback: 3600);
    final durationMinutes = (durationSeconds / 60).round();
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AdminColors.success.withOpacity(.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AdminColors.success,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusPill(status: status, color: statusColor),
                    const SizedBox(height: 9),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AdminColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (description.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AdminColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: ieltsType),
              _InfoChip(label: mode.toUpperCase()),
              _InfoChip(label: difficulty),
              _InfoChip(label: '$passageCount passages'),
              _InfoChip(label: '$questionCount questions'),
              _InfoChip(label: '$durationMinutes minutes'),
              if (data['speedReading'] == true)
                const _InfoChip(label: 'Speed analytics enabled'),
              if (data['possibleDuplicate'] == true)
                const _InfoChip(label: 'Similarity review required'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PassageSelector extends StatelessWidget {
  final List<Map<String, dynamic>> passages;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PassageSelector({
    required this.passages,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: passages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          final number = _asInt(
            passages[index]['passageNumber'],
            fallback: index + 1,
          );

          return ChoiceChip(
            selected: selected,
            label: Text('Passage $number'),
            avatar: Icon(
              selected ? Icons.check_circle_rounded : Icons.article_outlined,
              size: 18,
            ),
            onSelected: (_) => onSelected(index),
            selectedColor: AdminColors.primary.withOpacity(.20),
            backgroundColor: AdminColors.surface,
            side: BorderSide(
              color: selected ? AdminColors.primary : AdminColors.border,
            ),
            labelStyle: TextStyle(
              color: selected ? AdminColors.text : AdminColors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          );
        },
      ),
    );
  }
}

class _PassagePreviewCard extends StatelessWidget {
  final Map<String, dynamic> passage;

  const _PassagePreviewCard({required this.passage});

  @override
  Widget build(BuildContext context) {
    final number = _asInt(passage['passageNumber'], fallback: 1);
    final title = (passage['title'] ?? 'Reading Passage').toString();
    final topic = (passage['topic'] ?? 'General').toString();
    final text = (passage['text'] ?? '').toString();
    final paragraphs = _stringList(passage['paragraphs']);
    final effectiveParagraphs = paragraphs.isNotEmpty
        ? paragraphs
        : text
              .split(RegExp(r'\n\s*\n'))
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
    final wordCount = _asInt(
      passage['wordCount'],
      fallback: text.trim().isEmpty
          ? 0
          : text.trim().split(RegExp(r'\s+')).length,
    );
    final explanation = (passage['simplifiedExplanation'] ?? '').toString();
    final synonyms = _asMap(passage['synonyms']);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passage $number',
            style: const TextStyle(
              color: AdminColors.cyan,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: AdminColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: topic),
              _InfoChip(label: '$wordCount words'),
            ],
          ),
          const SizedBox(height: 18),
          if (effectiveParagraphs.isEmpty)
            const Text(
              'No passage text available.',
              style: TextStyle(color: AdminColors.textMuted),
            )
          else
            ...effectiveParagraphs.asMap().entries.map(
              (entry) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 11),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AdminColors.background,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AdminColors.border),
                ),
                child: SelectableText(
                  entry.value,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    height: 1.7,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          if (explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _ExpandableAdminSection(
              title: 'Simplified Explanation',
              icon: Icons.lightbulb_outline_rounded,
              child: SelectableText(
                explanation,
                style: const TextStyle(
                  color: AdminColors.textMuted,
                  height: 1.6,
                ),
              ),
            ),
          ],
          if (synonyms.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ExpandableAdminSection(
              title: 'Generated Synonyms',
              icon: Icons.sync_alt_rounded,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: synonyms.entries.map((entry) {
                  final values = _stringList(entry.value);
                  return _InfoChip(label: '${entry.key}: ${values.join(', ')}');
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionAnswerCard extends StatelessWidget {
  final Map<String, dynamic> question;
  final int fallbackNumber;

  const _QuestionAnswerCard({
    required this.question,
    required this.fallbackNumber,
  });

  @override
  Widget build(BuildContext context) {
    final number = _asInt(question['number'], fallback: fallbackNumber);
    final type = _firstText([
      question['type'],
      question['questionType'],
      question['format'],
    ], fallback: 'Reading question');
    final prompt = _firstText([
      question['prompt'],
      question['question'],
      question['sentence'],
      question['stem'],
      question['statement'],
      question['text'],
    ]);
    final options = _stringList(
      question['options'] ?? question['choices'] ?? question['headings'],
    );
    final correctAnswer = _firstText([
      question['correctAnswer'],
      question['answer'],
      question['correct'],
      question['expectedAnswer'],
    ]);
    final acceptedAnswers = _stringList(
      question['acceptedAnswers'] ?? question['alternativeAnswers'],
    );
    final explanation = _firstText([
      question['explanation'],
      question['reason'],
      question['feedback'],
    ]);
    final evidence = _firstText([
      question['evidenceText'],
      question['evidence'],
      question['sourceText'],
    ]);
    final paragraphIndex = _asInt(question['paragraphIndex'], fallback: 0);
    final keywords = _stringList(question['keywords']);
    final wordLimit = _firstText([
      question['wordLimit'],
      question['instruction'],
    ]);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminColors.primary.withOpacity(.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: AdminColors.cyan,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        color: AdminColors.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      prompt.isEmpty ? 'Question prompt is missing.' : prompt,
                      style: const TextStyle(
                        color: AdminColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (wordLimit.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              wordLimit,
              style: const TextStyle(
                color: AdminColors.warning,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
          if (options.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Options',
              style: TextStyle(
                color: AdminColors.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            ...options.asMap().entries.map(
              (entry) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AdminColors.background,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Text(
                  '${String.fromCharCode(65 + entry.key)}. ${entry.value}',
                  style: const TextStyle(color: AdminColors.textMuted),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AdminColors.success.withOpacity(.09),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AdminColors.success.withOpacity(.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AdminColors.success,
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Correct Answer',
                        style: TextStyle(
                          color: AdminColors.success,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        correctAnswer.isEmpty
                            ? 'No correct answer provided.'
                            : correctAnswer,
                        style: const TextStyle(
                          color: AdminColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (acceptedAnswers.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Accepted: ${acceptedAnswers.join(', ')}',
                          style: const TextStyle(
                            color: AdminColors.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (explanation.trim().isNotEmpty ||
              evidence.trim().isNotEmpty ||
              keywords.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ExpandableAdminSection(
              title: 'Explanation & Evidence',
              icon: Icons.fact_check_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (explanation.trim().isNotEmpty) ...[
                    const Text(
                      'Explanation',
                      style: TextStyle(
                        color: AdminColors.cyan,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      explanation,
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        height: 1.55,
                      ),
                    ),
                  ],
                  if (evidence.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Evidence from passage',
                      style: TextStyle(
                        color: AdminColors.warning,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      evidence,
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        height: 1.55,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(label: 'Paragraph ${paragraphIndex + 1}'),
                      ...keywords.map((keyword) => _InfoChip(label: keyword)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpandableAdminSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ExpandableAdminSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Icon(icon, color: AdminColors.cyan),
        title: Text(
          title,
          style: const TextStyle(
            color: AdminColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        children: [Align(alignment: Alignment.centerLeft, child: child)],
      ),
    );
  }
}

class _PreviewActions extends StatelessWidget {
  final String status;
  final VoidCallback onPublish;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _PreviewActions({
    required this.status,
    required this.onPublish,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (status != 'published')
          FilledButton.icon(
            onPressed: onPublish,
            icon: const Icon(Icons.public_rounded),
            label: const Text('Publish Reading'),
          ),
        if (status == 'published')
          OutlinedButton.icon(
            onPressed: onArchive,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive'),
          ),
        if (status == 'archived')
          OutlinedButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restore Draft'),
          ),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete'),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'All', Icons.grid_view_rounded),
      ('draft', 'Draft', Icons.edit_document),
      ('published', 'Published', Icons.public_rounded),
      ('archived', 'Archived', Icons.archive_outlined),
    ];

    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selected == filter.$1;

          return ChoiceChip(
            selected: isSelected,
            label: Text(filter.$2),
            avatar: Icon(filter.$3, size: 17),
            onSelected: (_) => onSelected(filter.$1),
            selectedColor: AdminColors.primary.withOpacity(.20),
            backgroundColor: AdminColors.surface,
            side: BorderSide(
              color: isSelected ? AdminColors.primary : AdminColors.border,
            ),
            labelStyle: TextStyle(
              color: isSelected ? AdminColors.text : AdminColors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          );
        },
      ),
    );
  }
}

class _ReadingTestCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onOpen;
  final VoidCallback onPublish;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _ReadingTestCard({
    required this.id,
    required this.data,
    required this.onOpen,
    required this.onPublish,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'draft').toString();
    final title = (data['title'] ?? 'Untitled Reading Test').toString();
    final ieltsType = (data['ieltsType'] ?? 'Academic').toString();
    final mode = (data['mode'] ?? 'passage').toString();
    final difficulty = (data['difficulty'] ?? 'Intermediate').toString();
    final questionCount = _mapList(data['questions']).length;
    final passageCount = _mapList(data['passages']).length;
    final statusColor = _statusColor(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AdminColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AdminColors.success.withOpacity(.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AdminColors.success,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AdminColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusPill(status: status, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _InfoChip(label: ieltsType),
                        _InfoChip(label: mode.toUpperCase()),
                        _InfoChip(label: difficulty),
                        _InfoChip(label: '$passageCount passage(s)'),
                        _InfoChip(label: '$questionCount questions'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.visibility_outlined, size: 17),
                          label: const Text('Preview'),
                        ),
                        if (status != 'published')
                          OutlinedButton.icon(
                            onPressed: onPublish,
                            icon: const Icon(Icons.public_rounded, size: 17),
                            label: const Text('Publish'),
                          ),
                        if (status == 'published')
                          OutlinedButton.icon(
                            onPressed: onArchive,
                            icon: const Icon(Icons.archive_outlined, size: 17),
                            label: const Text('Archive'),
                          ),
                        if (status == 'archived')
                          OutlinedButton.icon(
                            onPressed: onRestore,
                            icon: const Icon(Icons.restore_rounded, size: 17),
                            label: const Text('Restore'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _confirmDelete(context, onDelete),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 17,
                          ),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, VoidCallback delete) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: const Text(
          'Delete Reading Test?',
          style: TextStyle(color: AdminColors.text),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: AdminColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) delete();
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AdminColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AdminColors.textMuted)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusPill({required this.status, required this.color});

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
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AdminColors.cyan, size: 50),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminColors.textMuted,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AdminColors.cyan, size: 38),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AdminColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AdminColors.textMuted),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'published':
      return AdminColors.success;
    case 'archived':
      return AdminColors.violet;
    case 'failed':
      return const Color(0xFFEF4444);
    default:
      return AdminColors.cyan;
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is! Map) return const {};

  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _firstText(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }
  return fallback;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];

  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
