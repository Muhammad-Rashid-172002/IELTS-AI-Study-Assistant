import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyproject/controller/feedback_controller/feedback_controller.dart';

class SpeakingPractice extends StatefulWidget {
  const SpeakingPractice({super.key});

  @override
  State<SpeakingPractice> createState() => _SpeakingPracticeState();
}

class _SpeakingPracticeState extends State<SpeakingPractice> {
  final IELTSController controller = Get.put(IELTSController());
  final stt.SpeechToText speech = stt.SpeechToText();

  bool isListening = false;
  String transcript = "";
  String aiQuestion = "";

  // TIMER
  int seconds = 0;
  Timer? timer;

  String topic = "Describe your favorite place";

  // =========================================
  // 🎯 AI QUESTION
  // =========================================
  Future<void> generateQuestion() async {
    controller.isLoading.value = true;

    try {
      final prompt = """
You are a professional IELTS Speaking Examiner.

Generate a REAL IELTS Speaking Part 2 Cue Card.

Topic: $topic

Return EXACT format:

{
 "topic": "...",
 "question": "...",
 "prompts": ["...", "...", "..."]
}
""";

      final result =
          await controller.api.feedback(prompt, "speaking");

      aiQuestion = result;
      transcript = "";

      startPreparationTimer();
      setState(() {});
    } catch (e) {
      Get.snackbar("Error", "AI Question Failed");
    }

    controller.isLoading.value = false;
  }

  // =========================================
  // 🎤 SPEECH
  // =========================================
  void toggleMic() async {
    if (!isListening) {
      bool available = await speech.initialize();

      if (available) {
        setState(() => isListening = true);

        speech.listen(onResult: (res) {
          setState(() {
            transcript = res.recognizedWords;
          });
        });

        startSpeakingTimer();
      }
    } else {
      speech.stop();
      setState(() => isListening = false);
    }
  }

  // =========================================
  // ⏱ TIMER
  // =========================================
  void startPreparationTimer() {
    seconds = 60; // 1 min prep
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds == 0) {
        t.cancel();
      } else {
        setState(() => seconds--);
      }
    });
  }

  void startSpeakingTimer() {
    seconds = 120; // 2 min speaking
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds == 0) {
        t.cancel();
        speech.stop();
        setState(() => isListening = false);
      } else {
        setState(() => seconds--);
      }
    });
  }

  // =========================================
  // 🤖 AI ANALYSIS
  // =========================================
  Future<void> analyze() async {
    if (transcript.isEmpty) {
      Get.snackbar("Error", "Speak first");
      return;
    }

    controller.isLoading.value = true;

    try {
      final prompt = """
Evaluate IELTS Speaking answer.

Return JSON:

{
 "band": "...",
 "fluency": "...",
 "lexical": "...",
 "grammar": "...",
 "improvement": "..."
}

Answer:
$transcript
""";

      final result =
          await controller.api.feedback(prompt, "speaking_eval");

      controller.speakingFeedback.value = result;

      await saveToFirebase(result);
    } catch (e) {
      Get.snackbar("Error", "AI Analysis Failed");
    }

    controller.isLoading.value = false;
  }

  // =========================================
  // 🔥 FIREBASE SAVE
  // =========================================
  Future<void> saveToFirebase(String result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("speaking_history")
        .add({
      "topic": topic,
      "answer": transcript,
      "feedback": result,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // =========================================
  // UI
  // =========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text("IELTS Speaking PRO"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _topicDropdown(),
            const SizedBox(height: 16),
            _generateBtn(),
            const SizedBox(height: 20),
            if (aiQuestion.isNotEmpty) _questionCard(),
            const SizedBox(height: 20),
            _timerUI(),
            const SizedBox(height: 20),
            _micUI(),
            const SizedBox(height: 20),
            _analyzeBtn(),
            const SizedBox(height: 20),
            _resultUI(),
          ],
        ),
      ),
    );
  }

  // =========================================
  Widget _topicDropdown() {
    return DropdownButtonFormField(
      value: topic,
      items: [
        "Describe your favorite place",
        "Describe a memorable trip",
        "Describe your hometown"
      ]
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) => setState(() => topic = v!),
    );
  }

  Widget _generateBtn() {
    return ElevatedButton(
      onPressed: generateQuestion,
      child: const Text("Generate IELTS Question"),
    );
  }

  Widget _questionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(aiQuestion),
      ),
    );
  }

  Widget _timerUI() {
    return Text(
      "Time Left: $seconds s",
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _micUI() {
    return GestureDetector(
      onTap: toggleMic,
      child: CircleAvatar(
        radius: 40,
        backgroundColor:
            isListening ? Colors.red : Colors.deepPurple,
        child: Icon(
          isListening ? Icons.stop : Icons.mic,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _analyzeBtn() {
    return ElevatedButton(
      onPressed: analyze,
      child: const Text("Analyze Speaking"),
    );
  }

  Widget _resultUI() {
    return Obx(() {
      if (controller.speakingFeedback.value.isEmpty) {
        return const SizedBox();
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(controller.speakingFeedback.value),
        ),
      );
    });
  }
}