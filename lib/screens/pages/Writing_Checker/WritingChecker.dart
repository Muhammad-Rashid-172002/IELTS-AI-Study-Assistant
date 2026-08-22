import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyproject/offline/offline_content_service.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/resources/components/learner_state_view.dart';
import 'package:fyproject/resources/components/ielts_result_widgets.dart';
import 'package:fyproject/screens/pages/Subscription/Subscription_screen.dart';
import 'package:fyproject/screens/content_queue_service.dart';

class WritingPremiumManager {
  WritingPremiumManager._();

  // Free Writing access is completion-based: each published test once.
  // Kept only for backward compatibility with older usage documents.
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

  /// Free users may successfully complete each published Writing test once.
  /// Opening a task, choosing a mode, typing, autosaving, or navigating back
  /// does NOT consume the free attempt. The attempt is considered used only
  /// after a real completed AI evaluation is persisted to writing_cycles.
  static Future<bool> canAttemptWritingTask({
    required String poolKey,
    required String taskId,
  }) async {
    if (taskId.trim().isEmpty) return false;
    if (await isPremiumUser()) return true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    if (!OfflineContentService.instance.isOnline) {
      // Keep offline writing usable. Completion will be reconciled after sync.
      return true;
    }

    try {
      final progress = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('writing_cycles')
          .doc(poolKey)
          .get()
          .timeout(const Duration(seconds: 10));

      final completedIds = _stringList(
        progress.data()?['completedTaskIds'],
      ).map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

      return !completedIds.contains(taskId);
    } catch (error) {
      debugPrint('Writing single-attempt check failed: $error');
      // Fail open so a metadata/network issue does not wrongly lock practice.
      return true;
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
                fontSize: 11.5,
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
                              : 'Each Writing test once + 1 AI check every day',
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
                              : 'Free plan: each Writing test once, 3 drafts, latest 10 results and first 3 lessons.',
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

class _WritingCycleSelection {
  final WritingTask? task;
  final int cycleNumber;
  final int completedInCycle;

  const _WritingCycleSelection({
    required this.task,
    required this.cycleNumber,
    required this.completedInCycle,
  });
}

String _safeWritingCycleKey(String value) {
  final cleaned = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  return cleaned.isEmpty ? 'all' : cleaned;
}

int _compareWritingTasksNaturally(WritingTask a, WritingTask b) {
  final aNumber = _firstWritingNumber(a.title);
  final bNumber = _firstWritingNumber(b.title);

  if (aNumber != null && bNumber != null && aNumber != bNumber) {
    return aNumber.compareTo(bNumber);
  }

  final titleCompare = a.title.toLowerCase().compareTo(b.title.toLowerCase());

  if (titleCompare != 0) return titleCompare;

  return a.id.compareTo(b.id);
}

int? _firstWritingNumber(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(0)!);
}

Future<void> _completeWritingCycleAttempt({
  required User user,
  required String poolKey,
  required String category,
  required String taskType,
  required int cycleNumber,
  required String taskId,
  required String taskTitle,
  required int totalTasks,
  required double band,
}) async {
  if (!OfflineContentService.instance.isOnline) return;

  final firestore = FirebaseFirestore.instance;
  final userRef = firestore.collection('users').doc(user.uid);
  final progressRef = userRef.collection('writing_cycles').doc(poolKey);

  try {
    await firestore
        .runTransaction((transaction) async {
          final snapshot = await transaction.get(progressRef);
          final data = snapshot.data() ?? <String, dynamic>{};

          final storedCycle = _asInt(
            data['cycleNumber'],
            fallback: cycleNumber,
          );

          // Ignore stale completion callbacks from an older cycle.
          if (storedCycle != cycleNumber) return;

          final completedIds = _stringList(data['completedTaskIds']).toSet();
          final alreadyCompleted = completedIds.contains(taskId);

          if (!alreadyCompleted) {
            completedIds.add(taskId);
          }

          final previousCount = _asInt(data['cycleResultCount'], fallback: 0);
          final previousBandSum = _asDouble(data['cycleBandSum']);

          final nextCount = alreadyCompleted
              ? previousCount
              : previousCount + 1;
          final nextBandSum = alreadyCompleted
              ? previousBandSum
              : previousBandSum + band;

          final averageBand = nextCount == 0 ? 0.0 : nextBandSum / nextCount;

          final safeTotal = math.max(1, totalTasks);
          final completedCount = math.min(completedIds.length, safeTotal);
          final progressPercent = ((completedCount / safeTotal) * 100)
              .round()
              .clamp(0, 100);

          transaction.set(progressRef, {
            'poolKey': poolKey,
            'category': category,
            'taskType': taskType,
            'cycleNumber': cycleNumber,
            'completedTaskIds': completedIds.toList(),
            'completedCount': completedCount,
            'totalTasksAtLastLoad': safeTotal,
            'progressPercent': progressPercent,
            'currentTaskId': FieldValue.delete(),
            'currentTaskTitle': FieldValue.delete(),
            'lastCompletedTaskId': taskId,
            'lastCompletedTaskTitle': taskTitle,
            'lastBand': band,
            'cycleResultCount': nextCount,
            'cycleBandSum': nextBandSum,
            'cycleAverageBand': double.parse(averageBand.toStringAsFixed(2)),
            'cycleCompleted': completedCount >= safeTotal,
            'lastCompletedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Keep a simple current Writing band on the user profile while
          // preserving full result history in writing_results.
          transaction.set(userRef, {
            'writingBand': band,
            'lastWritingCycle': cycleNumber,
            'lastWritingTaskAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        })
        .timeout(const Duration(seconds: 15));
  } catch (error, stackTrace) {
    // The AI report/result remains valid even if secondary cycle metadata fails.
    debugPrint('Writing cycle completion update failed: $error');
    debugPrintStack(stackTrace: stackTrace);
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
  int _currentCycle = 1;
  int _availableCount = 0;
  int _completedInCycle = 0;

  String get _cyclePoolKey {
    final category = _safeWritingCycleKey(widget.category);
    final type = widget.taskType == null || widget.taskType!.trim().isEmpty
        ? 'all'
        : _safeWritingCycleKey(widget.taskType!);
    return 'category_${category}_type_$type';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _tasks = [];
      _availableCount = 0;
      _completedInCycle = 0;
    });

    try {
      final offline = OfflineContentService.instance;
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
            .where((task) => task.id.isNotEmpty)
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
            .where((task) => task.id.isNotEmpty)
            .toList();
      }

      available.sort(_compareWritingTasksNaturally);
      _availableCount = available.length;

      if (available.isEmpty) {
        if (!mounted) return;
        setState(() {
          _tasks = [];
          _loading = false;
          _error = null;
        });
        return;
      }

      final selection = await _selectWritingCycleTask(available);

      if (!mounted) return;

      _currentCycle = selection.cycleNumber;

      if (!mounted) return;
      setState(() {
        // Sequential IELTS flow: expose only the current assigned test.
        // Test 1 -> Test 2 -> ... -> last test -> new cycle -> Test 1.
        _tasks = selection.task == null
            ? <WritingTask>[]
            : <WritingTask>[selection.task!];
        _completedInCycle = selection.completedInCycle;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Writing task loading failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Writing tasks could not be loaded. Check your connection and try again.';
      });
    }
  }

  Future<_WritingCycleSelection> _selectWritingCycleTask(
    List<WritingTask> tasks,
  ) async {
    if (tasks.isEmpty) {
      return const _WritingCycleSelection(
        task: null,
        cycleNumber: 1,
        completedInCycle: 0,
      );
    }

    final orderedTasks = [...tasks]..sort(_compareWritingTasksNaturally);
    final offline = OfflineContentService.instance;

    if (!offline.isOnline) {
      return _WritingCycleSelection(
        task: orderedTasks.first,
        cycleNumber: 1,
        completedInCycle: 0,
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _WritingCycleSelection(
        task: orderedTasks.first,
        cycleNumber: 1,
        completedInCycle: 0,
      );
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final progressRef = userRef.collection('writing_cycles').doc(_cyclePoolKey);

    try {
      var snapshot = await progressRef.get().timeout(
        const Duration(seconds: 10),
      );

      // One-time migration. Existing completed tasks are seeded into Cycle 1
      // so an update does not suddenly repeat old tasks for current users.
      if (!snapshot.exists) {
        final legacyCompletedIds = <String>{};
        final availableIds = orderedTasks.map((task) => task.id).toSet();

        try {
          final queue = ContentQueueService();
          final queueCompletedIds = await queue.completedIds('writing');
          legacyCompletedIds.addAll(
            queueCompletedIds.where(availableIds.contains),
          );

          final resultSnapshot = await userRef
              .collection('writing_results')
              .get()
              .timeout(const Duration(seconds: 10));

          for (final doc in resultSnapshot.docs) {
            final taskId = (doc.data()['taskId'] ?? '').toString().trim();
            if (availableIds.contains(taskId)) {
              legacyCompletedIds.add(taskId);
            }
          }
        } catch (error) {
          debugPrint('Writing cycle migration lookup failed: $error');
        }

        await progressRef.set({
          'poolKey': _cyclePoolKey,
          'category': widget.category,
          'taskType': widget.taskType,
          'cycleNumber': 1,
          'completedTaskIds': legacyCompletedIds.toList(),
          'completedCount': legacyCompletedIds.length,
          'totalTasksAtLastLoad': orderedTasks.length,
          'cycleResultCount': 0,
          'cycleBandSum': 0.0,
          'cycleAverageBand': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        snapshot = await progressRef.get().timeout(const Duration(seconds: 10));
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      var cycleNumber = _asInt(data['cycleNumber'], fallback: 1);
      var completedIds = _stringList(data['completedTaskIds']).toSet();
      final currentTaskId = (data['currentTaskId'] ?? '').toString().trim();

      final availableIds = orderedTasks.map((task) => task.id).toSet();
      completedIds = completedIds.intersection(availableIds);

      // Keep showing the assigned task until its real AI evaluation finishes.
      // Existing draft/autosave logic can therefore continue the same task.
      if (currentTaskId.isNotEmpty &&
          availableIds.contains(currentTaskId) &&
          !completedIds.contains(currentTaskId)) {
        final currentTask = orderedTasks.firstWhere(
          (task) => task.id == currentTaskId,
        );

        return _WritingCycleSelection(
          task: currentTask,
          cycleNumber: cycleNumber,
          completedInCycle: completedIds.length,
        );
      }

      var remaining = orderedTasks
          .where((task) => !completedIds.contains(task.id))
          .toList();

      // Every published task in this pool is complete.
      // Start a fresh cycle for every user and return to Test 1.
      if (remaining.isEmpty) {
        cycleNumber += 1;
        completedIds = <String>{};
        remaining = [...orderedTasks];

        await progressRef.set({
          'cycleNumber': cycleNumber,
          'completedTaskIds': <String>[],
          'completedCount': 0,
          'currentTaskId': FieldValue.delete(),
          'currentTaskTitle': FieldValue.delete(),
          'cycleResultCount': 0,
          'cycleBandSum': 0.0,
          'cycleAverageBand': 0.0,
          'cycleCompleted': false,
          'cycleStartedAt': FieldValue.serverTimestamp(),
          'lastCycleResetAt': FieldValue.serverTimestamp(),
          'totalTasksAtLastLoad': orderedTasks.length,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Sequential/stable selection: first unfinished task in natural order.
      final selected = remaining.first;

      await progressRef.set({
        'poolKey': _cyclePoolKey,
        'category': widget.category,
        'taskType': widget.taskType,
        'cycleNumber': cycleNumber,
        'currentTaskId': selected.id,
        'currentTaskTitle': selected.title,
        'completedCount': completedIds.length,
        'totalTasksAtLastLoad': orderedTasks.length,
        'lastAssignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return _WritingCycleSelection(
        task: selected,
        cycleNumber: cycleNumber,
        completedInCycle: completedIds.length,
      );
    } catch (error, stackTrace) {
      debugPrint('Writing cycle selection failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      // Fail open: a cycle metadata issue should not block Writing practice.
      return _WritingCycleSelection(
        task: orderedTasks.first,
        cycleNumber: 1,
        completedInCycle: 0,
      );
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
            const LearnerStateView.loading(
              title: 'Selecting your next writing task',
              message:
                  'Matching a fresh prompt to your mode, level and completed practice.',
              icon: Icons.edit_note_rounded,
            )
          else if (_error != null)
            LearnerStateView.error(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load writing tasks',
              message:
                  'Your drafts and feedback are safe. Check your connection and try loading the tasks again.',
              onAction: _load,
            )
          else if (_tasks.isEmpty)
            LearnerStateView.empty(
              icon: Icons.edit_note_rounded,
              title: 'No writing task available',
              message: _availableCount == 0
                  ? 'No published Writing task is available for this selection yet.'
                  : 'Your next Writing task could not be prepared. Please try again.',
              actionLabel: 'Refresh tasks',
              onAction: _load,
            )
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
              children: [
                _WritingCycleProgressCard(
                  currentNumber: math.min(
                    _completedInCycle + 1,
                    _availableCount,
                  ),
                  total: _availableCount,
                  cycleNumber: _currentCycle,
                ),
                const SizedBox(height: 12),
                _WritingTaskCard(
                  task: _tasks.first,
                  completed: false,
                  premiumLocked: false,
                  onTap: () => _showModeSheet(context, _tasks.first),
                ),
              ],
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
                  style: const TextStyle(color: WColors.muted, fontSize: 12),
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

    final canAttempt = await WritingPremiumManager.canAttemptWritingTask(
      poolKey: _cyclePoolKey,
      taskId: task.id,
    );

    if (!mounted) return;

    if (!canAttempt) {
      // The visible card became stale because its AI evaluation completed.
      // Reloading advances to the next sequential test (or starts a new cycle).
      await _load();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WritingEditorScreen(
          task: task,
          mode: mode,
          trackCycle: true,
          cyclePoolKey: _cyclePoolKey,
          cycleNumber: _currentCycle,
          cycleTotalTasks: _availableCount,
        ),
      ),
    );
  }
}

class WritingEditorScreen extends StatefulWidget {
  final WritingTask task;
  final WritingMode mode;
  final String initialAnswer;
  final String? draftId;
  final bool trackCycle;
  final String cyclePoolKey;
  final int cycleNumber;
  final int cycleTotalTasks;

  const WritingEditorScreen({
    super.key,
    required this.task,
    required this.mode,
    this.initialAnswer = '',
    this.draftId,
    this.trackCycle = false,
    this.cyclePoolKey = 'writing_all',
    this.cycleNumber = 1,
    this.cycleTotalTasks = 1,
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
        'trackCycle': widget.trackCycle,
        'cyclePoolKey': widget.cyclePoolKey,
        'cycleNumber': widget.cycleNumber,
        'cycleTotalTasks': widget.cycleTotalTasks,
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
        'trackCycle': widget.trackCycle,
        'cyclePoolKey': widget.cyclePoolKey,
        'cycleNumber': widget.cycleNumber,
        'cycleTotalTasks': widget.cycleTotalTasks,
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
            trackCycle: widget.trackCycle,
            cyclePoolKey: widget.cyclePoolKey,
            cycleNumber: widget.cycleNumber,
            cycleTotalTasks: widget.cycleTotalTasks,
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
              'trackCycle': widget.trackCycle,
              'cyclePoolKey': widget.cyclePoolKey,
              'cycleNumber': widget.cycleNumber,
              'cycleTotalTasks': widget.cycleTotalTasks,
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

              // On small screens the editor can temporarily receive a very
              // short height (for example while the keyboard is animating).
              // Do not force the suggestion strip into that constrained space.
              final canShowSuggestionStrip =
                  _practiceMode && !_fullscreen && constraints.maxHeight >= 150;

              return Column(
                children: [
                  Expanded(child: writingBox),
                  if (canShowSuggestionStrip)
                    Flexible(
                      flex: 0,
                      child: _MobileSuggestionStrip(
                        suggestions: _liveSuggestions,
                        vocabulary: widget.task.usefulVocabulary,
                      ),
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
  final bool trackCycle;
  final String cyclePoolKey;
  final int cycleNumber;
  final int cycleTotalTasks;

  const WritingEvaluationWaitingScreen({
    super.key,
    required this.submissionId,
    required this.task,
    required this.answer,
    this.trackCycle = false,
    this.cyclePoolKey = 'writing_all',
    this.cycleNumber = 1,
    this.cycleTotalTasks = 1,
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
              if (snapshot.hasError) {
                return _MessageState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Report connection interrupted',
                  subtitle:
                      'Your submission is safe. Check your connection and reopen this report in a moment.',
                  action: () => Navigator.pop(context),
                );
              }
              final data = snapshot.data?.data();
              final status = (data?['status'] ?? 'queued').toString();

              if (status == 'completed' && data?['report'] is Map) {
                final report = WritingReport.fromMap(
                  Map<String, dynamic>.from(data!['report']),
                );

                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  final user = FirebaseAuth.instance.currentUser;

                  if (trackCycle && user != null && task.id.isNotEmpty) {
                    await _completeWritingCycleAttempt(
                      user: user,
                      poolKey: cyclePoolKey,
                      category: task.taskCategory,
                      taskType: task.taskType,
                      cycleNumber: cycleNumber,
                      taskId: task.id,
                      taskTitle: task.title,
                      totalTasks: cycleTotalTasks,
                      band: report.overallBand,
                    );
                  }

                  if (!context.mounted) return;

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
                  subtitle:
                      'We could not complete this writing report. Your response is safe—please try the evaluation again.',
                  action: () => Navigator.pop(context),
                );
              }

              return const IeltsAiAnalysisLoader(
                title: 'Building your writing report',
                subtitle:
                    'Your response is being assessed against all four IELTS Writing criteria.',
                steps: [
                  'Assessing task response',
                  'Mapping coherence and cohesion',
                  'Reviewing vocabulary and grammar',
                  'Preparing actionable feedback',
                ],
                accent: WColors.cyan,
                icon: Icons.auto_awesome_rounded,
              );
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

  List<(String, WritingCriterion)> get _criteria => [
    (
      task.taskCategory.toLowerCase().contains('task_1')
          ? 'Task Achievement'
          : 'Task Response',
      report.taskAchievement,
    ),
    ('Coherence & Cohesion', report.coherenceAndCohesion),
    ('Lexical Resource', report.lexicalResource),
    ('Grammatical Range & Accuracy', report.grammaticalRangeAndAccuracy),
  ];

  List<String> get _strengths => _criteria
      .expand((item) => item.$2.strengths.map((text) => '${item.$1}: $text'))
      .toSet()
      .take(5)
      .toList();

  List<String> get _improvements => _criteria
      .expand((item) => item.$2.improvements.map((text) => '${item.$1}: $text'))
      .toSet()
      .take(5)
      .toList();

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
              IeltsResultHero(
                accent: WColors.cyan,
                band: report.overallBand,
                title: 'Estimated Overall Band',
                eyebrow: 'AI WRITING EVALUATION',
                summary: report.summary,
                aiEstimated: true,
                meta: [
                  IeltsResultMetric(
                    value: '${report.wordCount}',
                    label: 'Words written',
                    icon: Icons.notes_rounded,
                  ),
                  IeltsResultMetric(
                    value: '${task.minimumWords}',
                    label: 'Task minimum',
                    icon: Icons.flag_outlined,
                  ),
                  IeltsResultMetric(
                    value: report.minimumWordsMet ? 'Met' : 'Below',
                    label: 'Word requirement',
                    icon: report.minimumWordsMet
                        ? Icons.check_circle_outline_rounded
                        : Icons.warning_amber_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              IeltsResultSectionTitle(
                title: 'IELTS criterion scores',
                subtitle:
                    'A separate estimated band for every official scoring dimension',
                icon: Icons.radar_rounded,
                accent: WColors.cyan,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 760 ? 4 : 2;
                  const spacing = 10.0;
                  final width =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                      columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: _criteria
                        .map(
                          (item) => SizedBox(
                            width: width,
                            child: IeltsCriterionCard(
                              title: item.$1,
                              band: item.$2.band,
                              feedback: item.$2.feedback,
                              accent: WColors.cyan,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 22),
              IeltsResultSectionTitle(
                title: 'What matters most',
                subtitle:
                    'Your strongest evidence and highest-impact improvements',
                icon: Icons.insights_rounded,
                accent: WColors.cyan,
              ),
              const SizedBox(height: 12),
              IeltsInsightCard(
                title: 'Strengths',
                items: _strengths,
                tone: IeltsInsightTone.strength,
                emptyMessage:
                    'The report did not identify a specific strength for this response.',
              ),
              const SizedBox(height: 10),
              IeltsInsightCard(
                title: 'Priority improvements',
                items: _improvements,
                tone: IeltsInsightTone.improvement,
                emptyMessage: 'No major criterion weakness was identified.',
              ),
              const SizedBox(height: 10),
              IeltsInsightCard(
                title: 'Recommended next practice',
                items: report.actionPlan,
                tone: IeltsInsightTone.recommendation,
                emptyMessage:
                    'Rewrite one paragraph using the feedback above, then compare both versions.',
              ),
              const SizedBox(height: 22),
              IeltsResultSectionTitle(
                title: 'Detailed criterion feedback',
                subtitle: 'Open a criterion for its complete AI assessment',
                icon: Icons.rate_review_outlined,
                accent: WColors.cyan,
              ),
              const SizedBox(height: 12),
              ..._criteria.map(
                (item) =>
                    _WritingCriterionDetail(title: item.$1, criterion: item.$2),
              ),
              const SizedBox(height: 10),
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
                title: 'Corrections & Improved Examples',
                icon: Icons.compare_arrows_rounded,
                child: report.sentenceCorrections.isEmpty
                    ? const _EmptyFeedback()
                    : Column(
                        children: report.sentenceCorrections
                            .map(
                              (item) => IeltsCorrectionTile(
                                original: (item['original'] ?? '').toString(),
                                improved: (item['improved'] ?? '').toString(),
                                reason: (item['reason'] ?? '').toString(),
                                accent: WColors.cyan,
                              ),
                            )
                            .toList(),
                      ),
              ),
              _ComparisonTabs(
                answer: answer,
                improved: report.improvedVersion,
                model: task.band8ModelAnswer,
              ),
              const SizedBox(height: 22),
              IeltsResultActions(
                primaryLabel: 'Practice Again',
                primaryIcon: Icons.edit_note_rounded,
                onPrimary: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WritingEditorScreen(
                      task: task,
                      mode: WritingMode.practice,
                    ),
                  ),
                ),
                secondaryLabel: 'Back to Writing',
                secondaryIcon: Icons.library_books_outlined,
                onSecondary: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WritingChecker()),
                  (route) => route.isFirst,
                ),
                accent: WColors.cyan,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WritingCriterionDetail extends StatelessWidget {
  const _WritingCriterionDetail({required this.title, required this.criterion});
  final String title;
  final WritingCriterion criterion;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: _panelDecoration(),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: WColors.cyan,
        collapsedIconColor: WColors.muted,
        title: Text(
          title,
          style: const TextStyle(
            color: WColors.text,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              criterion.band.toStringAsFixed(1),
              style: const TextStyle(
                color: WColors.cyan,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              criterion.feedback,
              style: const TextStyle(
                color: WColors.secondary,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
              if (snapshot.hasError) {
                return const LearnerStateView.error(
                  title: 'Drafts could not be synced',
                  message:
                      'Your locally saved work is safe. Check your connection and reopen Saved Drafts.',
                  icon: Icons.save_outlined,
                );
              }
              if (!snapshot.hasData) {
                return const LearnerStateView.loading(
                  title: 'Loading your drafts',
                  message:
                      'Restoring your saved writing and latest autosave points.',
                  icon: Icons.save_rounded,
                );
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
                    subtitle: [
                      if (_asInt(data['cycleNumber'], fallback: 0) > 0)
                        'Cycle ${_asInt(data['cycleNumber'], fallback: 1)}',
                      '${data['wordCount'] ?? 0} words',
                      (data['taskType'] ?? '').toString(),
                    ].where((item) => item.trim().isNotEmpty).join(' • '),
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
              if (snapshot.hasError) {
                return const LearnerStateView.error(
                  title: 'Writing history could not be synced',
                  message:
                      'Your completed evaluations are safe. Check your connection and reopen this screen.',
                  icon: Icons.history_rounded,
                );
              }
              if (!snapshot.hasData) {
                return const LearnerStateView.loading(
                  title: 'Loading your writing history',
                  message:
                      'Bringing together recent bands, task types and feedback.',
                  icon: Icons.history_rounded,
                );
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
              if (snapshot.hasError) {
                return const LearnerStateView.error(
                  title: 'Model answers are temporarily unavailable',
                  message:
                      'Check your connection and reopen the library to try again.',
                  icon: Icons.library_books_outlined,
                );
              }
              if (!snapshot.hasData) {
                return const LearnerStateView.loading(
                  title: 'Curating model answers',
                  message:
                      'Loading high-band examples for the available IELTS task types.',
                  icon: Icons.library_books_rounded,
                );
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
                          fontSize: 12,
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
                      fontSize: 11.5,
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
  final String type;
  final String title;
  final String description;
  final String unit;
  final List<String> categories;
  final List<Map<String, dynamic>> series;
  final List<String> stages;
  final List<String> locations;
  final List<WritingMapPanel> mapPanels;

  const WritingVisualData({
    required this.type,
    required this.title,
    required this.description,
    required this.unit,
    required this.categories,
    required this.series,
    required this.stages,
    required this.locations,
    required this.mapPanels,
  });

  const WritingVisualData.empty()
    : type = '',
      title = '',
      description = '',
      unit = '',
      categories = const [],
      series = const [],
      stages = const [],
      locations = const [],
      mapPanels = const [];

  factory WritingVisualData.fromMap(Map<String, dynamic> map) {
    return WritingVisualData(
      type: (map['type'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      unit: (map['unit'] ?? '').toString(),
      categories: _stringList(map['categories']),
      series: _list(
        map['series'],
      ).map((item) => Map<String, dynamic>.from(item as Map)).toList(),
      stages: _stringList(map['stages']),
      locations: _stringList(map['locations']),
      mapPanels: _list(map['mapPanels'])
          .whereType<Map>()
          .map(
            (item) => WritingMapPanel.fromMap(Map<String, dynamic>.from(item)),
          )
          .where((panel) => panel.features.isNotEmpty)
          .toList(),
    );
  }

  bool get hasRenderableVisual =>
      mapPanels.isNotEmpty ||
      series.isNotEmpty ||
      stages.isNotEmpty ||
      locations.isNotEmpty;
}

class WritingMapPanel {
  final String title;
  final List<WritingMapFeature> features;

  const WritingMapPanel({required this.title, required this.features});

  factory WritingMapPanel.fromMap(Map<String, dynamic> map) {
    return WritingMapPanel(
      title: (map['title'] ?? '').toString().trim(),
      features: _list(map['features'])
          .whereType<Map>()
          .map(
            (item) =>
                WritingMapFeature.fromMap(Map<String, dynamic>.from(item)),
          )
          .where((feature) => feature.label.isNotEmpty)
          .toList(),
    );
  }
}

class WritingMapFeature {
  final String label;
  final String kind;
  final double x;
  final double y;
  final double width;
  final double height;

  const WritingMapFeature({
    required this.label,
    required this.kind,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory WritingMapFeature.fromMap(Map<String, dynamic> map) {
    double percent(dynamic value, double fallback) {
      final number = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      return (number ?? fallback).clamp(0.0, 100.0);
    }

    return WritingMapFeature(
      label: (map['label'] ?? '').toString().trim(),
      kind: (map['kind'] ?? 'area').toString().trim().toLowerCase(),
      x: percent(map['x'], 10),
      y: percent(map['y'], 10),
      width: percent(map['width'], 24).clamp(8.0, 70.0),
      height: percent(map['height'], 16).clamp(7.0, 55.0),
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
    final canGoBack = Navigator.of(context).canPop();

    return Row(
      children: [
        canGoBack
            ? _WritingBackButton(onPressed: () => Navigator.pop(context))
            : const _GradientIcon(icon: Icons.draw_rounded),
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
                  fontSize: 11.5,
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
                  fontSize: 12,
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

class _WritingBackButton extends StatelessWidget {
  const _WritingBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: IconButton(
        tooltip: 'Back to Home',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: WColors.text,
          backgroundColor: WColors.surface.withOpacity(.94),
          side: BorderSide(color: Colors.white.withOpacity(.08)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
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
                        fontSize: 12,
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
                      fontSize: 12,
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
                        fontSize: 11.5,
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
                    fontSize: 12,
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

class _WritingCycleProgressCard extends StatelessWidget {
  const _WritingCycleProgressCard({
    required this.currentNumber,
    required this.total,
    required this.cycleNumber,
  });

  final int currentNumber;
  final int total;
  final int cycleNumber;

  @override
  Widget build(BuildContext context) {
    final safeTotal = math.max(1, total);
    final safeCurrent = currentNumber.clamp(1, safeTotal);
    final progress = (safeCurrent - 1) / safeTotal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Test $safeCurrent of $safeTotal',
                  style: const TextStyle(
                    color: WColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Cycle $cycleNumber',
                style: const TextStyle(
                  color: WColors.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: WColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(WColors.cyan),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Only your next unfinished test is shown. Completing the final test starts a fresh cycle from Test 1.',
            style: TextStyle(color: WColors.muted, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _WritingTaskCard extends StatelessWidget {
  final WritingTask task;
  final bool completed;
  final bool premiumLocked;
  final VoidCallback onTap;

  const _WritingTaskCard({
    required this.task,
    required this.completed,
    required this.premiumLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = premiumLocked ? WColors.violet : WColors.cyan;

    return _TapCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              premiumLocked
                  ? Icons.workspace_premium_rounded
                  : completed
                  ? Icons.check_circle_rounded
                  : Icons.edit_note_rounded,
              color: accent,
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
                        task.title,
                        style: const TextStyle(
                          color: WColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: accent.withOpacity(.28)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            premiumLocked
                                ? Icons.workspace_premium_rounded
                                : completed
                                ? Icons.check_rounded
                                : Icons.lock_open_rounded,
                            color: accent,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            premiumLocked
                                ? 'PREMIUM'
                                : completed
                                ? 'COMPLETED'
                                : 'FREE',
                            style: TextStyle(
                              color: accent,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  premiumLocked
                      ? 'Free attempt completed. Premium is required to repeat this test.'
                      : task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WColors.muted,
                    fontSize: 11.5,
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
                        fontSize: 12,
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
                  style: const TextStyle(color: WColors.muted, fontSize: 12),
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
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          if (task.taskCategory == 'academic_task_1' &&
              task.visualData.hasRenderableVisual) ...[
            const SizedBox(height: 14),
            _AcademicTaskVisual(
              taskType: task.taskType,
              visual: task.visualData,
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
                          fontSize: 11.5,
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

class _AcademicTaskVisual extends StatelessWidget {
  const _AcademicTaskVisual({required this.taskType, required this.visual});

  final String taskType;
  final WritingVisualData visual;

  bool get _isMap =>
      taskType.trim().toLowerCase() == 'map' ||
      visual.type.trim().toLowerCase() == 'map';

  bool get _isProcess =>
      taskType.trim().toLowerCase().contains('process') ||
      visual.type.trim().toLowerCase() == 'process';

  @override
  Widget build(BuildContext context) {
    if (_isMap) {
      return _WritingMapVisual(visual: visual);
    }

    if (_isProcess && visual.stages.isNotEmpty) {
      return _WritingProcessVisual(visual: visual);
    }

    if (visual.series.isNotEmpty && visual.categories.isNotEmpty) {
      return _WritingDataVisual(taskType: taskType, visual: visual);
    }

    if (visual.locations.isNotEmpty) {
      return _LegacyMapInformation(visual: visual);
    }

    return const SizedBox.shrink();
  }
}

class _WritingMapVisual extends StatelessWidget {
  const _WritingMapVisual({required this.visual});

  final WritingVisualData visual;

  @override
  Widget build(BuildContext context) {
    final panels = visual.mapPanels;

    if (panels.isEmpty) {
      return _LegacyMapInformation(visual: visual);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WColors.background.withOpacity(.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WColors.cyan.withOpacity(.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_outlined, color: WColors.cyan, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  visual.title.isEmpty ? 'Map comparison' : visual.title,
                  style: const TextStyle(
                    color: WColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const _VisualHintBadge(text: 'PINCH / TAP TO VIEW'),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns =
                  constraints.maxWidth >= 520 && panels.length >= 2;

              if (twoColumns) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: panels
                      .take(2)
                      .map(
                        (panel) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: panel == panels.first ? 6 : 0,
                              left: panel == panels.first ? 0 : 6,
                            ),
                            child: _MapPanelCard(panel: panel),
                          ),
                        ),
                      )
                      .toList(),
                );
              }

              return Column(
                children: panels
                    .map(
                      (panel) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MapPanelCard(panel: panel),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _WritingVisualFullscreen(
                      title: visual.title.isEmpty
                          ? 'IELTS Writing Map'
                          : visual.title,
                      child: _WritingMapVisualFullscreen(visual: visual),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
              label: const Text('View full screen'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPanelCard extends StatelessWidget {
  const _MapPanelCard({required this.panel});

  final WritingMapPanel panel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: WColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            color: WColors.cyan.withOpacity(.07),
            child: Text(
              panel.title.isEmpty ? 'Map' : panel.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: WColors.text,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ),
          AspectRatio(aspectRatio: 1.42, child: _SchematicMap(panel: panel)),
        ],
      ),
    );
  }
}

class _SchematicMap extends StatelessWidget {
  const _SchematicMap({required this.panel});

  final WritingMapPanel panel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: WColors.background.withOpacity(.45),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: const _MapGridPainter()),
              ),
              ...panel.features.map((feature) {
                final left = constraints.maxWidth * feature.x / 100;
                final top = constraints.maxHeight * feature.y / 100;
                final width = constraints.maxWidth * feature.width / 100;
                final height = constraints.maxHeight * feature.height / 100;

                return Positioned(
                  left: left,
                  top: top,
                  width: math.min(
                    width,
                    math.max(24.0, constraints.maxWidth - left - 4),
                  ),
                  height: math.min(
                    height,
                    math.max(20.0, constraints.maxHeight - top - 4),
                  ),
                  child: _MapFeatureTile(feature: feature),
                );
              }),
              Positioned(
                right: 8,
                bottom: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: WColors.surface.withOpacity(.90),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: WColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.explore_outlined,
                        color: WColors.muted,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'N',
                        style: TextStyle(
                          color: WColors.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapFeatureTile extends StatelessWidget {
  const _MapFeatureTile({required this.feature});

  final WritingMapFeature feature;

  IconData get _icon {
    switch (feature.kind) {
      case 'road':
        return Icons.alt_route_rounded;
      case 'water':
      case 'river':
      case 'lake':
        return Icons.water_rounded;
      case 'trees':
      case 'park':
      case 'garden':
        return Icons.park_rounded;
      case 'parking':
        return Icons.local_parking_rounded;
      case 'building':
        return Icons.apartment_rounded;
      case 'path':
        return Icons.route_rounded;
      case 'playground':
        return Icons.sports_soccer_rounded;
      default:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WColors.cyan.withOpacity(.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: WColors.cyan.withOpacity(.42), width: 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, color: WColors.cyan, size: 15),
            const SizedBox(height: 2),
            Text(
              feature.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: WColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = WColors.border.withOpacity(.35)
      ..strokeWidth = .8;

    for (var i = 1; i < 5; i++) {
      final dx = size.width * i / 5;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), linePaint);
    }

    for (var i = 1; i < 4; i++) {
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), linePaint);
    }

    final roadPaint = Paint()
      ..color = WColors.secondary.withOpacity(.16)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * .08, size.height * .78),
      Offset(size.width * .92, size.height * .78),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) => false;
}

class _LegacyMapInformation extends StatelessWidget {
  const _LegacyMapInformation({required this.visual});

  final WritingVisualData visual;

  @override
  Widget build(BuildContext context) {
    if (visual.locations.isEmpty) return const SizedBox.shrink();

    final groups = <String, List<String>>{};

    for (final raw in visual.locations) {
      final text = raw.trim();
      final match = RegExp(
        r'^\s*((?:19|20)\d{2}|before|after|current|proposed)\s*[:\-–]\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(text);

      final key = match == null ? 'Map features' : match.group(1)!.trim();
      final value = match == null ? text : match.group(2)!.trim();
      groups.putIfAbsent(key, () => <String>[]).add(value);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WColors.cyan.withOpacity(.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map_outlined, color: WColors.cyan, size: 18),
              SizedBox(width: 8),
              Text(
                'Map information',
                style: TextStyle(
                  color: WColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ...groups.entries.map(
            (entry) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: WColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: WColors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...entry.value.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(color: WColors.cyan),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: WColors.secondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
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

class _WritingProcessVisual extends StatelessWidget {
  const _WritingProcessVisual({required this.visual});

  final WritingVisualData visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WColors.cyan.withOpacity(.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            visual.title.isEmpty ? 'Process diagram' : visual.title,
            style: const TextStyle(
              color: WColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(visual.stages.length, (index) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: WColors.cyan.withOpacity(.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: WColors.cyan.withOpacity(.35)),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: WColors.cyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      visual.stages[index],
                      style: const TextStyle(
                        color: WColors.secondary,
                        fontSize: 9.8,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _WritingDataVisual extends StatelessWidget {
  const _WritingDataVisual({required this.taskType, required this.visual});

  final String taskType;
  final WritingVisualData visual;

  @override
  Widget build(BuildContext context) {
    final maxColumns = math.min(visual.categories.length, 6);
    final categories = visual.categories.take(maxColumns).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WColors.cyan.withOpacity(.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: WColors.cyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  visual.title.isEmpty ? taskType : visual.title,
                  style: const TextStyle(
                    color: WColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
              ),
              if (visual.unit.isNotEmpty) _VisualHintBadge(text: visual.unit),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 40,
              columnSpacing: 18,
              horizontalMargin: 8,
              columns: [
                const DataColumn(
                  label: Text(
                    'Series',
                    style: TextStyle(
                      color: WColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ...categories.map(
                  (category) => DataColumn(
                    label: Text(
                      category,
                      style: const TextStyle(
                        color: WColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
              rows: visual.series.map((series) {
                final values = _list(series['values']);
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        (series['name'] ?? 'Series').toString(),
                        style: const TextStyle(
                          color: WColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ...List.generate(categories.length, (index) {
                      final value = index < values.length ? values[index] : '—';
                      return DataCell(
                        Text(
                          value.toString(),
                          style: const TextStyle(
                            color: WColors.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualHintBadge extends StatelessWidget {
  const _VisualHintBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: WColors.cyan.withOpacity(.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: WColors.cyan,
          fontSize: 6.8,
          fontWeight: FontWeight.w900,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class _WritingVisualFullscreen extends StatelessWidget {
  const _WritingVisualFullscreen({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.background,
      appBar: AppBar(
        backgroundColor: WColors.background,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: InteractiveViewer(
        minScale: .8,
        maxScale: 4,
        boundaryMargin: const EdgeInsets.all(80),
        child: Center(child: child),
      ),
    );
  }
}

class _WritingMapVisualFullscreen extends StatelessWidget {
  const _WritingMapVisualFullscreen({required this.visual});

  final WritingVisualData visual;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 900,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: visual.mapPanels
              .take(2)
              .map(
                (panel) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: _MapPanelCard(panel: panel),
                  ),
                ),
              )
              .toList(),
        ),
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
                fontSize: 11.5,
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
                fontSize: 11.5,
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
                fontSize: 11.5,
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
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            criterion.feedback,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: WColors.muted,
              fontSize: 12,
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: WColors.text,
                    fontWeight: FontWeight.w900,
                  ),
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
              fontSize: 12,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              body,
              style: const TextStyle(
                color: WColors.secondary,
                fontSize: 11.5,
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
                    fontSize: 12,
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
          style: const TextStyle(color: WColors.muted, fontSize: 11.5),
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
