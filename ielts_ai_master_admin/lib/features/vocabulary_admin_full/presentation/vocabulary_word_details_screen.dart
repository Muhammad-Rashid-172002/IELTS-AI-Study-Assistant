import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/vocabulary_admin_repository.dart';
import '../domain/vocabulary_admin_word.dart';
import 'vocabulary_word_editor_screen.dart';

class VocabularyWordDetailsScreen extends StatelessWidget {
  final String wordId;

  const VocabularyWordDetailsScreen({
    super.key,
    required this.wordId,
  });

  @override
  Widget build(BuildContext context) {
    final repository = VocabularyAdminRepository();

    return AdminScaffold(
      title: 'Vocabulary Word Details',
      subtitle: 'Review learner content, metadata and engagement',
      body: StreamBuilder<VocabularyAdminWord?>(
        stream: repository.watchWord(wordId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorView(
              message: 'Vocabulary word load nahi hua.',
            );
          }
          if (!snapshot.hasData) return const LoadingView();

          final word = snapshot.data;
          if (word == null) {
            return const ErrorView(
              message: 'Vocabulary word not found.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              _hero(word),
              const SizedBox(height: 14),
              _metrics(word),
              const SizedBox(height: 14),
              _section(
                'Meaning and Translation',
                Icons.translate_rounded,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _labelValue('Meaning', word.meaning),
                    _labelValue('Translation', word.translation),
                    _labelValue('Pronunciation', word.pronunciation),
                    _labelValue('IPA', word.ipa),
                    _labelValue('Part of Speech', word.partOfSpeech),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _section(
                'Example and Usage',
                Icons.format_quote_rounded,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _labelValue(
                      'Example Sentence',
                      word.exampleSentence,
                    ),
                    _labelValue('Usage Note', word.usageNote),
                    _labelValue('Common Mistake', word.commonMistake),
                    _labelValue('Spelling Tip', word.spellingTip),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _section(
                'Word Relationships',
                Icons.hub_outlined,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chips('Synonyms', word.synonyms),
                    _chips('Antonyms', word.antonyms),
                    _chips('Collocations', word.collocations),
                    _chips('Word Family', word.wordFamily),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _section(
                'IELTS Classification',
                Icons.tune_rounded,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(word.categoryLabel),
                    _InfoChip(word.band),
                    _InfoChip(word.difficulty),
                    _InfoChip(word.topic),
                    _InfoChip(word.register),
                    ...word.modules.map(_InfoChip.new),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VocabularyWordEditorScreen(
                            existing: word,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit Word'),
                  ),
                  if (word.status != 'published')
                    OutlinedButton.icon(
                      onPressed: () => repository.updateStatus(
                        id: word.id,
                        status: 'published',
                      ),
                      icon: const Icon(Icons.public_rounded),
                      label: const Text('Publish'),
                    ),
                  if (word.status == 'published')
                    OutlinedButton.icon(
                      onPressed: () => repository.updateStatus(
                        id: word.id,
                        status: 'archived',
                      ),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archive'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => repository.duplicateWord(word.id),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Duplicate'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await repository.deleteWord(word.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
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

  Widget _hero(VocabularyAdminWord word) {
    final color = switch (word.status) {
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
        border:
            Border.all(color: AdminColors.cyan.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            word.status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            word.word,
            style: const TextStyle(
              color: AdminColors.text,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${word.pronunciation}  ${word.ipa}',
            style: const TextStyle(
              color: AdminColors.cyan,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            word.meaning,
            style: const TextStyle(
              color: AdminColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metrics(VocabularyAdminWord word) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650 ? 2 : 5;
        const spacing = 9.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        final items = [
          ('Saved', word.savedCount.toDouble()),
          ('Learned', word.learnedCount.toDouble()),
          ('Mastered', word.masteredCount.toDouble()),
          ('Reviews', word.reviewCount.toDouble()),
          ('Accuracy', word.averageAccuracy),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      item.$1 == 'Accuracy'
                          ? '${item.$2.toStringAsFixed(0)}%'
                          : item.$2.toInt().toString(),
                      style: const TextStyle(
                        color: AdminColors.cyan,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.$1,
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
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

  Widget _labelValue(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AdminColors.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              color: AdminColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(String label, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AdminColors.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: items.map(_InfoChip.new).toList(),
          ),
        ],
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
          const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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
