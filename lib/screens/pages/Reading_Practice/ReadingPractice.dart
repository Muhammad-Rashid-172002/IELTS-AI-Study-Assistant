import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/services/ai_service.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // ================= GENERATE =================
  Future<void> generateAIReadingTest() async {
    setState(() {
      isLoading = true;
      generated = false;
      showResult = false;
      score = 0;
    });

    try {
      final data = await ai.generateReadingTest();

      passage = data["passage"] ?? "";
      questions = data["questions"] ?? [];
      selectedAnswers = List.generate(questions.length, (_) => null);

      generated = true;
    } catch (e) {
      Get.snackbar("Error", "AI failed");
    }

    setState(() => isLoading = false);
  }

  // ================= SAVE TO FIREBASE =================
  Future<void> saveResultToFirebase() async {
    try {
      final user = auth.currentUser;

      if (user == null) {
        Get.snackbar("Error", "User not logged in");
        return;
      }

      final userRef = firestore.collection("users").doc(user.uid);

      final percentage = questions.isEmpty
          ? 0
          : ((score / questions.length) * 100).round();

      // 1️⃣ Save detailed result (history)
      await userRef.collection("reading_results").add({
        "score": score,
        "total": questions.length,
        "percentage": percentage,
        "timestamp": FieldValue.serverTimestamp(),
      });

      // 2️⃣ Update reading_progress (LIKE listening_progress)
      await userRef.set({
        "reading_progress": {
          "createdAt": FieldValue.serverTimestamp(),
          "lastActive": DateTime.now().toIso8601String(),
          "lastReset": DateTime.now().toIso8601String(),

          "progress": {
            "questions": FieldValue.increment(questions.length),
            "solved": FieldValue.increment(1),
            "streak": FieldValue.increment(1),
          },
        },
      }, SetOptions(merge: true));
      Get.snackbar("Success", "Reading progress updated");
    } catch (e) {
      Get.snackbar("Error", "Failed to save result");
    }
  }

  void submitAnswers() async {
    score = 0;

    for (int i = 0; i < questions.length; i++) {
      if (selectedAnswers[i] == questions[i]["answer"]) {
        score++;
      }
    }

    setState(() => showResult = true);

    // 🔥 Save after submit
    await saveResultToFirebase();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _appBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoCard(),
            const SizedBox(height: 16),
            _generateButton(),
            const SizedBox(height: 20),
            if (isLoading) _loading(),
            if (generated) _passageCard(),
            const SizedBox(height: 16),
            if (generated) _questions(),
            const SizedBox(height: 16),
            if (generated) _submitButton(),
            if (showResult) _resultCard(),
          ],
        ),
      ),
    );
  }

  AppBar _appBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: const Text(
        "AI Reading Practice",
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.black),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A79F6), Color(0xFF7FA6FF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Generate AI-based IELTS reading test instantly.",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _generateButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A79F6), Color(0xFF8FB2FF)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextButton.icon(
        onPressed: isLoading ? null : generateAIReadingTest,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          isLoading ? "Generating..." : "Generate Reading Test",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _loading() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: CircularProgressIndicator(),
    );
  }

  Widget _passageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book, color: Color(0xFF4A79F6)),
              SizedBox(width: 8),
              Text(
                "Reading Passage",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(passage, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  Widget _questions() {
    return Column(
      children: List.generate(questions.length, (i) {
        final q = questions[i];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: _card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Q${i + 1}. ${q["question"]}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              ...List.generate(4, (opt) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedAnswers[i] == opt
                          ? const Color(0xFF4A79F6)
                          : Colors.black12,
                    ),
                  ),
                  child: RadioListTile(
                    value: opt,
                    groupValue: selectedAnswers[i],
                    onChanged: (val) {
                      setState(() {
                        selectedAnswers[i] = val as int;
                      });
                    },
                    title: Text(q["options"][opt]),
                  ),
                );
              }),
            ],
          ),
        );
      }),
    );
  }

  Widget _submitButton() {
    return Container(
      width: double.infinity,
      height: 52,
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _resultCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: Column(
        children: [
          const Text(
            "Your Score",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF4A79F6),
            child: Text(
              "$score",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "$score / ${questions.length}",
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  BoxDecoration _card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.05)),
      ],
    );
  }
}
