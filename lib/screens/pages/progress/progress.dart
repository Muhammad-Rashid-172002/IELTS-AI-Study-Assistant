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
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      bottomNavigationBar: BottomNavigation(index: 1),
      body: FutureBuilder<Map<String, double>>(
        future: _calculateAllModules(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  "Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: Text("No Data Found")));
          }

          final data = snapshot.data!;

          double listening = data["listening"]!;
          double reading = data["reading"]!;
          double writing = data["writing"]!;
          double speaking = data["speaking"]!;

          double overall = (listening + reading + writing + speaking) / 4;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              /// ================= HEADER =================
              SliverToBoxAdapter(child: _header(overall)),

              /// ================= MODULES =================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          const Text(
                            "Module Scores",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Icon(
                            Icons.analytics_rounded,
                            color: Color(0xFF6C63FF),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      GridView(
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
                            color: const Color(0xFF2DD4BF), // Teal
                          ),

                          _moduleCard(
                            title: "Reading",
                            score: reading,
                            icon: Icons.menu_book_rounded,
                            color: const Color(0xFF60A5FA), // Soft Blue
                          ),

                          _moduleCard(
                            title: "Writing",
                            score: writing,
                            icon: Icons.edit_note_rounded,
                            color: const Color(0xFFF59E0B), // Amber
                          ),

                          _moduleCard(
                            title: "Speaking",
                            score: speaking,
                            icon: Icons.mic_rounded,
                            color: const Color(0xFFF472B6), // Soft Pink
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              /// ================= LINE CHART =================
              // SliverToBoxAdapter(
              //   child: _sectionCard(
              //     title: "Progress Overview",
              //     child: SizedBox(
              //       height: 250,
              //       child: LineChart(
              //         LineChartData(
              //           minY: 0,
              //           maxY: 9,
              //           borderData: FlBorderData(show: false),

              //           gridData: FlGridData(
              //             show: true,
              //             drawVerticalLine: false,
              //             horizontalInterval: 1,
              //             getDrawingHorizontalLine: (value) {
              //               return FlLine(
              //                 color: Colors.grey.shade200,
              //                 strokeWidth: 1,
              //               );
              //             },
              //           ),

              //           titlesData: FlTitlesData(
              //             leftTitles: AxisTitles(
              //               sideTitles: SideTitles(
              //                 showTitles: true,
              //                 reservedSize: 28,
              //                 getTitlesWidget:
              //                     (value, meta) {
              //                   return Text(
              //                     value.toInt().toString(),
              //                     style: const TextStyle(
              //                       fontSize: 12,
              //                       color: Colors.grey,
              //                     ),
              //                   );
              //                 },
              //               ),
              //             ),

              //             rightTitles: AxisTitles(
              //               sideTitles:
              //                   SideTitles(showTitles: false),
              //             ),

              //             topTitles: AxisTitles(
              //               sideTitles:
              //                   SideTitles(showTitles: false),
              //             ),

              //             bottomTitles: AxisTitles(
              //               sideTitles: SideTitles(
              //                 showTitles: true,
              //                 getTitlesWidget:
              //                     (value, meta) {
              //                   List<String> weeks = [
              //                     "",
              //                     "W1",
              //                     "W2",
              //                     "W3",
              //                     "W4",
              //                     "W5"
              //                   ];

              //                   return Padding(
              //                     padding:
              //                         const EdgeInsets.only(top: 10),
              //                     child: Text(
              //                       weeks[value.toInt()],
              //                       style: const TextStyle(
              //                         fontWeight:
              //                             FontWeight.w600,
              //                       ),
              //                     ),
              //                   );
              //                 },
              //               ),
              //             ),
              //           ),

              //           lineTouchData: LineTouchData(
              //             touchTooltipData:
              //                 LineTouchTooltipData(
              //               tooltipBorderRadius: BorderRadius.circular(14),
              //               getTooltipColor: (touchedSpot) =>
              //                   Colors.black,
              //               getTooltipItems: (spots) {
              //                 return spots.map((spot) {
              //                   return LineTooltipItem(
              //                     "Band ${spot.y.toStringAsFixed(1)}",
              //                     const TextStyle(
              //                       color: Colors.white,
              //                       fontWeight:
              //                           FontWeight.bold,
              //                     ),
              //                   );
              //                 }).toList();
              //               },
              //             ),
              //           ),

              //           lineBarsData: [
              //             LineChartBarData(
              //               isCurved: true,
              //               barWidth: 5,
              //               gradient: const LinearGradient(
              //                 colors: [
              //                   Color(0xFF6C63FF),
              //                   Color(0xFF9C6BFF),
              //                 ],
              //               ),
              //               belowBarData: BarAreaData(
              //                 show: true,
              //                 gradient: LinearGradient(
              //                   colors: [
              //                     const Color(0xFF6C63FF)
              //                         .withOpacity(0.25),
              //                     Colors.transparent,
              //                   ],
              //                   begin: Alignment.topCenter,
              //                   end: Alignment.bottomCenter,
              //                 ),
              //               ),
              //               dotData: FlDotData(
              //                 show: true,
              //                 getDotPainter:
              //                     (spot, percent, barData,
              //                         index) {
              //                   return FlDotCirclePainter(
              //                     radius: 5,
              //                     color:
              //                         const Color(0xFF6C63FF),
              //                     strokeWidth: 2,
              //                     strokeColor: Colors.white,
              //                   );
              //                 },
              //               ),
              //               spots: const [
              //                 FlSpot(1, 5.5),
              //                 FlSpot(2, 6.0),
              //                 FlSpot(3, 6.5),
              //                 FlSpot(4, 7.0),
              //                 FlSpot(5, 7.5),
              //               ],
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   ),
              // ),

              // /// ================= BAR CHART =================
              SliverToBoxAdapter(
                child: _sectionCard(
                  title: "Module Comparison",
                  child: SizedBox(
                    height: 260,
                    child: BarChart(
                      BarChartData(
                        maxY: 9,
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
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
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
                                List<String> titles = ["L", "R", "W", "S"];

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    titles[value.toInt()],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        barGroups: [
                          _bar(0, listening, const Color(0xFF4CAF50)),
                          _bar(1, reading, const Color(0xFF2196F3)),
                          _bar(2, writing, const Color(0xFFFF9800)),
                          _bar(3, speaking, const Color(0xFFE91E63)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff111827), Color(0xff1F2937)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "AI Performance Insight",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        overall >= 7
                            ? "Excellent progress. You're close to advanced IELTS level."
                            : overall >= 6
                            ? "Good improvement. Focus more on weak modules."
                            : "Practice consistently to improve your IELTS band.",
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.amber),

                          const SizedBox(width: 8),

                          Text(
                            "Estimated Overall Band: ${overall.toStringAsFixed(1)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              /// ================= INSIGHTS =================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      _insightCard(
                        title: "Your Strength",
                        subtitle:
                            "Excellent performance in ${_bestModule(listening, reading, writing, speaking)} module.",
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFF4CAF50),
                      ),

                      const SizedBox(height: 16),

                      _insightCard(
                        title: "Needs Improvement",
                        subtitle:
                            "Focus more on ${_worstModule(listening, reading, writing, speaking)} practice.",
                        icon: Icons.auto_graph_rounded,
                        color: const Color(0xFFFF9800),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// ================= HEADER =================

  Widget _header(double overall) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 65, 22, 35),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF08111F), Color(0xFF102A43), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Performance Analytics",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Track your IELTS growth & band score",
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
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
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${overall.toStringAsFixed(1)} / 9",
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF86EFAC),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 92,
                  width: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.35),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ================= MODULE CARD =================
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
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(28),

        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TOP ROW
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "$percentage%",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          /// MODULE NAME
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B1D28),
            ),
          ),

          const SizedBox(height: 10),

          /// SCORE ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  score.toStringAsFixed(1),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(left: 3, bottom: 4),
                child: Text(
                  "/9",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),

              Icon(Icons.trending_up_rounded, color: color, size: 22),
            ],
          ),

          const SizedBox(height: 16),

          /// PROGRESS BAR
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: score / 9,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),

                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.6),
                            blurRadius: 10,
                          ),
                        ],
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

  /// ================= COMMON CARD =================

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  /// ================= BAR =================

  BarChartGroupData _bar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 26,
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );
  }

  /// ================= INSIGHT CARD =================

  Widget _insightCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 30),
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
                    color: Colors.white.withOpacity(0.65),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ================= HELPERS =================

  String _bestModule(double l, double r, double w, double s) {
    Map<String, double> scores = {
      "Listening": l,
      "Reading": r,
      "Writing": w,
      "Speaking": s,
    };

    return scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String _worstModule(double l, double r, double w, double s) {
    Map<String, double> scores = {
      "Listening": l,
      "Reading": r,
      "Writing": w,
      "Speaking": s,
    };

    return scores.entries.reduce((a, b) => a.value < b.value ? a : b).key;
  }

  /// ================= FIREBASE LOGIC =================

  Future<Map<String, double>> _calculateAllModules(String uid) async {
    try {
      final firestore = FirebaseFirestore.instance;

      /// FETCH ALL COLLECTIONS
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

      /// LISTENING + READING
      double listening = _avgScore(listeningSnap.docs);
      double reading = _avgScore(readingSnap.docs);

      /// WRITING
      double writing = 0;

      if (writingSnap.docs.isNotEmpty) {
        final writingBands = writingSnap.docs.map((e) {
          try {
            final data = e.data();

            return double.tryParse(data["band"]?.toString() ?? "0") ?? 0;
          } catch (e) {
            debugPrint("Writing Error: $e");
            return 0;
          }
        }).toList();

        if (writingBands.isNotEmpty) {
          writing = writingBands.reduce((a, b) => a + b) / writingBands.length;
        }
      }

      /// SPEAKING
      double speaking = 0;
      if (speakingSnap.docs.isNotEmpty) {
        final speakingBands = speakingSnap.docs.map((e) {
          try {
            final data = e.data();

            return double.tryParse(data["band"]?.toString() ?? "0") ?? 0;
          } catch (e) {
            debugPrint("Speaking Error: $e");
            return 0.0;
          }
        }).toList();

        if (speakingBands.isNotEmpty) {
          speaking =
              speakingBands.reduce((a, b) => a + b) / speakingBands.length;
        }
      }

      return {
        "listening": listening,
        "reading": reading,
        "writing": writing,
        "speaking": speaking,
      };
    } catch (e) {
      debugPrint("Firebase Main Error: $e");

      return {"listening": 0, "reading": 0, "writing": 0, "speaking": 0};
    }
  }

  /// ================= SAFE AVG SCORE =================

  double _avgScore(List<QueryDocumentSnapshot> docs) {
    try {
      if (docs.isEmpty) return 0;

      final values = docs.map((e) {
        try {
          final data = e.data() as Map<String, dynamic>;

          final score = double.tryParse(data["score"]?.toString() ?? "0") ?? 0;

          final total =
              double.tryParse(
                (data["total"] ?? data["totalQuestions"] ?? 1).toString(),
              ) ??
              1;

          if (total == 0) return 0.0;

          return (score / total) * 9;
        } catch (e) {
          debugPrint("AVG Score Error: $e");
          return 0.0;
        }
      }).toList();

      if (values.isEmpty) return 0;

      return values.reduce((a, b) => a + b) / values.length;
    } catch (e) {
      debugPrint("AVG Main Error: $e");
      return 0;
    }
  }
}
