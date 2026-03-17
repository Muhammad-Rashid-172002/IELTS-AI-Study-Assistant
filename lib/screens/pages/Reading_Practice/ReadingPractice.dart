import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controller/feedback_controller/feedback_controller.dart';

class ReadingPractice extends StatefulWidget {
  const ReadingPractice({super.key});

  @override
  State<ReadingPractice> createState() => _ReadingPracticeState();
}

class _ReadingPracticeState extends State<ReadingPractice> {
  final feedbackController = Get.put(FeedbackController());

  int? q1;
  int? q2;

  int score = 0;
  bool showResult = false;

  bool generated = false;

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

  // ----------------------------------------------------
  // APP BAR
  // ----------------------------------------------------

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
            child: const Icon(Icons.menu_book, color: Color(0xFF4A79F6)),
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
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // INFO CARD
  // ----------------------------------------------------

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDDEBFF), Color(0xFFE9F3FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: Colors.blue, width: 4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF4A79F6)),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              "AI will generate an IELTS reading passage. Read carefully and answer questions.",
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // GENERATE AI PASSAGE
  // ----------------------------------------------------

  Widget _generateButton() {
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
        onPressed: () {
          feedbackController.generateFeedback(
            "Generate IELTS reading passage with questions",
            "Reading",
          );
          setState(() {
            generated = true;
          });

          feedbackController.generateFeedback(
            "Generate a short IELTS reading passage with 2 multiple choice questions.",

            "Reading",
          );
        },

        icon: const Icon(Icons.auto_awesome, color: Colors.white),

        label: const Text(
          "Generate AI Reading Test",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // PASSAGE
  // ----------------------------------------------------

  Widget _readingPassage() {
    return Obx(() {
      if (feedbackController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "AI Reading Passage",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(
              feedbackController.feedback.value,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      );
    });
  }

  // ----------------------------------------------------
  // QUESTIONS
  // ----------------------------------------------------

  Widget _questionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Questions",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          const Text("1. What is the main topic of the passage?"),

          RadioListTile(
            title: const Text("Artificial Intelligence"),
            value: 1,
            groupValue: q1,
            onChanged: (v) {
              setState(() => q1 = v);
            },
          ),

          RadioListTile(
            title: const Text("Climate Change"),
            value: 2,
            groupValue: q1,
            onChanged: (v) {
              setState(() => q1 = v);
            },
          ),

          const SizedBox(height: 10),

          const Text("2. Which industry uses AI?"),

          RadioListTile(
            title: const Text("Healthcare"),
            value: 1,
            groupValue: q2,
            onChanged: (v) {
              setState(() => q2 = v);
            },
          ),

          RadioListTile(
            title: const Text("Agriculture"),
            value: 2,
            groupValue: q2,
            onChanged: (v) {
              setState(() => q2 = v);
            },
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // SUBMIT BUTTON
  // ----------------------------------------------------

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
        onPressed: () {
          score = 0;

          if (q1 == 1) score++;
          if (q2 == 1) score++;

          setState(() {
            showResult = true;
          });
        },
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

  // ----------------------------------------------------
  // RESULT
  // ----------------------------------------------------

  Widget _resultCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),

      child: Column(
        children: [
          const Text(
            "Your Score",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Text(
            "$score / 2",
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

  // ----------------------------------------------------
  // COMMON UI
  // ----------------------------------------------------

  Widget _roundButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.black87),
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
