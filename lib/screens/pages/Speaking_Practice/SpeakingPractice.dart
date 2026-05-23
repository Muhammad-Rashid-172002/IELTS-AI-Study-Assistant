import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fyproject/services/ai_service.dart';

class SpeakingPractice extends StatefulWidget {
  const SpeakingPractice({super.key});

  @override
  State<SpeakingPractice> createState() => _SpeakingPracticeState();
}

class _SpeakingPracticeState extends State<SpeakingPractice> {
  final AIService ai = AIService();
  final SpeechToText speech = SpeechToText();
  final FlutterTts tts = FlutterTts();
  final AudioRecorder recorder = AudioRecorder();

  bool isRecording = false;
  bool isGeneratingTopic = false;
  bool isAnalyzing = false;

  String topicTitle = "Generate your IELTS speaking topic";
  List<String> points = [];
  List<String> followUps = [];

  String transcript = "";
  String band = "";
  String fluency = "";
  String lexical = "";
  String grammar = "";
  String pronunciation = "";
  String improvement = "";
  String strengths = "";
  String mistakes = "";
  String pronunciationTips = "";
  String fluencyTips = "";
  String improvedAnswer = "";

  int seconds = 0;
  Timer? timer;
  String? audioPath;
  Map<String, dynamic> speakingTest = {};
  String selectedPart = "part2";

  List<String> part1Questions = [];
  List<String> part3Questions = [];

  List recordings = [];

  Color get primary => const Color(0xFF14B8A6);
  Color get secondary => const Color(0xFF0F766E);
  Color get bg => const Color(0xFF08111F);

  @override
  void initState() {
    super.initState();
    generateFullSpeakingTest();
    loadRecordings();
  }

  @override
  void dispose() {
    timer?.cancel();
    speech.stop();
    tts.stop();
    recorder.dispose();
    super.dispose();
  }

  Future<void> generateFullSpeakingTest() async {
    if (isGeneratingTopic) return;

    setState(() => isGeneratingTopic = true);

    try {
      final data = await ai.generateSpeakingTest();

      final part1 = data["part1"] as Map<String, dynamic>? ?? {};
      final part2 = data["part2"] as Map<String, dynamic>? ?? {};
      final part3 = data["part3"] as Map<String, dynamic>? ?? {};

      setState(() {
        speakingTest = data;

        part1Questions = List<String>.from(part1["questions"] ?? []);
        topicTitle = part2["cue_card"] ?? "Describe an interesting place.";
        points = List<String>.from(part2["points"] ?? []);
        part3Questions = List<String>.from(part3["questions"] ?? []);

        selectedPart = "part2";

        transcript = "";
        band = "";
        fluency = "";
        lexical = "";
        grammar = "";
        pronunciation = "";
        improvement = "";
        seconds = 0;
      });

      await speakTopic();
    } catch (e) {
      _showInternetDialog();
    } finally {
      if (mounted) setState(() => isGeneratingTopic = false);
    }
  }

  Future<void> generateTopic() async {
    if (isGeneratingTopic) return;

    setState(() => isGeneratingTopic = true);

    try {
      final data = await ai.generateSpeakingTopic();

      setState(() {
        topicTitle =
            data["topic"] ?? "Describe an important event in your life.";
        points = List<String>.from(data["points"] ?? []);
        followUps = List<String>.from(data["follow_up_questions"] ?? []);
        transcript = "";
        band = "";
        fluency = "";
        lexical = "";
        grammar = "";
        pronunciation = "";
        improvement = "";
        seconds = 0;
      });

      await speakTopic();
    } catch (e) {
      _showInternetDialog();
    } finally {
      if (mounted) setState(() => isGeneratingTopic = false);
    }
  }

  Future<void> speakTopic() async {
    await tts.stop();
    await tts.setLanguage("en-GB");
    await tts.setSpeechRate(0.43);
    await tts.speak(topicTitle);
  }

