import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fyproject/controller/feedback_controller/feedback_controller.dart';

class ListeningPractice extends StatefulWidget {
  const ListeningPractice({super.key});

  @override
  State<ListeningPractice> createState() => _ListeningPracticeState();
}

class _ListeningPracticeState extends State<ListeningPractice> {
  final IELTSController ieltsController = Get.put(IELTSController());
  final FlutterTts flutterTts = FlutterTts();

  String audioScript = "";
  List<Map<String, dynamic>> questions = [];
  List<int?> selectedAnswers = [];

  bool generated = false;
  bool showResult = false;
  bool isPlaying = false;
  bool isLoading = false;

  int score = 0;

  @override
  void initState() {
    super.initState();

    flutterTts.setCompletionHandler(() {
      setState(() => isPlaying = false);
    });
  }

  Timer? countdownTimer;

  int totalSeconds = 1800; // 30 minutes

  String get formattedTime {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;

    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  void startCountdown() {
    countdownTimer?.cancel();

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (totalSeconds > 0) {
        setState(() {
          totalSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // generateListeningTest

  Future<void> generateListeningTest() async {
    ieltsController.isLoading.value = true;

    try {
      final result = await ieltsController.api.generateListeningTest();
      parseListeningResponse(result);

      setState(() {
        generated = true;
        showResult = false;
        score = 0;
      });
    } catch (e) {
      Get.snackbar("Error", "Failed to generate test");
    } finally {
      ieltsController.isLoading.value = false;
    }
  }

  //  PARSE
  void parseListeningResponse(String response) {
    questions.clear();
    selectedAnswers.clear();

    final parts = response.split("QUESTIONS:");

    if (parts.length < 2) {
      audioScript = "Failed transcript.";
      return;
    }

    audioScript = parts[0].replaceFirst("TRANSCRIPT:", "").trim();

    final blocks = parts[1].trim().split(RegExp(r'\n(?=\d+\.)'));

    for (var block in blocks) {
      final lines = block.trim().split("\n");

      if (lines.length >= 6) {
        List<String> options = [
          lines[1].replaceFirst("A) ", ""),
          lines[2].replaceFirst("B) ", ""),
          lines[3].replaceFirst("C) ", ""),
          lines[4].replaceFirst("D) ", ""),
        ];

        String correct = lines[5].replaceFirst("ANSWER:", "").trim();
        int correctIndex = ["A", "B", "C", "D"].indexOf(correct);

        questions.add({
          "question": lines[0],
          "options": options,
          "correct": correctIndex,
        });

        selectedAnswers.add(null);
      }
    }
  }

  //  AUDIO
  Future<void> playAudio() async {
    if (audioScript.isEmpty) return;

    await flutterTts.stop();

    await flutterTts.setLanguage("en-GB");
    await flutterTts.setSpeechRate(0.45);

    setState(() => isPlaying = true);

    startCountdown();

    await flutterTts.speak(audioScript);
  }

  Future<void> stopAudio() async {
    await flutterTts.stop();

    countdownTimer?.cancel();

    setState(() => isPlaying = false);
  }

  // ================= SUBMIT =================
  Future<void> submitAnswers() async {
    score = 0;
    List<int> correctAnswers = [];

    for (int i = 0; i < questions.length; i++) {
      correctAnswers.add(questions[i]["correct"]);

      if (selectedAnswers[i] == questions[i]["correct"]) {
        score++;
      }
    }

    setState(() => showResult = true);
    await saveResultToFirebase(correctAnswers);
  }

  double calculateBandScore() {
    if (questions.isEmpty) return 0;

    double percent = score / questions.length;

    // IELTS approx mapping
    if (percent >= 0.9) return 9;
    if (percent >= 0.8) return 8;
    if (percent >= 0.7) return 7;
    if (percent >= 0.6) return 6;
    if (percent >= 0.5) return 5;
    return 4;
  }

  Future<void> saveResultToFirebase(List<int> correctAnswers) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("listening_results")
        .add({
          "score": score,
          "band": calculateBandScore(),
          "total": questions.length,
          "timestamp": FieldValue.serverTimestamp(),
        });
  }

  //  UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            const SizedBox(height: 10),

            if (!generated)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Obx(
                  () => GestureDetector(
                    onTap: ieltsController.isLoading.value
                        ? null
                        : generateListeningTest,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff2F6BFF), Color(0xff7B2CFF)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: ieltsController.isLoading.value
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "Generate Test",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

            if (generated)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _audioCard(),
                      _progress(),
                      _questions(),
                      const SizedBox(height: 20),
                      _submitButton(),
                      if (showResult) _resultCard(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  //  HEADER
  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 50, 18, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff2F6BFF), Color(0xff7B2CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOP BAR
          Row(
            children: [
              // BACK BUTTON
              GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // TITLE
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Listening Practice",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 4),

                    Text(
                      " Social Context",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // HEADPHONE ICON
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headphones,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // INFO SECTION
          Row(
            children: [
              Expanded(
                child: _listeningInfoCard(
                  Icons.timer_outlined,
                  "Duration",
                  formattedTime,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _listeningInfoCard(
                  Icons.multitrack_audio,
                  "Audio",
                  "AI Generated",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listeningInfoCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  } //  AUDIO CARD

  Widget _audioCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff4A7BFF), Color(0xff6A5BFF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.volume_up, color: Colors.white),
              SizedBox(width: 10),
              Text(
                "Audio Track 1",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 20),
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle : Icons.play_circle,
              color: Colors.white,
              size: 50,
            ),
            onPressed: isPlaying ? stopAudio : playAudio,
          ),
        ],
      ),
    );
  }

  //  PROGRESS
  Widget _progress() {
    int answered = selectedAnswers.where((e) => e != null).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Questions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text("$answered of ${questions.length} answered"),
        ],
      ),
    );
  }

  //  QUESTIONS
  Widget _questions() {
    return Column(
      children: List.generate(questions.length, (i) {
        final q = questions[i];

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.green),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q["question"],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              ...List.generate(4, (index) {
                return RadioListTile<int>(
                  value: index,
                  groupValue: selectedAnswers[i],
                  onChanged: (v) {
                    setState(() {
                      selectedAnswers[i] = v;
                    });
                  },
                  title: Text(q["options"][index]),
                );
              }),
            ],
          ),
        );
      }),
    );
  }

  //  SUBMIT
  Widget _submitButton() {
    return GestureDetector(
      onTap: submitAnswers,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff2F6BFF), Color(0xffB721FF)],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Center(
          child: Text(
            "Submit Answers",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }

  //  RESULT
  Widget _resultCard() {
    double band = calculateBandScore();

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            "Your Band Score",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            band.toString(),
            style: const TextStyle(
              fontSize: 40,
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Score: $score / ${questions.length}",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
