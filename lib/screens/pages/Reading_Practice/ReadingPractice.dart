import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyproject/services/ai_service.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReadingPractice extends StatefulWidget {
  const ReadingPractice({super.key});

  @override
  State<ReadingPractice> createState() => _ReadingPracticeState();
}

class _ReadingPracticeState extends State<ReadingPractice> {
  final AIService ai = AIService();

  List questions = [];
  List<int?> selectedAnswers = [];

  String passage = "";

  bool isLoading = false;
  bool generated = false;
  bool showResult = false;

  int score = 0;

  // ⏱ TIMER
  int totalSeconds = 900; // 15 min
  Timer? timer;

  int currentQuestion = 0;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // ================= GENERATE =================
  Future<void> generateAIReadingTest() async {
    setState(() {
      isLoading = true;
      generated = false;
      showResult = false;
      score = 0;
      totalSeconds = 900;
    });

    try {
      final data = await ai.generateReadingTest();

      passage = data["passage"];
      questions = data["questions"];
      selectedAnswers = List.generate(questions.length, (_) => null);

      startTimer();

      generated = true;
    } catch (e) {
      Get.snackbar("Error", "AI failed");
    }

    setState(() => isLoading = false);
  }

  // ================= TIMER =================
  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (totalSeconds == 0) {
        t.cancel();
        submitAnswers();
      } else {
        setState(() => totalSeconds--);
      }
    });
  }

  String get timeFormatted {
    int min = totalSeconds ~/ 60;
    int sec = totalSeconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  // ================= SUBMIT =================
  void submitAnswers() async {
    timer?.cancel();

    score = 0;
    for (int i = 0; i < questions.length; i++) {
      if (selectedAnswers[i] == questions[i]["answer"]) {
        score++;
      }
    }

    setState(() => showResult = true);

    await saveResultToFirebase();
  }

  // ================= FIREBASE =================
Future<void> saveResultToFirebase() async {
  final user = auth.currentUser;

  if (user == null) {
    print("❌ No user logged in");
    return;
  }

  print("👤 User ID: ${user.uid}");
  print("📊 Score: $score");
  print("📊 Total Questions: ${questions.length}");
  print("📖 Passage: $passage");
  print("❓ Questions: $questions");
  print("✅ Selected Answers: $selectedAnswers");

  try {
    final docRef = await firestore
        .collection("users")
        .doc(user.uid)
        .collection("reading_results")
        .add({
      "score": score,
      "total": questions.length,
      "passage": passage,
      "questions": questions,
      "answers": selectedAnswers,
      "timestamp": FieldValue.serverTimestamp(),
    });

    print("✅ Data saved successfully!");
    print("📄 Document ID: ${docRef.id}");
  } catch (e) {
    print("❌ Error saving to Firebase: $e");
  }
  final data = {
  "score": score,
  "total": questions.length,
  "passage": passage,
  "questions": questions,
  "answers": selectedAnswers,
};

print("📦 FULL DATA: $data");
}
  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : generated
                      ? _body()
                      : _generateButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7B1FA2), Color(0xFFE040FB)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Reading Practice",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  Text("Academic Reading - Passage 1",
                      style: TextStyle(color: Colors.white70)),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(timeFormatted,
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
                Text(
                  "Q ${currentQuestion + 1}/${questions.length}",
                  style: const TextStyle(color: Colors.white),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // ================= BODY =================
  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _passageCard(),
          const SizedBox(height: 20),
          _questionCard(),
          const SizedBox(height: 20),
          _submitButton(),
          if (showResult) _resultCard()
        ],
      ),
    );
  }

  // ================= PASSAGE =================
  Widget _passageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("📖 Passage",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(passage, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  // ================= QUESTION =================
  Widget _questionCard() {
    final q = questions[currentQuestion];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Q${currentQuestion + 1}. ${q["question"]}",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          ...List.generate(4, (i) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedAnswers[currentQuestion] = i;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedAnswers[currentQuestion] == i
                        ? Colors.purple
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedAnswers[currentQuestion] == i
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(q["options"][i]))
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentQuestion > 0)
                TextButton(
                    onPressed: () =>
                        setState(() => currentQuestion--),
                    child: const Text("Previous")),
              if (currentQuestion < questions.length - 1)
                TextButton(
                    onPressed: () =>
                        setState(() => currentQuestion++),
                    child: const Text("Next")),
            ],
          )
        ],
      ),
    );
  }

  // ================= SUBMIT =================
  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: submitAnswers,
        child: const Text("Submit"),
      ),
    );
  }

  // ================= RESULT =================
  Widget _resultCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        children: [
          const Text("Result",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("$score / ${questions.length}",
              style: const TextStyle(fontSize: 22)),
        ],
      ),
    );
  }

  // ================= GENERATE BUTTON =================
Widget _generateButton() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
    child: Center(
      child: GestureDetector(
        onTap: generateAIReadingTest,
        child: Container(
          height: 55,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B1FA2), Color(0xFFE040FB)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B1FA2).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "Start AI Reading Test",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}  // ================= CARD =================
  BoxDecoration _card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            blurRadius: 10, color: Colors.black.withOpacity(0.05)),
      ],
    );
  }
}