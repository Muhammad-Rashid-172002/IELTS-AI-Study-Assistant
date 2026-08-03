import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WritingChecker extends StatelessWidget {
  const WritingChecker({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: WColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _WritingBackground()),
          SafeArea(
            child: CustomScrollView(
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
                    child: _BandCard(userId: user?.uid),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18, 24, 18, 12),
                    child: _SectionTitle(
                      title: 'Writing Practice',
                      subtitle: 'Choose an IELTS Writing task or learning tool',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final option = WritingHomeOption.values[index];
                      return _HomeOptionCard(
                        option: option,
                        onTap: () => _openOption(context, option),
                      );
                    }, childCount: WritingHomeOption.values.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                      title: 'Task Type Practice',
                      subtitle:
                          'Train for a specific IELTS Writing question format',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _TaskGroup(
                        title: 'Academic Task 1',
                        types: WritingTaskType.academicTask1,
                        category: 'academic_task_1',
                      ),
                      const SizedBox(height: 14),
                      _TaskGroup(
                        title: 'General Training Task 1',
                        types: WritingTaskType.generalTask1,
                        category: 'general_task_1',
                      ),
                      const SizedBox(height: 14),
                      _TaskGroup(
                        title: 'Writing Task 2',
                        types: WritingTaskType.task2,
                        category: 'task_2',
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _openOption(BuildContext context, WritingHomeOption option) {
    switch (option) {
      case WritingHomeOption.academicTask1:
        _openBrowser(context, 'academic_task_1');
        break;
      case WritingHomeOption.generalTask1:
        _openBrowser(context, 'general_task_1');
        break;
      case WritingHomeOption.task2:
        _openBrowser(context, 'task_2');
        break;
      case WritingHomeOption.lessons:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WritingLessonsScreen()),
        );
        break;
      case WritingHomeOption.aiChecker:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiWritingCheckerScreen()),
        );
        break;
      case WritingHomeOption.savedDrafts:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SavedDraftsScreen()),
        );
        break;
      case WritingHomeOption.history:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WritingHistoryScreen()),
        );
        break;
      case WritingHomeOption.modelAnswers:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ModelAnswersScreen()),
        );
        break;
    }
  }

  static void _openBrowser(
    BuildContext context,
    String category, {
    String? type,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WritingTaskBrowserScreen(category: category, taskType: type),
      ),
    );
  }
}

class WritingTaskBrowserScreen extends StatefulWidget {
  final String category;
  final String? taskType;

  const WritingTaskBrowserScreen({
    super.key,
    required this.category,
    this.taskType,
  });

  @override
  State<WritingTaskBrowserScreen> createState() =>
      _WritingTaskBrowserScreenState();
}

class _WritingTaskBrowserScreenState extends State<WritingTaskBrowserScreen> {
  bool _loading = true;
  String? _error;
  List<WritingTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('writing_tasks')
          .where('status', isEqualTo: 'published')
          .where('taskCategory', isEqualTo: widget.category);

      if (widget.taskType != null) {
        query = query.where('taskType', isEqualTo: widget.taskType);
      }

      QuerySnapshot<Map<String, dynamic>> snapshot;

