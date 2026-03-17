import 'package:flutter/material.dart';
import 'package:fyproject/resources/bottom_navigation_bar/botton_navigation.dart';
import 'package:fyproject/resources/routes/routes_names.dart';
import 'package:fyproject/screens/Full_Mock_Test/Full_mock_test.dart';
import 'package:fyproject/screens/Vocabulary_Builder/VocabularyBuilder.dart';
import 'package:fyproject/screens/pages/Reading_Practice/ReadingPractice.dart';
import 'package:fyproject/screens/pages/Listening_Practice/ListeningPractice.dart';
import 'package:fyproject/screens/pages/Writing_Checker/WritingChecker.dart';
import 'package:fyproject/screens/pages/Speaking_Practice/SpeakingPractice.dart';
import 'package:get/get.dart';

import '../../../controller/firebase_services/firebase_services.dart';
import '../../widgets/add_fire_pulse/fire_animation.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  void initState() {
    super.initState();
    final services = Get.find<FirebaseServices>();
    services.loadUserProfile(); // ensure listener starts
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      bottomNavigationBar: const BottomNavigation(index: 0),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =====================================================
              //                     HEADER SECTION
              // =====================================================
              _buildHeader(),

              const SizedBox(height: 20),

              // =====================================================
              //                     STUDY MODULES TEXT
              // =====================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Study Modules",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Choose a tool to enhance your learning",
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // =====================================================
              //                     MODULE CARDS
              // =====================================================
              _moduleCard(
                title: "Listening Practice",
                subtitle:
                    "Improve your listening skills with real IELTS audio tests",
                color: const Color(0xFF4A79F6),
                tag: "IELTS Skill",
                icon: Icons.headphones,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ListeningPractice()));
                },
              ),

              _moduleCard(
                title: "Reading Practice",
                subtitle:
                    "Practice academic reading passages with IELTS style questions",
                color: const Color(0xFF2ECC9A),
                tag: "IELTS Skill",
                icon: Icons.menu_book,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ReadingPractice()));
                },
              ),

              _moduleCard(
                title: "Writing Tasks",
                subtitle:
                    "Practice IELTS Writing Task 1 and Task 2 with AI feedback",
                color: const Color(0xFF8E44FF),
                tag: "AI Feedback",
                icon: Icons.edit_note,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const WritingChecker()));
                },
              ),

              _moduleCard(
                title: "Speaking Practice",
                subtitle:
                    "Practice speaking questions and get AI pronunciation feedback",
                color: const Color(0xFFFFA726),
                tag: "AI Speaking",
                icon: Icons.mic,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SpeakingPractice()));
                },
              ),

              _moduleCard(
                title: "Vocabulary Builder",
                subtitle: "Learn high band IELTS vocabulary with examples",
                color: const Color(0xFF26A69A),
                tag: "Vocabulary",
                icon: Icons.translate,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const Vocabularybuilder()));
                },
              ),

              _moduleCard(
                title: "Full Mock Test",
                subtitle: "Take a full IELTS test simulation with timer",
                color: const Color(0xFFE74C3C),
                tag: "Exam Mode",
                icon: Icons.assignment,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const FullMockTest()));
                },
              ),
              const SizedBox(height: 20),

            
              
              
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  //                     HEADER WIDGET
  // =====================================================
  Widget _buildHeader() {
    final FirebaseServices services = Get.find<FirebaseServices>();
    final data = services.userData;

    final int streak = data['streak'] ?? 1;

    final String? userName = data['name'];
    final String? userPhoto = data['profileImage'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A79F6), Color(0xFF5AA9FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + Notification
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Small logo box
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_stories,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "IELTS Master",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Your IELTS Preparation App",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),

              // Bell icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          Row(
            children: [
              // PROFILE IMAGE
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[300],

                backgroundImage: (userPhoto != null && userPhoto.isNotEmpty)
                    ? NetworkImage(userPhoto)
                    : null,

                child: (userPhoto == null || userPhoto.isEmpty)
                    ? Icon(Icons.person, size: 32, color: Colors.grey[700])
                    : null,
              ),

              const SizedBox(width: 14),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome back,",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    userName ?? "User",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Streak box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(18),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Study Streak",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      "$streak Days", // ⭐ Dynamic streak value
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const FirePulseIcon(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moduleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String tag,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),

        // 🔥 LEFT BORDER EXACT LIKE SCREENSHOT
        border: Border(left: BorderSide(color: color, width: 4)),

        // Soft shadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TAG BADGE
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ICON + TITLE ROW
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF717E98),
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            // START BUTTON (PILL)
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        "Start",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: const Color(0xFF4A79F6)),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

}