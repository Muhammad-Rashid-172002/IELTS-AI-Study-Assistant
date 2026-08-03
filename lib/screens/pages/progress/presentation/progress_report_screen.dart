import 'package:flutter/material.dart';

import '../models/progress_models.dart';
import 'progress_theme.dart';

class ProgressReportScreen extends StatelessWidget {
  final ProgressReport report;

  const ProgressReportScreen({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProgressColors.background,
      appBar: AppBar(
        backgroundColor: ProgressColors.background,
        title: Text(report.title),
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
                        value: report.overallBand.toStringAsFixed(1),
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
                        value: '${report.readiness.round()}%',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ReportSection(
            title: 'Skill Bands',
            icon: Icons.bar_chart_rounded,
            children: report.skillBands.entries
                .map(
                  (entry) => _ReportLine(
                    label: entry.key,
                    value: entry.value.toStringAsFixed(1),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          _ReportSection(
            title: 'Strengths',
            icon: Icons.trending_up_rounded,
            children: report.strengths
                .map((item) => _ReportBullet(item))
                .toList(),
          ),
          const SizedBox(height: 12),
          _ReportSection(
            title: 'Weaknesses',
            icon: Icons.warning_amber_rounded,
            children: report.weaknesses
                .map((item) => _ReportBullet(item))
                .toList(),
          ),
          const SizedBox(height: 12),
          _ReportSection(
            title: 'Recommended Next Steps',
            icon: Icons.auto_awesome_rounded,
            children: report.recommendations
                .map((item) => _ReportBullet(item))
                .toList(),
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
            ],
          ),
        ],
      ),
    );
  }

  static String _minutes(int minutes) {
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (hours == 0) return '$remaining min';
    return '${hours}h ${remaining}m';
  }
}

class _ReportMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ReportMetric({
    required this.label,
    required this.value,
  });

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
            style: const TextStyle(
              color: ProgressColors.muted,
              fontSize: 8.5,
            ),
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
              Icon(icon, color: ProgressColors.cyan),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: ProgressColors.text,
                  fontWeight: FontWeight.w900,
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

  const _ReportLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ProgressColors.secondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: ProgressColors.text,
              fontWeight: FontWeight.w900,
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
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              color: ProgressColors.cyan,
              size: 7,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ProgressColors.secondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
