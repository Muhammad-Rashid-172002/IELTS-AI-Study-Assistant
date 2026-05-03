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

  final List<Widget> sections = [
  //  const ListeningPractice(),
    const ReadingPractice(),
    const WritingChecker(),
  //  const SpeakingPractice(),
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
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (currentSection + 1) / sections.length,
          ),
          Expanded(child: sections[currentSection]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: RoundButton(
              onPress: nextSection,
              title: currentSection == 3 ? "Finish Test" : "Next Section",
            ),
          )
        ],
      ),
    );
  }
}