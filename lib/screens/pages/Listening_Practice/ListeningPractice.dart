import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyproject/offline/offline_content_service.dart';
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: _RecommendedLessonCard(
              weakTypes: effectiveWeakTypes,
              recentResults: recentResults,
            ),
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

      if (selectedTest == null) {
        setState(() {
          _loading = false;
          _error =
              'You have completed every available Listening test for this selection. New tests will appear when the administrator publishes them.';
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
    final offline = OfflineContentService.instance;
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
      await offline.cacheMany(
        module: 'listening',
        items: snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
      );
      return snapshot.docs
          .map(ListeningTest.fromDocument)
          .where(_isUsableTest)
          .toList();
    } catch (_) {
      return offline
          .cachedContent('listening', where: _matchesSelection)
          .map(
            (data) => ListeningTest.fromMap(
              data,
              id: data['_offlineId']?.toString() ?? '',
            ),
          )
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

  Future<ListeningTest?> _selectBestTest(List<ListeningTest> tests) async {
    if (tests.isEmpty) return null;

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

    if (unseenTests.isEmpty) return null;
    return unseenTests[math.Random.secure().nextInt(unseenTests.length)];
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

      final next = await _selectBestTest(sectionTests);
      if (next == null) return const <ListeningTest>[];
      selected.add(next);
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
  bool _timerStarted = false;
  bool _audioCached = false;
  bool _audioCaching = false;
  bool _audioCacheFailed = false;
  String? _resolvedAudioUrl;
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
    if (_timerStarted || _submitting) return;

    _timerStarted = true;
    _timer?.cancel();

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
        _audioCached = false;
        _audioCaching = false;
        _audioCacheFailed = false;
        _resolvedAudioUrl = null;
      });
    }

    try {
      await _player.stop();
      final offline = OfflineContentService.instance;
      final localPath = offline.localAudioPath(_currentTest.id);

      if (localPath != null && localPath.trim().isNotEmpty) {
        final localFile = File(localPath);
        if (await localFile.exists() && await localFile.length() > 0) {
          await _player.setFilePath(localPath);
          await _player.setVolume(_volume);
          if (mounted) setState(() => _audioCached = true);
          return;
        }
      }

      if (!offline.isOnline) {
        throw Exception(
          'Section ${_currentTest.section} audio is not available offline yet.',
        );
      }

      String? url = _currentTest.audioUrl?.trim();
      if ((url == null || url.isEmpty) &&
          _currentTest.audioStoragePath?.trim().isNotEmpty == true) {
        url = await FirebaseStorage.instance
            .ref(_currentTest.audioStoragePath!.trim())
            .getDownloadURL()
            .timeout(const Duration(seconds: 15));
      }

      if (url == null || url.isEmpty) {
        throw Exception(
          'Section ${_currentTest.section} audio URL is unavailable.',
        );
      }

      _resolvedAudioUrl = url;
      await _player.setUrl(url).timeout(const Duration(seconds: 25));
      await _player.setVolume(_volume);
    } catch (error, stackTrace) {
      debugPrint('Full listening audio loading failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _audioError = error.toString();
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _cacheCurrentAudioAfterPlay() async {
    if (_audioCached || _audioCaching || _resolvedAudioUrl == null) return;

    final offline = OfflineContentService.instance;
    if (!offline.isOnline) return;

    if (mounted) {
      setState(() {
        _audioCaching = true;
        _audioCacheFailed = false;
      });
    }

    try {
      final path = await offline.cacheRemoteAudio(
        testId: _currentTest.id,
        url: _resolvedAudioUrl!,
      );

      if (path == null || path.trim().isEmpty) {
        throw Exception('Audio cache did not return a local path.');
      }

      final file = File(path);
      if (!await file.exists() || await file.length() <= 0) {
        throw Exception('Downloaded audio file is missing or empty.');
      }

      if (mounted) {
        setState(() {
          _audioCached = true;
          _audioCaching = false;
          _audioCacheFailed = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Full listening audio cache failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _audioCaching = false;
          _audioCacheFailed = true;
        });
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

    if (!_timerStarted) {
      _startTimer();
    }

    await _player.play();
    unawaited(_cacheCurrentAudioAfterPlay());

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
    final offlineResult = <String, dynamic>{
      'testId': combinedTest.id,
      'testIds': _tests.map((test) => test.id).toList(),
      'title': combinedTest.title,
      'mode': 'full',
      'estimatedBand': result.estimatedBand,
      'rawScore': result.rawScore,
      'totalQuestions': result.totalQuestions,
      'accuracyPercent': result.accuracyPercent,
      'sectionAccuracy': result.sectionAccuracy,
      'questionTypeAccuracy': result.questionTypeAccuracy,
      'spellingMistakes': result.spellingMistakes,
      'missedKeywords': result.missedKeywords,
      'durationUsedSeconds': result.durationUsedSeconds,
      'completedAt': DateTime.now().toIso8601String(),
    };

    await OfflineContentService.instance.markCompleted(
      module: 'listening',
      contentId: combinedTest.id,
      result: offlineResult,
      synced: false,
    );

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
        await OfflineContentService.instance.markCompleted(
          module: 'listening',
          contentId: combinedTest.id,
          result: offlineResult,
          synced: true,
        );
      } catch (_) {
        await OfflineContentService.instance.queueFirestoreWrite(
          operation: 'set',
          path:
              'users/${user.uid}/listening_results/offline_${DateTime.now().microsecondsSinceEpoch}',
          data: offlineResult,
        );
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
                  offlineAvailable: _audioCached,
                  caching: _audioCaching,
                  cacheFailed: _audioCacheFailed,
                  online: OfflineContentService.instance.isOnline,
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
  bool _timerStarted = false;
  bool _audioCached = false;
  bool _audioCaching = false;
  bool _audioCacheFailed = false;
  String? _resolvedAudioUrl;
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
    if (mounted) {
      setState(() {
        _loadingAudio = true;
        _audioError = null;
        _audioCached = false;
        _audioCaching = false;
        _audioCacheFailed = false;
        _resolvedAudioUrl = null;
      });
    }

    try {
      final offline = OfflineContentService.instance;
      final localPath = offline.localAudioPath(widget.test.id);

      if (localPath != null && localPath.trim().isNotEmpty) {
        final localFile = File(localPath);
        if (await localFile.exists() && await localFile.length() > 0) {
          await _player.setFilePath(localPath);
          await _player.setVolume(_volume);
          if (mounted) setState(() => _audioCached = true);
          return;
        }
      }

      if (!offline.isOnline) {
        throw Exception(
          'This listening audio is not available offline yet. Play it once while online so it can be saved.',
        );
      }

      String? url = widget.test.audioUrl?.trim();
      if ((url == null || url.isEmpty) &&
          widget.test.audioStoragePath?.trim().isNotEmpty == true) {
        url = await FirebaseStorage.instance
            .ref(widget.test.audioStoragePath!.trim())
            .getDownloadURL()
            .timeout(const Duration(seconds: 15));
      }

      if (url == null || url.isEmpty) {
        throw Exception('Audio URL or Firebase Storage path is missing.');
      }

      _resolvedAudioUrl = url;
      await _player.setUrl(url).timeout(const Duration(seconds: 25));
      await _player.setVolume(_volume);
    } catch (error, stackTrace) {
      debugPrint('Listening audio loading failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _audioError = error.toString();
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _cacheAudioAfterPlay() async {
    if (_audioCached || _audioCaching || _resolvedAudioUrl == null) return;

    final offline = OfflineContentService.instance;
    if (!offline.isOnline) return;

    if (mounted) {
      setState(() {
        _audioCaching = true;
        _audioCacheFailed = false;
      });
    }

    try {
      final path = await offline.cacheRemoteAudio(
        testId: widget.test.id,
        url: _resolvedAudioUrl!,
      );

      if (path == null || path.trim().isEmpty) {
        throw Exception('Audio cache did not return a local path.');
      }

      final file = File(path);
      if (!await file.exists() || await file.length() <= 0) {
        throw Exception('Downloaded audio file is missing or empty.');
      }

      if (mounted) {
        setState(() {
          _audioCached = true;
          _audioCaching = false;
          _audioCacheFailed = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Listening audio cache failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _audioCaching = false;
          _audioCacheFailed = true;
        });
      }
    }
  }

  void _startTimer() {
    if (_timerStarted || _submitting) return;

    _timerStarted = true;
    _timer?.cancel();

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

    if (!_timerStarted) {
      _startTimer();
    }

    await _player.play();
    unawaited(_cacheAudioAfterPlay());
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
    final offlineResult = <String, dynamic>{
      'testId': widget.test.id,
      'title': widget.test.title,
      'mode': widget.test.mode,
      'section': widget.test.section,
      'estimatedBand': result.estimatedBand,
      'rawScore': result.rawScore,
      'totalQuestions': result.totalQuestions,
      'accuracyPercent': result.accuracyPercent,
      'sectionAccuracy': result.sectionAccuracy,
      'questionTypeAccuracy': result.questionTypeAccuracy,
      'spellingMistakes': result.spellingMistakes,
      'missedKeywords': result.missedKeywords,
      'durationUsedSeconds': result.durationUsedSeconds,
      'completedAt': DateTime.now().toIso8601String(),
    };

    await OfflineContentService.instance.markCompleted(
      module: 'listening',
      contentId: widget.test.id,
      result: offlineResult,
      synced: false,
    );

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

        await OfflineContentService.instance.markCompleted(
          module: 'listening',
          contentId: widget.test.id,
          result: offlineResult,
          synced: true,
        );
      } catch (_) {
        await OfflineContentService.instance.queueFirestoreWrite(
          operation: 'set',
          path:
              'users/${user.uid}/listening_results/offline_${DateTime.now().microsecondsSinceEpoch}',
          data: offlineResult,
        );
      }
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
                  offlineAvailable: _audioCached,
                  caching: _audioCaching,
                  cacheFailed: _audioCacheFailed,
                  online: OfflineContentService.instance.isOnline,
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
  ) => ListeningTest.fromMap(doc.data(), id: doc.id);

  factory ListeningTest.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return ListeningTest(
      id: id,
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
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LColors.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: LColors.cyan.withOpacity(.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.headphones_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listening Lab',
                style: TextStyle(
                  color: LColors.text,
                  fontSize: 25,
                  letterSpacing: -.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Train smarter with IELTS-focused practice',
                style: TextStyle(
                  color: LColors.muted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        _Badge(text: 'AI READY'),
      ],
    );
  }
}

class _BandCard extends StatelessWidget {
  final double band;

  const _BandCard({required this.band});

  @override
  Widget build(BuildContext context) {
    final progress = band <= 0 ? 0.0 : (band / 9).clamp(0.0, 1.0);
    final label = band <= 0
        ? 'Complete a test to unlock your estimate'
        : band >= 7
        ? 'Strong performance — keep refining accuracy'
        : band >= 5.5
        ? 'Good progress — focus on weak question types'
        : 'Build consistency with short daily sessions';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _heroDecoration(),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 98,
                height: 98,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 98,
                      height: 98,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        color: LColors.cyan,
                        backgroundColor: Colors.white.withOpacity(.08),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          band > 0 ? band.toStringAsFixed(1) : '—',
                          style: const TextStyle(
                            color: LColors.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'BAND',
                          style: TextStyle(
                            color: LColors.muted,
                            fontSize: 8.5,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Listening Level',
                      style: TextStyle(
                        color: LColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: LColors.secondary,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(.07),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_graph_rounded,
                            size: 15,
                            color: LColors.green,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Updates after every test',
                            style: TextStyle(
                              color: LColors.secondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(17),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _MiniIcon(
                icon: Icons.track_changes_rounded,
                color: LColors.orange,
              ),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Focus Areas',
                      style: TextStyle(
                        color: LColors.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Prioritize these question types next',
                      style: TextStyle(color: LColors.muted, fontSize: 9.7),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types
                .map(
                  (type) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: LColors.orange.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: LColors.orange.withOpacity(.23),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: LColors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          type,
                          style: const TextStyle(
                            color: Color(0xFFFFC28A),
                            fontSize: 9.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
  final List<String> weakTypes;
  final List<ListeningRecentResult> recentResults;

  const _RecommendedLessonCard({
    required this.weakTypes,
    required this.recentResults,
  });

  ListeningQuestionType get _recommendedType {
    final normalizedWeak = weakTypes
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList();

    for (final type in ListeningQuestionType.values) {
      final label = type.label.toLowerCase();

      if (normalizedWeak.any(
        (weak) =>
            weak == label ||
            weak.contains(label) ||
            label.contains(weak),
      )) {
        return type;
      }
    }

    return ListeningQuestionType.multipleChoice;
  }

  String _description(ListeningQuestionType type) {
    switch (type) {
      case ListeningQuestionType.form:
        return 'Build accuracy with names, numbers, dates and short factual details.';
      case ListeningQuestionType.note:
        return 'Train keyword recognition and complete notes without losing context.';
      case ListeningQuestionType.table:
        return 'Improve detail matching across rows, columns and grouped information.';
      case ListeningQuestionType.flowchart:
        return 'Follow sequences, processes and transitions more confidently.';
      case ListeningQuestionType.summary:
        return 'Identify main ideas and complete summaries with precise wording.';
      case ListeningQuestionType.multipleChoice:
        return 'Practice distractor detection, paraphrasing and answer elimination.';
      case ListeningQuestionType.matching:
        return 'Connect speakers, opinions and details accurately while listening.';
      case ListeningQuestionType.map:
        return 'Master directions, landmarks and location prediction.';
      case ListeningQuestionType.diagram:
        return 'Recognize position, structure and labelled visual information.';
      case ListeningQuestionType.sentence:
        return 'Complete sentences using grammar, meaning and word-limit clues.';
      case ListeningQuestionType.shortAnswer:
        return 'Capture exact details and produce concise answers under time pressure.';
    }
  }

  int _estimatedMinutes(ListeningQuestionType type) {
    switch (type) {
      case ListeningQuestionType.map:
      case ListeningQuestionType.diagram:
      case ListeningQuestionType.flowchart:
        return 15;
      case ListeningQuestionType.multipleChoice:
      case ListeningQuestionType.matching:
        return 18;
      default:
        return 12;
    }
  }

  String get _accuracyLabel {
    if (recentResults.isEmpty) return 'Start your first focused practice';

    final accuracy = recentResults.first.accuracyPercent.clamp(0, 100);
    return 'Recent accuracy $accuracy%';
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = _recommendedType;
    final minutes = _estimatedMinutes(recommendation);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ListeningTestBrowserScreen(
                questionType: recommendation.label,
              ),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                LColors.green.withValues(alpha: .14),
                LColors.cyan.withValues(alpha: .07),
              ],
            ),
            border: Border.all(
              color: LColors.green.withValues(alpha: .22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .16),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: LColors.green.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: LColors.green.withValues(alpha: .18),
                  ),
                ),
                child: Icon(
                  recommendation.icon,
                  color: LColors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR NEXT FOCUS',
                      style: TextStyle(
                        color: LColors.green,
                        fontSize: 8.8,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      recommendation.label,
                      style: const TextStyle(
                        color: LColors.text,
                        fontSize: 13.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _description(recommendation),
                      style: const TextStyle(
                        color: LColors.secondary,
                        fontSize: 9.8,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _RecommendationMeta(
                          icon: Icons.analytics_outlined,
                          label: _accuracyLabel,
                        ),
                        _RecommendationMeta(
                          icon: Icons.schedule_rounded,
                          label: '$minutes min',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .07),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .06),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: LColors.green,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RecommendationMeta({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: LColors.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LColors.border.withValues(alpha: .9),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: LColors.green,
            size: 12,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: LColors.secondary,
              fontSize: 8.7,
              fontWeight: FontWeight.w800,
            ),
          ),
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
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -18,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LColors.cyan.withOpacity(.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      LColors.cyan.withOpacity(.22),
                      LColors.violet.withOpacity(.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: LColors.cyan.withOpacity(.18)),
                ),
                child: Icon(mode.icon, color: LColors.cyan, size: 22),
              ),
              const Spacer(),
              Text(
                mode.label,
                style: const TextStyle(
                  color: LColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                mode.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LColors.muted,
                  fontSize: 9.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 9),
              const Row(
                children: [
                  Text(
                    'Start practice',
                    style: TextStyle(
                      color: LColors.cyan,
                      fontSize: 9.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: LColors.cyan,
                    size: 14,
                  ),
                ],
              ),
            ],
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
    final color = weak ? LColors.orange : LColors.cyan;
    return _TapCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(.11),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(.18)),
            ),
            child: Icon(type.icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              type.label,
              maxLines: 2,
              style: const TextStyle(
                color: LColors.text,
                fontSize: 10.3,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (weak)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: LColors.orange.withOpacity(.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'FOCUS',
                style: TextStyle(
                  color: LColors.orange,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: LColors.muted,
              size: 18,
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
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LColors.cyan.withOpacity(.18),
                  LColors.violet.withOpacity(.14),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: LColors.cyan.withOpacity(.16)),
            ),
            child: Text(
              result.estimatedBand.toStringAsFixed(1),
              style: const TextStyle(
                color: LColors.cyan,
                fontSize: 14,
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: LColors.green,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${result.rawScore}/${result.totalQuestions} correct',
                      style: const TextStyle(
                        color: LColors.secondary,
                        fontSize: 9.7,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: LColors.muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '${result.accuracyPercent}% accuracy',
                      style: const TextStyle(
                        color: LColors.cyan,
                        fontSize: 9.7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: LColors.muted),
        ],
      ),
    );
  }
}

// class _TestCard extends StatelessWidget {
//   final ListeningTest test;
//   final VoidCallback onTap;

//   const _TestCard({required this.test, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return _TapCard(
//       onTap: onTap,
//       child: Row(
//         children: [
//           const _GradientIcon(icon: Icons.play_circle_outline_rounded),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   test.title,
//                   style: const TextStyle(
//                     color: LColors.text,
//                     fontSize: 13,
//                     fontWeight: FontWeight.w900,
//                   ),
//                 ),
//                 const SizedBox(height: 5),
//                 Text(
//                   test.description,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(color: LColors.muted, fontSize: 9.8),
//                 ),
//                 const SizedBox(height: 7),
//                 Text(
//                   '${test.questions.length} questions • ${_formatClock(test.durationSeconds)} • ${test.accent}',
//                   style: const TextStyle(
//                     color: LColors.cyan,
//                     fontSize: 8.8,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

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
    final progress = total == 0 ? 0.0 : ((current + 1) / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LColors.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Question ${current + 1} of $total',
                      style: const TextStyle(
                        color: LColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: LColors.orange.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LColors.orange.withOpacity(.18)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: LColors.orange,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatClock(seconds),
                      style: const TextStyle(
                        color: Color(0xFFFFC28A),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              color: LColors.cyan,
              backgroundColor: LColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioOfflineStatus extends StatelessWidget {
  final bool offlineAvailable;
  final bool caching;
  final bool cacheFailed;
  final bool online;

  const _AudioOfflineStatus({
    required this.offlineAvailable,
    required this.caching,
    required this.cacheFailed,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String label;
    late final Color color;

    if (offlineAvailable) {
      icon = Icons.offline_pin_rounded;
      label = online ? 'Available offline' : 'Playing from device';
      color = LColors.green;
    } else if (caching) {
      icon = Icons.cloud_download_rounded;
      label = 'Saving for offline use...';
      color = LColors.cyan;
    } else if (cacheFailed) {
      icon = Icons.cloud_off_rounded;
      label = 'Offline save failed — play again to retry';
      color = const Color(0xFFF97316);
    } else if (online) {
      icon = Icons.cloud_queue_rounded;
      label = 'Streaming • offline save starts when you press Play';
      color = LColors.cyan;
    } else {
      icon = Icons.signal_wifi_connected_no_internet_4_rounded;
      label = 'Audio not available offline';
      color = const Color(0xFFF97316);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.24)),
      ),
      child: Row(
        children: [
          if (caching)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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
  final bool offlineAvailable;
  final bool caching;
  final bool cacheFailed;
  final bool online;
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
    required this.offlineAvailable,
    required this.caching,
    required this.cacheFailed,
    required this.online,
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
          _AudioOfflineStatus(
            offlineAvailable: offlineAvailable,
            caching: caching,
            cacheFailed: cacheFailed,
            online: online,
          ),
          const SizedBox(height: 10),
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
    return Container(
      height: 62,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: LColors.surface.withOpacity(.72),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withOpacity(.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: total,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                final selected = index == current;
                final done = answered.contains(index);
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: selected ? LColors.gradient : null,
                      color: selected
                          ? null
                          : done
                          ? LColors.green.withOpacity(.14)
                          : LColors.bg.withOpacity(.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : done
                            ? LColors.green.withOpacity(.28)
                            : LColors.border,
                      ),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : done
                            ? LColors.green
                            : LColors.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Tooltip(
            message: 'Auto next',
            child: Switch(
              value: autoScroll,
              onChanged: onAutoScroll,
              activeColor: LColors.cyan,
            ),
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
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(text: question.type.toUpperCase()),
              const Spacer(),
              Text(
                'Section ${question.section}',
                style: const TextStyle(
                  color: LColors.muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.prompt,
            style: const TextStyle(
              color: LColors.text,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          if (question.options.isNotEmpty)
            ...question.options.map((option) {
              final isSelected = option == selected;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => onSelected(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? LColors.cyan.withOpacity(.10)
                          : LColors.bg.withOpacity(.42),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isSelected
                            ? LColors.cyan.withOpacity(.55)
                            : LColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? LColors.cyan
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? LColors.cyan : LColors.muted,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: LColors.bg,
                                  size: 15,
                                )
                              : null,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              color: isSelected
                                  ? LColors.text
                                  : LColors.secondary,
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
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
              style: const TextStyle(color: LColors.text, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Type the answer exactly as you hear it',
                hintStyle: const TextStyle(
                  color: LColors.muted,
                  fontSize: 10.5,
                ),
                prefixIcon: const Icon(
                  Icons.edit_note_rounded,
                  color: LColors.cyan,
                ),
                filled: true,
                fillColor: LColors.bg.withOpacity(.45),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 16),
      decoration: BoxDecoration(
        color: LColors.bg.withOpacity(.94),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(.05))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.20),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (onBack != null)
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LColors.secondary,
                    side: const BorderSide(color: LColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            if (onBack != null) const SizedBox(width: 10),
            Expanded(
              child: _GradientButton(
                title: current == total - 1 ? 'Submit Test' : 'Next Question',
                icon: current == total - 1
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_rounded,
                loading: loading,
                onPressed: onNext,
              ),
            ),
          ],
        ),
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

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MiniIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withOpacity(.11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

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
                Color(0xFF030914),
                Color(0xFF071321),
                Color(0xFF091A2E),
                Color(0xFF06101C),
              ],
              stops: [0, .35, .72, 1],
            ),
          ),
        ),
        Positioned(
          top: -110,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LColors.violet.withOpacity(.08),
              boxShadow: [
                BoxShadow(
                  color: LColors.violet.withOpacity(.09),
                  blurRadius: 90,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 240,
          left: -110,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LColors.cyan.withOpacity(.055),
              boxShadow: [
                BoxShadow(
                  color: LColors.cyan.withOpacity(.07),
                  blurRadius: 90,
                  spreadRadius: 25,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LColors {
  static const bg = Color(0xFF06101C);
  static const surface = Color(0xFF101E31);
  static const surface2 = Color(0xFF14243A);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFD3DCE8);
  static const muted = Color(0xFF8FA1B7);
  static const border = Color(0xFF273A52);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF34D399);
  static const orange = Color(0xFFF59E0B);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}

BoxDecoration _card() => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      LColors.surface.withOpacity(.96),
      LColors.surface2.withOpacity(.88),
    ],
  ),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: Colors.white.withOpacity(.065)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(.18),
      blurRadius: 22,
      offset: const Offset(0, 12),
    ),
  ],
);

BoxDecoration _heroDecoration() => BoxDecoration(
  borderRadius: BorderRadius.circular(26),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFF2563EB).withOpacity(.28),
      LColors.cyan.withOpacity(.10),
      LColors.violet.withOpacity(.17),
    ],
  ),
  border: Border.all(color: LColors.cyan.withOpacity(.20)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(.22),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
  ],
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
