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

  int seconds = 0;
  Timer? timer;
  String? audioPath;

  List recordings = [];

  Color get primary => const Color(0xff14B8A6);
  Color get secondary => const Color(0xff2563EB);
  Color get bg => const Color(0xffF6F8FC);

  @override
  void initState() {
    super.initState();
    generateTopic();
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

  Future<void> generateTopic() async {
    if (isGeneratingTopic) return;

    setState(() => isGeneratingTopic = true);

    try {
      final data = await ai.generateSpeakingTopic();

      setState(() {
        topicTitle = data["topic"] ?? "Describe an important event in your life.";
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
      audioPath = "${dir.path}/speaking_${DateTime.now().millisecondsSinceEpoch}.m4a";

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
        _showError("No speech detected. Please speak clearly and try again.");
        return;
      }

      await analyzeSpeaking();
    } catch (e) {
      _showError("Failed to stop recording.");
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
        band = result["overall_band"]?.toString() ?? "0";
        fluency = result["fluency_coherence"]?["feedback"] ?? "";
        lexical = result["lexical_resource"]?["feedback"] ?? "";
        grammar = result["grammar"]?["feedback"] ?? "";
        pronunciation = result["pronunciation"]?["feedback"] ?? "";
        improvement = result["examiner_advice"] ?? "";
      });

      await saveToFirebase();
      await loadRecordings();
    } catch (e) {
      _showInternetDialog();
    } finally {
      if (mounted) setState(() => isAnalyzing = false);
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text("Connection Problem"),
        content: const Text(
          "Your internet connection is not working properly. Please check your network and try again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              generateTopic();
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
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
                  _gradientButton(
                    text: isGeneratingTopic ? "Generating..." : "Next Speaking Topic",
                    icon: Icons.refresh_rounded,
                    onTap: isGeneratingTopic ? null : generateTopic,
                    loading: isGeneratingTopic,
                  ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, secondary]),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
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
              Expanded(child: _infoCard("Duration", "$seconds sec", Icons.timer)),
              const SizedBox(width: 12),
              Expanded(child: _infoCard("Band", band.isEmpty ? "--" : band, Icons.auto_graph)),
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
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
          _cardTitle(Icons.topic_outlined, "Cue Card Topic"),
          const SizedBox(height: 12),
          Text(
            topicTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xff111827),
            ),
          ),
          const SizedBox(height: 12),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: primary, size: 19),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "You have 1 minute to prepare and 2 minutes to speak.",
            style: TextStyle(color: Color(0xff6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _recordCard() {
    return _whiteCard(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 110,
            width: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isRecording
                    ? [Colors.redAccent, Colors.deepOrange]
                    : [primary, secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isRecording ? Colors.red : primary).withOpacity(0.30),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 54,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isRecording ? "Recording your answer..." : "Ready to record",
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text("$seconds sec", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 18),
          _gradientButton(
            text: isRecording ? "Stop Recording" : "Start Recording",
            icon: isRecording ? Icons.stop : Icons.mic,
            onTap: isAnalyzing ? null : (isRecording ? stopRecording : startRecording),
            colors: isRecording
                ? [Colors.redAccent, Colors.deepOrange]
                : [primary, secondary],
          ),
          if (transcript.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xffF3F4F6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                transcript,
                style: const TextStyle(height: 1.4),
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
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.workspace_premium_outlined, "Speaking Result"),
          const SizedBox(height: 14),
          Center(
            child: Text(
              band,
              style: TextStyle(
                fontSize: 52,
                color: primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _feedbackTile("Fluency", fluency),
          _feedbackTile("Lexical", lexical),
          _feedbackTile("Grammar", grammar),
          _feedbackTile("Pronunciation", pronunciation),
          _feedbackTile("Advice", improvement),
        ],
      ),
    );
  }

  Widget _feedbackTile(String title, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xffF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        "$title: $value",
        style: const TextStyle(height: 1.4),
      ),
    );
  }

  Widget _history() {
    if (recordings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recent Practice",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...recordings.map((e) {
          final data = e.data() as Map<String, dynamic>;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.play_circle_fill, color: primary, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data["topic"] ?? "Speaking Practice",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text("Band ${data["band"] ?? "--"}"),
                  backgroundColor: Colors.green.shade100,
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

  Widget _cardTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors ?? [primary, secondary],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.3,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}