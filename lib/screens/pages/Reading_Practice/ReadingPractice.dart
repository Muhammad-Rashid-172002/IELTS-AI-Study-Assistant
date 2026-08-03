import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to open Reading.')),
      );
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    return Scaffold(
      backgroundColor: RColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _ReadingBackground()),
          SafeArea(
            bottom: false,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: userRef.snapshots(),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data?.data() ?? {};

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: userRef
                      .collection('reading_results')
                      .orderBy('completedAt', descending: true)
                      .limit(5)
                      .snapshots(),
                  builder: (context, resultSnapshot) {
                    final results =
                        resultSnapshot.data?.docs
                            .map(ReadingRecentResult.fromDocument)
                            .toList() ??
                        [];

                    return _ReadingHome(
                      currentBand: _asDouble(
                        userData['readingBand'] ??
                            (results.isNotEmpty
                                ? results.first.estimatedBand
                                : 0),
                      ),
                      weakTypes: _asStringList(
                        userData['weakReadingQuestionTypes'],
                      ),
                      recentResults: results,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingHome extends StatelessWidget {
  final double currentBand;
  final List<String> weakTypes;
  final List<ReadingRecentResult> recentResults;

  const _ReadingHome({
    required this.currentBand,
    required this.weakTypes,
    required this.recentResults,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWeak = weakTypes.isEmpty
        ? const [
            'Matching headings',
            'True / False / Not Given',
            'Summary completion',
          ]
        : weakTypes;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: _Header(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
            child: _BandHero(band: currentBand),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: _WeaknessCard(types: effectiveWeak),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 18, 12),
            child: _SectionTitle(
              title: 'Reading Modes',
              subtitle: 'Choose a complete test or focused reading activity',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final mode = ReadingMode.values[index];
              return _ModeCard(
                mode: mode,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReadingTestBrowserScreen(mode: mode),
                  ),
                ),
              );
            }, childCount: ReadingMode.values.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: 1.18,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 24, 18, 12),
            child: _SectionTitle(
              title: 'Question Type Practice',
              subtitle: 'Build accuracy in a specific IELTS Reading format',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final type = ReadingQuestionType.values[index];
              final isWeak = effectiveWeak
                  .map((e) => e.toLowerCase())
                  .contains(type.label.toLowerCase());

              return _QuestionTypeCard(
                type: type,
                weak: isWeak,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReadingTestBrowserScreen(questionType: type.label),
                  ),
                ),
              );
            }, childCount: ReadingQuestionType.values.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 24, 18, 12),
            child: _SectionTitle(
              title: 'Recent Reading Results',
              subtitle: 'Latest scores, bands and reading speed',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
          sliver: recentResults.isEmpty
              ? const SliverToBoxAdapter(
                  child: _EmptyCard(
                    title: 'No reading results yet',
                    subtitle:
                        'Complete your first reading activity to see analytics.',
                  ),
                )
              : SliverList.separated(
                  itemCount: recentResults.length,
                  itemBuilder: (_, index) =>
                      _RecentResultCard(result: recentResults[index]),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                ),
        ),
      ],
    );
  }
}

class ReadingTestBrowserScreen extends StatefulWidget {
  final ReadingMode? mode;
  final String? questionType;

  const ReadingTestBrowserScreen({super.key, this.mode, this.questionType});

  @override
  State<ReadingTestBrowserScreen> createState() =>
      _ReadingTestBrowserScreenState();
}

