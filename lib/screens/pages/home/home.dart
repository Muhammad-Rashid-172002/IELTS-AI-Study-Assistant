import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/screens/Full_Mock_Test/mock_test_setup_screen.dart';
import 'package:fyproject/screens/Vocabulary_Builder/VocabularyBuilder.dart';
import 'package:fyproject/screens/pages/Listening_Practice/ListeningPractice.dart';
import 'package:fyproject/screens/pages/Reading_Practice/ReadingPractice.dart';
import 'package:fyproject/screens/pages/Speaking_Practice/SpeakingPractice.dart';
import 'package:fyproject/screens/pages/Writing_Checker/WritingChecker.dart';
import 'package:fyproject/screens/pages/certificate/certificate_screen.dart';
import 'package:fyproject/screens/pages/registration/Auth_gateway_screen.dart';
import 'package:fyproject/screens/pages/Subscription/Subscription_screen.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  bool _activityRecorded = false;
  bool _certificateSyncStarted = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _SignedOutState();
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    if (!_activityRecorded) {
      _activityRecorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recordDailyActivity(userRef);
      });
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return _ErrorState(
            message: 'Profile data could not be loaded.',
            onRetry: () => setState(() {}),
          );
        }

        if (!userSnapshot.hasData) {
          return const _HomeLoadingState();
        }

        final userData = userSnapshot.data!.data() ?? <String, dynamic>{};

        if (!_certificateSyncStarted) {
          _certificateSyncStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncAchievementCertificates();
          });
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: userRef.collection('diagnosticResults').snapshots(),
          builder: (context, diagnosticSnapshot) {
            final diagnosticData = _latestDocumentData(
              diagnosticSnapshot.data?.docs ?? const [],
            );

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: userRef
                  .collection('studyPlans')
                  .doc('active')
                  .snapshots(),
              builder: (context, planSnapshot) {
                final planData =
                    planSnapshot.data?.data() ?? <String, dynamic>{};

                return _LiveSkillResults(
                  userRef: userRef,
                  builder: (latestResults) {
                    final model = HomeDashboardModel.fromFirestore(
                      authUser: user,
                      userData: userData,
                      diagnosticData: diagnosticData,
                      planData: planData,
                      latestResults: latestResults,
                    );

                    return _HomeDashboardView(model: model, userRef: userRef);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _syncAchievementCertificates() async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('syncAchievementCertificates');

      await callable.call();
    } catch (_) {
      // Certificate synchronization must never block the Home dashboard.
    }
  }

  Future<void> _recordDailyActivity(
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data() ?? <String, dynamic>{};

        final now = DateTime.now();
        final today = _dateKey(now);
        final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
        final lastActive = (data['lastActiveDate'] ?? '').toString();

        if (lastActive == today) return;

        final oldStreak = _asInt(data['currentStreak'] ?? data['streak']);
        final newStreak = lastActive == yesterday ? oldStreak + 1 : 1;
        final oldLongest = _asInt(data['longestStreak']);
        final oldXp = _asInt(data['xpPoints'] ?? data['xp']);

        transaction.set(userRef, {
          'lastActiveDate': today,
          'currentStreak': newStreak,
          'streak': newStreak,
          'longestStreak': math.max(oldLongest, newStreak),
          'xpPoints': oldXp + 10,
          'activityDates': FieldValue.arrayUnion([today]),
          'lastDashboardVisitAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // Dashboard must remain usable even if activity tracking fails.
    }
  }
}

class _LiveSkillResults extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> userRef;
  final Widget Function(Map<String, Map<String, dynamic>>) builder;

  const _LiveSkillResults({required this.userRef, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: userRef.collection('listening_results').snapshots(),
      builder: (context, listeningSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: userRef.collection('reading_results').snapshots(),
          builder: (context, readingSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: userRef.collection('writing_results').snapshots(),
              builder: (context, writingSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: userRef.collection('speaking_results').snapshots(),
                  builder: (context, speakingSnapshot) {
                    return builder({
                      'listening': _latestDocumentData(
                        listeningSnapshot.data?.docs ?? const [],
                      ),
                      'reading': _latestDocumentData(
                        readingSnapshot.data?.docs ?? const [],
                      ),
                      'writing': _latestDocumentData(
                        writingSnapshot.data?.docs ?? const [],
                      ),
                      'speaking': _latestDocumentData(
                        speakingSnapshot.data?.docs ?? const [],
                      ),
                    });
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _HomeDashboardView extends StatelessWidget {
  final HomeDashboardModel model;
  final DocumentReference<Map<String, dynamic>> userRef;

  const _HomeDashboardView({required this.model, required this.userRef});

  Future<void> _toggleTask(BuildContext context, HomeTask task) async {
    final planRef = userRef.collection('studyPlans').doc('active');

    try {
      if (task.completed) {
        await planRef.set({
          'completedTaskIds': FieldValue.arrayRemove([task.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await planRef.set({
          'completedTaskIds': FieldValue.arrayUnion([task.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'Task status could not be updated.');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _C.surfaceLight,
          content: Text(message),
        ),
      );
  }

  void _openQuickAction(BuildContext context, String action) {
    switch (action) {
      case 'Full Mock Test':
        _push(context, const MockTestSetupScreen());
        return;
      case 'Writing Checker':
        _push(context, const WritingChecker());
        return;
      case 'Speaking AI':
        _push(context, const SpeakingPractice());
        return;
      case 'Vocabulary':
      case 'Daily Quiz':
        _push(context, const VocabularyScreen());
        return;
      case 'Weakness Practice':
        _openSkillPractice(context, model.weakestSkill);
        return;
      case 'Certificates':
        _push(context, const CertificatesScreen());
        return;
      default:
        _showMessage(context, '$action is not available.');
    }
  }

  void _openTask(BuildContext context, HomeTask task) {
    final type = task.type.toLowerCase();

    if (type.contains('mock')) {
      _push(context, const MockTestSetupScreen());
    } else if (type.contains('vocab') || type.contains('quiz')) {
      _push(context, const VocabularyScreen());
    } else if (type.contains('listening')) {
      _push(context, const ListeningScreen());
    } else if (type.contains('reading')) {
      _push(context, const ReadingScreen());
    } else if (type.contains('writing')) {
      _push(context, const WritingChecker());
    } else if (type.contains('speaking')) {
      _push(context, const SpeakingPractice());
    } else {
      _showMessage(context, '${task.title} ka screen configure nahi hai.');
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openSkillPractice(BuildContext context, String skill) {
    late final Widget screen;

    switch (skill.toLowerCase()) {
      case 'listening':
        screen = const ListeningScreen();
        break;

      case 'reading':
        screen = const ReadingScreen();
        break;

      case 'writing':
        screen = const WritingChecker();
        break;

      case 'speaking':
        screen = const SpeakingPractice();
        break;

      default:
        _showMessage(context, '$skill practice screen is not available.');
        return;
    }

    _push(context, screen);
  }

  void _openAIInsightDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.72),
      builder: (sheetContext) {
        return _AICoachInsightSheet(
          model: model,
          onPracticeWeakest: () {
            Navigator.of(sheetContext).pop();
            _openSkillPractice(context, model.weakestSkill);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: _C.cyan,
              backgroundColor: _C.surface,
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 450));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(model: model),
                    const SizedBox(height: 20),
                    _ReadinessCard(model: model),
                    const SizedBox(height: 20),
                    _Title(
                      'Today’s Study Plan',
                      model.todayTasks.isEmpty
                          ? 'No tasks scheduled for today'
                          : '${model.todayTasks.length} personalized tasks for today',
                    ),
                    const SizedBox(height: 12),
                    _TodayPlan(
                      tasks: model.todayTasks,
                      totalMinutes: model.todayTotalMinutes,
                      onToggleTask: (task) => _toggleTask(context, task),
                      onContinue: model.todayTasks.isEmpty
                          ? null
                          : () {
                              final firstPending = model.todayTasks
                                  .where((task) => !task.completed)
                                  .firstOrNull;

                              if (firstPending == null) {
                                _showMessage(
                                  context,
                                  'Aaj ke tamam tasks complete ho chuke hain.',
                                );
                              } else {
                                _openTask(context, firstPending);
                              }
                            },
                    ),
                    const SizedBox(height: 20),
                    const _Title(
                      'Four Skills Overview',
                      'Real diagnostic and recent practice performance',
                    ),
                    const SizedBox(height: 12),
                    _Skills(
                      skills: model.skills,
                      onPractice: (skill) => _openSkillPractice(context, skill),
                    ),
                    const SizedBox(height: 20),
                    const _Title(
                      'Quick Actions',
                      'Open your most useful IELTS tools',
                    ),
                    const SizedBox(height: 12),
                    _QuickActions(
                      onTap: (action) => _openQuickAction(context, action),
                    ),
                    const SizedBox(height: 20),
                    _AIInsight(
                      text: model.aiInsight,
                      isPremium: model.isPremium,
                      onTap: () => _openAIInsightDialog(context),
                    ),
                    const SizedBox(height: 20),
                    _Streak(model: model),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeDashboardModel {
  final String userName;
  final String? profileImageUrl;
  final bool isPremium;
  final int examCountdownDays;
  final double currentBand;
  final double targetBand;
  final int readinessPercent;
  final int weeklyProgressPercent;
  final int completedSkillCount;
  final List<String> missingSkills;
  final int currentStreak;
  final int longestStreak;
  final int xpPoints;
  final List<bool> activeWeekDays;
  final List<HomeTask> todayTasks;
  final int todayTotalMinutes;
  final List<SkillOverview> skills;
  final String aiInsight;
  final String weakestSkill;

  const HomeDashboardModel({
    required this.userName,
    required this.profileImageUrl,
    required this.isPremium,
    required this.examCountdownDays,
    required this.currentBand,
    required this.targetBand,
    required this.readinessPercent,
    required this.weeklyProgressPercent,
    required this.completedSkillCount,
    required this.missingSkills,
    required this.currentStreak,
    required this.longestStreak,
    required this.xpPoints,
    required this.activeWeekDays,
    required this.todayTasks,
    required this.todayTotalMinutes,
    required this.skills,
    required this.aiInsight,
    required this.weakestSkill,
  });

  factory HomeDashboardModel.fromFirestore({
    required User authUser,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> diagnosticData,
    required Map<String, dynamic> planData,
    required Map<String, Map<String, dynamic>> latestResults,
  }) {
    final skillBands = _asMap(diagnosticData['skillBands']);
    final targetBands = _asMap(userData['targetBands']);

    final targetBand = _asDouble(
      targetBands['overall'] ?? userData['targetBand'],
      fallback: 7,
    );

    final skillValues = <String, double>{
      'Listening': _latestBand(
        latestResults['listening'],
        fallback: _asDouble(
          skillBands['listening'] ?? userData['listeningBand'],
        ),
      ),
      'Reading': _latestBand(
        latestResults['reading'],
        fallback: _asDouble(skillBands['reading'] ?? userData['readingBand']),
      ),
      'Writing': _latestBand(
        latestResults['writing'],
        fallback: _asDouble(skillBands['writing'] ?? userData['writingBand']),
      ),
      'Speaking': _latestBand(
        latestResults['speaking'],
        fallback: _asDouble(skillBands['speaking'] ?? userData['speakingBand']),
      ),
    };

    final completedSkillEntries = skillValues.entries
        .where((entry) => entry.value > 0 && entry.value <= 9)
        .toList();

    final completedSkillCount = completedSkillEntries.length;

    final missingSkills = skillValues.entries
        .where((entry) => entry.value <= 0 || entry.value > 9)
        .map((entry) => entry.key)
        .toList();

    final liveOverallBand = completedSkillEntries.isEmpty
        ? 0.0
        : _roundToNearestHalf(
            completedSkillEntries
                    .map((entry) => entry.value)
                    .reduce((a, b) => a + b) /
                completedSkillEntries.length,
          );

    final currentBand = liveOverallBand > 0
        ? liveOverallBand
        : _asDouble(
            userData['estimatedBand'] ??
                userData['overallBand'] ??
                userData['currentBand'] ??
                diagnosticData['overallBand'],
            fallback: 0,
          );

    final today = DateTime.now();
    final todayName = _dayName(today.weekday);
    final weeklyPlan = _asList(planData['weeklyPlan']);
    final completedTaskIds = _asStringSet(planData['completedTaskIds']);

    Map<String, dynamic>? todayPlan;

    for (final rawDay in weeklyPlan) {
      final dayMap = _asMap(rawDay);

      if ((dayMap['day'] ?? '').toString().toLowerCase() ==
          todayName.toLowerCase()) {
        todayPlan = dayMap;
        break;
      }
    }

    final rawTasks = _asList(todayPlan?['tasks']);
    final todayTasks = rawTasks.map((rawTask) {
      final task = _asMap(rawTask);
      final id = (task['id'] ?? task['title'] ?? '').toString();

      return HomeTask(
        id: id,
        title: (task['title'] ?? 'IELTS Study Task').toString(),
        subtitle: (task['subtitle'] ?? '').toString(),
        durationMinutes: _asInt(task['durationMinutes'], fallback: 10),
        type: (task['type'] ?? 'practice').toString(),
        completed: completedTaskIds.contains(id) || task['completed'] == true,
      );
    }).toList();

    final todayTotalMinutes = todayTasks.fold<int>(
      0,
      (sum, task) => sum + task.durationMinutes,
    );

    final completedToday = todayTasks.where((task) => task.completed).length;

    final calculatedWeekly = _calculateWeeklyProgress(
      weeklyPlan,
      completedTaskIds,
    );

    final weeklyProgress = _asInt(
      userData['weeklyProgressPercent'],
      fallback: calculatedWeekly,
    ).clamp(0, 100);

    final readiness = _calculateReadiness(
      currentBand: currentBand,
      targetBand: targetBand,
      weeklyProgress: weeklyProgress,
      completedSkillCount: completedSkillCount,
    ).clamp(0, 100);

    final weakest = _weakestSkill(skillValues);
    final weakQuestionTypes = _asStringList(userData['weakQuestionTypes']);
    final weakestTopic = weakQuestionTypes.isNotEmpty
        ? weakQuestionTypes.first
        : _defaultWeakTopic(weakest);

    final skillList = skillValues.entries.map((entry) {
      return SkillOverview(
        name: entry.key,
        band: entry.value,
        weeklyTrend: _skillTrend(userData, entry.key),
        pendingTask: _findPendingSkillTask(
          todayTasks,
          entry.key,
          fallback: _defaultPendingTask(entry.key),
        ),
      );
    }).toList();

    return HomeDashboardModel(
      userName: _firstNonEmpty([
        userData['fullName'],
        userData['name'],
        authUser.displayName,
        authUser.email?.split('@').first,
        'IELTS Learner',
      ]),
      profileImageUrl: _nullableString(
        userData['photoUrl'] ??
            userData['profileImageUrl'] ??
            authUser.photoURL,
      ),
      isPremium: _isHomePremiumUser(userData),
      examCountdownDays: _examCountdown(
        userData['exactExamDate'] ?? userData['examDate'],
      ),
      currentBand: currentBand,
      targetBand: targetBand,
      readinessPercent: readiness,
      weeklyProgressPercent: weeklyProgress,
      completedSkillCount: completedSkillCount,
      missingSkills: List<String>.unmodifiable(missingSkills),
      currentStreak: _asInt(userData['currentStreak'] ?? userData['streak']),
      longestStreak: _asInt(userData['longestStreak']),
      xpPoints: _asInt(userData['xpPoints'] ?? userData['xp']),
      activeWeekDays: _activeWeekDays(
        userData['activityDates'] ?? userData['weeklyActivity'],
        completedToday: completedToday,
      ),
      todayTasks: todayTasks,
      todayTotalMinutes: todayTotalMinutes,
      skills: skillList,
      weakestSkill: weakest,
      aiInsight: missingSkills.isNotEmpty
          ? 'Your current provisional band is based on '
                '$completedSkillCount completed '
                '${completedSkillCount == 1 ? 'skill' : 'skills'}. '
                'Complete ${missingSkills.join(' and ')} to unlock a full '
                'estimated IELTS overall band.'
          : 'Your $weakest performance needs the most attention. '
                '$weakestTopic is currently the main focus area. '
                'Complete today’s targeted task to improve your score.',
    );
  }
}

class HomeTask {
  final String id;
  final String title;
  final String subtitle;
  final int durationMinutes;
  final String type;
  final bool completed;

  const HomeTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.durationMinutes,
    required this.type,
    required this.completed,
  });

  IconData get icon {
    switch (type.toLowerCase()) {
      case 'listening':
        return Icons.headphones_rounded;
      case 'reading':
        return Icons.menu_book_rounded;
      case 'writing':
        return Icons.edit_note_rounded;
      case 'speaking':
        return Icons.mic_rounded;
      case 'vocabulary':
      case 'vocab':
        return Icons.auto_stories_rounded;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'mock':
        return Icons.timer_outlined;
      case 'review':
        return Icons.fact_check_outlined;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color get color {
    switch (type.toLowerCase()) {
      case 'listening':
        return const Color(0xFF22D3EE);
      case 'reading':
        return const Color(0xFF60A5FA);
      case 'writing':
        return const Color(0xFFA78BFA);
      case 'speaking':
        return const Color(0xFF34D399);
      case 'vocabulary':
      case 'vocab':
        return const Color(0xFF8B5CF6);
      case 'quiz':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF2563EB);
    }
  }
}

class SkillOverview {
  final String name;
  final double band;
  final double weeklyTrend;
  final String pendingTask;

  const SkillOverview({
    required this.name,
    required this.band,
    required this.weeklyTrend,
    required this.pendingTask,
  });

  IconData get icon {
    switch (name.toLowerCase()) {
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

  Color get color {
    switch (name.toLowerCase()) {
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
}

class _Header extends StatelessWidget {
  final HomeDashboardModel model;

  const _Header({required this.model});

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting();

    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _C.gradient,
            border: Border.all(color: Colors.white.withOpacity(.14), width: 2),
          ),
          child: ClipOval(
            child: model.profileImageUrl == null
                ? const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 28,
                  )
                : Image.network(
                    model.profileImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, ${model.userName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    color: _C.cyan,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      model.examCountdownDays > 0
                          ? '${model.examCountdownDays} days until your IELTS exam'
                          : 'No IELTS exam date selected',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (model.isPremium)
          Container(
            margin: const EdgeInsets.only(right: 7),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
              ),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
        IconButton(
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: _C.surface,
            foregroundColor: _C.text,
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _ReadinessCard extends StatelessWidget {
  final HomeDashboardModel model;

  const _ReadinessCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final hasAnyResult = model.completedSkillCount > 0;
    final hasCompleteOverallBand = model.completedSkillCount == 4;
    final missingText = model.missingSkills.join(' and ');

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            _C.blue.withOpacity(.26),
            _C.cyan.withOpacity(.12),
            _C.violet.withOpacity(.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _C.cyan.withOpacity(.2)),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withOpacity(.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: model.readinessPercent / 100,
                        strokeWidth: 9,
                        backgroundColor: _C.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasCompleteOverallBand ? _C.green : _C.cyan,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${model.readinessPercent}%',
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          hasCompleteOverallBand ? 'READY' : 'PROVISIONAL',
                          style: TextStyle(
                            color: hasCompleteOverallBand ? _C.green : _C.cyan,
                            fontSize: 7.2,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .35,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCompleteOverallBand
                          ? 'Exam Readiness'
                          : 'Provisional Readiness',
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      !hasAnyResult
                          ? 'Complete your first IELTS skill assessment to '
                                'generate an estimated band and readiness score.'
                          : hasCompleteOverallBand
                          ? 'Based on all four IELTS skills, weekly '
                                'activity and target-band progress.'
                          : 'Estimated from ${model.completedSkillCount} '
                                'completed ${model.completedSkillCount == 1 ? 'skill' : 'skills'}. '
                                'Complete $missingText for a full overall band.',
                      style: const TextStyle(
                        color: _C.secondary,
                        fontSize: 10.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: hasCompleteOverallBand
                      ? 'Overall Band'
                      : 'Provisional Band',
                  value: hasAnyResult
                      ? model.currentBand.toStringAsFixed(1)
                      : '—',
                  color: _C.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Target Band',
                  value: model.targetBand.toStringAsFixed(1),
                  color: _C.violet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Skills Done',
                  value: '${model.completedSkillCount}/4',
                  color: _C.green,
                ),
              ),
            ],
          ),
          if (!hasCompleteOverallBand) ...[
            const SizedBox(height: 15),
            _HomeMissingSkillsNotice(
              missingSkills: model.missingSkills,
              completedSkillCount: model.completedSkillCount,
            ),
          ],
          const SizedBox(height: 15),
          Row(
            children: [
              const Text(
                'Weekly progress',
                style: TextStyle(color: _C.muted, fontSize: 10.5),
              ),
              const Spacer(),
              Text(
                '${model.weeklyProgressPercent}%',
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: model.weeklyProgressPercent / 100,
              minHeight: 7,
              backgroundColor: _C.border,
              valueColor: const AlwaysStoppedAnimation<Color>(_C.green),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMissingSkillsNotice extends StatelessWidget {
  final List<String> missingSkills;
  final int completedSkillCount;

  const _HomeMissingSkillsNotice({
    required this.missingSkills,
    required this.completedSkillCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasStarted = completedSkillCount > 0;
    final title = hasStarted
        ? 'Complete ${missingSkills.join(' and ')}'
        : 'Complete your IELTS assessments';

    final description = hasStarted
        ? 'Your current band is calculated from completed skills only. '
              'Finish the missing ${missingSkills.length == 1 ? 'module' : 'modules'} '
              'to unlock a complete estimated overall band.'
        : 'Start with any IELTS skill. Your provisional band will update '
              'as each module is completed.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.orange.withOpacity(.12), _C.violet.withOpacity(.08)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.orange.withOpacity(.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _C.orange.withOpacity(.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_late_outlined,
              color: _C.orange,
              size: 20,
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
                    color: _C.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: _C.secondary,
                    fontSize: 9.5,
                    height: 1.45,
                  ),
                ),
                if (missingSkills.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: missingSkills.map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _C.bg.withOpacity(.42),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: _C.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_skillIcon(skill), color: _C.orange, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              skill,
                              style: const TextStyle(
                                color: _C.secondary,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _skillIcon(String skill) {
    return switch (skill.toLowerCase()) {
      'listening' => Icons.headphones_rounded,
      'reading' => Icons.menu_book_rounded,
      'writing' => Icons.edit_note_rounded,
      _ => Icons.mic_rounded,
    };
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
      decoration: BoxDecoration(
        color: _C.bg.withOpacity(.34),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.muted, fontSize: 8.4),
          ),
        ],
      ),
    );
  }
}

class _TodayPlan extends StatelessWidget {
  final List<HomeTask> tasks;
  final int totalMinutes;
  final ValueChanged<HomeTask> onToggleTask;
  final VoidCallback? onContinue;

  const _TodayPlan({
    required this.tasks,
    required this.totalMinutes,
    required this.onToggleTask,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.completed).length;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _card(),
      child: tasks.isEmpty
          ? const _EmptyTodayPlan()
          : Column(
              children: [
                Row(
                  children: [
                    const _SquareIcon(icon: Icons.checklist_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tasks.length} Daily Tasks',
                            style: const TextStyle(
                              color: _C.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalMinutes minutes total',
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$completed / ${tasks.length}',
                      style: const TextStyle(
                        color: _C.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                ...tasks
                    .take(4)
                    .map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onToggleTask(task),
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: task.completed
                                    ? _C.green.withOpacity(.08)
                                    : _C.bg.withOpacity(.35),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: task.completed
                                      ? _C.green.withOpacity(.22)
                                      : Colors.white.withOpacity(.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: task.color.withOpacity(.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      task.icon,
                                      color: task.color,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: task.completed
                                                ? _C.green
                                                : _C.text,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            decoration: task.completed
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        if (task.subtitle.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            task.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: _C.muted,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${task.durationMinutes} min',
                                    style: const TextStyle(
                                      color: _C.muted,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    task.completed
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: task.completed
                                        ? _C.green
                                        : _C.border,
                                    size: 19,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: _C.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(_C.cyan),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Continue Today’s Plan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyTodayPlan extends StatelessWidget {
  const _EmptyTodayPlan();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, color: _C.cyan, size: 38),
          SizedBox(height: 11),
          Text(
            'No study tasks for today',
            style: TextStyle(
              color: _C.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Activate a personalized study plan or add today to your available study days.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.muted, fontSize: 10.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Skills extends StatelessWidget {
  final List<SkillOverview> skills;
  final ValueChanged<String> onPractice;

  const _Skills({required this.skills, required this.onPractice});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: skills.map((skill) {
            return SizedBox(
              width: cardWidth,
              child: _SkillCard(
                skill: skill,
                onPractice: () => onPractice(skill.name),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SkillCard extends StatelessWidget {
  final SkillOverview skill;
  final VoidCallback onPractice;

  const _SkillCard({required this.skill, required this.onPractice});

  @override
  Widget build(BuildContext context) {
    final trendText = skill.weeklyTrend >= 0
        ? '+${skill.weeklyTrend.toStringAsFixed(1)}'
        : skill.weeklyTrend.toStringAsFixed(1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPractice,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 188),
          padding: const EdgeInsets.all(13),
          decoration: _card(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: skill.color.withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(skill.icon, color: skill.color, size: 19),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (skill.weeklyTrend >= 0 ? _C.green : Colors.redAccent)
                              .withOpacity(.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      trendText,
                      style: TextStyle(
                        color: skill.weeklyTrend >= 0
                            ? _C.green
                            : Colors.redAccent,
                        fontSize: 8.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                skill.band > 0 ? skill.band.toStringAsFixed(1) : '—',
                style: TextStyle(
                  color: skill.color,
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                skill.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                skill.pendingTask,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.muted,
                  fontSize: 9,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: OutlinedButton(
                  onPressed: onPractice,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: skill.color,
                    side: BorderSide(color: skill.color.withOpacity(.28)),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Text(
                    'Practice',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
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

class _QuickActions extends StatelessWidget {
  final ValueChanged<String> onTap;

  const _QuickActions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const actions = [
      (
        'Full Mock Test',
        'Complete exam simulation',
        Icons.timer_outlined,
        Color(0xFF2563EB),
      ),
      (
        'Writing Checker',
        'Get an estimated writing band',
        Icons.edit_note_rounded,
        Color(0xFF8B5CF6),
      ),
      (
        'Speaking AI',
        'Record and evaluate speaking',
        Icons.record_voice_over_rounded,
        Color(0xFF34D399),
      ),
      (
        'Vocabulary',
        'Flashcards and daily words',
        Icons.auto_stories_rounded,
        Color(0xFF22D3EE),
      ),
      (
        'Weakness Practice',
        'Practise your lowest skill',
        Icons.center_focus_strong_rounded,
        Color(0xFFF97316),
      ),
      (
        'Certificates',
        'View verified achievements',
        Icons.workspace_premium_outlined,
        Color(0xFF22C55E),
      ),
      (
        'Daily Quiz',
        'Quick vocabulary challenge',
        Icons.quiz_outlined,
        Color(0xFFF59E0B),
      ),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 11,
        crossAxisSpacing: 11,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(action.$1),
            borderRadius: BorderRadius.circular(19),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: _card(),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: action.$4.withOpacity(.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(action.$3, color: action.$4, size: 21),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          action.$2,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 8.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: action.$4,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AIInsight extends StatelessWidget {
  final String text;
  final bool isPremium;
  final VoidCallback onTap;

  const _AIInsight({
    required this.text,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _C.blue.withOpacity(.22),
                _C.cyan.withOpacity(.11),
                _C.violet.withOpacity(.17),
              ],
            ),
            border: Border.all(color: _C.cyan.withOpacity(.20)),
            boxShadow: [
              BoxShadow(
                color: _C.cyan.withOpacity(.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: _C.gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _C.cyan.withOpacity(.18), blurRadius: 18),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isPremium
                                ? 'Advanced AI Coach Insight'
                                : 'AI Coach Insight',
                            style: const TextStyle(
                              color: _C.text,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (isPremium ? _C.orange : _C.green)
                                .withOpacity(.10),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: (isPremium ? _C.orange : _C.green)
                                  .withOpacity(.20),
                            ),
                          ),
                          child: Text(
                            isPremium ? 'PREMIUM' : 'BASIC',
                            style: TextStyle(
                              color: isPremium ? _C.orange : _C.green,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.secondary,
                        fontSize: 11.2,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Text(
                          isPremium
                              ? 'View advanced coaching report'
                              : 'View basic coaching insight',
                          style: const TextStyle(
                            color: _C.cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: _C.cyan,
                          size: 16,
                        ),
                      ],
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

class _AICoachInsightSheet extends StatelessWidget {
  final HomeDashboardModel model;
  final VoidCallback onPracticeWeakest;

  const _AICoachInsightSheet({
    required this.model,
    required this.onPracticeWeakest,
  });

  @override
  Widget build(BuildContext context) {
    final completedSkills = model.skills
        .where((skill) => skill.band > 0 && skill.band <= 9)
        .toList();

    final sortedSkills = [...completedSkills]
      ..sort((a, b) => b.band.compareTo(a.band));

    final strongest = sortedSkills.isEmpty ? null : sortedSkills.first;
    final weakest = sortedSkills.isEmpty ? null : sortedSkills.last;

    final gap = model.currentBand > 0
        ? math.max(0.0, model.targetBand - model.currentBand)
        : model.targetBand;

    final pendingTasks =
        model.todayTasks.where((task) => !task.completed).toList();
    final completedTasks =
        model.todayTasks.where((task) => task.completed).length;

    final priorityText = model.completedSkillCount == 0
        ? 'Complete your first skill assessment so your coach can establish a real performance baseline.'
        : model.completedSkillCount < 4
            ? 'Complete ${model.missingSkills.join(' and ')} next. Your overall band is still provisional until all four skills have real results.'
            : '${model.weakestSkill} is currently your lowest-performing skill. Prioritize its targeted practice before adding extra volume elsewhere.';

    final basicPriorityText = model.completedSkillCount == 0
        ? 'Start with one IELTS skill assessment to establish your learning baseline.'
        : model.completedSkillCount < 4
            ? 'Complete your remaining IELTS skill assessments to improve the accuracy of your overall estimate.'
            : 'Focus your next practice session on ${model.weakestSkill}, your current lowest-scoring skill.';

    final nextAction = pendingTasks.isNotEmpty
        ? 'Next planned task: ${pendingTasks.first.title} (${pendingTasks.first.durationMinutes} min).'
        : model.completedSkillCount > 0
            ? 'Open ${model.weakestSkill} practice and complete one focused session.'
            : 'Complete one Listening, Reading, Writing or Speaking assessment.';

    return DraggableScrollableSheet(
      initialChildSize: .88,
      minChildSize: .64,
      maxChildSize: .96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _C.bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: (model.isPremium ? _C.orange : _C.cyan)
                  .withOpacity(.18),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 30,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _AIInsightBackground()),
              CustomScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.16),
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  gradient: model.isPremium
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFFF59E0B),
                                            Color(0xFFF97316),
                                          ],
                                        )
                                      : _C.gradient,
                                  borderRadius: BorderRadius.circular(19),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (model.isPremium
                                              ? _C.orange
                                              : _C.cyan)
                                          .withOpacity(.18),
                                      blurRadius: 22,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  model.isPremium
                                      ? Icons.workspace_premium_rounded
                                      : Icons.psychology_alt_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      model.isPremium
                                          ? 'Advanced AI Coach Report'
                                          : 'AI Coach Basic Insight',
                                      style: const TextStyle(
                                        color: _C.text,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -.5,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      model.isPremium
                                          ? 'Premium coaching built from your live IELTS results, skill trends, study-plan progress and activity.'
                                          : 'A basic coaching snapshot built from your current IELTS results and study progress.',
                                      style: const TextStyle(
                                        color: _C.secondary,
                                        fontSize: 10.5,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _CoachTierBadge(
                                      premium: model.isPremium,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                style: IconButton.styleFrom(
                                  backgroundColor: _C.surface,
                                  foregroundColor: _C.text,
                                ),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Both tiers get a real performance summary.
                          _CoachHeroSummary(
                            currentBand: model.currentBand,
                            targetBand: model.targetBand,
                            readiness: model.readinessPercent,
                            completedSkills: model.completedSkillCount,
                          ),
                          const SizedBox(height: 18),
                          const _CoachSectionTitle(
                            icon: Icons.auto_awesome_rounded,
                            title: 'Coach Summary',
                          ),
                          const SizedBox(height: 10),
                          _CoachTextCard(
                            text: model.aiInsight,
                            accent: _C.cyan,
                          ),
                          const SizedBox(height: 18),

                          if (!model.isPremium) ...[
                            // FREE / BASIC EXPERIENCE
                            const _CoachSectionTitle(
                              icon: Icons.center_focus_strong_rounded,
                              title: 'Basic Priority',
                            ),
                            const SizedBox(height: 10),
                            _CoachPriorityCard(
                              title: model.completedSkillCount < 4
                                  ? 'Build your baseline'
                                  : 'Your next focus',
                              description: basicPriorityText,
                              icon: model.completedSkillCount < 4
                                  ? Icons.fact_check_outlined
                                  : _coachSkillIcon(model.weakestSkill),
                            ),
                            const SizedBox(height: 18),
                            const _CoachSectionTitle(
                              icon: Icons.insights_outlined,
                              title: 'Basic Snapshot',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _CoachMetricCard(
                                    label: 'Band',
                                    value: model.currentBand > 0
                                        ? model.currentBand.toStringAsFixed(1)
                                        : '—',
                                    accent: _C.cyan,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: _CoachMetricCard(
                                    label: 'Readiness',
                                    value: '${model.readinessPercent}%',
                                    accent: _C.green,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: _CoachMetricCard(
                                    label: 'Skills',
                                    value: '${model.completedSkillCount}/4',
                                    accent: _C.violet,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _PremiumCoachLockedCard(
                              onUpgrade: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SubscriptionScreen(),
                                    settings: const RouteSettings(
                                      name: '/premium',
                                      arguments: {
                                        'source': 'ai_coach_insight',
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            const _CoachSectionTitle(
                              icon: Icons.route_rounded,
                              title: 'Recommended Next Step',
                            ),
                            const SizedBox(height: 10),
                            _CoachTextCard(
                              text: nextAction,
                              accent: _C.green,
                            ),
                          ] else ...[
                            // PREMIUM / ADVANCED EXPERIENCE
                            const _CoachSectionTitle(
                              icon: Icons.analytics_outlined,
                              title: 'Advanced Performance Snapshot',
                            ),
                            const SizedBox(height: 10),
                            _CoachSkillGrid(skills: model.skills),
                            const SizedBox(height: 18),
                            const _CoachSectionTitle(
                              icon: Icons.center_focus_strong_rounded,
                              title: 'Priority Focus',
                            ),
                            const SizedBox(height: 10),
                            _CoachPriorityCard(
                              title: model.completedSkillCount < 4
                                  ? 'Complete your baseline'
                                  : '${model.weakestSkill} needs attention',
                              description: priorityText,
                              icon: model.completedSkillCount < 4
                                  ? Icons.fact_check_outlined
                                  : _coachSkillIcon(model.weakestSkill),
                            ),
                            const SizedBox(height: 18),
                            const _CoachSectionTitle(
                              icon: Icons.compare_arrows_rounded,
                              title: 'Advanced Band Analysis',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _CoachMetricCard(
                                    label: 'Current',
                                    value: model.currentBand > 0
                                        ? model.currentBand.toStringAsFixed(1)
                                        : '—',
                                    accent: _C.cyan,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: _CoachMetricCard(
                                    label: 'Target',
                                    value:
                                        model.targetBand.toStringAsFixed(1),
                                    accent: _C.violet,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: _CoachMetricCard(
                                    label: 'Gap',
                                    value: model.currentBand > 0
                                        ? gap.toStringAsFixed(1)
                                        : '—',
                                    accent: _C.orange,
                                  ),
                                ),
                              ],
                            ),
                            if (strongest != null || weakest != null) ...[
                              const SizedBox(height: 11),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: _coachCardDecoration(),
                                child: Column(
                                  children: [
                                    if (strongest != null)
                                      _CoachDetailRow(
                                        icon: Icons.trending_up_rounded,
                                        label: 'Strongest skill',
                                        value:
                                            '${strongest.name} • ${strongest.band.toStringAsFixed(1)}',
                                        color: _C.green,
                                      ),
                                    if (strongest != null && weakest != null)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: Divider(
                                          height: 1,
                                          color: _C.border,
                                        ),
                                      ),
                                    if (weakest != null)
                                      _CoachDetailRow(
                                        icon: Icons.trending_down_rounded,
                                        label: 'Lowest skill',
                                        value:
                                            '${weakest.name} • ${weakest.band.toStringAsFixed(1)}',
                                        color: _C.orange,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            const _CoachSectionTitle(
                              icon: Icons.calendar_today_outlined,
                              title: 'Today’s Execution Analysis',
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: _coachCardDecoration(),
                              child: Column(
                                children: [
                                  _CoachDetailRow(
                                    icon:
                                        Icons.check_circle_outline_rounded,
                                    label: 'Tasks completed',
                                    value:
                                        '$completedTasks/${model.todayTasks.length}',
                                    color: _C.green,
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 10),
                                    child: Divider(
                                      height: 1,
                                      color: _C.border,
                                    ),
                                  ),
                                  _CoachDetailRow(
                                    icon: Icons.timer_outlined,
                                    label: 'Planned study time',
                                    value: '${model.todayTotalMinutes} min',
                                    color: _C.cyan,
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 10),
                                    child: Divider(
                                      height: 1,
                                      color: _C.border,
                                    ),
                                  ),
                                  _CoachDetailRow(
                                    icon:
                                        Icons.local_fire_department_rounded,
                                    label: 'Current streak',
                                    value: '${model.currentStreak} days',
                                    color: _C.orange,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _CoachSectionTitle(
                              icon: Icons.route_rounded,
                              title: 'Personalized Next Step',
                            ),
                            const SizedBox(height: 10),
                            _CoachTextCard(
                              text: nextAction,
                              accent: _C.green,
                            ),
                          ],

                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: model.isPremium
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFF59E0B),
                                          Color(0xFFF97316),
                                        ],
                                      )
                                    : _C.gradient,
                                borderRadius: BorderRadius.circular(17),
                                boxShadow: [
                                  BoxShadow(
                                    color: (model.isPremium
                                            ? _C.orange
                                            : _C.cyan)
                                        .withOpacity(.16),
                                    blurRadius: 22,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: onPracticeWeakest,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                                icon:
                                    const Icon(Icons.play_arrow_rounded),
                                label: Text(
                                  model.completedSkillCount == 0
                                      ? 'Start Skill Assessment'
                                      : 'Practice ${model.weakestSkill}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              model.isPremium
                                  ? 'Advanced insight uses your saved live dashboard data and updates as your results change.'
                                  : 'Basic insight uses your saved IELTS results. Upgrade to Premium for deeper skill, band and execution analysis.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _C.muted,
                                fontSize: 9,
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
            ],
          ),
        );
      },
    );
  }
}

class _CoachTierBadge extends StatelessWidget {
  final bool premium;

  const _CoachTierBadge({required this.premium});

  @override
  Widget build(BuildContext context) {
    final color = premium ? _C.orange : _C.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            premium
                ? Icons.workspace_premium_rounded
                : Icons.auto_awesome_rounded,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            premium ? 'PREMIUM • ADVANCED' : 'FREE • BASIC',
            style: TextStyle(
              color: color,
              fontSize: 7.8,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCoachLockedCard extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _PremiumCoachLockedCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    const premiumFeatures = [
      (
        Icons.analytics_rounded,
        'Advanced skill-by-skill performance analysis',
      ),
      (
        Icons.compare_arrows_rounded,
        'Current vs target band-gap analysis',
      ),
      (
        Icons.trending_up_rounded,
        'Strongest and weakest skill identification',
      ),
      (
        Icons.calendar_month_rounded,
        'Study execution and activity analysis',
      ),
      (
        Icons.route_rounded,
        'More detailed personalized next-step coaching',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            _C.orange.withOpacity(.13),
            _C.violet.withOpacity(.10),
            _C.surface.withOpacity(.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _C.orange.withOpacity(.26)),
        boxShadow: [
          BoxShadow(
            color: _C.orange.withOpacity(.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF59E0B),
                      Color(0xFFF97316),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock Advanced AI Coach',
                      style: TextStyle(
                        color: _C.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Premium turns your basic snapshot into a deeper coaching report.',
                      style: TextStyle(
                        color: _C.secondary,
                        fontSize: 9.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.lock_rounded,
                color: _C.orange,
                size: 19,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...premiumFeatures.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _C.orange.withOpacity(.09),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      feature.$1,
                      color: _C.orange,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        feature.$2,
                        style: const TextStyle(
                          color: _C.secondary,
                          fontSize: 9.7,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onUpgrade,
              icon: const Icon(
                Icons.workspace_premium_rounded,
                size: 19,
              ),
              label: const Text(
                'Upgrade to Premium',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachHeroSummary extends StatelessWidget {
  final double currentBand;
  final double targetBand;
  final int readiness;
  final int completedSkills;

  const _CoachHeroSummary({
    required this.currentBand,
    required this.targetBand,
    required this.readiness,
    required this.completedSkills,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            _C.blue.withOpacity(.25),
            _C.cyan.withOpacity(.12),
            _C.violet.withOpacity(.18),
          ],
        ),
        border: Border.all(color: _C.cyan.withOpacity(.20)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: CircularProgressIndicator(
                    value: readiness / 100,
                    strokeWidth: 7,
                    backgroundColor: _C.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(_C.cyan),
                  ),
                ),
                Text(
                  '$readiness%',
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your current coaching baseline',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentBand > 0
                      ? 'Band ${currentBand.toStringAsFixed(1)} toward ${targetBand.toStringAsFixed(1)} • $completedSkills/4 skills measured'
                      : '$completedSkills/4 skills measured • Target Band ${targetBand.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: _C.secondary,
                    fontSize: 10,
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

class _CoachSkillGrid extends StatelessWidget {
  final List<SkillOverview> skills;

  const _CoachSkillGrid({required this.skills});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 9) / 2;

        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: skills.map((skill) {
            return SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: _coachCardDecoration(),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: skill.color.withOpacity(.11),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(skill.icon, color: skill.color, size: 18),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            skill.name,
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            skill.band > 0
                                ? skill.band.toStringAsFixed(1)
                                : 'Not measured',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: skill.band > 0
                                  ? skill.color
                                  : _C.secondary,
                              fontSize: skill.band > 0 ? 17 : 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CoachPriorityCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _CoachPriorityCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.orange.withOpacity(.13), _C.violet.withOpacity(.08)],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _C.orange.withOpacity(.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: _C.orange.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _C.orange, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: _C.secondary,
                    fontSize: 10,
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

class _CoachMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _CoachMetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: _coachCardDecoration(),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _C.muted,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _CoachDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _C.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _C.text,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachTextCard extends StatelessWidget {
  final String text;
  final Color accent;

  const _CoachTextCard({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _coachCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _C.secondary,
                fontSize: 10.8,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CoachSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _C.cyan, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _C.text,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _AIInsightBackground extends StatelessWidget {
  const _AIInsightBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -110,
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.violet.withOpacity(.07),
              ),
            ),
          ),
          Positioned(
            top: 220,
            left: -120,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.cyan.withOpacity(.045),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _coachCardDecoration() {
  return BoxDecoration(
    color: _C.surface.withOpacity(.92),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white.withOpacity(.055)),
  );
}

IconData _coachSkillIcon(String skill) {
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

class _Streak extends StatelessWidget {
  final HomeDashboardModel model;

  const _Streak({required this.model});

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFF97316),
                size: 23,
              ),
              SizedBox(width: 8),
              Text(
                'Daily Streak',
                style: TextStyle(
                  color: _C.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Current streak',
                  value: '${model.currentStreak}',
                  color: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Longest streak',
                  value: '${model.longestStreak}',
                  color: _C.violet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'XP points',
                  value: '${model.xpPoints}',
                  color: _C.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final active = index < model.activeWeekDays.length
                  ? model.activeWeekDays[index]
                  : false;

              return Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? _C.green : _C.surfaceLight,
                      border: Border.all(color: active ? _C.green : _C.border),
                    ),
                    child: Icon(
                      active ? Icons.check_rounded : Icons.circle_outlined,
                      color: active ? _C.bg : _C.muted,
                      size: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[index],
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Title(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: _C.muted, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SquareIcon extends StatelessWidget {
  final IconData icon;

  const _SquareIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: _C.gradient,
      ),
      child: Icon(icon, color: Colors.white, size: 23),
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _C.gradient,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      "Please Login",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      "Sign in to access your personalized IELTS dashboard, study plan, progress and AI features.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _C.muted, height: 1.6),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.login_rounded),
                        label: const Text(
                          "Login",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AuthenticationGatewayScreen(
                                initialMode: AuthMode.signIn,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          Positioned.fill(child: _Background()),
          Center(child: CircularProgressIndicator(color: _C.cyan)),
        ],
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
    return Scaffold(
      backgroundColor: _C.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Colors.redAccent,
                size: 45,
              ),
              const SizedBox(height: 15),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 15),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
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
                Color(0xFF040A13),
                Color(0xFF07111F),
                Color(0xFF09182A),
                Color(0xFF07111F),
              ],
            ),
          ),
        ),
        const Positioned(
          top: -150,
          right: -120,
          child: _Glow(size: 340, color: Color(0x2B2563EB)),
        ),
        const Positioned(
          top: 390,
          left: -160,
          child: _Glow(size: 320, color: Color(0x1706B6D4)),
        ),
        const Positioned(
          bottom: -180,
          right: -150,
          child: _Glow(size: 390, color: Color(0x178B5CF6)),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

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

class _C {
  static const bg = Color(0xFF07111F);
  static const surface = Color(0xFF101C2E);
  static const surfaceLight = Color(0xFF182A40);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFF26364A);
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF34D399);
  static const orange = Color(0xFFFFA500);

  static const gradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}

BoxDecoration _card() {
  return BoxDecoration(
    color: _C.surface.withOpacity(.92),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(.065)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.14),
        blurRadius: 17,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const [];
}

Set<String> _asStringSet(dynamic value) {
  return _asList(value).map((item) => item.toString()).toSet();
}

List<String> _asStringList(dynamic value) {
  return _asList(value).map((item) => item.toString()).toList();
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _isHomePremiumUser(Map<String, dynamic> data) {
  if (data['isPremium'] == true ||
      data['premium'] == true ||
      data['subscriptionActive'] == true) {
    return true;
  }

  final status = (data['subscriptionStatus'] ??
          data['premiumStatus'] ??
          data['subscriptionRequestStatus'] ??
          '')
      .toString()
      .trim()
      .toLowerCase();

  if (status == 'active' || status == 'approved' || status == 'premium') {
    return true;
  }

  final expiryValue = data['premiumUntil'] ??
      data['premiumExpiry'] ??
      data['subscriptionExpiresAt'] ??
      data['subscriptionEnd'];

  DateTime? expiry;
  if (expiryValue is Timestamp) {
    expiry = expiryValue.toDate();
  } else if (expiryValue is DateTime) {
    expiry = expiryValue;
  } else if (expiryValue is String) {
    expiry = DateTime.tryParse(expiryValue);
  }

  if (expiry != null && expiry.isAfter(DateTime.now())) {
    return true;
  }

  return false;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();

  if (text == null || text.isEmpty || text == 'null') {
    return null;
  }

  return text;
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';

    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }

  return 'IELTS Learner';
}

int _examCountdown(dynamic value) {
  DateTime? examDate;

  if (value is Timestamp) {
    examDate = value.toDate();
  } else if (value is DateTime) {
    examDate = value;
  } else if (value is String) {
    examDate = DateTime.tryParse(value);
  }

  if (examDate == null) return 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(examDate.year, examDate.month, examDate.day);
  final difference = date.difference(today).inDays;

  return math.max(0, difference);
}

int _calculateReadiness({
  required double currentBand,
  required double targetBand,
  required int weeklyProgress,
  required int completedSkillCount,
}) {
  if (currentBand <= 0 || completedSkillCount <= 0) return 0;

  final safeTargetBand = targetBand <= 0 ? 7.0 : targetBand;
  final completionRatio = (completedSkillCount / 4).clamp(0.0, 1.0);
  final bandProgress = (currentBand / safeTargetBand * 100).clamp(0.0, 100.0);

  // Partial skill data produces provisional readiness only. Completing all
  // four IELTS skills unlocks the full readiness calculation.
  final performanceComponent = bandProgress * .75 * completionRatio;
  final activityComponent = weeklyProgress * .25;

  return (performanceComponent + activityComponent).round().clamp(0, 100);
}

double _roundToNearestHalf(double value) {
  return (value * 2).round() / 2;
}

int _calculateWeeklyProgress(
  List<dynamic> weeklyPlan,
  Set<String> completedTaskIds,
) {
  int total = 0;
  int completed = 0;

  for (final rawDay in weeklyPlan) {
    final day = _asMap(rawDay);

    for (final rawTask in _asList(day['tasks'])) {
      final task = _asMap(rawTask);
      final id = (task['id'] ?? task['title'] ?? '').toString();

      total++;

      if (completedTaskIds.contains(id) || task['completed'] == true) {
        completed++;
      }
    }
  }

  if (total == 0) return 0;

  return ((completed / total) * 100).round();
}

String _weakestSkill(Map<String, double> skillValues) {
  if (skillValues.isEmpty) return 'Writing';

  return skillValues.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
}

String _defaultWeakTopic(String skill) {
  switch (skill.toLowerCase()) {
    case 'listening':
      return 'Map Labelling';
    case 'reading':
      return 'Matching Headings';
    case 'writing':
      return 'Coherence and Grammar';
    case 'speaking':
      return 'Fluency and Pronunciation';
    default:
      return 'Core IELTS Strategy';
  }
}

String _defaultPendingTask(String skill) {
  switch (skill.toLowerCase()) {
    case 'listening':
      return 'Listening section practice';
    case 'reading':
      return 'Reading strategy practice';
    case 'writing':
      return 'Writing task practice';
    case 'speaking':
      return 'Speaking drill';
    default:
      return 'Targeted practice';
  }
}

String _findPendingSkillTask(
  List<HomeTask> tasks,
  String skill, {
  required String fallback,
}) {
  for (final task in tasks) {
    if (!task.completed &&
        (task.title.toLowerCase().contains(skill.toLowerCase()) ||
            task.type.toLowerCase().contains(skill.toLowerCase()))) {
      return task.title;
    }
  }

  return fallback;
}

double _skillTrend(Map<String, dynamic> userData, String skill) {
  final trends = _asMap(userData['skillTrends']);

  return _asDouble(
    trends[skill.toLowerCase()] ??
        trends[skill] ??
        userData['${skill.toLowerCase()}Trend'],
  );
}

List<bool> _activeWeekDays(dynamic value, {required int completedToday}) {
  final now = DateTime.now();
  final monday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  final result = List<bool>.filled(7, false);

  if (value is List) {
    final dateKeys = value.map((item) => item.toString()).toSet();

    for (var index = 0; index < 7; index++) {
      result[index] = dateKeys.contains(
        _dateKey(monday.add(Duration(days: index))),
      );
    }

    return result;
  }

  if (value is Map) {
    for (var index = 0; index < 7; index++) {
      final date = monday.add(Duration(days: index));
      final dayName = _dayName(date.weekday);
      result[index] =
          value[dayName] == true ||
          value[dayName.toLowerCase()] == true ||
          value[_dateKey(date)] == true;
    }
  }

  if (completedToday > 0) {
    result[now.weekday - 1] = true;
  }

  return result;
}

String _dayName(int weekday) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  return days[(weekday - 1).clamp(0, 6)];
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

Map<String, dynamic> _latestDocumentData(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  if (docs.isEmpty) return <String, dynamic>{};

  final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
    ..sort((a, b) => _resultDate(b.data()).compareTo(_resultDate(a.data())));

  return sorted.first.data();
}

DateTime _resultDate(Map<String, dynamic> data) {
  for (final key in const [
    'completedAt',
    'timestamp',
    'createdAt',
    'updatedAt',
    'submittedAt',
  ]) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

double _latestBand(Map<String, dynamic>? data, {required double fallback}) {
  if (data == null || data.isEmpty) return fallback;

  final report = _asMap(data['report']);
  final candidates = [
    data['overallBand'],
    data['band'],
    data['estimatedBand'],
    data['bandScore'],
    report['overallBand'],
    report['band'],
  ];

  for (final candidate in candidates) {
    final value = _asDouble(candidate);
    if (value > 0 && value <= 9) return value;
  }

  return fallback;
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;

    if (!iterator.moveNext()) return null;

    return iterator.current;
  }
}
