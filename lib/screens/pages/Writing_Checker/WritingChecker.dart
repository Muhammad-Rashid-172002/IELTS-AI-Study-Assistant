import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyproject/offline/offline_content_service.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/Subscription/Subscription_screen.dart';
import 'package:fyproject/screens/content_queue_service.dart';

class WritingPremiumManager {
  WritingPremiumManager._();

  static const int freeWritingTasksPerDay = 1;
  static const int freeAiChecksPerDay = 1;
  static const int freeDraftLimit = 3;
  static const int freeHistoryLimit = 10;
  static const int freeLessonCount = 3;
  static const int freeModelAnswers = 3;

  static bool isPremiumFromData(Map<String, dynamic> data) {
    if (data['isPremium'] == true ||
        data['premium'] == true ||
        data['subscriptionActive'] == true) {
      return true;
    }

    final status =
        (data['subscriptionStatus'] ??
                data['premiumStatus'] ??
                data['subscriptionRequestStatus'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    if (status == 'active' || status == 'approved' || status == 'premium') {
      return true;
    }

    final plan = (data['premiumPlan'] ?? '').toString().trim().toLowerCase();
    if (plan == 'monthly' ||
        plan == 'quarterly' ||
        plan == 'yearly' ||
        plan == 'annual') {
      return true;
    }

    final expiry = _readDate(
      data['premiumUntil'] ??
          data['premiumExpiry'] ??
          data['subscriptionExpiresAt'] ??
          data['subscriptionEnd'],
    );
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _dayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  static Future<bool> isPremiumUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      return isPremiumFromData(doc.data() ?? const <String, dynamic>{});
    } catch (_) {
      return false;
    }
  }

  static Future<_WritingLimitDecision> checkDaily({
    required String feature,
    required int limit,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _WritingLimitDecision(
        allowed: false,
        premium: false,
        used: 0,
        limit: limit,
      );
    }

    if (!OfflineContentService.instance.isOnline) {
      return _WritingLimitDecision(
        allowed: true,
        premium: false,
        used: 0,
        limit: limit,
        offlineBypass: true,
      );
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final usageRef = userRef.collection('feature_usage').doc('writing');

    try {
      final docs = await Future.wait([
        userRef.get().timeout(const Duration(seconds: 10)),
        usageRef.get().timeout(const Duration(seconds: 10)),
      ]);

      final userData =
          (docs[0] as DocumentSnapshot<Map<String, dynamic>>).data() ??
          const <String, dynamic>{};

      if (isPremiumFromData(userData)) {
        return _WritingLimitDecision(
          allowed: true,
          premium: true,
          used: 0,
          limit: limit,
        );
      }

      final usage =
          (docs[1] as DocumentSnapshot<Map<String, dynamic>>).data() ??
          const <String, dynamic>{};
      final today = _dayKey(DateTime.now());
      final storedDay = (usage['dailyKey'] ?? '').toString();
      final counts = _intMap(usage['dailyCounts']);
      final used = storedDay == today ? (counts[feature] ?? 0) : 0;

      return _WritingLimitDecision(
        allowed: used < limit,
        premium: false,
        used: used,
        limit: limit,
      );
    } catch (error) {
      debugPrint('Writing premium check failed: $error');
      return _WritingLimitDecision(
        allowed: true,
        premium: false,
        used: 0,
        limit: limit,
      );
    }
  }

  static Future<_WritingLimitDecision> consumeDaily({
    required String feature,
    required int limit,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _WritingLimitDecision(
        allowed: false,
        premium: false,
        used: 0,
        limit: limit,
      );
    }

    if (!OfflineContentService.instance.isOnline) {
      return _WritingLimitDecision(
        allowed: true,
        premium: false,
        used: 0,
        limit: limit,
        offlineBypass: true,
      );
    }

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final usageRef = userRef.collection('feature_usage').doc('writing');

    return firestore
        .runTransaction<_WritingLimitDecision>((tx) async {
          final userDoc = await tx.get(userRef);
          final userData = userDoc.data() ?? const <String, dynamic>{};

          if (isPremiumFromData(userData)) {
            return _WritingLimitDecision(
              allowed: true,
              premium: true,
              used: 0,
              limit: limit,
            );
          }

          final usageDoc = await tx.get(usageRef);
          final usage = usageDoc.data() ?? const <String, dynamic>{};
          final today = _dayKey(DateTime.now());
          final storedDay = (usage['dailyKey'] ?? '').toString();
          final counts = storedDay == today
              ? _intMap(usage['dailyCounts'])
              : <String, int>{};

          final used = counts[feature] ?? 0;
          if (used >= limit) {
            return _WritingLimitDecision(
              allowed: false,
              premium: false,
              used: used,
              limit: limit,
            );
          }

          counts[feature] = used + 1;

          tx.set(usageRef, {
            'dailyKey': today,
            'dailyCounts': counts,
            'lastFeature': feature,
            'lastUsedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return _WritingLimitDecision(
            allowed: true,
            premium: false,
            used: used + 1,
            limit: limit,
          );
        })
        .timeout(const Duration(seconds: 15));
  }

  static Future<bool> canCreateDraft() async {
    if (await isPremiumUser()) return true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('writing_drafts')
          .limit(freeDraftLimit + 1)
          .get()
          .timeout(const Duration(seconds: 10));
      return snapshot.docs.length < freeDraftLimit;
    } catch (_) {
      return true;
    }
  }

  static Map<String, int> _intMap(dynamic value) {
    if (value is! Map) return <String, int>{};
    final result = <String, int>{};
    value.forEach((key, raw) {
      if (raw is int) {
        result[key.toString()] = raw;
      } else if (raw is num) {
        result[key.toString()] = raw.toInt();
      } else {
        final parsed = int.tryParse(raw.toString());
        if (parsed != null) result[key.toString()] = parsed;
      }
    });
    return result;
  }
}

class _WritingLimitDecision {
  const _WritingLimitDecision({
    required this.allowed,
    required this.premium,
    required this.used,
    required this.limit,
    this.offlineBypass = false,
  });

  final bool allowed;
  final bool premium;
  final int used;
  final int limit;
  final bool offlineBypass;

  int get remaining => math.max(0, limit - used);
}

Future<void> _openWritingPremium(
  BuildContext context, {
  String source = 'writing',
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const SubscriptionScreen(),
      settings: RouteSettings(name: '/premium', arguments: {'source': source}),
    ),
  );
}

Future<void> _showWritingLimitSheet(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  if (!context.mounted) return;

  final upgrade = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: WColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: WColors.violet.withOpacity(.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.35),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: WColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [WColors.violet, WColors.cyan],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: WColors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                style: const TextStyle(
                  color: WColors.secondary,
                  fontSize: 11.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              const _WritingPremiumBenefit(
                icon: Icons.all_inclusive_rounded,
                text: 'Unlimited Writing tasks and AI checks',
              ),
              const _WritingPremiumBenefit(
                icon: Icons.auto_awesome_rounded,
                text: 'Full AI feedback and band estimation',
              ),
              const _WritingPremiumBenefit(
                icon: Icons.save_rounded,
                text: 'Unlimited drafts and complete history',
              ),
              const _WritingPremiumBenefit(
                icon: Icons.menu_book_rounded,
                text: 'All lessons and model answers',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text(
                    'Unlock Premium',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: WColors.violet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Maybe later'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (upgrade == true && context.mounted) {
    await _openWritingPremium(context, source: title);
  }
}

class _WritingPremiumBenefit extends StatelessWidget {
  const _WritingPremiumBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: WColors.green.withOpacity(.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: WColors.green, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: WColors.secondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: WColors.green,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _WritingPlanCard extends StatelessWidget {
  const _WritingPlanCard({required this.userId});
  final String? userId;

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: WritingPremiumManager.isPremiumUser(),
      builder: (context, snapshot) {
        final isPremium = snapshot.data ?? false;
        final accent = isPremium ? WColors.green : WColors.violet;

        return Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [accent.withOpacity(.14), WColors.cyan.withOpacity(.06)],
            ),
            border: Border.all(color: accent.withOpacity(.24)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPremium
                            ? [WColors.green, WColors.cyan]
                            : [WColors.violet, WColors.cyan],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      isPremium
                          ? Icons.verified_rounded
                          : Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium
                              ? 'PREMIUM WRITING ACTIVE'
                              : 'FREE WRITING PLAN',
                          style: TextStyle(
                            color: accent,
                            fontSize: 8.8,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isPremium
                              ? 'Unlimited IELTS Writing practice'
                              : '1 Writing task + 1 AI check every day',
                          style: const TextStyle(
                            color: WColors.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPremium
                              ? 'Unlimited tasks, AI reports, drafts, history, lessons and model answers.'
                              : 'Free plan: 3 drafts, latest 10 results and first 3 lessons.',
                          style: const TextStyle(
                            color: WColors.secondary,
                            fontSize: 9.8,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isPremium) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _openWritingPremium(context, source: 'writing_home'),
                    icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                    label: const Text(
                      'Unlock Unlimited Writing',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: WColors.violet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: _WritingPlanCard(userId: user?.uid),
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
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 166,
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
      final access = await WritingPremiumManager.checkDaily(
        feature: 'writing_task',
        limit: WritingPremiumManager.freeWritingTasksPerDay,
      );

      if (!access.allowed) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Daily Writing limit reached.';
        });

        await _showWritingLimitSheet(
          context,
          title: 'Daily Writing limit reached',
          message:
              'Free users can start 1 Writing task per day. Upgrade to Premium for unlimited Writing practice.',
        );
        return;
      }

      final queue = ContentQueueService();
      final offline = OfflineContentService.instance;
      final completedIds = await queue.completedIds('writing');
      List<WritingTask> available;

      try {
        final published = await FirebaseFirestore.instance
            .collection('writing_tasks')
            .where('status', isEqualTo: 'published')
            .limit(200)
            .get();
        await offline.cacheMany(
          module: 'writing',
          items: published.docs.map((doc) => MapEntry(doc.id, doc.data())),
        );
        available = published.docs
            .where((doc) {
              final data = doc.data();
              return data['taskCategory'] == widget.category &&
                  (widget.taskType == null ||
                      data['taskType'] == widget.taskType);
            })
            .map(WritingTask.fromDocument)
            .toList();
      } catch (_) {
        available = offline
            .cachedContent(
              'writing',
              where: (data) =>
                  data['taskCategory'] == widget.category &&
                  (widget.taskType == null ||
                      data['taskType'] == widget.taskType),
            )
            .map(
              (data) => WritingTask.fromMap(
                data,
                id: data['_offlineId']?.toString() ?? '',
              ),
            )
            .toList();
      }

      available = available
          .where((task) => !completedIds.contains(task.id))
          .take(1)
          .toList();

      if (!mounted) return;
      setState(() {
        _tasks = available;
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
      appBar: _writingAppBar(context, title),
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
              title: 'No new Writing task available',
              subtitle:
                  'Complete tasks are hidden. A new task will appear when the administrator publishes it.',
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
                  style: const TextStyle(color: WColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 20),
                _ModeTile(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Practice Mode',
                  subtitle:
                      'Grammar, vocabulary, checklist and sentence suggestions',
                  badge: 'RECOMMENDED',
                  onTap: () => _start(sheetContext, task, WritingMode.practice),
                ),
                const SizedBox(height: 10),
                _ModeTile(
                  icon: Icons.save_outlined,
                  title: 'Draft Mode',
                  subtitle:
                      'No fixed timer, automatic saving and continue later',
                  onTap: () => _start(sheetContext, task, WritingMode.draft),
                ),
                const SizedBox(height: 10),
                _ModeTile(
                  icon: Icons.lock_clock_outlined,
                  title: 'Exam Mode',
                  subtitle:
                      'Fixed IELTS timer with hints and corrections disabled',
                  badge: 'STRICT',
                  onTap: () => _start(sheetContext, task, WritingMode.exam),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _start(
    BuildContext sheetContext,
    WritingTask task,
    WritingMode mode,
  ) async {
    Navigator.of(sheetContext).pop();

    final access = await WritingPremiumManager.consumeDaily(
      feature: 'writing_task',
      limit: WritingPremiumManager.freeWritingTasksPerDay,
    );

    if (!mounted) return;

    if (!access.allowed) {
      await _showWritingLimitSheet(
        context,
        title: 'Daily Writing limit reached',
        message:
            'Free users can start 1 Writing task per day. Upgrade to Premium for unlimited Writing practice.',
      );
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WritingEditorScreen(task: task, mode: mode),
      ),
    );
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
      if (_draftId == null) {
        final canCreate = await WritingPremiumManager.canCreateDraft();
        if (!canCreate) {
          if (mounted) {
            setState(() => _autosaveLabel = 'Free draft limit reached');
          }
          return;
        }
      }

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
    } catch (_) {
      final localId = await OfflineContentService.instance
          .queueWritingEvaluation(
            uid: user.uid,
            taskId: widget.task.id,
            data: {
              'title': widget.task.title,
              'taskQuestion': widget.task.taskQuestion,
              'taskCategory': widget.task.taskCategory,
              'taskType': widget.task.taskType,
              'mode': widget.mode.name,
              'answer': answer,
              'wordCount': _wordCount,
              'durationUsedSeconds': _elapsedSeconds,
              'status': 'pending_ai_evaluation',
            },
          );
      await OfflineContentService.instance.markCompleted(
        module: 'writing',
        contentId: widget.task.id,
        result: {'status': 'pending_ai_evaluation', 'queueId': localId},
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Essay saved offline. AI band and feedback will be generated after reconnecting.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      appBar: _writingAppBar(context, 'AI Writing Report'),
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

    final access = await WritingPremiumManager.consumeDaily(
      feature: 'ai_checker',
      limit: WritingPremiumManager.freeAiChecksPerDay,
    );

    if (!mounted) return;

    if (!access.allowed) {
      await _showWritingLimitSheet(
        context,
        title: 'AI Writing limit reached',
        message:
            'Free users can generate 1 AI Writing report per day. Upgrade to Premium for unlimited AI evaluation.',
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
      appBar: _writingAppBar(context, 'AI Writing Checker'),
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
                dropdownColor: WColors.surface,
                iconEnabledColor: WColors.cyan,
                style: const TextStyle(
                  color: WColors.text,
                  fontWeight: FontWeight.w700,
                ),
                decoration: _writingInputDecoration(
                  label: 'Task Category',
                  icon: Icons.category_outlined,
                ),
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
                dropdownColor: WColors.surface,
                iconEnabledColor: WColors.cyan,
                style: const TextStyle(
                  color: WColors.text,
                  fontWeight: FontWeight.w700,
                ),
                decoration: _writingInputDecoration(
                  label: 'Task Type',
                  icon: Icons.tune_rounded,
                ),
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
                style: const TextStyle(color: WColors.text, height: 1.5),
                cursorColor: WColors.cyan,
                decoration: _writingInputDecoration(
                  label: 'Task Question',
                  icon: Icons.help_outline_rounded,
                  alignLabelWithHint: true,
                  hint: 'Paste the complete IELTS question here...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _answerController,
                minLines: 12,
                maxLines: 25,
                style: const TextStyle(color: WColors.text, height: 1.65),
                cursorColor: WColors.cyan,
                onChanged: (_) => setState(() {}),
                decoration: _writingInputDecoration(
                  label: 'Your Answer',
                  icon: Icons.edit_note_rounded,
                  alignLabelWithHint: true,
                  hint: 'Write or paste your complete response...',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_wordCount(_answerController.text)} words',
                style: const TextStyle(color: WColors.muted),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: const Text(
                    'Generate AI Writing Report',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
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

    if (user == null) {
      return Scaffold(
        backgroundColor: WColors.background,
        appBar: _writingAppBar(context, 'Saved Drafts'),
        body: const _MessageState(
          icon: Icons.lock_outline_rounded,
          title: 'Sign in required',
          subtitle: 'Please sign in to access saved drafts.',
        ),
      );
    }

    return FutureBuilder<bool>(
      future: WritingPremiumManager.isPremiumUser(),
      builder: (context, premiumSnapshot) {
        final isPremium = premiumSnapshot.data ?? false;

        return Scaffold(
          backgroundColor: WColors.background,
          appBar: _writingAppBar(
            context,
            isPremium ? 'Saved Drafts • Unlimited' : 'Saved Drafts • Free: 3',
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

              final allDocs = snapshot.data!.docs;
              final docs = isPremium
                  ? allDocs
                  : allDocs.take(WritingPremiumManager.freeDraftLimit).toList();

              if (docs.isEmpty) {
                return const _MessageState(
                  icon: Icons.save_outlined,
                  title: 'No saved drafts',
                  subtitle: 'Your autosaved writing drafts will appear here.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount:
                    docs.length +
                    (!isPremium && allDocs.length > docs.length ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index >= docs.length) {
                    return _WritingPremiumLockedCard(
                      title: 'Unlimited Drafts',
                      subtitle:
                          'Free users can keep up to ${WritingPremiumManager.freeDraftLimit} drafts. Upgrade to save more.',
                      onTap: () =>
                          _openWritingPremium(context, source: 'saved_drafts'),
                    );
                  }

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
      },
    );
  }
}

class WritingHistoryScreen extends StatelessWidget {
  const WritingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: WColors.background,
        appBar: _writingAppBar(context, 'Writing History'),
        body: const _MessageState(
          icon: Icons.lock_outline_rounded,
          title: 'Sign in required',
          subtitle: 'Please sign in to access writing history.',
        ),
      );
    }

    return FutureBuilder<bool>(
      future: WritingPremiumManager.isPremiumUser(),
      builder: (context, premiumSnapshot) {
        final isPremium = premiumSnapshot.data ?? false;

        return Scaffold(
          backgroundColor: WColors.background,
          appBar: _writingAppBar(
            context,
            isPremium
                ? 'Writing History • Complete'
                : 'Writing History • Latest 10',
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

              final allDocs = snapshot.data!.docs;
              final docs = isPremium
                  ? allDocs
                  : allDocs
                        .take(WritingPremiumManager.freeHistoryLimit)
                        .toList();

              if (docs.isEmpty) {
                return const _MessageState(
                  icon: Icons.history_rounded,
                  title: 'No writing results yet',
                  subtitle: 'Complete a writing task to build your history.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount:
                    docs.length +
                    (!isPremium && allDocs.length > docs.length ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index >= docs.length) {
                    return _WritingPremiumLockedCard(
                      title: 'Complete Writing History',
                      subtitle:
                          'Free users can view the latest ${WritingPremiumManager.freeHistoryLimit} results.',
                      onTap: () => _openWritingPremium(
                        context,
                        source: 'writing_history',
                      ),
                    );
                  }

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
      },
    );
  }
}

class ModelAnswersScreen extends StatelessWidget {
  const ModelAnswersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: WritingPremiumManager.isPremiumUser(),
      builder: (context, premiumSnapshot) {
        final isPremium = premiumSnapshot.data ?? false;

        return Scaffold(
          backgroundColor: WColors.background,
          appBar: _writingAppBar(
            context,
            isPremium
                ? 'Band 8–9 Model Answers'
                : 'Model Answers • First 3 Free',
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

              final allTasks = snapshot.data!.docs
                  .map(WritingTask.fromDocument)
                  .where((task) => task.band8ModelAnswer.isNotEmpty)
                  .toList();

              if (allTasks.isEmpty) {
                return const _MessageState(
                  icon: Icons.library_books_outlined,
                  title: 'No model answers available',
                  subtitle:
                      'Publish generated Writing tasks with model answers.',
                );
              }

              final tasks = isPremium
                  ? allTasks
                  : allTasks
                        .take(WritingPremiumManager.freeModelAnswers)
                        .toList();

              return ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount:
                    tasks.length +
                    (!isPremium && allTasks.length > tasks.length ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index >= tasks.length) {
                    return _WritingPremiumLockedCard(
                      title: 'Premium Model Answer Library',
                      subtitle:
                          'Unlock the complete Band 8–9 model answer library.',
                      onTap: () =>
                          _openWritingPremium(context, source: 'model_answers'),
                    );
                  }

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
      },
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

    return FutureBuilder<bool>(
      future: WritingPremiumManager.isPremiumUser(),
      builder: (context, premiumSnapshot) {
        final isPremium = premiumSnapshot.data ?? false;

        return Scaffold(
          backgroundColor: WColors.background,
          appBar: _writingAppBar(
            context,
            isPremium
                ? 'Writing Lessons • All Access'
                : 'Writing Lessons • First 3 Free',
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: lessons.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 178,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final locked =
                  !isPremium && index >= WritingPremiumManager.freeLessonCount;

              return InkWell(
                onTap: locked
                    ? () => _openWritingPremium(
                        context,
                        source: 'writing_lessons',
                      )
                    : null,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _panelDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            locked ? Icons.lock_rounded : lesson.$3,
                            color: locked ? WColors.violet : WColors.cyan,
                            size: 28,
                          ),
                          const Spacer(),
                          if (locked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: WColors.violet.withOpacity(.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: WColors.violet,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        lesson.$1,
                        style: TextStyle(
                          color: locked ? WColors.secondary : WColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        locked
                            ? 'Upgrade to Premium to unlock this lesson.'
                            : lesson.$2,
                        style: const TextStyle(
                          color: WColors.muted,
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _WritingPremiumLockedCard extends StatelessWidget {
  const _WritingPremiumLockedCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WColors.violet.withOpacity(.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: WColors.violet.withOpacity(.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: WColors.violet.withOpacity(.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: WColors.violet,
              ),
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: WColors.muted,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: WColors.violet),
          ],
        ),
      ),
    );
  }
}

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
    return Row(
      children: [
        const _GradientIcon(icon: Icons.draw_rounded),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Writing Studio',
                style: TextStyle(
                  color: WColors.text,
                  fontSize: 25,
                  letterSpacing: -.45,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Practice smarter, write confidently and improve your band',
                style: TextStyle(
                  color: WColors.muted,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: WColors.green.withOpacity(.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: WColors.green.withOpacity(.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: WColors.green, size: 14),
              SizedBox(width: 5),
              Text(
                'AI READY',
                style: TextStyle(
                  color: WColors.green,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
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
    final progress = (band / 9).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _heroDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 86,
                  height: 86,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withOpacity(.07),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      WColors.cyan,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      band > 0 ? band.toStringAsFixed(1) : '—',
                      style: const TextStyle(
                        color: WColors.text,
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'BAND',
                      style: TextStyle(
                        color: WColors.muted,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: WColors.cyan.withOpacity(.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: WColors.cyan.withOpacity(.22)),
                  ),
                  child: const Text(
                    'WRITING PERFORMANCE',
                    style: TextStyle(
                      color: WColors.cyan,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your estimated writing band',
                  style: TextStyle(
                    color: WColors.text,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complete AI-evaluated tasks to track progress across all IELTS writing criteria.',
                  style: TextStyle(
                    color: WColors.secondary,
                    fontSize: 10.5,
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

class _HomeOptionCard extends StatelessWidget {
  final WritingHomeOption option;
  final VoidCallback onTap;

  const _HomeOptionCard({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final featured = option == WritingHomeOption.aiChecker;
    final accent = featured ? WColors.violet : WColors.cyan;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: featured
                  ? const [Color(0xFF1B1C3F), Color(0xFF10243A)]
                  : const [Color(0xFF111E31), Color(0xFF0D1829)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: featured
                  ? WColors.violet.withOpacity(.38)
                  : Colors.white.withOpacity(.075),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.24),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              if (featured)
                BoxShadow(
                  color: WColors.violet.withOpacity(.09),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -30,
                top: -34,
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [accent.withOpacity(.18), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: featured
                                  ? [WColors.violet, WColors.cyan]
                                  : [
                                      WColors.cyan.withOpacity(.24),
                                      WColors.violet.withOpacity(.16),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: accent.withOpacity(.34)),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(.12),
                                blurRadius: 16,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Icon(
                            option.icon,
                            color: featured ? Colors.white : WColors.cyan,
                            size: 23,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.045),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(.07),
                            ),
                          ),
                          child: const Icon(
                            Icons.north_east_rounded,
                            color: WColors.secondary,
                            size: 17,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      option.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WColors.text,
                        fontSize: 14.2,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      option.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WColors.muted,
                        fontSize: 10.4,
                        height: 1.4,
                      ),
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
    final meta = _taskGroupMeta(category);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111E31), Color(0xFF0C1727)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(.075)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.22),
            blurRadius: 22,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      meta.color.withOpacity(.28),
                      meta.color.withOpacity(.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: meta.color.withOpacity(.32)),
                ),
                child: Icon(meta.icon, color: meta.color, size: 22),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${types.length} focused practice formats',
                      style: const TextStyle(
                        color: WColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(.09),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: meta.color.withOpacity(.21)),
                ),
                child: Text(
                  meta.badge,
                  style: TextStyle(
                    color: meta.color,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .55,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 9.0;
              final tileWidth = (constraints.maxWidth - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: 9,
                children: types.map((type) {
                  return SizedBox(
                    width: tileWidth,
                    child: _TaskTypeTile(
                      title: type,
                      icon: _taskTypeIcon(type),
                      color: meta.color,
                      onTap: () => WritingChecker._openBrowser(
                        context,
                        category,
                        type: type,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TaskTypeTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TaskTypeTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1626).withOpacity(.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(.20)),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WColors.secondary,
                    fontSize: 10.7,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withOpacity(.85),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({IconData icon, Color color, String badge}) _taskGroupMeta(String category) {
  switch (category) {
    case 'academic_task_1':
      return (
        icon: Icons.insights_rounded,
        color: WColors.cyan,
        badge: 'ACADEMIC',
      );
    case 'general_task_1':
      return (
        icon: Icons.mail_outline_rounded,
        color: WColors.green,
        badge: 'GENERAL',
      );
    default:
      return (
        icon: Icons.edit_note_rounded,
        color: WColors.violet,
        badge: 'ESSAYS',
      );
  }
}

IconData _taskTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'line graph':
      return Icons.show_chart_rounded;
    case 'bar chart':
      return Icons.bar_chart_rounded;
    case 'pie chart':
      return Icons.pie_chart_outline_rounded;
    case 'table':
      return Icons.table_chart_outlined;
    case 'map':
      return Icons.map_outlined;
    case 'process diagram':
      return Icons.account_tree_outlined;
    case 'mixed charts':
      return Icons.dashboard_customize_outlined;
    case 'formal letter':
      return Icons.business_center_outlined;
    case 'semi-formal letter':
      return Icons.handshake_outlined;
    case 'informal letter':
      return Icons.mark_email_read_outlined;
    case 'opinion essay':
      return Icons.record_voice_over_outlined;
    case 'discussion essay':
      return Icons.forum_outlined;
    case 'advantages/disadvantages':
      return Icons.balance_rounded;
    case 'problem/solution':
      return Icons.lightbulb_outline_rounded;
    case 'two-part question':
      return Icons.call_split_rounded;
    case 'direct question essay':
      return Icons.help_outline_rounded;
    default:
      return Icons.edit_document;
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
                  style: const TextStyle(color: WColors.muted, fontSize: 9),
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
          const Icon(Icons.auto_awesome_rounded, color: WColors.cyan, size: 19),
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
                  style: const TextStyle(
                    color: WColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
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
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -.25,
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
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF06101D),
                  Color(0xFF0A1628),
                  Color(0xFF08111F),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          top: -110,
          right: -85,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: WColors.cyan.withOpacity(.075),
              boxShadow: [
                BoxShadow(
                  color: WColors.cyan.withOpacity(.08),
                  blurRadius: 90,
                  spreadRadius: 24,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: -120,
          child: Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: WColors.violet.withOpacity(.055),
              boxShadow: [
                BoxShadow(
                  color: WColors.violet.withOpacity(.07),
                  blurRadius: 100,
                  spreadRadius: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

PreferredSizeWidget _writingAppBar(BuildContext context, String title) {
  return AppBar(
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: WColors.background.withOpacity(.96),
    surfaceTintColor: Colors.transparent,
    foregroundColor: WColors.text,
    iconTheme: const IconThemeData(color: WColors.text, size: 22),
    centerTitle: false,
    titleSpacing: 4,
    toolbarHeight: 68,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: WColors.text,
        fontSize: 19,
        fontWeight: FontWeight.w900,
        letterSpacing: -.25,
      ),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              WColors.cyan.withOpacity(.32),
              WColors.violet.withOpacity(.22),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );
}

InputDecoration _writingInputDecoration({
  required String label,
  required IconData icon,
  String? hint,
  bool alignLabelWithHint = false,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: WColors.border),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: alignLabelWithHint,
    prefixIcon: Icon(icon, color: WColors.cyan, size: 21),
    labelStyle: const TextStyle(
      color: WColors.secondary,
      fontWeight: FontWeight.w700,
    ),
    floatingLabelStyle: const TextStyle(
      color: WColors.cyan,
      fontWeight: FontWeight.w800,
    ),
    hintStyle: TextStyle(color: WColors.muted.withOpacity(.72), fontSize: 13),
    filled: true,
    fillColor: WColors.surface.withOpacity(.88),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    enabledBorder: border,
    border: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: WColors.cyan, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
  );
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
  gradient: LinearGradient(
    colors: [
      WColors.surface.withOpacity(.98),
      const Color(0xFF0F1A2C).withOpacity(.98),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: Colors.white.withOpacity(.065)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(.20),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: WColors.cyan.withOpacity(.025),
      blurRadius: 28,
      spreadRadius: 1,
    ),
  ],
);

BoxDecoration _heroDecoration() => BoxDecoration(
  gradient: LinearGradient(
    colors: [
      const Color(0xFF122238),
      WColors.cyan.withOpacity(.12),
      WColors.violet.withOpacity(.10),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.circular(26),
  border: Border.all(color: WColors.cyan.withOpacity(.25)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(.22),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
    BoxShadow(
      color: WColors.cyan.withOpacity(.06),
      blurRadius: 30,
      spreadRadius: 1,
    ),
  ],
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
