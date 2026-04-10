import 'package:flutter/material.dart';
import 'package:fyproject/controller/feedback_controller/feedback_controller.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReadingPractice extends StatefulWidget {
  const ReadingPractice({super.key});

  @override
  State<ReadingPractice> createState() => _ReadingPracticeState();
}

class _ReadingPracticeState extends State<ReadingPractice> {
  final IELTSController ieltsController = Get.put(IELTSController());
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> questions = [];
  List<int?> selectedAnswers = [];

  bool generated = false;
  bool showResult = false;
  int score = 0;

  String passage = "";

  // =========================================================
  // GENERATE FULL AI READING TEST
  // =========================================================
  Future<void> generateAIReadingTest() async {
    ieltsController.isLoading.value = true;

    try {
      final prompt = """
Generate a complete IELTS Reading Practice Test.

Format exactly like this:

PASSAGE:
<write one short IELTS reading passage>

QUESTIONS:
1. Question text
A) Option A
B) Option B
C) Option C
D) Option D
ANSWER: A

2. Question text
A) Option A
B) Option B
C) Option C
D) Option D
ANSWER: B
""";

      final response =
          await ieltsController.api.feedback(prompt, "reading");

      parseAIResponse(response);

      generated = true;
      showResult = false;
      score = 0;

      setState(() {});

      // Store the generated test in Firebase
      await storeReadingTestToFirebase();
    } catch (e) {
      Get.snackbar("Error", "Failed to generate reading test");
    }

    ieltsController.isLoading.value = false;
  }

  // =========================================================
  // PARSE AI RESPONSE
  // =========================================================
  void parseAIResponse(String response) {
    questions.clear();
    selectedAnswers.clear();

    final parts = response.split("QUESTIONS:");

    if (parts.length < 2) {
      passage = "Failed to load passage.";
      return;
    }

    passage = parts[0].replaceFirst("PASSAGE:", "").trim();

    final questionText = parts[1].trim();

    final questionBlocks =
        questionText.split(RegExp(r'\n(?=\d+\.)'));

    for (var block in questionBlocks) {
      final lines = block.trim().split("\n");

      if (lines.length >= 6) {
        String question = lines[0];

        List<String> options = [
          lines[1].replaceFirst("A) ", ""),
          lines[2].replaceFirst("B) ", ""),
          lines[3].replaceFirst("C) ", ""),
          lines[4].replaceFirst("D) ", ""),
        ];

        String answerLine = lines[5];
        String correctAnswer =
            answerLine.replaceFirst("ANSWER:", "").trim();

        int correctIndex = ["A", "B", "C", "D"].indexOf(correctAnswer);

        questions.add({
          "question": question,
          "options": options,
          "correct": correctIndex,
        });

        selectedAnswers.add(null);
      }
    }
  }

  // =========================================================
  // SUBMIT ANSWERS
  // =========================================================
  void submitAnswers() async {
    score = 0;

    for (int i = 0; i < questions.length; i++) {
      if (selectedAnswers[i] == questions[i]["correct"]) {
        score++;
      }
    }

    setState(() {
      showResult = true;
    });

    // Store the user's answers and score in Firebase
    await storeUserAnswersToFirebase();
  }

  // =========================================================
  // STORE GENERATED TEST TO FIREBASE
  // =========================================================
  Future<void> storeReadingTestToFirebase() async {
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final testData = {
        "userId": user.uid,
        "passage": passage,
        "questions": questions,
        "timestamp": FieldValue.serverTimestamp(),
      };

      await firestore.collection("reading_tests").add(testData);
    } catch (e) {
      print("Error storing reading test: $e");
    }
  }

  // =========================================================
  // STORE USER ANSWERS TO FIREBASE
  // =========================================================
  Future<void> storeUserAnswersToFirebase() async {
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final answersData = {
        "userId": user.uid,
        "answers": selectedAnswers,
        "score": score,
        "timestamp": FieldValue.serverTimestamp(),
      };

      await firestore.collection("reading_test_answers").add(answersData);
    } catch (e) {
      print("Error storing user answers: $e");
    }
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _infoCard(),
            const SizedBox(height: 20),
            _generateButton(),
            const SizedBox(height: 20),

            if (generated) _readingPassage(),

            const SizedBox(height: 20),

            if (generated) _questionCard(),

            const SizedBox(height: 20),

            if (generated) _submitButton(),

            if (showResult) _resultCard(),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // APP BAR
  // =========================================================
  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          _roundButton(Icons.arrow_back, onTap: () => Get.back()),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4A79F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book,
                color: Color(0xFF4A79F6)),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "AI Reading Practice",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                "IELTS Reading Test",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INFO CARD
  // =========================================================
  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDDEBFF), Color(0xFFE9F3FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Colors.blue, width: 4),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline,
              color: Color(0xFF4A79F6)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "AI will generate IELTS passage with dynamic MCQs automatically.",
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // GENERATE BUTTON
  // =========================================================
  Widget _generateButton() {
    return Obx(() {
      return Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A79F6), Color(0xFF8FB2FF)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextButton.icon(
          onPressed: ieltsController.isLoading.value
              ? null
              : generateAIReadingTest,
          icon: const Icon(Icons.auto_awesome,
              color: Colors.white),
          label: Text(
            ieltsController.isLoading.value
                ? "Generating..."
                : "Generate AI Reading Test",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }

  // =========================================================
  // PASSAGE
  // =========================================================
  Widget _readingPassage() {
    return Obx(() {
      if (ieltsController.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator());
      }

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "AI Reading Passage",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              passage,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    });
  }

  // =========================================================
  // QUESTIONS
  // =========================================================
  Widget _questionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Questions",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          ...List.generate(questions.length, (index) {
            final q = questions[index];

            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  q["question"],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                ...List.generate(
                  q["options"].length,
                  (optIndex) {
                    return RadioListTile<int>(
                      title:
                          Text(q["options"][optIndex]),
                      value: optIndex,
                      groupValue:
                          selectedAnswers[index],
                      onChanged: (value) {
                        setState(() {
                          selectedAnswers[index] =
                              value;
                        });
                      },
                    );
                  },
                ),

                const SizedBox(height: 14),
              ],
            );
          }),
        ],
      ),
    );
  }

  // =========================================================
  // SUBMIT BUTTON
  // =========================================================
  Widget _submitButton() {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A79F6), Color(0xFF8FB2FF)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextButton(
        onPressed: submitAnswers,
        child: const Text(
          "Submit Answers",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // RESULT CARD
  // =========================================================
  Widget _resultCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Text(
            "Your Score",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "$score / ${questions.length}",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A79F6),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // COMMON UI
  // =========================================================
  Widget _roundButton(IconData icon,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: Colors.black87),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}