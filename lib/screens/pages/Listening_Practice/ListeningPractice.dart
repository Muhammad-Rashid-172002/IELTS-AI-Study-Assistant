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

  Map<String, dynamic> listeningTest = {};
  String selectedPart = "part1";

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
  int totalSeconds = 1800;

  Color get primary => const Color(0xFF14B8A6);
  Color get secondary => const Color(0xFF0F766E);
  Color get bg => const Color(0xFF08111F);

  String get formattedTime {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => isPlaying = false);
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
      totalSeconds = 1800;
    });

    try {
      final data = await aiService.generateListeningTest();

      setState(() {
        listeningTest = data;
        generated = true;
      });

      loadPart("part1");
    } catch (e) {
      _showSnack("Error", "Failed to generate listening test");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void loadPart(String part) {
    final partData = listeningTest[part] as Map<String, dynamic>? ?? {};
    final qList = List<Map<String, dynamic>>.from(partData["questions"] ?? []);

    setState(() {
      selectedPart = part;
      title = partData["title"] ?? "IELTS Listening ${part.toUpperCase()}";
      audioScript = partData["audio_script"] ?? "";
      questions = qList;
      selectedAnswers = List.generate(qList.length, (_) => null);
      showResult = false;
      score = 0;
      totalSeconds = 1800;
    });
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
      final answer = _cleanAnswer(questions[i]["answer"]);
      final userAnswer = _cleanAnswer(selectedAnswers[i]);

      if (userAnswer == answer) correct++;
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

  String _cleanAnswer(dynamic value) {
    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(".", "")
        .replaceAll(",", "");
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
          "part": selectedPart,
          "score": score,
          "total": questions.length,
          "band": calculateBandScore(),
          "title": title,
          "answers": selectedAnswers,
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
                ? _testBody()
                : _startBody(),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF08111F), Color(0xFF102A43), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),

      child: Column(
        children: [
          Row(
            children: [
              _circleButton(
                icon: Icons.arrow_back_ios_new_rounded,
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
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    SizedBox(height: 4),

                    Text(
                      "AI Powered Listening Practice",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              _circleButton(icon: Icons.headphones_rounded, onTap: () {}),
            ],
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: _topInfo(
                  icon: Icons.timer_outlined,
                  title: "Time Left",
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
      child: _whiteCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primary),
            const SizedBox(height: 18),
            const Text(
              "Generating Listening Test...",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "AI is creating 4 IELTS listening parts.",
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
          const SizedBox(height: 28),
          _whiteCard(
            child: Column(
              children: [
                Container(
                  height: 88,
                  width: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Start IELTS Listening",
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Practice Part 1 to Part 4 with audio, mixed question types, auto-checking and estimated IELTS band.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xff6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                _featureTile(Icons.looks_one, "Part 1: daily conversation"),
                _featureTile(Icons.looks_two, "Part 2: social monologue"),
                _featureTile(Icons.looks_3, "Part 3: academic discussion"),
                _featureTile(Icons.looks_4, "Part 4: academic lecture"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _gradientButton(
            text: isLoading ? "Generating..." : "Generate Full Test",
            icon: Icons.auto_awesome,
            onTap: isLoading ? null : generateListeningTest,
            loading: isLoading,
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
          _partTabs(),
          const SizedBox(height: 14),
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
          if (showResult) ...[const SizedBox(height: 18), _resultCard()],
        ],
      ),
    );
  }

  Widget _partTabs() {
    return Row(
      children: [
        Expanded(child: _partButton("Part 1", "part1")),
        const SizedBox(width: 8),
        Expanded(child: _partButton("Part 2", "part2")),
        const SizedBox(width: 8),
        Expanded(child: _partButton("Part 3", "part3")),
        const SizedBox(width: 8),
        Expanded(child: _partButton("Part 4", "part4")),
      ],
    );
  }

  Widget _partButton(String text, String value) {
    final selected = selectedPart == value;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => loadPart(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [primary, secondary])
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xffE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xff6B7280),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _audioCard() {
    return _whiteCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.headphones_rounded,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      selectedPart.toUpperCase(),
                      style: TextStyle(color: Colors.white.withOpacity(0.60)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: (totalSeconds / 1800).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),

          const SizedBox(height: 28),

          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: isPlaying ? stopAudio : playAudio,
            child: Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [primary, secondary]),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            isPlaying ? "Audio is playing..." : "Tap to play listening audio",
            style: TextStyle(
              color: Colors.white.withOpacity(0.60),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard() {
    final answered = selectedAnswers
        .where((e) => e != null && e.trim().isNotEmpty)
        .length;

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
        final type = q["type"]?.toString() ?? "question";
        final hasOptions = options.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: showResult
                  ? _cleanAnswer(selectedAnswers[i]) ==
                            _cleanAnswer(correctAnswer)
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
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _typeChip(type),
              const SizedBox(height: 12),

              if (hasOptions)
                ...options.map(
                  (option) => _optionTile(i, option, correctAnswer),
                )
              else
                _answerField(i),

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

  Widget _typeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.replaceAll("_", " ").toUpperCase(),
        style: TextStyle(
          color: primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _optionTile(int i, String option, String? correctAnswer) {
    final isSelected = selectedAnswers[i] == option;
    final isCorrect =
        showResult && _cleanAnswer(correctAnswer) == _cleanAnswer(option);
    final isWrong = showResult && isSelected && !isCorrect;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: showResult
          ? null
          : () => setState(() => selectedAnswers[i] = option),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isCorrect
              ? Colors.green.withOpacity(0.15)
              : isWrong
              ? Colors.red.withOpacity(0.12)
              : isSelected
              ? primary.withOpacity(0.14)
              : const Color(0xFF1E293B),
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
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isCorrect
                      ? Colors.green.shade700
                      : isWrong
                      ? Colors.red.shade700
                      : isSelected
                      ? primary
                      : const Color(0xFF111827), // Dark text
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerField(int i) {
    return TextField(
      enabled: !showResult,
      onChanged: (value) => selectedAnswers[i] = value,
      decoration: InputDecoration(
        hintText: "Write your answer here",
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
      ),
    );
  }

  Widget _resultCard() {
    final band = calculateBandScore();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),

        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
        ),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),

      child: Column(
        children: [
          Text(
            "Estimated IELTS Band",
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            band.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xFF86EFAC),
              fontSize: 58,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            "Score: $score / ${questions.length}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 24),

          _gradientButton(
            text: "Generate New Test",
            icon: Icons.refresh_rounded,
            onTap: generateListeningTest,
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

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),

        border: Border.all(color: Colors.white.withOpacity(0.10)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
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
            colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6), Color(0xFF0F766E)],
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
