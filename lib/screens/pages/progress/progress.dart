import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/resources/bottom_navigation_bar/botton_navigation.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
  backgroundColor: const Color(0xFFF4F7FB),
    bottomNavigationBar:  BottomNavigation(index: 1, ),
  body: FutureBuilder<Map<String, double>>(
    future: _calculateAllModules(user.uid),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final data = snapshot.data!;

      double l = data["listening"]!;
      double r = data["reading"]!;
      double w = data["writing"]!;
      double s = data["speaking"]!;
      double overall = (l + r + w + s) / 4;

      return SingleChildScrollView(
        child: Column(
          children: [
            _header(overall),
            _modules(l, r, w, s),

            /// ✅ Chart Section (Fixed)
            // _chartSection(
            //   "Progress Over Time",
            //   LineChart(
            //     LineChartData(
            //       minY: 5,
            //       maxY: 9,

            //       gridData: FlGridData(
            //         show: true,
            //         drawVerticalLine: false,
            //         horizontalInterval: 1,
            //         getDrawingHorizontalLine: (value) {
            //           return FlLine(
            //             color: Colors.grey.withOpacity(0.2),
            //             strokeWidth: 1,
            //             dashArray: [5, 5],
            //           );
            //         },
            //       ),

            //       titlesData: FlTitlesData(
            //         leftTitles: AxisTitles(
            //           sideTitles: SideTitles(
            //             showTitles: true,
            //             reservedSize: 30,
            //           ),
            //         ),
            //         bottomTitles: AxisTitles(
            //           sideTitles: SideTitles(
            //             showTitles: true,
            //             getTitlesWidget: (value, meta) {
            //               switch (value.toInt()) {
            //                 case 1:
            //                   return const Text("Week 1");
            //                 case 2:
            //                   return const Text("Week 2");
            //                 case 3:
            //                   return const Text("Week 3");
            //                 case 4:
            //                   return const Text("Week 4");
            //                 case 5:
            //                   return const Text("Week 5");
            //               }
            //               return const Text("");
            //             },
            //           ),
            //         ),
            //       ),

            //       borderData: FlBorderData(show: false),

            //       lineBarsData: [
            //         LineChartBarData(
            //           isCurved: true,
            //           color: Colors.deepPurple,
            //           barWidth: 4,
            //           dotData: FlDotData(show: true),
            //           spots: const [
            //             FlSpot(1, 5.5),
            //             FlSpot(2, 5.8),
            //             FlSpot(3, 6.0),
            //             FlSpot(4, 6.2),
            //             FlSpot(5, 6.5),
            //           ],
            //         ),
            //       ],

            //       lineTouchData: LineTouchData(
            //         touchTooltipData: LineTouchTooltipData(
            //           getTooltipColor: (touchedSpot) => Colors.white,
            //           getTooltipItems: (touchedSpots) {
            //             return touchedSpots.map((spot) {
            //               return LineTooltipItem(
            //                 "Week ${spot.x.toInt()}\nScore: ${spot.y}",
            //                 const TextStyle(color: Colors.black),
            //               );
            //             }).toList();
            //           },
            //         ),
            //       ),
            //     ),
            //   ),
            // ),

            /// ✅ Module Comparison (ONLY once)
            _moduleComparisonChart(l, r, w, s),

            /// ✅ Insights
            _insights(l, r, w, s),
          ],
        ),
      );
    },
  ),
);
  }

  // ================= HEADER =================
  Widget _header(double overall) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Performance",
              style: TextStyle(color: Colors.white, fontSize: 26)),
          const SizedBox(height: 6),
          const Text("Track your progress",
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Overall Band Score",
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      "${overall.toStringAsFixed(1)} / 9.0",
                      style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                 
                  ],
                ),
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.emoji_events, color: Colors.white),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // ================= MODULES =================
  Widget _modules(double l, double r, double w, double s) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Align(
              alignment: Alignment.centerLeft,
              child: Text("Module Scores",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _card("Listening", l, Colors.green),
              _card("Reading", r, Colors.green),
              _card("Writing", w, Colors.red),
              _card("Speaking", s, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(String title, double value, Color changeColor, ) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const Spacer(),
          Row(
            children: [
              Text(value.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
            
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value / 9,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              color: Colors.deepPurple,
            ),
          )
        ],
      ),
    );
  }

  // ================= GRAPH =================
