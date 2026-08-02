import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/personalized_study_plan/personalized_study_plan-screen.dart';

class DiagnosticIntroScreen extends StatelessWidget {
  final String ieltsType;
  final double targetBand;

  const DiagnosticIntroScreen({
    super.key,
    this.ieltsType = 'Academic',
    this.targetBand = 7.0,
  });

  void _startTest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DiagnosticTestScreen(ieltsType: ieltsType, targetBand: targetBand),
      ),
    );
  }

  Future<void> _takeLater(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'diagnosticDeferred': true,
        'diagnosticDeferredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DiagnosticDeferredScreen()),
    );
  }

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
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IntroTopBar(onBack: () => Navigator.maybePop(context)),
                  const SizedBox(height: 25),
                  _DiagnosticHeroCard(
                    ieltsType: ieltsType,
                    targetBand: targetBand,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Your personalized starting point',
                    style: TextStyle(
                      color: DiagnosticColors.mainText,
                      fontSize: 27,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    'Complete a short four-skill assessment so IELTS AI Master can estimate your level and build a focused study plan.',
                    style: TextStyle(
                      color: DiagnosticColors.mutedText,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 23),
                  const _DiagnosticInformationGrid(),
                  const SizedBox(height: 18),
                  const _PreparationNotice(),
                  const SizedBox(height: 24),
                  _GradientButton(
                    title: 'Start Diagnostic Test',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => _startTest(context),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 53,
                    child: OutlinedButton(
                      onPressed: () => _takeLater(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DiagnosticColors.mainText,
                        side: BorderSide(color: Colors.white.withOpacity(0.09)),
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
                  const SizedBox(height: 13),
                  const Center(
                    child: Text(
                      'Your answers are saved securely during the assessment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: DiagnosticColors.subtleText,
                        fontSize: 10.5,
                        height: 1.4,
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
  final PageController _sectionController = PageController();
  final TextEditingController _listeningFormController =
      TextEditingController();
  final TextEditingController _listeningShortController =
      TextEditingController();
  final TextEditingController _writingController = TextEditingController();
  final TextEditingController _speakingNotesController =
      TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final AnimationController _audioController;
  late final AnimationController _waveController;

  Timer? _testTimer;
  Timer? _audioTimer;

  int _currentSection = 0;
  int _remainingSeconds = 30 * 60;
  int _audioSeconds = 0;
  bool _audioPlaying = false;
  bool _submitting = false;
  bool _speakingCompleted = false;

  final Map<int, String> _listeningAnswers = {};
  final Map<int, String> _readingAnswers = {};

  final List<String> _listeningCorrect = const [
    'B',
    'Wednesday',
    'C',
    'Library',
    'A',
    'B',
    'C',
    '18',
  ];

  final List<String> _readingCorrect = const [
    'True',
    'False',
    'Not Given',
    'B',
    'A',
    'C',
    'B',
    'A',
  ];

  @override
  void initState() {
    super.initState();

    _audioController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _startTestTimer();
  }

  @override
  void dispose() {
    _sectionController.dispose();
    _listeningFormController.dispose();
    _listeningShortController.dispose();
    _writingController.dispose();
    _speakingNotesController.dispose();
    _audioController.dispose();
    _waveController.dispose();
    _testTimer?.cancel();
    _audioTimer?.cancel();
    super.dispose();
  }

  void _startTestTimer() {
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        _submitDiagnostic();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  void _toggleAudio() {
    if (_audioPlaying) {
      _audioTimer?.cancel();
      _audioController.stop();
      setState(() => _audioPlaying = false);
      return;
    }

    setState(() => _audioPlaying = true);
    _audioController.repeat(reverse: true);

    _audioTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_audioSeconds >= 75) {
        timer.cancel();
        _audioController.stop();
        setState(() {
          _audioPlaying = false;
          _audioSeconds = 75;
        });
      } else {
        setState(() => _audioSeconds += 1);
      }
    });
  }

  void _toggleSpeakingRecording() {
    setState(() => _speakingCompleted = !_speakingCompleted);

    if (_speakingCompleted) {
      _waveController.repeat(reverse: true);
    } else {
      _waveController.stop();
    }
  }

  Future<void> _goNext() async {
    FocusScope.of(context).unfocus();

    if (_currentSection < 3) {
      await _sectionController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    await _submitDiagnostic();
  }

  Future<void> _goBack() async {
    FocusScope.of(context).unfocus();

    if (_currentSection > 0) {
      await _sectionController.previousPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _submitDiagnostic() async {
    if (_submitting) return;

    setState(() => _submitting = true);
    _testTimer?.cancel();

    final listeningScore = _calculateListeningScore();
    final readingScore = _calculateReadingScore();
    final writingBand = _estimateWritingBand();
    final speakingBand = _estimateSpeakingBand();

    final listeningBand = _scoreToDiagnosticBand(listeningScore, 8);
    final readingBand = _scoreToDiagnosticBand(readingScore, 8);

    final overallBand = _roundToHalfBand(
      (listeningBand + readingBand + writingBand + speakingBand) / 4,
    );

    final skillBands = <String, double>{
      'Listening': listeningBand,
      'Reading': readingBand,
      'Writing': writingBand,
      'Speaking': speakingBand,
    };

    final strongestSkill = skillBands.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    final weakestSkills = skillBands.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final weakestSkill = weakestSkills.first.key;
    final secondWeakestSkill = weakestSkills[1].key;

    final targetGap = math.max(0.0, widget.targetBand - overallBand).toDouble();

    final recommendedWeeks = _recommendedWeeks(targetGap);
    final startingLevel = _startingLevel(overallBand);

    final result = DiagnosticResultData(
      overallBand: overallBand,
      listeningBand: listeningBand,
      readingBand: readingBand,
      writingBand: writingBand,
      speakingBand: speakingBand,
      strongestSkill: strongestSkill,
      weakestSkill: weakestSkill,
      secondWeakestSkill: secondWeakestSkill,
      targetBand: widget.targetBand,
      targetGap: targetGap,
      recommendedWeeks: recommendedWeeks,
      startingLevel: startingLevel,
      ieltsType: widget.ieltsType,
    );

    await _saveDiagnosticResult(result);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DiagnosticResultScreen(result: result)),
    );
  }

  int _calculateListeningScore() {
    final answers = <String>[
      _listeningAnswers[0] ?? '',
      _listeningFormController.text.trim(),
      _listeningAnswers[2] ?? '',
      _listeningAnswers[3] ?? '',
      _listeningAnswers[4] ?? '',
      _listeningAnswers[5] ?? '',
      _listeningAnswers[6] ?? '',
      _listeningShortController.text.trim(),
    ];

    int score = 0;

    for (int index = 0; index < _listeningCorrect.length; index++) {
      if (answers[index].trim().toLowerCase() ==
          _listeningCorrect[index].trim().toLowerCase()) {
        score++;
      }
    }

    return score;
  }

  int _calculateReadingScore() {
    int score = 0;

    for (int index = 0; index < _readingCorrect.length; index++) {
      final answer = _readingAnswers[index] ?? '';

      if (answer.toLowerCase() == _readingCorrect[index].toLowerCase()) {
        score++;
      }
    }

    return score;
  }

  double _estimateWritingBand() {
    final text = _writingController.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;

    if (words >= 180) return 7.0;
    if (words >= 140) return 6.5;
    if (words >= 100) return 6.0;
    if (words >= 70) return 5.5;
    if (words >= 40) return 5.0;
    return 4.0;
  }

  double _estimateSpeakingBand() {
    final notesLength = _speakingNotesController.text.trim().length;

    if (_speakingCompleted && notesLength >= 100) return 6.5;
    if (_speakingCompleted && notesLength >= 50) return 6.0;
    if (_speakingCompleted) return 5.5;
    if (notesLength >= 40) return 5.0;
    return 4.0;
  }

  double _scoreToDiagnosticBand(int score, int total) {
    final ratio = score / total;

    if (ratio >= 0.88) return 7.5;
    if (ratio >= 0.75) return 7.0;
    if (ratio >= 0.63) return 6.5;
    if (ratio >= 0.50) return 6.0;
    if (ratio >= 0.38) return 5.5;
    if (ratio >= 0.25) return 5.0;
    return 4.0;
  }

  double _roundToHalfBand(double value) {
    return (value * 2).round() / 2;
  }

  int _recommendedWeeks(double gap) {
    if (gap <= 0.5) return 6;
    if (gap <= 1.0) return 8;
    if (gap <= 1.5) return 12;
    if (gap <= 2.0) return 16;
    return 20;
  }

  String _startingLevel(double band) {
    if (band < 4.0) return 'Foundation';
    if (band < 5.0) return 'Developing';
    if (band < 6.0) return 'Intermediate';
    if (band < 7.0) return 'Upper Intermediate';
    if (band < 8.0) return 'Advanced';
    return 'Expert';
  }

  Future<void> _saveDiagnosticResult(DiagnosticResultData result) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final resultRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('diagnosticResults')
        .doc();

    await resultRef.set({
      'resultId': resultRef.id,
      'ieltsType': result.ieltsType,
      'overallBand': result.overallBand,
      'targetBand': result.targetBand,
      'targetGap': result.targetGap,
      'skillBands': {
        'listening': result.listeningBand,
        'reading': result.readingBand,
        'writing': result.writingBand,
        'speaking': result.speakingBand,
      },
      'strongestSkill': result.strongestSkill,
      'weakestSkill': result.weakestSkill,
      'secondWeakestSkill': result.secondWeakestSkill,
      'recommendedWeeks': result.recommendedWeeks,
      'startingLevel': result.startingLevel,
      'writingWordCount': _writingController.text
          .trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length,
      'durationUsedSeconds': (30 * 60) - _remainingSeconds,
      'completedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(user.uid).set({
      'diagnosticCompleted': true,
      'diagnosticCompletedAt': FieldValue.serverTimestamp(),
      'currentBand': result.overallBand,
      'recommendedStartingLevel': result.startingLevel,
      'strongestSkill': result.strongestSkill,
      'weakestSkills': [result.weakestSkill, result.secondWeakestSkill],
      'recommendedPlanWeeks': result.recommendedWeeks,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitDialog();
        }
      },
      child: Scaffold(
        backgroundColor: DiagnosticColors.background,
        body: Stack(
          children: [
            const Positioned.fill(child: _DiagnosticBackground()),
            SafeArea(
              child: Column(
                children: [
                  _buildTestHeader(),
                  Expanded(
                    child: PageView(
                      controller: _sectionController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() => _currentSection = index);
                      },
                      children: [
                        _buildListeningSection(),
                        _buildReadingSection(),
                        _buildWritingSection(),
                        _buildSpeakingSection(),
                      ],
                    ),
                  ),
                  _buildBottomNavigation(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestHeader() {
    const sectionNames = ['Listening', 'Reading', 'Writing', 'Speaking'];

    const sectionIcons = [
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
                  borderRadius: BorderRadius.circular(14),
                  gradient: DiagnosticColors.gradient,
                ),
                child: Icon(
                  sectionIcons[_currentSection],
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sectionNames[_currentSection],
                      style: const TextStyle(
                        color: DiagnosticColors.mainText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Section ${_currentSection + 1} of 4',
                      style: const TextStyle(
                        color: DiagnosticColors.mutedText,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
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

  Widget _buildListeningSection() {
    return _SectionScrollView(
      title: 'Listening Diagnostic',
      description:
          'Listen to the short practice conversation and answer all 8 questions.',
      child: Column(
        children: [
          _AudioPlayerCard(
            isPlaying: _audioPlaying,
            seconds: _audioSeconds,
            controller: _audioController,
            onPlay: _toggleAudio,
          ),
          const SizedBox(height: 15),
          const _TestNotice(
            icon: Icons.info_outline_rounded,
            text:
                'Demo note: connect your real audio file later. The current player simulates a 75-second IELTS recording.',
          ),
          const SizedBox(height: 17),
          _QuestionCard(
            number: 1,
            title: 'Why is the student calling the learning centre?',
            child: _OptionGroup(
              options: const {
                'A': 'To cancel a course',
                'B': 'To ask about an English class',
                'C': 'To report a payment problem',
              },
              selected: _listeningAnswers[0],
              onSelected: (value) {
                setState(() => _listeningAnswers[0] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 2,
            title: 'Complete the form: The evening class starts on ______.',
            child: _CompactTextField(
              controller: _listeningFormController,
              hint: 'One word only',
            ),
          ),
          _QuestionCard(
            number: 3,
            title: 'Which course level does the adviser recommend?',
            child: _OptionGroup(
              options: const {
                'A': 'Beginner',
                'B': 'Elementary',
                'C': 'Intermediate',
              },
              selected: _listeningAnswers[2],
              onSelected: (value) {
                setState(() => _listeningAnswers[2] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 4,
            title: 'Where will the placement test take place?',
            child: _TextChoiceGroup(
              options: const ['Reception', 'Library', 'Computer room'],
              selected: _listeningAnswers[3],
              onSelected: (value) {
                setState(() => _listeningAnswers[3] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 5,
            title: 'What does the student need to bring?',
            child: _OptionGroup(
              options: const {
                'A': 'Photo identification',
                'B': 'A laptop',
                'C': 'A passport photograph',
              },
              selected: _listeningAnswers[4],
              onSelected: (value) {
                setState(() => _listeningAnswers[4] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 6,
            title: 'Which payment method is preferred?',
            child: _OptionGroup(
              options: const {
                'A': 'Cash',
                'B': 'Bank card',
                'C': 'Online transfer',
              },
              selected: _listeningAnswers[5],
              onSelected: (value) {
                setState(() => _listeningAnswers[5] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 7,
            title: 'Which extra facility is included?',
            child: _OptionGroup(
              options: const {
                'A': 'Free transport',
                'B': 'Private tutoring',
                'C': 'Online practice',
              },
              selected: _listeningAnswers[6],
              onSelected: (value) {
                setState(() => _listeningAnswers[6] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 8,
            title: 'How many students are normally in one class?',
            child: _CompactTextField(
              controller: _listeningShortController,
              hint: 'Enter a number',
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingSection() {
    return _SectionScrollView(
      title: 'Reading Diagnostic',
      description:
          'Read the passage and answer 8 questions using different IELTS question types.',
      child: Column(
        children: [
          const _ReadingPassageCard(),
          const SizedBox(height: 17),
          _QuestionCard(
            number: 1,
            title:
                'Community libraries are changing the services they provide.',
            child: _TextChoiceGroup(
              options: const ['True', 'False', 'Not Given'],
              selected: _readingAnswers[0],
              onSelected: (value) {
                setState(() => _readingAnswers[0] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 2,
            title: 'All modern libraries have stopped lending printed books.',
            child: _TextChoiceGroup(
              options: const ['True', 'False', 'Not Given'],
              selected: _readingAnswers[1],
              onSelected: (value) {
                setState(() => _readingAnswers[1] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 3,
            title: 'The first digital library opened in Canada.',
            child: _TextChoiceGroup(
              options: const ['True', 'False', 'Not Given'],
              selected: _readingAnswers[2],
              onSelected: (value) {
                setState(() => _readingAnswers[2] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 4,
            title: 'Which heading best matches paragraph two?',
            child: _OptionGroup(
              options: const {
                'A': 'The decline of public reading',
                'B': 'New functions for shared spaces',
                'C': 'Problems caused by technology',
              },
              selected: _readingAnswers[3],
              onSelected: (value) {
                setState(() => _readingAnswers[3] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 5,
            title: 'What is one benefit of library workshops?',
            child: _OptionGroup(
              options: const {
                'A': 'They help people develop practical skills',
                'B': 'They replace formal education',
                'C': 'They reduce the need for staff',
              },
              selected: _readingAnswers[4],
              onSelected: (value) {
                setState(() => _readingAnswers[4] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 6,
            title: 'Why do some visitors still prefer physical libraries?',
            child: _OptionGroup(
              options: const {
                'A': 'They dislike all digital tools',
                'B': 'Printed books are always free',
                'C': 'They value quiet study and human support',
              },
              selected: _readingAnswers[5],
              onSelected: (value) {
                setState(() => _readingAnswers[5] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 7,
            title: 'The writer suggests successful libraries should:',
            child: _OptionGroup(
              options: const {
                'A': 'focus only on technology',
                'B': 'balance traditional and modern services',
                'C': 'be managed entirely by volunteers',
              },
              selected: _readingAnswers[6],
              onSelected: (value) {
                setState(() => _readingAnswers[6] = value);
              },
            ),
          ),
          _QuestionCard(
            number: 8,
            title: 'What is the main purpose of the passage?',
            child: _OptionGroup(
              options: const {
                'A': 'To explain how libraries are adapting',
                'B': 'To compare libraries in different countries',
                'C': 'To argue that books are no longer useful',
              },
              selected: _readingAnswers[7],
              onSelected: (value) {
                setState(() => _readingAnswers[7] = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWritingSection() {
    final isAcademic = widget.ieltsType.toLowerCase().contains('academic');

    final taskTitle = isAcademic
        ? 'Academic short writing task'
        : 'General Training short writing task';

    final taskText = isAcademic
        ? 'The chart shows the percentage of students using three learning methods: classroom lessons (45%), online courses (35%), and private tutoring (20%). Summarize the main information and make relevant comparisons.'
        : 'You recently joined an English course, but the class schedule is unsuitable. Write a letter to the course manager. Explain the problem, describe your preferred schedule, and request a solution.';

    final wordCount = _writingController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;

    return _SectionScrollView(
      title: 'Writing Diagnostic',
      description:
          'Write a focused response. This short task helps estimate your grammar, vocabulary and organization.',
      child: Column(
        children: [
          _WritingTaskCard(
            title: taskTitle,
            text: taskText,
            isAcademic: isAcademic,
          ),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$wordCount words',
                      style: TextStyle(
                        color: wordCount >= 100
                            ? DiagnosticColors.success
                            : DiagnosticColors.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _writingController,
                  maxLines: 15,
                  minLines: 10,
                  onChanged: (_) => setState(() {}),
                  cursorColor: DiagnosticColors.cyan,
                  style: const TextStyle(
                    color: DiagnosticColors.mainText,
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Write your answer here. Aim for at least 100–150 words for this short diagnostic task.',
                    hintStyle: const TextStyle(
                      color: DiagnosticColors.subtleText,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                    filled: true,
                    fillColor: DiagnosticColors.background.withOpacity(0.58),
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
          const SizedBox(height: 14),
          const _TestNotice(
            icon: Icons.auto_awesome_rounded,
            text:
                'After submission, the production AI evaluator can analyze Task Response, Coherence, Vocabulary and Grammar.',
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakingSection() {
    return _SectionScrollView(
      title: 'Speaking Diagnostic',
      description:
          'Complete three short speaking prompts. Record naturally without reading a prepared answer.',
      child: Column(
        children: [
          const _SpeakingPromptCard(
            part: 'Introduction',
            duration: '30–45 seconds',
            prompt:
                'Please introduce yourself and explain why you are preparing for IELTS.',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          const _SpeakingPromptCard(
            part: 'Cue Card',
            duration: '1–2 minutes',
            prompt:
                'Describe a skill you would like to learn. You should say what the skill is, why you want to learn it, how you would learn it, and explain how it would help you.',
            icon: Icons.style_outlined,
          ),
          const SizedBox(height: 12),
          const _SpeakingPromptCard(
            part: 'Follow-up',
            duration: '45–60 seconds',
            prompt:
                'Do you think technology has made it easier for people to learn new skills? Why or why not?',
            icon: Icons.forum_outlined,
          ),
          const SizedBox(height: 16),
          _SpeakingRecorderCard(
            isRecording: _speakingCompleted,
            controller: _waveController,
            onTap: _toggleSpeakingRecording,
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preparation notes',
                  style: TextStyle(
                    color: DiagnosticColors.mainText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _speakingNotesController,
                  minLines: 4,
                  maxLines: 7,
                  cursorColor: DiagnosticColors.cyan,
                  style: const TextStyle(
                    color: DiagnosticColors.mainText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Add keywords or note what you discussed. Do not write a complete script.',
                    hintStyle: const TextStyle(
                      color: DiagnosticColors.subtleText,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: DiagnosticColors.background.withOpacity(0.58),
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
          const SizedBox(height: 14),
          const _TestNotice(
            icon: Icons.mic_none_rounded,
            text:
                'Demo note: connect a real recorder and pronunciation analysis service later. This screen already contains the full production flow.',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 17),
      decoration: BoxDecoration(
        color: DiagnosticColors.background.withOpacity(0.97),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          if (_currentSection > 0)
            Expanded(
              child: SizedBox(
                height: 53,
                child: OutlinedButton(
                  onPressed: _goBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DiagnosticColors.mainText,
                    side: BorderSide(color: Colors.white.withOpacity(0.09)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
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
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: DiagnosticColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(23),
          ),
          title: const Text(
            'Leave diagnostic test?',
            style: TextStyle(
              color: DiagnosticColors.mainText,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Your current answers on this device will be lost.',
            style: TextStyle(color: DiagnosticColors.mutedText, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Continue Test',
                style: TextStyle(color: DiagnosticColors.cyan),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Leave',
                style: TextStyle(color: DiagnosticColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      Navigator.pop(context);
    }
  }
}

class DiagnosticResultScreen extends StatelessWidget {
  final DiagnosticResultData result;

  const DiagnosticResultScreen({super.key, required this.result});

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
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 28),
              child: Column(
                children: [
                  const _ResultHeader(),
                  const SizedBox(height: 22),
                  _OverallBandHero(result: result),
                  const SizedBox(height: 17),
                  _SkillBandGrid(result: result),
                  const SizedBox(height: 17),
                  _StrengthWeaknessCard(result: result),
                  const SizedBox(height: 17),
                  _RecommendedPlanCard(result: result),
                  const SizedBox(height: 17),
                  _TargetGapCard(result: result),
                  const SizedBox(height: 24),
                  _GradientButton(
                    title: 'Create My Study Plan',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              StudyPlanPreviewScreen(result: result),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 53,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const DiagnosticIntroScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retake Diagnostic'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DiagnosticColors.mainText,
                        side: BorderSide(color: Colors.white.withOpacity(0.09)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
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

class DiagnosticResultData {
  final double overallBand;
  final double listeningBand;
  final double readingBand;
  final double writingBand;
  final double speakingBand;
  final String strongestSkill;
  final String weakestSkill;
  final String secondWeakestSkill;
  final double targetBand;
  final double targetGap;
  final int recommendedWeeks;
  final String startingLevel;
  final String ieltsType;

  const DiagnosticResultData({
    required this.overallBand,
    required this.listeningBand,
    required this.readingBand,
    required this.writingBand,
    required this.speakingBand,
    required this.strongestSkill,
    required this.weakestSkill,
    required this.secondWeakestSkill,
    required this.targetBand,
    required this.targetGap,
    required this.recommendedWeeks,
    required this.startingLevel,
    required this.ieltsType,
  });
}

class _DiagnosticInformationGrid extends StatelessWidget {
  const _DiagnosticInformationGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _IntroFeatureCard(
                icon: Icons.schedule_rounded,
                title: '20–30 min',
                subtitle: 'Estimated duration',
                accent: Color(0xFF22D3EE),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _IntroFeatureCard(
                icon: Icons.grid_view_rounded,
                title: '4 Skills',
                subtitle: 'Complete assessment',
                accent: Color(0xFF60A5FA),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _IntroFeatureCard(
                icon: Icons.headphones_rounded,
                title: 'Headphones',
                subtitle: 'Recommended',
                accent: Color(0xFFA78BFA),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _IntroFeatureCard(
                icon: Icons.psychology_alt_rounded,
                title: 'AI Plan',
                subtitle: 'After your result',
                accent: Color(0xFF34D399),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntroFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _IntroFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: DiagnosticColors.mainText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
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

class _IntroTopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _IntroTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: DiagnosticColors.surface,
            foregroundColor: DiagnosticColors.mainText,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 11),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: DiagnosticColors.gradient,
          ),
          child: const Icon(
            Icons.analytics_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diagnostic Assessment',
                style: TextStyle(
                  color: DiagnosticColors.mainText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Personalized IELTS starting point',
                style: TextStyle(
                  color: DiagnosticColors.mutedText,
                  fontSize: 10,
                ),
              ),
            ],
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
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DiagnosticColors.blue.withOpacity(0.27),
            DiagnosticColors.cyan.withOpacity(0.12),
            DiagnosticColors.violet.withOpacity(0.19),
          ],
        ),
        border: Border.all(color: DiagnosticColors.cyan.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: DiagnosticColors.blue.withOpacity(0.13),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          const _DiagnosticRing(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adaptive Level Check',
                  style: TextStyle(
                    color: DiagnosticColors.mainText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$ieltsType • Target Band ${targetBand.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: DiagnosticColors.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Listening, Reading, Writing and Speaking are combined into one intelligent baseline.',
                  style: TextStyle(
                    color: DiagnosticColors.secondaryText,
                    fontSize: 10.5,
                    height: 1.45,
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

class _DiagnosticRing extends StatelessWidget {
  const _DiagnosticRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFF2563EB),
            Color(0xFF06B6D4),
            Color(0xFF8B5CF6),
            Color(0xFF2563EB),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: DiagnosticColors.cyan.withOpacity(0.2),
            blurRadius: 20,
          ),
        ],
      ),
      child: Container(
        width: 69,
        height: 69,
        decoration: const BoxDecoration(
          color: Color(0xFF0B1726),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: DiagnosticColors.cyan,
          size: 28,
        ),
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
      decoration: BoxDecoration(
        color: DiagnosticColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: const Column(
        children: [
          _PreparationRow(
            icon: Icons.volume_up_outlined,
            text: 'Use headphones for the listening section.',
          ),
          SizedBox(height: 12),
          _PreparationRow(
            icon: Icons.do_not_disturb_on_outlined,
            text: 'Choose a quiet place with minimal interruption.',
          ),
          SizedBox(height: 12),
          _PreparationRow(
            icon: Icons.route_outlined,
            text: 'Your result will generate a personalized preparation plan.',
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
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: DiagnosticColors.cyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: DiagnosticColors.cyan, size: 18),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: DiagnosticColors.secondaryText,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
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
              fontWeight: FontWeight.w800,
              letterSpacing: -0.45,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(
              color: DiagnosticColors.mutedText,
              fontSize: 12.5,
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

class _AudioPlayerCard extends StatelessWidget {
  final bool isPlaying;
  final int seconds;
  final AnimationController controller;
  final VoidCallback onPlay;

  const _AudioPlayerCard({
    required this.isPlaying,
    required this.seconds,
    required this.controller,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: LinearGradient(
          colors: [
            DiagnosticColors.blue.withOpacity(0.2),
            DiagnosticColors.cyan.withOpacity(0.09),
          ],
        ),
        border: Border.all(color: DiagnosticColors.cyan.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPlay,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 53,
                    height: 53,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: DiagnosticColors.gradient,
                      boxShadow: [
                        BoxShadow(
                          color: DiagnosticColors.cyan.withOpacity(0.22),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning Centre Enquiry',
                      style: TextStyle(
                        color: DiagnosticColors.mainText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Diagnostic Listening • One playback recommended',
                      style: TextStyle(
                        color: DiagnosticColors.mutedText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_formatSeconds(seconds)} / 01:15',
                style: const TextStyle(
                  color: DiagnosticColors.cyan,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return _AudioWave(progress: isPlaying ? controller.value : 0.3);
            },
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: seconds / 75,
              minHeight: 5,
              backgroundColor: DiagnosticColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DiagnosticColors.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioWave extends StatelessWidget {
  final double progress;

  const _AudioWave({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 35,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(32, (index) {
          final base = 8 + (math.sin(index * 0.85 + progress * 5) + 1) * 8;

          return Expanded(
            child: Container(
              height: base,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF2563EB), Color(0xFF22D3EE)],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int number;
  final String title;
  final Widget child;

  const _QuestionCard({
    required this.number,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: DiagnosticColors.gradient,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: DiagnosticColors.mainText,
                    fontSize: 12.8,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _OptionGroup extends StatelessWidget {
  final Map<String, String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _OptionGroup({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.entries.map((entry) {
        final isSelected = entry.key == selected;

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(entry.key),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DiagnosticColors.blue.withOpacity(0.17)
                      : DiagnosticColors.background.withOpacity(0.42),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? DiagnosticColors.cyan.withOpacity(0.55)
                        : Colors.white.withOpacity(0.055),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? DiagnosticColors.cyan
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? DiagnosticColors.cyan
                              : DiagnosticColors.border,
                        ),
                      ),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: isSelected
                              ? DiagnosticColors.background
                              : DiagnosticColors.mutedText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          color: DiagnosticColors.secondaryText,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TextChoiceGroup extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _TextChoiceGroup({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: options.map((option) {
        final isSelected = option == selected;

        return ChoiceChip(
          selected: isSelected,
          onSelected: (_) => onSelected(option),
          label: Text(option),
          labelStyle: TextStyle(
            color: isSelected
                ? DiagnosticColors.background
                : DiagnosticColors.secondaryText,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
          selectedColor: DiagnosticColors.cyan,
          backgroundColor: DiagnosticColors.background.withOpacity(0.48),
          side: BorderSide(
            color: isSelected
                ? DiagnosticColors.cyan
                : Colors.white.withOpacity(0.06),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }).toList(),
    );
  }
}

class _CompactTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _CompactTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: DiagnosticColors.cyan,
      style: const TextStyle(color: DiagnosticColors.mainText, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: DiagnosticColors.subtleText,
          fontSize: 12,
        ),
        filled: true,
        fillColor: DiagnosticColors.background.withOpacity(0.48),
        border: _fieldBorder(DiagnosticColors.border),
        enabledBorder: _fieldBorder(DiagnosticColors.border),
        focusedBorder: _fieldBorder(DiagnosticColors.cyan, width: 1.4),
      ),
    );
  }
}

class _ReadingPassageCard extends StatelessWidget {
  const _ReadingPassageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FB),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.17),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE CHANGING ROLE OF COMMUNITY LIBRARIES',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'For generations, public libraries were mainly places where people borrowed printed books. Although that service remains important, many libraries are now expanding their role. They offer digital resources, internet access, study areas and assistance for people who need help using technology.',
            style: TextStyle(
              color: Color(0xFF334155),
              fontSize: 12.2,
              height: 1.62,
            ),
          ),
          SizedBox(height: 11),
          Text(
            'Some libraries also organize language classes, employment workshops and creative activities. These programmes allow visitors to develop practical skills while meeting other members of the community. For students and remote workers, the library may provide a quiet environment that is difficult to find at home.',
            style: TextStyle(
              color: Color(0xFF334155),
              fontSize: 12.2,
              height: 1.62,
            ),
          ),
          SizedBox(height: 11),
          Text(
            'Digital services have not removed the need for physical libraries. Many people still value personal support from trained staff and access to reliable information. The most successful libraries appear to combine traditional services with modern facilities, adapting to local needs rather than following a single model.',
            style: TextStyle(
              color: Color(0xFF334155),
              fontSize: 12.2,
              height: 1.62,
            ),
          ),
        ],
      ),
    );
  }
}

class _WritingTaskCard extends StatelessWidget {
  final String title;
  final String text;
  final bool isAcademic;

  const _WritingTaskCard({
    required this.title,
    required this.text,
    required this.isAcademic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            DiagnosticColors.violet.withOpacity(0.18),
            DiagnosticColors.blue.withOpacity(0.12),
          ],
        ),
        border: Border.all(color: DiagnosticColors.violet.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: DiagnosticColors.violet.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isAcademic
                      ? Icons.bar_chart_rounded
                      : Icons.mail_outline_rounded,
                  color: const Color(0xFFA78BFA),
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: DiagnosticColors.mainText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Text(
                '15 min',
                style: TextStyle(
                  color: Color(0xFFA78BFA),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            text,
            style: const TextStyle(
              color: DiagnosticColors.secondaryText,
              fontSize: 12.2,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakingPromptCard extends StatelessWidget {
  final String part;
  final String duration;
  final String prompt;
  final IconData icon;

  const _SpeakingPromptCard({
    required this.part,
    required this.duration,
    required this.prompt,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: DiagnosticColors.success.withOpacity(0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: DiagnosticColors.success, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      part,
                      style: const TextStyle(
                        color: DiagnosticColors.mainText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      duration,
                      style: const TextStyle(
                        color: DiagnosticColors.success,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  prompt,
                  style: const TextStyle(
                    color: DiagnosticColors.secondaryText,
                    fontSize: 11.5,
                    height: 1.5,
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

class _SpeakingRecorderCard extends StatelessWidget {
  final bool isRecording;
  final AnimationController controller;
  final VoidCallback onTap;

  const _SpeakingRecorderCard({
    required this.isRecording,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            DiagnosticColors.success.withOpacity(0.13),
            DiagnosticColors.cyan.withOpacity(0.08),
          ],
        ),
        border: Border.all(color: DiagnosticColors.success.withOpacity(0.19)),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return SizedBox(
                height: 45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(22, (index) {
                    final height = isRecording
                        ? 8 +
                              (math.sin(index * 0.8 + controller.value * 7) +
                                      1) *
                                  10
                        : 7.0;

                    return Container(
                      width: 4,
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isRecording
                            ? DiagnosticColors.success
                            : DiagnosticColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording
                      ? DiagnosticColors.error
                      : DiagnosticColors.success,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isRecording
                                  ? DiagnosticColors.error
                                  : DiagnosticColors.success)
                              .withOpacity(0.25),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(
                  isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            isRecording
                ? 'Tap to finish your speaking response'
                : 'Tap to start the speaking simulation',
            style: const TextStyle(
              color: DiagnosticColors.secondaryText,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TestNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TestNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: DiagnosticColors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiagnosticColors.cyan.withOpacity(0.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DiagnosticColors.cyan, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: DiagnosticColors.mutedText,
                fontSize: 10.5,
                height: 1.45,
              ),
            ),
          ),
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
    final danger = seconds <= 300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: (danger ? DiagnosticColors.error : DiagnosticColors.blue)
            .withOpacity(0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: (danger ? DiagnosticColors.error : DiagnosticColors.cyan)
              .withOpacity(0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            color: danger ? DiagnosticColors.error : DiagnosticColors.cyan,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            _formatSeconds(seconds),
            style: TextStyle(
              color: danger
                  ? DiagnosticColors.error
                  : DiagnosticColors.mainText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: DiagnosticColors.gradient,
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diagnostic Complete',
                style: TextStyle(
                  color: DiagnosticColors.mainText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Your personalized IELTS baseline',
                style: TextStyle(
                  color: DiagnosticColors.mutedText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.verified_rounded,
          color: DiagnosticColors.success,
          size: 25,
        ),
      ],
    );
  }
}

class _OverallBandHero extends StatelessWidget {
  final DiagnosticResultData result;

  const _OverallBandHero({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            DiagnosticColors.blue.withOpacity(0.25),
            DiagnosticColors.cyan.withOpacity(0.11),
            DiagnosticColors.violet.withOpacity(0.18),
          ],
        ),
        border: Border.all(color: DiagnosticColors.cyan.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 127,
            height: 127,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFF2563EB),
                  Color(0xFF06B6D4),
                  Color(0xFF8B5CF6),
                  Color(0xFF2563EB),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: DiagnosticColors.cyan.withOpacity(0.2),
                  blurRadius: 25,
                ),
              ],
            ),
            child: Container(
              width: 108,
              height: 108,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF0B1726),
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    result.overallBand.toStringAsFixed(1),
                    style: const TextStyle(
                      color: DiagnosticColors.mainText,
                      fontSize: 37,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ESTIMATED BAND',
                    style: TextStyle(
                      color: DiagnosticColors.cyan,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            result.startingLevel,
            style: const TextStyle(
              color: DiagnosticColors.mainText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${result.ieltsType} preparation starting level',
            style: const TextStyle(
              color: DiagnosticColors.mutedText,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillBandGrid extends StatelessWidget {
  final DiagnosticResultData result;

  const _SkillBandGrid({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ResultSkillCard(
                icon: Icons.headphones_rounded,
                title: 'Listening',
                band: result.listeningBand,
                accent: const Color(0xFF22D3EE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ResultSkillCard(
                icon: Icons.menu_book_rounded,
                title: 'Reading',
                band: result.readingBand,
                accent: const Color(0xFF60A5FA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ResultSkillCard(
                icon: Icons.edit_note_rounded,
                title: 'Writing',
                band: result.writingBand,
                accent: const Color(0xFFA78BFA),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ResultSkillCard(
                icon: Icons.mic_rounded,
                title: 'Speaking',
                band: result.speakingBand,
                accent: const Color(0xFF34D399),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultSkillCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final double band;
  final Color accent;

  const _ResultSkillCard({
    required this.icon,
    required this.title,
    required this.band,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const Spacer(),
              Text(
                band.toStringAsFixed(1),
                style: TextStyle(
                  color: accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: DiagnosticColors.mainText,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StrengthWeaknessCard extends StatelessWidget {
  final DiagnosticResultData result;

  const _StrengthWeaknessCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _InsightRow(
            icon: Icons.emoji_events_outlined,
            title: 'Strongest Skill',
            value: result.strongestSkill,
            accent: DiagnosticColors.success,
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 14),
          _InsightRow(
            icon: Icons.center_focus_strong_rounded,
            title: 'Main Focus',
            value: '${result.weakestSkill} & ${result.secondWeakestSkill}',
            accent: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  const _InsightRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.11),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: DiagnosticColors.mutedText,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: DiagnosticColors.mainText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendedPlanCard extends StatelessWidget {
  final DiagnosticResultData result;

  const _RecommendedPlanCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            DiagnosticColors.success.withOpacity(0.13),
            DiagnosticColors.cyan.withOpacity(0.08),
          ],
        ),
        border: Border.all(color: DiagnosticColors.success.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 67,
            height: 67,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DiagnosticColors.success.withOpacity(0.13),
              border: Border.all(
                color: DiagnosticColors.success.withOpacity(0.35),
              ),
            ),
            child: Text(
              '${result.recommendedWeeks}',
              style: const TextStyle(
                color: DiagnosticColors.success,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommended Plan',
                  style: TextStyle(
                    color: DiagnosticColors.mainText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${result.recommendedWeeks} weeks of focused preparation based on your target and current performance.',
                  style: const TextStyle(
                    color: DiagnosticColors.secondaryText,
                    fontSize: 10.8,
                    height: 1.45,
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

class _TargetGapCard extends StatelessWidget {
  final DiagnosticResultData result;

  const _TargetGapCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final progress = result.targetBand == 0
        ? 0.0
        : (result.overallBand / result.targetBand).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Target Band Progress',
                style: TextStyle(
                  color: DiagnosticColors.mainText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${result.overallBand.toStringAsFixed(1)} → ${result.targetBand.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: DiagnosticColors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: DiagnosticColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DiagnosticColors.cyan,
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              const Text(
                'Target gap',
                style: TextStyle(
                  color: DiagnosticColors.mutedText,
                  fontSize: 10.5,
                ),
              ),
              const Spacer(),
              Text(
                '${result.targetGap.toStringAsFixed(1)} band',
                style: const TextStyle(
                  color: DiagnosticColors.mainText,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StudyPlanPreviewScreen extends StatelessWidget {
  final DiagnosticResultData result;

  const StudyPlanPreviewScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DiagnosticColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _DiagnosticBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(26),
                  decoration: _cardDecoration(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: DiagnosticColors.gradient,
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Study plan ready',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: DiagnosticColors.mainText,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A ${result.recommendedWeeks}-week plan will focus first '
                        'on ${result.weakestSkill} and '
                        '${result.secondWeakestSkill}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: DiagnosticColors.mutedText,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _GradientButton(
                        title: 'Continue to Dashboard',
                        icon: Icons.dashboard_outlined,
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PersonalizedStudyPlanScreen(
                                currentBand: 5.5,
                                targetBand: 7.0,
                                dailyStudyMinutes: 45,
                                availableDays: [
                                  'Monday',
                                  'Tuesday',
                                  'Wednesday',
                                  'Thursday',
                                  'Friday',
                                ],
                                weakQuestionTypes: [
                                  'Matching Headings',
                                  'Map Labelling',
                                  'Writing Coherence',
                                ],
                                recentScores: {
                                  'Listening': 6.0,
                                  'Reading': 5.0,
                                  'Writing': 5.5,
                                  'Speaking': 6.0,
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DiagnosticDeferredScreen extends StatelessWidget {
  const DiagnosticDeferredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DiagnosticColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _DiagnosticBackground()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(26),
                  decoration: _cardDecoration(),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: DiagnosticColors.cyan,
                        size: 47,
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Diagnostic saved for later',
                        style: TextStyle(
                          color: DiagnosticColors.mainText,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 9),
                      Text(
                        'You can start the assessment anytime from your dashboard.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: DiagnosticColors.mutedText,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GradientButton({
    required this.title,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: DiagnosticColors.gradient,
          boxShadow: [
            BoxShadow(
              color: DiagnosticColors.blue.withOpacity(0.26),
              blurRadius: 22,
              offset: const Offset(0, 11),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DiagnosticBackground extends StatelessWidget {
  const _DiagnosticBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF040A13),
                Color(0xFF07111F),
                Color(0xFF09182A),
                Color(0xFF07111F),
              ],
              stops: [0, 0.35, 0.72, 1],
            ),
          ),
        ),
        const Positioned(
          top: -150,
          right: -120,
          child: _GlowOrb(size: 340, color: Color(0x2B2563EB)),
        ),
        const Positioned(
          top: 340,
          left: -160,
          child: _GlowOrb(size: 320, color: Color(0x1706B6D4)),
        ),
        const Positioned(
          bottom: -180,
          right: -150,
          child: _GlowOrb(size: 390, color: Color(0x178B5CF6)),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

class DiagnosticColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF101C2E);
  static const surfaceLight = Color(0xFF182A40);
  static const mainText = Color(0xFFF8FAFC);
  static const secondaryText = Color(0xFFCBD5E1);
  static const mutedText = Color(0xFF94A3B8);
  static const subtleText = Color(0xFF64748B);
  static const border = Color(0xFF26364A);
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const success = Color(0xFF34D399);
  static const error = Color(0xFFEF4444);

  static const gradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: DiagnosticColors.surface.withOpacity(0.92),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.065)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.14),
        blurRadius: 17,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
}

String _formatSeconds(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
