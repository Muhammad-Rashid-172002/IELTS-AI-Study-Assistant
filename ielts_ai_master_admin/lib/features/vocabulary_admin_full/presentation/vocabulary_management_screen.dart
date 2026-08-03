import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/vocabulary_admin_repository.dart';
import '../domain/vocabulary_admin_word.dart';
import 'create_vocabulary_generation_job_sheet.dart';
import 'vocabulary_analytics_screen.dart';
import 'vocabulary_word_details_screen.dart';
import 'vocabulary_word_editor_screen.dart';

class VocabularyManagementScreen extends StatefulWidget {
  const VocabularyManagementScreen({super.key});

  @override
  State<VocabularyManagementScreen> createState() =>
      _VocabularyManagementScreenState();
}

class _VocabularyManagementScreenState
    extends State<VocabularyManagementScreen> {
  final _repository = VocabularyAdminRepository();

  final Set<String> _selectedIds = {};
  String _status = 'all';
  String _category = 'all';
  String _band = 'all';
  String _query = '';
  bool _gridView = true;

  void _openGenerator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .96,
      ),
      builder: (_) => const CreateVocabularyGenerationJobSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Vocabulary Management',
      subtitle:
          'Generate, edit, publish and analyse IELTS vocabulary content',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGenerator,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Generate Vocabulary'),
      ),
      body: Column(
        children: [
          _toolbar(),
          if (_selectedIds.isNotEmpty) _bulkBar(),
          Expanded(
            child: StreamBuilder<List<VocabularyAdminWord>>(
              stream: _repository.watchWords(
                status: _status,
                category: _category,
                band: _band,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ErrorView(
                    message:
                        'Vocabulary load nahi hui. Firestore rules/index check karein.',
                  );
                }
                if (!snapshot.hasData) return const LoadingView();

                final words = snapshot.data!.where((word) {
                  if (_query.isEmpty) return true;

                  final text = [
                    word.word,
                    word.meaning,
                    word.translation,
                    word.topic,
                    word.partOfSpeech,
                    ...word.synonyms,
                    ...word.collocations,
                  ].join(' ').toLowerCase();

                  return text.contains(_query);
                }).toList();

                if (words.isEmpty) {
                  return _EmptyState(
                    onGenerate: _openGenerator,
                    onCreateManual: _openManualCreate,
                  );
                }

                if (!_gridView) {
                  return _table(words);
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1300
                        ? 4
                        : constraints.maxWidth >= 980
                            ? 3
                            : constraints.maxWidth >= 650
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
                          children: words.map((word) {
                            return SizedBox(
                              width: width,
                              child: _VocabularyCard(
                                word: word,
                                selected:
                                    _selectedIds.contains(word.id),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedIds.add(word.id);
                                    } else {
                                      _selectedIds.remove(word.id);
                                    }
                                  });
                                },
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
          final compact = constraints.maxWidth < 1050;

          final search = SizedBox(
            width: compact ? double.infinity : 300,
            child: TextField(
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
              decoration: const InputDecoration(
                hintText: 'Search word, meaning or topic...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          );

          final controls = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filter(
                width: 160,
                label: 'Status',
                value: _status,
                items: const {
                  'all': 'All Status',
                  'draft': 'Draft',
                  'published': 'Published',
                  'archived': 'Archived',
                },
                onChanged: (value) =>
                    setState(() => _status = value),
              ),
              _filter(
                width: 190,
                label: 'Category',
                value: _category,
                items: const {
                  'all': 'All Categories',
                  'academic': 'Academic',
                  'topic': 'Topic',
                  'band_5': 'Band 5',
                  'band_6': 'Band 6',
                  'band_7': 'Band 7',
                  'band_8_9': 'Band 8–9',
                  'collocations': 'Collocations',
                  'phrasal_verbs': 'Phrasal Verbs',
                  'synonyms': 'Synonyms',
                  'spelling': 'Spelling',
                },
                onChanged: (value) =>
                    setState(() => _category = value),
              ),
              _filter(
                width: 140,
                label: 'Band',
                value: _band,
                items: const {
                  'all': 'All Bands',
                  'Band 5': 'Band 5',
                  'Band 6': 'Band 6',
                  'Band 7': 'Band 7',
                  'Band 8': 'Band 8',
                  'Band 8-9': 'Band 8–9',
                  'Band 9': 'Band 9',
                },
                onChanged: (value) =>
                    setState(() => _band = value),
              ),
              IconButton.filledTonal(
                tooltip: _gridView ? 'Table view' : 'Grid view',
                onPressed: () =>
                    setState(() => _gridView = !_gridView),
                icon: Icon(
                  _gridView
                      ? Icons.table_rows_outlined
                      : Icons.grid_view_rounded,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openManualCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Manual Word'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const VocabularyAnalyticsScreen(),
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
              children: [
                search,
                const SizedBox(height: 10),
                controls,
              ],
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

  Widget _bulkBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AdminColors.primary.withOpacity(.13),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AdminColors.primary.withOpacity(.30)),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedIds.length} selected',
            style: const TextStyle(
              color: AdminColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _bulkStatus('published'),
            child: const Text('Publish'),
          ),
          TextButton(
            onPressed: () => _bulkStatus('archived'),
            child: const Text('Archive'),
          ),
          IconButton(
            tooltip: 'Clear selection',
            onPressed: () => setState(_selectedIds.clear),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkStatus(String status) async {
    await _repository.bulkUpdateStatus(_selectedIds, status);
    if (mounted) setState(_selectedIds.clear);
  }

  Widget _table(List<VocabularyAdminWord> words) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      child: Container(
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AdminColors.border),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: true,
            columns: const [
              DataColumn(label: Text('Word')),
              DataColumn(label: Text('Meaning')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Band')),
              DataColumn(label: Text('Topic')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Saved')),
              DataColumn(label: Text('Mastered')),
              DataColumn(label: Text('Actions')),
            ],
            rows: words.map((word) {
              return DataRow(
                selected: _selectedIds.contains(word.id),
                onSelectChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedIds.add(word.id);
                    } else {
                      _selectedIds.remove(word.id);
                    }
                  });
                },
                cells: [
                  DataCell(
                    Text(
                      word.word,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 240,
                      child: Text(
                        word.meaning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(word.categoryLabel)),
                  DataCell(Text(word.band)),
                  DataCell(Text(word.topic)),
                  DataCell(Text(word.status)),
                  DataCell(Text('${word.savedCount}')),
                  DataCell(Text('${word.masteredCount}')),
                  DataCell(
                    IconButton(
                      tooltip: 'Open',
                      onPressed: () => _openDetails(word.id),
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
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
        decoration: InputDecoration(labelText: label),
        items: items.entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }

  void _openManualCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VocabularyWordEditorScreen(),
      ),
    );
  }

  void _openDetails(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VocabularyWordDetailsScreen(wordId: id),
      ),
    );
  }
}

class _VocabularyCard extends StatelessWidget {
  final VocabularyAdminWord word;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VocabularyAdminRepository repository;

  const _VocabularyCard({
    required this.word,
    required this.selected,
    required this.onSelected,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (word.status) {
      'published' => AdminColors.success,
      'archived' => AdminColors.violet,
      _ => AdminColors.cyan,
    };

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VocabularyWordDetailsScreen(wordId: word.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AdminColors.primary : AdminColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.09),
              blurRadius: 17,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (value) => onSelected(value == true),
                ),
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    word.word.isEmpty
                        ? '?'
                        : word.word[0].toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const Spacer(),
                _Status(label: word.status, color: color),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              word.word,
              style: const TextStyle(
                color: AdminColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${word.pronunciation} ${word.ipa}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminColors.cyan,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              word.meaning,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminColors.textMuted,
                height: 1.45,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(word.categoryLabel),
                _Tag(word.band),
                _Tag(word.topic),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                _Metric(
                  icon: Icons.bookmark_outline_rounded,
                  value: word.savedCount,
                ),
                const SizedBox(width: 10),
                _Metric(
                  icon: Icons.check_circle_outline_rounded,
                  value: word.learnedCount,
                ),
                const SizedBox(width: 10),
                _Metric(
                  icon: Icons.workspace_premium_outlined,
                  value: word.masteredCount,
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'publish') {
                      await repository.updateStatus(
                        id: word.id,
                        status: 'published',
                      );
                    } else if (action == 'archive') {
                      await repository.updateStatus(
                        id: word.id,
                        status: 'archived',
                      );
                    } else if (action == 'draft') {
                      await repository.updateStatus(
                        id: word.id,
                        status: 'draft',
                      );
                    } else if (action == 'duplicate') {
                      await repository.duplicateWord(word.id);
                    } else if (action == 'delete') {
                      await repository.deleteWord(word.id);
                    }
                  },
                  itemBuilder: (context) => [
                    if (word.status != 'published')
                      const PopupMenuItem(
                        value: 'publish',
                        child: Text('Publish'),
                      ),
                    if (word.status == 'published')
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Archive'),
                      ),
                    if (word.status == 'archived')
                      const PopupMenuItem(
                        value: 'draft',
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
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final int value;

  const _Metric({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AdminColors.textMuted, size: 15),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: const TextStyle(
            color: AdminColors.textMuted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  final String label;
  final Color color;

  const _Status({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

class _Tag extends StatelessWidget {
  final String label;

  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AdminColors.textMuted,
          fontSize: 8.5,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onGenerate;
  final VoidCallback onCreateManual;

  const _EmptyState({
    required this.onGenerate,
    required this.onCreateManual,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(27),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.translate_rounded,
              color: AdminColors.cyan,
              size: 54,
            ),
            const SizedBox(height: 15),
            const Text(
              'No Vocabulary Words Found',
              style: TextStyle(
                color: AdminColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate vocabulary with AI or create a complete learner card manually.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AdminColors.textMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Generate with AI'),
                ),
                OutlinedButton.icon(
                  onPressed: onCreateManual,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Manually'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