Widget _chartSection(String title, Widget child) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20), // smooth rounded corners
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937), // dark text like image
          ),
        ),
        const SizedBox(height: 16),

        // Chart Area with light background
        Container(
          height: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB), // light grey bg like image
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      ],
    ),
  );
}

Widget _moduleComparisonChart(
    double l, double r, double w, double s) {
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 15,
          offset: const Offset(0, 5),
        )
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Module Comparison",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: 9,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 3,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.shade300,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
              ),

              borderData: FlBorderData(show: false),

              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 3,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: Colors.grey),
                      );
                    },
                  ),
                ),

                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const labels = ["L", "R", "W", "S"];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          labels[value.toInt()],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),

                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),

              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                 tooltipBorderRadius: BorderRadius.circular(12),
                  tooltipPadding: const EdgeInsets.all(12),
                  getTooltipItem:
                      (group, groupIndex, rod, rodIndex) {
                    const labels = ["L", "R", "W", "S"];
                    return BarTooltipItem(
                      "${labels[group.x]}\nscore : ${rod.toY.toStringAsFixed(1)}",
                      const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
              ),

              barGroups: [
                _barGradient(0, l),
                _barGradient(1, r),
                _barGradient(2, w),
                _barGradient(3, s),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
BarChartGroupData _barGradient(int x, double y) {
  return BarChartGroupData(
    x: x,
    barRods: [
      BarChartRodData(
        toY: y,
        width: 28,
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7B61FF),
            Color(0xFF5A4AE3),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    ],
  );
}
  // ================= COMPARISON =================
  Widget _comparison(double l, double r, double w, double s) {
    return Container(
      height: 250,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: BarChart(
        BarChartData(
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            _bar(0, l),
            _bar(1, r),
            _bar(2, w),
            _bar(3, s),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _bar(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 18,
          borderRadius: BorderRadius.circular(6),
          color: Colors.deepPurple,
        ),
      ],
    );
  }

  // ================= INSIGHTS =================
  Widget _insights(double l, double r, double w, double s) {
    Map<String, double> scores = {
      "Listening": l,
      "Reading": r,
      "Writing": w,
      "Speaking": s,
    };

    String best =
        scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    String worst =
        scores.entries.reduce((a, b) => a.value < b.value ? a : b).key;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _infoCard(
              "Strengths",
              "Excellent performance in $best. Keep it up!",
              Colors.green.shade100,
              Colors.green),
          const SizedBox(height: 12),
          _infoCard(
              "Areas to Improve",
              "Focus more on $worst to boost your score.",
              Colors.orange.shade100,
              Colors.orange),
        ],
      ),
    );
  }

  Widget _infoCard(
      String title, String text, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor,
            child: const Icon(Icons.trending_up, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(text),
                ]),
          )
        ],
      ),
    );
  }

  // ================= LOGIC (UNCHANGED) =================
  Future<Map<String, double>> _calculateAllModules(String uid) async {
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
        .collection("speaking_history")
        .get();

    double listening = _avgScore(listeningSnap.docs);
    double reading = _avgScore(readingSnap.docs);

    double writing = writingSnap.docs.isEmpty
        ? 0
        : writingSnap.docs
                .map((e) =>
                    double.tryParse(e["band"].toString()) ?? 0)
                .reduce((a, b) => a + b) /
            writingSnap.docs.length;

    double speaking = 0;

    if (speakingSnap.docs.isNotEmpty) {
      final bands = speakingSnap.docs.map((e) {
        final feedback = e["feedback"].toString();
        final match =
            RegExp(r'"band":\s*"(\d+(\.\d+)?)"').firstMatch(feedback);
        return double.tryParse(match?.group(1) ?? "0") ?? 0;
      }).toList();

      speaking = bands.reduce((a, b) => a + b) / bands.length;
    }

    return {
      "listening": listening,
      "reading": reading,
      "writing": writing,
      "speaking": speaking,
    };
  }

  double _avgScore(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;

    final values = docs.map((e) {
      final score = e["score"] ?? 0;
      final total = e["total"] ?? e["totalQuestions"] ?? 1;
      return (score / total) * 9;
    }).toList();

    return values.reduce((a, b) => a + b) / values.length;
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4))
      ],
    );
  }
}