import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyproject/services/ai_service.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SpeakingPractice extends StatefulWidget {
  const SpeakingPractice({super.key});

  @override
  State<SpeakingPractice> createState() => _SpeakingPracticeState();
}

class _SpeakingPracticeState extends State<SpeakingPractice> {
  final SpeechToText speech = SpeechToText();
  final FlutterTts tts = FlutterTts();

  bool isRecording = false;
  String transcript = "";
  String topic = "Loading topic...";
  int seconds = 0;
  Timer? timer;
  bool isGeneratingTopic = false;
  bool isAnalyzing = false;

  List recordings = [];
  String band = "";
  final AudioRecorder recorder = AudioRecorder();
  String? audioPath;

  //  AI TOPIC GENERATOR

  final ai = AIService();

  Future<void> generateTopic() async {
    if (isGeneratingTopic) return;

    isGeneratingTopic = true;

    try {
      final data = await ai.generateSpeakingTopic();

      if (!mounted) return;

      setState(() {
        topic =
            "${data["topic"]}\n\n"
            "• ${data["points"][0]}\n"
            "• ${data["points"][1]}\n"
            "• ${data["points"][2]}\n"
            "• ${data["points"][3]}";
      });

      await speakQuestion();
    } catch (e) {
      debugPrint("TOPIC ERROR: $e");
    } finally {
      isGeneratingTopic = false;
    }
  }

  //  START RECORDING

  Future<void> startRecording() async {
    try {
      bool speechAvailable = await speech.initialize();
      bool micPermission = await recorder.hasPermission();

      if (!speechAvailable || !micPermission) {
        debugPrint("Permission denied");
        return;
      }

      setState(() {
        isRecording = true;
        seconds = 0;
        transcript = "";
      });

   speech.listen(
  partialResults: false,
  onResult: (res) {
    if (!mounted) return;

    setState(() {
      transcript = res.recognizedWords;
    });
  },
);

      // SAFE STORAGE PATH
      final dir = await getApplicationDocumentsDirectory();

      audioPath =
          '${dir.path}/speaking_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: audioPath!,
      );

      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          seconds++;
        });
      });
    } catch (e) {
      debugPrint("Recording Error: $e");
    }
  }

  //  STOP RECORDING

  Future<void> stopRecording() async {
    try {
      timer?.cancel();

      await speech.stop();

      final path = await recorder.stop();

      setState(() {
        isRecording = false;
        audioPath = path;
      });

      if (transcript.trim().isNotEmpty && !isAnalyzing) {
        await analyzeSpeaking();
      }
    } catch (e) {
      debugPrint("Stop Error: $e");
    }
  }

  //  AI ANALYSIS

  Future<void> analyzeSpeaking() async {
    if (isAnalyzing) return;

    isAnalyzing = true;

    try {
      final result = await ai.evaluateSpeaking(transcript, seconds);

      if (!mounted) return;

      setState(() {
        band = result["band"] ?? "0";
      });

      final fluency = result["fluency"] ?? "";
      final lexical = result["lexical"] ?? "";
      final grammar = result["grammar"] ?? "";
      final pronunciation = result["pronunciation"] ?? "";
      final improvement = result["improvement"] ?? "";

      await saveToFirebaseExtra(
        fluency,
        lexical,
        grammar,
        pronunciation,
        improvement,
      );

      loadRecordings();
    } catch (e) {
      debugPrint("ANALYZE ERROR: $e");
    } finally {
      isAnalyzing = false;
    }
  }

  Future<void> saveToFirebaseExtra(
    String fluency,
    String lexical,
    String grammar,
    String pronunciation,
    String improvement,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("speaking")
        .add({
          "topic": topic,
          "transcript": transcript,
          "band": band,
          "duration": seconds,
          "fluency": fluency,
          "lexical": lexical,
          "grammar": grammar,
          "pronunciation": pronunciation,
          "improvement": improvement,
          "createdAt": Timestamp.now(),
        });
  }

  // FIREBASE SAVE

  Future<void> saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("speaking")
        .add({
          "topic": topic,
          "transcript": transcript,
          "band": band,
          "duration": seconds,
          "createdAt": Timestamp.now(),
        });
  }

  //  LOAD RECORDINGS

  void loadRecordings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("speaking")
        .orderBy("createdAt", descending: true)
        .get();

    setState(() {
      recordings = data.docs;
    });
  }

  //  SPEAK QUESTION

  Future speakQuestion() async {
    await tts.speak(topic);
  }

  @override
  void initState() {
    super.initState();
    generateTopic();
    loadRecordings();
  }

  // UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: Stack(
        children: [
          Column(
            children: [
              _topHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _topicCard(),
                      const SizedBox(height: 20),
                      _micSection(),
                      const SizedBox(height: 20),
                      _recordings(),
                      const SizedBox(height: 20),
                      _nextButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Speaking",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text("Speaking", style: TextStyle(color: Colors.white70)),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _infoCard("Duration", "$seconds sec", Icons.timer),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _infoCard(
                  "AI Score",
                  band.isEmpty ? "--" : band,
                  Icons.auto_graph,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
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

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),

              const SizedBox(height: 4),

              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topicCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Topic ",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(topic, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          const Text(
            "You will have 1 minute to prepare and 2 minutes to speak.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // MIC UI

  Widget _micSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          //  MIC ICON (JUST VISUAL)
          CircleAvatar(
            radius: 55,
            backgroundColor: isRecording
                ? Colors.teal.withOpacity(0.3)
                : Colors.teal,
            child: const Icon(Icons.mic, size: 50, color: Colors.white),
          ),

          const SizedBox(height: 15),

          Text(
            isRecording ? "Recording..." : "Ready to record",
            style: const TextStyle(fontSize: 16),
          ),

          const SizedBox(height: 5),

          Text(
            "$seconds sec",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          //  START BUTTON
          if (!isRecording)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isAnalyzing ? null : startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  "Start Recording",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),

          //  STOP BUTTON
          if (isRecording)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isAnalyzing ? null : stopRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  "Stop Recording",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  } 

  // RECORDINGS
  // ======================
  Widget _recordings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Your Recordings",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        ...recordings.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP ROW
                Row(
                  children: [
                    const Icon(
                      Icons.play_circle_fill,
                      size: 40,
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${e['topic'] ?? 'No Topic'}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text("${e['duration']} sec"),
                        ],
                      ),
                    ),

                    Chip(
                      label: Text("Band ${e['band']}"),
                      backgroundColor: Colors.green.shade100,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // IELTS BREAKDOWN
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _scoreChip("Fluency", e['fluency']),
                    _scoreChip("Lexical", e['lexical']),
                    _scoreChip("Grammar", e['grammar']),
                    _scoreChip("Pronunciation", e['pronunciation']),
                  ],
                ),

                const SizedBox(height: 10),

                // IMPROVEMENT
                if (e['improvement'] != null)
                  Text(
                    " ${e['improvement']}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _scoreChip(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text("$title: $value", style: const TextStyle(fontSize: 12)),
    );
  }

  // ======================
  // NEXT BUTTON
  // ======================
  Widget _nextButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F9D8A), Color(0xFF1E6CE3)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ElevatedButton(
        onPressed: isGeneratingTopic ? null : generateTopic,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.all(16),
        ),
        child: const Text("Next Question", style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
