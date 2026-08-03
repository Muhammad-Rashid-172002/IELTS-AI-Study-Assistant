import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class ListeningScreen extends StatelessWidget {
  const ListeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _MessageScreen(
        icon: Icons.login_rounded,
        title: 'Sign in required',
        message: 'Please sign in to open your listening dashboard.',
      );
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    return Scaffold(
      backgroundColor: LColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            bottom: false,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: userRef.snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: LColors.cyan),
                  );
                }

                final userData = userSnapshot.data!.data() ?? {};

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: userRef
                      .collection('listening_results')
                      .orderBy('completedAt', descending: true)
                      .limit(5)
                      .snapshots(),
                  builder: (context, resultSnapshot) {
                    final results =
                        resultSnapshot.data?.docs
                            .map(ListeningRecentResult.fromDocument)
                            .toList() ??
                        [];

                    return _ListeningHome(
                      currentBand: _asDouble(
                        userData['listeningBand'] ??
                            (results.isNotEmpty
                                ? results.first.estimatedBand
                                : 0),
                      ),
                      weakTypes: _asStringList(userData['weakQuestionTypes']),
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

class _ListeningHome extends StatelessWidget {
  final double currentBand;
  final List<String> weakTypes;
  final List<ListeningRecentResult> recentResults;

  const _ListeningHome({
    required this.currentBand,
    required this.weakTypes,
    required this.recentResults,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWeakTypes = weakTypes.isEmpty
        ? const ['Matching', 'Map labelling', 'Multiple choice']
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
            child: _BandCard(band: currentBand),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: _WeakTypesCard(types: effectiveWeakTypes),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: _RecommendedLessonCard(),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 18, 12),
            child: _SectionTitle(
              title: 'Practice Modes',
              subtitle: 'Choose a section or complete test mode',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final mode = ListeningMode.values[index];
              return _ModeCard(
                mode: mode,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ListeningTestBrowserScreen(mode: mode),
                  ),
                ),
              );
            }, childCount: ListeningMode.values.length),
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
            padding: EdgeInsets.fromLTRB(18, 22, 18, 12),
            child: _SectionTitle(
              title: 'Question Type Practice',
              subtitle: 'Practice a specific IELTS listening question type',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final type = ListeningQuestionType.values[index];
              final weak = effectiveWeakTypes
                  .map((e) => e.toLowerCase())
                  .contains(type.label.toLowerCase());

              return _QuestionTypeCard(
                type: type,
                weak: weak,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ListeningTestBrowserScreen(questionType: type.label),
                  ),
                ),
              );
            }, childCount: ListeningQuestionType.values.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.65,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 18, 12),
            child: _SectionTitle(
              title: 'Recent Tests',
              subtitle: 'Latest scores and estimated bands',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
          sliver: recentResults.isEmpty
              ? const SliverToBoxAdapter(
                  child: _EmptyCard(
                    title: 'No recent listening tests',
                    subtitle:
                        'Complete your first listening activity to see results here.',
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

class ListeningTestBrowserScreen extends StatefulWidget {
  final ListeningMode? mode;
  final String? questionType;

  const ListeningTestBrowserScreen({super.key, this.mode, this.questionType});

  @override
  State<ListeningTestBrowserScreen> createState() =>
      _ListeningTestBrowserScreenState();
}

class _ListeningTestBrowserScreenState extends State<ListeningTestBrowserScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _pulseAnimation;

  String? _error;
  bool _loading = true;
  int _availableCount = 0;

  String get _title =>
      widget.questionType ?? widget.mode?.label ?? 'Listening Practice';

  String get _subtitle {
    if (widget.questionType != null) {
      return 'Preparing a ${widget.questionType} activity';
    }

    if (widget.mode?.section != null) {
      return 'Preparing IELTS Listening Section ${widget.mode!.section}';
    }

    return 'Finding the best published listening test for you';
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: .92, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadAndOpenTest();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAndOpenTest() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _availableCount = 0;
    });

    final minimumLoading = Future<void>.delayed(
      const Duration(milliseconds: 1100),
    );

    try {
      final tests = await _fetchMatchingTests();
      await minimumLoading;

      if (!mounted) return;

      if (tests.isEmpty) {
        setState(() {
          _loading = false;
          _error =
              'No published audio-ready test is available for this selection.';
        });
        return;
      }

      _availableCount = tests.length;

      if (widget.mode == ListeningMode.full) {
        final fullMockTests = await _selectFullMockTests(tests);

        if (!mounted) return;

        if (fullMockTests.length != 4) {
          setState(() {
            _loading = false;
            _error =
                'Full Listening Test requires one published, audio-ready exam test for each Section 1–4.';
          });
          return;
        }

        await Navigator.pushReplacement(
          context,
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 450),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (_, animation, __) => FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: FullListeningPracticeScreen(tests: fullMockTests),
            ),
          ),
        );
        return;
      }

      final selectedTest = await _selectBestTest(tests);

      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: ListeningPracticeScreen(test: selectedTest),
          ),
        ),
      );
    } on FirebaseException catch (error) {
      await minimumLoading;

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.code == 'permission-denied'
            ? 'You do not have permission to load listening tests.'
            : 'Listening tests could not be loaded. Please try again.';
      });
    } catch (_) {
      await minimumLoading;

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Something went wrong while preparing your test.';
      });
    }
  }

  Future<List<ListeningTest>> _fetchMatchingTests() async {
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('listening_tests')
          .where('status', isEqualTo: 'published')
          .where('audioStatus', isEqualTo: 'ready');

      if (widget.questionType != null) {
        query = query.where('questionType', isEqualTo: widget.questionType);
      } else if (widget.mode?.section != null) {
        query = query.where('section', isEqualTo: widget.mode!.section);
      } else if (widget.mode != null) {
        query = query.where(
          'mode',
          isEqualTo: widget.mode == ListeningMode.full
              ? 'exam'
              : widget.mode!.firestoreValue,
        );
      }

      final snapshot = await query
          .limit(widget.mode == ListeningMode.full ? 120 : 40)
          .get();

      return snapshot.docs
          .map(ListeningTest.fromDocument)
          .where(_isUsableTest)
          .toList();
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') rethrow;

      // Safe fallback while a composite Firestore index is being created.
      final snapshot = await FirebaseFirestore.instance
          .collection('listening_tests')
          .where('status', isEqualTo: 'published')
          .limit(200)
          .get();

      return snapshot.docs
          .where((doc) => _matchesSelection(doc.data()))
          .map(ListeningTest.fromDocument)
          .where(_isUsableTest)
          .toList();
    }
  }

  bool _matchesSelection(Map<String, dynamic> data) {
    if ((data['audioStatus'] ?? '').toString().toLowerCase() != 'ready') {
      return false;
    }

    if (widget.questionType != null) {
      return (data['questionType'] ?? '').toString() == widget.questionType;
    }

    if (widget.mode?.section != null) {
      return _asInt(data['section']) == widget.mode!.section;
    }

    if (widget.mode != null) {
      final expectedMode = widget.mode == ListeningMode.full
          ? 'exam'
          : widget.mode!.firestoreValue;
      return (data['mode'] ?? '').toString() == expectedMode;
    }

    return true;
  }

  bool _isUsableTest(ListeningTest test) {
    final hasAudio =
        (test.audioUrl?.trim().isNotEmpty ?? false) ||
        (test.audioStoragePath?.trim().isNotEmpty ?? false);

    return hasAudio &&
        test.questions.isNotEmpty &&
        test.transcript.trim().isNotEmpty;
  }

  Future<ListeningTest> _selectBestTest(List<ListeningTest> tests) async {
    if (tests.length == 1) return tests.first;

    final user = FirebaseAuth.instance.currentUser;
    final attemptedIds = <String>{};

    if (user != null) {
      try {
        final recentResults = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('listening_results')
            .orderBy('completedAt', descending: true)
            .limit(20)
            .get();

        for (final doc in recentResults.docs) {
          final testId = (doc.data()['testId'] ?? '').toString();
          if (testId.isNotEmpty) attemptedIds.add(testId);
        }
      } catch (_) {
        // Recent-history lookup is optional; selection still works without it.
      }
    }

    final unseenTests = tests
        .where((test) => !attemptedIds.contains(test.id))
        .toList();

    final pool = unseenTests.isNotEmpty ? unseenTests : tests;
    return pool[math.Random.secure().nextInt(pool.length)];
  }

  Future<List<ListeningTest>> _selectFullMockTests(
    List<ListeningTest> tests,
  ) async {
    final selected = <ListeningTest>[];

    for (int section = 1; section <= 4; section++) {
      final sectionTests = tests
          .where((test) => test.section == section)
          .toList();

      if (sectionTests.isEmpty) {
        return const <ListeningTest>[];
      }

      selected.add(await _selectBestTest(sectionTests));
    }

    selected.sort((a, b) => a.section.compareTo(b.section));
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            child: Column(
              children: [
                _InnerHeader(
                  title: _title,
                  subtitle: _loading
                      ? 'Personalizing your next activity'
                      : 'Listening activity unavailable',
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _loading ? _buildLoadingState() : _buildErrorState(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      key: const ValueKey('listening-loading'),
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
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [LColors.cyan, LColors.violet],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: LColors.cyan.withOpacity(.22),
                        blurRadius: 30,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.headphones_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LColors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LColors.secondary,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 25),
              const LinearProgressIndicator(
                minHeight: 5,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                color: LColors.cyan,
                backgroundColor: LColors.border,
              ),
              const SizedBox(height: 21),
              const _PreparationStep(
                icon: Icons.cloud_done_outlined,
                title: 'Loading published test',
                active: true,
              ),
              const SizedBox(height: 11),
              const _PreparationStep(
                icon: Icons.graphic_eq_rounded,
                title: 'Preparing listening audio',
                active: true,
              ),
              const SizedBox(height: 11),
              const _PreparationStep(
                icon: Icons.psychology_alt_outlined,
                title: 'Matching the best activity',
                active: true,
              ),
              const SizedBox(height: 22),
              const Text(
                'Your test will start automatically',
                style: TextStyle(
                  color: LColors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      key: const ValueKey('listening-error'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(24),
          decoration: _card(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF97316).withOpacity(.12),
                  border: Border.all(
                    color: const Color(0xFFF97316).withOpacity(.28),
                  ),
                ),
                child: const Icon(
                  Icons.headset_off_rounded,
                  color: Color(0xFFF97316),
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No matching test yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LColors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                _error ?? 'Please try another listening activity.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LColors.secondary,
                  fontSize: 11.5,
                  height: 1.55,
                ),
              ),
              if (_availableCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$_availableCount activities were checked.',
                  style: const TextStyle(color: LColors.muted, fontSize: 10),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: _GradientButton(
                  title: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: _loadAndOpenTest,
                ),
              ),
              const SizedBox(height: 9),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Choose another activity'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparationStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;

  const _PreparationStep({
    required this.icon,
    required this.title,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? LColors.cyan.withOpacity(.12) : LColors.surface,
            border: Border.all(
              color: active ? LColors.cyan.withOpacity(.3) : LColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: active ? LColors.cyan : LColors.muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: active ? LColors.text : LColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (active)
          const Icon(
            Icons.check_circle_rounded,
            color: LColors.green,
            size: 18,
          ),
      ],
    );
  }
}

class FullListeningPracticeScreen extends StatefulWidget {
  final List<ListeningTest> tests;

  const FullListeningPracticeScreen({super.key, required this.tests});

  @override
  State<FullListeningPracticeScreen> createState() =>
      _FullListeningPracticeScreenState();
}

class _FullListeningPracticeScreenState
    extends State<FullListeningPracticeScreen> {
  final AudioPlayer _player = AudioPlayer();
  final PageController _pageController = PageController();
  final Map<int, String> _answers = {};
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, int> _playCounts = {};

  Timer? _timer;
  late final List<ListeningTest> _tests;
  late final int _totalDurationSeconds;

  int _sectionIndex = 0;
  int _currentQuestion = 0;
  int _remainingSeconds = 0;
  double _volume = 1;
  bool _loadingAudio = true;
  bool _autoScroll = false;
  bool _submitting = false;
  String? _audioError;

  ListeningTest get _currentTest => _tests[_sectionIndex];

  int get _questionOffset {
    int offset = 0;
    for (int i = 0; i < _sectionIndex; i++) {
      offset += _tests[i].questions.length;
    }
    return offset;
  }

  int get _globalQuestionIndex => _questionOffset + _currentQuestion;

  int get _totalQuestions =>
      _tests.fold(0, (total, test) => total + test.questions.length);

  Set<int> get _answeredInCurrentSection {
    final answered = <int>{};
    for (int i = 0; i < _currentTest.questions.length; i++) {
      final value = _answers[_questionOffset + i]?.trim() ?? '';
      if (value.isNotEmpty) answered.add(i);
    }
    return answered;
  }

  @override
  void initState() {
    super.initState();

    _tests = [...widget.tests]..sort((a, b) => a.section.compareTo(b.section));

    _totalDurationSeconds = _tests.fold(
      0,
      (total, test) => total + test.durationSeconds,
    );
    _remainingSeconds = _totalDurationSeconds;

    int globalIndex = 0;
    for (final test in _tests) {
      for (final question in test.questions) {
        if (question.options.isEmpty) {
          _controllers[globalIndex] = TextEditingController();
        }
        globalIndex++;
      }
    }

    _loadCurrentAudio();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    _pageController.dispose();

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        _submitFullTest();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _loadCurrentAudio() async {
    if (mounted) {
      setState(() {
        _loadingAudio = true;
        _audioError = null;
      });
    }

    try {
      await _player.stop();

      String? url = _currentTest.audioUrl;

      if ((url == null || url.isEmpty) &&
          _currentTest.audioStoragePath != null) {
        url = await FirebaseStorage.instance
            .ref(_currentTest.audioStoragePath!)
            .getDownloadURL();
      }

      if (url == null || url.isEmpty) {
        throw Exception(
          'Section ${_currentTest.section} audio is unavailable.',
        );
      }

      await _player.setUrl(url);
      await _player.setVolume(_volume);
    } catch (error) {
      _audioError = error.toString();
    } finally {
      if (mounted) {
        setState(() => _loadingAudio = false);
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_loadingAudio || _audioError != null) return;

    if (_player.playing) {
      await _player.pause();
      return;
    }

    final section = _currentTest.section;
    final playCount = _playCounts[section] ?? 0;

    if (_player.processingState == ProcessingState.completed) {
      _snack('Audio replay is disabled in Full Test mode.');
      return;
    }

    if (_player.position == Duration.zero && playCount > 0) {
      _snack('Section audio can only be played once.');
      return;
    }

    if (_player.position == Duration.zero) {
      _playCounts[section] = playCount + 1;
    }

    await _player.play();

    if (mounted) setState(() {});
  }

  Future<void> _goToQuestion(int index) async {
    if (index < 0 || index >= _currentTest.questions.length) return;

    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _changeSection(int newSectionIndex) async {
    if (newSectionIndex < 0 || newSectionIndex >= _tests.length) return;

    await _player.pause();

    setState(() {
      _sectionIndex = newSectionIndex;
      _currentQuestion = 0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    await _loadCurrentAudio();
  }

  Future<void> _next() async {
    if (_currentQuestion < _currentTest.questions.length - 1) {
      await _goToQuestion(_currentQuestion + 1);
      return;
    }

    if (_sectionIndex < _tests.length - 1) {
      await _changeSection(_sectionIndex + 1);
      return;
    }

    await _submitFullTest();
  }

  Future<void> _back() async {
    if (_currentQuestion > 0) {
      await _goToQuestion(_currentQuestion - 1);
      return;
    }

    if (_sectionIndex > 0) {
      final previousSectionIndex = _sectionIndex - 1;
      await _player.pause();

      setState(() {
        _sectionIndex = previousSectionIndex;
        _currentQuestion = _tests[previousSectionIndex].questions.length - 1;
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentQuestion);
      }

      await _loadCurrentAudio();
    }
  }

  ListeningTest _buildCombinedTest() {
    final combinedQuestions = <ListeningQuestion>[];
    int number = 1;

    for (final test in _tests) {
      for (final question in test.questions) {
        combinedQuestions.add(
          ListeningQuestion(
            number: number,
            section: test.section,
            type: question.type,
            prompt: question.prompt,
            options: question.options,
            correctAnswer: question.correctAnswer,
            acceptedAnswers: question.acceptedAnswers,
            explanation: question.explanation,
            keywords: question.keywords,
          ),
        );
        number++;
      }
    }

    return ListeningTest(
      id: _tests.map((test) => test.id).join('_'),
      title: 'Full IELTS Listening Test',
      description:
          'Complete IELTS Listening mock containing Sections 1, 2, 3 and 4.',
      mode: 'full',
      section: 0,
      accent: _tests.map((test) => test.accent).toSet().join(', '),
      difficulty: _tests.first.difficulty,
      durationSeconds: _totalDurationSeconds,
      audioUrl: null,
      audioStoragePath: null,
      transcript: _tests
          .map(
            (test) =>
                'SECTION ${test.section}: ${test.title}\n\n${test.transcript}',
          )
          .join('\n\n'),
      questions: combinedQuestions,
    );
  }

  Future<void> _submitFullTest() async {
    if (_submitting) return;

    for (final entry in _controllers.entries) {
      _answers[entry.key] = entry.value.text.trim();
    }

    setState(() => _submitting = true);

    _timer?.cancel();
    await _player.pause();

    final combinedTest = _buildCombinedTest();
    final result = ListeningResultCalculator.calculate(
      test: combinedTest,
      answers: _answers,
      durationUsedSeconds: _totalDurationSeconds - _remainingSeconds,
    );

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('listening_results')
            .doc();

        await ref.set({
          'resultId': ref.id,
          'testId': combinedTest.id,
          'testIds': _tests.map((test) => test.id).toList(),
          'title': combinedTest.title,
          'mode': 'full',
          'rawScore': result.rawScore,
          'totalQuestions': result.totalQuestions,
          'estimatedBand': result.estimatedBand,
          'accuracyPercent': result.accuracyPercent,
          'sectionAccuracy': result.sectionAccuracy,
          'questionTypeAccuracy': result.questionTypeAccuracy,
          'spellingMistakes': result.spellingMistakes,
          'missedKeywords': result.missedKeywords,
          'durationUsedSeconds': result.durationUsedSeconds,
          'completedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'listeningBand': result.estimatedBand,
          'weakQuestionTypes': result.weakQuestionTypes,
          'lastListeningTestAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // Result screen still opens if result persistence temporarily fails.
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ListeningResultScreen(test: combinedTest, result: result),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final globalIndex = _globalQuestionIndex;

    return Scaffold(
      backgroundColor: LColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            child: Column(
              children: [
                _PracticeHeader(
                  title:
                      'Full Listening Test • Section ${_currentTest.section}',
                  current: globalIndex,
                  total: _totalQuestions,
                  seconds: _remainingSeconds,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: List.generate(_tests.length, (index) {
                      final selected = index == _sectionIndex;
                      final completed = index < _sectionIndex;

                      return Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(
                            right: index == _tests.length - 1 ? 0 : 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: selected || completed
                                ? LColors.cyan
                                : LColors.border,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                _AudioPlayerCard(
                  player: _player,
                  loading: _loadingAudio,
                  error: _audioError,
                  examMode: true,
                  learningMode: false,
                  volume: _volume,
                  speed: 1,
                  onPlay: _togglePlay,
                  onVolumeChanged: (value) async {
                    setState(() => _volume = value);
                    await _player.setVolume(value);
                  },
                  onSpeedChanged: (_) {},
                ),
                _QuestionNav(
                  total: _currentTest.questions.length,
                  current: _currentQuestion,
                  answered: _answeredInCurrentSection,
                  autoScroll: _autoScroll,
                  onAutoScroll: (value) => setState(() => _autoScroll = value),
                  onTap: _goToQuestion,
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentTest.questions.length,
                    onPageChanged: (index) {
                      setState(() => _currentQuestion = index);
                    },
                    itemBuilder: (_, index) {
                      final localQuestion = _currentTest.questions[index];
                      final answerIndex = _questionOffset + index;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FullSectionBanner(
                              section: _currentTest.section,
                              title: _currentTest.title,
                              questionNumber: answerIndex + 1,
                              totalQuestions: _totalQuestions,
                            ),
                            const SizedBox(height: 12),
                            _QuestionCard(
                              question: localQuestion,
                              selected: _answers[answerIndex],
                              controller: _controllers[answerIndex],
                              onSelected: (answer) {
                                setState(() {
                                  _answers[answerIndex] = answer;
                                });

                                if (_autoScroll &&
                                    index < _currentTest.questions.length - 1) {
                                  Future.delayed(
                                    const Duration(milliseconds: 220),
                                    () => _goToQuestion(index + 1),
                                  );
                                }
                              },
                              onTextChanged: (value) {
                                _answers[answerIndex] = value.trim();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _BottomBar(
                  current: globalIndex,
                  total: _totalQuestions,
                  loading: _submitting,
                  onBack: globalIndex > 0 ? () => _back() : null,
                  onNext: _next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullSectionBanner extends StatelessWidget {
  final int section;
  final String title;
  final int questionNumber;
  final int totalQuestions;

  const _FullSectionBanner({
    required this.section,
    required this.title,
    required this.questionNumber,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: LColors.cyan.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LColors.cyan.withOpacity(.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: LColors.cyan.withOpacity(.15),
            child: Text(
              '$section',
              style: const TextStyle(
                color: LColors.cyan,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Section $section',
                  style: const TextStyle(
                    color: LColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: LColors.muted, fontSize: 9.5),
                ),
              ],
            ),
          ),
          Text(
            '$questionNumber/$totalQuestions',
            style: const TextStyle(
              color: LColors.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class ListeningPracticeScreen extends StatefulWidget {
  final ListeningTest test;

  const ListeningPracticeScreen({super.key, required this.test});

  @override
  State<ListeningPracticeScreen> createState() =>
      _ListeningPracticeScreenState();
}

class _ListeningPracticeScreenState extends State<ListeningPracticeScreen> {
  final AudioPlayer _player = AudioPlayer();
  final PageController _pageController = PageController();
  final Map<int, String> _answers = {};
  final Map<int, TextEditingController> _controllers = {};

  Timer? _timer;
  int _current = 0;
  int _remainingSeconds = 0;
  int _playCount = 0;
  double _volume = 1;
  double _speed = 1;
  bool _loadingAudio = true;
  bool _autoScroll = true;
  bool _submitting = false;
  String? _audioError;

  bool get _examMode =>
      widget.test.mode == 'exam' || widget.test.mode == 'full';

  bool get _learningMode => widget.test.mode == 'learning';

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.test.durationSeconds;

    for (int i = 0; i < widget.test.questions.length; i++) {
      if (widget.test.questions[i].options.isEmpty) {
        _controllers[i] = TextEditingController();
      }
    }

    _loadAudio();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAudio() async {
    try {
      String? url = widget.test.audioUrl;

      if ((url == null || url.isEmpty) &&
          widget.test.audioStoragePath != null) {
        url = await FirebaseStorage.instance
            .ref(widget.test.audioStoragePath!)
            .getDownloadURL();
      }

      if (url == null || url.isEmpty) {
        throw Exception('Audio URL or Storage path is missing.');
      }

      await _player.setUrl(url);
      await _player.setVolume(_volume);
    } catch (e) {
      _audioError = e.toString();
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        _submit();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _togglePlay() async {
    if (_loadingAudio || _audioError != null) return;

    if (_player.playing) {
      await _player.pause();
      return;
    }

    if (_player.processingState == ProcessingState.completed) {
      if (_examMode) {
        _snack('Replay is disabled in exam mode.');
        return;
      }
      await _player.seek(Duration.zero);
    }

    if (_player.position == Duration.zero) {
      if (_examMode && _playCount > 0) {
        _snack('Audio can only be played once in exam mode.');
        return;
      }
      _playCount++;
    }

    await _player.play();
    if (mounted) setState(() {});
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= widget.test.questions.length) return;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;

    for (final entry in _controllers.entries) {
      _answers[entry.key] = entry.value.text.trim();
    }

    setState(() => _submitting = true);
    _timer?.cancel();
    await _player.pause();

    final result = ListeningResultCalculator.calculate(
      test: widget.test,
      answers: _answers,
      durationUsedSeconds: widget.test.durationSeconds - _remainingSeconds,
    );

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('listening_results')
            .doc();

        await ref.set({
          'resultId': ref.id,
          'testId': widget.test.id,
          'title': widget.test.title,
          'rawScore': result.rawScore,
          'totalQuestions': result.totalQuestions,
          'estimatedBand': result.estimatedBand,
          'accuracyPercent': result.accuracyPercent,
          'sectionAccuracy': result.sectionAccuracy,
          'questionTypeAccuracy': result.questionTypeAccuracy,
          'spellingMistakes': result.spellingMistakes,
          'missedKeywords': result.missedKeywords,
          'durationUsedSeconds': result.durationUsedSeconds,
          'completedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'listeningBand': result.estimatedBand,
          'weakQuestionTypes': result.weakQuestionTypes,
          'lastListeningTestAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ListeningResultScreen(test: widget.test, result: result),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            child: Column(
              children: [
                _PracticeHeader(
                  title: widget.test.title,
                  current: _current,
                  total: widget.test.questions.length,
                  seconds: _remainingSeconds,
                ),
                _AudioPlayerCard(
                  player: _player,
                  loading: _loadingAudio,
                  error: _audioError,
                  examMode: _examMode,
                  learningMode: _learningMode,
                  volume: _volume,
                  speed: _speed,
                  onPlay: _togglePlay,
                  onVolumeChanged: (value) async {
                    setState(() => _volume = value);
                    await _player.setVolume(value);
                  },
                  onSpeedChanged: (value) async {
                    if (!_learningMode) return;
                    setState(() => _speed = value);
                    await _player.setSpeed(value);
                  },
                ),
                _QuestionNav(
                  total: widget.test.questions.length,
                  current: _current,
                  answered: _answers.keys.toSet(),
                  autoScroll: _autoScroll,
                  onAutoScroll: (value) => setState(() => _autoScroll = value),
                  onTap: _goTo,
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.test.questions.length,
                    onPageChanged: (index) => setState(() => _current = index),
                    itemBuilder: (_, index) {
                      final question = widget.test.questions[index];

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                        child: _QuestionCard(
                          question: question,
                          selected: _answers[index],
                          controller: _controllers[index],
                          onSelected: (answer) {
                            setState(() => _answers[index] = answer);
                            if (_autoScroll &&
                                index < widget.test.questions.length - 1) {
                              Future.delayed(
                                const Duration(milliseconds: 220),
                                () => _goTo(index + 1),
                              );
                            }
                          },
                          onTextChanged: (value) =>
                              _answers[index] = value.trim(),
                        ),
                      );
                    },
                  ),
                ),
                _BottomBar(
                  current: _current,
                  total: widget.test.questions.length,
                  loading: _submitting,
                  onBack: _current > 0 ? () => _goTo(_current - 1) : null,
                  onNext: () {
                    if (_current < widget.test.questions.length - 1) {
                      _goTo(_current + 1);
                    } else {
                      _submit();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListeningResultScreen extends StatelessWidget {
  final ListeningTest test;
  final ListeningTestResult result;

  const ListeningResultScreen({
    super.key,
    required this.test,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
              children: [
                const _ResultHeader(),
                const SizedBox(height: 20),
                _ResultHero(result: result),
                const SizedBox(height: 16),
                _ResultMetrics(result: result),
                const SizedBox(height: 20),
                const _SectionTitle(
                  title: 'Accuracy by Section',
                  subtitle: 'Performance across listening sections',
                ),
                const SizedBox(height: 10),
                ...result.sectionAccuracy.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _AccuracyCard(title: entry.key, value: entry.value),
                  ),
                ),
                const SizedBox(height: 14),
                const _SectionTitle(
                  title: 'Accuracy by Question Type',
                  subtitle: 'Question types requiring more practice',
                ),
                const SizedBox(height: 10),
                ...result.questionTypeAccuracy.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _AccuracyCard(
                      title: entry.key,
                      value: entry.value,
                      color: LColors.violet,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _AnalysisCard(result: result),
                const SizedBox(height: 16),
                _RecommendationCard(result: result),
                if (test.transcript.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _TranscriptCard(
                    transcript: test.transcript,
                    questions: test.questions,
                    result: result,
                  ),
                ],
                const SizedBox(height: 22),
                _GradientButton(
                  title: 'Back to Listening',
                  icon: Icons.headphones_rounded,
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const ListeningScreen()),
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

class ListeningRecentResult {
  final String title;
  final int rawScore;
  final int totalQuestions;
  final double estimatedBand;
  final int accuracyPercent;

  const ListeningRecentResult({
    required this.title,
    required this.rawScore,
    required this.totalQuestions,
    required this.estimatedBand,
    required this.accuracyPercent,
  });

  factory ListeningRecentResult.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return ListeningRecentResult(
      title: (data['title'] ?? 'Listening Test').toString(),
      rawScore: _asInt(data['rawScore']),
      totalQuestions: _asInt(data['totalQuestions'], fallback: 40),
      estimatedBand: _asDouble(data['estimatedBand']),
      accuracyPercent: _asInt(data['accuracyPercent']),
    );
  }
}

class ListeningTest {
  final String id;
  final String title;
  final String description;
  final String mode;
  final int section;
  final String accent;
  final String difficulty;
  final int durationSeconds;
  final String? audioUrl;
  final String? audioStoragePath;
  final String transcript;
  final List<ListeningQuestion> questions;

  const ListeningTest({
    required this.id,
    required this.title,
    required this.description,
    required this.mode,
    required this.section,
    required this.accent,
    required this.difficulty,
    required this.durationSeconds,
    required this.audioUrl,
    required this.audioStoragePath,
    required this.transcript,
    required this.questions,
  });

  factory ListeningTest.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return ListeningTest(
      id: doc.id,
      title: (data['title'] ?? 'Listening Test').toString(),
      description: (data['description'] ?? '').toString(),
      mode: (data['mode'] ?? 'practice').toString(),
      section: _asInt(data['section']),
      accent: (data['accent'] ?? 'British').toString(),
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      durationSeconds: _asInt(data['durationSeconds'], fallback: 1800),
      audioUrl: _nullableString(data['audioUrl']),
      audioStoragePath: _nullableString(data['audioStoragePath']),
      transcript: (data['transcript'] ?? '').toString(),
      questions: _asList(
        data['questions'],
      ).map((item) => ListeningQuestion.fromMap(_asMap(item))).toList(),
    );
  }
}

class ListeningQuestion {
  final int number;
  final int section;
  final String type;
  final String prompt;
  final List<String> options;
  final String correctAnswer;
  final List<String> acceptedAnswers;
  final String explanation;
  final List<String> keywords;

  const ListeningQuestion({
    required this.number,
    required this.section,
    required this.type,
    required this.prompt,
    required this.options,
    required this.correctAnswer,
    required this.acceptedAnswers,
    required this.explanation,
    required this.keywords,
  });

  factory ListeningQuestion.fromMap(Map<String, dynamic> map) {
    final accepted = _asStringList(map['acceptedAnswers']);

    return ListeningQuestion(
      number: _asInt(map['number']),
      section: _asInt(map['section'], fallback: 1),
      type: (map['type'] ?? 'Short answers').toString(),
      prompt: (map['prompt'] ?? '').toString(),
      options: _asStringList(map['options']),
      correctAnswer: (map['correctAnswer'] ?? '').toString(),
      acceptedAnswers: accepted.isEmpty
          ? [(map['correctAnswer'] ?? '').toString()]
          : accepted,
      explanation: (map['explanation'] ?? '').toString(),
      keywords: _asStringList(map['keywords']),
    );
  }
}

class ListeningTestResult {
  final int rawScore;
  final int totalQuestions;
  final double estimatedBand;
  final int accuracyPercent;
  final Map<String, int> sectionAccuracy;
  final Map<String, int> questionTypeAccuracy;
  final List<String> spellingMistakes;
  final List<String> missedKeywords;
  final int durationUsedSeconds;
  final List<String> weakQuestionTypes;
  final Map<int, bool> correctByQuestion;

  const ListeningTestResult({
    required this.rawScore,
    required this.totalQuestions,
    required this.estimatedBand,
    required this.accuracyPercent,
    required this.sectionAccuracy,
    required this.questionTypeAccuracy,
    required this.spellingMistakes,
    required this.missedKeywords,
    required this.durationUsedSeconds,
    required this.weakQuestionTypes,
    required this.correctByQuestion,
  });
}

class ListeningResultCalculator {
  static ListeningTestResult calculate({
    required ListeningTest test,
    required Map<int, String> answers,
    required int durationUsedSeconds,
  }) {
    int score = 0;
    final sectionTotal = <int, int>{};
    final sectionCorrect = <int, int>{};
    final typeTotal = <String, int>{};
    final typeCorrect = <String, int>{};
    final spelling = <String>[];
    final keywords = <String>[];
    final correctMap = <int, bool>{};

    for (int i = 0; i < test.questions.length; i++) {
      final q = test.questions[i];
      final answer = answers[i]?.trim() ?? '';
      final correct = q.acceptedAnswers.any(
        (item) => _normalize(item) == _normalize(answer),
      );

      correctMap[i] = correct;
      sectionTotal[q.section] = (sectionTotal[q.section] ?? 0) + 1;
      typeTotal[q.type] = (typeTotal[q.type] ?? 0) + 1;

      if (correct) {
        score++;
        sectionCorrect[q.section] = (sectionCorrect[q.section] ?? 0) + 1;
        typeCorrect[q.type] = (typeCorrect[q.type] ?? 0) + 1;
      } else {
        if (_near(answer, q.correctAnswer)) {
          spelling.add('$answer → ${q.correctAnswer}');
        }
        for (final keyword in q.keywords) {
          if (!answer.toLowerCase().contains(keyword.toLowerCase())) {
            keywords.add(keyword);
          }
        }
      }
    }

    final sectionAccuracy = <String, int>{};
    sectionTotal.forEach((section, total) {
      sectionAccuracy['Section $section'] =
          (((sectionCorrect[section] ?? 0) / total) * 100).round();
    });

    final typeAccuracy = <String, int>{};
    typeTotal.forEach((type, total) {
      typeAccuracy[type] = (((typeCorrect[type] ?? 0) / total) * 100).round();
    });

    final weakTypes = typeAccuracy.entries
        .where((entry) => entry.value < 70)
        .map((entry) => entry.key)
        .toList();

    final total = test.questions.length;
    final accuracy = total == 0 ? 0 : ((score / total) * 100).round();

    return ListeningTestResult(
      rawScore: score,
      totalQuestions: total,
      estimatedBand: _scoreToBand(score, total),
      accuracyPercent: accuracy,
      sectionAccuracy: sectionAccuracy,
      questionTypeAccuracy: typeAccuracy,
      spellingMistakes: spelling.toSet().toList(),
      missedKeywords: keywords.toSet().toList(),
      durationUsedSeconds: math.max(0, durationUsedSeconds),
      weakQuestionTypes: weakTypes,
      correctByQuestion: correctMap,
    );
  }

  static String _normalize(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static bool _near(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final x = _normalize(a);
    final y = _normalize(b);
    if (x == y) return false;
    return (x.length - y.length).abs() <= 1 &&
        x.isNotEmpty &&
        y.isNotEmpty &&
        x[0] == y[0];
  }

  static double _scoreToBand(int score, int total) {
    if (total == 0) return 0;
    final scaled = (score / total) * 40;
    if (scaled >= 39) return 9;
    if (scaled >= 37) return 8.5;
    if (scaled >= 35) return 8;
    if (scaled >= 32) return 7.5;
    if (scaled >= 30) return 7;
    if (scaled >= 26) return 6.5;
    if (scaled >= 23) return 6;
    if (scaled >= 18) return 5.5;
    if (scaled >= 16) return 5;
    if (scaled >= 13) return 4.5;
    return 4;
  }
}

enum ListeningMode {
  section1(
    'Section 1',
    'section',
    1,
    Icons.looks_one_rounded,
    'Social conversation',
  ),
  section2(
    'Section 2',
    'section',
    2,
    Icons.looks_two_rounded,
    'Social monologue',
  ),
  section3(
    'Section 3',
    'section',
    3,
    Icons.looks_3_rounded,
    'Academic discussion',
  ),
  section4(
    'Section 4',
    'section',
    4,
    Icons.looks_4_rounded,
    'Academic lecture',
  ),
  timed(
    'Timed Listening',
    'timed',
    null,
    Icons.timer_outlined,
    'Practice with a timer',
  ),
  full(
    'Full Listening Test',
    'full',
    null,
    Icons.assignment_outlined,
    'Complete 40 questions',
  ),
  accent(
    'Accent Training',
    'accent',
    null,
    Icons.record_voice_over_rounded,
    'British, Australian and more',
  ),
  learning(
    'Learning Mode',
    'learning',
    null,
    Icons.school_outlined,
    'Replay and speed control',
  );

  final String label;
  final String firestoreValue;
  final int? section;
  final IconData icon;
  final String subtitle;

  const ListeningMode(
    this.label,
    this.firestoreValue,
    this.section,
    this.icon,
    this.subtitle,
  );
}

enum ListeningQuestionType {
  form('Form completion', Icons.description_outlined),
  note('Note completion', Icons.note_alt_outlined),
  table('Table completion', Icons.table_chart_outlined),
  flowchart('Flowchart completion', Icons.account_tree_outlined),
  summary('Summary completion', Icons.summarize_outlined),
  multipleChoice('Multiple choice', Icons.checklist_rtl_rounded),
  matching('Matching', Icons.compare_arrows_rounded),
  map('Map labelling', Icons.map_outlined),
  diagram('Diagram labelling', Icons.schema_outlined),
  sentence('Sentence completion', Icons.short_text_rounded),
  shortAnswer('Short answers', Icons.question_answer_outlined);

  final String label;
  final IconData icon;

  const ListeningQuestionType(this.label, this.icon);
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _GradientIcon(icon: Icons.headphones_rounded),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listening',
                style: TextStyle(
                  color: LColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Real-time IELTS listening practice and analytics',
                style: TextStyle(color: LColors.muted, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BandCard extends StatelessWidget {
  final double band;

  const _BandCard({required this.band});

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
              border: Border.all(color: LColors.cyan, width: 8),
              boxShadow: [
                BoxShadow(color: LColors.cyan.withOpacity(.2), blurRadius: 20),
              ],
            ),
            child: Text(
              band > 0 ? band.toStringAsFixed(1) : '—',
              style: const TextStyle(
                color: LColors.text,
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
                  'Current Estimated Band',
                  style: TextStyle(
                    color: LColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Updated automatically from your latest listening results.',
                  style: TextStyle(
                    color: LColors.secondary,
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

class _WeakTypesCard extends StatelessWidget {
  final List<String> types;

  const _WeakTypesCard({required this.types});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weak Question Types',
            style: TextStyle(
              color: LColors.text,
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

class _RecommendedLessonCard extends StatelessWidget {
  const _RecommendedLessonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: LColors.green.withOpacity(.09),
        border: Border.all(color: LColors.green.withOpacity(.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.recommend_outlined, color: LColors.green, size: 27),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended Lesson',
                  style: TextStyle(color: LColors.muted, fontSize: 9.5),
                ),
                SizedBox(height: 4),
                Text(
                  'Map Labelling Essentials',
                  style: TextStyle(
                    color: LColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Improve direction vocabulary and location prediction.',
                  style: TextStyle(color: LColors.secondary, fontSize: 9.8),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: LColors.green),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final ListeningMode mode;
  final VoidCallback onTap;

  const _ModeCard({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(mode.icon, color: LColors.cyan, size: 25),
          const Spacer(),
          Text(
            mode.label,
            style: const TextStyle(
              color: LColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            mode.subtitle,
            maxLines: 2,
            style: const TextStyle(color: LColors.muted, fontSize: 9.3),
          ),
        ],
      ),
    );
  }
}

class _QuestionTypeCard extends StatelessWidget {
  final ListeningQuestionType type;
  final bool weak;
  final VoidCallback onTap;

  const _QuestionTypeCard({
    required this.type,
    required this.weak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = weak ? const Color(0xFFF97316) : LColors.cyan;

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
                color: LColors.text,
                fontSize: 10.3,
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
  final ListeningRecentResult result;

  const _RecentResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _card(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: LColors.cyan.withOpacity(.13),
            child: Text(
              result.estimatedBand.toStringAsFixed(1),
              style: const TextStyle(
                color: LColors.cyan,
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
                    color: LColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${result.rawScore}/${result.totalQuestions} • ${result.accuracyPercent}% accuracy',
                  style: const TextStyle(color: LColors.muted, fontSize: 9.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final ListeningTest test;
  final VoidCallback onTap;

  const _TestCard({required this.test, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Row(
        children: [
          const _GradientIcon(icon: Icons.play_circle_outline_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  test.title,
                  style: const TextStyle(
                    color: LColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  test.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: LColors.muted, fontSize: 9.8),
                ),
                const SizedBox(height: 7),
                Text(
                  '${test.questions.length} questions • ${_formatClock(test.durationSeconds)} • ${test.accent}',
                  style: const TextStyle(
                    color: LColors.cyan,
                    fontSize: 8.8,
                    fontWeight: FontWeight.w700,
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

class _PracticeHeader extends StatelessWidget {
  final String title;
  final int current;
  final int total;
  final int seconds;

  const _PracticeHeader({
    required this.title,
    required this.current,
    required this.total,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$title\nQuestion ${current + 1} of $total',
              style: const TextStyle(
                color: LColors.text,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _Badge(text: _formatClock(seconds)),
        ],
      ),
    );
  }
}

class _AudioPlayerCard extends StatelessWidget {
  final AudioPlayer player;
  final bool loading;
  final String? error;
  final bool examMode;
  final bool learningMode;
  final double volume;
  final double speed;
  final VoidCallback onPlay;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;

  const _AudioPlayerCard({
    required this.player,
    required this.loading,
    required this.error,
    required this.examMode,
    required this.learningMode,
    required this.volume,
    required this.speed,
    required this.onPlay,
    required this.onVolumeChanged,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(13),
      decoration: _heroDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (_, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return IconButton.filled(
                    onPressed: loading || error != null ? null : onPlay,
                    icon: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                  );
                },
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  error != null
                      ? 'Audio unavailable'
                      : examMode
                      ? 'Exam mode • one playback only'
                      : 'Practice mode • replay available',
                  style: TextStyle(
                    color: error != null ? Colors.redAccent : LColors.text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (learningMode)
                DropdownButton<double>(
                  value: speed,
                  dropdownColor: LColors.surface,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: .75, child: Text('0.75x')),
                    DropdownMenuItem(value: 1, child: Text('1.0x')),
                    DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                    DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                  ],
                  onChanged: (value) {
                    if (value != null) onSpeedChanged(value);
                  },
                ),
            ],
          ),
          if (error == null)
            Row(
              children: [
                const Icon(Icons.volume_down_rounded, color: LColors.muted),
                Expanded(
                  child: Slider(value: volume, onChanged: onVolumeChanged),
                ),
                const Icon(Icons.volume_up_rounded, color: LColors.muted),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuestionNav extends StatelessWidget {
  final int total;
  final int current;
  final Set<int> answered;
  final bool autoScroll;
  final ValueChanged<bool> onAutoScroll;
  final ValueChanged<int> onTap;

  const _QuestionNav({
    required this.total,
    required this.current,
    required this.answered,
    required this.autoScroll,
    required this.onAutoScroll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: total,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) => InkWell(
                onTap: () => onTap(index),
                child: CircleAvatar(
                  backgroundColor: index == current
                      ? LColors.cyan
                      : answered.contains(index)
                      ? LColors.green
                      : LColors.surface,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: index == current ? LColors.bg : LColors.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Switch(
            value: autoScroll,
            onChanged: onAutoScroll,
            activeColor: LColors.cyan,
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final ListeningQuestion question;
  final String? selected;
  final TextEditingController? controller;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onTextChanged;

  const _QuestionCard({
    required this.question,
    required this.selected,
    required this.controller,
    required this.onSelected,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(text: '${question.type} • Section ${question.section}'),
          const SizedBox(height: 14),
          Text(
            question.prompt,
            style: const TextStyle(
              color: LColors.text,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (question.options.isNotEmpty)
            ...question.options.map(
              (option) => RadioListTile<String>(
                value: option,
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) onSelected(value);
                },
                activeColor: LColors.cyan,
                title: Text(
                  option,
                  style: const TextStyle(
                    color: LColors.secondary,
                    fontSize: 11.5,
                  ),
                ),
              ),
            )
          else
            TextField(
              controller: controller,
              onChanged: onTextChanged,
              style: const TextStyle(color: LColors.text),
              decoration: InputDecoration(
                hintText: 'Enter the answer exactly as you hear it',
                filled: true,
                fillColor: LColors.bg.withOpacity(.4),
                border: _border(LColors.border),
                enabledBorder: _border(LColors.border),
                focusedBorder: _border(LColors.cyan),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int current;
  final int total;
  final bool loading;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  const _BottomBar({
    required this.current,
    required this.total,
    required this.loading,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          if (onBack != null)
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                child: const Text('Back'),
              ),
            ),
          if (onBack != null) const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _GradientButton(
              title: current == total - 1 ? 'Submit Test' : 'Next',
              icon: current == total - 1
                  ? Icons.check_rounded
                  : Icons.arrow_forward_rounded,
              loading: loading,
              onPressed: onNext,
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
        Expanded(
          child: Text(
            'Listening Result',
            style: TextStyle(
              color: LColors.text,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Icon(Icons.verified_rounded, color: LColors.green),
      ],
    );
  }
}

class _ResultHero extends StatelessWidget {
  final ListeningTestResult result;

  const _ResultHero({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _heroDecoration(),
      child: Column(
        children: [
          Text(
            result.estimatedBand.toStringAsFixed(1),
            style: const TextStyle(
              color: LColors.cyan,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'ESTIMATED BAND',
            style: TextStyle(
              color: LColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${result.rawScore}/${result.totalQuestions} correct • ${result.accuracyPercent}% accuracy',
            style: const TextStyle(
              color: LColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultMetrics extends StatelessWidget {
  final ListeningTestResult result;

  const _ResultMetrics({required this.result});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Metric(
            value: '${result.spellingMistakes.length}',
            label: 'Spelling',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            value: '${result.missedKeywords.length}',
            label: 'Keywords',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            value: _formatClock(result.durationUsedSeconds),
            label: 'Time Used',
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _card(),
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                color: LColors.cyan,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: LColors.muted, fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;

  const _AccuracyCard({
    required this.title,
    required this.value,
    this.color = LColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: LColors.text,
                    fontSize: 11.5,
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
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value / 100,
            minHeight: 7,
            color: color,
            backgroundColor: LColors.border,
          ),
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final ListeningTestResult result;

  const _AnalysisCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mistake Analysis',
            style: TextStyle(
              color: LColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.spellingMistakes.isEmpty
                ? 'Spelling mistakes: none detected'
                : 'Spelling mistakes: ${result.spellingMistakes.join(', ')}',
            style: const TextStyle(
              color: LColors.secondary,
              fontSize: 10.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            result.missedKeywords.isEmpty
                ? 'Missed keywords: none detected'
                : 'Missed keywords: ${result.missedKeywords.join(', ')}',
            style: const TextStyle(
              color: LColors.secondary,
              fontSize: 10.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final ListeningTestResult result;

  const _RecommendationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final items = result.weakQuestionTypes.isEmpty
        ? const ['Timed mixed listening', 'Section 4 academic lecture']
        : result.weakQuestionTypes.map((e) => '$e targeted practice').toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LColors.green.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LColors.green.withOpacity(.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended Practice',
            style: TextStyle(
              color: LColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: LColors.green,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: LColors.secondary,
                        fontSize: 10.5,
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

class _TranscriptCard extends StatelessWidget {
  final String transcript;
  final List<ListeningQuestion> questions;
  final ListeningTestResult result;

  const _TranscriptCard({
    required this.transcript,
    required this.questions,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      collapsedBackgroundColor: LColors.surface,
      backgroundColor: LColors.surface,
      collapsedIconColor: LColors.cyan,
      iconColor: LColors.cyan,
      title: const Text(
        'Transcript, Correct Answers & Distractors',
        style: TextStyle(
          color: LColors.text,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        SelectableText(
          transcript,
          style: const TextStyle(
            color: LColors.secondary,
            fontSize: 11,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(questions.length, (index) {
          final q = questions[index];
          final correct = result.correctByQuestion[index] ?? false;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: (correct ? LColors.green : Colors.redAccent).withOpacity(
                .08,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              'Q${q.number}: ${q.correctAnswer}\n${q.explanation}',
              style: const TextStyle(
                color: LColors.secondary,
                fontSize: 10,
                height: 1.45,
              ),
            ),
          );
        }),
      ],
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
            color: LColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: LColors.muted, fontSize: 10.5),
        ),
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
      padding: const EdgeInsets.fromLTRB(14, 10, 18, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: LColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: LColors.muted, fontSize: 10),
                ),
              ],
            ),
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _card(),
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LColors.gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: LColors.cyan.withOpacity(.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: LColors.cyan,
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
  final VoidCallback? onPressed;
  final bool loading;

  const _GradientButton({
    required this.title,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LColors.gradient,
          borderRadius: BorderRadius.circular(17),
        ),
        child: ElevatedButton.icon(
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon),
          label: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
          ),
        ),
      ),
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
      padding: const EdgeInsets.all(25),
      decoration: _card(),
      child: Column(
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            color: LColors.muted,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: LColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: LColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _MessageScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool embedded;

  const _MessageScreen({
    required this.icon,
    required this.title,
    required this.message,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: LColors.cyan, size: 46),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: LColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LColors.muted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );

    if (embedded) return content;

    return Scaffold(backgroundColor: LColors.bg, body: content);
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return Container(
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
        ),
      ),
    );
  }
}

class LColors {
  static const bg = Color(0xFF07111F);
  static const surface = Color(0xFF101C2E);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFF26364A);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF34D399);

  static const gradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}

BoxDecoration _card() => BoxDecoration(
  color: LColors.surface.withOpacity(.93),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: Colors.white.withOpacity(.06)),
);

BoxDecoration _heroDecoration() => BoxDecoration(
  borderRadius: BorderRadius.circular(24),
  gradient: LinearGradient(
    colors: [
      const Color(0xFF2563EB).withOpacity(.23),
      LColors.cyan.withOpacity(.1),
      LColors.violet.withOpacity(.15),
    ],
  ),
  border: Border.all(color: LColors.cyan.withOpacity(.18)),
);

OutlineInputBorder _border(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(15),
  borderSide: BorderSide(color: color),
);

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return {};
}

List<dynamic> _asList(dynamic value) => value is List ? value : const [];

List<String> _asStringList(dynamic value) =>
    _asList(value).map((e) => e.toString()).toList();

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

String _formatClock(int seconds) {
  final safe = math.max(0, seconds);
  final minutes = safe ~/ 60;
  final rest = safe % 60;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}
