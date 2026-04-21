import 'package:flutter/material.dart';
import 'package:fyproject/services/ai_service.dart';
import 'package:get/get.dart';


class WritingChecker extends StatefulWidget {
  const WritingChecker({super.key});

  @override
  State<WritingChecker> createState() => _WritingCheckerState();
}

class _WritingCheckerState extends State<WritingChecker> {
  final TextEditingController _essayController = TextEditingController();

  final AIService ai = AIService();

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _appBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _infoBanner(),
            const SizedBox(height: 20),
            _essayInput(),
            const SizedBox(height: 20),
            _quickTips(),
            const SizedBox(height: 20),
            _checkButton(),
            const SizedBox(height: 24),
            if (bandScore.isNotEmpty) _resultCard(),
          ],
        ),
      ),
    );
  }

  // ---------------- APP BAR ----------------
  AppBar _appBar() {
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
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFFF9F43).withOpacity(0.15),
            ),
            child: const Icon(Icons.edit, color: Color(0xFFFF9F43)),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Writing Task Checker",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                "AI Essay Evaluation",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- INFO ----------------
  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1E6), Color(0xFFFFF6EE)],
        ),
        border: const Border(
          left: BorderSide(color: Color(0xFFFF9F43), width: 4),
        ),
      ),
      child: const Text(
        """Some people believe that technology has made our lives more complicated. Others think it has made life easier. Discuss both views and give your own opinion.

Write at least 250 words.""",
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _quickTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFDDE5FF), Color(0xFFFFF6EE)],
        ),
      ),
      child: const Text(
        """💡 Tips:
• Write clear introduction, body, conclusion
• Use linking words
• Give examples""",
      ),
    );
  }

  // ---------------- INPUT ----------------
  Widget _essayInput() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
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
          const SizedBox(height: 12),
          TextField(
            controller: _essayController,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: "Write essay...",
              border: OutlineInputBorder(),
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
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF9F43),
        ),
        onPressed: isLoading ? null : _checkEssay,
        icon: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white),
              )
            : const Icon(Icons.auto_fix_high),
        label: Text(isLoading ? "Analyzing..." : "Check Essay"),
      ),
    );
  }

  // ---------------- AI CALL ----------------
  Future<void> _checkEssay() async {
    if (_essayController.text.trim().isEmpty) {
      Get.snackbar("Error", "Write essay first");
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await ai.evaluateWriting(
        _essayController.text,
        "2",
      );

      setState(() {
        bandScore = result["band"] ?? "0";
        taskResponse = result["task_response"] ?? "";
        coherence = result["coherence"] ?? "";
        lexical = result["lexical"] ?? "";
        grammar = result["grammar"] ?? "";
        improvement = result["improvement"] ?? "";
      });
    } catch (e) {
      Get.snackbar("Error", "AI failed. Try again.");
    }

    setState(() => isLoading = false);
  }

  // ---------------- RESULT ----------------
  Widget _resultCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("AI Evaluation",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          const SizedBox(height: 12),

          Text("Band: $bandScore",
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),
          Text("Task Response: $taskResponse"),
          Text("Coherence: $coherence"),
          Text("Lexical: $lexical"),
          Text("Grammar: $grammar"),

          const SizedBox(height: 10),
          Text("Improvement:\n$improvement"),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  Widget _roundButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          blurRadius: 10,
          color: Colors.black.withOpacity(0.05),
        )
      ],
    );
  }
}