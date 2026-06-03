import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/resources/bottom_navigation_bar/botton_navigation.dart';
import 'package:fyproject/screens/Full_Mock_Test/Full_mock_test.dart';
import 'package:fyproject/screens/pages/Listening_Practice/ListeningPractice.dart';
import 'package:fyproject/screens/pages/Reading_Practice/ReadingPractice.dart';
import 'package:fyproject/screens/pages/Speaking_Practice/SpeakingPractice.dart';
import 'package:fyproject/screens/pages/Writing_Checker/WritingChecker.dart';
import 'package:fyproject/screens/widgets/add_fire_pulse/fire_animation.dart';
import 'package:fyproject/services/StreakService.dart';
import 'package:get/get.dart';

import '../../../controller/firebase_services/firebase_services.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  double readingBand = 0;
  double listeningBand = 0;
  double writingBand = 0;
  double speakingBand = 0;

  bool loadingAnalyzer = true;
  String weakestSkill = "Start a test";
  String todayFocus = "Complete your first IELTS test";

  @override
  void initState() {
    super.initState();
    final services = Get.find<FirebaseServices>();
    services.loadUserProfile();
    StreakService.updateUserStreak();
    loadWeaknessAnalyzer();
  }

  Future<void> loadWeaknessAnalyzer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final uid = user.uid;

      final reading = await _getModuleAverage(uid, "reading_results");
      final listening = await _getModuleAverage(uid, "listening_results");
      final writing = await _getModuleAverage(uid, "writing_results");
      final speaking = await _getModuleAverage(uid, "speaking");

      setState(() {
        readingBand = reading;
        listeningBand = listening;
        writingBand = writing;
        speakingBand = speaking;

        _analyzeWeakArea();
        loadingAnalyzer = false;
      });
    } catch (e) {
      setState(() => loadingAnalyzer = false);
    }
  }

  Future<double> _getModuleAverage(String uid, String collection) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection(collection)
        .get();

    if (snapshot.docs.isEmpty) return 0;

    if (collection == "listening_results" || collection == "reading_results") {
      return _avgScore(snapshot.docs);
    } else {
      return _avgBand(snapshot.docs, "band");
    }
  }

  double _avgBand(List<QueryDocumentSnapshot> docs, String field) {
    try {
      if (docs.isEmpty) return 0;

      final values = docs
          .map((e) {
            final data = e.data() as Map<String, dynamic>;
            return double.tryParse(data[field]?.toString() ?? "0") ?? 0.0;
          })
          .where((e) => e > 0)
          .toList();

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

      final values = docs
          .map((e) {
            final data = e.data() as Map<String, dynamic>;

            final bandField = double.tryParse(data["band"]?.toString() ?? "");

            if (bandField != null && bandField > 0) {
              return bandField;
            }

            final score =
                double.tryParse(data["score"]?.toString() ?? "0") ?? 0;
            final total =
                double.tryParse(
                  (data["total"] ?? data["totalQuestions"] ?? 1).toString(),
                ) ??
                1;

            if (total == 0) return 0.0;

            return (score / total) * 9;
          })
          .where((e) => e > 0)
          .toList();

      if (values.isEmpty) return 0;

      return values.reduce((a, b) => a + b) / values.length;
    } catch (e) {
      debugPrint("AVG Score Error: $e");
      return 0;
    }
  }

  void _analyzeWeakArea() {
    final scores = {
      "Reading": readingBand,
      "Listening": listeningBand,
      "Writing": writingBand,
      "Speaking": speakingBand,
    };

    final validScores = scores.entries.where((e) => e.value > 0).toList();

    if (validScores.isEmpty) {
      weakestSkill = "No test data yet";
      todayFocus = "Take your first IELTS test";
      return;
    }

    validScores.sort((a, b) => a.value.compareTo(b.value));

    weakestSkill = validScores.first.key;

    if (weakestSkill == "Writing") {
      todayFocus = "Grammar & Writing";
    } else if (weakestSkill == "Speaking") {
      todayFocus = "Pronunciation & Speaking";
    } else if (weakestSkill == "Reading") {
      todayFocus = "Reading Accuracy";
    } else {
      todayFocus = "Listening Practice";
    }
  }

  Widget _buildWeaknessAnalyzerCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF111827),
              const Color(0xFF0F766E).withOpacity(.72),
              const Color(0xFF14B8A6).withOpacity(.22),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(.12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14B8A6).withOpacity(.22),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: loadingAnalyzer
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 58,
                        width: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5EEAD4), Color(0xFF14B8A6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5EEAD4).withOpacity(.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),

                      const SizedBox(width: 14),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "IELTS Performance ",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.3,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              "Analyze strengths, weaknesses & focus areas",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.8,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(.10),
                          ),
                        ),
                        child: const Text(
                          "Insights",
                          style: TextStyle(
                            color: Color(0xFFCCFBF1),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: _bandMiniCard("Reading", readingBand)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _bandMiniCard("Listening", listeningBand),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(child: _bandMiniCard("Writing", writingBand)),
                      const SizedBox(width: 10),
                      Expanded(child: _bandMiniCard("Speaking", speakingBand)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(.14),
                          Colors.white.withOpacity(.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white.withOpacity(.10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF14B8A6).withOpacity(.22),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.track_changes_rounded,
                                color: Color(0xFF5EEAD4),
                                size: 22,
                              ),
                            ),

                            const SizedBox(width: 12),

                            const Expanded(
                              child: Text(
                                "Improvement Priority",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Text(
                          weakestSkill,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.4,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "Recommended Focus: $todayFocus",
                          style: const TextStyle(
                            color: Color(0xFFCCFBF1),
                            fontSize: 14.5,
                            height: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withOpacity(.13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF5EEAD4).withOpacity(.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF5EEAD4),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  weakestSkill == "No test data yet"
                                      ? "Complete your first IELTS test to unlock smart performance insights."
                                      : "Focus on $todayFocus today to improve your overall IELTS band score.",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(.88),
                                    fontSize: 13.5,
                                    height: 1.45,
                                    fontWeight: FontWeight.w700,
                                  ),
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
      ),
    );
  }

  Widget _bandMiniCard(String title, double band) {
    final bool hasData = band > 0;

    String status;
    IconData statusIcon;
    Color statusColor;

    if (!hasData) {
      status = "No Data";
      statusIcon = Icons.lock_outline_rounded;
      statusColor = Colors.white.withOpacity(.45);
    } else if (band >= 7) {
      status = "Strong";
      statusIcon = Icons.trending_up_rounded;
      statusColor = const Color(0xFF5EEAD4);
    } else if (band >= 5.5) {
      status = "Average";
      statusIcon = Icons.stacked_line_chart_rounded;
      statusColor = const Color(0xFFFACC15);
    } else {
      status = "Needs Work";
      statusIcon = Icons.warning_amber_rounded;
      statusColor = const Color(0xFFF87171);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(.12),
            Colors.white.withOpacity(.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(statusIcon, color: statusColor, size: 17),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            hasData ? band.toStringAsFixed(1) : "--",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -.4,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.14),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: statusColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      bottomNavigationBar: BottomNavigation(index: 0),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //                   HEADER SECTION
              _buildHeader(),
              const SizedBox(height: 18),

              _buildDailyCoachCard(),

              const SizedBox(height: 18),

              _buildWeaknessAnalyzerCard(),

              const SizedBox(height: 20),

              //                     STUDY MODULES TEXT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5EEAD4), Color(0xFF14B8A6)],
                            ),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),

                        const SizedBox(width: 12),

                        const Expanded(
                          child: Text(
                            "IELTS Study Hub",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Master Reading, Listening, Writing and Speaking with personalized AI-powered practice and real exam simulations.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.65),
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withOpacity(.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF14B8A6).withOpacity(.20),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF5EEAD4),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "AI Powered Learning",
                            style: TextStyle(
                              color: Color(0xFFCCFBF1),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              //                     MODULE CARDS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _moduleCard(
                            title: "Listening",
                            subtitle: "Audio & conversation practice",
                            tag: "Practice",
                            icon: Icons.headphones_rounded,
                            startColor: const Color(0xFF2563EB),
                            endColor: const Color(0xFF1D4ED8),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ListeningPractice(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _moduleCard(
                            title: "Reading",
                            subtitle: "Academic passage training",
                            tag: "Academic",
                            icon: Icons.menu_book_rounded,
                            startColor: const Color(0xFF7C3AED),
                            endColor: const Color(0xFF6D28D9),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReadingPractice(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _moduleCard(
                            title: "Writing",
                            subtitle: "Essay & grammar evaluation",
                            tag: "Checker",
                            icon: Icons.edit_note_rounded,
                            startColor: const Color(0xFFF97316),
                            endColor: const Color(0xFFEA580C),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WritingChecker(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _moduleCard(
                            title: "Speaking",
                            subtitle: "Fluency & pronunciation coach",
                            tag: "Coach",
                            icon: Icons.record_voice_over_rounded,
                            startColor: const Color(0xFF14B8A6),
                            endColor: const Color(0xFF0F766E),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SpeakingPractice(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: _moduleCard(
                    //         title: "Vocabulary",
                    //         subtitle: "Word builder",
                    //         color: const Color(0xFF26A69A),
                    //         tag: "Vocab",
                    //         icon: Icons.translate,
                    //         onTap: () {
                    //           Navigator.push(
                    //             context,
                    //             MaterialPageRoute(
                    //               builder: (_) => const Vocabularybuilder(),
                    //             ),
                    //           );
                    //         },
                    //       ),
                    //     ),
                    //     const SizedBox(width: 12),
                    //   ],
                    // ),
                    SizedBox(height: 12),
                    _moduleCard1(
                      title: "Full Mock Test",
                      subtitle:
                          "Complete IELTS exam simulation with timer, scoring and band prediction.",
                      color: Colors.orange,
                      tag: "EXAM MODE",
                      icon: Icons.workspace_premium_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FullMockTest(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyCoachCard() {
    final FirebaseServices services = Get.find<FirebaseServices>();
    final data = services.userData;
    final String userName = data['name'] ?? "IELTS Student";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF111827),
              const Color(0xFF0F766E).withOpacity(.85),
              const Color(0xFF14B8A6).withOpacity(.30),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(.12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14B8A6).withOpacity(.22),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5EEAD4), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5EEAD4).withOpacity(.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                const SizedBox(width: 14),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Daily IELTS Coach",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.3,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Smart study plan for today",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(.10)),
                  ),
                  child: const Text(
                    "IELTS Coach",
                    style: TextStyle(
                      color: Color(0xFFCCFBF1),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            Text(
              "Good Morning, $userName 👋",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              _coachMessage(),
              style: TextStyle(
                color: Colors.white.withOpacity(.82),
                fontSize: 14.5,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(.14),
                    Colors.white.withOpacity(.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6).withOpacity(.20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.track_changes_rounded,
                          color: Color(0xFF5EEAD4),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Today's Focus Plan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  ..._todayTasks().map((task) => _coachTaskRow(task)),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _coachMessage() {
    if (weakestSkill == "No test data yet" || weakestSkill == "Start a test") {
      return "Start your first IELTS practice test today. I will track your performance and guide you step by step.";
    }

    return "Your weakest skill is $weakestSkill. Focus on $todayFocus today to improve your overall IELTS band.";
  }

  List<String> _todayTasks() {
    if (weakestSkill == "Writing") {
      return [
        "Complete 1 Writing Task",
        "Review grammar mistakes",
        "Learn 10 academic words",
      ];
    }

    if (weakestSkill == "Speaking") {
      return [
        "Complete 1 Speaking Practice",
        "Speak for at least 5 minutes",
        "Use longer answers in Part 2",
      ];
    }

    if (weakestSkill == "Reading") {
      return [
        "Complete 1 Reading Test",
        "Review wrong answers",
        "Practice skimming and scanning",
      ];
    }

    if (weakestSkill == "Listening") {
      return [
        "Complete 1 Listening Test",
        "Replay difficult audio parts",
        "Write down new vocabulary",
      ];
    }

    return [
      "Complete 1 IELTS practice test",
      "Check your band score",
      "Build your study streak",
    ];
  }

  Widget _coachTaskRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF5EEAD4),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //                     HEADER WIDGET

  Widget _buildHeader() {
    final FirebaseServices services = Get.find<FirebaseServices>();
    final data = services.userData;

    final int streak = data['streak'] ?? 0;
    final String? userName = data['name'];
    final String? userPhoto = data['profileImage'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF06111F), Color(0xFF0B2538), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "IELTS Genius AI",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Reach your target band with smart practice",
                      style: TextStyle(
                        color: Colors.white.withOpacity(.68),
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(.13),
                  Colors.white.withOpacity(.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.22),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5EEAD4), Color(0xFF14B8A6)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 31,
                    backgroundColor: const Color(0xFF08111F),
                    backgroundImage: (userPhoto != null && userPhoto.isNotEmpty)
                        ? NetworkImage(userPhoto)
                        : null,
                    child: (userPhoto == null || userPhoto.isEmpty)
                        ? const Icon(
                            Icons.person_rounded,
                            color: Colors.white70,
                            size: 32,
                          )
                        : null,
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome Back 👋",
                        style: TextStyle(
                          color: Colors.white.withOpacity(.65),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        userName ?? "IELTS Student",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6).withOpacity(.18),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          "IELTS Journey Active",
                          style: TextStyle(
                            color: Color(0xFFCCFBF1),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF14B8A6).withOpacity(.34),
                  const Color(0xFF0F766E).withOpacity(.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(.12)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14B8A6).withOpacity(.18),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FirePulseIcon(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Study Streak",
                            style: TextStyle(
                              color: Colors.white.withOpacity(.68),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "$streak Days",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(.10),
                        ),
                      ),
                      child: const Text(
                        "Keep Going",
                        style: TextStyle(
                          color: Color(0xFFCCFBF1),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _nextRewardProgress(streak),

                const SizedBox(height: 18),

                Text(
                  "Achievement Rewards",
                  style: TextStyle(
                    color: Colors.white.withOpacity(.88),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _rewardBadge(
                        title: "7 Day\nWarrior",
                        icon: Icons.shield_rounded,
                        unlocked: streak >= 7,
                        progressText: "${streak.clamp(0, 7)} / 7",
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _rewardBadge(
                        title: "30 Day\nChampion",
                        icon: Icons.emoji_events_rounded,
                        unlocked: streak >= 30,
                        progressText: "${streak.clamp(0, 30)} / 30",
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _rewardBadge(
                        title: "100 Day\nMaster",
                        icon: Icons.workspace_premium_rounded,
                        unlocked: streak >= 100,
                        progressText: "${streak.clamp(0, 100)} / 100",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextRewardProgress(int streak) {
    int target = 7;
    String reward = "7 Day Warrior";

    if (streak >= 7 && streak < 30) {
      target = 30;
      reward = "30 Day Champion";
    } else if (streak >= 30 && streak < 100) {
      target = 100;
      reward = "100 Day Master";
    } else if (streak >= 100) {
      target = 100;
      reward = "All Rewards Unlocked";
    }

    final progress = (streak / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Next Reward",
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reward,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white.withOpacity(0.10),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF5EEAD4)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            streak >= 100 ? "Completed" : "$streak / $target Days",
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardBadge({
    required String title,
    required IconData icon,
    required bool unlocked,
    required String progressText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: unlocked
            ? LinearGradient(
                colors: [
                  const Color(0xFF14B8A6).withOpacity(0.35),
                  const Color(0xFF0F766E).withOpacity(0.22),
                ],
              )
            : null,
        color: unlocked ? null : Colors.white.withOpacity(0.06),
        border: Border.all(
          color: unlocked
              ? const Color(0xFF5EEAD4).withOpacity(0.35)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(
            unlocked ? icon : Icons.lock_rounded,
            color: unlocked
                ? const Color(0xFF5EEAD4)
                : Colors.white.withOpacity(0.35),
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: unlocked ? Colors.white : Colors.white.withOpacity(0.48),
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progressText,
            style: TextStyle(
              color: unlocked
                  ? const Color(0xFFCCFBF1)
                  : Colors.white.withOpacity(0.40),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // Module 1

  Widget _moduleCard1({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String tag,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFA000), Color(0xFFFF6D00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFFF9800),
              blurRadius: 30,
              spreadRadius: 1,
              offset: Offset(0, 14),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(.25),
                    Colors.white.withOpacity(.08),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(.15)),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.4,
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.18),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.92),
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Real Exam Experience",
                        style: TextStyle(
                          color: Colors.white.withOpacity(.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.18),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color startColor,
    required Color endColor,
    required String tag,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              startColor.withOpacity(.26),
              endColor.withOpacity(.13),
              const Color(0xFF111827).withOpacity(.35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(.10)),
          boxShadow: [
            BoxShadow(
              color: startColor.withOpacity(.24),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(.20),
                        Colors.white.withOpacity(.07),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(.10)),
                    boxShadow: [
                      BoxShadow(
                        color: startColor.withOpacity(.20),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),

                const Spacer(),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.11),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(.10)),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Color(0xFFCCFBF1),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -.3,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(.72),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
               
                // Expanded(
                //   child: Container(
                //     height: 4,
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(20),
                //       color: Colors.white.withOpacity(.10),
                //     ),
                //     child: FractionallySizedBox(
                //       alignment: Alignment.centerLeft,
                //       widthFactor: .65,
                //       child: Container(
                //         decoration: BoxDecoration(
                //           borderRadius: BorderRadius.circular(20),
                //           gradient: LinearGradient(
                //             colors: [startColor, endColor],
                //           ),
                //         ),
                //       ),
                //     ),
                //   ),
                // ),

                const SizedBox(width: 12),

                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(.20),
                        Colors.white.withOpacity(.08),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withOpacity(.10)),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
