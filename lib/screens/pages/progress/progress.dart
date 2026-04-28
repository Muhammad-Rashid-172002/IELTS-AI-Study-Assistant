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
  double listening = 0;
  double reading = 0;
  double writing = 0;
  double speaking = 0;

  List<double> readingGraph = [];
  List<double> writingGraph = [];
  List<double> speakingGraph = [];
  List<double> listeningGraph = [];

  bool isLoading = true;
  bool hasData = true;

  double get overall => (listening + reading + writing + speaking) / 4;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  // =========================================
  // ⚡ FAST FIREBASE FETCH (PARALLEL)
  // =========================================
  Future<void> fetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("❌ No user logged in");
      return;
    }

    final db = FirebaseFirestore.instance;

    try {
      debugPrint("🚀 Fetching Firebase data for UID: ${user.uid}");

      final userDocFuture = db.collection("users").doc(user.uid).get();

      final readingFuture = db
          .collection("users")
          .doc(user.uid)
          .collection("reading_results")
          .orderBy("timestamp", descending: false)
          .get();

      final writingFuture = db
          .collection("users")
          .doc(user.uid)
          .collection("writing_results")
       .orderBy("timestamp", descending: false)
          .get();

      final speakingFuture = db
          .collection("users")
          .doc(user.uid)
          .collection("speaking_history")
         .orderBy("timestamp", descending: false)
          .get();

      final results = await Future.wait([
        userDocFuture,
        readingFuture,
        writingFuture,
        speakingFuture,
      ]);

      // ================= USER DATA =================
      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;

      final readingSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;

      final writingSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;

      final speakingSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

      final userData = userDoc.data() ?? {};

      // 🔥 PRINT FULL USER DATA
      debugPrint("📌 USER DOC DATA:");
      debugPrint(userData.toString());

      // ================= MAIN SCORES =================
     final progress = userData["progress"] ?? {};

listening = (progress["listening"] ?? 0).toDouble();
reading = (progress["reading"] ?? 0).toDouble();
writing = (progress["writing"] ?? 0).toDouble();
speaking = (progress["speaking"] ?? 0).toDouble();

      debugPrint("🎯 SCORES:");
      debugPrint("Listening: $listening");
      debugPrint("Reading: $reading");
      debugPrint("Writing: $writing");
      debugPrint("Speaking: $speaking");

      // ================= READ COLLECTION =================
      debugPrint("📚 reading_results:");
      for (var doc in readingSnap.docs) {
        debugPrint(doc.data().toString());
      }

      // ================= WRITING COLLECTION =================
      debugPrint("✍️ writing_results:");
      for (var doc in writingSnap.docs) {
        debugPrint(doc.data().toString());
      }

      // ================= SPEAKING COLLECTION =================
      debugPrint("🗣 speaking_history:");
      for (var doc in speakingSnap.docs) {
        debugPrint(doc.data().toString());
      }

      // ================= GRAPH =================
      readingGraph = _mapReading(readingSnap);
      writingGraph = _mapReading(writingSnap);
      speakingGraph = _mapReading(speakingSnap);

      hasData =
          readingGraph.isNotEmpty ||
          writingGraph.isNotEmpty ||
          speakingGraph.isNotEmpty;

      debugPrint("📊 GRAPH DATA:");
      debugPrint("Reading: $readingGraph");
      debugPrint("Writing: $writingGraph");
      debugPrint("Speaking: $speakingGraph");

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("❌ FIREBASE ERROR: $e");
      hasData = false;
      setState(() => isLoading = false);
    }
  } // 📊 SAFE MAPPING

  // =========================================
 List<double> _mapReading(QuerySnapshot<Map<String, dynamic>> snap) {
  return snap.docs.map<double>((e) {
    final data = e.data();

    final score = data["score"] ?? 0;
    final total = data["total"] ?? 1;

    // IELTS style band (approx)
    double band = (score / total) * 9;

    return band;
  }).toList();
}

  // =========================================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!hasData) {
      return Scaffold(
        bottomNavigationBar: const BottomNavigation(index: 1),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 80, color: Colors.grey),
              SizedBox(height: 10),
              Text("No Progress Data Found", style: TextStyle(fontSize: 18)),
              SizedBox(height: 5),
              Text(
                "Start practicing to see your progress",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      bottomNavigationBar: const BottomNavigation(index: 1),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _header(),
            _modules(),
            _chart("Reading Progress", readingGraph),
            _chart("Writing Progress", writingGraph),
            _chart("Speaking Progress", speakingGraph),
            _insights(),
          ],
        ),
      ),
    );
  }

  // =========================================
  // HEADER
  // =========================================
  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFF5A4AE3)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            "Performance",
            style: TextStyle(color: Colors.white, fontSize: 22),
          ),
          const SizedBox(height: 10),
          Text(
            "Overall: ${overall.toStringAsFixed(1)}",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // =========================================
  // MODULES
  // =========================================
  Widget _modules() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _card("Listening", listening),
          _card("Reading", reading),
          _card("Writing", writing),
          _card("Speaking", speaking),
        ],
      ),
    );
  }

  Widget _card(String title, double value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const Spacer(),
          Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 22)),
          LinearProgressIndicator(value: value / 9),
        ],
      ),
    );
  }

  // =========================================
  // CHART (REUSABLE)
  // =========================================
  Widget _chart(String title, List<double> data) {
    if (data.isEmpty) return const SizedBox();

    return Container(
      height: 220,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      data.length,
                      (i) => FlSpot(i.toDouble(), data[i]),
                    ),
                    isCurved: true,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // INSIGHTS (REAL CALCULATED)
  // =========================================
  Widget _insights() {
    String strength = listening >= 7 || reading >= 7
        ? "Strong in Reading/Listening"
        : "Balanced Performance";

    String improve = writing < 6.5
        ? "Improve Writing Structure"
        : "Keep Practicing Consistently";

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _insight("Strength", strength, Colors.green),
          const SizedBox(height: 10),
          _insight("Improve", improve, Colors.orange),
        ],
      ),
    );
  }

  Widget _insight(String title, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color),
          const SizedBox(width: 10),
          Expanded(child: Text("$title: $text")),
        ],
      ),
    );
  }

  // =========================================
  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
      ],
    );
  }
}
