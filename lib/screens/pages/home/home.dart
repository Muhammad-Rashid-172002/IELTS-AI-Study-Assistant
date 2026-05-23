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
  @override
  void initState() {
    super.initState();
    final services = Get.find<FirebaseServices>();
    services.loadUserProfile();
    StreakService.updateUserStreak();
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

              const SizedBox(height: 20),

              //                     STUDY MODULES TEXT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Study Modules",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Boost your IELTS band score with AI powered tools",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.60),
                        height: 1.5,
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
                            subtitle: "AI listening",

                            tag: "AI",
                            icon: Icons.mic,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ListeningPractice(),
                                ),
                              );
                            },
                            startColor: Color(0xff2F6BFF),
                            endColor: Color(0xff7B2CFF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _moduleCard(
                            title: "Reading",
                            subtitle: "Passage practice",

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
                            startColor: Color(0xFF7B1FA2),
                            endColor: Color(0xFFC2185B),
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
                            subtitle: "AI writing checker",

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
                            startColor: Color(0xFFFF2D8D),
                            endColor: Color(0xFFD0005B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _moduleCard(
                            title: "Speaking",
                            subtitle: "AI speaking",
                            startColor: Color(0xFF14B8A6),
                            endColor: Color(0xFF0F766E),
                            tag: "AI",
                            icon: Icons.mic,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SpeakingPractice(),
                                ),
                              );
                              // Get.snackbar(
                              //   "Coming Soon ",
                              //   "This feature will be available soon",
                              //   snackPosition: SnackPosition.TOP,
                              //   backgroundColor: Colors.black87,
                              //   colorText: Colors.white,
                              //   margin: const EdgeInsets.all(10),
                              //   borderRadius: 10,
                              //   duration: const Duration(seconds: 2),
                              // );
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
                      subtitle: "Take a full IELTS test simulation with timer",
                      color: Colors.black,
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
  //                     HEADER WIDGET

  Widget _buildHeader() {
    final FirebaseServices services = Get.find<FirebaseServices>();
    final data = services.userData;

    final int streak = data['streak'] ?? 0;
    final String? userName = data['name'];
    final String? userPhoto = data['profileImage'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
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
          /// TOP BAR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "IELTS AI Master",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "AI Powered IELTS Preparation",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

          
            ],
          ),

          const SizedBox(height: 28),

          /// USER CARD
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),

            child: Row(
              children: [
                CircleAvatar(
                  radius: 31,
                  backgroundColor: Colors.white,
                  backgroundImage: (userPhoto != null && userPhoto.isNotEmpty)
                      ? NetworkImage(userPhoto)
                      : null,
                  child: (userPhoto == null || userPhoto.isEmpty)
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome Back 👋",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        userName ?? "IELTS Student",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          /// STREAK CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF14B8A6).withOpacity(0.30),
                  const Color(0xFF0F766E).withOpacity(0.18),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Study Streak",
                      style: TextStyle(color: Colors.white.withOpacity(0.65)),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "$streak Days",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFF111827), Color(0xFF1F2937)],
          ),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.assignment,
                color: Colors.white,
                size: 28,
              ),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 18,
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
            colors: [startColor.withOpacity(0.18), endColor.withOpacity(0.10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),

          border: Border.all(color: Colors.white.withOpacity(0.08)),

          boxShadow: [
            BoxShadow(
              color: startColor.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.68),
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.bottomRight,
              child: Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
