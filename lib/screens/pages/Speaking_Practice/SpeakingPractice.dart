import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

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

  final Color primary = const Color(0xFF2DD4BF);
  final Color primaryDark = const Color(0xFF0F766E);
  final Color accent = const Color(0xFF38BDF8);
  final Color background = const Color(0xFF07111F);
  final Color surface = const Color(0xFF0E1A2B);

  bool isRecording = false;
  bool isGeneratingTopic = false;
  bool isAnalyzing = false;
  bool isOfflineMode = false;
  bool isSpeakingTopic = false;

  String selectedPart = 'part2';
  String topicTitle = 'Your IELTS speaking test will appear here.';
  List<String> part1Questions = [];
  List<String> cueCardPoints = [];
  List<String> part3Questions = [];
  Map<String, dynamic> speakingTest = {};

  String transcript = '';
  String band = '';
  String fluency = '';
  String lexical = '';
  String grammar = '';
  String pronunciation = '';
  String examinerAdvice = '';
  String strengths = '';
  String mistakes = '';
  String pronunciationTips = '';
  String fluencyTips = '';
  String improvedAnswer = '';

  int seconds = 0;
  Timer? timer;
  String? audioPath;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> recordings = [];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await Future.wait([
      generateFullSpeakingTest(showSuccess: false),
      loadRecordings(),
    ]);
  }

  @override
  void dispose() {
    timer?.cancel();
    speech.stop();
    tts.stop();
    recorder.dispose();
    super.dispose();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  DocumentReference<Map<String, dynamic>>? get _cachedTestReference {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cached_tests')
        .doc('speaking_full_test');
  }

  Future<void> generateFullSpeakingTest({bool showSuccess = true}) async {
    if (isGeneratingTopic || isRecording || isAnalyzing) return;

    if (mounted) {
      setState(() => isGeneratingTopic = true);
    }

    final online = await _hasInternet();

    if (!online) {
      final loaded = await _loadCachedSpeakingTest();
      if (!loaded && mounted) {
        _showConnectionDialog(
          title: 'No Internet Connection',
          message:
              'A saved speaking test is not available on this device. Connect to the internet to generate your first IELTS speaking test.',
          retry: () => generateFullSpeakingTest(showSuccess: showSuccess),
        );
      }
      if (mounted) setState(() => isGeneratingTopic = false);
      return;
    }

    try {
      final data = await ai.generateSpeakingTest().timeout(
        const Duration(seconds: 45),
      );

      _applySpeakingTest(data, offline: false);
      await _saveSpeakingTestToFirebase(data);

      if (showSuccess && mounted) {
        _showSnack(
          title: 'New Test Ready',
          message: 'A complete IELTS speaking test has been generated.',
          type: _SnackType.success,
        );
      }
    } on TimeoutException {
      await _handleGenerationFailure(
        title: 'Request Timed Out',
        message:
            'The AI service took too long to respond. A saved test will be loaded when available.',
      );
    } catch (error) {
      final message = error.toString().toLowerCase();
      String title = 'Speaking Test Unavailable';
      String description =
          'The speaking test could not be generated. A saved test will be loaded when available.';

      if (message.contains('403') || message.contains('permission')) {
        title = 'AI Permission Error';
        description =
            'The AI service is not authorized for this request. Please check your API configuration.';
      } else if (message.contains('429') || message.contains('quota')) {
        title = 'AI Usage Limit Reached';
        description =
            'The AI request limit has been reached. Please try again later.';
      }

      await _handleGenerationFailure(title: title, message: description);
    } finally {
      if (mounted) setState(() => isGeneratingTopic = false);
    }
  }

  Future<void> _handleGenerationFailure({
    required String title,
    required String message,
  }) async {
    final loaded = await _loadCachedSpeakingTest();
    if (!loaded && mounted) {
      _showConnectionDialog(
        title: title,
        message: message,
        retry: generateFullSpeakingTest,
      );
    }
  }

  void _applySpeakingTest(Map<String, dynamic> data, {required bool offline}) {
    final part1 = Map<String, dynamic>.from(data['part1'] ?? {});
    final part2 = Map<String, dynamic>.from(data['part2'] ?? {});
    final part3 = Map<String, dynamic>.from(data['part3'] ?? {});

    if (!mounted) return;
    setState(() {
      speakingTest = data;
      part1Questions = List<String>.from(part1['questions'] ?? []);
      topicTitle = part2['cue_card']?.toString().trim().isNotEmpty == true
          ? part2['cue_card'].toString()
          : 'Describe an interesting experience that you remember clearly.';
      cueCardPoints = List<String>.from(part2['points'] ?? []);
      part3Questions = List<String>.from(part3['questions'] ?? []);
      selectedPart = 'part2';
      isOfflineMode = offline;
      _clearEvaluation(resetTranscript: true);
    });
  }

  Future<void> _saveSpeakingTestToFirebase(Map<String, dynamic> data) async {
    final reference = _cachedTestReference;
    if (reference == null) return;

    try {
      await reference.set({
        'testData': data,
        'testType': 'speaking',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Firestore persistence can still retain pending writes locally.
    }
  }

  Future<bool> _loadCachedSpeakingTest() async {
    final reference = _cachedTestReference;
    if (reference == null) return false;

    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await reference.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await reference.get(const GetOptions(source: Source.cache));
      }

      final data = snapshot.data();
      final rawTest = data?['testData'];
      if (!snapshot.exists || rawTest is! Map) return false;

      _applySpeakingTest(Map<String, dynamic>.from(rawTest), offline: true);

      if (mounted) {
        _showSnack(
          title: 'Offline Practice Mode',
          message: 'Your previously saved speaking test has been loaded.',
          type: _SnackType.info,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _clearEvaluation({bool resetTranscript = false}) {
    band = '';
    fluency = '';
    lexical = '';
    grammar = '';
    pronunciation = '';
    examinerAdvice = '';
    strengths = '';
    mistakes = '';
    pronunciationTips = '';
    fluencyTips = '';
    improvedAnswer = '';
    seconds = 0;
    if (resetTranscript) transcript = '';
  }

  Future<void> speakTopic() async {
    if (topicTitle.trim().isEmpty || isSpeakingTopic) return;

    try {
      setState(() => isSpeakingTopic = true);
      await tts.stop();
      await tts.setLanguage('en-GB');
      await tts.setSpeechRate(0.43);
      await tts.setPitch(1.0);
      await tts.speak(topicTitle);
    } catch (_) {
      _showSnack(
        title: 'Audio Unavailable',
        message: 'The topic could not be read aloud on this device.',
        type: _SnackType.warning,
      );
    } finally {
      if (mounted) setState(() => isSpeakingTopic = false);
    }
  }

  Future<void> startRecording() async {
    if (isRecording || isAnalyzing || isGeneratingTopic) return;

    try {
      await tts.stop();
      final speechAvailable = await speech.initialize();
      final micPermission = await recorder.hasPermission();

      if (!speechAvailable || !micPermission) {
        _showMessageDialog(
          title: 'Microphone Permission Required',
          message:
              'Allow microphone and speech recognition access to record and analyze your speaking answer.',
          icon: Icons.mic_off_rounded,
          danger: true,
        );
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      audioPath =
          '${directory.path}/speaking_${DateTime.now().millisecondsSinceEpoch}.m4a';

      setState(() {
        isRecording = true;
        transcript = '';
        seconds = 0;
        _clearEvaluation();
      });

      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: audioPath!,
      );

      speech.listen(
        partialResults: true,
        listenMode: ListenMode.dictation,
        onResult: (result) {
          if (!mounted) return;
          setState(() => transcript = result.recognizedWords);
        },
      );

      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && isRecording) setState(() => seconds++);
      });
    } catch (_) {
      if (mounted) setState(() => isRecording = false);
      _showSnack(
        title: 'Recording Failed',
        message: 'The recording could not be started. Please try again.',
        type: _SnackType.error,
      );
    }
  }

  Future<void> stopRecording() async {
    if (!isRecording) return;

    try {
      timer?.cancel();
      await speech.stop();
      final path = await recorder.stop();

      if (mounted) {
        setState(() {
          isRecording = false;
          audioPath = path;
        });
      }

      if (transcript.trim().isEmpty) {
        _showMessageDialog(
          title: 'No Speech Detected',
          message:
              'No clear speech was detected. Move closer to the microphone and try again.',
          icon: Icons.graphic_eq_rounded,
          danger: true,
        );
        return;
      }

      await analyzeSpeaking();
    } catch (_) {
      if (mounted) setState(() => isRecording = false);
      _showSnack(
        title: 'Recording Error',
        message: 'The recording could not be completed.',
        type: _SnackType.error,
      );
    }
  }

  Future<void> analyzeSpeaking() async {
    if (isAnalyzing || transcript.trim().isEmpty) return;

    final online = await _hasInternet();
    if (!online) {
      _showConnectionDialog(
        title: 'Internet Required for Evaluation',
        message:
            'Your recording and transcript remain available on this screen. Connect to the internet and select Analyze Answer to receive AI feedback.',
        retry: analyzeSpeaking,
      );
      return;
    }

    setState(() => isAnalyzing = true);

    try {
      final result = await ai
          .evaluateSpeaking(transcript: transcript, durationSeconds: seconds)
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;
      setState(() {
        band = result['overall_band']?.toString() ?? '0';
        fluency = result['fluency_coherence']?['feedback']?.toString() ?? '';
        lexical = result['lexical_resource']?['feedback']?.toString() ?? '';
        grammar = result['grammar']?['feedback']?.toString() ?? '';
        pronunciation = result['pronunciation']?['feedback']?.toString() ?? '';
        strengths = result['strengths']?.toString() ?? '';
        mistakes = result['mistakes']?.toString() ?? '';
        pronunciationTips = result['pronunciation_tips']?.toString() ?? '';
        fluencyTips = result['fluency_tips']?.toString() ?? '';
        improvedAnswer = result['improved_answer']?.toString() ?? '';
        examinerAdvice = result['examiner_advice']?.toString() ?? '';
      });

      await saveToFirebase();
      await loadRecordings();

      if (mounted) {
        _showSnack(
          title: 'Evaluation Complete',
          message: 'Your speaking performance has been analyzed successfully.',
          type: _SnackType.success,
        );
      }
    } on TimeoutException {
      _showSnack(
        title: 'Evaluation Timed Out',
        message:
            'The AI examiner took too long. Please analyze the answer again.',
        type: _SnackType.warning,
      );
    } catch (error) {
      final message = error.toString().toLowerCase();
      _showSnack(
        title: message.contains('429')
            ? 'AI Limit Reached'
            : 'Evaluation Failed',
        message: message.contains('429')
            ? 'The AI request limit has been reached. Please try again later.'
            : 'The AI examiner could not evaluate your answer. Your transcript is still available.',
        type: _SnackType.error,
      );
    } finally {
      if (mounted) setState(() => isAnalyzing = false);
    }
  }

  Future<void> saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('speaking')
          .add({
            'topic': topicTitle,
            'selectedPart': selectedPart,
            'points': cueCardPoints,
            'transcript': transcript,
            'band': band,
            'duration': seconds,
            'fluency': fluency,
            'lexical': lexical,
            'grammar': grammar,
            'pronunciation': pronunciation,
            'strengths': strengths,
            'mistakes': mistakes,
            'pronunciationTips': pronunciationTips,
            'fluencyTips': fluencyTips,
            'improvedAnswer': improvedAnswer,
            'improvement': examinerAdvice,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      _showSnack(
        title: 'Result Saved Locally',
        message: 'The result will synchronize when Firebase becomes available.',
        type: _SnackType.info,
      );
    }
  }

  Future<void> loadRecordings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      final query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('speaking')
          .orderBy('createdAt', descending: true)
          .limit(5);

      try {
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.cache));
      }

      if (mounted) setState(() => recordings = snapshot.docs);
    } catch (_) {
      // History is optional and must not block the practice screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, -0.9),
                  radius: 1.2,
                  colors: [primary.withOpacity(0.12), background, background],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _appBar(),
                Expanded(
                  child: RefreshIndicator(
                    color: primary,
                    backgroundColor: surface,
                    onRefresh: () async {
                      await generateFullSpeakingTest();
                      await loadRecordings();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                      child: Column(
                        children: [
                          if (isOfflineMode) _offlineBanner(),
                          _heroDashboard(),
                          const SizedBox(height: 18),
                          _partSelector(),
                          const SizedBox(height: 18),
                          _topicSection(),
                          const SizedBox(height: 18),
                          _recordingStudio(),
                          if (isAnalyzing) ...[
                            const SizedBox(height: 18),
                            _analysisProgress(),
                          ],
                          if (band.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _resultSection(),
                          ],
                          if (recordings.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _historySection(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IELTS Speaking Studio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Practice, record and improve with AI',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _iconButton(
            icon: Icons.refresh_rounded,
            loading: isGeneratingTopic,
            onTap: isGeneratingTopic ? null : generateFullSpeakingTest,
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _offlineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFFBBF24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Offline Practice Mode • A saved speaking test is being used. AI evaluation requires internet access.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontWeight: FontWeight.w600,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDashboard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            primary.withOpacity(0.32),
            const Color(0xFF12324A),
            primaryDark.withOpacity(0.76),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Speaking Examiner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Realistic three-part IELTS speaking practice',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  label: 'Duration',
                  value: _formatDuration(seconds),
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  label: 'Band Score',
                  value: band.isEmpty ? '—' : band,
                  icon: Icons.workspace_premium_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  label: 'Mode',
                  value: isOfflineMode ? 'Offline' : 'Online',
                  icon: isOfflineMode
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 19),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _partSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Expanded(child: _partButton('Part 1', 'Interview', 'part1')),
          Expanded(child: _partButton('Part 2', 'Cue Card', 'part2')),
          Expanded(child: _partButton('Part 3', 'Discussion', 'part3')),
        ],
      ),
    );
  }

  Widget _partButton(String title, String subtitle, String value) {
    final selected = selectedPart == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: isRecording
            ? null
            : () {
                setState(() {
                  selectedPart = value;
                  transcript = '';
                  _clearEvaluation();
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [primary, primaryDark])
                : null,
            borderRadius: BorderRadius.circular(17),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: selected
                      ? Colors.white.withOpacity(0.72)
                      : Colors.white38,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topicSection() {
    final title = selectedPart == 'part1'
        ? 'Part 1 • Introduction & Interview'
        : selectedPart == 'part2'
        ? 'Part 2 • Individual Long Turn'
        : 'Part 3 • Two-way Discussion';

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(
                selectedPart == 'part1'
                    ? Icons.chat_bubble_outline_rounded
                    : selectedPart == 'part2'
                    ? Icons.style_outlined
                    : Icons.forum_outlined,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _partInstruction(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedPart == 'part2')
                _miniAction(
                  icon: isSpeakingTopic
                      ? Icons.volume_up_rounded
                      : Icons.volume_up_outlined,
                  onTap: isSpeakingTopic ? null : speakTopic,
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (isGeneratingTopic)
            _topicSkeleton()
          else if (selectedPart == 'part2')
            _cueCard()
          else
            ..._activeQuestions().asMap().entries.map(
              (entry) => _questionItem(entry.key + 1, entry.value),
            ),
          const SizedBox(height: 18),
          _gradientButton(
            text: isGeneratingTopic
                ? 'Generating Test...'
                : 'Generate New Test',
            icon: Icons.auto_awesome_rounded,
            loading: isGeneratingTopic,
            onTap: isGeneratingTopic || isRecording
                ? null
                : generateFullSpeakingTest,
          ),
        ],
      ),
    );
  }

  String _partInstruction() {
    if (selectedPart == 'part1')
      return 'Answer naturally in two or three sentences.';
    if (selectedPart == 'part2')
      return 'Prepare for one minute, then speak for up to two minutes.';
    return 'Give developed answers with reasons and examples.';
  }

  List<String> _activeQuestions() {
    return selectedPart == 'part1' ? part1Questions : part3Questions;
  }

  Widget _cueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.13), accent.withOpacity(0.06)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'CUE CARD',
              style: TextStyle(
                color: primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            topicTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.45,
            ),
          ),
          if (cueCardPoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...cueCardPoints.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7),
                      height: 7,
                      width: 7,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.80),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.045),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer_outlined, color: Colors.white70, size: 19),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Preparation: 1 minute  •  Speaking: up to 2 minutes',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionItem(int number, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.065)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 31,
            width: 31,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$number',
              style: TextStyle(color: primary, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.84),
                fontSize: 14.5,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordingStudio() {
    return _glassCard(
      child: Column(
        children: [
          Row(
            children: [
              _sectionIcon(Icons.mic_none_rounded),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recording Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isRecording
                          ? 'Speak clearly. Your answer is being transcribed live.'
                          : 'Record your response for AI band evaluation.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: isAnalyzing
                ? null
                : (isRecording ? stopRecording : startRecording),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              height: 134,
              width: 134,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isRecording
                      ? [const Color(0xFFFB7185), const Color(0xFFDC2626)]
                      : [primary, primaryDark],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isRecording ? Colors.redAccent : primary)
                        .withOpacity(0.34),
                    blurRadius: isRecording ? 42 : 30,
                    spreadRadius: isRecording ? 3 : 0,
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
          ),
          const SizedBox(height: 20),
          Text(
            isRecording ? 'Recording in progress' : 'Ready to speak',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatDuration(seconds),
            style: TextStyle(
              color: isRecording ? const Color(0xFFFDA4AF) : Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 22),
          _gradientButton(
            text: isRecording ? 'Stop & Analyze' : 'Start Recording',
            icon: isRecording ? Icons.stop_circle_outlined : Icons.mic_rounded,
            colors: isRecording
                ? [const Color(0xFFFB7185), const Color(0xFFDC2626)]
                : null,
            onTap: isAnalyzing || isGeneratingTopic
                ? null
                : (isRecording ? stopRecording : startRecording),
          ),
          if (transcript.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notes_rounded, color: primary, size: 19),
                      const SizedBox(width: 9),
                      const Text(
                        'Live Transcript',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    transcript,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      height: 1.65,
                      fontSize: 14.5,
                    ),
                  ),
                  if (!isRecording && band.isEmpty) ...[
                    const SizedBox(height: 15),
                    _outlineButton(
                      text: 'Analyze Answer',
                      icon: Icons.auto_graph_rounded,
                      onTap: isAnalyzing ? null : analyzeSpeaking,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _analysisProgress() {
    return _glassCard(
      child: Column(
        children: [
          SizedBox(
            height: 72,
            width: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  color: primary,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withOpacity(0.08),
                ),
                Icon(Icons.auto_awesome_rounded, color: primary, size: 29),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'AI Examiner is Analyzing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Evaluating fluency, vocabulary, grammar, pronunciation and overall IELTS performance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.60),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              _StaticChip('Fluency'),
              _StaticChip('Vocabulary'),
              _StaticChip('Grammar'),
              _StaticChip('Pronunciation'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultSection() {
    final value = double.tryParse(band) ?? 0;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withOpacity(0.24),
                surface,
                const Color(0xFF101827),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: primary.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.16),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Estimated IELTS Speaking Band',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 122,
                width: 122,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [primary, primaryDark]),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.30),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Text(
                  band,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: (value / 9).clamp(0.0, 1.0),
                  minHeight: 9,
                  backgroundColor: Colors.white.withOpacity(0.07),
                  valueColor: AlwaysStoppedAnimation(primary),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _resultMetric(
                      'Duration',
                      _formatDuration(seconds),
                      Icons.timer_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _resultMetric(
                      'Status',
                      'Evaluated',
                      Icons.verified_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _feedbackCard('Fluency & Coherence', fluency, Icons.speed_rounded),
        _feedbackCard('Lexical Resource', lexical, Icons.menu_book_rounded),
        _feedbackCard(
          'Grammar Range & Accuracy',
          grammar,
          Icons.spellcheck_rounded,
        ),
        _feedbackCard('Pronunciation', pronunciation, Icons.graphic_eq_rounded),
        _feedbackCard('Strengths', strengths, Icons.thumb_up_alt_outlined),
        _feedbackCard('Mistakes to Fix', mistakes, Icons.build_outlined),
        _feedbackCard(
          'Pronunciation Tips',
          pronunciationTips,
          Icons.hearing_rounded,
        ),
        _feedbackCard('Fluency Tips', fluencyTips, Icons.trending_up_rounded),
        _feedbackCard(
          'Improved Answer',
          improvedAnswer,
          Icons.auto_fix_high_rounded,
        ),
        _feedbackCard(
          'Examiner Advice',
          examinerAdvice,
          Icons.psychology_outlined,
        ),
      ],
    );
  }

  Widget _resultMetric(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: primary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.52),
                    fontSize: 11.5,
                  ),
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

  Widget _feedbackCard(String title, String value, IconData icon) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(icon, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              height: 1.7,
              fontSize: 14.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionIcon(Icons.history_rounded),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Recent Speaking Results',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...recordings.map((document) {
          final data = document.data();
          final topic = data['topic']?.toString() ?? 'Speaking Practice';
          final savedBand = data['band']?.toString() ?? '—';
          final duration = data['duration'] is int
              ? data['duration'] as int
              : 0;

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 11),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.065)),
            ),
            child: Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, primaryDark]),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white),
                ),
                const SizedBox(width: 13),
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
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${_formatDuration(duration)} • AI evaluated',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.48),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Band $savedBand',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.075)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionIcon(IconData icon, {double size = 46}) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primaryDark]),
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.46),
    );
  }

  Widget _miniAction({required IconData icon, required VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.11),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: primary, size: 21),
        ),
      ),
    );
  }

  Widget _topicSkeleton() {
    return Column(
      children: List.generate(
        4,
        (index) => Container(
          height: index == 0 ? 70 : 48,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _gradientButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
    List<Color>? colors,
  }) {
    final disabled = onTap == null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: disabled && !loading ? 0.48 : 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors ?? [primary, primaryDark]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: (colors?.first ?? primary).withOpacity(0.24),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: disabled ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      height: 21,
                      width: 21,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.3,
                      ),
                    )
                  else
                    Icon(icon, color: Colors.white, size: 21),
                  const SizedBox(width: 11),
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
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

  Widget _outlineButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withOpacity(0.20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primary, size: 19),
              const SizedBox(width: 9),
              Text(
                text,
                style: TextStyle(color: primary, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int value) {
    final minutes = value ~/ 60;
    final remaining = value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  void _showConnectionDialog({
    required String title,
    required String message,
    required VoidCallback retry,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.76),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogIcon(Icons.wifi_off_rounded, danger: false),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.63),
                  height: 1.55,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _dialogButton(
                      text: 'Close',
                      onTap: () => Navigator.pop(context),
                      filled: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dialogButton(
                      text: 'Retry',
                      onTap: () {
                        Navigator.pop(context);
                        retry();
                      },
                      filled: true,
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

  void _showMessageDialog({
    required String title,
    required String message,
    required IconData icon,
    bool danger = false,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.76),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogIcon(icon, danger: danger),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.63),
                  height: 1.55,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 22),
              _dialogButton(
                text: 'OK',
                onTap: () => Navigator.pop(context),
                filled: true,
                danger: danger,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogIcon(IconData icon, {required bool danger}) {
    final colors = danger
        ? [const Color(0xFFFB7185), const Color(0xFFDC2626)]
        : [primary, primaryDark];
    return Container(
      height: 76,
      width: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 36),
    );
  }

  Widget _dialogButton({
    required String text,
    required VoidCallback onTap,
    required bool filled,
    bool danger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: filled
                ? LinearGradient(
                    colors: danger
                        ? [const Color(0xFFFB7185), const Color(0xFFDC2626)]
                        : [primary, primaryDark],
                  )
                : null,
            color: filled ? null : Colors.white.withOpacity(0.055),
            borderRadius: BorderRadius.circular(16),
            border: filled
                ? null
                : Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack({
    required String title,
    required String message,
    required _SnackType type,
  }) {
    if (!mounted) return;

    final configuration = switch (type) {
      _SnackType.success => (
        const Color(0xFF22C55E),
        Icons.check_circle_rounded,
      ),
      _SnackType.warning => (
        const Color(0xFFF59E0B),
        Icons.warning_amber_rounded,
      ),
      _SnackType.error => (
        const Color(0xFFFB7185),
        Icons.error_outline_rounded,
      ),
      _SnackType.info => (accent, Icons.info_outline_rounded),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
          content: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: configuration.$1.withOpacity(0.28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: configuration.$1.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(configuration.$2, color: configuration.$1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.64),
                          height: 1.35,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

enum _SnackType { success, warning, error, info }

class _StaticChip extends StatelessWidget {
  final String text;

  const _StaticChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