      try {
        snapshot = await query.limit(40).get();
      } on FirebaseException catch (error) {
        if (error.code != 'failed-precondition') rethrow;

        final fallback = await FirebaseFirestore.instance
            .collection('writing_tasks')
            .where('status', isEqualTo: 'published')
            .limit(150)
            .get();

        final docs = fallback.docs.where((doc) {
          final data = doc.data();
          return data['taskCategory'] == widget.category &&
              (widget.taskType == null || data['taskType'] == widget.taskType);
        }).toList();

        if (!mounted) return;
        setState(() {
          _tasks = docs.map(WritingTask.fromDocument).toList();
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _tasks = snapshot.docs.map(WritingTask.fromDocument).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Writing tasks could not be loaded: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.taskType ?? _categoryLabel(widget.category);

    return Scaffold(
      backgroundColor: WColors.background,
      appBar: AppBar(backgroundColor: WColors.background, title: Text(title)),
      body: Stack(
        children: [
          const Positioned.fill(child: _WritingBackground()),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _MessageState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load writing tasks',
              subtitle: _error!,
              action: _load,
            )
          else if (_tasks.isEmpty)
            _MessageState(
              icon: Icons.edit_note_rounded,
              title: 'No published tasks found',
              subtitle: 'Publish a matching Writing task from the admin panel.',
              action: _load,
            )
          else
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
              itemCount: _tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 11),
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return _WritingTaskCard(
                  task: task,
                  onTap: () => _showModeSheet(context, task),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showModeSheet(BuildContext context, WritingTask task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .78,
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
          decoration: const BoxDecoration(
            color: WColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(color: WColors.border),
              left: BorderSide(color: WColors.border),
              right: BorderSide(color: WColors.border),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: WColors.muted.withOpacity(.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Choose Writing Mode',
                  style: TextStyle(
                    color: WColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${task.taskType} • ${task.minimumWords}+ words • '
                  '${_formatClock(task.durationSeconds)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: WColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
                _ModeTile(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Practice Mode',
                  subtitle:
                      'Grammar, vocabulary, checklist and sentence suggestions',
                  badge: 'RECOMMENDED',
                  onTap: () => _start(
                    sheetContext,
                    task,
                    WritingMode.practice,
                  ),
                ),
                const SizedBox(height: 10),
                _ModeTile(
                  icon: Icons.save_outlined,
                  title: 'Draft Mode',
                  subtitle:
                      'No fixed timer, automatic saving and continue later',
                  onTap: () => _start(
                    sheetContext,
                    task,
                    WritingMode.draft,
                  ),
                ),
                const SizedBox(height: 10),
                _ModeTile(
                  icon: Icons.lock_clock_outlined,
                  title: 'Exam Mode',
                  subtitle:
                      'Fixed IELTS timer with hints and corrections disabled',
                  badge: 'STRICT',
                  onTap: () => _start(
                    sheetContext,
                    task,
                    WritingMode.exam,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _start(
    BuildContext sheetContext,
    WritingTask task,
    WritingMode mode,
  ) {
    Navigator.of(sheetContext).pop();

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WritingEditorScreen(
            task: task,
            mode: mode,
          ),
        ),
      );
    });
  }
}

class WritingEditorScreen extends StatefulWidget {
  final WritingTask task;
  final WritingMode mode;
  final String initialAnswer;
  final String? draftId;

  const WritingEditorScreen({
    super.key,
    required this.task,
    required this.mode,
    this.initialAnswer = '',
    this.draftId,
  });

  @override
  State<WritingEditorScreen> createState() => _WritingEditorScreenState();
}

class _WritingEditorScreenState extends State<WritingEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  Timer? _timer;
  Timer? _autosaveTimer;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0;
  bool _fullscreen = false;
  bool _submitting = false;
  bool _showChecklist = true;
  bool _recordingHistory = true;
  String? _draftId;
  String _autosaveLabel = 'Not saved';

  bool get _examMode => widget.mode == WritingMode.exam;
  bool get _practiceMode => widget.mode == WritingMode.practice;
  bool get _draftMode => widget.mode == WritingMode.draft;

  int get _wordCount {
    final text = _controller.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;
  }

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    _controller.text = widget.initialAnswer;
    _remainingSeconds = widget.task.durationSeconds;

    _controller.addListener(_onTextChanged);
    _startClock();
    _autosaveTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _autosave(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autosaveTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_draftMode) {
        setState(() => _elapsedSeconds++);
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        if (_examMode) _submit();
      } else {
        setState(() {
          _remainingSeconds--;
          _elapsedSeconds++;
        });
      }
    });
  }

  void _onTextChanged() {
    if (!_recordingHistory) return;

    final current = _controller.text;
    if (_undoStack.isEmpty || _undoStack.last != current) {
      _undoStack.add(current);
      if (_undoStack.length > 100) _undoStack.removeAt(0);
      _redoStack.clear();
    }

    if (mounted) setState(() {});
  }

  void _undo() {
    if (_undoStack.length < 2) return;

    _recordingHistory = false;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    _controller.text = _undoStack.last;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _recordingHistory = true;
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;

    _recordingHistory = false;
    final value = _redoStack.removeLast();
    _undoStack.add(value);
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _recordingHistory = true;
    setState(() {});
  }

  Future<void> _autosave() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _controller.text.trim().isEmpty) return;

    try {
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('writing_drafts');

      final ref = _draftId == null
          ? collection.doc()
          : collection.doc(_draftId);

      await ref.set({
        'draftId': ref.id,
        'taskId': widget.task.id,
        'title': widget.task.title,
        'taskCategory': widget.task.taskCategory,
        'taskType': widget.task.taskType,
        'mode': widget.mode.name,
        'answer': _controller.text,
        'wordCount': _wordCount,
        'elapsedSeconds': _elapsedSeconds,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _draftId = ref.id;
      if (mounted) {
        setState(() => _autosaveLabel = 'Saved just now');
      }
    } catch (_) {
      if (mounted) setState(() => _autosaveLabel = 'Autosave failed');
    }
  }

  List<String> get _liveSuggestions {
    if (!_practiceMode) return const [];

    final suggestions = <String>[];
    final text = _controller.text.trim();

    if (_wordCount < widget.task.minimumWords) {
      suggestions.add(
        'Add ${widget.task.minimumWords - _wordCount} more words.',
      );
    }

    if (text.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(text)) {
      suggestions.add('End the final sentence with punctuation.');
    }

    final lower = text.toLowerCase();
    if (widget.task.taskCategory == 'academic_task_1' &&
        !lower.contains('overall') &&
        !lower.contains('in general')) {
      suggestions.add('Add a clear overview paragraph.');
    }

    if (RegExp(r'\bI think\b', caseSensitive: false).allMatches(text).length >
        2) {
      suggestions.add(
        'Reduce repeated “I think”; use varied position phrases.',
      );
    }

    if (text.split('\n\n').where((p) => p.trim().isNotEmpty).length < 3 &&
        _wordCount > 80) {
      suggestions.add('Use clearer paragraphing.');
    }

    return suggestions;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final answer = _controller.text.trim();
    if (answer.length < 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write a longer answer before submitting.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    _timer?.cancel();
    await _autosave();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _submitting = false);
      return;
    }

    try {
      final ref = FirebaseFirestore.instance
          .collection('writing_submissions')
          .doc();

      await ref.set({
        'submissionId': ref.id,
        'userId': user.uid,
        'taskId': widget.task.id,
        'title': widget.task.title,
        'taskQuestion': widget.task.taskQuestion,
        'taskCategory': widget.task.taskCategory,
        'taskType': widget.task.taskType,
        'mode': widget.mode.name,
        'answer': answer,
        'wordCount': _wordCount,
        'durationUsedSeconds': _elapsedSeconds,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WritingEvaluationWaitingScreen(
            submissionId: ref.id,
            task: widget.task,
            answer: answer,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submission failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = Column(
      children: [
        if (!_fullscreen)
          _EditorHeader(
            task: widget.task,
            mode: widget.mode,
            remainingSeconds: _remainingSeconds,
            elapsedSeconds: _elapsedSeconds,
            wordCount: _wordCount,
            autosaveLabel: _autosaveLabel,
            onFullscreen: () => setState(() => _fullscreen = true),
          ),
        if (!_fullscreen)
          _TaskPromptCard(
            task: widget.task,
            showChecklist: _showChecklist,
            onToggleChecklist: () {
              setState(() => _showChecklist = !_showChecklist);
            },
          ),
        _EditorToolbar(
          canUndo: _undoStack.length > 1,
          canRedo: _redoStack.isNotEmpty,
          fullscreen: _fullscreen,
          examMode: _examMode,
          onUndo: _undo,
          onRedo: _redo,
          onFullscreen: () {
            setState(() => _fullscreen = !_fullscreen);
          },
          onChecklist: () {
            setState(() => _showChecklist = !_showChecklist);
          },
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;

              final writingBox = Container(
                margin: EdgeInsets.fromLTRB(
                  14,
                  8,
                  wide && _practiceMode ? 6 : 14,
                  10,
                ),
                decoration: _panelDecoration(),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    color: WColors.text,
                    fontSize: 15,
                    height: 1.75,
                  ),
                  decoration: InputDecoration(
                    hintText: _examMode
                        ? 'Write your exam response here...'
                        : 'Start writing your response here...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(18),
                  ),
                ),
              );

              if (wide) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: writingBox),
                    if (_practiceMode)
                      Expanded(
                        child: _SuggestionPanel(
                          suggestions: _liveSuggestions,
                          vocabulary: widget.task.usefulVocabulary,
                        ),
                      ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(child: writingBox),
                  if (_practiceMode && !_fullscreen)
                    _MobileSuggestionStrip(
                      suggestions: _liveSuggestions,
                      vocabulary: widget.task.usefulVocabulary,
                    ),
                ],
              );
            },
          ),
        ),
        _SubmitBar(
          wordCount: _wordCount,
          minimumWords: widget.task.minimumWords,
          loading: _submitting,
          onSave: _autosave,
          onSubmit: _submit,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: WColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _WritingBackground()),
          SafeArea(child: editor),
        ],
      ),
    );
  }
}

