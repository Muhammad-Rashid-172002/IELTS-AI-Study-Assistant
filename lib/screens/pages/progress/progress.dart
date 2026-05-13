import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/resources/bottom_navigation_bar/botton_navigation.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

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
      backgroundColor: const Color(0xFFF4F7FC),
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
                          Text(
                            "Module Scores",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B1D28),
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
                            color: const Color(0xFF4CAF50),
                          ),
                          _moduleCard(
                            title: "Reading",
                            score: reading,
                            icon: Icons.menu_book_rounded,
                            color: const Color(0xFF2196F3),
                          ),
                          _moduleCard(
                            title: "Writing",
                            score: writing,
                            icon: Icons.edit_note_rounded,
                            color: const Color(0xFFFF9800),
                          ),
                          _moduleCard(
                            title: "Speaking",
                            score: speaking,
                            icon: Icons.mic_rounded,
                            color: const Color(0xFFE91E63),
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
                              color: Colors.grey.shade200,
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
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
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
          colors: [Color(0xFF6C63FF), Color(0xFF8E7CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Performance Analytics",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "Track your IELTS growth & performance",
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),

          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Overall Band",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        overall.toStringAsFixed(1) + " / 9",
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.amber,
                    size: 48,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  color: color.withOpacity(0.12),
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
                  color: color.withOpacity(0.10),
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
                    color: Colors.grey,
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
            child: LinearProgressIndicator(
              value: score / 9,
              minHeight: 10,
              backgroundColor: color.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation(color),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B1D28),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
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

            final feedback = data["feedback"]?.toString() ?? "";

            final match = RegExp(
              r'"band":\s*"(\d+(\.\d+)?)"',
            ).firstMatch(feedback);

            return double.tryParse(match?.group(1) ?? "0") ?? 0;
          } catch (e) {
            debugPrint("Speaking Error: $e");
            return 0;
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
