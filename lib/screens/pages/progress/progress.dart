import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';

import '../../../controller/firebase_services/firebase_services.dart';
import '../../../resources/bottom_navigation_bar/botton_navigation.dart';


import 'package:intl/intl.dart';

import '../../widgets/weekly_progress/weekly_progress.dart';

// class Progress extends StatefulWidget {
//   const Progress({super.key});
//
//   @override
//   State<Progress> createState() => _ProgressState();
// }
//
// class _ProgressState extends State<Progress> {
//   final FirebaseServices _fs = Get.find();
//   List<Map<String, dynamic>> weekly = [];
//
//   @override
//   void initState() {
//     super.initState();
//     loadChart();
//   }
//
//   void loadChart() async {
//     weekly = await _fs.getWeeklyProgress();
//     setState(() {});
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Progress')),
//       bottomNavigationBar: BottomNavigation(index: 1),
//
//       body: weekly.isEmpty
//           ? const Center(child: Text("No weekly data"))
//           : ListView.builder(
//         itemCount: weekly.length,
//         itemBuilder: (_, i) {
//           final item = weekly[i];
//           final ts = item['date'] as Timestamp;
//           final date = DateFormat('yyyy-MM-dd').format(ts.toDate());
//
//           return ListTile(
//             title: Text(date),
//             subtitle: Text(
//               "Summaries: ${item['summaries']} | "
//                   "MCQs: ${item['questions']} | "
//                   "Math Solved: ${item['solved']}",
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
class Progress extends StatefulWidget {
  const Progress({super.key});

  @override
  State<Progress> createState() => _ProgressState();
}

class _ProgressState extends State<Progress> {
  final FirebaseServices _fs = Get.find();
  List<Map<String, dynamic>> weekly = [];

  @override
  void initState() {
    super.initState();
    loadChart();
  }

  void loadChart() async {
    weekly = await _fs.getWeeklyProgress();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Progress',style: TextStyle(fontWeight: FontWeight.bold),),
      ),
      bottomNavigationBar: BottomNavigation(index: 1),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// ==============================
            /// BEAUTIFUL WEEKLY BAR CHART
            /// ==============================
            WeeklyProgressChart(weekly: weekly),

            const SizedBox(height: 20),

            /// ==============================
            /// WEEKLY RAW LIST
            /// ==============================
            weekly.isEmpty
                ? const Center(child: Text("No weekly data"))
                : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: weekly.length,
              itemBuilder: (_, i) {
                final item = weekly[i];
                final ts = item['date'] as Timestamp;
                final date =
                DateFormat('yyyy-MM-dd').format(ts.toDate());

                // return ListTile(
                //   title: Text(date),
                //   subtitle: Text(
                //     "Summaries: ${item['summaries']} | "
                //         "MCQs: ${item['questions']} | "
                //         "Math Solved: ${item['solved']}",
                //   ),
                // );
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Header
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Three Numbers Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _miniStat("Summaries", item['summaries'], Icons.menu_book_rounded, Colors.blue),
                          _miniStat("MCQs", item['questions'], Icons.quiz_outlined, Colors.green),
                          _miniStat("Solved", item['solved'], Icons.calculate_outlined, Colors.purple),
                        ],
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
  Widget _miniStat(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

}
