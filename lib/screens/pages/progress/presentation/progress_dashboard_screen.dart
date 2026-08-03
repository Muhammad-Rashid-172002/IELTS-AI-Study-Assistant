import 'package:flutter/material.dart';

import '../data/progress_repository.dart';
import '../models/progress_models.dart';
import '../widgets/progress_charts.dart';
import 'progress_report_screen.dart';
import 'progress_theme.dart';
import 'skill_analytics_screen.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState
    extends State<ProgressDashboardScreen> {
  final _repository = ProgressRepository();
  ProgressPeriod _period = ProgressPeriod.all;

  Future<void> _openReport(ProgressPeriod period) async {
    final report = await _repository.buildReport(period: period);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgressReportScreen(report: report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProgressColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _ProgressBackground()),
            StreamBuilder<ProgressOverview>(
              stream: _repository.watchOverview(period: _period),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorState(
                    error: snapshot.error.toString(),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final overview = snapshot.data!;

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _header()),
                      SliverToBoxAdapter(
                        child: _periodSelector(),
                      ),
                      SliverToBoxAdapter(
                        child: _hero(overview),
                      ),
                      SliverToBoxAdapter(
                        child: _overviewMetrics(overview),
                      ),
                      SliverToBoxAdapter(
                        child: _skillChart(overview),
                      ),
                      SliverToBoxAdapter(
                        child: _skillCards(overview),
                      ),
                      SliverToBoxAdapter(
                        child: _reports(),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 110),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 17, 20, 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  ProgressColors.cyan,
                  ProgressColors.blue,
                  ProgressColors.violet,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(
                    color: ProgressColors.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your IELTS performance and readiness',
                  style: TextStyle(
                    color: ProgressColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Target readiness report',
            onPressed: () => _openReport(
              ProgressPeriod.all,
            ),
            icon: const Icon(Icons.description_outlined),
          ),
        ],
      ),
    );
  }

  Widget _periodSelector() {
    return SizedBox(
      height: 47,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: ProgressPeriod.values.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final period = ProgressPeriod.values[index];

          return ChoiceChip(
            selected: _period == period,
            label: Text(period.label),
            onSelected: (_) {
              setState(() => _period = period);
            },
          );
        },
      ),
    );
  }

  Widget _hero(ProgressOverview overview) {
    final bandGap =
        (overview.targetBand - overview.overallBand)
            .clamp(0, 9);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      padding: const EdgeInsets.all(19),
      decoration: progressHeroDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 530;

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Estimated Band',
                style: TextStyle(
                  color: ProgressColors.secondary,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    overview.overallBand.toStringAsFixed(1),
                    style: const TextStyle(
                      color: ProgressColors.text,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ProgressColors.orange
                          .withOpacity(.11),
                      borderRadius:
                          BorderRadius.circular(9),
                    ),
                    child: Text(
                      'Target ${overview.targetBand.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: ProgressColors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                bandGap <= 0
                    ? 'You have reached your target band.'
                    : '${bandGap.toStringAsFixed(1)} band gap remaining.',
                style: const TextStyle(
                  color: ProgressColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                content,
                const SizedBox(height: 17),
                ReadinessRing(
                  value: overview.examReadiness,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              ReadinessRing(
                value: overview.examReadiness,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _overviewMetrics(ProgressOverview overview) {
    final items = [
      (
        'Weekly Study',
        _formatMinutes(overview.weeklyStudyMinutes),
        Icons.schedule_rounded,
        ProgressColors.cyan
      ),
      (
        'Lessons',
        '${overview.completedLessons}',
        Icons.auto_stories_outlined,
        ProgressColors.blue
      ),
      (
        'Mock Tests',
        '${overview.completedMocks}',
        Icons.fact_check_outlined,
        ProgressColors.violet
      ),
      (
        'Current Streak',
        '${overview.currentStreak} days',
        Icons.local_fire_department_rounded,
        ProgressColors.orange
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 4 : 2;
          const spacing = 10.0;
          final width =
              (constraints.maxWidth -
                      spacing * (columns - 1)) /
                  columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: items.map((item) {
              return SizedBox(
                width: width,
                child: _OverviewMetric(
                  label: item.$1,
                  value: item.$2,
                  icon: item.$3,
                  color: item.$4,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _skillChart(ProgressOverview overview) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(17),
      decoration: progressPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skill Comparison',
            style: TextStyle(
              color: ProgressColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Listening • Reading • Writing • Speaking',
            style: TextStyle(
              color: ProgressColors.muted,
              fontSize: 9.5,
            ),
          ),
          const SizedBox(height: 12),
          SkillComparisonChart(
            skills: overview.skills,
            targetBand: overview.targetBand,
          ),
        ],
      ),
    );
  }

  Widget _skillCards(ProgressOverview overview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Detailed Analytics',
          subtitle:
              'Open each skill for criterion and question-type performance.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 760 ? 2 : 1;
              const spacing = 10.0;
              final width =
                  (constraints.maxWidth -
                          spacing * (columns - 1)) /
                      columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: overview.skills.values.map((skill) {
                  return SizedBox(
                    width: width,
                    child: _SkillCard(
                      progress: skill,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SkillAnalyticsScreen(
                              progress: skill,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _reports() {
    final reports = [
      (
        'Daily Report',
        'Today’s activity and completed goals',
        Icons.today_rounded,
        ProgressPeriod.week
      ),
      (
        'Weekly Report',
        'Study time, progress and weak areas',
        Icons.calendar_view_week_rounded,
        ProgressPeriod.week
      ),
      (
        'Monthly Report',
        'Long-term trends and band movement',
        Icons.calendar_month_rounded,
        ProgressPeriod.month
      ),
      (
        'Mock Comparison',
        'Compare recent mock-test performance',
        Icons.compare_arrows_rounded,
        ProgressPeriod.all
      ),
      (
        'Target Readiness',
        'Band gap and exam-readiness analysis',
        Icons.flag_outlined,
        ProgressPeriod.all
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Reports',
          subtitle:
              'Actionable summaries for your next study decision.',
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          decoration: progressPanelDecoration(),
          child: Column(
            children: List.generate(reports.length, (index) {
              final report = reports[index];

              return Column(
                children: [
                  ListTile(
                    onTap: () => _openReport(report.$4),
                    leading: CircleAvatar(
                      backgroundColor:
                          ProgressColors.cyan.withOpacity(.11),
                      child: Icon(
                        report.$3,
                        color: ProgressColors.cyan,
                      ),
                    ),
                    title: Text(
                      report.$1,
                      style: const TextStyle(
                        color: ProgressColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      report.$2,
                      style: const TextStyle(
                        color: ProgressColors.muted,
                        fontSize: 9.5,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                    ),
                  ),
                  if (index < reports.length - 1)
                    const Divider(
                      height: 1,
                      color: ProgressColors.border,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  static String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (hours == 0) return '$remaining min';
    return '${hours}h ${remaining}m';
  }
}

class _OverviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: progressPanelDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.11),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: ProgressColors.muted,
                    fontSize: 8.5,
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

class _SkillCard extends StatelessWidget {
  final SkillProgress progress;
  final VoidCallback onTap;

  const _SkillCard({
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final positive = progress.change >= 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: progressPanelDecoration(),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  ProgressColors.cyan.withOpacity(.11),
              child: Icon(
                _skillIcon(progress.skill),
                color: ProgressColors.cyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.skill,
                    style: const TextStyle(
                      color: ProgressColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${progress.attempts} attempts • '
                    '${progress.accuracy.toStringAsFixed(0)}% accuracy',
                    style: const TextStyle(
                      color: ProgressColors.muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  progress.band.toStringAsFixed(1),
                  style: const TextStyle(
                    color: ProgressColors.cyan,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      positive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: positive
                          ? ProgressColors.green
                          : ProgressColors.red,
                      size: 14,
                    ),
                    Text(
                      '${positive ? '+' : ''}'
                      '${progress.change.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: positive
                            ? ProgressColors.green
                            : ProgressColors.red,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
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

  static IconData _skillIcon(String skill) {
    return switch (skill) {
      'Listening' => Icons.headphones_rounded,
      'Reading' => Icons.menu_book_rounded,
      'Writing' => Icons.edit_note_rounded,
      _ => Icons.mic_rounded,
    };
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ProgressColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: ProgressColors.muted,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBackground extends StatelessWidget {
  const _ProgressBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(.7, -.9),
          radius: 1.1,
          colors: [
            ProgressColors.blue.withOpacity(.10),
            ProgressColors.background,
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;

  const _ErrorState({
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(22),
        decoration: progressPanelDecoration(
          borderColor: ProgressColors.red.withOpacity(.35),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: ProgressColors.red,
              size: 48,
            ),
            const SizedBox(height: 13),
            const Text(
              'Progress could not be loaded',
              style: TextStyle(
                color: ProgressColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ProgressColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
