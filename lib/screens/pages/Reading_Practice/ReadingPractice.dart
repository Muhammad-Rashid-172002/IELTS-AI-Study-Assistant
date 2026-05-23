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

  Color get primary => const Color(0xFF14B8A6);
  Color get secondary => const Color(0xFF0F766E);
  Color get bg => const Color(0xFF08111F);

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
      final correctAnswer = questions[i]["answer"]
          .toString()
          .trim()
          .toLowerCase()
          .replaceAll(".", "")
          .replaceAll(",", "");

      final userAnswer = selectedAnswers[i]
          ?.trim()
          .toLowerCase()
          .replaceAll(".", "")
          .replaceAll(",", "");

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
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.25),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// ICON
              Container(
                height: 82,
                width: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [primary, secondary]),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),

              const SizedBox(height: 24),

              /// TITLE
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 14),

              /// MESSAGE
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 28),

              /// BUTTONS
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            "Close",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(context);
                        retry();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primary, secondary],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "Retry",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
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
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 30),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF08111F), const Color(0xFF102A43), secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),

      child: Column(
        children: [
          Row(
            children: [
              _circleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),

                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),

                        const SizedBox(width: 10),

                        const Expanded(
                          child: Text(
                            "IELTS Reading",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "AI Academic Reading Practice",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              _circleButton(icon: Icons.menu_book_rounded, onTap: () {}),
            ],
          ),

          const SizedBox(height: 30),

          Row(
            children: [
              Expanded(
                child: _infoCard(
                  title: "Time Left",
                  value: timeFormatted,
                  icon: Icons.timer_outlined,
                ),
              ),

              const SizedBox(width: 14),

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

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
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
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
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
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),

          borderRadius: BorderRadius.circular(32),

          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1.2),

          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),

            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 92,
              width: 92,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                gradient: LinearGradient(colors: [primary, secondary]),

                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),

              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 72,
                    width: 72,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      backgroundColor: Colors.white.withOpacity(0.12),
                    ),
                  ),

                  const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              "Generating IELTS Reading Test...",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              "AI is creating an advanced IELTS reading passage with realistic questions, smart evaluation and band scoring.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 14,
                height: 1.7,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 26),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _loadingChip("Passage"),
                const SizedBox(width: 8),
                _loadingChip("MCQs"),
                const SizedBox(width: 8),
                _loadingChip("True/False"),
                const SizedBox(width: 8),
                _loadingChip("Band Score"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),

      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.84),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _startBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 24),

          _whiteCard(
            child: Column(
              children: [
                Container(
                  height: 96,
                  width: 96,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    gradient: LinearGradient(
                      colors: [primary, secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),

                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  "Start Reading Practice",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  "Practice real IELTS-style reading passages with advanced AI-generated questions, detailed scoring and estimated IELTS band.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.7,
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.70),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 28),

                _featureTile(
                  Icons.article_outlined,
                  "Academic IELTS reading passage",
                ),

                _featureTile(
                  Icons.quiz_rounded,
                  "MCQs, True/False & Not Given",
                ),

                _featureTile(
                  Icons.analytics_outlined,
                  "Instant score & performance analysis",
                ),

                _featureTile(
                  Icons.workspace_premium_outlined,
                  "Estimated IELTS Band Score",
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),

                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: primary.withOpacity(0.22)),
                  ),

                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: primary),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          "AI creates a unique IELTS Reading test every time.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.84),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.white.withOpacity(0.08)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,

            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, secondary]),

              borderRadius: BorderRadius.circular(14),

              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),

            child: Icon(icon, color: Colors.white, size: 22),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),

          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withOpacity(0.45),
            size: 16,
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
          if (showResult) ...[const SizedBox(height: 18), _resultCard()],
        ],
      ),
    );
  }

  Widget _passageCard() {
    final formattedPassage = passage
        .replaceAll("###", "\n###")
        .replaceAll("##", "\n##")
        .replaceAll("Paragraph", "\nParagraph");

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TOP HEADER
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),
                  borderRadius: BorderRadius.circular(18),

                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? "IELTS Academic Reading" : title,

                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "AI Generated IELTS Passage",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          /// READING LABEL
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

            decoration: BoxDecoration(
              color: primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withOpacity(0.22)),
            ),

            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_stories_rounded, color: primary, size: 18),

                const SizedBox(width: 8),

                Text(
                  "READING PASSAGE",
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          /// PASSAGE CONTENT
          SelectableText.rich(
            TextSpan(children: _buildFormattedPassage(formattedPassage)),
          ),
        ],
      ),
    );
  }

  /// FORMAT PASSAGE
  List<TextSpan> _buildFormattedPassage(String text) {
    final lines = text.split("\n");

    return lines.map((line) {
      final trimmed = line.trim();

      /// MAIN HEADINGS
      if (trimmed.startsWith("###") || trimmed.startsWith("##")) {
        return TextSpan(
          text: "\n${trimmed.replaceAll("#", "").trim()}\n",
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            height: 1.8,
          ),
        );
      }

      /// PARAGRAPH LABELS
      if (trimmed.startsWith("Paragraph")) {
        return TextSpan(
          text: "\n$trimmed\n",
          style: TextStyle(
            color: primary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.8,
          ),
        );
      }

      /// NORMAL TEXT
      return TextSpan(
        text: "$trimmed\n\n",
        style: TextStyle(
          color: Colors.white.withOpacity(0.84),
          fontSize: 15.5,
          height: 2.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      );
    }).toList();
  }

  Widget _progressCard() {
    final answered = selectedAnswers.where((e) => e != null).length;

    final progress = questions.isEmpty ? 0.0 : answered / questions.length;

    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(30),

        border: Border.all(color: Colors.white.withOpacity(0.08)),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 50,
                width: 50,

                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),

                  borderRadius: BorderRadius.circular(16),

                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reading Progress",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "$answered of ${questions.length} answered",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),

                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primary.withOpacity(0.22)),
                ),

                child: Text(
                  "${(progress * 100).round()}%",
                  style: const TextStyle(
                    color: Color(0xFF86EFAC),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(primary),
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

    final type = q["type"]?.toString() ?? "multiple_choice";

    final hasOptions = options.isNotEmpty;

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TOP HEADER
          Row(
            children: [
              Container(
                height: 48,
                width: 48,

                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),

                  borderRadius: BorderRadius.circular(16),

                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: Center(
                  child: Text(
                    "${currentQuestion + 1}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reading Question",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "Question ${currentQuestion + 1} of ${questions.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          /// QUESTION TEXT
          Container(
            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),

              borderRadius: BorderRadius.circular(22),

              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),

            child: Text(
              q["question"]?.toString() ?? "",

              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.6,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 18),

          /// TYPE CHIP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withOpacity(0.22),
                  secondary.withOpacity(0.12),
                ],
              ),

              borderRadius: BorderRadius.circular(22),

              border: Border.all(color: primary.withOpacity(0.25)),
            ),

            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.quiz_rounded, color: primary, size: 18),

                const SizedBox(width: 8),

                Text(
                  type.replaceAll("_", " ").toUpperCase(),

                  style: TextStyle(
                    color: primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          /// OPTIONS
          if (hasOptions)
            ...options.map((option) {
              final isSelected = selectedAnswers[currentQuestion] == option;

              final isCorrect = showResult && correctAnswer == option;

              final isWrong = showResult && isSelected && !isCorrect;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),

                margin: const EdgeInsets.only(bottom: 14),

                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCorrect
                        ? [
                            Colors.green.withOpacity(0.22),
                            Colors.green.withOpacity(0.08),
                          ]
                        : isWrong
                        ? [
                            Colors.red.withOpacity(0.20),
                            Colors.red.withOpacity(0.08),
                          ]
                        : isSelected
                        ? [
                            primary.withOpacity(0.22),
                            secondary.withOpacity(0.10),
                          ]
                        : [
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.04),
                          ],
                  ),

                  borderRadius: BorderRadius.circular(22),

                  border: Border.all(
                    color: isCorrect
                        ? Colors.greenAccent
                        : isWrong
                        ? Colors.redAccent
                        : isSelected
                        ? primary
                        : Colors.white.withOpacity(0.08),
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? primary.withOpacity(0.16)
                          : Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: Material(
                  color: Colors.transparent,

                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),

                    onTap: showResult
                        ? null
                        : () {
                            setState(() {
                              selectedAnswers[currentQuestion] = option;
                            });
                          },

                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),

                      child: Row(
                        children: [
                          Icon(
                            isCorrect
                                ? Icons.check_circle_rounded
                                : isWrong
                                ? Icons.cancel_rounded
                                : isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,

                            color: isCorrect
                                ? Colors.greenAccent
                                : isWrong
                                ? Colors.redAccent
                                : isSelected
                                ? primary
                                : Colors.white54,
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Text(
                              option,

                              style: TextStyle(
                                color: Colors.white.withOpacity(0.90),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            })
          else
            _answerField(),

          /// EXPLANATION
          if (showResult && q["explanation"] != null) ...[
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withOpacity(0.12),
                    secondary.withOpacity(0.08),
                  ],
                ),

                borderRadius: BorderRadius.circular(20),

                border: Border.all(color: primary.withOpacity(0.18)),
              ),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_rounded, color: primary),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      q["explanation"],

                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          /// NAVIGATION
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

              const SizedBox(width: 12),

              Expanded(
                child: _smallButton(
                  text: currentQuestion == questions.length - 1
                      ? "Finish"
                      : "Next",

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

  Widget _answerField() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: TextField(
        key: ValueKey(currentQuestion),

        controller: TextEditingController(
          text: selectedAnswers[currentQuestion] ?? "",
        ),

        enabled: !showResult,

        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),

        cursorColor: primary,

        onChanged: (value) {
          selectedAnswers[currentQuestion] = value;
        },

        decoration: InputDecoration(
          hintText: "Write your answer here...",
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontWeight: FontWeight.w500,
          ),

          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, secondary]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),

          filled: true,
          fillColor: Colors.transparent,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: primary, width: 1.5),
          ),

          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
      ),
    );
  }

  Widget _resultCard() {
    final band = calculateBandScore();
    final percent = questions.isEmpty ? 0.0 : score / questions.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          colors: [
            primary.withOpacity(0.22),
            const Color(0xFF111827),
            const Color(0xFF0B1220),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: primary.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.28),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 86,
            width: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [primary, secondary]),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.38),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            "Estimated IELTS Band",
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            band.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xFF86EFAC),
              fontSize: 66,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            "Score: $score / ${questions.length}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 26),

          _gradientButton(
            text: "Generate New Reading Test",
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

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(34),

        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1.2),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),

      child: child,
    );
  }

  Widget _smallButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),

      decoration: BoxDecoration(
        gradient: isDisabled
            ? LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.03),
                ],
              )
            : LinearGradient(
                colors: [
                  primary.withOpacity(0.22),
                  secondary.withOpacity(0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

        borderRadius: BorderRadius.circular(22),

        border: Border.all(
          color: isDisabled
              ? Colors.white.withOpacity(0.06)
              : primary.withOpacity(0.22),
        ),

        boxShadow: [
          BoxShadow(
            color: isDisabled
                ? Colors.black.withOpacity(0.10)
                : primary.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,

          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),

                  decoration: BoxDecoration(
                    color: isDisabled
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.12),

                    shape: BoxShape.circle,
                  ),

                  child: Icon(
                    icon,
                    color: isDisabled ? Colors.white24 : Colors.white,

                    size: 18,
                  ),
                ),

                const SizedBox(width: 10),

                Text(
                  text,
                  style: TextStyle(
                    color: isDisabled ? Colors.white38 : Colors.white,

                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradientButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),

        gradient: const LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,

          child: Container(
            width: double.infinity,

            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
  mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),

                  child: Icon(icon, color: Colors.white, size: 20),
                ),

                const SizedBox(width: 14),

                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                       overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
