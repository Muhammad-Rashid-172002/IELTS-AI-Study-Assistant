import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fyproject/services/ai_service.dart';

class ListeningPractice extends StatefulWidget {
  const ListeningPractice({super.key});

  @override
  State<ListeningPractice> createState() => _ListeningPracticeState();
}

class _ListeningPracticeState extends State<ListeningPractice> {
  final AIService aiService = AIService();
  final FlutterTts flutterTts = FlutterTts();

  String title = "";
  String audioScript = "";
  List<Map<String, dynamic>> questions = [];
  List<String?> selectedAnswers = [];

  bool generated = false;
  bool isLoading = false;
  bool isPlaying = false;
  bool showResult = false;

  int score = 0;
  Timer? countdownTimer;
  int totalSeconds = 600;

  String get formattedTime {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();

    flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    flutterTts.stop();
    super.dispose();
  }

  Future<void> generateListeningTest() async {
    setState(() {
      isLoading = true;
      showResult = false;
      score = 0;
      totalSeconds = 600;
    });

    try {
      final data = await aiService.generateListeningTest(section: "Section 1");

      final qList = List<Map<String, dynamic>>.from(
        data["questions"] ?? [],
      );

      setState(() {
        title = data["title"] ?? "IELTS Listening Test";
        audioScript = data["audio_script"] ?? "";
        questions = qList;
        selectedAnswers = List.generate(qList.length, (_) => null);
        generated = true;
      });
    } catch (e) {
      _showSnack("Error", "Failed to generate listening test");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> playAudio() async {
    if (audioScript.isEmpty) return;

    await flutterTts.stop();
    await flutterTts.setLanguage("en-GB");
    await flutterTts.setSpeechRate(0.43);
    await flutterTts.setPitch(1.0);

    setState(() => isPlaying = true);
    startTimer();

    await flutterTts.speak(audioScript);
  }

  Future<void> stopAudio() async {
    await flutterTts.stop();
    countdownTimer?.cancel();

    setState(() => isPlaying = false);
  }

  void startTimer() {
    countdownTimer?.cancel();

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (totalSeconds > 0) {
        setState(() => totalSeconds--);
      } else {
        timer.cancel();
        submitAnswers();
      }
    });
  }

  Future<void> submitAnswers() async {
    if (questions.isEmpty) return;

    int correct = 0;

    for (int i = 0; i < questions.length; i++) {
      final answer = questions[i]["answer"].toString().trim().toLowerCase();
      final userAnswer = selectedAnswers[i]?.trim().toLowerCase();

      if (userAnswer == answer) {
        correct++;
      }
    }

    setState(() {
      score = correct;
      showResult = true;
      isPlaying = false;
    });

    countdownTimer?.cancel();
    await flutterTts.stop();
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
        .collection("listening_results")
        .add({
      "score": score,
      "total": questions.length,
      "band": calculateBandScore(),
      "title": title,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  void _showSnack(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$title: $message"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color get primary => const Color(0xff2563EB);
  Color get secondary => const Color(0xff7C3AED);
  Color get bg => const Color(0xffF6F8FC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _header(),

          Expanded(
            child: generated ? _testBody() : _startBody(),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 52, 18, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                      "IELTS Listening",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "AI generated real practice test",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _circleButton(
                icon: Icons.headphones_rounded,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _topInfo(
                  icon: Icons.timer_outlined,
                  title: "Timer",
                  value: formattedTime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _topInfo(
                  icon: Icons.quiz_outlined,
                  title: "Questions",
                  value: "${questions.length}",
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

  Widget _topInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _startBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 82,
                  width: 82,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Start Listening Practice",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff111827),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Generate an IELTS-style listening test with audio script, questions, answers, score and band result.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xff6B7280),
                  ),
                ),

                const SizedBox(height: 24),

                _featureTile(Icons.record_voice_over, "British English TTS audio"),
                _featureTile(Icons.check_circle_outline, "Auto checking answers"),
                _featureTile(Icons.workspace_premium_outlined, "Estimated IELTS band"),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _gradientButton(
            text: isLoading ? "Generating..." : "Generate Listening Test",
            icon: Icons.auto_awesome,
            onTap: isLoading ? null : generateListeningTest,
            loading: isLoading,
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
          Icon(icon, color: primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xff374151),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      child: Column(
        children: [
          _audioCard(),
          const SizedBox(height: 14),
          _progressCard(),
          const SizedBox(height: 14),
          _questionList(),
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

  Widget _audioCard() {
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.headphones_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? "Listening Section 1" : title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Listen once and answer carefully",
                      style: TextStyle(
                        color: Color(0xff6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xffF3F4F6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Text(
                  formattedTime,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xff111827),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: totalSeconds / 600,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(20),
                    backgroundColor: Colors.grey.shade300,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: isPlaying ? stopAudio : playAudio,
            child: Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, secondary]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 42,
              ),
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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            "${questions.isEmpty ? 0 : ((answered / questions.length) * 100).round()}%",
            style: const TextStyle(
              color: Color(0xff86EFAC),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionList() {
    return Column(
      children: List.generate(questions.length, (i) {
        final q = questions[i];
        final options = List<String>.from(q["options"] ?? []);
        final correctAnswer = q["answer"]?.toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: showResult
                  ? selectedAnswers[i] == correctAnswer
                      ? Colors.green
                      : Colors.redAccent
                  : Colors.transparent,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Question ${i + 1}",
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                q["question"]?.toString() ?? "",
                style: const TextStyle(
                  color: Color(0xff111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              ...options.map((option) {
                final isSelected = selectedAnswers[i] == option;
                final isCorrect = showResult && correctAnswer == option;
                final isWrong = showResult && isSelected && !isCorrect;

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: showResult
                      ? null
                      : () {
                          setState(() {
                            selectedAnswers[i] = option;
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
                              fontWeight: FontWeight.w600,
                              color: Color(0xff374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              if (showResult && q["explanation"] != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "Explanation: ${q["explanation"]}",
                    style: const TextStyle(
                      color: Color(0xff1E40AF),
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Text(
            "Your Estimated Band",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            band.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xff86EFAC),
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Score: $score / ${questions.length}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _gradientButton(
            text: "Generate New Test",
            icon: Icons.refresh_rounded,
            onTap: generateListeningTest,
          ),
        ],
      ),
    );
  }

  Widget _gradientButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onTap == null
                ? [Colors.grey, Colors.grey.shade500]
                : [primary, secondary],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}