class WritingEvaluationWaitingScreen extends StatelessWidget {
  final String submissionId;
  final WritingTask task;
  final String answer;

  const WritingEvaluationWaitingScreen({
    super.key,
    required this.submissionId,
    required this.task,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _WritingBackground()),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('writing_submissions')
                .doc(submissionId)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final status = (data?['status'] ?? 'queued').toString();

              if (status == 'completed' && data?['report'] is Map) {
                final report = WritingReport.fromMap(
                  Map<String, dynamic>.from(data!['report']),
                );

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WritingReportScreen(
                        task: task,
                        answer: answer,
                        report: report,
                      ),
                    ),
                  );
                });
              }

              if (status == 'failed') {
                return _MessageState(
                  icon: Icons.error_outline_rounded,
                  title: 'Evaluation failed',
                  subtitle: (data?['errorMessage'] ?? 'Please try again later.')
                      .toString(),
                  action: () => Navigator.pop(context),
                );
              }

              return const Center(child: _EvaluationLoadingCard());
            },
          ),
        ],
      ),
    );
  }
}

class WritingReportScreen extends StatelessWidget {
  final WritingTask task;
  final String answer;
  final WritingReport report;

  const WritingReportScreen({
    super.key,
    required this.task,
    required this.answer,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.background,
      appBar: AppBar(
        backgroundColor: WColors.background,
        title: const Text('AI Writing Report'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _WritingBackground()),
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 35),
            children: [
              _ReportHero(report: report),
              const SizedBox(height: 14),
              _CriteriaGrid(report: report),
              const SizedBox(height: 18),
              _ReportSection(
                title: 'Grammar Errors',
                icon: Icons.spellcheck_rounded,
                child: _ObjectFeedbackList(
                  items: report.grammarErrors,
                  titleKey: 'original',
                  bodyKeys: const ['correction', 'explanation'],
                ),
              ),
              _ReportSection(
                title: 'Repeated Vocabulary',
                icon: Icons.repeat_rounded,
                child: report.repeatedVocabulary.isEmpty
                    ? const _EmptyFeedback()
                    : Column(
                        children: report.repeatedVocabulary.map((item) {
                          return _FeedbackTile(
                            title: '${item.word} (${item.count} times)',
                            body:
                                'Alternatives: ${item.alternatives.join(', ')}',
                          );
                        }).toList(),
                      ),
              ),
              _ReportSection(
                title: 'Informal Words',
                icon: Icons.record_voice_over_outlined,
                child: _ObjectFeedbackList(
                  items: report.informalWords,
                  titleKey: 'word',
                  bodyKeys: const ['formalAlternative'],
                ),
              ),
              _ReportSection(
                title: 'Weak Paragraphs',
                icon: Icons.view_agenda_outlined,
                child: report.weakParagraphs.isEmpty
                    ? const _EmptyFeedback()
                    : Column(
                        children: report.weakParagraphs.map((item) {
                          return _FeedbackTile(
                            title: 'Paragraph ${item.paragraphNumber}',
                            body: '${item.issue}\n${item.suggestion}',
                          );
                        }).toList(),
                      ),
              ),
              _ReportSection(
                title: 'Sentence-by-Sentence Corrections',
                icon: Icons.compare_arrows_rounded,
                child: _ObjectFeedbackList(
                  items: report.sentenceCorrections,
                  titleKey: 'original',
                  bodyKeys: const ['improved', 'reason'],
                ),
              ),
              _ComparisonTabs(
                answer: answer,
                improved: report.improvedVersion,
                model: task.band8ModelAnswer,
              ),
              const SizedBox(height: 14),
              _ActionPlan(items: report.actionPlan),
            ],
          ),
        ],
      ),
    );
  }
}

class AiWritingCheckerScreen extends StatefulWidget {
  const AiWritingCheckerScreen({super.key});

  @override
  State<AiWritingCheckerScreen> createState() => _AiWritingCheckerScreenState();
}

class _AiWritingCheckerScreenState extends State<AiWritingCheckerScreen> {
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  String _category = 'task_2';
  String _taskType = 'Opinion essay';
  bool _loading = false;

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_questionController.text.trim().length < 20 ||
        _answerController.text.trim().length < 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a valid question and a longer answer.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final ref = FirebaseFirestore.instance
        .collection('writing_submissions')
        .doc();

