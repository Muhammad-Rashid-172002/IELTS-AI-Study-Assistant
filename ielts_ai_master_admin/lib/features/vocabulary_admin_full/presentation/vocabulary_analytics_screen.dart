import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';

class VocabularyAnalyticsScreen extends StatelessWidget {
  const VocabularyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Vocabulary Analytics',
      subtitle:
          'Content inventory, learner progress and difficult vocabulary',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('vocabulary_words')
            .snapshots(),
        builder: (context, wordsSnapshot) {
          if (!wordsSnapshot.hasData) return const LoadingView();

          final words = wordsSnapshot.data!.docs;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collectionGroup('vocabulary_progress')
                .limit(1000)
                .snapshots(),
            builder: (context, progressSnapshot) {
              final progress = progressSnapshot.data?.docs ?? [];

              final published = words
                  .where((doc) => doc.data()['status'] == 'published')
                  .length;
              final drafts = words
                  .where((doc) => doc.data()['status'] == 'draft')
                  .length;
              final saved = progress
                  .where((doc) => doc.data()['isSaved'] == true)
                  .length;
              final learned = progress
                  .where((doc) => doc.data()['status'] == 'learned')
                  .length;
              final mastered = progress
                  .where((doc) => doc.data()['status'] == 'mastered')
                  .length;

              final reviews = progress.fold<int>(
                0,
                (total, doc) =>
                    total + _int(doc.data()['reviewCount']),
              );

              final difficult = progress.where((doc) {
                final rating = _int(doc.data()['lastRating']);
                final count = _int(doc.data()['reviewCount']);
                return count >= 2 && rating <= 1;
              }).length;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1100
                          ? 4
                          : constraints.maxWidth >= 620
                              ? 3
                              : 2;
                      const spacing = 10.0;
                      final width =
                          (constraints.maxWidth -
                                  spacing * (columns - 1)) /
                              columns;

                      final metrics = [
                        ('Total Words', words.length, Icons.translate_rounded),
                        ('Published', published, Icons.public_rounded),
                        ('Drafts', drafts, Icons.edit_outlined),
                        ('Saved', saved, Icons.bookmark_outline_rounded),
                        ('Learned', learned, Icons.check_circle_outline_rounded),
                        ('Mastered', mastered,
                            Icons.workspace_premium_outlined),
                        ('Reviews', reviews, Icons.refresh_rounded),
                        ('Difficult', difficult, Icons.warning_amber_rounded),
                      ];

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: metrics.map((item) {
                          return SizedBox(
                            width: width,
                            child: _MetricCard(
                              title: item.$1,
                              value: item.$2,
                              icon: item.$3,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _categoryPanel(words),
                  const SizedBox(height: 12),
                  _bandPanel(words),
                  const SizedBox(height: 12),
                  _topWordsPanel(words),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _categoryPanel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> words,
  ) {
    const labels = {
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
    };

    final values = <String, int>{};
    for (final word in words) {
      final key = (word.data()['category'] ?? 'other').toString();
      values[key] = (values[key] ?? 0) + 1;
    }

    return _Panel(
      title: 'Words by Category',
      icon: Icons.category_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values.entries.map((entry) {
          return _CountChip(
            label: labels[entry.key] ?? entry.key,
            count: entry.value,
          );
        }).toList(),
      ),
    );
  }

  Widget _bandPanel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> words,
  ) {
    final values = <String, int>{};
    for (final word in words) {
      final key = (word.data()['band'] ?? 'Unknown').toString();
      values[key] = (values[key] ?? 0) + 1;
    }

    return _Panel(
      title: 'Words by IELTS Band',
      icon: Icons.insights_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values.entries
            .map(
              (entry) => _CountChip(
                label: entry.key,
                count: entry.value,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _topWordsPanel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> words,
  ) {
    final sorted = [...words]
      ..sort(
        (a, b) => _int(b.data()['savedCount'])
            .compareTo(_int(a.data()['savedCount'])),
      );

    return _Panel(
      title: 'Most Saved Words',
      icon: Icons.bookmark_rounded,
      child: Column(
        children: sorted.take(10).map((doc) {
          final data = doc.data();

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor:
                  AdminColors.cyan.withOpacity(.12),
              child: Text(
                (data['word'] ?? '?')
                    .toString()
                    .substring(0, 1)
                    .toUpperCase(),
                style: const TextStyle(
                  color: AdminColors.cyan,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            title: Text(
              (data['word'] ?? 'Unknown').toString(),
              style: const TextStyle(
                color: AdminColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              (data['topic'] ?? 'General IELTS').toString(),
              style: const TextStyle(
                color: AdminColors.textMuted,
              ),
            ),
            trailing: Text(
              '${_int(data['savedCount'])} saved',
              style: const TextStyle(
                color: AdminColors.cyan,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminColors.cyan.withOpacity(.12),
            child: Icon(icon, color: AdminColors.cyan),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: AdminColors.cyan,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 9.5,
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

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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

class _CountChip extends StatelessWidget {
  final String label;
  final int count;

  const _CountChip({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text(
        '$label  $count',
        style: const TextStyle(
          color: AdminColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
