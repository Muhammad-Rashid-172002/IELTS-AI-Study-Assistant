import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/resources/bottom_navigation_bar/botton_navigation.dart';

class PersonalizedStudyPlanScreen extends StatefulWidget {
  final double currentBand;
  final double targetBand;
  final int dailyStudyMinutes;
  final List<String> availableDays;
  final DateTime? examDate;
  final List<String> weakQuestionTypes;
  final Map<String, double> recentScores;

  const PersonalizedStudyPlanScreen({
    super.key,
    required this.currentBand,
    required this.targetBand,
    required this.dailyStudyMinutes,
    required this.availableDays,
    required this.weakQuestionTypes,
    required this.recentScores,
    this.examDate,
  });

  @override
  State<PersonalizedStudyPlanScreen> createState() =>
      _PersonalizedStudyPlanScreenState();
}

class _PersonalizedStudyPlanScreenState
    extends State<PersonalizedStudyPlanScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final List<StudyDayPlan> _weeklyPlan;

  int _selectedDayIndex = 0;
  bool _isSaving = false;
  final Set<String> _completedTaskIds = {};

  @override
  void initState() {
    super.initState();
    _weeklyPlan = _generateAdaptivePlan();
  }

  List<StudyDayPlan> _generateAdaptivePlan() {
    final days = widget.availableDays.isEmpty
        ? const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
        : widget.availableDays;

    final weakestSkill = _getWeakestSkill();
    final secondWeakestSkill = _getSecondWeakestSkill();
    final plan = <StudyDayPlan>[];

    for (int index = 0; index < days.length; index++) {
      final day = days[index];
      final tasks = _tasksForDay(
        dayIndex: index,
        weakestSkill: weakestSkill,
        secondWeakestSkill: secondWeakestSkill,
      );

      plan.add(
        StudyDayPlan(
          day: day,
          totalMinutes: tasks.fold(
            0,
            (sum, task) => sum + task.durationMinutes,
          ),
          tasks: tasks,
        ),
      );
    }

    return plan;
  }

  List<StudyTask> _tasksForDay({
    required int dayIndex,
    required String weakestSkill,
    required String secondWeakestSkill,
  }) {
    final dailyMinutes = widget.dailyStudyMinutes.clamp(15, 120);
    final baseTaskMinutes = dailyMinutes >= 60 ? 20 : 15;
    final shortTaskMinutes = dailyMinutes >= 45 ? 10 : 8;

    final weakTopic = widget.weakQuestionTypes.isNotEmpty
        ? widget.weakQuestionTypes[dayIndex % widget.weakQuestionTypes.length]
        : 'Core IELTS Strategy';

    final taskTemplates = <List<StudyTask>>[
      [
        StudyTask(
          id: 'day${dayIndex}_1',
          title: '$weakestSkill Focus Practice',
          subtitle: weakTopic,
          type: StudyTaskType.practice,
          durationMinutes: baseTaskMinutes,
          icon: _skillIcon(weakestSkill),
          accent: _skillColor(weakestSkill),
        ),
        StudyTask(
          id: 'day${dayIndex}_2',
          title: 'Vocabulary Builder',
          subtitle: 'Learn 10 IELTS topic words',
          type: StudyTaskType.vocabulary,
          durationMinutes: shortTaskMinutes,
          icon: Icons.auto_stories_rounded,
          accent: const Color(0xFF8B5CF6),
        ),
        StudyTask(
          id: 'day${dayIndex}_3',
          title: '$secondWeakestSkill Mini Drill',
          subtitle: 'Targeted confidence practice',
          type: StudyTaskType.practice,
          durationMinutes: shortTaskMinutes,
          icon: _skillIcon(secondWeakestSkill),
          accent: _skillColor(secondWeakestSkill),
        ),
      ],
      [
        StudyTask(
          id: 'day${dayIndex}_1',
          title: 'Reading Strategy Lesson',
          subtitle: 'Matching Headings and paraphrasing',
          type: StudyTaskType.lesson,
          durationMinutes: baseTaskMinutes,
          icon: Icons.menu_book_rounded,
          accent: const Color(0xFF60A5FA),
        ),
        StudyTask(
          id: 'day${dayIndex}_2',
          title: 'Writing Task 2 Lesson',
          subtitle: 'Structure, thesis and coherence',
          type: StudyTaskType.lesson,
          durationMinutes: baseTaskMinutes,
          icon: Icons.edit_note_rounded,
          accent: const Color(0xFFA78BFA),
        ),
        StudyTask(
          id: 'day${dayIndex}_3',
          title: 'Grammar Mini Quiz',
          subtitle: 'Complex sentences and accuracy',
          type: StudyTaskType.quiz,
          durationMinutes: shortTaskMinutes,
          icon: Icons.quiz_outlined,
          accent: const Color(0xFFF59E0B),
        ),
      ],
      [
        StudyTask(
          id: 'day${dayIndex}_1',
          title: 'Listening Map Labelling',
          subtitle: 'Directions, locations and distractors',
          type: StudyTaskType.practice,
          durationMinutes: baseTaskMinutes,
          icon: Icons.headphones_rounded,
          accent: const Color(0xFF22D3EE),
        ),
        StudyTask(
          id: 'day${dayIndex}_2',
          title: 'Speaking Cue Card',
          subtitle: '1-minute preparation and 2-minute answer',
          type: StudyTaskType.speaking,
          durationMinutes: baseTaskMinutes,
          icon: Icons.mic_rounded,
          accent: const Color(0xFF34D399),
        ),
        StudyTask(
          id: 'day${dayIndex}_3',
          title: 'Vocabulary Review',
          subtitle: 'Spaced repetition review',
          type: StudyTaskType.vocabulary,
          durationMinutes: shortTaskMinutes,
          icon: Icons.refresh_rounded,
          accent: const Color(0xFF8B5CF6),
        ),
      ],
      [
        StudyTask(
          id: 'day${dayIndex}_1',
          title: '$weakestSkill Timed Practice',
          subtitle: 'Improve speed and exam control',
          type: StudyTaskType.timed,
          durationMinutes: baseTaskMinutes,
          icon: Icons.timer_outlined,
          accent: _skillColor(weakestSkill),
        ),
        StudyTask(
          id: 'day${dayIndex}_2',
          title: 'Error Review',
          subtitle: 'Understand recent mistakes',
          type: StudyTaskType.review,
          durationMinutes: shortTaskMinutes,
          icon: Icons.fact_check_outlined,
          accent: const Color(0xFFF97316),
        ),
        StudyTask(
          id: 'day${dayIndex}_3',
          title: 'AI Coach Reflection',
          subtitle: 'Update your next focus area',
          type: StudyTaskType.aiCoach,
          durationMinutes: shortTaskMinutes,
          icon: Icons.psychology_alt_rounded,
          accent: const Color(0xFF06B6D4),
        ),
      ],
      [
        StudyTask(
          id: 'day${dayIndex}_1',
          title: 'Mini Mock Test',
          subtitle: 'Mixed Listening, Reading and Writing',
          type: StudyTaskType.mock,
          durationMinutes: dailyMinutes >= 60 ? 30 : 20,
          icon: Icons.assignment_outlined,
          accent: const Color(0xFF2563EB),
        ),
        StudyTask(
          id: 'day${dayIndex}_2',
          title: 'Weekly Performance Review',
          subtitle: 'Compare scores and weak areas',
          type: StudyTaskType.review,
          durationMinutes: shortTaskMinutes,
          icon: Icons.analytics_outlined,
          accent: const Color(0xFF34D399),
        ),
      ],
      [
        StudyTask(
          id: 'day${dayIndex}_1',
          title: 'Writing Improvement Session',
          subtitle: 'Rewrite one weak paragraph',
          type: StudyTaskType.writing,
          durationMinutes: baseTaskMinutes,
          icon: Icons.edit_note_rounded,
          accent: const Color(0xFFA78BFA),
        ),
        StudyTask(
          id: 'day${dayIndex}_2',
          title: 'Speaking Fluency Drill',
          subtitle: 'Reduce pauses and extend answers',
          type: StudyTaskType.speaking,
          durationMinutes: baseTaskMinutes,
          icon: Icons.record_voice_over_rounded,
          accent: const Color(0xFF34D399),
        ),
      ],
      [
        StudyTask(
          id: 'day${dayIndex}_1',
          title: 'Light Review Day',
          subtitle: 'Review vocabulary and saved mistakes',
          type: StudyTaskType.review,
          durationMinutes: shortTaskMinutes,
          icon: Icons.self_improvement_rounded,
          accent: const Color(0xFF22D3EE),
        ),
        StudyTask(
          id: 'day${dayIndex}_2',
          title: 'Next Week Preparation',
          subtitle: 'Set goals with AI Coach',
          type: StudyTaskType.aiCoach,
          durationMinutes: shortTaskMinutes,
          icon: Icons.route_rounded,
          accent: const Color(0xFF8B5CF6),
        ),
      ],
    ];

    return taskTemplates[dayIndex % taskTemplates.length];
  }

  String _getWeakestSkill() {
    if (widget.recentScores.isEmpty) {
      return 'Writing';
    }

    return widget.recentScores.entries
        .reduce((a, b) => a.value <= b.value ? a : b)
        .key;
  }

  String _getSecondWeakestSkill() {
    if (widget.recentScores.length < 2) {
      return 'Reading';
    }

    final sorted = widget.recentScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return sorted[1].key;
  }

  IconData _skillIcon(String skill) {
    switch (skill.toLowerCase()) {
      case 'listening':
        return Icons.headphones_rounded;
      case 'reading':
        return Icons.menu_book_rounded;
      case 'writing':
        return Icons.edit_note_rounded;
      case 'speaking':
        return Icons.mic_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _skillColor(String skill) {
    switch (skill.toLowerCase()) {
      case 'listening':
        return const Color(0xFF22D3EE);
      case 'reading':
        return const Color(0xFF60A5FA);
      case 'writing':
        return const Color(0xFFA78BFA);
      case 'speaking':
        return const Color(0xFF34D399);
      default:
        return const Color(0xFF06B6D4);
    }
  }

  int get _completedCount => _completedTaskIds.length;

  int get _totalTaskCount =>
      _weeklyPlan.fold(0, (sum, day) => sum + day.tasks.length);

  double get _completionProgress {
    if (_totalTaskCount == 0) return 0;
    return _completedCount / _totalTaskCount;
  }

  int get _daysUntilExam {
    if (widget.examDate == null) return 0;
    final difference = widget.examDate!.difference(DateTime.now()).inDays;
    return difference < 0 ? 0 : difference;
  }

  void _toggleTask(String taskId) {
    setState(() {
      if (_completedTaskIds.contains(taskId)) {
        _completedTaskIds.remove(taskId);
      } else {
        _completedTaskIds.add(taskId);
      }
    });
  }

  Future<void> _saveStudyPlan() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please sign in again before saving your plan.');
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final planRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('studyPlans')
          .doc('active');

      await planRef.set({
        'currentBand': widget.currentBand,
        'targetBand': widget.targetBand,
        'dailyStudyMinutes': widget.dailyStudyMinutes,
        'availableDays': widget.availableDays,
        'examDate': widget.examDate == null
            ? null
            : Timestamp.fromDate(widget.examDate!),
        'weakQuestionTypes': widget.weakQuestionTypes,
        'recentScores': widget.recentScores,
        'completionProgress': _completionProgress,
        'completedTaskIds': _completedTaskIds.toList(),
        'weeklyPlan': _weeklyPlan.map((day) => day.toMap()).toList(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('users').doc(user.uid).set({
        'activeStudyPlan': true,
        'studyPlanUpdatedAt': FieldValue.serverTimestamp(),
        'weeklyTaskCount': _totalTaskCount,
        'weeklyCompletedTaskCount': _completedCount,
        'profileCompleted': true,
        'diagnosticCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const IELTSMainNavigation()),
        (route) => false,
      );
    } catch (error, stackTrace) {
      debugPrint('Save study plan error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage('Study plan could not be saved: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: StudyPlanColors.surfaceLight,
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _weeklyPlan[_selectedDayIndex];

    return Scaffold(
      backgroundColor: StudyPlanColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _StudyPlanBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                    child: Column(
                      children: [
                        _buildPlanHero(),
                        const SizedBox(height: 17),
                        _buildAdaptiveInsight(),
                        const SizedBox(height: 18),
                        _buildDaySelector(),
                        const SizedBox(height: 16),
                        _SelectedDaySummary(day: selectedDay),
                        const SizedBox(height: 13),
                        ...selectedDay.tasks.map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _StudyTaskCard(
                              task: task,
                              completed: _completedTaskIds.contains(task.id),
                              onTap: () => _toggleTask(task.id),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildWeeklyOverview(),
                      ],
                    ),
                  ),
                ),
                _buildBottomAction(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 18, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              backgroundColor: StudyPlanColors.surface,
              foregroundColor: StudyPlanColors.mainText,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: StudyPlanColors.gradient,
            ),
            child: const Icon(
              Icons.route_rounded,
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
                  'Personalized Study Plan',
                  style: TextStyle(
                    color: StudyPlanColors.mainText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Adapted to your target and weak areas',
                  style: TextStyle(
                    color: StudyPlanColors.mutedText,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: StudyPlanColors.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: StudyPlanColors.cyan.withOpacity(0.17)),
            ),
            child: Text(
              '${(_completionProgress * 100).round()}%',
              style: const TextStyle(
                color: StudyPlanColors.cyan,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanHero() {
    final bandGap = (widget.targetBand - widget.currentBand).clamp(0.0, 9.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: LinearGradient(
          colors: [
            StudyPlanColors.blue.withOpacity(0.24),
            StudyPlanColors.cyan.withOpacity(0.10),
            StudyPlanColors.violet.withOpacity(0.17),
          ],
        ),
        border: Border.all(color: StudyPlanColors.cyan.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: StudyPlanColors.blue.withOpacity(0.12),
            blurRadius: 27,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _BandCircle(
                label: 'Current',
                value: widget.currentBand,
                accent: StudyPlanColors.cyan,
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        color: StudyPlanColors.success,
                        size: 25,
                      ),
                      SizedBox(height: 5),
                      Text(
                        'PERSONAL PATH',
                        style: TextStyle(
                          color: StudyPlanColors.mutedText,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _BandCircle(
                label: 'Target',
                value: widget.targetBand,
                accent: StudyPlanColors.violet,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  icon: Icons.schedule_rounded,
                  title: '${widget.dailyStudyMinutes} min',
                  subtitle: 'Daily study',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.calendar_view_week_rounded,
                  title: '${_weeklyPlan.length} days',
                  subtitle: 'Available weekly',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.track_changes_rounded,
                  title: bandGap.toStringAsFixed(1),
                  subtitle: 'Band gap',
                ),
              ),
            ],
          ),
          if (widget.examDate != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StudyPlanColors.background.withOpacity(0.38),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    color: StudyPlanColors.cyan,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'IELTS exam countdown',
                      style: TextStyle(
                        color: StudyPlanColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$_daysUntilExam days',
                    style: const TextStyle(
                      color: StudyPlanColors.mainText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdaptiveInsight() {
    final weakestSkill = _getWeakestSkill();
    final weakTopic = widget.weakQuestionTypes.isEmpty
        ? 'Core IELTS Strategy'
        : widget.weakQuestionTypes.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: StudyPlanColors.gradient,
            ),
            child: const Icon(
              Icons.psychology_alt_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Plan Insight',
                  style: TextStyle(
                    color: StudyPlanColors.mainText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your plan gives extra attention to $weakestSkill, especially $weakTopic, while maintaining balanced practice across all IELTS skills.',
                  style: const TextStyle(
                    color: StudyPlanColors.mutedText,
                    fontSize: 11.2,
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

  Widget _buildDaySelector() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _weeklyPlan.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = _weeklyPlan[index];
          final selected = _selectedDayIndex == index;
          final completed = day.tasks
              .where((task) => _completedTaskIds.contains(task.id))
              .length;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _selectedDayIndex = index);
              },
              borderRadius: BorderRadius.circular(17),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 82,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF14314A)
                      : StudyPlanColors.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected
                        ? StudyPlanColors.cyan.withOpacity(0.62)
                        : Colors.white.withOpacity(0.06),
                    width: selected ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _shortDay(day.day),
                      style: TextStyle(
                        color: selected
                            ? StudyPlanColors.cyan
                            : StudyPlanColors.mainText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$completed/${day.tasks.length} done',
                      style: const TextStyle(
                        color: StudyPlanColors.mutedText,
                        fontSize: 8.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyOverview() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Overview',
            style: TextStyle(
              color: StudyPlanColors.mainText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _OverviewItem(
                  value: '$_totalTaskCount',
                  label: 'Total tasks',
                  accent: StudyPlanColors.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewItem(
                  value: '$_completedCount',
                  label: 'Completed',
                  accent: StudyPlanColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewItem(
                  value:
                      '${_weeklyPlan.fold(0, (sum, day) => sum + day.totalMinutes)}',
                  label: 'Minutes',
                  accent: StudyPlanColors.violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: _completionProgress,
              minHeight: 8,
              backgroundColor: StudyPlanColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                StudyPlanColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 18),
      decoration: BoxDecoration(
        color: StudyPlanColors.background.withOpacity(0.97),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: _GradientButton(
        title: 'Save and Activate Plan',
        icon: Icons.check_circle_outline_rounded,
        isLoading: _isSaving,
        onPressed: _saveStudyPlan,
      ),
    );
  }

  String _shortDay(String day) {
    if (day.length <= 3) return day;
    return day.substring(0, 3);
  }
}

class StudyDayPlan {
  final String day;
  final int totalMinutes;
  final List<StudyTask> tasks;

  const StudyDayPlan({
    required this.day,
    required this.totalMinutes,
    required this.tasks,
  });

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'totalMinutes': totalMinutes,
      'tasks': tasks.map((task) => task.toMap()).toList(),
    };
  }
}

class StudyTask {
  final String id;
  final String title;
  final String subtitle;
  final StudyTaskType type;
  final int durationMinutes;
  final IconData icon;
  final Color accent;

  const StudyTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.durationMinutes,
    required this.icon,
    required this.accent,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'type': type.name,
      'durationMinutes': durationMinutes,
      'completed': false,
    };
  }
}

enum StudyTaskType {
  lesson,
  practice,
  vocabulary,
  quiz,
  speaking,
  writing,
  timed,
  review,
  aiCoach,
  mock,
}

class _SelectedDaySummary extends StatelessWidget {
  final StudyDayPlan day;

  const _SelectedDaySummary({required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            StudyPlanColors.blue.withOpacity(0.16),
            StudyPlanColors.cyan.withOpacity(0.08),
          ],
        ),
        border: Border.all(color: StudyPlanColors.cyan.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: StudyPlanColors.cyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: StudyPlanColors.cyan,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.day,
                  style: const TextStyle(
                    color: StudyPlanColors.mainText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.tasks.length} tasks • ${day.totalMinutes} minutes',
                  style: const TextStyle(
                    color: StudyPlanColors.mutedText,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.auto_awesome_rounded,
            color: StudyPlanColors.violet,
            size: 21,
          ),
        ],
      ),
    );
  }
}

class _StudyTaskCard extends StatelessWidget {
  final StudyTask task;
  final bool completed;
  final VoidCallback onTap;

  const _StudyTaskCard({
    required this.task,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: completed
                ? StudyPlanColors.success.withOpacity(0.10)
                : StudyPlanColors.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: completed
                  ? StudyPlanColors.success.withOpacity(0.32)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: task.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(task.icon, color: task.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: completed
                            ? StudyPlanColors.success
                            : StudyPlanColors.mainText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      task.subtitle,
                      style: const TextStyle(
                        color: StudyPlanColors.mutedText,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: task.accent,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${task.durationMinutes} min',
                          style: TextStyle(
                            color: task.accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _TaskTypeBadge(type: task.type),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed
                      ? StudyPlanColors.success
                      : Colors.transparent,
                  border: Border.all(
                    color: completed
                        ? StudyPlanColors.success
                        : StudyPlanColors.border,
                  ),
                ),
                child: completed
                    ? const Icon(
                        Icons.check_rounded,
                        color: StudyPlanColors.background,
                        size: 18,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskTypeBadge extends StatelessWidget {
  final StudyTaskType type;

  const _TaskTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: StudyPlanColors.surfaceLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _label(type),
        style: const TextStyle(
          color: StudyPlanColors.secondaryText,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _label(StudyTaskType type) {
    switch (type) {
      case StudyTaskType.lesson:
        return 'LESSON';
      case StudyTaskType.practice:
        return 'PRACTICE';
      case StudyTaskType.vocabulary:
        return 'VOCAB';
      case StudyTaskType.quiz:
        return 'QUIZ';
      case StudyTaskType.speaking:
        return 'SPEAKING';
      case StudyTaskType.writing:
        return 'WRITING';
      case StudyTaskType.timed:
        return 'TIMED';
      case StudyTaskType.review:
        return 'REVIEW';
      case StudyTaskType.aiCoach:
        return 'AI COACH';
      case StudyTaskType.mock:
        return 'MOCK';
    }
  }
}

class _BandCircle extends StatelessWidget {
  final String label;
  final double value;
  final Color accent;

  const _BandCircle({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.12),
            border: Border.all(color: accent.withOpacity(0.45), width: 2),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(0.15), blurRadius: 18),
            ],
          ),
          child: Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              color: accent,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            color: StudyPlanColors.mutedText,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MiniMetric({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: StudyPlanColors.background.withOpacity(0.35),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: StudyPlanColors.cyan, size: 18),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: StudyPlanColors.mainText,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: StudyPlanColors.mutedText,
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;

  const _OverviewItem({
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.09),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: StudyPlanColors.mutedText,
              fontSize: 8.8,
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
          gradient: StudyPlanColors.gradient,
          boxShadow: [
            BoxShadow(
              color: StudyPlanColors.blue.withOpacity(0.26),
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

class _StudyPlanBackground extends StatelessWidget {
  const _StudyPlanBackground();

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

class StudyPlanColors {
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

  static const gradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: StudyPlanColors.surface.withOpacity(0.92),
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
