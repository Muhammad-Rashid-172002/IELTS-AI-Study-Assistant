import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class WeeklyProgressChart extends StatelessWidget {
  final List<Map<String, dynamic>> weekly;

  const WeeklyProgressChart({super.key, required this.weekly});

  @override
  Widget build(BuildContext context) {
    if (weekly.isEmpty) {
      return const Center(child: Text("No Weekly Progress"));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Weekly Performance",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),

                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),

                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= weekly.length) {
                          return const SizedBox();
                        }

                        final ts = weekly[index]['date'];
                        final date = ts.toDate().toString().substring(5, 10); // MM-DD

                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                barGroups: List.generate(
                  weekly.length,
                      (index) {
                    final item = weekly[index];

                    final summaries = (item['summaries'] ?? 0).toDouble();
                    final mcqs = (item['questions'] ?? 0).toDouble();
                    final solved = (item['solved'] ?? 0).toDouble();

                    return BarChartGroupData(
                      x: index,
                      barsSpace: 6,
                      barRods: [
                        BarChartRodData(
                          toY: summaries,
                          color: Colors.blueAccent,
                          width: 15,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: mcqs,
                          color: Colors.green,
                          width: 15,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: solved,
                          color: Colors.purple,
                          width: 15,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // LEGEND
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _Legend(color: Colors.blueAccent, label: "Summaries"),
              _Legend(color: Colors.green, label: "MCQs"),
              _Legend(color: Colors.purple, label: "Math Solved"),
            ],
          ),
        ],
      ),
    );
  }
}

// Legend widget
class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
