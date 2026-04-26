import 'package:flutter/material.dart';
import 'package:fyproject/services/ai_service.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WritingChecker extends StatefulWidget {
  const WritingChecker({super.key});

  @override
  State<WritingChecker> createState() => _WritingCheckerState();
}

class _WritingCheckerState extends State<WritingChecker> {
  final TextEditingController _essayController = TextEditingController();
  final AIService ai = AIService();

  String topic = "";
  bool isTopicLoading = true;

  String bandScore = "";
  String taskResponse = "";
  String coherence = "";
  String lexical = "";
  String grammar = "";
  String improvement = "";

  bool isLoading = false;
  int wordCount = 0;

  @override
  void initState() {
    super.initState();

    _essayController.addListener(() {
      final words = _essayController.text.trim().split(RegExp(r'\s+'));
      setState(() {
        wordCount = _essayController.text.trim().isEmpty ? 0 : words.length;
      });
    });

    loadTopic();
  }

  // 🔥 AI TOPIC
  Future<void> loadTopic() async {
    try {
      final t = await ai.generateWritingTopic("2");

      setState(() {
        topic = t;
        isTopicLoading = false;
      });
    } catch (e) {
      setState(() {
        topic = "Failed to load topic";
        isTopicLoading = false;
      });
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF4F7FB),
    body: Stack(
      children: [
        Column(
          children: [
            _topHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _topicCard(),
                    const SizedBox(height: 16),
                    _essayInput(),
                    const SizedBox(height: 16),
                    _checkButton(),
                    const SizedBox(height: 20),
                    if (bandScore.isNotEmpty) _resultSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (isLoading) _loadingOverlay(),
      ],
    ),
  );
}
//====== top header
Widget _topHeader() {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFF2D8D), Color(0xFFD0005B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Get.back(),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "Writing",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text("Essay Writing",
            style: TextStyle(color: Colors.white70)),

        const SizedBox(height: 20),

        Row(
          children: [
            _infoCard("Time Left", "35:20", Icons.access_time),
            const SizedBox(width: 10),
            _infoCard("Word Count", "$wordCount / 250", Icons.description),
          ],
        )
      ],
    ),
  );
}
Widget _infoCard(String title, String value, IconData icon) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    ),
  );
}

  // ---------------- TOPIC ----------------
Widget _topicCard() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF4EDE4),
      borderRadius: BorderRadius.circular(16),
      border: Border(
        left: BorderSide(color: Colors.orange, width: 4),
      ),
    ),
    child: isTopicLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("💡 Task Prompt",
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Text(topic),
              const SizedBox(height: 10),
              const Text("Write at least 250 words",
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
  );
}

  // ---------------- INPUT ----------------
Widget _essayInput() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: _card(),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Your Essay",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text("$wordCount words"),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _essayController,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: "Start writing here...",
            filled: true,
            fillColor: const Color(0xFFF7F9FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );
}
  // ---------------- BUTTON ----------------
Widget _checkButton() {
  return SizedBox(
    width: double.infinity,
    height: 55,
    child: ElevatedButton(
      onPressed: isLoading ? null : _checkEssay,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: EdgeInsets.zero,
      ),
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF2D8D), Color(0xFFFF004D)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        child: const Center(
          child: Text("Submit Essay",
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    ),
  );
}
  // ---------------- LOADING ----------------
  Widget _loadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  // ---------------- AI + FIREBASE ----------------
  Future<void> _checkEssay() async {
    if (_essayController.text.trim().isEmpty) {
      Get.snackbar("Error", "Write essay first");
      return;
    }

    if (wordCount < 250) {
      Get.snackbar("Too Short", "Minimum 250 words required");
      return;
    }

    setState(() => isLoading = true);

    try {
      final result =
          await ai.evaluateWriting(_essayController.text, "2");

      bandScore = result["band"] ?? "0";
      taskResponse = result["task_response"] ?? "";
      coherence = result["coherence"] ?? "";
      lexical = result["lexical"] ?? "";
      grammar = result["grammar"] ?? "";
      improvement = result["improvement"] ?? "";

      await _saveToFirebase();

      setState(() {});
    } catch (e) {
      Get.snackbar("Error", "AI failed");
    }

    setState(() => isLoading = false);
  }

  // ---------------- FIREBASE ----------------
  Future<void> _saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("writing_results")
        .add({
      "topic": topic,
      "essay": _essayController.text,
      "band": bandScore,
      "task_response": taskResponse,
      "coherence": coherence,
      "lexical": lexical,
      "grammar": grammar,
      "improvement": improvement,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // ---------------- RESULT ----------------
  Widget _resultSection() {
    return Column(
      children: [
        _bandCard(),
        const SizedBox(height: 16),
        _detailCard("Task Response", taskResponse),
        _detailCard("Coherence & Cohesion", coherence),
        _detailCard("Lexical Resource", lexical),
        _detailCard("Grammar", grammar),
        const SizedBox(height: 10),
        _detailCard("Improvement", improvement),
      ],
    );
  }

  Widget _bandCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text("Overall Band Score",
              style: TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          Text(
            bandScore,
            style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  BoxDecoration _card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10)
      ],
    );
  }
}