import 'package:flutter/material.dart';
import 'package:ielts_ai_master_admin/core/theme/admin_theme.dart';
import 'package:ielts_ai_master_admin/features/generation/data/generation_job_repository.dart';

class CreateReadingGenerationJobSheet extends StatefulWidget {
  const CreateReadingGenerationJobSheet({super.key});

  @override
  State<CreateReadingGenerationJobSheet> createState() =>
      _CreateReadingGenerationJobSheetState();
}

class _CreateReadingGenerationJobSheetState
    extends State<CreateReadingGenerationJobSheet> {
  final ReadingGenerationJobRepository _repository =
      ReadingGenerationJobRepository();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _ieltsType = 'Academic';
  String _mode = 'passage';
  String _difficulty = 'Intermediate';
  String _questionType = 'Multiple choice';
  int _passageCount = 1;
  int _questionCount = 10;
  int _requestedCount = 1;
  bool _loading = false;

  static const List<_ReadingModeOption> _modes = [
    _ReadingModeOption(
      value: 'academic',
      title: 'Academic Reading',
      subtitle: '3 passages • 40 questions',
      icon: Icons.school_outlined,
      badge: 'FULL TEST',
    ),
    _ReadingModeOption(
      value: 'general',
      title: 'General Training',
      subtitle: 'Public, workplace and general texts',
      icon: Icons.work_outline_rounded,
      badge: 'FULL TEST',
    ),
    _ReadingModeOption(
      value: 'passage',
      title: 'Passage Practice',
      subtitle: 'Focused single-passage practice',
      icon: Icons.article_outlined,
      badge: 'POPULAR',
    ),
    _ReadingModeOption(
      value: 'question_type',
      title: 'Question Type Practice',
      subtitle: 'Master one specific format',
      icon: Icons.checklist_rounded,
      badge: 'FOCUSED',
    ),
    _ReadingModeOption(
      value: 'timed',
      title: 'Timed Reading',
      subtitle: '13 questions • 20 minutes',
      icon: Icons.timer_outlined,
      badge: 'TIMED',
    ),
    _ReadingModeOption(
      value: 'full',
      title: 'Full Reading Test',
      subtitle: '3 passages • 40 questions • 60 min',
      icon: Icons.fact_check_outlined,
      badge: 'EXAM',
    ),
    _ReadingModeOption(
      value: 'speed',
      title: 'Speed Reading',
      subtitle: 'WPM and comprehension practice',
      icon: Icons.speed_rounded,
      badge: 'SKILL',
    ),
    _ReadingModeOption(
      value: 'exam',
      title: 'Strict Exam Mode',
      subtitle: 'Full test with learning tools disabled',
      icon: Icons.lock_outline_rounded,
      badge: 'STRICT',
    ),
  ];

  static const List<_QuestionTypeOption> _questionTypes = [
    _QuestionTypeOption(
      value: 'Multiple choice',
      title: 'Multiple choice',
      icon: Icons.checklist_rounded,
      difficulty: 'Medium',
      description: 'Choose the correct option.',
    ),
    _QuestionTypeOption(
      value: 'True / False / Not Given',
      title: 'True / False / Not Given',
      icon: Icons.rule_rounded,
      difficulty: 'Hard',
      description: 'Check factual agreement.',
    ),
    _QuestionTypeOption(
      value: 'Yes / No / Not Given',
      title: 'Yes / No / Not Given',
      icon: Icons.balance_rounded,
      difficulty: 'Hard',
      description: 'Identify the writer’s views.',
    ),
    _QuestionTypeOption(
      value: 'Matching headings',
      title: 'Matching headings',
      icon: Icons.format_align_left_rounded,
      difficulty: 'Hard',
      description: 'Match headings to paragraphs.',
    ),
    _QuestionTypeOption(
      value: 'Matching information',
      title: 'Matching information',
      icon: Icons.compare_arrows_rounded,
      difficulty: 'Medium',
      description: 'Locate details in paragraphs.',
    ),
    _QuestionTypeOption(
      value: 'Matching features',
      title: 'Matching features',
      icon: Icons.account_tree_outlined,
      difficulty: 'Medium',
      description: 'Match people, facts or categories.',
    ),
    _QuestionTypeOption(
      value: 'Sentence endings',
      title: 'Sentence endings',
      icon: Icons.short_text_rounded,
      difficulty: 'Medium',
      description: 'Complete sentences from options.',
    ),
    _QuestionTypeOption(
      value: 'Summary completion',
      title: 'Summary completion',
      icon: Icons.summarize_outlined,
      difficulty: 'Hard',
      description: 'Complete a passage summary.',
    ),
    _QuestionTypeOption(
      value: 'Sentence completion',
      title: 'Sentence completion',
      icon: Icons.notes_rounded,
      difficulty: 'Medium',
      description: 'Fill missing words in sentences.',
    ),
    _QuestionTypeOption(
      value: 'Note completion',
      title: 'Note completion',
      icon: Icons.note_alt_outlined,
      difficulty: 'Medium',
      description: 'Complete structured notes.',
    ),
    _QuestionTypeOption(
      value: 'Table completion',
      title: 'Table completion',
      icon: Icons.table_chart_outlined,
      difficulty: 'Medium',
      description: 'Complete missing table data.',
    ),
    _QuestionTypeOption(
      value: 'Flowchart completion',
      title: 'Flowchart completion',
      icon: Icons.account_tree_rounded,
      difficulty: 'Hard',
      description: 'Complete stages in a process.',
    ),
    _QuestionTypeOption(
      value: 'Diagram labels',
      title: 'Diagram labels',
      icon: Icons.schema_outlined,
      difficulty: 'Medium',
      description: 'Label parts of a diagram.',
    ),
    _QuestionTypeOption(
      value: 'Short answers',
      title: 'Short answers',
      icon: Icons.chat_bubble_outline_rounded,
      difficulty: 'Medium',
      description: 'Give concise text answers.',
    ),
  ];

  bool get _isFullMode =>
      _mode == 'full' ||
      _mode == 'exam' ||
      _mode == 'academic' ||
      _mode == 'general';

  bool get _isQuestionTypeMode => _mode == 'question_type';

  bool get _isSpeedMode => _mode == 'speed';

  int get _durationMinutes {
    if (_isFullMode) return 60;
    if (_mode == 'timed') return 20;
    if (_isSpeedMode) return 10;
    return 20;
  }

  int get _estimatedWords {
    if (_isFullMode) return 2600;
    if (_isSpeedMode) return 450;
    return _passageCount * 750;
  }

  int get _estimatedGenerationMinutes {
    if (_isFullMode) return 5;
    if (_requestedCount >= 5) return 7;
    if (_requestedCount >= 3) return 5;
    return 2;
  }

  int get _qualityEstimate {
    var quality = 94;

    if (_requestedCount == 1) quality += 3;
    if (_difficulty == 'Expert') quality -= 2;
    if (_isFullMode) quality -= 1;

    return quality.clamp(88, 98);
  }

  double get _qualityProgress => _qualityEstimate / 100;

  String get _modeDescription => switch (_mode) {
    'academic' =>
      'Creates a complete Academic Reading test with three increasingly difficult passages and 40 questions.',
    'general' =>
      'Creates a General Training test using public notices, workplace documents and a longer general-interest passage.',
    'passage' =>
      'Creates focused passage practice with configurable passage and question counts.',
    'question_type' =>
      'Creates one passage containing only the selected IELTS Reading question format.',
    'timed' =>
      'Creates a 20-minute, one-passage activity with 13 questions and disabled learning tools.',
    'full' =>
      'Creates a complete 60-minute Reading test with three passages and 40 questions.',
    'speed' =>
      'Creates a shorter passage with comprehension questions and words-per-minute metadata.',
    'exam' =>
      'Creates a strict full Reading test with dictionary, explanation, synonym and hint tools disabled.',
    _ => '',
  };

  String? get _validationMessage {
    if (_isQuestionTypeMode && _questionType.trim().isEmpty) {
      return 'Select one question type.';
    }

    if (_passageCount < 1 || _passageCount > 3) {
      return 'Passage count must be between 1 and 3.';
    }

    if (_questionCount < 5 || _questionCount > 40) {
      return 'Question count must be between 5 and 40.';
    }

    if (_isFullMode && (_passageCount != 3 || _questionCount != 40)) {
      return 'Full Reading modes require 3 passages and 40 questions.';
    }

    if (_requestedCount < 1 || _requestedCount > 5) {
      return 'Number of tests must be between 1 and 5.';
    }

    return null;
  }

  bool get _canSubmit => !_loading && _validationMessage == null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _changeMode(String value) {
    setState(() {
      _mode = value;

      if (value == 'academic') {
        _ieltsType = 'Academic';
      } else if (value == 'general') {
        _ieltsType = 'General Training';
      }

      if (_isFullMode) {
        _passageCount = 3;
        _questionCount = 40;
        _requestedCount = 1;
      } else if (_isSpeedMode) {
        _passageCount = 1;
        _questionCount = 5;
      } else if (value == 'timed') {
        _passageCount = 1;
        _questionCount = 13;
      } else {
        _passageCount = 1;
        _questionCount = 10;
      }
    });
  }

  Future<void> _create() async {
    if (!_canSubmit) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);

    try {
      final jobId = await _repository.createReadingJob(
        ieltsType: _ieltsType,
        mode: _mode,
        difficulty: _difficulty,
        passageCount: _passageCount,
        questionCount: _questionCount,
        requestedCount: _requestedCount,
        questionType: _isQuestionTypeMode ? _questionType : null,
        title: _titleController.text,
        description: _descriptionController.text,
        durationSeconds: _durationMinutes * 60,
        estimatedWords: _estimatedWords,
        qualityTarget: _qualityEstimate,
      );

      if (!mounted) return;

      await _showSuccessDialog(jobId);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showSuccessDialog(String jobId) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AdminColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
          contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0x1A22C55E),
                child: Icon(Icons.check_rounded, color: AdminColors.success),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reading Job Created',
                  style: TextStyle(
                    color: AdminColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogRow(label: 'Mode', value: _selectedMode.title),
              _DialogRow(label: 'IELTS type', value: _ieltsType),
              _DialogRow(
                label: 'Structure',
                value: '$_passageCount passage(s) • $_questionCount questions',
              ),
              if (_isQuestionTypeMode)
                _DialogRow(label: 'Question type', value: _questionType),
              _DialogRow(
                label: 'Estimated time',
                value: '$_estimatedGenerationMinutes minute(s)',
              ),
              _DialogRow(label: 'Job ID', value: jobId),
            ],
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.done_rounded),
              label: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('permission-denied')) {
      return 'Permission denied. Admin account aur Firestore rules check karein.';
    }

    if (message.contains('unavailable')) {
      return 'Firebase temporarily unavailable. Please retry.';
    }

    if (message.contains('quota') || message.contains('429')) {
      return 'Gemini quota reached. Billing, usage ya rate limits check karein.';
    }

    return 'Reading job create nahi hua: $error';
  }

  _ReadingModeOption get _selectedMode {
    return _modes.firstWhere(
      (item) => item.value == _mode,
      orElse: () => _modes.first,
    );
  }

  _QuestionTypeOption get _selectedQuestionType {
    return _questionTypes.firstWhere(
      (item) => item.value == _questionType,
      orElse: () => _questionTypes.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 600 ? 16.0 : 22.0;

    return PopScope(
      canPop: !_loading,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            14,
            horizontalPadding,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 940;

                  if (desktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildScrollableForm()),
                        const SizedBox(width: 18),
                        SizedBox(width: 330, child: _buildStickyPreview()),
                      ],
                    );
                  }

                  return _buildScrollableForm(includeMobilePreview: true);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableForm({bool includeMobilePreview = false}) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildStatsStrip(),
          const SizedBox(height: 22),
          _sectionTitle(
            'IELTS Reading type',
            'Choose the content style used for generated passages.',
          ),
          const SizedBox(height: 12),
          _buildIeltsTypeSelector(),
          const SizedBox(height: 22),
          _sectionTitle(
            'Reading mode',
            'Select the activity that will appear in the student app.',
          ),
          const SizedBox(height: 12),
          _buildModeGrid(),
          const SizedBox(height: 12),
          _InfoPanel(
            icon: Icons.tips_and_updates_outlined,
            title: 'Selected mode',
            message: _modeDescription,
            color: AdminColors.primary,
          ),
          if (_isQuestionTypeMode) ...[
            const SizedBox(height: 22),
            _sectionTitle(
              'Question type',
              'All 14 supported IELTS Reading formats are available.',
            ),
            const SizedBox(height: 12),
            _buildQuestionTypeGrid(),
          ],
          const SizedBox(height: 22),
          _sectionTitle(
            'Difficulty and challenge',
            'Control vocabulary, inference and passage complexity.',
          ),
          const SizedBox(height: 12),
          _buildDifficultySelector(),
          if (!_isFullMode) ...[
            const SizedBox(height: 22),
            _sectionTitle(
              'Test structure',
              'Configure passages and questions for this activity.',
            ),
            const SizedBox(height: 12),
            _buildStructureSelectors(),
          ],
          const SizedBox(height: 22),
          _sectionTitle(
            'Optional metadata',
            'Leave empty to let AI create the title and description.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            enabled: !_loading,
            style: const TextStyle(color: AdminColors.text),
            decoration: const InputDecoration(
              labelText: 'Custom title (optional)',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            enabled: !_loading,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: AdminColors.text),
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              prefixIcon: Icon(Icons.description_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle(
            'Generation quantity',
            'Small batches reduce quota pressure and validation failures.',
          ),
          const SizedBox(height: 12),
          _buildCountSelector(),
          if (includeMobilePreview) ...[
            const SizedBox(height: 22),
            _buildStickyPreview(),
          ],
          const SizedBox(height: 16),
          _InfoPanel(
            icon: Icons.verified_user_outlined,
            title: 'Production validation',
            message:
                'Generated content is saved as a draft, validated by the backend and reviewed by an administrator before publishing.',
            color: AdminColors.success,
          ),
          if (_validationMessage != null) ...[
            const SizedBox(height: 12),
            _InfoPanel(
              icon: Icons.error_outline_rounded,
              title: 'Configuration issue',
              message: _validationMessage!,
              color: const Color(0xFFEF4444),
            ),
          ],
          const SizedBox(height: 18),
          _buildSubmitButton(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [AdminColors.cyan, AdminColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AdminColors.cyan.withOpacity(.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create AI Reading Content',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Generate validated IELTS-style passages, questions, answers and explanations.',
                style: TextStyle(
                  color: AdminColors.textMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _loading
              ? null
              : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(context);
                },
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildStatsStrip() {
    const stats = [
      _MiniMetric(
        label: 'Reading modes',
        value: '8',
        icon: Icons.dashboard_customize_outlined,
      ),
      _MiniMetric(
        label: 'Question types',
        value: '14',
        icon: Icons.quiz_outlined,
      ),
      _MiniMetric(
        label: 'Validation',
        value: 'Enabled',
        icon: Icons.verified_outlined,
      ),
      _MiniMetric(
        label: 'Publishing',
        value: 'Draft first',
        icon: Icons.visibility_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : 4;
        final spacing = 9.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats
              .map((item) => SizedBox(width: width, child: item))
              .toList(),
        );
      },
    );
  }

  Widget _buildIeltsTypeSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 480;

        final academic = _ChoiceCard(
          selected: _ieltsType == 'Academic',
          icon: Icons.school_outlined,
          title: 'Academic',
          subtitle: 'University topics and increasing difficulty',
          onTap: _loading
              ? null
              : () => setState(() => _ieltsType = 'Academic'),
        );

        final general = _ChoiceCard(
          selected: _ieltsType == 'General Training',
          icon: Icons.work_outline_rounded,
          title: 'General Training',
          subtitle: 'Public, workplace and general-interest texts',
          onTap: _loading
              ? null
              : () => setState(() => _ieltsType = 'General Training'),
        );

        if (stacked) {
          return Column(
            children: [academic, const SizedBox(height: 10), general],
          );
        }

        return Row(
          children: [
            Expanded(child: academic),
            const SizedBox(width: 10),
            Expanded(child: general),
          ],
        );
      },
    );
  }

  Widget _buildModeGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520
            ? 2
            : constraints.maxWidth < 780
            ? 3
            : 4;
        final spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _modes.map((option) {
            return SizedBox(
              width: itemWidth,
              child: _ModeCard(
                option: option,
                selected: _mode == option.value,
                onTap: _loading ? null : () => _changeMode(option.value),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildQuestionTypeGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520
            ? 2
            : constraints.maxWidth < 780
            ? 3
            : 4;
        final spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _questionTypes.map((option) {
            return SizedBox(
              width: itemWidth,
              child: _QuestionTypeCard(
                option: option,
                selected: _questionType == option.value,
                onTap: _loading
                    ? null
                    : () => setState(() => _questionType = option.value),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDifficultySelector() {
    const options = [
      ('Foundation', 'Band 4–5', Icons.eco_outlined),
      ('Intermediate', 'Band 5–6', Icons.trending_up_rounded),
      ('Upper Intermediate', 'Band 6–7', Icons.insights_rounded),
      ('Advanced', 'Band 7–8', Icons.auto_graph_rounded),
      ('Expert', 'Band 8–9', Icons.workspace_premium_outlined),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = _difficulty == option.$1;

          return InkWell(
            onTap: _loading
                ? null
                : () => setState(() => _difficulty = option.$1),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 156,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: selected
                    ? AdminColors.primary.withOpacity(.14)
                    : AdminColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AdminColors.primary : AdminColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    option.$3,
                    color: selected ? AdminColors.cyan : AdminColors.textMuted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          option.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AdminColors.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          option.$2,
                          style: TextStyle(
                            color: selected
                                ? AdminColors.cyan
                                : AdminColors.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  Widget _buildStructureSelectors() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 480;

        final passages = DropdownButtonFormField<int>(
          value: _passageCount,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Passages',
            prefixIcon: Icon(Icons.article_outlined),
          ),
          items: const [1, 2, 3]
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text('$value passage${value > 1 ? 's' : ''}'),
                ),
              )
              .toList(),
          onChanged: _loading
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _passageCount = value);
                  }
                },
        );

        final questions = DropdownButtonFormField<int>(
          value: _questionCount,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Questions',
            prefixIcon: Icon(Icons.help_outline_rounded),
          ),
          items: const [5, 8, 10, 13, 15, 20]
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text('$value questions'),
                ),
              )
              .toList(),
          onChanged: _loading
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _questionCount = value);
                  }
                },
        );

        if (stacked) {
          return Column(
            children: [passages, const SizedBox(height: 10), questions],
          );
        }

        return Row(
          children: [
            Expanded(child: passages),
            const SizedBox(width: 10),
            Expanded(child: questions),
          ],
        );
      },
    );
  }

  Widget _buildCountSelector() {
    const counts = [1, 2, 3, 5];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: counts.map((count) {
        final selected = _requestedCount == count;
        final disabled = _isFullMode && count > 1;

        return InkWell(
          onTap: _loading || disabled
              ? null
              : () => setState(() => _requestedCount = count),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: disabled ? .35 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 78,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AdminColors.primary.withOpacity(.14)
                    : AdminColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AdminColors.primary : AdminColors.border,
                ),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? AdminColors.cyan : AdminColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStickyPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                color: AdminColors.cyan,
                size: 21,
              ),
              SizedBox(width: 8),
              Text(
                'Live Generation Preview',
                style: TextStyle(
                  color: AdminColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PreviewLine(label: 'IELTS type', value: _ieltsType),
          _PreviewLine(label: 'Mode', value: _selectedMode.title),
          _PreviewLine(label: 'Difficulty', value: _difficulty),
          if (_isQuestionTypeMode)
            _PreviewLine(
              label: 'Question type',
              value: _selectedQuestionType.title,
            ),
          _PreviewLine(
            label: 'Structure',
            value: '$_passageCount passage(s) • $_questionCount questions',
          ),
          _PreviewLine(
            label: 'Student timer',
            value: '$_durationMinutes minutes',
          ),
          _PreviewLine(label: 'Estimated words', value: '≈ $_estimatedWords'),
          _PreviewLine(label: 'Tests', value: '$_requestedCount'),
          const SizedBox(height: 15),
          Text(
            'AI quality target: $_qualityEstimate%',
            style: const TextStyle(
              color: AdminColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _qualityProgress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            color: AdminColors.success,
            backgroundColor: AdminColors.border,
          ),
          const SizedBox(height: 8),
          const Text(
            'Estimate only. Final quality is calculated by backend validation.',
            style: TextStyle(
              color: AdminColors.textMuted,
              fontSize: 9.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          _TimelineStep(
            icon: Icons.schedule_rounded,
            title: 'Queued',
            active: true,
          ),
          const _TimelineConnector(),
          _TimelineStep(
            icon: Icons.auto_awesome_rounded,
            title: 'Generate passages and questions',
            active: false,
          ),
          const _TimelineConnector(),
          _TimelineStep(
            icon: Icons.verified_outlined,
            title: 'Validate structure and answers',
            active: false,
          ),
          const _TimelineConnector(),
          _TimelineStep(
            icon: Icons.cloud_done_outlined,
            title: 'Save as Firestore draft',
            active: false,
          ),
          const SizedBox(height: 15),
          _InfoPanel(
            icon: Icons.timer_outlined,
            title: 'Estimated generation',
            message:
                'Approximately $_estimatedGenerationMinutes minute(s). Actual time depends on Gemini quota and response size.',
            color: AdminColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _canSubmit
            ? const LinearGradient(
                colors: [AdminColors.cyan, AdminColors.primary],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: FilledButton.icon(
        onPressed: _canSubmit ? _create : null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: AdminColors.border,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _loading
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(
          _loading ? 'Creating Reading Job...' : 'Generate AI Reading Test',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AdminColors.text,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: AdminColors.textMuted,
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ReadingModeOption {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;

  const _ReadingModeOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
  });
}

class _QuestionTypeOption {
  final String value;
  final String title;
  final IconData icon;
  final String difficulty;
  final String description;

  const _QuestionTypeOption({
    required this.value,
    required this.title,
    required this.icon,
    required this.difficulty,
    required this.description,
  });
}

class _ModeCard extends StatelessWidget {
  final _ReadingModeOption option;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 132,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AdminColors.primary.withOpacity(.14)
                : AdminColors.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? AdminColors.primary : AdminColors.border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AdminColors.primary.withOpacity(.08),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    option.icon,
                    color: selected ? AdminColors.cyan : AdminColors.textMuted,
                    size: 24,
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AdminColors.cyan,
                      size: 19,
                    )
                  else
                    _TinyBadge(
                      text: option.badge,
                      color: AdminColors.textMuted,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                option.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                option.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminColors.textMuted,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionTypeCard extends StatelessWidget {
  final _QuestionTypeOption option;
  final bool selected;
  final VoidCallback? onTap;

  const _QuestionTypeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  Color get _difficultyColor {
    switch (option.difficulty) {
      case 'Hard':
        return AdminColors.warning;
      case 'Easy':
        return AdminColors.success;
      default:
        return AdminColors.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected
                ? AdminColors.cyan.withOpacity(.10)
                : AdminColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AdminColors.cyan : AdminColors.border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AdminColors.cyan.withOpacity(.07),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    option.icon,
                    color: selected ? AdminColors.cyan : AdminColors.textMuted,
                    size: 22,
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AdminColors.cyan,
                      size: 18,
                    )
                  else
                    _TinyBadge(
                      text: option.difficulty,
                      color: _difficultyColor,
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                option.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                option.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminColors.textMuted,
                  fontSize: 9.4,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 9),
              const Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: AdminColors.success,
                    size: 14,
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Fully supported',
                      style: TextStyle(
                        color: AdminColors.success,
                        fontSize: 8.8,
                        fontWeight: FontWeight.w800,
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
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AdminColors.primary.withOpacity(.14)
              : AdminColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AdminColors.primary : AdminColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AdminColors.primary.withOpacity(.22)
                    : AdminColors.cyan.withOpacity(.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? AdminColors.cyan : AdminColors.textMuted,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AdminColors.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 10.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AdminColors.cyan,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88, // 82 se 88 kar diya
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AdminColors.cyan, size: 19),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 11.5,
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

class _PreviewLine extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 10.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AdminColors.text,
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

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AdminColors.cyan : AdminColors.textMuted;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withOpacity(.10),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: active ? AdminColors.text : AdminColors.textMuted,
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.only(left: 14),
      color: AdminColors.border,
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _TinyBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AdminColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
