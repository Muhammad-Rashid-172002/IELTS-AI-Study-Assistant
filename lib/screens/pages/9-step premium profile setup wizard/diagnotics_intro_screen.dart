import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/certificate/certificate_screen.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:fyproject/screens/pages/personalized_study_plan/personalized_study_plan-screen.dart';

class DiagnosticIntroScreen extends StatelessWidget {
  final String ieltsType;
  final double targetBand;

  const DiagnosticIntroScreen({
    super.key,
    this.ieltsType = 'Academic',
    this.targetBand = 7.0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DiagnosticColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _DiagnosticBackground()),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IntroTopBar(onBack: () => Navigator.maybePop(context)),
                  const SizedBox(height: 24),
                  _DiagnosticHeroCard(
                    ieltsType: ieltsType,
                    targetBand: targetBand,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Your real IELTS starting point',
                    style: TextStyle(
                      color: DiagnosticColors.mainText,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Complete a four-skill diagnostic using published questions, real listening audio, AI writing evaluation and recorded speaking analysis.',
                    style: TextStyle(
                      color: DiagnosticColors.mutedText,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _DiagnosticInformationGrid(),
                  const SizedBox(height: 18),
                  const _PreparationNotice(),
                  const SizedBox(height: 24),
                  _GradientButton(
                    title: 'Start Diagnostic Test',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DiagnosticTestScreen(
                            ieltsType: ieltsType,
                            targetBand: targetBand,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 53,
                    child: OutlinedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .set({
                                'diagnosticDeferred': true,
                                'diagnosticDeferredAt':
                                    FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                        }

                        if (!context.mounted) return;
                        Navigator.maybePop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DiagnosticColors.mainText,
                        side: BorderSide(color: Colors.white.withOpacity(.09)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Text(
                        'Take Later',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DiagnosticTestScreen extends StatefulWidget {
  final String ieltsType;
  final double targetBand;

  const DiagnosticTestScreen({
    super.key,
    required this.ieltsType,
    required this.targetBand,
  });

  @override
  State<DiagnosticTestScreen> createState() => _DiagnosticTestScreenState();
}

class _DiagnosticTestScreenState extends State<DiagnosticTestScreen>
    with TickerProviderStateMixin {
  final _repository = DiagnosticRepository();
  final _pageController = PageController();
  final _writingController = TextEditingController();
  final _audioPlayer = AudioPlayer();
  final _recorder = AudioRecorder();

  late final AnimationController _waveController;

  DiagnosticTestModel? _test;
  Timer? _timer;
  StreamSubscription<Duration>? _positionSubscription;

  final Map<String, dynamic> _listeningAnswers = {};
  final Map<String, dynamic> _readingAnswers = {};

  int _currentSection = 0;
  int _remainingSeconds = 30 * 60;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  bool _loading = true;
  bool _submitting = false;
  bool _recording = false;
  String? _recordingPath;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _loadTest();
  }

  Future<void> _loadTest() async {
    try {
      final test = await _repository.loadPublishedTest(
        ieltsType: widget.ieltsType,
      );

      await _audioPlayer.setUrl(test.listening.audioUrl);

      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        if (!mounted) return;
        setState(() => _audioPosition = position);
      });

      _audioPlayer.durationStream.listen((duration) {
        if (!mounted || duration == null) return;
        setState(() => _audioDuration = duration);
      });

      if (!mounted) return;

      setState(() {
        _test = test;
        _remainingSeconds = test.totalDurationMinutes * 60;
        _loading = false;
      });

      _startTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        _submitDiagnostic();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    _pageController.dispose();
    _writingController.dispose();
    _audioPlayer.dispose();
    _recorder.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }

    if (mounted) setState(() {});
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      _waveController.stop();

      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordingPath = path;
      });
      return;
    }

    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      _showMessage('Microphone permission is required.');
      return;
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/diagnostic_'
        '${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    _waveController.repeat(reverse: true);

    if (!mounted) return;
    setState(() {
      _recording = true;
      _recordingPath = null;
    });
  }

  Future<void> _goNext() async {
    FocusScope.of(context).unfocus();

    if (_currentSection < 3) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    await _submitDiagnostic();
  }

  Future<void> _goBack() async {
    FocusScope.of(context).unfocus();

    if (_currentSection > 0) {
      await _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _submitDiagnostic() async {
    if (_submitting || _test == null) return;

    if (_recording) {
      await _toggleRecording();
    }

    final test = _test!;
    final writing = _writingController.text.trim();

    if (writing.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length <
        test.writing.minimumWords) {
      _showMessage(
        'Writing response must contain at least '
        '${test.writing.minimumWords} words.',
      );
      return;
    }

    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      _showMessage('Please record your Speaking response.');
      return;
    }

    setState(() => _submitting = true);
    _timer?.cancel();

    try {
      final listeningResult = DiagnosticScoring.scoreObjectiveSection(
        questions: test.listening.questions,
        answers: _listeningAnswers,
      );

      final readingResult = DiagnosticScoring.scoreObjectiveSection(
        questions: test.reading.questions,
        answers: _readingAnswers,
      );

      final speakingUrl = await _repository.uploadSpeakingRecording(
        testId: test.id,
        localPath: _recordingPath!,
      );

      final evaluations = await Future.wait([
        _repository.evaluateWriting(
          testId: test.id,
          ieltsType: widget.ieltsType,
          prompt: test.writing.prompt,
          answer: writing,
        ),
        _repository.evaluateSpeaking(
          testId: test.id,
          prompts: test.speaking.prompts,
          audioUrl: speakingUrl,
        ),
      ]);

      final writingEvaluation = evaluations[0] as DiagnosticWritingEvaluation;
      final speakingEvaluation = evaluations[1] as DiagnosticSpeakingEvaluation;

      final listeningBand = DiagnosticScoring.scoreToBand(
        listeningResult.correct,
        listeningResult.total,
      );

      final readingBand = DiagnosticScoring.scoreToBand(
        readingResult.correct,
        readingResult.total,
      );

      final overallBand = DiagnosticScoring.roundIeltsOverallBand(
        (listeningBand +
                readingBand +
                writingEvaluation.overallBand +
                speakingEvaluation.overallBand) /
            4,
      );

      final result = DiagnosticResultData(
        testId: test.id,
        overallBand: overallBand,
        listeningBand: listeningBand,
        readingBand: readingBand,
        writingBand: writingEvaluation.overallBand,
        speakingBand: speakingEvaluation.overallBand,
        targetBand: widget.targetBand,
        ieltsType: widget.ieltsType,
        listeningCorrect: listeningResult.correct,
        listeningTotal: listeningResult.total,
        readingCorrect: readingResult.correct,
        readingTotal: readingResult.total,
        writingEvaluation: writingEvaluation,
        speakingEvaluation: speakingEvaluation,
        speakingAudioUrl: speakingUrl,
        durationUsedSeconds: test.totalDurationMinutes * 60 - _remainingSeconds,
      );

      final resultId = await _repository.saveResult(result);
      final certificateId = await _repository.issueCompletionCertificate(
        resultId: resultId,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DiagnosticResultScreen(
            result: result,
            certificateId: certificateId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _submitting = false);
      _startTimer();
      _showMessage('Diagnostic submission failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: DiagnosticColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null || _test == null) {
      return Scaffold(
        backgroundColor: DiagnosticColors.background,
        body: _ErrorState(
          message: _loadError ?? 'No published diagnostic test found.',
          onRetry: () {
            setState(() {
              _loading = true;
              _loadError = null;
            });
            _loadTest();
          },
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: DiagnosticColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentSection = index);
                  },
                  children: [
                    _buildListening(),
                    _buildReading(),
                    _buildWriting(),
                    _buildSpeaking(),
                  ],
                ),
              ),
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const names = ['Listening', 'Reading', 'Writing', 'Speaking'];
    const icons = [
      Icons.headphones_rounded,
      Icons.menu_book_rounded,
      Icons.edit_note_rounded,
      Icons.mic_rounded,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _showExitDialog,
                style: IconButton.styleFrom(
                  backgroundColor: DiagnosticColors.surface,
                  foregroundColor: DiagnosticColors.mainText,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: DiagnosticColors.gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icons[_currentSection], color: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      names[_currentSection],
                      style: const TextStyle(
                        color: DiagnosticColors.mainText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Section ${_currentSection + 1} of 4',
                      style: const TextStyle(
                        color: DiagnosticColors.mutedText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              _TimerBadge(seconds: _remainingSeconds),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(4, (index) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 6,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: index <= _currentSection
                        ? DiagnosticColors.gradient
                        : null,
                    color: index <= _currentSection
                        ? null
                        : DiagnosticColors.border,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildListening() {
    final section = _test!.listening;

    return _SectionScrollView(
      title: 'Listening Diagnostic',
      description:
          'Play the recording and answer all questions. Answers are scored against the published test key.',
      child: Column(
        children: [
          _RealAudioPlayerCard(
            title: section.title,
            playing: _audioPlayer.playing,
            position: _audioPosition,
            duration: _audioDuration,
            onPlay: _toggleAudio,
          ),
          const SizedBox(height: 16),
          ...section.questions.map(
            (question) => _DiagnosticQuestionCard(
              question: question,
              value: _listeningAnswers[question.id],
              onChanged: (value) {
                setState(() {
                  _listeningAnswers[question.id] = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReading() {
    final section = _test!.reading;

    return _SectionScrollView(
      title: 'Reading Diagnostic',
      description:
          'Read the passage carefully and complete each IELTS-style question.',
      child: Column(
        children: [
          _ReadingPassageCard(
            title: section.passageTitle,
            passage: section.passage,
          ),
          const SizedBox(height: 16),
          ...section.questions.map(
            (question) => _DiagnosticQuestionCard(
              question: question,
              value: _readingAnswers[question.id],
              onChanged: (value) {
                setState(() {
                  _readingAnswers[question.id] = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriting() {
    final writing = _test!.writing;
    final wordCount = _writingController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;

    return _SectionScrollView(
      title: 'Writing Diagnostic',
      description:
          'Your answer will be evaluated for IELTS criteria by the secure backend.',
      child: Column(
        children: [
          _WritingTaskCard(task: writing),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Your response',
                      style: TextStyle(
                        color: DiagnosticColors.mainText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$wordCount / ${writing.minimumWords}+ words',
                      style: TextStyle(
                        color: wordCount >= writing.minimumWords
                            ? DiagnosticColors.success
                            : DiagnosticColors.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _writingController,
                  minLines: 13,
                  maxLines: 22,
                  onChanged: (_) => setState(() {}),
                  cursorColor: DiagnosticColors.cyan,
                  style: const TextStyle(
                    color: DiagnosticColors.mainText,
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write your complete answer here...',
                    filled: true,
                    fillColor: DiagnosticColors.background.withOpacity(.58),
                    border: _fieldBorder(DiagnosticColors.border),
                    enabledBorder: _fieldBorder(DiagnosticColors.border),
                    focusedBorder: _fieldBorder(
                      DiagnosticColors.cyan,
                      width: 1.4,
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

  Widget _buildSpeaking() {
    final speaking = _test!.speaking;

    return _SectionScrollView(
      title: 'Speaking Diagnostic',
      description:
          'Record one continuous response. The backend evaluates Fluency, Lexical Resource, Grammar and Pronunciation.',
      child: Column(
        children: [
          ...speaking.prompts.map(
            (prompt) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SpeakingPromptCard(prompt: prompt),
            ),
          ),
          const SizedBox(height: 4),
          _SpeakingRecorderCard(
            isRecording: _recording,
            hasRecording: _recordingPath != null,
            controller: _waveController,
            onTap: _toggleRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 17),
      decoration: BoxDecoration(
        color: DiagnosticColors.background.withOpacity(.98),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(.05))),
      ),
      child: Row(
        children: [
          if (_currentSection > 0)
            Expanded(
              child: SizedBox(
                height: 53,
                child: OutlinedButton(
                  onPressed: _submitting ? null : _goBack,
                  child: const Text('Back'),
                ),
              ),
            ),
          if (_currentSection > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _GradientButton(
              title: _currentSection == 3 ? 'Submit Diagnostic' : 'Continue',
              icon: _currentSection == 3
                  ? Icons.check_circle_outline_rounded
                  : Icons.arrow_forward_rounded,
              isLoading: _submitting,
              onPressed: _goNext,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExitDialog() async {
    final exit =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: DiagnosticColors.surface,
            title: const Text(
              'Leave diagnostic test?',
              style: TextStyle(color: DiagnosticColors.mainText),
            ),
            content: const Text(
              'Your current unsaved answers and recording will be lost.',
              style: TextStyle(color: DiagnosticColors.mutedText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continue Test'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Leave',
                  style: TextStyle(color: DiagnosticColors.error),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (exit && mounted) Navigator.pop(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class DiagnosticResultScreen extends StatelessWidget {
  final DiagnosticResultData result;
  final String? certificateId;

  const DiagnosticResultScreen({
    super.key,
    required this.result,
    this.certificateId,
  });

  @override
  Widget build(BuildContext context) {
    final bands = {
      'Listening': result.listeningBand,
      'Reading': result.readingBand,
      'Writing': result.writingBand,
      'Speaking': result.speakingBand,
    };

    final sorted = bands.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final gap = math.max(0, result.targetBand - result.overallBand);

    return Scaffold(
      backgroundColor: DiagnosticColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _DiagnosticBackground()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                const Text(
                  'Diagnostic Result',
                  style: TextStyle(
                    color: DiagnosticColors.mainText,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: _heroDecoration(),
                  child: Column(
                    children: [
                      const Text(
                        'Estimated Overall Band',
                        style: TextStyle(color: DiagnosticColors.secondaryText),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        result.overallBand.toStringAsFixed(1),
                        style: const TextStyle(
                          color: DiagnosticColors.mainText,
                          fontSize: 55,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        gap <= 0
                            ? 'Target reached'
                            : '${gap.toStringAsFixed(1)} band gap to target',
                        style: const TextStyle(
                          color: DiagnosticColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.75,
                  children: bands.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: _cardDecoration(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.value.toStringAsFixed(1),
                            style: const TextStyle(
                              color: DiagnosticColors.cyan,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: DiagnosticColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
                _FeedbackPanel(
                  title: 'Writing Evaluation',
                  rows: {
                    'Task Response': result.writingEvaluation.taskResponse,
                    'Coherence': result.writingEvaluation.coherenceCohesion,
                    'Lexical Resource':
                        result.writingEvaluation.lexicalResource,
                    'Grammar': result.writingEvaluation.grammarAccuracy,
                  },
                  summary: result.writingEvaluation.summary,
                ),
                const SizedBox(height: 15),
                _FeedbackPanel(
                  title: 'Speaking Evaluation',
                  rows: {
                    'Fluency': result.speakingEvaluation.fluencyCoherence,
                    'Lexical Resource':
                        result.speakingEvaluation.lexicalResource,
                    'Grammar': result.speakingEvaluation.grammarAccuracy,
                    'Pronunciation': result.speakingEvaluation.pronunciation,
                  },
                  summary: result.speakingEvaluation.summary,
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: _cardDecoration(),
                  child: Text(
                    'Strongest skill: ${sorted.last.key}\n'
                    'Priority skill: ${sorted.first.key}\n'
                    'Listening: ${result.listeningCorrect}/${result.listeningTotal}\n'
                    'Reading: ${result.readingCorrect}/${result.readingTotal}',
                    style: const TextStyle(
                      color: DiagnosticColors.secondaryText,
                      height: 1.7,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                _DiagnosticCertificateCard(
                  certificateIssued: certificateId != null,
                  onView: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CertificatesScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                _GradientButton(
                  title: 'Create My Study Plan',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () {
                    final recentScores = <String, double>{
                      'Listening': result.listeningBand,
                      'Reading': result.readingBand,
                      'Writing': result.writingBand,
                      'Speaking': result.speakingBand,
                    };

                    final weakQuestionTypes =
                        <String>[
                              ...result.writingEvaluation.improvements,
                              ...result.speakingEvaluation.improvements,
                            ]
                            .map((item) => item.trim())
                            .where((item) => item.isNotEmpty)
                            .toSet()
                            .take(8)
                            .toList();

                    final dailyStudyMinutes = _recommendedDailyMinutes(
                      gap.toDouble(),
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonalizedStudyPlanScreen(
                          currentBand: result.overallBand,
                          targetBand: result.targetBand,
                          dailyStudyMinutes: dailyStudyMinutes,
                          availableDays: const [
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday',
                          ],
                          weakQuestionTypes: weakQuestionTypes,
                          recentScores: recentScores,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _recommendedDailyMinutes(double gap) {
    if (gap <= .5) return 30;
    if (gap <= 1) return 45;
    if (gap <= 1.5) return 60;
    if (gap <= 2) return 75;
    return 90;
  }
}

class _DiagnosticCertificateCard extends StatelessWidget {
  final bool certificateIssued;
  final VoidCallback onView;

  const _DiagnosticCertificateCard({
    required this.certificateIssued,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: DiagnosticColors.gradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  certificateIssued
                      ? 'Certificate Earned'
                      : 'Certificate Processing',
                  style: const TextStyle(
                    color: DiagnosticColors.mainText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  certificateIssued
                      ? 'Your verified Diagnostic Completion certificate is ready.'
                      : 'Your result is saved. Certificate synchronization will retry automatically.',
                  style: const TextStyle(
                    color: DiagnosticColors.mutedText,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (certificateIssued)
            TextButton(onPressed: onView, child: const Text('View')),
        ],
      ),
    );
  }
}

class DiagnosticRepository {
  DiagnosticRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User is not signed in.');
    return user;
  }

  Future<DiagnosticTestModel> loadPublishedTest({
    required String ieltsType,
  }) async {
    final snapshot = await _firestore
        .collection('diagnostic_tests')
        .where('status', isEqualTo: 'published')
        .where('ieltsType', isEqualTo: ieltsType)
        .limit(20)
        .get();

    if (snapshot.docs.isEmpty) {
      throw StateError('No published $ieltsType diagnostic test is available.');
    }

    final docs = [...snapshot.docs]..shuffle();
    return DiagnosticTestModel.fromDocument(docs.first);
  }

  Future<String> uploadSpeakingRecording({
    required String testId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw StateError('Speaking recording file does not exist.');
    }

    final ref = _storage.ref(
      'diagnostic_speaking/${_user.uid}/$testId/'
      '${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    await ref.putFile(file, SettableMetadata(contentType: 'audio/mp4'));

    return ref.getDownloadURL();
  }

  Future<DiagnosticWritingEvaluation> evaluateWriting({
    required String testId,
    required String ieltsType,
    required String prompt,
    required String answer,
  }) async {
    final callable = _functions.httpsCallable('evaluateDiagnosticWriting');

    final response = await callable.call({
      'testId': testId,
      'ieltsType': ieltsType,
      'prompt': prompt,
      'answer': answer,
    });

    return DiagnosticWritingEvaluation.fromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<DiagnosticSpeakingEvaluation> evaluateSpeaking({
    required String testId,
    required List<SpeakingPrompt> prompts,
    required String audioUrl,
  }) async {
    final callable = _functions.httpsCallable('evaluateDiagnosticSpeaking');

    final response = await callable.call({
      'testId': testId,
      'audioUrl': audioUrl,
      'prompts': prompts.map((e) => e.toMap()).toList(),
    });

    return DiagnosticSpeakingEvaluation.fromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<String> saveResult(DiagnosticResultData result) async {
    final userRef = _firestore.collection('users').doc(_user.uid);
    final resultRef = userRef.collection('diagnostic_results').doc();

    final skillBands = {
      'listening': result.listeningBand,
      'reading': result.readingBand,
      'writing': result.writingBand,
      'speaking': result.speakingBand,
    };

    final batch = _firestore.batch();

    batch.set(resultRef, {
      'resultId': resultRef.id,
      'testId': result.testId,
      'ieltsType': result.ieltsType,
      'targetBand': result.targetBand,
      'overallBand': result.overallBand,
      'skillBands': skillBands,
      'objectiveScores': {
        'listening': {
          'correct': result.listeningCorrect,
          'total': result.listeningTotal,
        },
        'reading': {
          'correct': result.readingCorrect,
          'total': result.readingTotal,
        },
      },
      'writingEvaluation': result.writingEvaluation.toMap(),
      'speakingEvaluation': result.speakingEvaluation.toMap(),
      'speakingAudioUrl': result.speakingAudioUrl,
      'durationUsedSeconds': result.durationUsedSeconds,
      'completedAt': FieldValue.serverTimestamp(),
    });

    batch.set(userRef, {
      'diagnosticCompleted': true,
      'diagnosticCompletedAt': FieldValue.serverTimestamp(),
      'currentBand': result.overallBand,
      'estimatedBand': result.overallBand,
      'overallBand': result.overallBand,
      'skillBands': skillBands,
      'ieltsType': result.ieltsType,
      'targetBand': result.targetBand,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    return resultRef.id;
  }

  Future<String?> issueCompletionCertificate({required String resultId}) async {
    try {
      final callable = _functions.httpsCallable('issueAchievementCertificate');

      final response = await callable.call({
        'achievementType': 'diagnostic_completion',
        'sourceId': resultId,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final certificateId = data['certificateId']?.toString().trim() ?? '';
      return certificateId.isEmpty ? null : certificateId;
    } catch (_) {
      return null;
    }
  }
}

class DiagnosticScoring {
  static ObjectiveScore scoreObjectiveSection({
    required List<DiagnosticQuestion> questions,
    required Map<String, dynamic> answers,
  }) {
    var correct = 0;

    for (final question in questions) {
      final userAnswer = answers[question.id];

      if (_isCorrect(question, userAnswer)) {
        correct++;
      }
    }

    return ObjectiveScore(correct: correct, total: questions.length);
  }

  static bool _isCorrect(DiagnosticQuestion question, dynamic userAnswer) {
    if (userAnswer == null) return false;

    String normalize(dynamic value) {
      return value.toString().trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
    }

    final normalized = normalize(userAnswer);

    return question.acceptedAnswers.any(
      (answer) => normalize(answer) == normalized,
    );
  }

  static double scoreToBand(int correct, int total) {
    if (total <= 0) return 0;

    final ratio = correct / total;

    if (ratio >= .975) return 9;
    if (ratio >= .925) return 8.5;
    if (ratio >= .875) return 8;
    if (ratio >= .80) return 7.5;
    if (ratio >= .725) return 7;
    if (ratio >= .65) return 6.5;
    if (ratio >= .575) return 6;
    if (ratio >= .50) return 5.5;
    if (ratio >= .425) return 5;
    if (ratio >= .35) return 4.5;
    return 4;
  }

  static double roundIeltsOverallBand(double value) {
    final whole = value.floor();
    final fraction = value - whole;

    if (fraction < .25) return whole.toDouble();
    if (fraction < .75) return whole + .5;
    return whole + 1.0;
  }
}

class DiagnosticTestModel {
  final String id;
  final String title;
  final String ieltsType;
  final int totalDurationMinutes;
  final ListeningDiagnosticSection listening;
  final ReadingDiagnosticSection reading;
  final WritingDiagnosticTask writing;
  final SpeakingDiagnosticSection speaking;

  const DiagnosticTestModel({
    required this.id,
    required this.title,
    required this.ieltsType,
    required this.totalDurationMinutes,
    required this.listening,
    required this.reading,
    required this.writing,
    required this.speaking,
  });

  factory DiagnosticTestModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return DiagnosticTestModel(
      id: doc.id,
      title: (data['title'] ?? 'IELTS Diagnostic Test').toString(),
      ieltsType: (data['ieltsType'] ?? 'Academic').toString(),
      totalDurationMinutes: _int(data['totalDurationMinutes'], 30),
      listening: ListeningDiagnosticSection.fromMap(
        Map<String, dynamic>.from(data['listening'] as Map? ?? {}),
      ),
      reading: ReadingDiagnosticSection.fromMap(
        Map<String, dynamic>.from(data['reading'] as Map? ?? {}),
      ),
      writing: WritingDiagnosticTask.fromMap(
        Map<String, dynamic>.from(data['writing'] as Map? ?? {}),
      ),
      speaking: SpeakingDiagnosticSection.fromMap(
        Map<String, dynamic>.from(data['speaking'] as Map? ?? {}),
      ),
    );
  }

  static int _int(dynamic value, [int fallback = 0]) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class ListeningDiagnosticSection {
  final String title;
  final String audioUrl;
  final List<DiagnosticQuestion> questions;

  const ListeningDiagnosticSection({
    required this.title,
    required this.audioUrl,
    required this.questions,
  });

  factory ListeningDiagnosticSection.fromMap(Map<String, dynamic> data) {
    final audioUrl = (data['audioUrl'] ?? '').toString();

    if (audioUrl.isEmpty) {
      throw StateError('Published diagnostic test has no Listening audio URL.');
    }

    return ListeningDiagnosticSection(
      title: (data['title'] ?? 'Listening Recording').toString(),
      audioUrl: audioUrl,
      questions: _questions(data['questions']),
    );
  }
}

class ReadingDiagnosticSection {
  final String passageTitle;
  final String passage;
  final List<DiagnosticQuestion> questions;

  const ReadingDiagnosticSection({
    required this.passageTitle,
    required this.passage,
    required this.questions,
  });

  factory ReadingDiagnosticSection.fromMap(Map<String, dynamic> data) {
    return ReadingDiagnosticSection(
      passageTitle: (data['passageTitle'] ?? 'Reading Passage').toString(),
      passage: (data['passage'] ?? '').toString(),
      questions: _questions(data['questions']),
    );
  }
}

List<DiagnosticQuestion> _questions(dynamic raw) {
  if (raw is! List) return const [];

  return raw
      .whereType<Map>()
      .map(
        (value) => DiagnosticQuestion.fromMap(Map<String, dynamic>.from(value)),
      )
      .toList();
}

class DiagnosticQuestion {
  final String id;
  final String type;
  final String prompt;
  final Map<String, String> options;
  final List<String> acceptedAnswers;
  final String instruction;

  const DiagnosticQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.options,
    required this.acceptedAnswers,
    required this.instruction,
  });

  factory DiagnosticQuestion.fromMap(Map<String, dynamic> data) {
    final options = <String, String>{};

    if (data['options'] is Map) {
      for (final entry in (data['options'] as Map).entries) {
        options[entry.key.toString()] = entry.value.toString();
      }
    }

    final accepted = data['acceptedAnswers'] is List
        ? (data['acceptedAnswers'] as List).map((e) => e.toString()).toList()
        : [if (data['answer'] != null) data['answer'].toString()];

    return DiagnosticQuestion(
      id: (data['id'] ?? data['questionId'] ?? '').toString(),
      type: (data['type'] ?? 'text').toString(),
      prompt: (data['prompt'] ?? data['question'] ?? '').toString(),
      options: options,
      acceptedAnswers: accepted,
      instruction: (data['instruction'] ?? '').toString(),
    );
  }
}

class WritingVisualSeries {
  final String name;
  final List<double> values;

  const WritingVisualSeries({required this.name, required this.values});

  factory WritingVisualSeries.fromMap(Map<String, dynamic> data) {
    return WritingVisualSeries(
      name: (data['name'] ?? '').toString(),
      values: data['values'] is List
          ? (data['values'] as List)
                .map((value) => _visualDouble(value))
                .toList()
          : const [],
    );
  }
}

class WritingVisualPoint {
  final String label;
  final double x;
  final double y;

  const WritingVisualPoint({
    required this.label,
    required this.x,
    required this.y,
  });

  factory WritingVisualPoint.fromMap(Map<String, dynamic> data) {
    return WritingVisualPoint(
      label: (data['label'] ?? '').toString(),
      x: _visualDouble(data['x']),
      y: _visualDouble(data['y']),
    );
  }
}

class WritingVisualData {
  final String type;
  final String title;
  final String subtitle;
  final String xAxisLabel;
  final String yAxisLabel;
  final String unit;
  final List<String> categories;
  final List<WritingVisualSeries> series;
  final List<String> tableColumns;
  final List<List<String>> tableRows;
  final List<String> processSteps;
  final List<WritingVisualPoint> mapPoints;
  final String note;

  const WritingVisualData({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.unit,
    required this.categories,
    required this.series,
    required this.tableColumns,
    required this.tableRows,
    required this.processSteps,
    required this.mapPoints,
    required this.note,
  });

  factory WritingVisualData.empty() {
    return const WritingVisualData(
      type: 'none',
      title: '',
      subtitle: '',
      xAxisLabel: '',
      yAxisLabel: '',
      unit: '',
      categories: [],
      series: [],
      tableColumns: [],
      tableRows: [],
      processSteps: [],
      mapPoints: [],
      note: '',
    );
  }

  factory WritingVisualData.fromMap(Map<String, dynamic> data) {
    final rawSeries = data['series'];
    final rawRows = data['tableRows'];
    final rawPoints = data['mapPoints'];

    return WritingVisualData(
      type: (data['type'] ?? 'none').toString().trim().toLowerCase(),
      title: (data['title'] ?? '').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      xAxisLabel: (data['xAxisLabel'] ?? '').toString(),
      yAxisLabel: (data['yAxisLabel'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      categories: data['categories'] is List
          ? (data['categories'] as List).map((item) => item.toString()).toList()
          : const [],
      series: rawSeries is List
          ? rawSeries
                .whereType<Map>()
                .map(
                  (item) => WritingVisualSeries.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      tableColumns: data['tableColumns'] is List
          ? (data['tableColumns'] as List)
                .map((item) => item.toString())
                .toList()
          : const [],
      tableRows: rawRows is List
          ? rawRows
                .whereType<List>()
                .map((row) => row.map((item) => item.toString()).toList())
                .toList()
          : const [],
      processSteps: data['processSteps'] is List
          ? (data['processSteps'] as List)
                .map((item) => item.toString())
                .toList()
          : const [],
      mapPoints: rawPoints is List
          ? rawPoints
                .whereType<Map>()
                .map(
                  (item) => WritingVisualPoint.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      note: (data['note'] ?? '').toString(),
    );
  }

  bool get hasContent {
    if (type == 'table') {
      return tableColumns.isNotEmpty && tableRows.isNotEmpty;
    }

    if (type == 'process') {
      return processSteps.length >= 3;
    }

    if (type == 'map') {
      return mapPoints.isNotEmpty;
    }

    return categories.isNotEmpty &&
        series.isNotEmpty &&
        series.any((item) => item.values.isNotEmpty);
  }
}

class WritingDiagnosticTask {
  final String taskType;
  final String prompt;
  final int minimumWords;
  final int recommendedMinutes;
  final WritingVisualData visual;

  const WritingDiagnosticTask({
    required this.taskType,
    required this.prompt,
    required this.minimumWords,
    required this.recommendedMinutes,
    required this.visual,
  });

  factory WritingDiagnosticTask.fromMap(Map<String, dynamic> data) {
    final visualMap = data['visual'] is Map
        ? Map<String, dynamic>.from(data['visual'])
        : <String, dynamic>{};

    return WritingDiagnosticTask(
      taskType: (data['taskType'] ?? 'Task 2').toString(),
      prompt: (data['prompt'] ?? '').toString(),
      minimumWords: _int(data['minimumWords'], 150),
      recommendedMinutes: _int(data['recommendedMinutes'], 20),
      visual: WritingVisualData.fromMap(visualMap),
    );
  }

  static int _int(dynamic value, [int fallback = 0]) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

double _visualDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class SpeakingDiagnosticSection {
  final List<SpeakingPrompt> prompts;

  const SpeakingDiagnosticSection({required this.prompts});

  factory SpeakingDiagnosticSection.fromMap(Map<String, dynamic> data) {
    final raw = data['prompts'];

    return SpeakingDiagnosticSection(
      prompts: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (value) =>
                      SpeakingPrompt.fromMap(Map<String, dynamic>.from(value)),
                )
                .toList()
          : const [],
    );
  }
}

class SpeakingPrompt {
  final String part;
  final String prompt;
  final String duration;

  const SpeakingPrompt({
    required this.part,
    required this.prompt,
    required this.duration,
  });

  factory SpeakingPrompt.fromMap(Map<String, dynamic> data) {
    return SpeakingPrompt(
      part: (data['part'] ?? 'Speaking').toString(),
      prompt: (data['prompt'] ?? '').toString(),
      duration: (data['duration'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'part': part,
    'prompt': prompt,
    'duration': duration,
  };
}

class DiagnosticWritingEvaluation {
  final double overallBand;
  final double taskResponse;
  final double coherenceCohesion;
  final double lexicalResource;
  final double grammarAccuracy;
  final String summary;
  final List<String> improvements;

  const DiagnosticWritingEvaluation({
    required this.overallBand,
    required this.taskResponse,
    required this.coherenceCohesion,
    required this.lexicalResource,
    required this.grammarAccuracy,
    required this.summary,
    required this.improvements,
  });

  factory DiagnosticWritingEvaluation.fromMap(Map<String, dynamic> data) {
    return DiagnosticWritingEvaluation(
      overallBand: _double(data['overallBand']),
      taskResponse: _double(data['taskResponse'] ?? data['taskAchievement']),
      coherenceCohesion: _double(data['coherenceCohesion']),
      lexicalResource: _double(data['lexicalResource']),
      grammarAccuracy: _double(
        data['grammarAccuracy'] ?? data['grammaticalRangeAndAccuracy'],
      ),
      summary: (data['summary'] ?? '').toString(),
      improvements: data['improvements'] is List
          ? (data['improvements'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'overallBand': overallBand,
    'taskResponse': taskResponse,
    'coherenceCohesion': coherenceCohesion,
    'lexicalResource': lexicalResource,
    'grammarAccuracy': grammarAccuracy,
    'summary': summary,
    'improvements': improvements,
  };
}

class DiagnosticSpeakingEvaluation {
  final double overallBand;
  final double fluencyCoherence;
  final double lexicalResource;
  final double grammarAccuracy;
  final double pronunciation;
  final String transcript;
  final String summary;
  final List<String> improvements;

  const DiagnosticSpeakingEvaluation({
    required this.overallBand,
    required this.fluencyCoherence,
    required this.lexicalResource,
    required this.grammarAccuracy,
    required this.pronunciation,
    required this.transcript,
    required this.summary,
    required this.improvements,
  });

  factory DiagnosticSpeakingEvaluation.fromMap(Map<String, dynamic> data) {
    return DiagnosticSpeakingEvaluation(
      overallBand: _double(data['overallBand']),
      fluencyCoherence: _double(data['fluencyCoherence']),
      lexicalResource: _double(data['lexicalResource']),
      grammarAccuracy: _double(
        data['grammarAccuracy'] ?? data['grammaticalRangeAndAccuracy'],
      ),
      pronunciation: _double(data['pronunciation']),
      transcript: (data['transcript'] ?? '').toString(),
      summary: (data['summary'] ?? '').toString(),
      improvements: data['improvements'] is List
          ? (data['improvements'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'overallBand': overallBand,
    'fluencyCoherence': fluencyCoherence,
    'lexicalResource': lexicalResource,
    'grammarAccuracy': grammarAccuracy,
    'pronunciation': pronunciation,
    'transcript': transcript,
    'summary': summary,
    'improvements': improvements,
  };
}

class DiagnosticResultData {
  final String testId;
  final double overallBand;
  final double listeningBand;
  final double readingBand;
  final double writingBand;
  final double speakingBand;
  final double targetBand;
  final String ieltsType;
  final int listeningCorrect;
  final int listeningTotal;
  final int readingCorrect;
  final int readingTotal;
  final DiagnosticWritingEvaluation writingEvaluation;
  final DiagnosticSpeakingEvaluation speakingEvaluation;
  final String speakingAudioUrl;
  final int durationUsedSeconds;

  const DiagnosticResultData({
    required this.testId,
    required this.overallBand,
    required this.listeningBand,
    required this.readingBand,
    required this.writingBand,
    required this.speakingBand,
    required this.targetBand,
    required this.ieltsType,
    required this.listeningCorrect,
    required this.listeningTotal,
    required this.readingCorrect,
    required this.readingTotal,
    required this.writingEvaluation,
    required this.speakingEvaluation,
    required this.speakingAudioUrl,
    required this.durationUsedSeconds,
  });
}

class ObjectiveScore {
  final int correct;
  final int total;

  const ObjectiveScore({required this.correct, required this.total});
}

double _double(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

class _DiagnosticQuestionCard extends StatelessWidget {
  final DiagnosticQuestion question;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _DiagnosticQuestionCard({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isChoice = question.options.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.instruction.isNotEmpty) ...[
            Text(
              question.instruction,
              style: const TextStyle(
                color: DiagnosticColors.cyan,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
          ],
          Text(
            question.prompt,
            style: const TextStyle(
              color: DiagnosticColors.mainText,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (isChoice)
            ...question.options.entries.map(
              (entry) => _ChoiceTile(
                selected: value?.toString() == entry.key,
                label: entry.key,
                text: entry.value,
                onTap: () => onChanged(entry.key),
              ),
            )
          else
            TextFormField(
              initialValue: value?.toString() ?? '',
              onChanged: onChanged,
              style: const TextStyle(color: DiagnosticColors.mainText),
              decoration: const InputDecoration(
                hintText: 'Type your answer...',
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final bool selected;
  final String label;
  final String text;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.selected,
    required this.label,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? DiagnosticColors.cyan.withOpacity(.12)
              : DiagnosticColors.background.withOpacity(.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? DiagnosticColors.cyan : DiagnosticColors.border,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: selected
                  ? DiagnosticColors.cyan
                  : DiagnosticColors.surface,
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : DiagnosticColors.secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: DiagnosticColors.secondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RealAudioPlayerCard extends StatelessWidget {
  final String title;
  final bool playing;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlay;

  const _RealAudioPlayerCard({
    required this.title,
    required this.playing,
    required this.position,
    required this.duration,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final progress = (position.inMilliseconds / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _heroDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: onPlay,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: DiagnosticColors.mainText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_formatDuration(position)} / '
                '${_formatDuration(duration)}',
                style: const TextStyle(
                  color: DiagnosticColors.cyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
    );
  }
}

class _ReadingPassageCard extends StatelessWidget {
  final String title;
  final String passage;

  const _ReadingPassageCard({required this.title, required this.passage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: DiagnosticColors.mainText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            passage,
            style: const TextStyle(
              color: DiagnosticColors.secondaryText,
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _WritingTaskCard extends StatelessWidget {
  final WritingDiagnosticTask task;

  const _WritingTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.taskType,
            style: const TextStyle(
              color: DiagnosticColors.cyan,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            task.prompt,
            style: const TextStyle(
              color: DiagnosticColors.mainText,
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (task.visual.hasContent) ...[
            const SizedBox(height: 18),
            _WritingVisualCard(data: task.visual),
          ] else if (task.taskType.toLowerCase().contains('task 1')) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DiagnosticColors.error.withOpacity(.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: DiagnosticColors.error.withOpacity(.28),
                ),
              ),
              child: const Text(
                'This Task 1 question has no chart data. Please ask the '
                'administrator to regenerate or update this diagnostic test.',
                style: TextStyle(
                  color: DiagnosticColors.secondaryText,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${task.minimumWords}+ words • '
            '${task.recommendedMinutes} minutes',
            style: const TextStyle(color: DiagnosticColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _WritingVisualCard extends StatelessWidget {
  final WritingVisualData data;

  const _WritingVisualCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: DiagnosticColors.background.withOpacity(.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DiagnosticColors.cyan.withOpacity(.24)),
      ),
      child: Column(
        children: [
          if (data.title.isNotEmpty)
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DiagnosticColors.mainText,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (data.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              data.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DiagnosticColors.mutedText,
                fontSize: 9.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _WritingVisualRenderer(data: data),
          if (data.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              data.note,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DiagnosticColors.mutedText,
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WritingVisualRenderer extends StatelessWidget {
  final WritingVisualData data;

  const _WritingVisualRenderer({required this.data});

  @override
  Widget build(BuildContext context) {
    switch (data.type) {
      case 'table':
        return _WritingTableVisual(data: data);
      case 'process':
        return _WritingProcessVisual(data: data);
      case 'map':
        return _WritingMapVisual(data: data);
      case 'pie':
        return SizedBox(
          height: 250,
          child: CustomPaint(
            painter: _WritingPiePainter(data),
            child: const SizedBox.expand(),
          ),
        );
      case 'line':
        return SizedBox(
          height: 270,
          child: CustomPaint(
            painter: _WritingCartesianPainter(data, chartType: 'line'),
            child: const SizedBox.expand(),
          ),
        );
      case 'mixed':
        return SizedBox(
          height: 270,
          child: CustomPaint(
            painter: _WritingCartesianPainter(data, chartType: 'mixed'),
            child: const SizedBox.expand(),
          ),
        );
      case 'bar':
      default:
        return SizedBox(
          height: 270,
          child: CustomPaint(
            painter: _WritingCartesianPainter(data, chartType: 'bar'),
            child: const SizedBox.expand(),
          ),
        );
    }
  }
}

class _WritingCartesianPainter extends CustomPainter {
  final WritingVisualData data;
  final String chartType;

  const _WritingCartesianPainter(this.data, {required this.chartType});

  static const _palette = [
    Color(0xFF22D3EE),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const left = 43.0;
    const right = 10.0;
    const top = 18.0;
    const bottom = 58.0;

    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );

    final values = data.series.expand((item) => item.values).toList();
    if (values.isEmpty || data.categories.isEmpty) return;

    final maxValue = values.reduce(math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue * 1.12;

    final gridPaint = Paint()
      ..color = DiagnosticColors.border.withOpacity(.65)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = DiagnosticColors.mutedText.withOpacity(.8)
      ..strokeWidth = 1.2;

    for (var index = 0; index <= 4; index++) {
      final y = plot.bottom - (plot.height * index / 4);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _drawText(
        canvas,
        _formatChartNumber(safeMax * index / 4),
        Offset(0, y - 7),
        width: left - 5,
        align: TextAlign.right,
        fontSize: 8.5,
        color: DiagnosticColors.mutedText,
      );
    }

    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axisPaint,
    );

    final categoryWidth = plot.width / data.categories.length;
    final seriesCount = math.max(1, data.series.length);

    for (
      var categoryIndex = 0;
      categoryIndex < data.categories.length;
      categoryIndex++
    ) {
      final centerX = plot.left + categoryWidth * (categoryIndex + .5);

      _drawText(
        canvas,
        data.categories[categoryIndex],
        Offset(centerX - categoryWidth * .46, plot.bottom + 8),
        width: categoryWidth * .92,
        align: TextAlign.center,
        fontSize: 7.6,
        color: DiagnosticColors.mutedText,
        maxLines: 2,
      );

      if (chartType == 'line') continue;

      final availableWidth = categoryWidth * .70;
      final barWidth = math.min(22.0, availableWidth / seriesCount);

      for (
        var seriesIndex = 0;
        seriesIndex < data.series.length;
        seriesIndex++
      ) {
        final series = data.series[seriesIndex];
        if (categoryIndex >= series.values.length) continue;

        if (chartType == 'mixed' && seriesIndex == 1) {
          continue;
        }

        final value = series.values[categoryIndex];
        final height = plot.height * value / safeMax;
        final x = centerX - availableWidth / 2 + seriesIndex * barWidth;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            plot.bottom - height,
            math.max(3, barWidth - 2),
            height,
          ),
          const Radius.circular(4),
        );

        canvas.drawRRect(
          rect,
          Paint()..color = _palette[seriesIndex % _palette.length],
        );
      }
    }

    if (chartType == 'line' || chartType == 'mixed') {
      final startSeries = chartType == 'mixed' ? 1 : 0;

      for (
        var seriesIndex = startSeries;
        seriesIndex < data.series.length;
        seriesIndex++
      ) {
        final series = data.series[seriesIndex];
        final path = Path();
        final pointPaint = Paint()
          ..color = _palette[seriesIndex % _palette.length]
          ..style = PaintingStyle.fill;
        final linePaint = Paint()
          ..color = _palette[seriesIndex % _palette.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;

        for (
          var index = 0;
          index < math.min(data.categories.length, series.values.length);
          index++
        ) {
          final x = plot.left + categoryWidth * (index + .5);
          final y = plot.bottom - plot.height * series.values[index] / safeMax;

          if (index == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }

          canvas.drawCircle(Offset(x, y), 3.4, pointPaint);
        }

        canvas.drawPath(path, linePaint);
      }
    }

    _drawLegend(canvas, size);
  }

  void _drawLegend(Canvas canvas, Size size) {
    var x = 46.0;
    const y = 0.0;

    for (var index = 0; index < data.series.length; index++) {
      final name = data.series[index].name;
      if (name.isEmpty) continue;

      canvas.drawCircle(
        Offset(x + 4, y + 5),
        3.5,
        Paint()..color = _palette[index % _palette.length],
      );

      final painter = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(
            color: DiagnosticColors.secondaryText,
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);

      painter.paint(canvas, Offset(x + 11, y));
      x += painter.width + 25;

      if (x > size.width - 90) break;
    }
  }

  @override
  bool shouldRepaint(covariant _WritingCartesianPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.chartType != chartType;
  }
}

class _WritingPiePainter extends CustomPainter {
  final WritingVisualData data;

  const _WritingPiePainter(this.data);

  static const _palette = [
    Color(0xFF22D3EE),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (data.series.isEmpty || data.series.first.values.isEmpty) return;

    final values = data.series.first.values;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;

    final center = Offset(size.width * .34, size.height * .48);
    final radius = math.min(size.width * .24, size.height * .34);
    final rect = Rect.fromCircle(center: center, radius: radius);

    var startAngle = -math.pi / 2;

    for (var index = 0; index < values.length; index++) {
      final sweep = math.pi * 2 * values[index] / total;
      final paint = Paint()
        ..color = _palette[index % _palette.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweep, true, paint);
      startAngle += sweep;
    }

    canvas.drawCircle(
      center,
      radius * .53,
      Paint()..color = DiagnosticColors.background,
    );

    _drawText(
      canvas,
      data.unit.isEmpty ? 'Total' : data.unit,
      Offset(center.dx - radius * .45, center.dy - 8),
      width: radius * .9,
      align: TextAlign.center,
      fontSize: 10,
      color: DiagnosticColors.mainText,
    );

    final legendX = size.width * .62;
    var legendY = 28.0;

    for (
      var index = 0;
      index < math.min(data.categories.length, values.length);
      index++
    ) {
      canvas.drawCircle(
        Offset(legendX, legendY + 5),
        4,
        Paint()..color = _palette[index % _palette.length],
      );

      _drawText(
        canvas,
        '${data.categories[index]} '
        '(${_formatChartNumber(values[index])}${data.unit})',
        Offset(legendX + 10, legendY),
        width: size.width - legendX - 12,
        fontSize: 8.5,
        color: DiagnosticColors.secondaryText,
      );

      legendY += 28;
    }
  }

  @override
  bool shouldRepaint(covariant _WritingPiePainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _WritingTableVisual extends StatelessWidget {
  final WritingVisualData data;

  const _WritingTableVisual({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          DiagnosticColors.cyan.withOpacity(.10),
        ),
        dataRowMinHeight: 38,
        dataRowMaxHeight: 48,
        horizontalMargin: 12,
        columnSpacing: 22,
        columns: data.tableColumns
            .map(
              (column) => DataColumn(
                label: Text(
                  column,
                  style: const TextStyle(
                    color: DiagnosticColors.mainText,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
            .toList(),
        rows: data.tableRows
            .map(
              (row) => DataRow(
                cells: List.generate(
                  data.tableColumns.length,
                  (index) => DataCell(
                    Text(
                      index < row.length ? row[index] : '',
                      style: const TextStyle(
                        color: DiagnosticColors.secondaryText,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _WritingProcessVisual extends StatelessWidget {
  final WritingVisualData data;

  const _WritingProcessVisual({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(data.processSteps.length, (index) {
        final isLast = index == data.processSteps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: DiagnosticColors.gradient,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 34,
                    color: DiagnosticColors.cyan.withOpacity(.35),
                  ),
              ],
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: DiagnosticColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DiagnosticColors.border),
                ),
                child: Text(
                  data.processSteps[index],
                  style: const TextStyle(
                    color: DiagnosticColors.secondaryText,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _WritingMapVisual extends StatelessWidget {
  final WritingVisualData data;

  const _WritingMapVisual({required this.data});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.45,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: BoxDecoration(
              color: DiagnosticColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DiagnosticColors.border),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: const _MapGridPainter()),
                ),
                ...data.mapPoints.map((point) {
                  final x = point.x.clamp(0, 100) / 100;
                  final y = point.y.clamp(0, 100) / 100;

                  return Positioned(
                    left: x * math.max(0, constraints.maxWidth - 88),
                    top: y * math.max(0, constraints.maxHeight - 38),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 88),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: DiagnosticColors.cyan.withOpacity(.16),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: DiagnosticColors.cyan.withOpacity(.5),
                        ),
                      ),
                      child: Text(
                        point.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: DiagnosticColors.mainText,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DiagnosticColors.border.withOpacity(.55)
      ..strokeWidth = 1;

    for (var index = 1; index < 6; index++) {
      final x = size.width * index / 6;
      final y = size.height * index / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final roadPaint = Paint()
      ..color = DiagnosticColors.cyan.withOpacity(.25)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * .08, size.height * .72),
      Offset(size.width * .91, size.height * .28),
      roadPaint,
    );

    canvas.drawLine(
      Offset(size.width * .18, size.height * .12),
      Offset(size.width * .76, size.height * .90),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) => false;
}

void _drawText(
  Canvas canvas,
  String text,
  Offset offset, {
  required double width,
  TextAlign align = TextAlign.left,
  double fontSize = 9,
  Color color = DiagnosticColors.mutedText,
  int maxLines = 1,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: math.max(1, width));

  painter.paint(canvas, offset);
}

String _formatChartNumber(double value) {
  if ((value - value.round()).abs() < .01) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

class _SpeakingPromptCard extends StatelessWidget {
  final SpeakingPrompt prompt;

  const _SpeakingPromptCard({required this.prompt});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${prompt.part} • ${prompt.duration}',
            style: const TextStyle(
              color: DiagnosticColors.cyan,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            prompt.prompt,
            style: const TextStyle(
              color: DiagnosticColors.mainText,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakingRecorderCard extends StatelessWidget {
  final bool isRecording;
  final bool hasRecording;
  final AnimationController controller;
  final VoidCallback onTap;

  const _SpeakingRecorderCard({
    required this.isRecording,
    required this.hasRecording,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: _heroDecoration(),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) {
              final scale = isRecording ? 1 + controller.value * .08 : 1.0;

              return Transform.scale(
                scale: scale,
                child: IconButton.filled(
                  onPressed: onTap,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(78, 78),
                    backgroundColor: isRecording
                        ? DiagnosticColors.error
                        : DiagnosticColors.cyan,
                  ),
                  icon: Icon(
                    isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 35,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            isRecording
                ? 'Recording… tap to stop'
                : hasRecording
                ? 'Recording saved • tap to record again'
                : 'Tap to start your Speaking recording',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DiagnosticColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  final String title;
  final Map<String, double> rows;
  final String summary;

  const _FeedbackPanel({
    required this.title,
    required this.rows,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: DiagnosticColors.mainText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          ...rows.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: DiagnosticColors.secondaryText,
                      ),
                    ),
                  ),
                  Text(
                    entry.value.toStringAsFixed(1),
                    style: const TextStyle(
                      color: DiagnosticColors.cyan,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (summary.isNotEmpty) ...[
            const Divider(color: DiagnosticColors.border),
            Text(
              summary,
              style: const TextStyle(
                color: DiagnosticColors.mutedText,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionScrollView extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _SectionScrollView({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(17, 7, 17, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: DiagnosticColors.mainText,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(
              color: DiagnosticColors.mutedText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final int seconds;

  const _TimerBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: DiagnosticColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: DiagnosticColors.border),
      ),
      child: Text(
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}',
        style: const TextStyle(
          color: DiagnosticColors.cyan,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(22),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: DiagnosticColors.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DiagnosticColors.secondaryText),
            ),
            const SizedBox(height: 15),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _IntroTopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _IntroTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        const Text(
          'Diagnostic Assessment',
          style: TextStyle(
            color: DiagnosticColors.mainText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DiagnosticHeroCard extends StatelessWidget {
  final String ieltsType;
  final double targetBand;

  const _DiagnosticHeroCard({
    required this.ieltsType,
    required this.targetBand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: _heroDecoration(),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  DiagnosticColors.blue,
                  DiagnosticColors.cyan,
                  DiagnosticColors.violet,
                  DiagnosticColors.blue,
                ],
              ),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adaptive Level Check',
                  style: TextStyle(
                    color: DiagnosticColors.mainText,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$ieltsType • Target ${targetBand.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: DiagnosticColors.cyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Real content, real audio and criterion-based evaluation.',
                  style: TextStyle(
                    color: DiagnosticColors.mutedText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticInformationGrid extends StatelessWidget {
  const _DiagnosticInformationGrid();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _InfoCard(
            icon: Icons.schedule_rounded,
            title: '30 min',
            subtitle: 'Timed assessment',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _InfoCard(
            icon: Icons.grid_view_rounded,
            title: '4 Skills',
            subtitle: 'Complete baseline',
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 105,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DiagnosticColors.cyan),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: DiagnosticColors.mainText,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: DiagnosticColors.mutedText,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparationNotice extends StatelessWidget {
  const _PreparationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: const Column(
        children: [
          _PreparationRow(
            icon: Icons.headphones_rounded,
            text: 'Use headphones for the Listening section.',
          ),
          SizedBox(height: 11),
          _PreparationRow(
            icon: Icons.mic_none_rounded,
            text: 'Allow microphone permission for Speaking.',
          ),
          SizedBox(height: 11),
          _PreparationRow(
            icon: Icons.wifi_rounded,
            text: 'Keep a stable internet connection for AI evaluation.',
          ),
        ],
      ),
    );
  }
}

class _PreparationRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PreparationRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: DiagnosticColors.cyan),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: DiagnosticColors.secondaryText),
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;

  const _GradientButton({
    required this.title,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: DiagnosticColors.gradient,
        borderRadius: BorderRadius.circular(17),
      ),
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(title),
      ),
    );
  }
}

class _DiagnosticBackground extends StatelessWidget {
  const _DiagnosticBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(.7, -.9),
          radius: 1.1,
          colors: [
            DiagnosticColors.blue.withOpacity(.11),
            DiagnosticColors.background,
          ],
        ),
      ),
    );
  }
}

class DiagnosticColors {
  static const background = Color(0xFF08111F);
  static const surface = Color(0xFF111C2E);
  static const border = Color(0xFF25344C);
  static const mainText = Color(0xFFF8FAFC);
  static const secondaryText = Color(0xFFCBD5E1);
  static const mutedText = Color(0xFF94A3B8);
  static const subtleText = Color(0xFF64748B);
  static const cyan = Color(0xFF06B6D4);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF8B5CF6);
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);

  static const gradient = LinearGradient(colors: [cyan, blue, violet]);
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: DiagnosticColors.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: DiagnosticColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.12),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration _heroDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        DiagnosticColors.surface,
        DiagnosticColors.blue.withOpacity(.18),
        DiagnosticColors.cyan.withOpacity(.10),
        DiagnosticColors.violet.withOpacity(.10),
      ],
    ),
    borderRadius: BorderRadius.circular(23),
    border: Border.all(color: DiagnosticColors.cyan.withOpacity(.24)),
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
}

String _formatDuration(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