  Future<void> startRecording() async {
    try {
      final speechAvailable = await speech.initialize();
      final micPermission = await recorder.hasPermission();

      if (!speechAvailable || !micPermission) {
        _showError("Microphone permission required.");
        return;
      }

      setState(() {
        isRecording = true;
        transcript = "";
        seconds = 0;
      });

      speech.listen(
        partialResults: true,
        listenMode: ListenMode.dictation,
        onResult: (res) {
          if (!mounted) return;
          setState(() => transcript = res.recognizedWords);
        },
      );

      final dir = await getApplicationDocumentsDirectory();
      audioPath =
          "${dir.path}/speaking_${DateTime.now().millisecondsSinceEpoch}.m4a";

      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: audioPath!,
      );

      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => seconds++);
      });
    } catch (e) {
      _showError("Recording failed. Please try again.");
    }
  }

  Future<void> stopRecording() async {
    try {
      timer?.cancel();
      await speech.stop();
      final path = await recorder.stop();

      setState(() {
        isRecording = false;
        audioPath = path;
      });

      if (transcript.trim().isEmpty) {
        _showCustomError(
          title: "No Speech Detected",
          message: "Please speak clearly and try again.",
        );
        return;
      }

      await analyzeSpeaking();
    } catch (e) {
      _showCustomError(
        title: "Recording Failed",
        message: "Failed to stop recording. Please try again.",
      );
    }
  }

  Future<void> analyzeSpeaking() async {
    if (isAnalyzing) return;

    setState(() => isAnalyzing = true);

    try {
      final result = await ai.evaluateSpeaking(
        transcript: transcript,
        durationSeconds: seconds,
      );

      setState(() {
        /// OVERALL BAND
        band = result["overall_band"]?.toString() ?? "0";

        /// IELTS CRITERIA
        fluency = result["fluency_coherence"]?["feedback"] ?? "";

        lexical = result["lexical_resource"]?["feedback"] ?? "";

        grammar = result["grammar"]?["feedback"] ?? "";

        pronunciation = result["pronunciation"]?["feedback"] ?? "";

        /// EXTRA AI FEEDBACK
        strengths = result["strengths"]?.toString() ?? "";

        mistakes = result["mistakes"]?.toString() ?? "";

        pronunciationTips = result["pronunciation_tips"]?.toString() ?? "";

        fluencyTips = result["fluency_tips"]?.toString() ?? "";

        improvedAnswer = result["improved_answer"]?.toString() ?? "";

        improvement = result["examiner_advice"]?.toString() ?? "";
      });

      await saveToFirebase();
      await loadRecordings();
    } catch (e) {
      _showInternetDialog();
    } finally {
      if (mounted) {
        setState(() => isAnalyzing = false);
      }
    }
  }

  Future<void> saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("speaking")
        .add({
          "topic": topicTitle,
          "points": points,
          "transcript": transcript,
          "band": band,
          "duration": seconds,
          "fluency": fluency,
          "lexical": lexical,
          "grammar": grammar,
          "pronunciation": pronunciation,
          "improvement": improvement,
          "createdAt": FieldValue.serverTimestamp(),
        });
  }

  Future<void> loadRecordings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("speaking")
        .orderBy("createdAt", descending: true)
        .limit(5)
        .get();

    if (mounted) {
      setState(() => recordings = data.docs);
    }
  }

  void _showInternetDialog() {
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
                color: primary.withOpacity(0.28),
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
                height: 86,
                width: 86,
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
              const Text(
                "Connection Problem",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 14),

              /// MESSAGE
              Text(
                "Your internet connection is not working properly or the AI speaking examiner is unavailable. Please check your network and try again.",
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
                        generateFullSpeakingTest();
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _topicCard(),
                  const SizedBox(height: 16),
                  _recordCard(),
                  const SizedBox(height: 16),
                  if (isAnalyzing) _analyzingCard(),
                  if (band.isNotEmpty) _resultCard(),
                  const SizedBox(height: 16),
                  _history(),
                  const SizedBox(height: 20),
                  // _gradientButton(
                  //   text: isGeneratingTopic
                  //       ? "Generating..."
                  //       : "New Speaking Test",

                  //   icon: isGeneratingTopic
                  //       ? Icons.hourglass_top_rounded
                  //       : Icons.refresh_rounded,

                  //   onTap: isGeneratingTopic ? null : generateFullSpeakingTest,

                  //   loading: isGeneratingTopic,
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 52, 18, 24),
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
                Icons.arrow_back_ios_new,
                () => Navigator.pop(context),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "IELTS Speaking",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      "AI examiner practice test",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              _circleButton(Icons.mic_rounded, () {}),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _infoCard("Duration", "$seconds sec", Icons.timer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  "Band",
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

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  Widget _infoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
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

  Widget _topicCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _partTabs(),
          const SizedBox(height: 16),

          if (selectedPart == "part1") ...[
            _cardTitle(Icons.chat_bubble_outline, "Part 1 - Introduction"),
            const SizedBox(height: 12),
            ...part1Questions.map((q) => _questionTile(q)),
          ],

          if (selectedPart == "part2") ...[
            _cardTitle(Icons.topic_outlined, "Part 2 - Cue Card"),
            const SizedBox(height: 12),
            Text(
              topicTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...points.map((p) => _questionTile(p)),
            const SizedBox(height: 8),
            Text(
              "You have 1 minute to prepare and 2 minutes to speak.",
              style: TextStyle(color: Colors.white.withOpacity(0.60)),
            ),
          ],

          if (selectedPart == "part3") ...[
            _cardTitle(Icons.forum_outlined, "Part 3 - Discussion"),
            const SizedBox(height: 12),
            ...part3Questions.map((q) => _questionTile(q)),
          ],
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
      ],
    );
  }

  Widget _partButton(String title, String value) {
    final bool selected = selectedPart == value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),

      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: [primary, secondary, const Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.07),
                  Colors.white.withOpacity(0.03),
                ],
              ),

        borderRadius: BorderRadius.circular(22),

        border: Border.all(
          color: selected ? Colors.transparent : Colors.white.withOpacity(0.08),
          width: 1.2,
        ),

        boxShadow: [
          BoxShadow(
            color: selected
                ? primary.withOpacity(0.35)
                : Colors.black.withOpacity(0.10),

            blurRadius: selected ? 22 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(22),

          onTap: () {
            setState(() {
              selectedPart = value;
              transcript = "";
              seconds = 0;
            });
          },

          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),

                  padding: const EdgeInsets.all(10),

                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.18)
                        : Colors.white.withOpacity(0.06),

                    shape: BoxShape.circle,
                  ),

                  child: Icon(
                    value == "part1"
                        ? Icons.chat_bubble_outline_rounded
                        : value == "part2"
                        ? Icons.topic_outlined
                        : Icons.forum_outlined,

                    color: selected
                        ? Colors.white
                        : Colors.white.withOpacity(0.60),

                    size: 20,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  title,
                  textAlign: TextAlign.center,

                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withOpacity(0.60),

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

  Widget _questionTile(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: primary, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordCard() {
    return _whiteCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isRecording
                  ? Colors.redAccent.withOpacity(0.12)
                  : primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRecording
                    ? Colors.redAccent.withOpacity(0.30)
                    : primary.withOpacity(0.25),
              ),
            ),
            child: Text(
              isRecording ? "LIVE RECORDING" : "SPEAKING PRACTICE",
              style: TextStyle(
                color: isRecording ? Colors.redAccent : primary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ),

          const SizedBox(height: 22),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isRecording
                    ? [Colors.redAccent, Colors.deepOrange]
                    : [primary, secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isRecording ? Colors.redAccent : primary).withOpacity(
                    0.38,
                  ),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(
              isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 58,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            isRecording ? "Recording your answer..." : "Ready to record",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "$seconds sec",
            style: TextStyle(
              color: Colors.white.withOpacity(0.60),
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 22),

          _gradientButton(
            text: isRecording ? "Stop Recording" : "Start Recording",
            icon: isRecording ? Icons.stop_rounded : Icons.mic_rounded,
            onTap: isAnalyzing
                ? null
                : (isRecording ? stopRecording : startRecording),
            colors: isRecording
                ? [Colors.redAccent, Colors.deepOrange]
                : [primary, secondary],
          ),

          if (transcript.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Live Transcript",
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    transcript,
                    style: TextStyle(
                      height: 1.6,
                      color: Colors.white.withOpacity(0.84),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _analyzingCard() {
    return _whiteCard(
      child: Row(
        children: [
          CircularProgressIndicator(color: primary),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              "AI examiner is checking your speaking answer...",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final bandValue = double.tryParse(band) ?? 0.0;
    final progress = (bandValue / 9).clamp(0.0, 1.0);

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.workspace_premium_rounded, "Speaking Result"),

          const SizedBox(height: 22),

          Center(
            child: Container(
              height: 120,
              width: 120,
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
              child: Center(
                child: Text(
                  band,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: _speakingStat(
                  icon: Icons.timer_outlined,
                  title: "Duration",
                  value: "$seconds sec",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _speakingStat(
                  icon: Icons.mic_rounded,
                  title: "Status",
                  value: "Analyzed",
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _feedbackTile("Fluency & Coherence", fluency),

          _feedbackTile("Lexical Resource", lexical),

          _feedbackTile("Grammar Range & Accuracy", grammar),

          _feedbackTile("Pronunciation", pronunciation),

          _feedbackTile("Strengths", strengths),

          _feedbackTile("Mistakes", mistakes),

          _feedbackTile("Pronunciation Tips", pronunciationTips),

          _feedbackTile("Fluency Tips", fluencyTips),

          _feedbackTile("Improved Answer", improvedAnswer),

          _feedbackTile("Examiner Advice", improvement),
        ],
      ),
    );
  }

  Widget _speakingStat({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
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

  Widget _feedbackTile(String title, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(26),

        border: Border.all(color: primary.withOpacity(0.14), width: 1.1),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),

                  borderRadius: BorderRadius.circular(14),

                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),

              borderRadius: BorderRadius.circular(20),

              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),

            child: Text(
              value,
              style: TextStyle(
                height: 1.75,
                fontSize: 14.8,
                color: Colors.white.withOpacity(0.84),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _history() {
    if (recordings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),

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
                Icons.history_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Text(
                "Recent Practice",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        ...recordings.map((e) {
          final data = e.data() as Map<String, dynamic>;

          final topic = data["topic"] ?? "Speaking Practice";
          final bandScore = data["band"] ?? "--";

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

              borderRadius: BorderRadius.circular(28),

              border: Border.all(color: primary.withOpacity(0.12)),

              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),

                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 62,
                  width: 62,

                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),

                    borderRadius: BorderRadius.circular(20),

                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.30),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),

                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),

                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.14),

                              borderRadius: BorderRadius.circular(18),

                              border: Border.all(
                                color: Colors.green.withOpacity(0.25),
                              ),
                            ),

                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Colors.greenAccent,
                                  size: 16,
                                ),

                                const SizedBox(width: 6),

                                Text(
                                  "Band $bandScore",
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          Text(
                            "AI Evaluated",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.35),
                  size: 18,
                ),
              ],
            ),
          );
        }),
      ],
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

        border: Border.all(color: primary.withOpacity(0.14), width: 1.2),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),

      child: child,
    );
  }

  Widget _cardTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primary, secondary]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradientButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
    List<Color>? colors,
  }) {
    final bool isDisabled = onTap == null || loading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isDisabled && !loading
              ? [Colors.grey.shade700, Colors.grey.shade600]
              : colors ?? [primary, secondary, const Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDisabled
                ? Colors.black.withOpacity(0.12)
                : primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: isDisabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            child: Center(
              child: loading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Please wait...",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            text,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  //
  void _showCustomError({required String title, required String message}) {
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
                color: Colors.redAccent.withOpacity(0.25),
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
                height: 84,
                width: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.redAccent, Colors.deepOrange],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.40),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
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
                  fontSize: 24,
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

              /// BUTTON
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "OK",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






// add in ai result

// strengths
// mistakes
// pronunciation_tips
// fluency_tips
// improved_answer