    await ref.set({
      'submissionId': ref.id,
      'userId': user.uid,
      'taskId': null,
      'title': 'AI Writing Checker',
      'taskQuestion': _questionController.text.trim(),
      'taskCategory': _category,
      'taskType': _taskType,
      'mode': 'checker',
      'answer': _answerController.text.trim(),
      'wordCount': _wordCount(_answerController.text),
      'durationUsedSeconds': 0,
      'status': 'queued',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    final temporaryTask = WritingTask(
      id: '',
      title: 'AI Writing Checker',
      description: '',
      instructions: '',
      taskQuestion: _questionController.text.trim(),
      taskCategory: _category,
      taskType: _taskType,
      difficulty: 'Intermediate',
      minimumWords: _category == 'task_2' ? 250 : 150,
      durationSeconds: _category == 'task_2' ? 2400 : 1200,
      checklist: const [],
      planningPoints: const [],
      usefulVocabulary: const [],
      visualData: const WritingVisualData.empty(),
      band8ModelAnswer: '',
      modelAnswerNotes: const [],
      lesson: const WritingLesson.empty(),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WritingEvaluationWaitingScreen(
          submissionId: ref.id,
          task: temporaryTask,
          answer: _answerController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = _category == 'academic_task_1'
        ? WritingTaskType.academicTask1
        : _category == 'general_task_1'
        ? WritingTaskType.generalTask1
        : WritingTaskType.task2;

    if (!types.contains(_taskType)) _taskType = types.first;

    return Scaffold(
      backgroundColor: WColors.background,
      appBar: AppBar(
        backgroundColor: WColors.background,
        title: const Text('AI Writing Checker'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _WritingBackground()),
          ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const _SectionTitle(
                title: 'Check Your Writing',
                subtitle:
                    'Paste your task question and answer for an estimated IELTS report',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Task Category'),
                items: const [
                  DropdownMenuItem(
                    value: 'academic_task_1',
                    child: Text('Academic Task 1'),
                  ),
                  DropdownMenuItem(
                    value: 'general_task_1',
                    child: Text('General Training Task 1'),
                  ),
                  DropdownMenuItem(
                    value: 'task_2',
                    child: Text('Writing Task 2'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _category = value;
                    _taskType = value == 'academic_task_1'
                        ? WritingTaskType.academicTask1.first
                        : value == 'general_task_1'
                        ? WritingTaskType.generalTask1.first
                        : WritingTaskType.task2.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _taskType,
                decoration: const InputDecoration(labelText: 'Task Type'),
                items: types
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _taskType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _questionController,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Task Question',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _answerController,
                minLines: 12,
                maxLines: 25,
                decoration: const InputDecoration(
                  labelText: 'Your Answer',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_wordCount(_answerController.text)} words',
                style: const TextStyle(color: WColors.muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generate AI Writing Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SavedDraftsScreen extends StatelessWidget {
  const SavedDraftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: WColors.background,
      appBar: AppBar(
        backgroundColor: WColors.background,
        title: const Text('Saved Drafts'),
      ),
      body: user == null
          ? const _MessageState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              subtitle: 'Please sign in to access saved drafts.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('writing_drafts')
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const _MessageState(
                    icon: Icons.save_outlined,
                    title: 'No saved drafts',
                    subtitle: 'Your autosaved writing drafts will appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    return _SimpleListCard(
                      title: (data['title'] ?? 'Writing Draft').toString(),
                      subtitle:
                          '${data['wordCount'] ?? 0} words • ${data['taskType'] ?? ''}',
                      icon: Icons.save_outlined,
                      onTap: null,
                      trailing: IconButton(
                        onPressed: () => doc.reference.delete(),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class WritingHistoryScreen extends StatelessWidget {
  const WritingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: WColors.background,
      appBar: AppBar(
        backgroundColor: WColors.background,
        title: const Text('Writing History'),
      ),
      body: user == null
          ? const _MessageState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              subtitle: 'Please sign in to access writing history.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('writing_results')
                  .orderBy('completedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const _MessageState(
                    icon: Icons.history_rounded,
                    title: 'No writing results yet',
                    subtitle: 'Complete a writing task to build your history.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    return _SimpleListCard(
                      title: (data['title'] ?? 'Writing Result').toString(),
                      subtitle:
                          '${data['wordCount'] ?? 0} words • ${data['taskType'] ?? ''}',
                      icon: Icons.analytics_outlined,
                      trailing: CircleAvatar(
                        backgroundColor: WColors.cyan.withOpacity(.12),
                        child: Text(
                          _asDouble(data['overallBand']).toStringAsFixed(1),
                          style: const TextStyle(
                            color: WColors.cyan,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class ModelAnswersScreen extends StatelessWidget {
  const ModelAnswersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.background,
      appBar: AppBar(
        backgroundColor: WColors.background,
        title: const Text('Band 8 Model Answers'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('writing_tasks')
            .where('status', isEqualTo: 'published')
            .limit(60)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!.docs
              .map(WritingTask.fromDocument)
              .where((task) => task.band8ModelAnswer.isNotEmpty)
              .toList();

          if (tasks.isEmpty) {
            return const _MessageState(
              icon: Icons.library_books_outlined,
              title: 'No model answers available',
              subtitle: 'Publish generated Writing tasks with model answers.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _SimpleListCard(
                title: task.title,
                subtitle: task.taskType,
                icon: Icons.star_outline_rounded,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: WColors.surface,
                    title: Text(
                      task.title,
                      style: const TextStyle(color: WColors.text),
                    ),
                    content: SizedBox(
                      width: 650,
                      child: SingleChildScrollView(
                        child: Text(
                          task.band8ModelAnswer,
                          style: const TextStyle(
                            color: WColors.secondary,
                            height: 1.65,
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class WritingLessonsScreen extends StatelessWidget {
  const WritingLessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const lessons = [
      (
        'Task Achievement',
        'Answer every part of the question and develop relevant ideas.',
        Icons.flag_outlined,
      ),
      (
        'Coherence and Cohesion',
        'Organise ideas logically and use linking language naturally.',
        Icons.account_tree_outlined,
      ),
      (
        'Lexical Resource',
        'Use precise vocabulary, collocations and controlled paraphrasing.',
        Icons.translate_rounded,
      ),
      (
        'Grammar Range and Accuracy',
        'Mix sentence structures while maintaining grammatical control.',
        Icons.spellcheck_rounded,
      ),
      (
        'Academic Task 1 Overview',
        'Identify the most important trends, stages or changes.',
        Icons.insights_rounded,
      ),
      (
        'Essay Planning',
        'Plan your position, topic sentences and supporting examples.',
        Icons.schema_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: WColors.background,
      appBar: AppBar(
        backgroundColor: WColors.background,
        title: const Text('Writing Lessons'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: lessons.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisExtent: 170,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: _panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(lesson.$3, color: WColors.cyan, size: 28),
                const Spacer(),
                Text(
                  lesson.$1,
                  style: const TextStyle(
                    color: WColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  lesson.$2,
                  style: const TextStyle(
                    color: WColors.muted,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class WritingTask {
  final String id;
  final String title;
  final String description;
  final String instructions;
  final String taskQuestion;
  final String taskCategory;
  final String taskType;
  final String difficulty;
  final int minimumWords;
  final int durationSeconds;
  final List<String> checklist;
  final List<String> planningPoints;
  final List<WritingVocabularyItem> usefulVocabulary;
  final WritingVisualData visualData;
  final String band8ModelAnswer;
  final List<String> modelAnswerNotes;
  final WritingLesson lesson;

  const WritingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.taskQuestion,
    required this.taskCategory,
    required this.taskType,
    required this.difficulty,
    required this.minimumWords,
    required this.durationSeconds,
    required this.checklist,
    required this.planningPoints,
    required this.usefulVocabulary,
    required this.visualData,
    required this.band8ModelAnswer,
    required this.modelAnswerNotes,
    required this.lesson,
  });

  factory WritingTask.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return WritingTask.fromMap(data, id: doc.id);
  }

  factory WritingTask.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return WritingTask(
      id: id,
      title: (data['title'] ?? 'Writing Task').toString(),
      description: (data['description'] ?? '').toString(),
      instructions: (data['instructions'] ?? '').toString(),
      taskQuestion: (data['taskQuestion'] ?? '').toString(),
      taskCategory: (data['taskCategory'] ?? 'task_2').toString(),
      taskType: (data['taskType'] ?? 'Opinion essay').toString(),
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      minimumWords: _asInt(data['minimumWords'], fallback: 250),
      durationSeconds: _asInt(data['durationSeconds'], fallback: 2400),
      checklist: _stringList(data['checklist']),
      planningPoints: _stringList(data['planningPoints']),
      usefulVocabulary: _list(data['usefulVocabulary'])
          .map(
            (item) => WritingVocabularyItem.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      visualData: WritingVisualData.fromMap(_map(data['visualData'])),
      band8ModelAnswer: (data['band8ModelAnswer'] ?? '').toString(),
      modelAnswerNotes: _stringList(data['modelAnswerNotes']),
      lesson: WritingLesson.fromMap(_map(data['lesson'])),
    );
  }
}

class WritingVocabularyItem {
  final String word;
  final String meaning;
  final String example;

  const WritingVocabularyItem({
    required this.word,
    required this.meaning,
    required this.example,
  });

  factory WritingVocabularyItem.fromMap(Map<String, dynamic> map) {
    return WritingVocabularyItem(
      word: (map['word'] ?? '').toString(),
      meaning: (map['meaning'] ?? '').toString(),
      example: (map['example'] ?? '').toString(),
    );
  }
}

class WritingVisualData {
  final String title;
  final String description;
  final List<String> categories;
  final List<Map<String, dynamic>> series;
  final List<String> stages;
  final List<String> locations;

  const WritingVisualData({
    required this.title,
    required this.description,
    required this.categories,
    required this.series,
    required this.stages,
    required this.locations,
  });

  const WritingVisualData.empty()
    : title = '',
      description = '',
      categories = const [],
      series = const [],
      stages = const [],
      locations = const [];

  factory WritingVisualData.fromMap(Map<String, dynamic> map) {
    return WritingVisualData(
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      categories: _stringList(map['categories']),
      series: _list(
        map['series'],
      ).map((item) => Map<String, dynamic>.from(item as Map)).toList(),
      stages: _stringList(map['stages']),
      locations: _stringList(map['locations']),
    );
  }
}

class WritingLesson {
  final String overview;
  final List<String> structure;
  final List<String> commonMistakes;
  final List<String> examTips;

  const WritingLesson({
    required this.overview,
    required this.structure,
    required this.commonMistakes,
    required this.examTips,
  });

  const WritingLesson.empty()
    : overview = '',
      structure = const [],
      commonMistakes = const [],
      examTips = const [];

  factory WritingLesson.fromMap(Map<String, dynamic> map) {
    return WritingLesson(
      overview: (map['overview'] ?? '').toString(),
      structure: _stringList(map['structure']),
      commonMistakes: _stringList(map['commonMistakes']),
      examTips: _stringList(map['examTips']),
    );
  }
}

class WritingReport {
  final double overallBand;
  final String summary;
  final int wordCount;
  final bool minimumWordsMet;
  final WritingCriterion taskAchievement;
  final WritingCriterion coherenceAndCohesion;
  final WritingCriterion lexicalResource;
  final WritingCriterion grammaticalRangeAndAccuracy;
  final List<Map<String, dynamic>> grammarErrors;
  final List<RepeatedVocabularyItem> repeatedVocabulary;
  final List<Map<String, dynamic>> informalWords;
  final bool missingOverview;
  final List<WeakParagraph> weakParagraphs;
  final List<Map<String, dynamic>> sentenceCorrections;
  final String improvedVersion;
  final List<String> actionPlan;

  const WritingReport({
    required this.overallBand,
    required this.summary,
    required this.wordCount,
    required this.minimumWordsMet,
    required this.taskAchievement,
    required this.coherenceAndCohesion,
    required this.lexicalResource,
    required this.grammaticalRangeAndAccuracy,
    required this.grammarErrors,
    required this.repeatedVocabulary,
    required this.informalWords,
    required this.missingOverview,
    required this.weakParagraphs,
    required this.sentenceCorrections,
    required this.improvedVersion,
    required this.actionPlan,
  });

  factory WritingReport.fromMap(Map<String, dynamic> map) {
    return WritingReport(
      overallBand: _asDouble(map['overallBand']),
      summary: (map['summary'] ?? '').toString(),
      wordCount: _asInt(map['wordCount']),
      minimumWordsMet: map['minimumWordsMet'] == true,
      taskAchievement: WritingCriterion.fromMap(_map(map['taskAchievement'])),
      coherenceAndCohesion: WritingCriterion.fromMap(
        _map(map['coherenceAndCohesion']),
      ),
      lexicalResource: WritingCriterion.fromMap(_map(map['lexicalResource'])),
      grammaticalRangeAndAccuracy: WritingCriterion.fromMap(
        _map(map['grammaticalRangeAndAccuracy']),
      ),
      grammarErrors: _list(
        map['grammarErrors'],
      ).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      repeatedVocabulary: _list(map['repeatedVocabulary'])
          .map(
            (e) => RepeatedVocabularyItem.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      informalWords: _list(
        map['informalWords'],
      ).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      missingOverview: map['missingOverview'] == true,
      weakParagraphs: _list(map['weakParagraphs'])
          .map(
            (e) => WeakParagraph.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      sentenceCorrections: _list(
        map['sentenceCorrections'],
      ).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      improvedVersion: (map['improvedVersion'] ?? '').toString(),
      actionPlan: _stringList(map['actionPlan']),
    );
  }
}

class WritingCriterion {
  final double band;
  final String feedback;
  final List<String> strengths;
  final List<String> improvements;

  const WritingCriterion({
    required this.band,
    required this.feedback,
    required this.strengths,
    required this.improvements,
  });

  factory WritingCriterion.fromMap(Map<String, dynamic> map) {
    return WritingCriterion(
      band: _asDouble(map['band']),
      feedback: (map['feedback'] ?? '').toString(),
      strengths: _stringList(map['strengths']),
      improvements: _stringList(map['improvements']),
    );
  }
}

class RepeatedVocabularyItem {
  final String word;
  final int count;
  final List<String> alternatives;

  const RepeatedVocabularyItem({
    required this.word,
    required this.count,
    required this.alternatives,
  });

  factory RepeatedVocabularyItem.fromMap(Map<String, dynamic> map) {
    return RepeatedVocabularyItem(
      word: (map['word'] ?? '').toString(),
      count: _asInt(map['count']),
      alternatives: _stringList(map['alternatives']),
    );
  }
}

class WeakParagraph {
  final int paragraphNumber;
  final String issue;
  final String suggestion;

  const WeakParagraph({
    required this.paragraphNumber,
    required this.issue,
    required this.suggestion,
  });

  factory WeakParagraph.fromMap(Map<String, dynamic> map) {
    return WeakParagraph(
      paragraphNumber: _asInt(map['paragraphNumber']),
      issue: (map['issue'] ?? '').toString(),
      suggestion: (map['suggestion'] ?? '').toString(),
    );
  }
}

enum WritingMode { practice, draft, exam }

enum WritingHomeOption {
  academicTask1(
    'Academic Task 1',
    'Charts, maps and processes',
    Icons.insights_rounded,
  ),
  generalTask1(
    'General Training Task 1',
    'Formal and informal letters',
    Icons.mail_outline_rounded,
  ),
  task2(
    'Writing Task 2',
    'Essay practice and planning',
    Icons.article_outlined,
  ),
  lessons(
    'Writing Lessons',
    'Criteria, structure and strategies',
    Icons.school_outlined,
  ),
  aiChecker(
    'AI Writing Checker',
    'Get a detailed estimated band report',
    Icons.auto_awesome_rounded,
  ),
  savedDrafts(
    'Saved Drafts',
    'Continue your autosaved writing',
    Icons.save_outlined,
  ),
  history(
    'Writing History',
    'Track scores and weak areas',
    Icons.history_rounded,
  ),
  modelAnswers(
    'Model Answers',
    'Study Band 8 examples',
    Icons.star_outline_rounded,
  );

  final String title;
  final String subtitle;
  final IconData icon;

  const WritingHomeOption(this.title, this.subtitle, this.icon);
}

abstract final class WritingTaskType {
  static const academicTask1 = [
    'Line graph',
    'Bar chart',
    'Pie chart',
    'Table',
    'Map',
    'Process diagram',
    'Mixed charts',
  ];

  static const generalTask1 = [
    'Formal letter',
    'Semi-formal letter',
    'Informal letter',
  ];

  static const task2 = [
    'Opinion essay',
    'Discussion essay',
    'Advantages/disadvantages',
    'Problem/solution',
    'Two-part question',
    'Direct question essay',
  ];
}

// ---------------------------------------------------------------------------
// UI widgets
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _GradientIcon(icon: Icons.edit_note_rounded),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Writing',
                style: TextStyle(
                  color: WColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'IELTS tasks, smart editor and AI band feedback',
                style: TextStyle(color: WColors.muted, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BandCard extends StatelessWidget {
  final String? userId;

  const _BandCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const _StaticBandCard(band: 0);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        return _StaticBandCard(
          band: _asDouble(snapshot.data?.data()?['writingBand']),
        );
      },
    );
  }
}

class _StaticBandCard extends StatelessWidget {
  final double band;

  const _StaticBandCard({required this.band});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: _heroDecoration(),
      child: Row(
        children: [
          Container(
            width: 86,
            height: 86,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: WColors.cyan, width: 8),
            ),
            child: Text(
              band > 0 ? band.toStringAsFixed(1) : '—',
              style: const TextStyle(
                color: WColors.text,
                fontSize: 25,
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
                  'Current Estimated Writing Band',
                  style: TextStyle(
                    color: WColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Updated after every completed AI Writing report.',
                  style: TextStyle(
                    color: WColors.secondary,
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

class _HomeOptionCard extends StatelessWidget {
  final WritingHomeOption option;
  final VoidCallback onTap;

  const _HomeOptionCard({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(option.icon, color: WColors.cyan, size: 26),
          const Spacer(),
          Text(
            option.title,
            style: const TextStyle(
              color: WColors.text,
              fontSize: 12.4,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            option.subtitle,
            maxLines: 2,
            style: const TextStyle(color: WColors.muted, fontSize: 9.3),
          ),
        ],
      ),
    );
  }
}

class _TaskGroup extends StatelessWidget {
  final String title;
  final List<String> types;
  final String category;

  const _TaskGroup({
    required this.title,
    required this.types,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: WColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((type) {
              return ActionChip(
                label: Text(type),
                avatar: const Icon(Icons.arrow_forward_rounded, size: 16),
                onPressed: () =>
                    WritingChecker._openBrowser(context, category, type: type),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _WritingTaskCard extends StatelessWidget {
  final WritingTask task;
  final VoidCallback onTap;

  const _WritingTaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: WColors.cyan.withOpacity(.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.edit_note_rounded, color: WColors.cyan),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    color: WColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WColors.muted,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Badge(task.taskType),
                    _Badge('${task.minimumWords}+ words'),
                    _Badge(_formatClock(task.durationSeconds)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WColors.background.withOpacity(.62),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: WColors.cyan.withOpacity(.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: WColors.cyan, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: WColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: WColors.cyan.withOpacity(.11),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: WColors.cyan,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: WColors.muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: WColors.muted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  final WritingTask task;
  final WritingMode mode;
  final int remainingSeconds;
  final int elapsedSeconds;
  final int wordCount;
  final String autosaveLabel;
  final VoidCallback onFullscreen;

  const _EditorHeader({
    required this.task,
    required this.mode,
    required this.remainingSeconds,
    required this.elapsedSeconds,
    required this.wordCount,
    required this.autosaveLabel,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final time = mode == WritingMode.draft ? elapsedSeconds : remainingSeconds;
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onFullscreen,
                icon: const Icon(Icons.fullscreen_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                _Badge(mode.name.toUpperCase()),
                const SizedBox(width: 7),
                _Badge('$wordCount words'),
                const SizedBox(width: 7),
                _Badge(_formatClock(time)),
                const Spacer(),
                Text(
                  autosaveLabel,
                  style: const TextStyle(
                    color: WColors.muted,
                    fontSize: 9,
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

class _TaskPromptCard extends StatelessWidget {
  final WritingTask task;
  final bool showChecklist;
  final VoidCallback onToggleChecklist;

  const _TaskPromptCard({
    required this.task,
    required this.showChecklist,
    required this.onToggleChecklist,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(15),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.taskQuestion,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WColors.text,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleChecklist,
                icon: Icon(
                  showChecklist
                      ? Icons.expand_less_rounded
                      : Icons.checklist_rounded,
                ),
              ),
            ],
          ),
          if (task.visualData.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              task.visualData.description,
              style: const TextStyle(
                color: WColors.secondary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
          if (showChecklist) ...[
            const Divider(height: 22),
            ...task.checklist.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: WColors.cyan,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: WColors.secondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final bool fullscreen;
  final bool examMode;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onFullscreen;
  final VoidCallback onChecklist;

  const _EditorToolbar({
    required this.canUndo,
    required this.canRedo,
    required this.fullscreen,
    required this.examMode,
    required this.onUndo,
    required this.onRedo,
    required this.onFullscreen,
    required this.onChecklist,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          IconButton(
            tooltip: 'Undo',
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: canRedo ? onRedo : null,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: fullscreen ? 'Exit full screen' : 'Full screen',
            onPressed: onFullscreen,
            icon: Icon(
              fullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Task checklist',
            onPressed: onChecklist,
            icon: const Icon(Icons.checklist_rounded),
          ),
          if (examMode)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Center(child: _Badge('EXAM MODE • HINTS OFF')),
            ),
        ],
      ),
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  final List<String> suggestions;
  final List<WritingVocabularyItem> vocabulary;
  final bool embedded;

  const _SuggestionPanel({
    required this.suggestions,
    required this.vocabulary,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: embedded
          ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
          : const EdgeInsets.fromLTRB(6, 8, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: ListView(
        children: [
          const Text(
            'Practice Suggestions',
            style: TextStyle(color: WColors.text, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (suggestions.isEmpty)
            const Text(
              'Keep writing. Suggestions will appear as your answer develops.',
              style: TextStyle(
                color: WColors.muted,
                fontSize: 10.5,
                height: 1.45,
              ),
            )
          else
            ...suggestions.map(
              (item) => _FeedbackTile(title: 'Suggestion', body: item),
            ),
          if (vocabulary.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Vocabulary Ideas',
              style: TextStyle(
                color: WColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ...vocabulary
                .take(8)
                .map(
                  (item) => _FeedbackTile(
                    title: item.word,
                    body: '${item.meaning}\n${item.example}',
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _MobileSuggestionStrip extends StatelessWidget {
  final List<String> suggestions;
  final List<WritingVocabularyItem> vocabulary;

  const _MobileSuggestionStrip({
    required this.suggestions,
    required this.vocabulary,
  });

  @override
  Widget build(BuildContext context) {
    final count = suggestions.length + vocabulary.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: WColors.cyan.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WColors.cyan.withOpacity(.20)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: WColors.cyan,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              suggestions.isEmpty
                  ? 'Practice guidance will appear while you write.'
                  : suggestions.first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: WColors.secondary,
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: WColors.surface,
                showDragHandle: true,
                builder: (_) => FractionallySizedBox(
                  heightFactor: .72,
                  child: _SuggestionPanel(
                    suggestions: suggestions,
                    vocabulary: vocabulary,
                    embedded: true,
                  ),
                ),
              );
            },
            child: Text(count > 0 ? 'View $count' : 'View'),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final int wordCount;
  final int minimumWords;
  final bool loading;
  final VoidCallback onSave;
  final VoidCallback onSubmit;

  const _SubmitBar({
    required this.wordCount,
    required this.minimumWords,
    required this.loading,
    required this.onSave,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final met = wordCount >= minimumWords;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: WColors.background,
        border: Border(top: BorderSide(color: WColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              met
                  ? 'Minimum word count reached'
                  : '${minimumWords - wordCount} words remaining',
              style: TextStyle(
                color: met ? WColors.green : WColors.warning,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: loading ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
          const SizedBox(width: 9),
          FilledButton.icon(
            onPressed: loading ? null : onSubmit,
            icon: loading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _EvaluationLoadingCard extends StatelessWidget {
  const _EvaluationLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 430),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(28),
      decoration: _heroDecoration(),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 22),
          Text(
            'Evaluating Your Writing',
            style: TextStyle(
              color: WColors.text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Analysing task response, coherence, vocabulary and grammar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: WColors.secondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  final WritingReport report;

  const _ReportHero({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _heroDecoration(),
      child: Column(
        children: [
          const Text(
            'Overall Estimated Band',
            style: TextStyle(color: WColors.secondary),
          ),
          const SizedBox(height: 8),
          Text(
            report.overallBand.toStringAsFixed(1),
            style: const TextStyle(
              color: WColors.cyan,
              fontSize: 50,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.wordCount} words • ${report.minimumWordsMet ? 'Minimum met' : 'Below minimum'}',
            style: const TextStyle(
              color: WColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            report.summary,
            textAlign: TextAlign.center,
            style: const TextStyle(color: WColors.secondary, height: 1.5),
          ),
          if (report.missingOverview) ...[
            const SizedBox(height: 12),
            const _Badge('MISSING OVERVIEW'),
          ],
        ],
      ),
    );
  }
}

class _CriteriaGrid extends StatelessWidget {
  final WritingReport report;

  const _CriteriaGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Task Achievement / Response', report.taskAchievement),
      ('Coherence and Cohesion', report.coherenceAndCohesion),
      ('Lexical Resource', report.lexicalResource),
      ('Grammatical Range and Accuracy', report.grammaticalRangeAndAccuracy),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        final spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: width,
              child: _CriterionCard(title: item.$1, criterion: item.$2),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CriterionCard extends StatelessWidget {
  final String title;
  final WritingCriterion criterion;

  const _CriterionCard({required this.title, required this.criterion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            criterion.band.toStringAsFixed(1),
            style: const TextStyle(
              color: WColors.cyan,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: WColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            criterion.feedback,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: WColors.muted,
              fontSize: 9.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ReportSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: WColors.cyan),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: WColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ObjectFeedbackList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String titleKey;
  final List<String> bodyKeys;

  const _ObjectFeedbackList({
    required this.items,
    required this.titleKey,
    required this.bodyKeys,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyFeedback();

    return Column(
      children: items.map((item) {
        return _FeedbackTile(
          title: (item[titleKey] ?? '').toString(),
          body: bodyKeys
              .map((key) => (item[key] ?? '').toString())
              .where((value) => value.isNotEmpty)
              .join('\n'),
        );
      }).toList(),
    );
  }
}

class _EmptyFeedback extends StatelessWidget {
  const _EmptyFeedback();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'No major issue was identified in this category.',
      style: TextStyle(color: WColors.muted),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  final String title;
  final String body;

  const _FeedbackTile({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WColors.background.withOpacity(.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: WColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              body,
              style: const TextStyle(
                color: WColors.secondary,
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonTabs extends StatefulWidget {
  final String answer;
  final String improved;
  final String model;

  const _ComparisonTabs({
    required this.answer,
    required this.improved,
    required this.model,
  });

  @override
  State<_ComparisonTabs> createState() => _ComparisonTabsState();
}

class _ComparisonTabsState extends State<_ComparisonTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final labels = ['Your Answer', 'Improved Answer', 'Band 8 Model'];
    final values = [widget.answer, widget.improved, widget.model];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Writing Comparison',
            style: TextStyle(color: WColors.text, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: List.generate(
              labels.length,
              (index) => ChoiceChip(
                selected: _index == index,
                label: Text(labels[index]),
                onSelected: (_) => setState(() => _index = index),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(
            values[_index].isEmpty
                ? 'No answer is available for this comparison.'
                : values[_index],
            style: const TextStyle(color: WColors.secondary, height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _ActionPlan extends StatelessWidget {
  final List<String> items;

  const _ActionPlan({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WColors.green.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WColors.green.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Action Plan',
            style: TextStyle(color: WColors.green, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: WColors.green,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: WColors.secondary),
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

class _SimpleListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SimpleListCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: WColors.cyan.withOpacity(.12),
            child: Icon(icon, color: WColors.cyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: WColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(color: WColors.muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? action;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(24),
        decoration: _panelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: WColors.cyan, size: 50),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: WColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: WColors.muted, height: 1.5),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
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
            color: WColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: WColors.muted, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _TapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TapCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: _panelDecoration(),
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
        gradient: const LinearGradient(colors: [WColors.cyan, WColors.violet]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: WColors.cyan.withOpacity(.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WColors.cyan.withOpacity(.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: WColors.cyan,
          fontSize: 9.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WritingBackground extends StatelessWidget {
  const _WritingBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [WColors.background, Color(0xFF0D172B), WColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

abstract final class WColors {
  static const background = Color(0xFF08111F);
  static const surface = Color(0xFF111C2E);
  static const border = Color(0xFF22324A);
  static const cyan = Color(0xFF06B6D4);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
}

BoxDecoration _panelDecoration() => BoxDecoration(
  color: WColors.surface.withOpacity(.94),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: WColors.border),
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
      WColors.surface,
      WColors.cyan.withOpacity(.09),
      WColors.violet.withOpacity(.08),
    ],
  ),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: WColors.cyan.withOpacity(.22)),
);

String _categoryLabel(String value) => switch (value) {
  'academic_task_1' => 'Academic Task 1',
  'general_task_1' => 'General Training Task 1',
  'task_2' => 'Writing Task 2',
  _ => 'Writing Practice',
};

String _formatClock(int seconds) {
  final safe = math.max(0, seconds);
  final minutes = safe ~/ 60;
  final remaining = safe % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remaining.toString().padLeft(2, '0')}';
}

int _wordCount(String text) {
  final clean = text.trim();
  if (clean.isEmpty) return 0;
  return clean.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

List<dynamic> _list(dynamic value) =>
    value is List ? List<dynamic>.from(value) : <dynamic>[];

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<String> _stringList(dynamic value) => value is List
    ? value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList()
    : <String>[];