class _ReadingTestBrowserScreenState extends State<ReadingTestBrowserScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _pulseAnimation;

  bool _loading = true;
  String? _error;

  String get _title =>
      widget.questionType ?? widget.mode?.label ?? 'Reading Practice';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: .93, end: 1.07).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadTest();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTest() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final minimumDelay = Future<void>.delayed(
      const Duration(milliseconds: 900),
    );

    try {
      final tests = await _fetchTests();
      await minimumDelay;

      if (!mounted) return;

      if (tests.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No published reading test is available for this selection.';
        });
        return;
      }

      final test = await _selectBestTest(tests);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: ReadingPracticeScreen(test: test),
          ),
        ),
      );
    } on FirebaseException catch (error) {
      await minimumDelay;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.code == 'permission-denied'
            ? 'You do not have permission to access reading tests.'
            : 'Reading tests could not be loaded.';
      });
    } catch (_) {
      await minimumDelay;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong while preparing your reading test.';
      });
    }
  }

  Future<List<ReadingTest>> _fetchTests() async {
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('reading_tests')
          .where('status', isEqualTo: 'published');

      if (widget.questionType != null) {
        query = query.where(
          'primaryQuestionType',
          isEqualTo: widget.questionType,
        );
      } else if (widget.mode != null) {
        if (widget.mode == ReadingMode.academic) {
          query = query.where('ieltsType', isEqualTo: 'Academic');
        } else if (widget.mode == ReadingMode.generalTraining) {
          query = query.where('ieltsType', isEqualTo: 'General Training');
        } else {
          query = query.where('mode', isEqualTo: widget.mode!.firestoreValue);
        }
      }

      final snapshot = await query.limit(60).get();
      return snapshot.docs
          .map(ReadingTest.fromDocument)
          .where(
            (test) => test.passages.isNotEmpty && test.questions.isNotEmpty,
          )
          .toList();
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') rethrow;

      final snapshot = await FirebaseFirestore.instance
          .collection('reading_tests')
          .where('status', isEqualTo: 'published')
          .limit(200)
          .get();

      return snapshot.docs
          .where((doc) => _matches(doc.data()))
          .map(ReadingTest.fromDocument)
          .where(
            (test) => test.passages.isNotEmpty && test.questions.isNotEmpty,
          )
          .toList();
    }
  }

  bool _matches(Map<String, dynamic> data) {
    if (widget.questionType != null) {
      final questions = _asList(data['questions']);
      return questions.any(
        (item) => _asMap(item)['type']?.toString() == widget.questionType,
      );
    }

    if (widget.mode == ReadingMode.academic) {
      return data['ieltsType'] == 'Academic';
    }

    if (widget.mode == ReadingMode.generalTraining) {
      return data['ieltsType'] == 'General Training';
    }

    if (widget.mode != null) {
      return data['mode'] == widget.mode!.firestoreValue;
    }

    return true;
  }

  Future<ReadingTest> _selectBestTest(List<ReadingTest> tests) async {
    if (tests.length == 1) return tests.first;

    final user = FirebaseAuth.instance.currentUser;
    final attemptedIds = <String>{};

    if (user != null) {
      try {
        final recent = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reading_results')
            .orderBy('completedAt', descending: true)
            .limit(20)
            .get();

        for (final doc in recent.docs) {
          final id = (doc.data()['testId'] ?? '').toString();
          if (id.isNotEmpty) attemptedIds.add(id);
        }
      } catch (_) {}
    }

    final unseen = tests
        .where((test) => !attemptedIds.contains(test.id))
        .toList();
    final pool = unseen.isNotEmpty ? unseen : tests;
    return pool[math.Random.secure().nextInt(pool.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _ReadingBackground()),
          SafeArea(
            child: Column(
              children: [
                _InnerHeader(
                  title: _title,
                  subtitle: _loading
                      ? 'Preparing your next reading activity'
                      : 'Reading activity unavailable',
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _loading ? _loadingState() : _errorState(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingState() {
    return Center(
      key: const ValueKey('reading-loading'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
          decoration: _heroDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [RColors.cyan, RColors.violet],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: RColors.cyan.withOpacity(.22),
                        blurRadius: 30,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 43,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RColors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Loading a published passage, questions and reading tools.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RColors.secondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const LinearProgressIndicator(
                minHeight: 5,
                color: RColors.cyan,
                backgroundColor: RColors.border,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              const SizedBox(height: 20),
              const _PreparationRow(
                icon: Icons.article_outlined,
                title: 'Preparing passages',
              ),
              const SizedBox(height: 10),
              const _PreparationRow(
                icon: Icons.checklist_rounded,
                title: 'Loading question sets',
              ),
              const SizedBox(height: 10),
              const _PreparationRow(
                icon: Icons.analytics_outlined,
                title: 'Starting reading analytics',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      key: const ValueKey('reading-error'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.find_in_page_outlined,
                size: 58,
                color: Color(0xFFF97316),
              ),
              const SizedBox(height: 18),
              const Text(
                'No matching reading test',
                style: TextStyle(
                  color: RColors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                _error ?? 'Please choose another reading activity.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: RColors.secondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: _GradientButton(
                  title: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: _loadTest,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Choose another activity'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReadingPracticeScreen extends StatefulWidget {
  final ReadingTest test;

  const ReadingPracticeScreen({super.key, required this.test});

  @override
  State<ReadingPracticeScreen> createState() => _ReadingPracticeScreenState();
}

class _ReadingPracticeScreenState extends State<ReadingPracticeScreen> {
  final Map<int, String> _answers = {};
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, String> _notes = {};
  final Set<String> _highlightedParagraphs = {};
  final Map<int, Set<String>> _eliminatedOptions = {};
  final Map<int, int> _timeByPassage = {};
  final Set<int> _markedForReview = {};

  Timer? _timer;
  Timer? _autoSaveDebounce;
  int _remainingSeconds = 0;
  int _currentPassageIndex = 0;
  int _currentQuestionIndex = 0;
  int _lastTrackedPassage = 1;
  bool _submitting = false;
  bool _eliminateMode = false;
  bool _mobileShowQuestions = true;
  bool _restoringDraft = true;

  bool get _examMode =>
      widget.test.mode == 'exam' || widget.test.mode == 'full';

  bool get _toolsEnabled => !_examMode && widget.test.toolsEnabled;

  ReadingPassage get _currentPassage =>
      widget.test.passages[_currentPassageIndex];

  List<ReadingQuestion> get _currentPassageQuestions =>
      widget.test.questions
          .where(
            (question) =>
                question.passageNumber == _currentPassage.passageNumber,
          )
          .toList()
        ..sort((a, b) => a.number.compareTo(b.number));

  ReadingQuestion get _currentQuestion =>
      _currentPassageQuestions[_currentQuestionIndex];

  int get _currentGlobalIndex => _globalQuestionIndex(_currentQuestion);

  int get _answeredCount =>
      _answers.values.where((answer) => answer.trim().isNotEmpty).length;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.test.durationSeconds;
    _lastTrackedPassage = _currentPassage.passageNumber;

    for (int i = 0; i < widget.test.questions.length; i++) {
      if (widget.test.questions[i].options.isEmpty) {
        _controllers[i] = TextEditingController();
      }
    }

    _restoreDraft();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoSaveDebounce?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _restoringDraft = false);
      return;
    }

    try {
      final draft = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reading_drafts')
          .doc(widget.test.id)
          .get();

      if (!draft.exists || !mounted) {
        if (mounted) setState(() => _restoringDraft = false);
        return;
      }

      final data = draft.data() ?? {};
      final rawAnswers = _asMap(data['answers']);
      final restoredAnswers = <int, String>{};

      rawAnswers.forEach((key, value) {
        final index = int.tryParse(key);
        if (index != null &&
            index >= 0 &&
            index < widget.test.questions.length) {
          restoredAnswers[index] = value.toString();
        }
      });

      final restoredReview = _asList(data['markedForReview'])
          .map((value) => _asInt(value, fallback: -1))
          .where((value) => value >= 0 && value < widget.test.questions.length)
          .toSet();

      final passageIndex = _asInt(data['currentPassageIndex']);
      final safePassageIndex = passageIndex
          .clamp(0, widget.test.passages.length - 1)
          .toInt();

      final passageNumber =
          widget.test.passages[safePassageIndex].passageNumber;
      final passageQuestionCount = widget.test.questions
          .where((question) => question.passageNumber == passageNumber)
          .length;
      final questionIndex = _asInt(data['currentQuestionIndex']);
      final safeQuestionIndex = passageQuestionCount == 0
          ? 0
          : questionIndex.clamp(0, passageQuestionCount - 1).toInt();

      setState(() {
        _answers
          ..clear()
          ..addAll(restoredAnswers);
        _markedForReview
          ..clear()
          ..addAll(restoredReview);
        _currentPassageIndex = safePassageIndex;
        _currentQuestionIndex = safeQuestionIndex;
        _lastTrackedPassage =
            widget.test.passages[safePassageIndex].passageNumber;
        _remainingSeconds = _asInt(
          data['remainingSeconds'],
          fallback: widget.test.durationSeconds,
        ).clamp(0, widget.test.durationSeconds).toInt();
        _mobileShowQuestions = data['mobileShowQuestions'] != false;
        _restoringDraft = false;
      });

      for (final entry in restoredAnswers.entries) {
        _controllers[entry.key]?.text = entry.value;
      }
    } catch (_) {
      if (mounted) setState(() => _restoringDraft = false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _restoringDraft) return;

      _timeByPassage[_lastTrackedPassage] =
          (_timeByPassage[_lastTrackedPassage] ?? 0) + 1;

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        _submit(force: true);
      } else {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds % 15 == 0) _scheduleAutoSave(immediate: true);
      }
    });
  }

  int _globalQuestionIndex(ReadingQuestion question) => widget.test.questions
      .indexWhere((item) => item.number == question.number);

  void _scheduleAutoSave({bool immediate = false}) {
    _autoSaveDebounce?.cancel();
    if (immediate) {
      _saveDraft();
      return;
    }
    _autoSaveDebounce = Timer(const Duration(milliseconds: 650), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _submitting) return;

    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) _answers[entry.key] = value;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reading_drafts')
          .doc(widget.test.id)
          .set({
            'testId': widget.test.id,
            'title': widget.test.title,
            'answers': _answers.map((key, value) => MapEntry('$key', value)),
            'markedForReview': _markedForReview.toList(),
            'currentPassageIndex': _currentPassageIndex,
            'currentQuestionIndex': _currentQuestionIndex,
            'remainingSeconds': _remainingSeconds,
            'mobileShowQuestions': _mobileShowQuestions,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _goToPassage(int index, {bool showQuestions = false}) {
    if (index < 0 || index >= widget.test.passages.length) return;

    setState(() {
      _currentPassageIndex = index;
      _currentQuestionIndex = 0;
      _lastTrackedPassage = widget.test.passages[index].passageNumber;
      _mobileShowQuestions = showQuestions;
    });
    _scheduleAutoSave();
  }

  void _goToQuestion(int localIndex) {
    if (localIndex < 0 || localIndex >= _currentPassageQuestions.length) return;
    setState(() {
      _currentQuestionIndex = localIndex;
      _mobileShowQuestions = true;
    });
    _scheduleAutoSave();
  }

  void _goToGlobalQuestion(int globalIndex) {
    if (globalIndex < 0 || globalIndex >= widget.test.questions.length) return;

    final target = widget.test.questions[globalIndex];
    final passageIndex = widget.test.passages.indexWhere(
      (passage) => passage.passageNumber == target.passageNumber,
    );
    if (passageIndex < 0) return;

    final passageQuestions =
        widget.test.questions
            .where((question) => question.passageNumber == target.passageNumber)
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    final localIndex = passageQuestions.indexWhere(
      (question) => question.number == target.number,
    );

    setState(() {
      _currentPassageIndex = passageIndex;
      _currentQuestionIndex = localIndex < 0 ? 0 : localIndex;
      _lastTrackedPassage = target.passageNumber;
      _mobileShowQuestions = true;
    });
    _scheduleAutoSave();
  }

  void _goToPreviousQuestion() {
    if (_currentGlobalIndex > 0) {
      _goToGlobalQuestion(_currentGlobalIndex - 1);
    }
  }

  void _goToNextQuestion() {
    if (_currentGlobalIndex < widget.test.questions.length - 1) {
      _goToGlobalQuestion(_currentGlobalIndex + 1);
    } else {
      _submit();
    }
  }

  void _skipQuestion() {
    if (_currentGlobalIndex < widget.test.questions.length - 1) {
      _goToGlobalQuestion(_currentGlobalIndex + 1);
    }
  }

  void _toggleReview() {
    final index = _currentGlobalIndex;
    setState(() {
      if (_markedForReview.contains(index)) {
        _markedForReview.remove(index);
      } else {
        _markedForReview.add(index);
      }
    });
    _scheduleAutoSave();
  }

  Future<void> _addNote(int paragraphIndex) async {
    if (!_toolsEnabled) return;
    final key = _paragraphKey(_currentPassage.passageNumber, paragraphIndex);
    final controller = TextEditingController(text: _notes[key.hashCode] ?? '');

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RColors.surface,
        title: const Text('Add Note', style: TextStyle(color: RColors.text)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Write your note for this paragraph...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (value != null && mounted) {
      setState(() => _notes[key.hashCode] = value);
      _scheduleAutoSave();
    }
  }

  void _toggleHighlight(int paragraphIndex) {
    if (!_toolsEnabled) return;
    final key = _paragraphKey(_currentPassage.passageNumber, paragraphIndex);

    setState(() {
      if (_highlightedParagraphs.contains(key)) {
        _highlightedParagraphs.remove(key);
      } else {
        _highlightedParagraphs.add(key);
      }
    });
  }

  Future<void> _showDictionary() async {
    if (!_toolsEnabled) return;

    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RColors.surface,
        title: const Text(
          'Reading Dictionary',
          style: TextStyle(color: RColors.text),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Enter a word',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onSubmitted: (word) {
            Navigator.pop(context);
            _showWordMeaning(word);
          },
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final word = controller.text.trim();
              Navigator.pop(context);
              _showWordMeaning(word);
            },
            child: const Text('Look Up'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showWordMeaning(String word) async {
    if (word.trim().isEmpty || !mounted) return;

    final synonyms = _findSynonyms(word);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RColors.surface,
        title: Text(word, style: const TextStyle(color: RColors.text)),
        content: Text(
          synonyms.isEmpty
              ? 'No saved synonym was generated for this word. Use the paragraph context to infer its meaning.'
              : 'Synonyms: ${synonyms.join(', ')}',
          style: const TextStyle(color: RColors.secondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<String> _findSynonyms(String word) {
    final target = word.toLowerCase().trim();
    for (final entry in _currentPassage.synonyms.entries) {
      if (entry.key.toLowerCase() == target) return entry.value;
    }
    return const [];
  }

  Future<void> _explainPassage() async {
    if (!_toolsEnabled) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RColors.surface,
        title: const Text(
          'Simplified Explanation',
          style: TextStyle(color: RColors.text),
        ),
        content: SingleChildScrollView(
          child: Text(
            _currentPassage.simplifiedExplanation,
            style: const TextStyle(color: RColors.secondary, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSynonyms() async {
    if (!_toolsEnabled) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: RColors.surface,
      showDragHandle: true,
      builder: (context) {
        final entries = _currentPassage.synonyms.entries.toList();

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              const Text(
                'Passage Synonyms',
                style: TextStyle(
                  color: RColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              if (entries.isEmpty)
                const Text(
                  'No synonym set was generated for this passage.',
                  style: TextStyle(color: RColors.secondary),
                )
              else
                ...entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      entry.key,
                      style: const TextStyle(
                        color: RColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      entry.value.join(', '),
                      style: const TextStyle(color: RColors.secondary),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _toggleEliminateMode() {
    if (!_toolsEnabled) return;
    setState(() => _eliminateMode = !_eliminateMode);
  }

  void _selectOption(ReadingQuestion question, String option) {
    final globalIndex = _globalQuestionIndex(question);

    if (_eliminateMode) {
      setState(() {
        final eliminated = _eliminatedOptions.putIfAbsent(
          globalIndex,
          () => {},
        );
        if (eliminated.contains(option)) {
          eliminated.remove(option);
        } else {
          eliminated.add(option);
        }
      });
      return;
    }

    setState(() => _answers[globalIndex] = option);
    _scheduleAutoSave();
  }

  void _onTextAnswerChanged(int globalIndex, String value) {
    setState(() => _answers[globalIndex] = value.trim());
    _scheduleAutoSave();
  }

  Future<bool> _confirmSubmit() async {
    final unanswered = widget.test.questions.length - _answeredCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RColors.surface,
        title: const Text(
          'Submit Reading Test?',
          style: TextStyle(color: RColors.text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Answered: $_answeredCount/${widget.test.questions.length}',
              style: const TextStyle(color: RColors.secondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Unanswered: $unanswered',
              style: TextStyle(
                color: unanswered > 0 ? const Color(0xFFF97316) : RColors.green,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Marked for review: ${_markedForReview.length}',
              style: const TextStyle(color: RColors.secondary),
            ),
            if (unanswered > 0) ...[
              const SizedBox(height: 12),
              const Text(
                'Unanswered questions will be counted as incorrect.',
                style: TextStyle(color: RColors.muted, height: 1.4),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Test'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.done_all_rounded),
            label: const Text('Submit'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _submit({bool force = false}) async {
    if (_submitting) return;

    for (final entry in _controllers.entries) {
      _answers[entry.key] = entry.value.text.trim();
    }

    if (!force && !await _confirmSubmit()) return;
    if (!mounted) return;

    setState(() => _submitting = true);
    _timer?.cancel();
    _autoSaveDebounce?.cancel();

    final result = ReadingResultCalculator.calculate(
      test: widget.test,
      answers: _answers,
      durationUsedSeconds: widget.test.durationSeconds - _remainingSeconds,
      timeByPassage: _timeByPassage,
    );

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final resultRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reading_results')
            .doc();

        await resultRef.set({
          'resultId': resultRef.id,
          'testId': widget.test.id,
          'title': widget.test.title,
          'ieltsType': widget.test.ieltsType,
          'mode': widget.test.mode,
          'rawScore': result.rawScore,
          'totalQuestions': result.totalQuestions,
          'estimatedBand': result.estimatedBand,
          'accuracyPercent': result.accuracyPercent,
          'passageScores': result.passageScores,
          'questionTypeAccuracy': result.questionTypeAccuracy,
          'readingSpeedWpm': result.readingSpeedWpm,
          'unansweredQuestions': result.unansweredQuestions,
          'timeSpentPerPassage': result.timeSpentPerPassage,
          'weakQuestionTypes': result.weakQuestionTypes,
          'durationUsedSeconds': result.durationUsedSeconds,
          'markedForReviewCount': _markedForReview.length,
          'answers': _answers.map((key, value) => MapEntry('$key', value)),
          'completedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'readingBand': result.estimatedBand,
          'weakReadingQuestionTypes': result.weakQuestionTypes,
          'lastReadingTestAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reading_drafts')
            .doc(widget.test.id)
            .delete();
      } catch (_) {}
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingResultScreen(test: widget.test, result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringDraft) {
      return const Scaffold(
        backgroundColor: RColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = _currentQuestion;
    final globalIndex = _currentGlobalIndex;
    final isLastQuestion = globalIndex == widget.test.questions.length - 1;

    return Scaffold(
      backgroundColor: RColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _ReadingBackground()),
          SafeArea(
            child: Column(
              children: [
                _PracticeHeader(
                  title: widget.test.title,
                  passage: _currentPassageIndex + 1,
                  passageTotal: widget.test.passages.length,
                  question: question.number,
                  questionTotal: widget.test.questions.length,
                  seconds: _remainingSeconds,
                ),
                _ReadingProgressSummary(
                  answered: _answeredCount,
                  total: widget.test.questions.length,
                  markedForReview: _markedForReview.length,
                ),
                _PassageTabs(
                  passages: widget.test.passages,
                  selectedIndex: _currentPassageIndex,
                  onSelected: (index) => _goToPassage(index),
                ),
                if (_toolsEnabled)
                  _ReadingToolbar(
                    eliminateMode: _eliminateMode,
                    onDictionary: _showDictionary,
                    onExplain: _explainPassage,
                    onSynonyms: _showSynonyms,
                    onEliminate: _toggleEliminateMode,
                  )
                else
                  const _ExamModeNotice(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;

                      if (wide) {
                        return Row(
                          children: [
                            Expanded(
                              flex: 11,
                              child: _PassageView(
                                passage: _currentPassage,
                                highlightedParagraphs: _highlightedParagraphs,
                                notes: _notes,
                                toolsEnabled: _toolsEnabled,
                                onHighlight: _toggleHighlight,
                                onNote: _addNote,
                              ),
                            ),
                            Container(width: 1, color: RColors.border),
                            Expanded(
                              flex: 9,
                              child: _QuestionPane(
                                question: question,
                                selected: _answers[globalIndex],
                                controller: _controllers[globalIndex],
                                eliminated:
                                    _eliminatedOptions[globalIndex] ?? {},
                                eliminateMode: _eliminateMode,
                                onOption: (option) =>
                                    _selectOption(question, option),
                                onTextChanged: (value) =>
                                    _onTextAnswerChanged(globalIndex, value),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _MobileReadingViewSwitcher(
                            showQuestions: _mobileShowQuestions,
                            onPassage: () =>
                                setState(() => _mobileShowQuestions = false),
                            onQuestions: () =>
                                setState(() => _mobileShowQuestions = true),
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _mobileShowQuestions
                                  ? _QuestionPane(
                                      key: ValueKey(
                                        'question-${question.number}',
                                      ),
                                      question: question,
                                      selected: _answers[globalIndex],
                                      controller: _controllers[globalIndex],
                                      eliminated:
                                          _eliminatedOptions[globalIndex] ?? {},
                                      eliminateMode: _eliminateMode,
                                      onOption: (option) =>
                                          _selectOption(question, option),
                                      onTextChanged: (value) =>
                                          _onTextAnswerChanged(
                                            globalIndex,
                                            value,
                                          ),
                                    )
                                  : _PassageView(
                                      key: ValueKey(
                                        'passage-${_currentPassage.passageNumber}',
                                      ),
                                      passage: _currentPassage,
                                      highlightedParagraphs:
                                          _highlightedParagraphs,
                                      notes: _notes,
                                      toolsEnabled: _toolsEnabled,
                                      onHighlight: _toggleHighlight,
                                      onNote: _addNote,
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _QuestionNavigator(
                  questions: widget.test.questions,
                  currentGlobalIndex: globalIndex,
                  answeredGlobalIndices: _answers.entries
                      .where((entry) => entry.value.trim().isNotEmpty)
                      .map((entry) => entry.key)
                      .toSet(),
                  markedForReviewGlobalIndices: _markedForReview,
                  onTap: _goToGlobalQuestion,
                ),
                _BottomBar(
                  loading: _submitting,
                  backEnabled: globalIndex > 0,
                  finalQuestion: isLastQuestion,
                  markedForReview: _markedForReview.contains(globalIndex),
                  onBack: _goToPreviousQuestion,
                  onSkip: _skipQuestion,
                  onToggleReview: _toggleReview,
                  onNext: _goToNextQuestion,
                  onSubmit: () => _submit(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReadingResultScreen extends StatelessWidget {
  final ReadingTest test;
  final ReadingTestResult result;

  const ReadingResultScreen({
    super.key,
    required this.test,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _ReadingBackground()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
              children: [
                const _ResultHeader(),
                const SizedBox(height: 20),
                _ResultHero(result: result),
                const SizedBox(height: 14),
                _MetricGrid(result: result),
                const SizedBox(height: 22),
                const _SectionTitle(
                  title: 'Passage Performance',
                  subtitle: 'Score and time used for every passage',
                ),
                const SizedBox(height: 10),
                ...result.passageScores.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _PerformanceCard(
                      title: entry.key,
                      value: entry.value,
                      subtitle:
                          '${result.timeSpentPerPassage[entry.key] ?? 0}s spent',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionTitle(
                  title: 'Question Type Performance',
                  subtitle: 'Accuracy across IELTS Reading formats',
                ),
                const SizedBox(height: 10),
                ...result.questionTypeAccuracy.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _PerformanceCard(
                      title: entry.key,
                      value: entry.value,
                      color: RColors.violet,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _RecommendationCard(result: result),
                const SizedBox(height: 22),
                _GradientButton(
                  title: 'Back to Reading',
                  icon: Icons.menu_book_rounded,
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const ReadingScreen()),
                    (route) => route.isFirst,
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

class ReadingTest {
  final String id;
  final String title;
  final String description;
  final String ieltsType;
  final String mode;
  final String difficulty;
  final int durationSeconds;
  final bool toolsEnabled;
  final List<ReadingPassage> passages;
  final List<ReadingQuestion> questions;

  const ReadingTest({
    required this.id,
    required this.title,
    required this.description,
    required this.ieltsType,
    required this.mode,
    required this.difficulty,
    required this.durationSeconds,
    required this.toolsEnabled,
    required this.passages,
    required this.questions,
  });

  factory ReadingTest.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return ReadingTest(
      id: doc.id,
      title: (data['title'] ?? 'Reading Test').toString(),
      description: (data['description'] ?? '').toString(),
      ieltsType: (data['ieltsType'] ?? 'Academic').toString(),
      mode: (data['mode'] ?? 'passage').toString(),
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      durationSeconds: _asInt(data['durationSeconds'], fallback: 3600),
      toolsEnabled: data['toolsEnabled'] != false,
      passages: _asList(
        data['passages'],
      ).map((item) => ReadingPassage.fromMap(_asMap(item))).toList(),
      questions: _asList(
        data['questions'],
      ).map((item) => ReadingQuestion.fromMap(_asMap(item))).toList(),
    );
  }

  int get totalWords =>
      passages.fold(0, (sum, passage) => sum + passage.wordCount);
}

class ReadingPassage {
  final String passageId;
  final int passageNumber;
  final String title;
  final String topic;
  final String text;
  final List<String> paragraphs;
  final int wordCount;
  final String simplifiedExplanation;
  final Map<String, List<String>> synonyms;

  const ReadingPassage({
    required this.passageId,
    required this.passageNumber,
    required this.title,
    required this.topic,
    required this.text,
    required this.paragraphs,
    required this.wordCount,
    required this.simplifiedExplanation,
    required this.synonyms,
  });

  factory ReadingPassage.fromMap(Map<String, dynamic> map) {
    final synonymMap = <String, List<String>>{};
    final rawSynonyms = _asMap(map['synonyms']);

    rawSynonyms.forEach((key, value) {
      synonymMap[key] = _asStringList(value);
    });

    final text = (map['text'] ?? '').toString();
    final paragraphs = _asStringList(map['paragraphs']);

    return ReadingPassage(
      passageId: (map['passageId'] ?? '').toString(),
      passageNumber: _asInt(map['passageNumber'], fallback: 1),
      title: (map['title'] ?? 'Reading Passage').toString(),
      topic: (map['topic'] ?? 'General').toString(),
      text: text,
      paragraphs: paragraphs.isEmpty
          ? text
                .split(RegExp(r'\n\s*\n'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : paragraphs,
      wordCount: _asInt(
        map['wordCount'],
        fallback: text.split(RegExp(r'\s+')).length,
      ),
      simplifiedExplanation: (map['simplifiedExplanation'] ?? '').toString(),
      synonyms: synonymMap,
    );
  }
}

class ReadingQuestion {
  final int number;
  final int passageNumber;
  final String type;
  final String prompt;
  final List<String> options;
  final String correctAnswer;
  final List<String> acceptedAnswers;
  final String explanation;
  final String evidenceText;
  final int paragraphIndex;
  final List<String> keywords;
  final String wordLimit;

  const ReadingQuestion({
    required this.number,
    required this.passageNumber,
    required this.type,
    required this.prompt,
    required this.options,
    required this.correctAnswer,
    required this.acceptedAnswers,
    required this.explanation,
    required this.evidenceText,
    required this.paragraphIndex,
    required this.keywords,
    required this.wordLimit,
  });

  factory ReadingQuestion.fromMap(Map<String, dynamic> map) {
    final accepted = _asStringList(map['acceptedAnswers']);

    final rawType = _firstNonEmptyString([
      map['type'],
      map['questionType'],
      map['format'],
    ], fallback: 'Short answers');

    final rawPrompt = _firstNonEmptyString([
      map['prompt'],
      map['question'],
      map['sentence'],
      map['stem'],
      map['text'],
      map['statement'],
      map['instruction'],
    ]);

    final correctAnswer = _firstNonEmptyString([
      map['correctAnswer'],
      map['answer'],
      map['correct'],
      map['expectedAnswer'],
    ]);

    final normalizedPrompt = _normalizeReadingQuestionPrompt(
      type: rawType,
      prompt: rawPrompt,
      correctAnswer: correctAnswer,
      number: _asInt(map['number']),
    );

    return ReadingQuestion(
      number: _asInt(map['number']),
      passageNumber: _asInt(map['passageNumber'], fallback: 1),
      type: rawType,
      prompt: normalizedPrompt,
      options: _asStringList(map['options']).isNotEmpty
          ? _asStringList(map['options'])
          : _asStringList(map['choices']),
      correctAnswer: correctAnswer,
      acceptedAnswers: accepted.isEmpty
          ? (correctAnswer.isEmpty ? const [] : [correctAnswer])
          : accepted,
      explanation: _firstNonEmptyString([
        map['explanation'],
        map['reason'],
        map['feedback'],
      ]),
      evidenceText: _firstNonEmptyString([
        map['evidenceText'],
        map['evidence'],
        map['sourceText'],
      ]),
      paragraphIndex: _asInt(map['paragraphIndex']),
      keywords: _asStringList(map['keywords']),
      wordLimit: _firstNonEmptyString([map['wordLimit'], map['instruction']]),
    );
  }
}

class ReadingTestResult {
  final int rawScore;
  final int totalQuestions;
  final double estimatedBand;
  final int accuracyPercent;
  final Map<String, int> passageScores;
  final Map<String, int> questionTypeAccuracy;
  final int readingSpeedWpm;
  final int unansweredQuestions;
  final Map<String, int> timeSpentPerPassage;
  final List<String> weakQuestionTypes;
  final int durationUsedSeconds;

  const ReadingTestResult({
    required this.rawScore,
    required this.totalQuestions,
    required this.estimatedBand,
    required this.accuracyPercent,
    required this.passageScores,
    required this.questionTypeAccuracy,
    required this.readingSpeedWpm,
    required this.unansweredQuestions,
    required this.timeSpentPerPassage,
    required this.weakQuestionTypes,
    required this.durationUsedSeconds,
  });
}

class ReadingResultCalculator {
  static ReadingTestResult calculate({
    required ReadingTest test,
    required Map<int, String> answers,
    required int durationUsedSeconds,
    required Map<int, int> timeByPassage,
  }) {
    int score = 0;
    int unanswered = 0;

    final passageTotals = <int, int>{};
    final passageCorrect = <int, int>{};
    final typeTotals = <String, int>{};
    final typeCorrect = <String, int>{};

    for (int i = 0; i < test.questions.length; i++) {
      final question = test.questions[i];
      final answer = (answers[i] ?? '').trim();

      if (answer.isEmpty) unanswered++;

      final correct = question.acceptedAnswers.any(
        (accepted) => _normalize(accepted) == _normalize(answer),
      );

      passageTotals[question.passageNumber] =
          (passageTotals[question.passageNumber] ?? 0) + 1;
      typeTotals[question.type] = (typeTotals[question.type] ?? 0) + 1;

      if (correct) {
        score++;
        passageCorrect[question.passageNumber] =
            (passageCorrect[question.passageNumber] ?? 0) + 1;
        typeCorrect[question.type] = (typeCorrect[question.type] ?? 0) + 1;
      }
    }

    final passageScores = <String, int>{};
    passageTotals.forEach((passage, total) {
      passageScores['Passage $passage'] =
          (((passageCorrect[passage] ?? 0) / total) * 100).round();
    });

    final typeAccuracy = <String, int>{};
    typeTotals.forEach((type, total) {
      typeAccuracy[type] = (((typeCorrect[type] ?? 0) / total) * 100).round();
    });

    final weakTypes = typeAccuracy.entries
        .where((entry) => entry.value < 70)
        .map((entry) => entry.key)
        .toList();

    final total = test.questions.length;
    final accuracy = total == 0 ? 0 : ((score / total) * 100).round();

    final minutes = math.max(1 / 60, durationUsedSeconds / 60);
    final readingSpeed = (test.totalWords / minutes).round();

    final timeSpent = <String, int>{};
    timeByPassage.forEach((passage, seconds) {
      timeSpent['Passage $passage'] = seconds;
    });

    return ReadingTestResult(
      rawScore: score,
      totalQuestions: total,
      estimatedBand: _scoreToBand(score, total, test.ieltsType),
      accuracyPercent: accuracy,
      passageScores: passageScores,
      questionTypeAccuracy: typeAccuracy,
      readingSpeedWpm: readingSpeed,
      unansweredQuestions: unanswered,
      timeSpentPerPassage: timeSpent,
      weakQuestionTypes: weakTypes,
      durationUsedSeconds: durationUsedSeconds,
    );
  }

  static String _normalize(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static double _scoreToBand(int score, int total, String ieltsType) {
    if (total == 0) return 0;

    final scaled = (score / total) * 40;

    if (ieltsType == 'General Training') {
      if (scaled >= 40) return 9;
      if (scaled >= 39) return 8.5;
      if (scaled >= 37) return 8;
      if (scaled >= 36) return 7.5;
      if (scaled >= 34) return 7;
      if (scaled >= 32) return 6.5;
      if (scaled >= 30) return 6;
      if (scaled >= 27) return 5.5;
      if (scaled >= 23) return 5;
      if (scaled >= 19) return 4.5;
      return 4;
    }

    if (scaled >= 39) return 9;
    if (scaled >= 37) return 8.5;
    if (scaled >= 35) return 8;
    if (scaled >= 33) return 7.5;
    if (scaled >= 30) return 7;
    if (scaled >= 27) return 6.5;
    if (scaled >= 23) return 6;
    if (scaled >= 19) return 5.5;
    if (scaled >= 15) return 5;
    if (scaled >= 13) return 4.5;
    return 4;
  }
}

class ReadingRecentResult {
  final String title;
  final int rawScore;
  final int totalQuestions;
  final double estimatedBand;
  final int readingSpeedWpm;

  const ReadingRecentResult({
    required this.title,
    required this.rawScore,
    required this.totalQuestions,
    required this.estimatedBand,
    required this.readingSpeedWpm,
  });

  factory ReadingRecentResult.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return ReadingRecentResult(
      title: (data['title'] ?? 'Reading Test').toString(),
      rawScore: _asInt(data['rawScore']),
      totalQuestions: _asInt(data['totalQuestions'], fallback: 40),
      estimatedBand: _asDouble(data['estimatedBand']),
      readingSpeedWpm: _asInt(data['readingSpeedWpm']),
    );
  }
}

enum ReadingMode {
  academic(
    'Academic Reading',
    'academic',
    Icons.school_outlined,
    '3 passages • 40 questions',
  ),
  generalTraining(
    'General Training',
    'general',
    Icons.work_outline_rounded,
    'Notices, workplace and general texts',
  ),
  passage(
    'Passage Practice',
    'passage',
    Icons.article_outlined,
    'Focus on one passage',
  ),
  questionType(
    'Question Type Practice',
    'question_type',
    Icons.checklist_rounded,
    'Master a specific format',
  ),
  timed(
    'Timed Reading',
    'timed',
    Icons.timer_outlined,
    'Practice under time pressure',
  ),
  full(
    'Full Reading Test',
    'full',
    Icons.fact_check_outlined,
    '60 minutes • 40 questions',
  ),
  speed(
    'Speed Reading Exercise',
    'speed',
    Icons.speed_rounded,
    'Improve words per minute',
  );

  final String label;
  final String firestoreValue;
  final IconData icon;
  final String subtitle;

  const ReadingMode(this.label, this.firestoreValue, this.icon, this.subtitle);
}

enum ReadingQuestionType {
  multipleChoice('Multiple choice', Icons.checklist_rtl_rounded),
  trueFalseNotGiven('True / False / Not Given', Icons.rule_rounded),
  yesNoNotGiven('Yes / No / Not Given', Icons.balance_rounded),
  matchingHeadings('Matching headings', Icons.view_headline_rounded),
  matchingInformation('Matching information', Icons.compare_arrows_rounded),
  matchingFeatures('Matching features', Icons.merge_type_rounded),
  sentenceEndings('Sentence endings', Icons.short_text_rounded),
  summaryCompletion('Summary completion', Icons.summarize_outlined),
  sentenceCompletion('Sentence completion', Icons.subject_rounded),
  noteCompletion('Note completion', Icons.note_alt_outlined),
  tableCompletion('Table completion', Icons.table_chart_outlined),
  flowchartCompletion('Flowchart completion', Icons.account_tree_outlined),
  diagramLabels('Diagram labels', Icons.schema_outlined),
  shortAnswers('Short answers', Icons.question_answer_outlined);

  final String label;
  final IconData icon;

  const ReadingQuestionType(this.label, this.icon);
}

class _PassageView extends StatelessWidget {
  final ReadingPassage passage;
  final Set<String> highlightedParagraphs;
  final Map<int, String> notes;
  final bool toolsEnabled;
  final ValueChanged<int> onHighlight;
  final ValueChanged<int> onNote;

  const _PassageView({
    super.key,
    required this.passage,
    required this.highlightedParagraphs,
    required this.notes,
    required this.toolsEnabled,
    required this.onHighlight,
    required this.onNote,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          Text(
            passage.title,
            style: const TextStyle(
              color: RColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(text: 'Passage ${passage.passageNumber}'),
              _Badge(text: '${passage.wordCount} words'),
              _Badge(text: passage.topic),
            ],
          ),
          const SizedBox(height: 18),
          ...passage.paragraphs.asMap().entries.map((entry) {
            final key = _paragraphKey(passage.passageNumber, entry.key);
            final highlighted = highlightedParagraphs.contains(key);
            final note = notes[key.hashCode];

            return Container(
              margin: const EdgeInsets.only(bottom: 13),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: highlighted
                    ? const Color(0xFFFACC15).withOpacity(.12)
                    : RColors.surface.withOpacity(.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: highlighted
                      ? const Color(0xFFFACC15).withOpacity(.45)
                      : RColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.value,
                    style: const TextStyle(
                      color: RColors.secondary,
                      fontSize: 14,
                      height: 1.75,
                    ),
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Note: $note',
                      style: const TextStyle(
                        color: RColors.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (toolsEnabled) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => onHighlight(entry.key),
                          icon: Icon(
                            highlighted
                                ? Icons.highlight_off_rounded
                                : Icons.highlight_rounded,
                            size: 17,
                          ),
                          label: Text(
                            highlighted ? 'Remove highlight' : 'Highlight',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => onNote(entry.key),
                          icon: const Icon(Icons.note_add_outlined, size: 17),
                          label: const Text('Add note'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _QuestionPane extends StatelessWidget {
  final ReadingQuestion question;
  final String? selected;
  final TextEditingController? controller;
  final Set<String> eliminated;
  final bool eliminateMode;
  final ValueChanged<String> onOption;
  final ValueChanged<String> onTextChanged;

  const _QuestionPane({
    super.key,
    required this.question,
    required this.selected,
    required this.controller,
    required this.eliminated,
    required this.eliminateMode,
    required this.onOption,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Row(
          children: [
            _Badge(text: 'Question ${question.number}'),
            const SizedBox(width: 8),
            Expanded(child: _Badge(text: question.type)),
          ],
        ),
        const SizedBox(height: 16),
        _QuestionPromptCard(question: question),
        if (question.wordLimit.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(
            question.wordLimit,
            style: const TextStyle(
              color: RColors.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (question.options.isNotEmpty)
          ...question.options.map((option) {
            final chosen = selected == option;
            final isEliminated = eliminated.contains(option);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onOption(option),
                borderRadius: BorderRadius.circular(15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: chosen
                        ? RColors.cyan.withOpacity(.13)
                        : RColors.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: chosen ? RColors.cyan : RColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        eliminateMode
                            ? Icons.remove_circle_outline
                            : chosen
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isEliminated
                            ? RColors.muted
                            : chosen
                            ? RColors.cyan
                            : RColors.secondary,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            color: isEliminated ? RColors.muted : RColors.text,
                            fontWeight: FontWeight.w700,
                            decoration: isEliminated
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })
        else
          TextField(
            controller: controller,
            onChanged: onTextChanged,
            maxLines: 2,

            style: const TextStyle(
              color: RColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),

            cursorColor: RColors.cyan,

            decoration: const InputDecoration(
              labelText: 'Your answer',
              hintText: 'Type your answer here',

              labelStyle: TextStyle(
                color: RColors.violet,
                fontWeight: FontWeight.w700,
              ),

              hintStyle: TextStyle(color: RColors.muted),

              prefixIcon: Icon(Icons.edit_rounded, color: RColors.violet),

              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: RColors.violet, width: 2),
              ),

              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: RColors.cyan, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuestionPromptCard extends StatelessWidget {
  final ReadingQuestion question;

  const _QuestionPromptCard({required this.question});

  bool get _isCompletionType {
    final type = question.type.toLowerCase();
    return type.contains('sentence completion') ||
        type.contains('summary completion') ||
        type.contains('note completion') ||
        type.contains('table completion') ||
        type.contains('flowchart completion');
  }

  @override
  Widget build(BuildContext context) {
    final prompt = question.prompt.trim();
    final hasVisiblePrompt = prompt.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCompletionType
              ? RColors.cyan.withOpacity(.35)
              : RColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isCompletionType) ...[
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: RColors.cyan, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Complete the sentence using information from the passage.',
                    style: TextStyle(
                      color: RColors.cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SelectableText(
            hasVisiblePrompt
                ? prompt
                : 'Question text is unavailable. Please report this generated test to the administrator.',
            style: TextStyle(
              color: hasVisiblePrompt ? RColors.text : const Color(0xFFF97316),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingToolbar extends StatelessWidget {
  final bool eliminateMode;
  final VoidCallback onDictionary;
  final VoidCallback onExplain;
  final VoidCallback onSynonyms;
  final VoidCallback onEliminate;

  const _ReadingToolbar({
    required this.eliminateMode,
    required this.onDictionary,
    required this.onExplain,
    required this.onSynonyms,
    required this.onEliminate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        children: [
          _ToolButton(
            icon: Icons.menu_book_outlined,
            label: 'Dictionary',
            onTap: onDictionary,
          ),
          _ToolButton(
            icon: Icons.psychology_alt_outlined,
            label: 'Explain',
            onTap: onExplain,
          ),
          _ToolButton(
            icon: Icons.swap_horiz_rounded,
            label: 'Synonyms',
            onTap: onSynonyms,
          ),
          _ToolButton(
            icon: Icons.remove_circle_outline,
            label: eliminateMode ? 'Eliminating' : 'Eliminate',
            selected: eliminateMode,
            onTap: onEliminate,
          ),
        ],
      ),
    );
  }
}

class _ExamModeNotice extends StatelessWidget {
  const _ExamModeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withOpacity(.09),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(.22)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFFF97316), size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Exam mode: dictionary, explanations, synonyms and option elimination are disabled.',
              style: TextStyle(color: RColors.secondary, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassageTabs extends StatelessWidget {
  final List<ReadingPassage> passages;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PassageTabs({
    required this.passages,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 47,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: passages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;

          return ChoiceChip(
            selected: selected,
            label: Text('Passage ${index + 1}'),
            onSelected: (_) => onSelected(index),
            selectedColor: RColors.cyan.withOpacity(.16),
            backgroundColor: RColors.surface,
            side: BorderSide(color: selected ? RColors.cyan : RColors.border),
            labelStyle: TextStyle(
              color: selected ? RColors.cyan : RColors.secondary,
              fontWeight: FontWeight.w800,
            ),
          );
        },
      ),
    );
  }
}

class _ReadingProgressSummary extends StatelessWidget {
  final int answered;
  final int total;
  final int markedForReview;

  const _ReadingProgressSummary({
    required this.answered,
    required this.total,
    required this.markedForReview,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : answered / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Answered $answered/$total',
                  style: const TextStyle(
                    color: RColors.secondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.bookmark_rounded,
                color: Color(0xFFF59E0B),
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                '$markedForReview for review',
                style: const TextStyle(
                  color: RColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: RColors.green,
            backgroundColor: RColors.border,
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
    );
  }
}

class _MobileReadingViewSwitcher extends StatelessWidget {
  final bool showQuestions;
  final VoidCallback onPassage;
  final VoidCallback onQuestions;

  const _MobileReadingViewSwitcher({
    required this.showQuestions,
    required this.onPassage,
    required this.onQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: RColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MobileViewButton(
              selected: !showQuestions,
              icon: Icons.article_outlined,
              label: 'Read Passage',
              onTap: onPassage,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _MobileViewButton(
              selected: showQuestions,
              icon: Icons.quiz_outlined,
              label: 'Answer Question',
              onTap: onQuestions,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileViewButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MobileViewButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? RColors.cyan : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : RColors.secondary,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : RColors.secondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
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

class _QuestionNavigator extends StatelessWidget {
  final List<ReadingQuestion> questions;
  final int currentGlobalIndex;
  final Set<int> answeredGlobalIndices;
  final Set<int> markedForReviewGlobalIndices;
  final ValueChanged<int> onTap;

  const _QuestionNavigator({
    required this.questions,
    required this.currentGlobalIndex,
    required this.answeredGlobalIndices,
    required this.markedForReviewGlobalIndices,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: RColors.bg,
        border: Border(top: BorderSide(color: RColors.border)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: questions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final question = questions[index];
          final selected = index == currentGlobalIndex;
          final answered = answeredGlobalIndices.contains(index);
          final review = markedForReviewGlobalIndices.contains(index);

          Color background;
          Color border;
          Color foreground;

          if (selected) {
            background = RColors.cyan;
            border = RColors.cyan;
            foreground = Colors.white;
          } else if (review) {
            background = const Color(0xFFF59E0B).withOpacity(.15);
            border = const Color(0xFFF59E0B);
            foreground = const Color(0xFFFBBF24);
          } else if (answered) {
            background = RColors.green.withOpacity(.14);
            border = RColors.green;
            foreground = RColors.green;
          } else {
            background = RColors.surface;
            border = RColors.border;
            foreground = RColors.secondary;
          }

          return InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: border),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Text(
                      '${question.number}',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (review)
                    const Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(
                        Icons.bookmark_rounded,
                        size: 10,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PracticeHeader extends StatelessWidget {
  final String title;
  final int passage;
  final int passageTotal;
  final int question;
  final int questionTotal;
  final int seconds;

  const _PracticeHeader({
    required this.title,
    required this.passage,
    required this.passageTotal,
    required this.question,
    required this.questionTotal,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Passage $passage/$passageTotal • Question $question/$questionTotal',
                  style: const TextStyle(
                    color: RColors.secondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: RColors.cyan.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RColors.cyan.withOpacity(.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: RColors.cyan, size: 16),
                const SizedBox(width: 5),
                Text(
                  _formatClock(seconds),
                  style: const TextStyle(
                    color: RColors.cyan,
                    fontSize: 11,
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
}

class _BottomBar extends StatelessWidget {
  final bool loading;
  final bool backEnabled;
  final bool finalQuestion;
  final bool markedForReview;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onToggleReview;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.loading,
    required this.backEnabled,
    required this.finalQuestion,
    required this.markedForReview,
    required this.onBack,
    required this.onSkip,
    required this.onToggleReview,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: RColors.bg.withOpacity(.98),
        border: const Border(top: BorderSide(color: RColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: loading ? null : onToggleReview,
                  icon: Icon(
                    markedForReview
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: markedForReview
                        ? const Color(0xFFF59E0B)
                        : RColors.secondary,
                    size: 18,
                  ),
                  label: Text(
                    markedForReview ? 'Review marked' : 'Mark for review',
                    style: TextStyle(
                      color: markedForReview
                          ? const Color(0xFFF59E0B)
                          : RColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: loading || finalQuestion ? null : onSkip,
                icon: const Icon(Icons.skip_next_rounded, size: 18),
                label: const Text('Skip'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: backEnabled && !loading ? onBack : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading
                      ? null
                      : finalQuestion
                      ? onSubmit
                      : onNext,
                  icon: loading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          finalQuestion
                              ? Icons.done_all_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                  label: Text(finalQuestion ? 'Submit Test' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _GradientIcon(icon: Icons.menu_book_rounded),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reading',
                style: TextStyle(
                  color: RColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'IELTS passages, smart tools and detailed analytics',
                style: TextStyle(color: RColors.muted, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BandHero extends StatelessWidget {
  final double band;

  const _BandHero({required this.band});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: _heroDecoration(),
      child: Row(
        children: [
          Container(
            width: 90,
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: RColors.cyan, width: 8),
              boxShadow: [
                BoxShadow(color: RColors.cyan.withOpacity(.2), blurRadius: 20),
              ],
            ),
            child: Text(
              band > 0 ? band.toStringAsFixed(1) : '—',
              style: const TextStyle(
                color: RColors.text,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Estimated Reading Band',
                  style: TextStyle(
                    color: RColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Updated automatically from your latest reading result.',
                  style: TextStyle(
                    color: RColors.secondary,
                    fontSize: 10.7,
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

class _WeaknessCard extends StatelessWidget {
  final List<String> types;

  const _WeaknessCard({required this.types});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weak Reading Question Types',
            style: TextStyle(
              color: RColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types
                .map(
                  (type) => Chip(
                    label: Text(type),
                    backgroundColor: const Color(0xFFF97316).withOpacity(.12),
                    side: BorderSide(
                      color: const Color(0xFFF97316).withOpacity(.25),
                    ),
                    labelStyle: const TextStyle(
                      color: Color(0xFFFDBA74),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final ReadingMode mode;
  final VoidCallback onTap;

  const _ModeCard({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(mode.icon, color: RColors.cyan, size: 25),
          const Spacer(),
          Text(
            mode.label,
            style: const TextStyle(
              color: RColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            mode.subtitle,
            maxLines: 2,
            style: const TextStyle(color: RColors.muted, fontSize: 9.3),
          ),
        ],
      ),
    );
  }
}

class _QuestionTypeCard extends StatelessWidget {
  final ReadingQuestionType type;
  final bool weak;
  final VoidCallback onTap;

  const _QuestionTypeCard({
    required this.type,
    required this.weak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = weak ? const Color(0xFFF97316) : RColors.cyan;

    return _TapCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(type.icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              type.label,
              style: const TextStyle(
                color: RColors.text,
                fontSize: 10.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (weak)
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF97316),
              size: 16,
            ),
        ],
      ),
    );
  }
}

class _RecentResultCard extends StatelessWidget {
  final ReadingRecentResult result;

  const _RecentResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: RColors.cyan.withOpacity(.13),
            child: Text(
              result.estimatedBand.toStringAsFixed(1),
              style: const TextStyle(
                color: RColors.cyan,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${result.rawScore}/${result.totalQuestions} • ${result.readingSpeedWpm} WPM',
                  style: const TextStyle(color: RColors.muted, fontSize: 9.8),
                ),
              ],
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
    return const Row(
      children: [
        _GradientIcon(icon: Icons.analytics_outlined),
        SizedBox(width: 12),
        Text(
          'Reading Result',
          style: TextStyle(
            color: RColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ResultHero extends StatelessWidget {
  final ReadingTestResult result;

  const _ResultHero({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _heroDecoration(),
      child: Column(
        children: [
          const Text(
            'Estimated Band',
            style: TextStyle(color: RColors.secondary),
          ),
          const SizedBox(height: 8),
          Text(
            result.estimatedBand.toStringAsFixed(1),
            style: const TextStyle(
              color: RColors.cyan,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.rawScore}/${result.totalQuestions} correct • ${result.accuracyPercent}% accuracy',
            style: const TextStyle(
              color: RColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final ReadingTestResult result;

  const _MetricGrid({required this.result});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.speed_rounded,
            value: '${result.readingSpeedWpm}',
            label: 'Words/min',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.help_outline_rounded,
            value: '${result.unansweredQuestions}',
            label: 'Unanswered',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.timer_outlined,
            value: _formatClock(result.durationUsedSeconds),
            label: 'Time used',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: RColors.cyan, size: 20),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: RColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RColors.muted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final String title;
  final int value;
  final String? subtitle;
  final Color color;

  const _PerformanceCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.color = RColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: RColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$value%',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: RColors.muted, fontSize: 9.5),
            ),
          ],
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: value / 100,
            color: color,
            backgroundColor: RColors.border,
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final ReadingTestResult result;

  const _RecommendationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final recommendation = result.weakQuestionTypes.isEmpty
        ? 'Strong performance. Continue with timed full tests to maintain speed and accuracy.'
        : 'Focus next on ${result.weakQuestionTypes.take(3).join(', ')}. Review evidence-location and paraphrasing strategies.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RColors.green.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RColors.green.withOpacity(.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: RColors.green),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              recommendation,
              style: const TextStyle(color: RColors.secondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(
          icon,
          size: 17,
          color: selected ? Colors.white : RColors.cyan,
        ),
        label: Text(label),
        backgroundColor: selected ? RColors.cyan : RColors.surface,
        side: BorderSide(color: selected ? RColors.cyan : RColors.border),
        labelStyle: TextStyle(
          color: selected ? Colors.white : RColors.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreparationRow extends StatelessWidget {
  final IconData icon;
  final String title;

  const _PreparationRow({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: RColors.cyan.withOpacity(.12),
            border: Border.all(color: RColors.cyan.withOpacity(.3)),
          ),
          child: Icon(icon, size: 17, color: RColors.cyan),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: RColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(Icons.check_circle_rounded, color: RColors.green, size: 18),
      ],
    );
  }
}

class _InnerHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _InnerHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: RColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: RColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: RColors.muted, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            color: RColors.cyan,
            size: 35,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: RColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _TapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: _cardDecoration(),
          child: child,
        ),
      ),
    );
  }
}

class _GradientIcon extends StatelessWidget {
  final IconData icon;

  const _GradientIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [RColors.cyan, RColors.violet]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: RColors.cyan.withOpacity(.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RColors.cyan.withOpacity(.22)),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: RColors.cyan,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(title),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }
}

class _ReadingBackground extends StatelessWidget {
  const _ReadingBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [RColors.bg, Color(0xFF0D172B), RColors.bg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: _Glow(size: 260, color: RColors.cyan),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _Glow(size: 300, color: RColors.violet),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(.07),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.08),
            blurRadius: 90,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }
}

abstract final class RColors {
  static const bg = Color(0xFF08111F);
  static const surface = Color(0xFF111C2E);
  static const border = Color(0xFF22324A);
  static const cyan = Color(0xFF06B6D4);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: RColors.surface.withOpacity(.92),
  borderRadius: BorderRadius.circular(19),
  border: Border.all(color: RColors.border),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(.12),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ],
);

BoxDecoration _heroDecoration() => BoxDecoration(
  gradient: LinearGradient(
    colors: [
      RColors.surface,
      RColors.cyan.withOpacity(.09),
      RColors.violet.withOpacity(.07),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: RColors.cyan.withOpacity(.2)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(.16),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ],
);

String _paragraphKey(int passage, int paragraph) => '$passage-$paragraph';

String _formatClock(int seconds) {
  final safe = math.max(0, seconds);
  final minutes = safe ~/ 60;
  final remaining = safe % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _firstNonEmptyString(List<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }
  return fallback;
}

String _normalizeReadingQuestionPrompt({
  required String type,
  required String prompt,
  required String correctAnswer,
  required int number,
}) {
  var value = prompt.trim();
  final normalizedType = type.toLowerCase();

  if (value.isEmpty) {
    return '';
  }

  final isCompletion =
      normalizedType.contains('completion') ||
      normalizedType.contains('short answer');

  if (!isCompletion) {
    return value;
  }

  // Gemini may return the completed sentence with the answer already inserted.
  // Replace the first exact answer occurrence with a visible blank.
  if (correctAnswer.trim().isNotEmpty &&
      !value.contains('_____') &&
      !value.contains('______') &&
      !value.contains('...')) {
    final answerPattern = RegExp(
      RegExp.escape(correctAnswer.trim()),
      caseSensitive: false,
    );

    if (answerPattern.hasMatch(value)) {
      value = value.replaceFirst(answerPattern, '__________');
    }
  }

  // Ensure generated placeholders are visually clear.
  value = value
      .replaceAll(
        RegExp(r'\[\s*blank\s*\]', caseSensitive: false),
        '__________',
      )
      .replaceAll(RegExp(r'<\s*blank\s*>', caseSensitive: false), '__________')
      .replaceAll(
        RegExp(r'\{\s*blank\s*\}', caseSensitive: false),
        '__________',
      );

  // When Gemini returns only an instruction, make the question number visible.
  if (!value.contains('_____') &&
      normalizedType.contains('sentence completion')) {
    value = '$value\n\nAnswer $number: __________';
  }

  return value;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<dynamic> _asList(dynamic value) =>
    value is List ? List<dynamic>.from(value) : <dynamic>[];

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<String> _asStringList(dynamic value) {
  if (value is! List) return <String>[];
  return value
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList();
}
