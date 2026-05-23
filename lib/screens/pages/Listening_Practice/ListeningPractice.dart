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
            Container(
              height: 90,
              width: 90,
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
                    height: 70,
                    width: 70,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                      backgroundColor: Colors.white.withOpacity(0.12),
                    ),
                  ),

                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            const Text(
              "Generating Listening Test...",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              "AI is creating professional IELTS listening sections with realistic conversations, questions and answers.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.70),
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _loadingChip("Part 1"),
                const SizedBox(width: 8),
                _loadingChip("Part 2"),
                const SizedBox(width: 8),
                _loadingChip("Part 3"),
                const SizedBox(width: 8),
                _loadingChip("Part 4"),
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
          color: Colors.white.withOpacity(0.82),
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
                    color: Color.fromARGB(255, 165, 174, 192),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => loadPart(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),

          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      const Color(0xFF2DD4BF),
                      const Color(0xFF14B8A6),
                      const Color(0xFF0F766E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04),
                    ],
                  ),

            borderRadius: BorderRadius.circular(20),

            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.08),
              width: 1.2,
            ),

            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.35),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),

              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withOpacity(0.72),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
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

        final isCorrect =
            showResult &&
            _cleanAnswer(selectedAnswers[i]) == _cleanAnswer(correctAnswer);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.045),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: showResult
                  ? isCorrect
                        ? Colors.greenAccent.withOpacity(0.8)
                        : Colors.redAccent.withOpacity(0.8)
                  : Colors.white.withOpacity(0.10),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: showResult
                    ? isCorrect
                          ? Colors.greenAccent.withOpacity(0.18)
                          : Colors.redAccent.withOpacity(0.16)
                    : Colors.black.withOpacity(0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primary, secondary]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        "${i + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _typeChip(type)),
                  if (showResult)
                    Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                q["question"]?.toString() ?? "",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 18),

              if (hasOptions)
                ...options.map(
                  (option) => _optionTile(i, option, correctAnswer),
                )
              else
                _answerField(i),

              if (showResult && q["explanation"] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_rounded, color: primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Explanation: ${q["explanation"]}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _typeChip(String type) {
    IconData icon;

    switch (type.toLowerCase()) {
      case "multiple_choice":
        icon = Icons.radio_button_checked_rounded;
        break;

      case "fill_in_the_blank":
        icon = Icons.edit_note_rounded;
        break;

      case "true_false":
        icon = Icons.fact_check_rounded;
        break;

      default:
        icon = Icons.quiz_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.22), secondary.withOpacity(0.16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(30),

        border: Border.all(color: primary.withOpacity(0.35), width: 1),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primary, size: 16),

          const SizedBox(width: 8),

          Text(
            type.replaceAll("_", " ").toUpperCase(),
            style: TextStyle(
              color: primary,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionTile(int i, String option, String? correctAnswer) {
    final isSelected = selectedAnswers[i] == option;

    final isCorrect =
        showResult && _cleanAnswer(correctAnswer) == _cleanAnswer(option);

    final isWrong = showResult && isSelected && !isCorrect;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 14),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCorrect
              ? [Colors.green.withOpacity(0.22), Colors.green.withOpacity(0.10)]
              : isWrong
              ? [Colors.red.withOpacity(0.20), Colors.red.withOpacity(0.08)]
              : isSelected
              ? [primary.withOpacity(0.22), secondary.withOpacity(0.12)]
              : [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          width: 1.3,
        ),

        boxShadow: [
          BoxShadow(
            color: isCorrect
                ? Colors.green.withOpacity(0.16)
                : isWrong
                ? Colors.red.withOpacity(0.16)
                : isSelected
                ? primary.withOpacity(0.18)
                : Colors.black.withOpacity(0.14),
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
              : () => setState(() => selectedAnswers[i] = option),

          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 30,
                  width: 30,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    gradient: isCorrect
                        ? const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          )
                        : isWrong
                        ? const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          )
                        : isSelected
                        ? LinearGradient(colors: [primary, secondary])
                        : null,

                    color: !isCorrect && !isWrong && !isSelected
                        ? Colors.white.withOpacity(0.08)
                        : null,

                    border: Border.all(
                      color: isCorrect
                          ? Colors.greenAccent
                          : isWrong
                          ? Colors.redAccent
                          : isSelected
                          ? primary
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),

                  child: Icon(
                    isCorrect
                        ? Icons.check_rounded
                        : isWrong
                        ? Icons.close_rounded
                        : isSelected
                        ? Icons.done_rounded
                        : Icons.circle_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      height: 1.4,

                      color: isCorrect
                          ? Colors.greenAccent.shade100
                          : isWrong
                          ? Colors.redAccent.shade100
                          : Colors.white.withOpacity(isSelected ? 1 : 0.88),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _answerField(int i) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        border: Border.all(color: primary.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        enabled: !showResult,
        onChanged: (value) => selectedAnswers[i] = value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: primary,
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
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(color: primary, width: 1.6),
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
      padding: const EdgeInsets.all(24),
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
        border: Border.all(color: primary.withOpacity(0.28)),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 30,
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
                  color: primary.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),

          const SizedBox(height: 18),

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
              fontSize: 64,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, secondary]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),

          Icon(
            Icons.check_circle_rounded,
            color: primary.withOpacity(0.9),
            size: 20,
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
            color: primary.withOpacity(0.10),
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

      child: child,
    );
  }

  Widget _gradientButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),

        gradient: const LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.35),
            blurRadius: 26,
            offset: const Offset(0, 12),
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
          borderRadius: BorderRadius.circular(26),
          onTap: loading ? null : onTap,

          child: Container(
            width: double.infinity,

            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),

            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    )
                  : Row(
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

                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
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
      ),
    );
  }
}
