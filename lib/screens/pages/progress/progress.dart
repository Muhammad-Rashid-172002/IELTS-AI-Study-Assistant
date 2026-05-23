import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/resources/bottom_navigation_bar/botton_navigation.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Future<Map<String, double>>? _progressFuture;

  Color get primary => const Color(0xFF14B8A6);
  Color get secondary => const Color(0xFF0F766E);
  Color get bg => const Color(0xFF08111F);

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _progressFuture = _calculateAllModules(user.uid);
    }
  }

  Future<void> _refreshProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _progressFuture = _calculateAllModules(user.uid);
    });

    await _progressFuture;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(
          child: Text(
            "User not logged in",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: BottomNavigation(index: 1),
      body: FutureBuilder<Map<String, double>>(
        future: _progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loadingBody();
          }

          if (snapshot.hasError) {
            return _errorBody(snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return _emptyBody();
          }

          final data = snapshot.data!;

          final listening = data["listening"] ?? 0.0;
          final reading = data["reading"] ?? 0.0;
          final writing = data["writing"] ?? 0.0;
          final speaking = data["speaking"] ?? 0.0;

          final overall = (listening + reading + writing + speaking) / 4;

          return RefreshIndicator(
            color: primary,
            backgroundColor: const Color(0xFF111827),
            onRefresh: _refreshProgress,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _header(overall)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
                    child: _sectionHeader(
                      title: "Module Scores",
                      subtitle: "Average band from your latest practice",
                      icon: Icons.analytics_rounded,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.82,
                      ),
                      children: [
                        _moduleCard(
                          title: "Listening",
                          score: listening,
                          icon: Icons.headphones_rounded,
                          color: const Color(0xFF2DD4BF),
                        ),
                        _moduleCard(
                          title: "Reading",
                          score: reading,
                          icon: Icons.menu_book_rounded,
                          color: const Color(0xFF60A5FA),
                        ),
                        _moduleCard(
                          title: "Writing",
                          score: writing,
                          icon: Icons.edit_note_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                        _moduleCard(
                          title: "Speaking",
                          score: speaking,
                          icon: Icons.mic_rounded,
                          color: const Color(0xFFF472B6),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _sectionCard(
                    title: "Module Comparison",
                    subtitle: "Compare your IELTS band performance",
                    icon: Icons.bar_chart_rounded,
                    child: SizedBox(
                      height: 260,
                      child: BarChart(
                        BarChartData(
                          maxY: 9,
                          minY: 0,
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.white.withOpacity(0.10),
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.60),
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final titles = ["L", "R", "W", "S"];
                                  final index = value.toInt();

                                  if (index < 0 || index >= titles.length) {
                                    return const SizedBox.shrink();
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      titles[index],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBorderRadius: BorderRadius.circular(8),
                              getTooltipColor: (_) =>
                                  const Color(0xFF111827),
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  "Band ${rod.toY.toStringAsFixed(1)}",
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                );
                              },
                            ),
                          ),
                          barGroups: [
                            _bar(0, listening, const Color(0xFF2DD4BF)),
                            _bar(1, reading, const Color(0xFF60A5FA)),
                            _bar(2, writing, const Color(0xFFF59E0B)),
                            _bar(3, speaking, const Color(0xFFF472B6)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _aiInsightCard(
                    overall: overall,
                    weakestModule: _worstModule(
                      listening,
                      reading,
                      writing,
                      speaking,
                    ),
                    strongestModule: _bestModule(
                      listening,
                      reading,
                      writing,
                      speaking,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                    child: Column(
                      children: [
                        _insightCard(
                          title: "Your Strength",
                          subtitle:
                              "Excellent performance in ${_bestModule(listening, reading, writing, speaking)} module.",
                          icon: Icons.trending_up_rounded,
                          color: const Color(0xFF22C55E),
                        ),
                        const SizedBox(height: 16),
                        _insightCard(
                          title: "Needs Improvement",
                          subtitle:
                              "Focus more on ${_worstModule(listening, reading, writing, speaking)} practice.",
                          icon: Icons.auto_graph_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _loadingBody() {
    return Container(
      color: bg,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.20),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 86,
                width: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [primary, secondary]),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 66,
                      width: 66,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                        backgroundColor: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    const Icon(
                      Icons.analytics_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Loading Progress",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Calculating your IELTS performance analytics...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBody(String error) {
    return Container(
      color: bg,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: _glassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 14),
              const Text(
                "Something went wrong",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.65)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyBody() {
    return Container(
      color: bg,
      child: Center(
        child: Text(
          "No Data Found",
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _header(double overall) {
    final level = _levelLabel(overall);
    final progress = (overall / 9).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 64, 22, 34),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bg,
            const Color(0xFF102A43),
            secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topHeaderRow(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Overall Band",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.66),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        overall.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 58,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF86EFAC),
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        level,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 110,
                  width: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 106,
                        width: 106,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          color: const Color(0xFF86EFAC),
                          backgroundColor: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      Container(
                        height: 82,
                        width: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [primary, secondary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.35),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topHeaderRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primary, secondary]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.insights_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Performance Analytics",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Track your IELTS growth & band score",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.58),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withOpacity(0.20)),
          ),
          child: Icon(icon, color: primary),
        ),
      ],
    );
  }

  Widget _moduleCard({
    required String title,
    required double score,
    required IconData icon,
    required Color color,
  }) {
    final percentage = ((score / 9) * 100).clamp(0, 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.90),
                      color.withOpacity(0.55),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Text(
                  "$percentage%",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  score.toStringAsFixed(1),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 3, bottom: 4),
                child: Text(
                  "/9",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.trending_up_rounded, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (score / 9).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title: title, subtitle: subtitle, icon: icon),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }

  Widget _aiInsightCard({
    required double overall,
    required String weakestModule,
    required String strongestModule,
  }) {
    final readiness = ((overall / 9) * 100).clamp(0, 100).round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withOpacity(0.20),
            const Color(0xFF111827),
            const Color(0xFF0B1220),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: primary.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: "AI Performance Insight",
            subtitle: "Smart recommendation based on your scores",
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 18),
          Text(
            overall >= 7
                ? "Excellent progress. You are close to an advanced IELTS level. Maintain consistency and polish your weaker module."
                : overall >= 6
                    ? "Good improvement. Focus more on $weakestModule to increase your overall band."
                    : "Practice consistently. Your fastest improvement can come from focused $weakestModule practice.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              height: 1.65,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chip("Overall ${overall.toStringAsFixed(1)}"),
              _chip("$readiness% Ready"),
              _chip("Best: $strongestModule"),
              _chip("Focus: $weakestModule"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.84),
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: child,
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y.clamp(0.0, 9.0),
          width: 26,
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.65), color],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );
  }

  Widget _insightCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.90),
                  color.withOpacity(0.55),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _levelLabel(double overall) {
    if (overall >= 8) return "Expert IELTS Level";
    if (overall >= 7) return "Advanced IELTS Level";
    if (overall >= 6) return "Good IELTS Level";
    if (overall >= 5) return "Intermediate IELTS Level";
    if (overall > 0) return "Beginner IELTS Level";
    return "Start practicing to unlock your level";
  }

  String _bestModule(double l, double r, double w, double s) {
    final scores = {
      "Listening": l,
      "Reading": r,
      "Writing": w,
      "Speaking": s,
    };

    return scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String _worstModule(double l, double r, double w, double s) {
    final scores = {
      "Listening": l,
      "Reading": r,
      "Writing": w,
      "Speaking": s,
    };

    return scores.entries.reduce((a, b) => a.value < b.value ? a : b).key;
  }

  Future<Map<String, double>> _calculateAllModules(String uid) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final listeningSnap = await firestore
          .collection("users")
          .doc(uid)
          .collection("listening_results")
          .get();

      final readingSnap = await firestore
          .collection("users")
          .doc(uid)
          .collection("reading_results")
          .get();

      final writingSnap = await firestore
          .collection("users")
          .doc(uid)
          .collection("writing_results")
          .get();

      final speakingSnap = await firestore
          .collection("users")
          .doc(uid)
          .collection("speaking")
          .get();

      final listening = _avgScore(listeningSnap.docs);
      final reading = _avgScore(readingSnap.docs);
      final writing = _avgBand(writingSnap.docs, "band");
      final speaking = _avgBand(speakingSnap.docs, "band");

      return {
        "listening": listening,
        "reading": reading,
        "writing": writing,
        "speaking": speaking,
      };
    } catch (e) {
      debugPrint("Firebase Main Error: $e");

      return {
        "listening": 0,
        "reading": 0,
        "writing": 0,
        "speaking": 0,
      };
    }
  }

  double _avgBand(List<QueryDocumentSnapshot> docs, String field) {
    try {
      if (docs.isEmpty) return 0;

      final values = docs.map((e) {
        try {
          final data = e.data() as Map<String, dynamic>;
          return double.tryParse(data[field]?.toString() ?? "0") ?? 0.0;
        } catch (_) {
          return 0.0;
        }
      }).where((e) => e > 0).toList();

      if (values.isEmpty) return 0;

      return values.reduce((a, b) => a + b) / values.length;
    } catch (e) {
      debugPrint("AVG Band Error: $e");
      return 0;
    }
  }

  double _avgScore(List<QueryDocumentSnapshot> docs) {
    try {
      if (docs.isEmpty) return 0;

      final values = docs.map((e) {
        try {
          final data = e.data() as Map<String, dynamic>;

          final bandField = double.tryParse(data["band"]?.toString() ?? "");

          if (bandField != null && bandField > 0) {
            return bandField;
          }

          final score = double.tryParse(data["score"]?.toString() ?? "0") ?? 0;
          final total = double.tryParse(
                (data["total"] ?? data["totalQuestions"] ?? 1).toString(),
              ) ??
              1;

          if (total == 0) return 0.0;

          return (score / total) * 9;
        } catch (e) {
          debugPrint("AVG Score Error: $e");
          return 0.0;
        }
      }).where((e) => e > 0).toList();

      if (values.isEmpty) return 0;

      return values.reduce((a, b) => a + b) / values.length;
    } catch (e) {
      debugPrint("AVG Main Error: $e");
      return 0;
    }
  }
}