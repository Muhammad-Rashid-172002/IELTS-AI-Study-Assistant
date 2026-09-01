import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/config/platform_links.dart';
import 'package:fyproject/data/mock_test_repository.dart';
import 'package:fyproject/models/mock_test_models.dart';
import 'package:fyproject/services/mock_timer_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import 'mock_shared_ui.dart';
import 'mock_test_result_screen.dart';

int _runnerInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _runnerStrings(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class MockTestRunnerScreen extends StatefulWidget {
  final String attemptId;
  final MockTestConfig config;

  const MockTestRunnerScreen({
    super.key,
    required this.attemptId,
    required this.config,
  });

  @override
  State<MockTestRunnerScreen> createState() => _MockTestRunnerScreenState();
}

class _MockTestRunnerScreenState extends State<MockTestRunnerScreen> {
  final _repository = MockTestRepository();
  final Map<String, MockAnswer> _answers = {};
  final Map<String, int> _skillTimeSpent = {};

  late final List<MockSkill> _skills;
  late MockSkill _currentSkill;
  late MockTimerController _timerController;

  List<MockQuestion> _questions = [];
  int _skillIndex = 0;
  int _questionIndex = 0;
  int _remainingSeconds = 0;
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  bool _submitting = false;
  Timer? _autosaveTimer;

  MockQuestion? get _currentQuestion {
    if (_questions.isEmpty ||
        _questionIndex < 0 ||
        _questionIndex >= _questions.length) {
      return null;
    }

    return _questions[_questionIndex];
  }

  @override
  void initState() {
    super.initState();

    _skills = widget.config.skills;
    _currentSkill = _skills.first;

    _timerController = MockTimerController(
      initialSeconds: _currentSkill.durationMinutes * 60,
      onTick: (seconds) {
        if (!mounted) return;

        setState(() => _remainingSeconds = seconds);
      },
      onTimeExpired: _handleTimeExpired,
    );

    _loadSkill(_currentSkill);
    _autosaveTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveCheckpoint(),
    );
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _loadSkill(MockSkill skill) async {
    setState(() {
      _loading = true;
      _currentSkill = skill;
      _questionIndex = 0;
    });

    try {
      final questions = await _repository.loadQuestions(
        config: widget.config,
        skill: skill,
      );

      if (!mounted) return;

      _timerController.dispose();
      _timerController = MockTimerController(
        initialSeconds: skill.durationMinutes * 60,
        onTick: (seconds) {
          if (!mounted) return;
          setState(() => _remainingSeconds = seconds);
        },
        onTimeExpired: _handleTimeExpired,
      );

      setState(() {
        _questions = questions;
        _remainingSeconds = skill.durationMinutes * 60;
        _loading = false;
      });

      _timerController.start();
    } catch (error) {
      debugPrint('Mock question loading failed: $error');
      if (!mounted) return;

      setState(() {
        _questions = const [];
        _loadError =
            'This section could not be prepared. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  void _updateAnswer(dynamic value) {
    final question = _currentQuestion;
    if (question == null) return;

    final existing = _answers[question.id];

    setState(() {
      _answers[question.id] = MockAnswer(
        questionId: question.id,
        value: value,
        flagged: existing?.flagged ?? false,
        updatedAt: DateTime.now(),
      );
    });

    _saveCurrentAnswer();
  }

  void _toggleFlag() {
    final question = _currentQuestion;
    if (question == null) return;

    final existing = _answers[question.id];

    setState(() {
      _answers[question.id] = MockAnswer(
        questionId: question.id,
        value: existing?.value,
        flagged: !(existing?.flagged ?? false),
        updatedAt: DateTime.now(),
      );
    });

    _saveCurrentAnswer();
  }

  Future<void> _saveCurrentAnswer() async {
    final question = _currentQuestion;
    if (question == null) return;

    final answer = _answers[question.id];
    if (answer == null) return;

    setState(() => _saving = true);

    try {
      await _repository.saveAnswer(
        attemptId: widget.attemptId,
        skill: _currentSkill,
        answer: answer,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveCheckpoint() async {
    final elapsed = _currentSkill.durationMinutes * 60 - _remainingSeconds;

    _skillTimeSpent[_currentSkill.value] = elapsed;

    await _repository.saveCheckpoint(
      attemptId: widget.attemptId,
      skill: _currentSkill,
      questionIndex: _questionIndex,
      remainingSeconds: _remainingSeconds,
      skillTimeSpent: _skillTimeSpent,
    );
  }

  Future<void> _nextQuestion() async {
    final current = _currentQuestion;
    final currentValue = current == null ? null : _answers[current.id]?.value;
    if (_currentSkill == MockSkill.speaking &&
        (currentValue is! Map ||
            (currentValue['audioStoragePath'] ?? '').toString().isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record and save this speaking response first.'),
          ),
        );
      }
      return;
    }
    await _saveCurrentAnswer();

    if (_questionIndex + 1 < _questions.length) {
      setState(() => _questionIndex++);
      return;
    }

    await _completeCurrentSkill();
  }

  void _previousQuestion() {
    if (_questionIndex > 0) {
      setState(() => _questionIndex--);
    }
  }

  Future<void> _completeCurrentSkill() async {
    _timerController.pause();

    final elapsed = _currentSkill.durationMinutes * 60 - _remainingSeconds;
    _skillTimeSpent[_currentSkill.value] = elapsed;

    if (_skillIndex + 1 < _skills.length) {
      _skillIndex++;
      await _loadSkill(_skills[_skillIndex]);
      return;
    }

    await _submit(autoSubmitted: false);
  }

  Future<void> _handleTimeExpired() async {
    await _completeCurrentSkill();
  }

  Future<void> _submit({required bool autoSubmitted}) async {
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      await _saveCheckpoint();

      await _repository.submitAttempt(
        attemptId: widget.attemptId,
        autoSubmitted: autoSubmitted,
        skillTimeSpent: _skillTimeSpent,
      );

      await _recordMockCycleCompletion();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MockTestResultScreen(attemptId: widget.attemptId),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _recordMockCycleCompletion() async {
    final user = FirebaseAuth.instance.currentUser;
    final mockId = widget.config.mockTestId.trim();

    if (user == null || mockId.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final cycleRef = userRef
        .collection('mock_test_cycles')
        .doc('all_published_mocks');

    try {
      await firestore
          .runTransaction((transaction) async {
            final snapshot = await transaction.get(cycleRef);
            final data = snapshot.data() ?? const <String, dynamic>{};

            final storedCycle = _runnerInt(
              data['cycleNumber'],
              fallback: widget.config.cycleNumber,
            );

            if (storedCycle != widget.config.cycleNumber) return;

            final completedIds = _runnerStrings(
              data['completedMockIds'],
            ).toSet();
            completedIds.add(mockId);

            final total = math.max(1, widget.config.cycleTotalTests);
            final completedCount = math.min(completedIds.length, total);
            final progressPercent = ((completedCount / total) * 100)
                .round()
                .clamp(0, 100);

            transaction.set(cycleRef, {
              'poolKey': 'all_published_mocks',
              'cycleNumber': widget.config.cycleNumber,
              'completedMockIds': completedIds.toList(),
              'completedCount': completedCount,
              'totalMocksAtLastLoad': total,
              'progressPercent': progressPercent,
              'lastCompletedMockId': mockId,
              'lastCompletedMockTitle': widget.config.mockTitle,
              'cycleCompleted': completedCount >= total,
              'lastCompletedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            transaction.set(userRef, {
              'lastMockCycle': widget.config.cycleNumber,
              'lastMockTestId': mockId,
              'lastMockTestAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          })
          .timeout(const Duration(seconds: 15));
    } catch (error, stackTrace) {
      debugPrint('Mock cycle completion update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> _confirmExit() async {
    if (widget.config.mode == MockMode.practice) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: MockColors.surface,
            title: const Text(
              'Exit mock test?',
              style: TextStyle(color: MockColors.text),
            ),
            content: const Text(
              'Your latest answers are autosaved, but the exam timer will continue until the attempt is submitted.',
              style: TextStyle(color: MockColors.secondary, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continue Test'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.config.mode == MockMode.practice,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final exit = await _confirmExit();

        if (exit && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: MockColors.background,
        body: SafeArea(
          child: _loading
              ? MockLoadingPanel(
                  title: 'Loading ${_currentSkill.label}',
                  subtitle:
                      'Restoring your timer, questions and latest saved answers.',
                )
              : _questions.isEmpty
              ? _EmptyQuestionBank(
                  message: _loadError,
                  onRetry: () => _loadSkill(_currentSkill),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 980;

                    return Column(
                      children: [
                        _topBar(),
                        Expanded(
                          child: desktop
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width: 285,
                                      child: _questionPalette(),
                                    ),
                                    Expanded(child: _questionArea()),
                                  ],
                                )
                              : _questionArea(),
                        ),
                        _bottomBar(),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: MockColors.surface,
        border: Border(bottom: BorderSide(color: MockColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              final exit = await _confirmExit();

              if (exit && mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_currentSkill.label} • ${widget.config.mode.label}',
                  style: const TextStyle(
                    color: MockColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Question ${_questionIndex + 1} of ${_questions.length}',
                  style: const TextStyle(color: MockColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Saving',
                    style: TextStyle(color: MockColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          _TimerChip(seconds: _remainingSeconds),
        ],
      ),
    );
  }

  Widget _questionPalette() {
    return Container(
      color: MockColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Question Palette',
            style: TextStyle(
              color: MockColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_questions.length, (index) {
              final question = _questions[index];
              final answer = _answers[question.id];
              final current = index == _questionIndex;

              return _PaletteButton(
                number: index + 1,
                current: current,
                answered: answer?.isAnswered ?? false,
                flagged: answer?.flagged ?? false,
                onTap: () {
                  setState(() => _questionIndex = index);
                },
              );
            }),
          ),
          const Spacer(),
          const _PaletteLegend(),
        ],
      ),
    );
  }

  Widget _questionArea() {
    final question = _currentQuestion!;
    final answer = _answers[question.id];

    return Stack(
      children: [
        const Positioned.fill(child: MockBackground()),
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            Row(
              children: [
                Tag(
                  _currentSkill == MockSkill.speaking
                      ? 'spoken response'
                      : question.type.replaceAll('_', ' '),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _toggleFlag,
                  icon: Icon(
                    answer?.flagged == true
                        ? Icons.flag_rounded
                        : Icons.flag_outlined,
                  ),
                  label: Text(
                    answer?.flagged == true ? 'Flagged' : 'Flag for Review',
                  ),
                ),
              ],
            ),
            if (_currentSkill == MockSkill.listening) ...[
              const SizedBox(height: 12),
              _MockListeningAudioPanel(question: question),
            ],
            if (question.passage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: panelDecoration(),
                child: SelectableText(
                  question.passage,
                  style: const TextStyle(
                    color: MockColors.secondary,
                    height: 1.65,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: heroDecoration(),
              child: Text(
                question.prompt,
                style: const TextStyle(
                  color: MockColors.text,
                  fontSize: 17,
                  height: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _answerWidget(question, answer),
          ],
        ),
      ],
    );
  }

  Widget _answerWidget(MockQuestion question, MockAnswer? answer) {
    // Speaking must always be answered with a real audio recording.
    // Do not trust question.type here because older/admin-authored mock data can
    // contain generic values such as `mixed`, which previously fell through to
    // the text-field fallback and made a speaking response typeable.
    if (_currentSkill == MockSkill.speaking) {
      return _MockSpeakingRecorder(
        key: ValueKey('recorder_${widget.attemptId}_${question.id}'),
        attemptId: widget.attemptId,
        question: question,
        existingValue: answer?.value,
        onUploaded: _updateAnswer,
      );
    }

    switch (question.type) {
      case 'multiple_choice':
        return Column(
          children: question.options.map((option) {
            return RadioListTile<String>(
              value: option,
              groupValue: answer?.value?.toString(),
              onChanged: (value) => _updateAnswer(value),
              title: Text(
                option,
                style: const TextStyle(color: MockColors.text),
              ),
            );
          }).toList(),
        );

      case 'multiple_select':
        final selected = answer?.value is List
            ? List<String>.from(answer!.value)
            : <String>[];

        return Column(
          children: question.options.map((option) {
            return CheckboxListTile(
              value: selected.contains(option),
              onChanged: (checked) {
                final updated = [...selected];

                if (checked == true) {
                  updated.add(option);
                } else {
                  updated.remove(option);
                }

                _updateAnswer(updated);
              },
              title: Text(
                option,
                style: const TextStyle(color: MockColors.text),
              ),
            );
          }).toList(),
        );

      case 'writing_task':
        return TextFormField(
          initialValue: answer?.value?.toString() ?? '',
          minLines: 14,
          maxLines: 24,
          cursorColor: Colors.cyanAccent,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
          onChanged: _updateAnswer,
          decoration: const InputDecoration(
            hintText: 'Write your answer here...',
            hintStyle: TextStyle(color: Colors.white38, fontSize: 17),
            alignLabelWithHint: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        );

      case 'speaking_part':
        return _MockSpeakingRecorder(
          key: ValueKey('recorder_${widget.attemptId}_${question.id}'),
          attemptId: widget.attemptId,
          question: question,
          existingValue: answer?.value,
          onUploaded: _updateAnswer,
        );

      default:
        return TextFormField(
          key: ValueKey(question.id),
          initialValue: answer?.value?.toString() ?? '',
          minLines: 1,
          maxLines: 4,
          cursorColor: MockColors.cyan,
          style: const TextStyle(
            color: MockColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          onChanged: _updateAnswer,
          decoration: const InputDecoration(
            hintText: 'Type your answer...',
            hintStyle: TextStyle(
              color: MockColors.muted,
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: MockColors.violet, width: 2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: MockColors.cyan, width: 2.5),
            ),
          ),
        );
    }
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: MockColors.surface,
        border: Border(top: BorderSide(color: MockColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _questionIndex > 0 ? _previousQuestion : null,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Previous'),
              ),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width < 980)
                IconButton.filledTonal(
                  tooltip: 'Question palette',
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: MockColors.surface,
                      builder: (_) =>
                          SizedBox(height: 420, child: _questionPalette()),
                    );
                  },
                  icon: const Icon(Icons.grid_view_rounded),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _submitting ? null : _nextQuestion,
                icon: Icon(
                  _questionIndex + 1 == _questions.length
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _questionIndex + 1 == _questions.length
                      ? 'Finish Section'
                      : 'Next',
                ),
              ),
            ],
          ),
          if (_currentSkill == MockSkill.speaking) ...[
            const SizedBox(height: 8),
            const SizedBox(
              width: double.infinity,
              child: Text(
                PlatformLinks.audioProcessingNotice,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: MockColors.muted,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MockListeningAudioPanel extends StatefulWidget {
  const _MockListeningAudioPanel({super.key, required this.question});

  final MockQuestion question;

  @override
  State<_MockListeningAudioPanel> createState() =>
      _MockListeningAudioPanelState();
}

class _MockListeningAudioPanelState extends State<_MockListeningAudioPanel> {
  final AudioPlayer _player = AudioPlayer();
  bool _preparing = false;
  String? _resolvedUrl;
  String? _error;

  StreamSubscription<PlayerState>? _playerStateSub;

  String get _audioReference => widget.question.audioUrl.trim();

  @override
  void initState() {
    super.initState();
    _playerStateSub = _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _MockListeningAudioPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id ||
        oldWidget.question.audioUrl != widget.question.audioUrl) {
      _resetForQuestion();
    }
  }

  Future<void> _resetForQuestion() async {
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _resolvedUrl = null;
      _error = null;
      _preparing = false;
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<String> _resolveAudioUrl(String reference) async {
    final value = reference.trim();
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return value;
    }

    if (value.startsWith('gs://')) {
      return FirebaseStorage.instance.refFromURL(value).getDownloadURL();
    }

    // Treat non-URL values as Firebase Storage object paths.
    return FirebaseStorage.instance.ref(value).getDownloadURL();
  }

  Future<void> _togglePlayback() async {
    final reference = _audioReference;
    if (reference.isEmpty || _preparing) return;

    try {
      final state = _player.playerState;
      if (state.playing) {
        await _player.pause();
        return;
      }

      if (state.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }

      if (_resolvedUrl == null) {
        setState(() {
          _preparing = true;
          _error = null;
        });
        final url = await _resolveAudioUrl(reference);
        if (url.isEmpty) {
          throw StateError('Listening audio is unavailable.');
        }
        await _player.setUrl(url);
        _resolvedUrl = url;
      }

      await _player.play();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Audio could not be played. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _audioReference.isNotEmpty;
    final playing = _player.playing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.headphones_rounded, color: MockColors.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Listening audio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MockColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasAudio
                          ? 'Play the recording and answer the questions as you listen.'
                          : 'Audio is not attached to this listening question.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MockColors.muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: MockColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          StreamBuilder<Duration?>(
            stream: _player.durationStream,
            builder: (context, durationSnapshot) {
              final duration = durationSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final maxMs = duration.inMilliseconds <= 0
                      ? 1.0
                      : duration.inMilliseconds.toDouble();
                  final posMs = position.inMilliseconds
                      .clamp(0, maxMs.toInt())
                      .toDouble();

                  return Column(
                    children: [
                      Slider(
                        value: posMs,
                        min: 0,
                        max: maxMs,
                        onChanged: hasAudio && duration > Duration.zero
                            ? (value) => _player.seek(
                                Duration(milliseconds: value.round()),
                              )
                            : null,
                      ),
                      Row(
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              color: MockColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              color: MockColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasAudio && !_preparing ? _togglePlayback : null,
              icon: _preparing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
              label: Text(
                _preparing
                    ? 'Loading audio…'
                    : playing
                    ? 'Pause audio'
                    : 'Play audio',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockSpeakingRecorder extends StatefulWidget {
  const _MockSpeakingRecorder({
    super.key,
    required this.attemptId,
    required this.question,
    required this.existingValue,
    required this.onUploaded,
  });

  final String attemptId;
  final MockQuestion question;
  final dynamic existingValue;
  final ValueChanged<dynamic> onUploaded;

  @override
  State<_MockSpeakingRecorder> createState() => _MockSpeakingRecorderState();
}

class _MockSpeakingRecorderState extends State<_MockSpeakingRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  bool _uploading = false;
  String? _error;
  int _durationSeconds = 0;
  Timer? _timer;

  bool get _hasRecording {
    final value = widget.existingValue;
    return value is Map &&
        (value['audioStoragePath'] ?? '').toString().trim().isNotEmpty;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_uploading) return;
    if (_recording) {
      await _finishAndUpload();
      return;
    }

    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'Microphone permission is required.');
        return;
      }
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/mock_${widget.attemptId}_${widget.question.id}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _durationSeconds = 0;
        _error = null;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _durationSeconds++);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Recording could not start.');
    }
  }

  Future<void> _finishAndUpload() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _uploading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || path == null || !File(path).existsSync()) {
        throw StateError('Recording is unavailable.');
      }
      if (_durationSeconds < 2) {
        throw StateError('Record a complete response before continuing.');
      }
      final safeQuestionId = widget.question.id.replaceAll(
        RegExp('[^a-zA-Z0-9_-]'),
        '_',
      );
      final storagePath =
          'speaking_recordings/${user.uid}/'
          '${widget.attemptId}_${safeQuestionId}.m4a';
      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putFile(File(path), SettableMetadata(contentType: 'audio/mp4'));
      widget.onUploaded({
        'audioStoragePath': storagePath,
        'audioMimeType': 'audio/mp4',
        'durationSeconds': _durationSeconds,
        'questionText': widget.question.prompt,
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: panelDecoration(),
      child: Column(
        children: [
          Icon(
            _recording ? Icons.graphic_eq_rounded : Icons.mic_rounded,
            color: _recording ? MockColors.warning : MockColors.cyan,
            size: 44,
          ),
          const SizedBox(height: 10),
          Text(
            _recording
                ? 'Recording ${_durationSeconds}s'
                : _uploading
                ? 'Securing your recording…'
                : _hasRecording
                ? 'Response recorded and saved'
                : 'Record your complete spoken response',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MockColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MockColors.warning),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _uploading ? null : _toggle,
            icon: _uploading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(
              _recording
                  ? 'Stop and save'
                  : _hasRecording
                  ? 'Record again'
                  : 'Start recording',
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  final int seconds;

  const _TimerChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    final danger = seconds <= 300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: danger
            ? Colors.redAccent.withOpacity(.10)
            : MockColors.cyan.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: danger
              ? Colors.redAccent.withOpacity(.30)
              : MockColors.cyan.withOpacity(.25),
        ),
      ),
      child: Text(
        '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: danger ? Colors.redAccent : MockColors.cyan,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  final int number;
  final bool current;
  final bool answered;
  final bool flagged;
  final VoidCallback onTap;

  const _PaletteButton({
    required this.number,
    required this.current,
    required this.answered,
    required this.flagged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = flagged
        ? MockColors.warning
        : answered
        ? MockColors.green
        : current
        ? MockColors.cyan
        : MockColors.border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color),
        ),
        child: Text(
          '$number',
          style: TextStyle(
            color: current ? MockColors.text : color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PaletteLegend extends StatelessWidget {
  const _PaletteLegend();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegendItem(color: MockColors.green, label: 'Answered'),
        SizedBox(height: 6),
        _LegendItem(color: MockColors.border, label: 'Unanswered'),
        SizedBox(height: 6),
        _LegendItem(color: MockColors.warning, label: 'Flagged'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(color: MockColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _EmptyQuestionBank extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _EmptyQuestionBank({this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StatePanel(
        icon: Icons.inventory_2_outlined,
        title: 'This section is not ready yet',
        subtitle:
            message ??
            'A complete exam section is not available right now. Please try again shortly.',
        actionLabel: 'Try again',
        onAction: onRetry,
      ),
    );
  }
}
