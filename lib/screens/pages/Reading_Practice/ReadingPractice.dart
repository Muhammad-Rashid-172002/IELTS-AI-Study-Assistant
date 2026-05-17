import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fyproject/services/ai_service.dart';

class ReadingPractice extends StatefulWidget {
  const ReadingPractice({super.key});

  @override
  State<ReadingPractice> createState() => _ReadingPracticeState();
}

class _ReadingPracticeState extends State<ReadingPractice> {
  final AIService ai = AIService();

  String title = "";
  String passage = "";

  List<Map<String, dynamic>> questions = [];
  List<String?> selectedAnswers = [];

  bool isLoading = false;
  bool generated = false;
  bool showResult = false;

  int score = 0;
  int currentQuestion = 0;

  int totalSeconds = 1200;
  Timer? timer;

  Color get primary => const Color(0xff7C3AED);
  Color get secondary => const Color(0xffEC4899);
  Color get bg => const Color(0xffF6F8FC);

  String get timeFormatted {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> generateAIReadingTest() async {
    setState(() {
      isLoading = true;
      generated = false;
      showResult = false;
      score = 0;
      currentQuestion = 0;
      totalSeconds = 1200;
    });

    try {
      final data = await ai.generateReadingTest();

      final qList = List<Map<String, dynamic>>.from(data["questions"] ?? []);

      setState(() {
        title = data["title"] ?? "IELTS Academic Reading";
        passage = data["passage"] ?? "";
        questions = qList;
        selectedAnswers = List.generate(qList.length, (_) => null);
        generated = true;
      });

      startTimer();
    } catch (e) {
      _showInternetDialog(
        title: "Reading Test Failed",
        message:
            "Your internet connection is not working properly, or the AI service is unavailable. Please check your network and try again.",
        retry: generateAIReadingTest,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (totalSeconds > 0) {
        setState(() => totalSeconds--);
      } else {
        timer?.cancel();
        submitAnswers();
      }
    });
  }

  Future<void> submitAnswers() async {
    if (questions.isEmpty) return;

    timer?.cancel();

    int correct = 0;

    for (int i = 0; i < questions.length; i++) {
      final correctAnswer = questions[i]["answer"].toString().trim().toLowerCase();
      final userAnswer = selectedAnswers[i]?.trim().toLowerCase();

      if (userAnswer == correctAnswer) {
        correct++;
      }
    }

    setState(() {
      score = correct;
      showResult = true;
    });

    await saveResultToFirebase();
  }

  double calculateBandScore() {
    if (questions.isEmpty) return 0;

    final percent = score / questions.length;

    if (percent >= 0.95) return 9.0;
    if (percent >= 0.85) return 8.0;
    if (percent >= 0.75) return 7.0;
    if (percent >= 0.65) return 6.5;
    if (percent >= 0.55) return 6.0;
    if (percent >= 0.45) return 5.5;
    if (percent >= 0.35) return 5.0;
    return 4.0;
  }

  Future<void> saveResultToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("reading_results")
        .add({
      "title": title,
      "passage": passage,
      "questions": questions,
      "answers": selectedAnswers,
      "score": score,
      "total": questions.length,
      "band": calculateBandScore(),
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  void _showInternetDialog({
    required String title,
    required String message,
    required VoidCallback retry,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: primary),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              retry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: isLoading
                ? _loadingBody()
                : generated
                    ? _body()
                    : _startBody(),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 52, 18, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, secondary]),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleButton(
                icon: Icons.arrow_back_ios_new,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "IELTS Reading",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Academic passage practice",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _circleButton(
                icon: Icons.menu_book_rounded,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  title: "Time Left",
                  value: timeFormatted,
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  title: "Questions",
                  value: questions.isEmpty
                      ? "0"
                      : "${currentQuestion + 1}/${questions.length}",
                  icon: Icons.quiz_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingBody() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primary),
            const SizedBox(height: 18),
            const Text(
              "Generating IELTS Reading Test...",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              "AI is creating a passage and questions.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _startBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 26),
          _whiteCard(
            child: Column(
              children: [
                Container(
                  height: 86,
                  width: 86,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Start Reading Practice",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Generate a real IELTS-style reading passage with MCQ and True/False/Not Given questions.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.5,
                    color: Color(0xff6B7280),
                  ),
                ),
                const SizedBox(height: 20),
                _featureTile(Icons.article_outlined, "Academic IELTS passage"),
                _featureTile(Icons.quiz_outlined, "Mixed question types"),
                _featureTile(Icons.workspace_premium_outlined, "Score and estimated band"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _gradientButton(
            text: "Start AI Reading Test",
            icon: Icons.play_arrow_rounded,
            onTap: generateAIReadingTest,
          ),
        ],
      ),
    );
  }

  Widget _featureTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xff374151),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _passageCard(),
          const SizedBox(height: 16),
          _progressCard(),
          const SizedBox(height: 16),
          if (questions.isNotEmpty) _questionCard(),
          const SizedBox(height: 16),
          _gradientButton(
            text: "Submit Answers",
            icon: Icons.done_all_rounded,
            onTap: submitAnswers,
          ),
          if (showResult) ...[
            const SizedBox(height: 18),
            _resultCard(),
          ],
        ],
      ),
    );
  }

  Widget _passageCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.menu_book_rounded, title.isEmpty ? "Reading Passage" : title),
          const SizedBox(height: 12),
          Text(
            passage,
            style: const TextStyle(
              height: 1.6,
              color: Color(0xff374151),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard() {
    final answered = selectedAnswers.where((e) => e != null).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff111827),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_turned_in_outlined, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$answered of ${questions.length} answered",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            "${questions.isEmpty ? 0 : ((answered / questions.length) * 100).round()}%",
            style: const TextStyle(
              color: Color(0xffF9A8D4),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard() {
    final q = questions[currentQuestion];
    final options = List<String>.from(q["options"] ?? []);
    final correctAnswer = q["answer"]?.toString();

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Question ${currentQuestion + 1}",
            style: TextStyle(
              color: primary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            q["question"]?.toString() ?? "",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.4,
              color: Color(0xff111827),
            ),
          ),
          const SizedBox(height: 14),

          ...options.map((option) {
            final isSelected = selectedAnswers[currentQuestion] == option;
            final isCorrect = showResult && correctAnswer == option;
            final isWrong = showResult && isSelected && !isCorrect;

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: showResult
                  ? null
                  : () {
                      setState(() {
                        selectedAnswers[currentQuestion] = option;
                      });
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withOpacity(0.12)
                      : isWrong
                          ? Colors.red.withOpacity(0.10)
                          : isSelected
                              ? primary.withOpacity(0.10)
                              : const Color(0xffF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCorrect
                        ? Colors.green
                        : isWrong
                            ? Colors.redAccent
                            : isSelected
                                ? primary
                                : const Color(0xffE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle
                          : isWrong
                              ? Icons.cancel
                              : isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                      color: isCorrect
                          ? Colors.green
                          : isWrong
                              ? Colors.redAccent
                              : isSelected
                                  ? primary
                                  : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option,
                        style: const TextStyle(
                          color: Color(0xff374151),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          if (showResult && q["explanation"] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "Explanation: ${q["explanation"]}",
                style: const TextStyle(color: Color(0xff1E40AF), height: 1.4),
              ),
            ),
          ],

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _smallButton(
                  text: "Previous",
                  icon: Icons.arrow_back_rounded,
                  onTap: currentQuestion > 0
                      ? () => setState(() => currentQuestion--)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _smallButton(
                  text: currentQuestion == questions.length - 1 ? "Last" : "Next",
                  icon: Icons.arrow_forward_rounded,
                  onTap: currentQuestion < questions.length - 1
                      ? () => setState(() => currentQuestion++)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final band = calculateBandScore();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff111827), Color(0xff1F2937)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Text(
            "Estimated IELTS Band",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            band.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xffF9A8D4),
              fontSize: 52,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Score: $score / ${questions.length}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _gradientButton(
            text: "Generate New Test",
            icon: Icons.refresh_rounded,
            onTap: generateAIReadingTest,
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xff111827),
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xffF3F4F6) : primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap == null ? const Color(0xffE5E7EB) : primary.withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: onTap == null ? Colors.grey : primary, size: 18),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: onTap == null ? Colors.grey : primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [primary, secondary]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}