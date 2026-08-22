import 'package:flutter/material.dart';

import '../models/progress_models.dart';
import 'progress_theme.dart';

class ProgressReportScreen extends StatelessWidget {
  final ProgressReport report;

  const ProgressReportScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final calculatedResult = _calculateOverallBand(report.skillBands);
    final hasCompleteResult = calculatedResult != null;

    final readiness = hasCompleteResult
        ? report.readiness.clamp(0.0, 100.0)
        : 0.0;

    return Scaffold(
      backgroundColor: ProgressColors.background,
      appBar: AppBar(
        backgroundColor: ProgressColors.background,
        foregroundColor: ProgressColors.text,
        elevation: 0,
        title: Text(
          report.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: progressHeroDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.subtitle,
                  style: const TextStyle(
                    color: ProgressColors.cyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _ReportMetric(
                        label: 'Overall Band',
                        value: hasCompleteResult
                            ? calculatedResult.toStringAsFixed(1)
                            : '—',
                        valueColor: hasCompleteResult
                            ? ProgressColors.cyan
                            : ProgressColors.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReportMetric(
                        label: 'Target Band',
                        value: report.targetBand.toStringAsFixed(1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReportMetric(
                        label: 'Readiness',
                        value: hasCompleteResult
                            ? '${readiness.round()}%'
                            : '—',
                        valueColor: hasCompleteResult
                            ? ProgressColors.cyan
                            : ProgressColors.muted,
                      ),
                    ),
                  ],
                ),

                if (!hasCompleteResult) ...[
                  const SizedBox(height: 16),
                  const _IncompleteBandNotice(),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          _ReportSection(
            title: 'Skill Bands',
            icon: Icons.bar_chart_rounded,
            children: _orderedSkillEntries(report.skillBands).map((entry) {
              final completed = entry.value > 0;

              return _ReportLine(
                label: entry.key,
                value: completed
                    ? entry.value.toStringAsFixed(1)
                    : 'Not attempted',
                valueColor: completed
                    ? ProgressColors.text
                    : ProgressColors.orange,
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          _ReportSection(
            title: 'Overall Band Calculation',
            icon: Icons.calculate_outlined,
            children: [
              if (hasCompleteResult) ...[
                _ReportLine(
                  label: 'Calculated overall band',
                  value: calculatedResult.toStringAsFixed(1),
                ),
                const _ReportBullet(
                  'The overall band is calculated from Listening, Reading, '
                  'Writing and Speaking, then rounded to the nearest 0.5 band.',
                ),
              ] else ...[
                const _ReportBullet(
                  'Complete all four IELTS skills before an overall band '
                  'can be calculated.',
                ),
                ..._missingSkills(report.skillBands).map(
                  (skill) =>
                      _ReportBullet('$skill assessment is still required.'),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          _ReportSection(
            title: 'Strengths',
            icon: Icons.trending_up_rounded,
            children: report.strengths.isEmpty
                ? const [
                    _ReportBullet(
                      'Complete more assessments to identify your strengths.',
                    ),
                  ]
                : report.strengths.map((item) => _ReportBullet(item)).toList(),
          ),

          const SizedBox(height: 12),

          _ReportSection(
            title: 'Weaknesses',
            icon: Icons.warning_amber_rounded,
            children: report.weaknesses.isEmpty
                ? const [
                    _ReportBullet(
                      'Complete more assessments to identify weak areas.',
                    ),
                  ]
                : report.weaknesses.map((item) => _ReportBullet(item)).toList(),
          ),

          const SizedBox(height: 12),

          _ReportSection(
            title: 'Recommended Next Steps',
            icon: Icons.auto_awesome_rounded,
            children: [
              if (!hasCompleteResult)
                ..._missingSkills(report.skillBands).map(
                  (skill) => _ReportBullet('Complete the $skill assessment.'),
                ),
              ...report.recommendations.map((item) => _ReportBullet(item)),
            ],
          ),

          const SizedBox(height: 12),

          _ReportSection(
            title: 'Study Summary',
            icon: Icons.schedule_rounded,
            children: [
              _ReportLine(
                label: 'Study time',
                value: _minutes(report.studyMinutes),
              ),
              _ReportLine(
                label: 'Practice attempts',
                value: '${report.attempts}',
              ),
              _ReportLine(
                label: 'Completed skills',
                value: '${_completedSkillCount(report.skillBands)} / 4',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Calculates the IELTS overall band only when all four skills exist
  /// and each skill has a valid band greater than zero.
  static double? _calculateOverallBand(Map<String, double> skillBands) {
    const requiredSkills = ['Listening', 'Reading', 'Writing', 'Speaking'];

    final scores = <double>[];

    for (final skill in requiredSkills) {
      final score = _findSkillBand(skillBands, skill);

      if (score == null || score <= 0 || score > 9) {
        return null;
      }

      scores.add(score);
    }

    final average =
        scores.reduce((first, second) => first + second) / scores.length;

    return _roundToNearestHalfBand(average);
  }

  static double _roundToNearestHalfBand(double value) {
    return (value * 2).round() / 2;
  }

  static double? _findSkillBand(
    Map<String, double> skillBands,
    String requiredSkill,
  ) {
    for (final entry in skillBands.entries) {
      if (entry.key.trim().toLowerCase() == requiredSkill.toLowerCase()) {
        return entry.value;
      }
    }

    return null;
  }

  static List<MapEntry<String, double>> _orderedSkillEntries(
    Map<String, double> skillBands,
  ) {
    const requiredSkills = ['Listening', 'Reading', 'Writing', 'Speaking'];

    return requiredSkills.map((skill) {
      return MapEntry(skill, _findSkillBand(skillBands, skill) ?? 0.0);
    }).toList();
  }

  static List<String> _missingSkills(Map<String, double> skillBands) {
    const requiredSkills = ['Listening', 'Reading', 'Writing', 'Speaking'];

    return requiredSkills.where((skill) {
      final score = _findSkillBand(skillBands, skill);
      return score == null || score <= 0;
    }).toList();
  }

  static int _completedSkillCount(Map<String, double> skillBands) {
    return _orderedSkillEntries(
      skillBands,
    ).where((entry) => entry.value > 0).length;
  }

  static String _minutes(int minutes) {
    final safeMinutes = minutes.clamp(0, 1000000);
    final hours = safeMinutes ~/ 60;
    final remaining = safeMinutes % 60;

    if (hours == 0) return '$remaining min';
    if (remaining == 0) return '${hours}h';

    return '${hours}h ${remaining}m';
  }
}

class _IncompleteBandNotice extends StatelessWidget {
  const _IncompleteBandNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ProgressColors.orange.withOpacity(.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProgressColors.orange.withOpacity(.28)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: ProgressColors.orange,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Overall band is incomplete. Complete Listening, Reading, '
              'Writing and Speaking to calculate a valid IELTS overall band.',
              style: TextStyle(
                color: ProgressColors.secondary,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _ReportMetric({
    required this.label,
    required this.value,
    this.valueColor = ProgressColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProgressColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProgressColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ProgressColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ReportSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: progressPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ProgressColors.cyan, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ProgressColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }
}

class _ReportLine extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _ReportLine({
    required this.label,
    required this.value,
    this.valueColor = ProgressColors.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBullet extends StatelessWidget {
  final String text;

  const _ReportBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, color: ProgressColors.cyan, size: 7),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ProgressColors.secondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
