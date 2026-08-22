import 'package:flutter/material.dart';

import '../models/progress_models.dart';
import '../widgets/progress_charts.dart';
import 'progress_theme.dart';

class SkillAnalyticsScreen extends StatelessWidget {
  final SkillProgress progress;

  const SkillAnalyticsScreen({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProgressColors.background,
      appBar: AppBar(
        backgroundColor: ProgressColors.background,
        title: Text('${progress.skill} Analytics'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _summary(),
          const SizedBox(height: 14),
          _trend(),
          const SizedBox(height: 14),
          _questionTypes(),
          const SizedBox(height: 14),
          ..._skillSpecificSections(),
        ],
      ),
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: progressHeroDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              label: 'Current Band',
              value: progress.band.toStringAsFixed(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Metric(
              label: 'Accuracy',
              value: '${progress.accuracy.toStringAsFixed(0)}%',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Metric(label: 'Attempts', value: '${progress.attempts}'),
          ),
        ],
      ),
    );
  }

  Widget _trend() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: progressPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Band Trend',
            style: TextStyle(
              color: ProgressColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          BandTrendChart(points: progress.trend),
        ],
      ),
    );
  }

  Widget _questionTypes() {
    final entries = progress.questionTypeAccuracy.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: progressPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Question-Type Accuracy',
            style: TextStyle(
              color: ProgressColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          if (entries.isEmpty)
            const Text(
              'Complete more practice to unlock question-type analytics.',
              style: TextStyle(color: ProgressColors.muted),
            )
          else
            ...entries.map(
              (entry) => _ProgressRow(
                label: _label(entry.key),
                value: entry.value,
                suffix: '%',
                maximum: 100,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _skillSpecificSections() {
    return switch (progress.skill) {
      'Listening' => [
        _MapSection(
          title: 'Section Performance',
          values: _map('sectionPerformance'),
          suffix: '%',
        ),
        const SizedBox(height: 14),
        _MapSection(
          title: 'Accent Performance',
          values: _map('accentPerformance'),
          suffix: '%',
        ),
        const SizedBox(height: 14),
        _SingleValueSection(
          title: 'Spelling Issues',
          value: '${_number(progress.details['spellingIssues']).round()}',
          subtitle: 'Total spelling-related mistakes found in current period.',
        ),
      ],
      'Reading' => [
        _MapSection(
          title: 'Passage Performance',
          values: _map('passagePerformance'),
          suffix: '%',
        ),
        const SizedBox(height: 14),
        _SingleValueSection(
          title: 'Reading Speed',
          value: '${_number(progress.details['readingSpeed']).round()} WPM',
          subtitle: 'Average reading speed based on recorded attempts.',
        ),
        const SizedBox(height: 14),
        _SingleValueSection(
          title: 'Time Management',
          value:
              '${_number(progress.details['timeManagement']).toStringAsFixed(0)}%',
          subtitle: 'Estimated efficiency in completing passages on time.',
        ),
      ],
      'Writing' => [
        _MapSection(
          title: 'Criterion Trends',
          values: _map('criteria'),
          suffix: '',
          maximum: 9,
        ),
        const SizedBox(height: 14),
        _MapSection(
          title: 'Grammar Error Categories',
          values: _map('grammarErrors'),
          suffix: '',
        ),
        const SizedBox(height: 14),
        _SingleValueSection(
          title: 'Vocabulary Growth',
          value: _number(
            progress.details['vocabularyGrowth'],
          ).toStringAsFixed(1),
          subtitle: 'Average Lexical Resource or vocabulary score.',
        ),
      ],
      _ => [
        _MapSection(
          title: 'Speaking Criteria',
          values: _map('criteria'),
          suffix: '',
          maximum: 9,
        ),
        const SizedBox(height: 14),
        _SpeakingCriteriaGrid(
          values: {
            'Fluency': _number(progress.details['fluency']),
            'Pronunciation': _number(progress.details['pronunciation']),
            'Grammar': _number(progress.details['grammar']),
            'Vocabulary': _number(progress.details['vocabulary']),
          },
        ),
      ],
    };
  }

  Map<String, double> _map(String key) {
    final value = progress.details[key];

    if (value is Map<String, double>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      ).map((key, value) => MapEntry(key, _number(value)));
    }

    return const {};
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _label(String value) {
    return value
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProgressColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProgressColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: ProgressColors.cyan,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ProgressColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  final String title;
  final Map<String, double> values;
  final String suffix;
  final double? maximum;

  const _MapSection({
    required this.title,
    required this.values,
    required this.suffix,
    this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList();

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: progressPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ProgressColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          if (entries.isEmpty)
            const Text(
              'No analytics available yet.',
              style: TextStyle(color: ProgressColors.muted),
            )
          else
            ...entries.map(
              (entry) => _ProgressRow(
                label: entry.key,
                value: entry.value,
                suffix: suffix,
                maximum: maximum ?? (entry.value <= 9 ? 9 : 100),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final String suffix;
  final double maximum;

  const _ProgressRow({
    required this.label,
    required this.value,
    required this.suffix,
    required this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maximum <= 0 ? 0.0 : (value / maximum).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: ProgressColors.secondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                suffix.isEmpty
                    ? value.toStringAsFixed(1)
                    : '${value.toStringAsFixed(0)}$suffix',
                style: const TextStyle(
                  color: ProgressColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
    );
  }
}

class _SingleValueSection extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _SingleValueSection({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: progressPanelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ProgressColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ProgressColors.muted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: ProgressColors.cyan,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakingCriteriaGrid extends StatelessWidget {
  final Map<String, double> values;

  const _SpeakingCriteriaGrid({required this.values});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: progressPanelDecoration(),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        childAspectRatio: 2.2,
        children: values.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: ProgressColors.background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: ProgressColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.value.toStringAsFixed(1),
                  style: const TextStyle(
                    color: ProgressColors.cyan,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  entry.key,
                  style: const TextStyle(
                    color: ProgressColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
