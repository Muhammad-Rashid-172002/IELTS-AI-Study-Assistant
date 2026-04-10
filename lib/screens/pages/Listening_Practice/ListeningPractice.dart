import 'package:flutter/material.dart';
import 'package:fyproject/controller/feedback_controller/feedback_controller.dart';
import 'package:get/get.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ListeningPractice extends StatefulWidget {
  const ListeningPractice({super.key});

  @override
  State<ListeningPractice> createState() =>
      _ListeningPracticeState();
}

class _ListeningPracticeState
    extends State<ListeningPractice> {
  final IELTSController ieltsController =
      Get.put(IELTSController());

  final FlutterTts flutterTts = FlutterTts();

  String transcript = "";
  String audioScript = "";

  List<Map<String, dynamic>> questions = [];
  List<int?> selectedAnswers = [];

  bool generated = false;
  bool showResult = false;
  bool isPlaying = false;

  int score = 0;

  // =====================================================
  // GENERATE LISTENING TEST
  // =====================================================
  Future<void> generateListeningTest() async {
    ieltsController.isLoading.value = true;

    try {
      final prompt = """
Generate a real IELTS Listening Practice Test.

Format exactly like this:

TRANSCRIPT:
<short listening conversation transcript>

QUESTIONS:
1. Question text
A) Option A
B) Option B
C) Option C
D) Option D
ANSWER: A

2. Question text
A) Option A
B) Option B
C) Option C
D) Option D
ANSWER: B
""";

      final result = await ieltsController.api.feedback(
        prompt,
        "listening",
      );

      parseListeningResponse(result);

      setState(() {
        generated = true;
        showResult = false;
        score = 0;
      });
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to generate listening test",
      );
    }

    ieltsController.isLoading.value = false;
  }

  // =====================================================
  // PARSE AI RESPONSE
  // =====================================================
  void parseListeningResponse(String response) {
    questions.clear();
    selectedAnswers.clear();

    final parts = response.split("QUESTIONS:");

    if (parts.length < 2) {
      audioScript = "Failed to generate transcript.";
      return;
    }

    audioScript =
        parts[0].replaceFirst("TRANSCRIPT:", "").trim();

    final questionPart = parts[1].trim();

    final blocks =
        questionPart.split(RegExp(r'\n(?=\d+\.)'));

    for (var block in blocks) {
      final lines = block.trim().split("\n");

      if (lines.length >= 6) {
        String question = lines[0];

        List<String> options = [
          lines[1].replaceFirst("A) ", ""),
          lines[2].replaceFirst("B) ", ""),
          lines[3].replaceFirst("C) ", ""),
          lines[4].replaceFirst("D) ", ""),
        ];

        String correct =
            lines[5].replaceFirst("ANSWER:", "").trim();

        int correctIndex =
            ["A", "B", "C", "D"].indexOf(correct);

        questions.add({
          "question": question,
          "options": options,
          "correct": correctIndex,
        });

        selectedAnswers.add(null);
      }
    }
  }

  // =====================================================
  // PLAY AUDIO
  // =====================================================
  Future<void> playAudioScript() async {
    if (audioScript.isEmpty) return;

    setState(() => isPlaying = true);

    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.speak(audioScript);

    flutterTts.setCompletionHandler(() {
      setState(() => isPlaying = false);
    });
  }

  // =====================================================
  // STOP AUDIO
  // =====================================================
  Future<void> stopAudio() async {
    await flutterTts.stop();
    setState(() => isPlaying = false);
  }

  // =====================================================
  // SUBMIT ANSWERS + SAVE TO FIREBASE
  // =====================================================
  Future<void> submitAnswers() async {
    score = 0;

    List<int> correctAnswers = [];

    for (int i = 0; i < questions.length; i++) {
      correctAnswers.add(questions[i]["correct"]);

      if (selectedAnswers[i] ==
          questions[i]["correct"]) {
        score++;
      }
    }

    setState(() {
      showResult = true;
    });

    await saveResultToFirebase(correctAnswers);
  }

  // =====================================================
  // SAVE RESULT INTO USERS COLLECTION
  // users/{uid}/listening_results/{doc}
  // =====================================================
  Future<void> saveResultToFirebase(
      List<int> correctAnswers) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("listening_results")
        .add({
      "score": score,
      "totalQuestions": questions.length,
      "selectedAnswers":
          selectedAnswers.map((e) => e ?? -1).toList(),
      "correctAnswers": correctAnswers,
      "audioScript": audioScript,
      "timestamp": FieldValue.serverTimestamp(),
      "type": "listening",
    });
  }

  // =====================================================
  // FETCH PROGRESS FROM FIREBASE
  // =====================================================
  Future<List<Map<String, dynamic>>>
      fetchListeningProgress() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("listening_results")
        .orderBy("timestamp", descending: true)
        .get();

    return snapshot.docs
        .map((doc) => doc.data())
        .toList();
  }

  // =====================================================
  // DISPOSE
  // =====================================================
  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D5BFF),
        elevation: 0,
        title: const Text("AI Listening Practice"),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ListeningProgressScreen(),
                ),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _audioCard(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _generateButton(),
                  const SizedBox(height: 20),
                  if (generated) _questionsSection(),
                  if (generated)
                    const SizedBox(height: 20),
                  if (generated) _submitButton(),
                  if (showResult) _resultCard(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // =====================================================
  // AUDIO CARD
  // =====================================================
  Widget _audioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2D5BFF),
            Color(0xFF4A79F6),
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            "Section 1 - AI Generated Listening",
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Colors.white.withOpacity(0.2),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.volume_up,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI Audio Track",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Real AI Generated Audio",
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: isPlaying
                    ? stopAudio
                    : playAudioScript,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      Colors.white,
                  child: Icon(
                    isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // GENERATE BUTTON
  // =====================================================
  Widget _generateButton() {
    return Obx(() {
      return Container(
        height: 55,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF6A5AE0),
              Color(0xFF9D6BFF),
            ],
          ),
        ),
        child: TextButton(
          onPressed:
              ieltsController.isLoading.value
                  ? null
                  : generateListeningTest,
          child: Text(
            ieltsController.isLoading.value
                ? "Generating..."
                : "Generate AI Listening Test",
            style: const TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }

  // =====================================================
  // QUESTIONS
  // =====================================================
  Widget _questionsSection() {
    return Column(
      children: List.generate(
        questions.length,
        (index) {
          final q = questions[index];

          return Padding(
            padding:
                const EdgeInsets.only(bottom: 16),
            child: _questionTile(
              number: index + 1,
              title: q["question"],
              options:
                  List<String>.from(q["options"]),
              groupValue:
                  selectedAnswers[index],
              onChanged: (v) {
                setState(() {
                  selectedAnswers[index] = v;
                });
              },
            ),
          );
        },
      ),
    );
  }

  // =====================================================
  // SUBMIT BUTTON
  // =====================================================
  Widget _submitButton() {
    return Container(
      height: 55,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6A5AE0),
            Color(0xFF9D6BFF),
          ],
        ),
      ),
      child: TextButton(
        onPressed: submitAnswers,
        child: const Text(
          "Submit Answers",
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // =====================================================
  // RESULT CARD
  // =====================================================
  Widget _resultCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Text(
        "Score: $score / ${questions.length}",
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // =====================================================
  // QUESTION TILE
  // =====================================================
  Widget _questionTile({
    required int number,
    required String title,
    required List<String> options,
    required int? groupValue,
    required Function(int?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border:
            Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    Colors.green,
                child: Text(
                  "$number",
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(
            options.length,
            (index) {
              return RadioListTile<int>(
                value: index,
                groupValue: groupValue,
                onChanged: onChanged,
                title: Text(options[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =====================================================
// PROGRESS SCREEN
// =====================================================
class ListeningProgressScreen
    extends StatelessWidget {
  const ListeningProgressScreen({super.key});

  Future<List<Map<String, dynamic>>>
      getProgress() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("listening_results")
        .orderBy("timestamp", descending: true)
        .get();

    return snapshot.docs
        .map((e) => e.data())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text("Listening Progress")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: getProgress(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!;

          if (data.isEmpty) {
            return const Center(
              child: Text("No progress found"),
            );
          }

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];

              return Card(
                child: ListTile(
                  title: Text(
                    "Score: ${item["score"]} / ${item["totalQuestions"]}",
                  ),
                  subtitle: Text(
                    "Type: ${item["type"]}",
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}