import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:fyproject/screens/pages/registration/Auth_gateway_screen.dart';

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

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  final _repository = ProgressRepository();
  ProgressPeriod _period = ProgressPeriod.all;

  Future<void> _openReport(ProgressPeriod period) async {
    final report = await _repository.buildReport(period: period);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProgressReportScreen(report: report)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: ProgressColors.background,
            body: _ProgressLoadingState(),
          );
        }

        if (authSnapshot.data == null) {
          return const _ProgressLoginRequired();
        }

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
                      return _ErrorState(error: snapshot.error.toString());
                    }

                    if (!snapshot.hasData) {
                      return const _ProgressLoadingState();
                    }

                    final overview = snapshot.data!;

                    return RefreshIndicator(
                      color: ProgressColors.cyan,
                      backgroundColor: ProgressColors.surface,
                      onRefresh: () async => setState(() {}),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(child: _header()),
                          SliverToBoxAdapter(child: _periodSelector()),
                          SliverToBoxAdapter(child: _hero(overview)),
                          SliverToBoxAdapter(child: _overviewMetrics(overview)),
                          SliverToBoxAdapter(child: _skillChart(overview)),
                          SliverToBoxAdapter(child: _skillCards(overview)),
                          SliverToBoxAdapter(child: _reports()),
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
      },
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: TextStyle(color: ProgressColors.muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Target readiness report',
            onPressed: () => _openReport(ProgressPeriod.all),
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
    final completedSkills = overview.skills.values
        .where(
          (skill) => skill.attempts > 0 && skill.band > 0 && skill.band <= 9,
        )
        .toList();

    final missingSkills = overview.skills.values
        .where(
          (skill) => skill.attempts <= 0 || skill.band <= 0 || skill.band > 9,
        )
        .map((skill) => skill.skill)
        .toList();

    final hasAnyResult = completedSkills.isNotEmpty;
    final isComplete = completedSkills.length == 4;
    final bandGap = hasAnyResult
        ? (overview.targetBand - overview.overallBand).clamp(0, 9)
        : overview.targetBand;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      padding: const EdgeInsets.all(19),
      decoration: progressHeroDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 530;

          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isComplete
                          ? 'Current Estimated Overall Band'
                          : 'Current Provisional Band',
                      style: const TextStyle(
                        color: ProgressColors.secondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _CompletionBadge(completed: completedSkills.length, total: 4),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    hasAnyResult
                        ? overview.overallBand.toStringAsFixed(1)
                        : '—',
                    style: const TextStyle(
                      color: ProgressColors.text,
                      fontSize: 42,
                      height: 1,
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
                      color: ProgressColors.orange.withOpacity(.11),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: ProgressColors.orange.withOpacity(.20),
                      ),
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
              const SizedBox(height: 8),
              Text(
                !hasAnyResult
                    ? 'Complete your first IELTS skill assessment to '
                          'generate an estimated band.'
                    : isComplete
                    ? bandGap <= 0
                          ? 'You have reached your target band.'
                          : '${bandGap.toStringAsFixed(1)} band gap remaining.'
                    : 'Estimated from ${completedSkills.length} completed '
                          '${completedSkills.length == 1 ? 'skill' : 'skills'}. '
                          'Complete the missing ${missingSkills.length == 1 ? 'part' : 'parts'} '
                          'for your full overall band.',
                style: const TextStyle(
                  color: ProgressColors.muted,
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
            ],
          );

          final ring = Column(
            children: [
              ReadinessRing(value: overview.examReadiness),
              if (!isComplete) ...[
                const SizedBox(height: 8),
                const Text(
                  'Provisional readiness',
                  style: TextStyle(
                    color: ProgressColors.muted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          );

          final topContent = compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summary,
                    const SizedBox(height: 17),
                    Center(child: ring),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 18),
                    ring,
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              topContent,
              if (!isComplete) ...[
                const SizedBox(height: 17),
                _MissingSkillsNotice(
                  missingSkills: missingSkills,
                  completedSkills: completedSkills
                      .map((skill) => skill.skill)
                      .toList(),
                ),
              ],
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
        ProgressColors.cyan,
      ),
      (
        'Lessons',
        '${overview.completedLessons}',
        Icons.auto_stories_outlined,
        ProgressColors.blue,
      ),
      (
        'Mock Tests',
        '${overview.completedMocks}',
        Icons.fact_check_outlined,
        ProgressColors.violet,
      ),
      (
        'Current Streak',
        '${overview.currentStreak} days',
        Icons.local_fire_department_rounded,
        ProgressColors.orange,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760 ? 4 : 2;
          const spacing = 10.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;

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
            style: TextStyle(color: ProgressColors.muted, fontSize: 9.5),
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
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              const spacing = 10.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

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
                                SkillAnalyticsScreen(progress: skill),
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
        ProgressPeriod.week,
      ),
      (
        'Weekly Report',
        'Study time, progress and weak areas',
        Icons.calendar_view_week_rounded,
        ProgressPeriod.week,
      ),
      (
        'Monthly Report',
        'Long-term trends and band movement',
        Icons.calendar_month_rounded,
        ProgressPeriod.month,
      ),
      (
        'Mock Comparison',
        'Compare recent mock-test performance',
        Icons.compare_arrows_rounded,
        ProgressPeriod.all,
      ),
      (
        'Target Readiness',
        'Band gap and exam-readiness analysis',
        Icons.flag_outlined,
        ProgressPeriod.all,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Reports',
          subtitle: 'Actionable summaries for your next study decision.',
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
                      backgroundColor: ProgressColors.cyan.withOpacity(.11),
                      child: Icon(report.$3, color: ProgressColors.cyan),
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
                    const Divider(height: 1, color: ProgressColors.border),
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

class _CompletionBadge extends StatelessWidget {
  final int completed;
  final int total;

  const _CompletionBadge({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final complete = completed == total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (complete ? ProgressColors.green : ProgressColors.violet)
            .withOpacity(.11),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: (complete ? ProgressColors.green : ProgressColors.violet)
              .withOpacity(.28),
        ),
      ),
      child: Text(
        complete ? 'ALL SKILLS COMPLETE' : '$completed OF $total COMPLETE',
        style: TextStyle(
          color: complete ? ProgressColors.green : ProgressColors.violet,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .45,
        ),
      ),
    );
  }
}

class _MissingSkillsNotice extends StatelessWidget {
  final List<String> missingSkills;
  final List<String> completedSkills;

  const _MissingSkillsNotice({
    required this.missingSkills,
    required this.completedSkills,
  });

  @override
  Widget build(BuildContext context) {
    final hasStarted = completedSkills.isNotEmpty;
    final title = missingSkills.isEmpty
        ? 'All IELTS skills completed'
        : hasStarted
        ? 'Complete ${missingSkills.join(' and ')}'
        : 'Start your IELTS assessment';

    final description = missingSkills.isEmpty
        ? 'Your estimated overall band now includes all four skills.'
        : hasStarted
        ? 'Your current band uses ${completedSkills.join(', ')}. '
              'Complete the missing ${missingSkills.length == 1 ? 'skill' : 'skills'} '
              'to unlock a full estimated overall band.'
        : 'Complete Listening, Reading, Writing and Speaking to unlock '
              'your estimated overall band.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ProgressColors.orange.withOpacity(.11),
            ProgressColors.violet.withOpacity(.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProgressColors.orange.withOpacity(.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ProgressColors.orange.withOpacity(.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: ProgressColors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ProgressColors.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: ProgressColors.secondary,
                    fontSize: 9.5,
                    height: 1.45,
                  ),
                ),
                if (missingSkills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: missingSkills
                        .map(
                          (skill) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ProgressColors.background.withOpacity(.55),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: ProgressColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _missingSkillIcon(skill),
                                  color: ProgressColors.orange,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  skill,
                                  style: const TextStyle(
                                    color: ProgressColors.secondary,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _missingSkillIcon(String skill) {
    return switch (skill) {
      'Listening' => Icons.headphones_rounded,
      'Reading' => Icons.menu_book_rounded,
      'Writing' => Icons.edit_note_rounded,
      _ => Icons.mic_rounded,
    };
  }
}

class _ProgressLoadingState extends StatelessWidget {
  const _ProgressLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: ProgressColors.cyan,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading your progress...',
            style: TextStyle(
              color: ProgressColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLoginRequired extends StatelessWidget {
  const _ProgressLoginRequired();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProgressColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _ProgressBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ProgressColors.surface.withOpacity(.98),
                        ProgressColors.blue.withOpacity(.10),
                        ProgressColors.violet.withOpacity(.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: ProgressColors.cyan.withOpacity(.20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.28),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              ProgressColors.cyan,
                              ProgressColors.blue,
                              ProgressColors.violet,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: ProgressColors.cyan.withOpacity(.25),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                          size: 45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Please Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ProgressColors.text,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sign in to view your IELTS band estimates, skill '
                        'analytics, study reports and exam readiness.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ProgressColors.secondary,
                          fontSize: 12,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 21),
                      const _LoginBenefit(
                        icon: Icons.bar_chart_rounded,
                        text: 'Track all four IELTS skill bands',
                      ),
                      const SizedBox(height: 9),
                      const _LoginBenefit(
                        icon: Icons.track_changes_rounded,
                        text: 'See your target band and missing skills',
                      ),
                      const SizedBox(height: 9),
                      const _LoginBenefit(
                        icon: Icons.description_outlined,
                        text: 'Access personalised progress reports',
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                ProgressColors.blue,
                                ProgressColors.cyan,
                                ProgressColors.violet,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: ProgressColors.blue.withOpacity(.30),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AuthenticationGatewayScreen(
                                        initialMode: AuthMode.signIn,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.login_rounded),
                            label: const Text(
                              'Login to Continue',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBenefit extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LoginBenefit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: ProgressColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProgressColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: ProgressColors.cyan, size: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ProgressColors.secondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: ProgressColors.green,
            size: 17,
          ),
        ],
      ),
    );
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
              crossAxisAlignment: CrossAxisAlignment.start,
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

  const _SkillCard({required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final attempted = progress.attempts > 0 && progress.band > 0;
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
              backgroundColor: ProgressColors.cyan.withOpacity(.11),
              child: Icon(
                _skillIcon(progress.skill),
                color: ProgressColors.cyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    attempted
                        ? '${progress.attempts} attempts • '
                              '${progress.accuracy.toStringAsFixed(0)}% accuracy'
                        : 'Not attempted yet',
                    style: TextStyle(
                      color: attempted
                          ? ProgressColors.muted
                          : ProgressColors.orange,
                      fontSize: 9,
                      fontWeight: attempted ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  attempted ? progress.band.toStringAsFixed(1) : '—',
                  style: TextStyle(
                    color: attempted
                        ? ProgressColors.cyan
                        : ProgressColors.muted,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (attempted)
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
                  )
                else
                  const Text(
                    'Required',
                    style: TextStyle(
                      color: ProgressColors.orange,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
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

  const _SectionTitle({required this.title, required this.subtitle});

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
            style: const TextStyle(color: ProgressColors.muted, fontSize: 9.5),
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

  const _ErrorState({required this.error});

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
              style: const TextStyle(color: ProgressColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
