import 'package:flutter/material.dart';
import 'package:fyproject/resources/bottom_navigation_bar/botton_navigation.dart';
import 'package:fyproject/screens/Full_Mock_Test/Full_mock_test.dart';
import 'package:fyproject/screens/Vocabulary_Builder/VocabularyBuilder.dart';
import 'package:fyproject/screens/pages/Reading_Practice/ReadingPractice.dart';
import 'package:fyproject/screens/pages/Listening_Practice/ListeningPractice.dart';
import 'package:fyproject/screens/pages/Writing_Checker/WritingChecker.dart';
import 'package:fyproject/screens/pages/Speaking_Practice/SpeakingPractice.dart';
import 'package:fyproject/screens/widgets/add_fire_pulse/fire_animation.dart';
import 'package:get/get.dart';

import '../../../controller/firebase_services/firebase_services.dart';


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
              /// ================= GRID (2 per row) =================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _moduleCard(
                            title: "Listening",
                            subtitle: "Audio practice",
                            color: const Color(0xFF4A79F6),
                            tag: "IELTS",
                            icon: Icons.headphones,
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
                            subtitle: "Passage practice",
                            color: const Color(0xFF2ECC9A),
                            tag: "IELTS",
                            icon: Icons.menu_book,
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
                            subtitle: "AI feedback",
                            color: const Color(0xFF8E44FF),
                            tag: "AI",
                            icon: Icons.edit_note,
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
                            subtitle: "AI speaking",
                            color: const Color(0xFFFFA726),
                            tag: "AI",
                            icon: Icons.mic,
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

                    Row(
                      children: [
                        Expanded(
                          child: _moduleCard(
                            title: "Vocabulary",
                            subtitle: "Word builder",
                            color: const Color(0xFF26A69A),
                            tag: "Vocab",
                            icon: Icons.translate,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const Vocabularybuilder(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    SizedBox(height: 12),
                    _moduleCard1(
                      title: "Full Mock Test",
                      subtitle: "Take a full IELTS test simulation with timer",
                      color: Colors.black, // 🔥 full black card
                      tag: "Exam Mode",
                      icon: Icons.assignment,
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
          colors: [Color(0xff4A00E0), Color(0xff8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TOP ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "IELTS Master",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
          
            ],
          ),

          const SizedBox(height: 20),

          /// USER INFO
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                backgroundImage: (userPhoto != null && userPhoto.isNotEmpty)
                    ? NetworkImage(userPhoto)
                    : null,
                child: (userPhoto == null || userPhoto.isEmpty)
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome back 👋",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    userName ?? "User",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// 🔥 GLASS STREAK CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Study Streak",
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "$streak Days 🔥",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              FirePulseIcon(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //
  Widget _moduleCard1({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String tag,
    required VoidCallback onTap,
  }) {
    final bool isDark =
        color == Colors.black || color == const Color(0xFF1C1C1E);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12), // 🔥 size kam kiya
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? color : Colors.white, // 🔥 full black card
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ICON
            Container(
              padding: const EdgeInsets.all(10), // 🔥 small
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDark ? Colors.white : color,
                size: 20, // 🔥 small icon
              ),
            ),

            const SizedBox(height: 10),

            /// TITLE
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14, // 🔥 small text
                color: isDark ? Colors.white : Colors.black,
              ),
            ),

            const SizedBox(height: 4),

            /// SUBTITLE
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ),

            const SizedBox(height: 10),

            /// BUTTON
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                Icons.arrow_forward,
                size: 18,
                color: isDark ? Colors.white : color,
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
    required Color color,
    required String tag,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ICON
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),

            const SizedBox(height: 12),

            /// TITLE
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const SizedBox(height: 4),

            /// SUBTITLE
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 12),

            /// BUTTON
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(Icons.arrow_forward, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
