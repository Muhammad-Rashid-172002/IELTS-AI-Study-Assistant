import 'package:flutter/material.dart';
import 'package:fyproject/screens/Full_Mock_Test/test_runner.dart';
import 'package:fyproject/screens/pages/Listening_Practice/ListeningPractice.dart';
import 'package:fyproject/screens/pages/Reading_Practice/ReadingPractice.dart';
import 'package:fyproject/screens/pages/Speaking_Practice/SpeakingPractice.dart';
import 'package:fyproject/screens/pages/Writing_Checker/WritingChecker.dart';
import 'package:get/get.dart';
import 'package:fyproject/controller/feedback_controller/feedback_controller.dart';

class FullMockTest extends StatefulWidget {
  const FullMockTest({super.key});

  @override
  State<FullMockTest> createState() => _FullMockTestState();
}

class _FullMockTestState extends State<FullMockTest>
    with SingleTickerProviderStateMixin {
  final IELTSController ieltsController = Get.put(IELTSController());

  bool testStarted = false;

  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  // UI


  @override
  Widget build(BuildContext context) {
    final double headerHeight = 240;

    return Scaffold(
      backgroundColor: const Color(0xffeef1f7),
      body: Stack(
        children: [
          //  HEADER
          _topHeader(),

          //  CONTENT
          SingleChildScrollView(
            child: Column(
              children: [
                //  Space equal to header
                SizedBox(height: headerHeight - 60),

                // Main Card (Overlapping)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _mainCard(),
                ),

                const SizedBox(height: 20),

                //  Sections
                _sectionTile(
                  "Listening",
                  Icons.headphones,
                  "30 min • 40 Q",
                  Colors.blue,
                  onTap: () => Get.to(() => const ListeningPractice()),
                ),

                _sectionTile(
                  "Reading",
                  Icons.menu_book,
                  "15 min • 5 Q",
                  Colors.purple,
                  onTap: () => Get.to(() => const ReadingPractice()),
                ),

                _sectionTile(
                  "Writing",
                  Icons.edit,
                  "60 min • 2 Q",
                  Colors.pink,
                  onTap: () => Get.to(() => const WritingChecker()),
                ),

                _sectionTile(
                  "Speaking",
                  Icons.mic,
                  "15 min • 3 Q",
                  Colors.teal,
                  onTap: () => Get.to(() => const SpeakingPractice()),
                ),

                const SizedBox(height: 20),

                _startButton(),

                const SizedBox(height: 20),

                _beforeStartCard(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Widget mockTestScreen() {
  //   return Scaffold(
  //     backgroundColor: const Color(0xfff5f6fa),
  //     body: Stack(
  //       children: [
  //         //  Top Header
  //         _topHeader(),

  //         //  Card Section
  //         Positioned(
  //           top: 180, // overlap effect
  //           left: 20,
  //           right: 20,
  //           child: Container(
  //             padding: const EdgeInsets.all(20),
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(25),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.black12,
  //                   blurRadius: 10,
  //                   offset: Offset(0, 5),
  //                 ),
  //               ],
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 // Title Row
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: const [
  //                         Text(
  //                           "Academic IELTS",
  //                           style: TextStyle(
  //                             fontSize: 20,
  //                             fontWeight: FontWeight.bold,
  //                           ),
  //                         ),
  //                         SizedBox(height: 5),
  //                         Text(
  //                           "Practice Test #12",
  //                           style: TextStyle(color: Colors.grey),
  //                         ),
  //                       ],
  //                     ),
  //                     Column(
  //                       children: const [
  //                         Row(
  //                           children: [
  //                             Icon(Icons.access_time, size: 18),
  //                             SizedBox(width: 5),
  //                             Text("165 min"),
  //                           ],
  //                         ),
  //                         SizedBox(height: 5),
  //                         Text(
  //                           "Total Duration",
  //                           style: TextStyle(color: Colors.grey),
  //                         ),
  //                       ],
  //                     ),
  //                   ],
  //                 ),

  //                 const SizedBox(height: 20),

  //                 // Instructions Box
  //                 Container(
  //                   padding: const EdgeInsets.all(15),
  //                   decoration: BoxDecoration(
  //                     color: const Color(0xffeef1f5),
  //                     borderRadius: BorderRadius.circular(15),
  //                   ),
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: const [
  //                       Row(
  //                         children: [
  //                           Icon(Icons.description),
  //                           SizedBox(width: 8),
  //                           Text(
  //                             "Instructions",
  //                             style: TextStyle(fontWeight: FontWeight.bold),
  //                           ),
  //                         ],
  //                       ),
  //                       SizedBox(height: 10),

  //                       Text("• Complete all four sections in order"),
  //                       Text("• Time limit applies to each section"),
  //                       Text("• You can review answers before submitting"),
  //                       Text("• Results will be available immediately after"),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }


  //  HEADER

  Widget _topHeader() {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff4a00e0), Color(0xff8e2de2)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(width: 20),

              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Full Mock Test",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Complete IELTS Simulation",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.workspace_premium, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  //  PROGRESS CARD
  // =====================================================
  // Widget _progressCard() {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16),
  //     padding: const EdgeInsets.all(18),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(22),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Text(
  //           "Your Readiness",
  //           style: TextStyle(fontWeight: FontWeight.bold),
  //         ),
  //         const SizedBox(height: 10),

  //         ClipRRect(
  //           borderRadius: BorderRadius.circular(10),
  //           child: LinearProgressIndicator(
  //             value: 0.7,
  //             minHeight: 10,
  //             backgroundColor: Colors.grey[200],
  //             color: Colors.deepPurple,
  //           ),
  //         ),

  //         const SizedBox(height: 6),
  //         const Text("70% Ready - Keep practicing "),
  //       ],
  //     ),
  //   );
  // }


  //  MAIN CARD

  Widget _mainCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Academic IELTS",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                
                ],
              ),
          
            ],
          ),

          const SizedBox(height: 20),

          // Instructions
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xffeef1f5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description),
                    SizedBox(width: 8),
                    Text(
                      "Instructions",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text("• Complete all four sections in order"),
                Text("• Time limit applies to each section"),
                Text("• Review answers before submitting"),
                Text("• Results available instantly"),
              ],
            ),
          ),
        ],
      ),
    );
  } 

  //  SECTION TILE

  Widget _sectionTile(
    String title,
    IconData icon,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            Get.snackbar(title, "Section preview coming soon 🚀");
          },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // 🚀 START BUTTON (ANIMATED)
  // =====================================================
  Widget _startButton() {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: () {
          Get.to(() => const TestRunner());
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 65,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff4a00e0), Color(0xff8e2de2)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.4),
                blurRadius: 15,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              "Start Mock Test",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // 💡 TIPS CARD
  // =====================================================
  Widget _beforeStartCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffff3e0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.lightbulb, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Find a quiet space and ensure stable internet before starting.",
            ),
          ),
        ],
      ),
    );
  }
}
