import 'package:flutter/material.dart';
import 'package:fyproject/controller/feedback_controller/feedback_controller.dart';
import 'package:get/get.dart';


class FullMockTest extends StatefulWidget {
  const FullMockTest({super.key});

  @override
  State<FullMockTest> createState() => _FullMockTestState();
}

class _FullMockTestState extends State<FullMockTest> {
  final IELTSController ieltsController = Get.put(IELTSController());

  final TextEditingController answerController = TextEditingController();

  int questionIndex = 0;
  bool testStarted = false;
  bool testSubmitted = false;

  List<String> questions = [];
  List<String> userAnswers = [];

  // =====================================================
  // GENERATE FULL AI MOCK TEST QUESTIONS
  // =====================================================
  Future<void> generateMockTestQuestions() async {
    ieltsController.isLoading.value = true;

    try {
      final prompt = """
Generate a full IELTS mock test with 4 questions:
1 Writing question
1 Speaking question
1 Reading analytical question
1 Listening analytical question

Format:
1. Question text
2. Question text
3. Question text
4. Question text
""";

      final response =
          await ieltsController.api.feedback(prompt, "mocktest");

      parseQuestions(response);

      setState(() {
        testStarted = true;
        questionIndex = 0;
        testSubmitted = false;
      });
    } catch (e) {
      Get.snackbar("Error", "Failed to generate mock test");
    }

    ieltsController.isLoading.value = false;
  }

  // =====================================================
  // PARSE QUESTIONS
  // =====================================================
  void parseQuestions(String response) {
    questions.clear();
    userAnswers.clear();

    final lines = response.split("\n");

    for (var line in lines) {
      if (line.trim().isNotEmpty &&
          RegExp(r'^\d+\.').hasMatch(line.trim())) {
        questions.add(line.trim());
      }
    }

    userAnswers = List.generate(questions.length, (_) => "");
  }

  // =====================================================
  // NEXT QUESTION
  // =====================================================
  void nextQuestion() {
    userAnswers[questionIndex] = answerController.text.trim();

    if (questionIndex < questions.length - 1) {
      setState(() {
        questionIndex++;
        answerController.text = userAnswers[questionIndex];
      });
    } else {
      submitFullTest();
    }
  }

  // =====================================================
  // SUBMIT FULL TEST TO AI
  // =====================================================
  Future<void> submitFullTest() async {
    ieltsController.isLoading.value = true;

    try {
      String compiledAnswers = "";

      for (int i = 0; i < questions.length; i++) {
        compiledAnswers += """
${questions[i]}
Answer: ${userAnswers[i]}

""";
      }

      final prompt = """
You are an IELTS examiner.

Evaluate this full IELTS mock test.

Give:
- Estimated Band Score
- Writing Feedback
- Speaking Feedback
- Reading Feedback
- Listening Feedback
- Improvement Suggestions

Answers:
$compiledAnswers
""";

      final result =
          await ieltsController.api.feedback(prompt, "mocktest");

      ieltsController.bandScore.value = result;

      setState(() {
        testSubmitted = true;
      });
    } catch (e) {
      Get.snackbar("Error", "Failed to evaluate mock test");
    }

    ieltsController.isLoading.value = false;
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _appBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoBanner(),
              const SizedBox(height: 20),

              if (!testStarted) _startTestButton(),

              if (testStarted) _questionCard(),

              const SizedBox(height: 20),

              if (testStarted && !testSubmitted) _answerBox(),

              const SizedBox(height: 20),

              if (testStarted && !testSubmitted) _nextButton(),

              const SizedBox(height: 20),

              _aiResult(),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // APP BAR
  // =====================================================
  AppBar _appBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 72,
      title: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.black87),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.quiz,
                color: Colors.orange),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "AI Full Mock Test",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
              Text(
                "Simulate real IELTS exam",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54),
              ),
            ],
          )
        ],
      ),
    );
  }

  // =====================================================
  // INFO BANNER
  // =====================================================
  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF3E0),
            Color(0xFFFFF8ED)
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(
              color: Colors.orange, width: 4),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline,
              color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Take a full IELTS style mock test. AI will generate questions and evaluate your band score.",
              style:
                  TextStyle(fontSize: 14, height: 1.4),
            ),
          )
        ],
      ),
    );
  }

  // =====================================================
  // START BUTTON
  // =====================================================
  Widget _startTestButton() {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF9800),
            Color(0xFFFFC107)
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextButton(
        onPressed: generateMockTestQuestions,
        child: const Text(
          "Start AI Mock Test",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // =====================================================
  // QUESTION CARD
  // =====================================================
  Widget _questionCard() {
    return Obx(() {
      if (ieltsController.isLoading.value &&
          questions.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _card(),
        child: Text(
          questions[questionIndex],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    });
  }

  // =====================================================
  // ANSWER BOX
  // =====================================================
  Widget _answerBox() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: TextField(
        controller: answerController,
        maxLines: 6,
        decoration: const InputDecoration(
          hintText: "Write your answer here...",
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  // =====================================================
  // NEXT BUTTON
  // =====================================================
  Widget _nextButton() {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF9800),
            Color(0xFFFFC107)
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextButton(
        onPressed: nextQuestion,
        child: Text(
          questionIndex == questions.length - 1
              ? "Submit Test"
              : "Next Question",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // =====================================================
  // AI RESULT
  // =====================================================
  Widget _aiResult() {
    return Obx(() {
      if (ieltsController.bandScore.value.isEmpty) {
        return const SizedBox();
      }

      if (ieltsController.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _card(),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "AI Test Result",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ieltsController.bandScore.value,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            )
          ],
        ),
      );
    });
  }

  // =====================================================
  // CARD STYLE
  // =====================================================
  BoxDecoration _card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )
      ],
    );
  }
}