import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/Listening_Practice/ListeningPractice.dart';
import 'package:fyproject/screens/pages/Reading_Practice/ReadingPractice.dart';
import 'package:fyproject/screens/pages/Speaking_Practice/SpeakingPractice.dart';
import 'package:fyproject/screens/pages/Writing_Checker/WritingChecker.dart';
import 'package:fyproject/screens/pages/progress/progress.dart';
import 'package:fyproject/screens/widgets/botton/round_botton.dart';
import 'package:get/get.dart';

class TestRunner extends StatefulWidget {
  const TestRunner({super.key});

  @override
  State<TestRunner> createState() => _TestRunnerState();
}

class _TestRunnerState extends State<TestRunner> {
  int currentSection = 0;

  final List<Widget> sections = const [
    ListeningPractice(),
    ReadingPractice(),
    WritingChecker(),
    SpeakingPractice(),
  ];

  final List<String> titles = ["Listening", "Reading", "Writing", "Speaking"];

  final List<IconData> icons = [
    Icons.headphones_rounded,
    Icons.menu_book_rounded,
    Icons.edit_note_rounded,
    Icons.mic_rounded,
  ];

  void nextSection() {
    if (currentSection < sections.length - 1) {
      setState(() => currentSection++);
    } else {
      Get.off(() => const ProgressScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
   

    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF08111F),
                  Color(0xFF102A43),
                  Color(0xFF0F766E),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Get.back(),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Full Mock Test",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${titles[currentSection]} Section",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        icons[currentSection],
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: List.generate(sections.length, (index) {
                    final selected = index <= currentSection;

                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: index == sections.length - 1 ? 0 : 8,
                        ),
                        height: 8,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF2DD4BF)
                              : Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Step ${currentSection + 1} of ${sections.length}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: sections[currentSection],
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            decoration: BoxDecoration(
              color: const Color(0xFF08111F),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: RoundButton(
              onPress: nextSection,
              title: currentSection == sections.length - 1
                  ? "Finish Test"
                  : "Next Section",
              isLoading: false,
            ),
          ),
        ],
      ),
    );
  }
}
