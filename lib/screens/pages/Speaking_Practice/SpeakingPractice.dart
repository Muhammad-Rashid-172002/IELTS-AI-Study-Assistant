import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyproject/offline/offline_content_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/resources/components/learner_state_view.dart';
import 'package:fyproject/resources/components/ielts_result_widgets.dart';
import 'package:fyproject/screens/pages/Subscription/Subscription_screen.dart';
import 'package:fyproject/screens/content_queue_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class SpeakingPremiumManager {
  SpeakingPremiumManager._();

  static const int freeUsesPerModePerDay = 1;
  static const int freeHistoryItems = 5;

  static const Set<String> premiumOnlyModes = {'ai_partner', 'full_test'};

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

  static Future<SpeakingHomeAccess> loadHomeAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SpeakingHomeAccess(
        isPremium: false,
        counts: <String, int>{},
      );
    }

    // Offline cached Speaking practice should remain accessible.
    if (!OfflineContentService.instance.isOnline) {
      return const SpeakingHomeAccess(
        isPremium: false,
        counts: <String, int>{},
        offlineMode: true,
      );
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final usageRef = userRef.collection('feature_usage').doc('speaking');

    try {
      final docs = await Future.wait([
        userRef.get().timeout(const Duration(seconds: 10)),
        usageRef.get().timeout(const Duration(seconds: 10)),
      ]);

      final userData =
          (docs[0] as DocumentSnapshot<Map<String, dynamic>>).data() ??
          const <String, dynamic>{};

      final isPremium = isPremiumFromData(userData);
      if (isPremium) {
        return const SpeakingHomeAccess(
          isPremium: true,
          counts: <String, int>{},
        );
      }

      final usage =
          (docs[1] as DocumentSnapshot<Map<String, dynamic>>).data() ??
          const <String, dynamic>{};

      final today = _dayKey(DateTime.now());
      final storedDay = (usage['dailyKey'] ?? '').toString();
      final counts = storedDay == today
          ? _intMap(usage['dailyCounts'])
          : <String, int>{};

      return SpeakingHomeAccess(isPremium: false, counts: counts);
    } catch (error) {
      debugPrint('Speaking premium status check failed: $error');
      return const SpeakingHomeAccess(
        isPremium: false,
        counts: <String, int>{},
      );
    }
  }

  static Future<SpeakingAccessDecision> checkMode(String mode) async {
    final home = await loadHomeAccess();

    if (home.offlineMode) {
      return const SpeakingAccessDecision(
        allowed: true,
        premium: false,
        used: 0,
        limit: freeUsesPerModePerDay,
        offlineBypass: true,
      );
    }

    if (home.isPremium) {
      return const SpeakingAccessDecision(
        allowed: true,
        premium: true,
        used: 0,
        limit: freeUsesPerModePerDay,
      );
    }

    if (premiumOnlyModes.contains(mode)) {
      return const SpeakingAccessDecision(
        allowed: false,
        premium: false,
        used: 0,
        limit: 0,
        premiumOnly: true,
      );
    }

    final used = home.counts[mode] ?? 0;
    return SpeakingAccessDecision(
      allowed: used < freeUsesPerModePerDay,
      premium: false,
      used: used,
      limit: freeUsesPerModePerDay,
    );
  }

  static Future<SpeakingAccessDecision> consumeMode(String mode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SpeakingAccessDecision(
        allowed: false,
        premium: false,
        used: 0,
        limit: freeUsesPerModePerDay,
      );
    }

    if (!OfflineContentService.instance.isOnline) {
      return const SpeakingAccessDecision(
        allowed: true,
        premium: false,
        used: 0,
        limit: freeUsesPerModePerDay,
        offlineBypass: true,
      );
    }

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final usageRef = userRef.collection('feature_usage').doc('speaking');

    return firestore
        .runTransaction<SpeakingAccessDecision>((tx) async {
          final userDoc = await tx.get(userRef);
          final userData = userDoc.data() ?? const <String, dynamic>{};

          if (isPremiumFromData(userData)) {
            return const SpeakingAccessDecision(
              allowed: true,
              premium: true,
              used: 0,
              limit: freeUsesPerModePerDay,
            );
          }

          if (premiumOnlyModes.contains(mode)) {
            return const SpeakingAccessDecision(
              allowed: false,
              premium: false,
              used: 0,
              limit: 0,
              premiumOnly: true,
            );
          }

          final usageDoc = await tx.get(usageRef);
          final usage = usageDoc.data() ?? const <String, dynamic>{};

          final today = _dayKey(DateTime.now());
          final storedDay = (usage['dailyKey'] ?? '').toString();
          final counts = storedDay == today
              ? _intMap(usage['dailyCounts'])
              : <String, int>{};

          final used = counts[mode] ?? 0;
          if (used >= freeUsesPerModePerDay) {
            return SpeakingAccessDecision(
              allowed: false,
              premium: false,
              used: used,
              limit: freeUsesPerModePerDay,
            );
          }

          counts[mode] = used + 1;

          tx.set(usageRef, {
            'dailyKey': today,
            'dailyCounts': counts,
            'lastMode': mode,
            'lastUsedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return SpeakingAccessDecision(
            allowed: true,
            premium: false,
            used: used + 1,
            limit: freeUsesPerModePerDay,
          );
        })
        .timeout(const Duration(seconds: 15));
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

class SpeakingHomeAccess {
  const SpeakingHomeAccess({
    required this.isPremium,
    required this.counts,
    this.offlineMode = false,
  });

  final bool isPremium;
  final Map<String, int> counts;
  final bool offlineMode;

  int usedFor(String mode) => counts[mode] ?? 0;

  bool availableFor(String mode) {
    if (offlineMode || isPremium) return true;
    if (SpeakingPremiumManager.premiumOnlyModes.contains(mode)) return false;
    return usedFor(mode) < SpeakingPremiumManager.freeUsesPerModePerDay;
  }
}

class SpeakingAccessDecision {
  const SpeakingAccessDecision({
    required this.allowed,
    required this.premium,
    required this.used,
    required this.limit,
    this.premiumOnly = false,
    this.offlineBypass = false,
  });

  final bool allowed;
  final bool premium;
  final int used;
  final int limit;
  final bool premiumOnly;
  final bool offlineBypass;
}

Future<void> _openSpeakingPremium(
  BuildContext context, {
  String source = 'speaking',
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const SubscriptionScreen(),
      settings: RouteSettings(name: '/premium', arguments: {'source': source}),
    ),
  );
}

Future<void> _showSpeakingPremiumSheet(
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
            color: SColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: SColors.violet.withOpacity(.34)),
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
                    color: SColors.border,
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
                    colors: [SColors.violet, SColors.cyan],
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
                  color: SColors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                style: const TextStyle(
                  color: SColors.secondary,
                  fontSize: 11.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              const _SpeakingPremiumBenefit(
                icon: Icons.all_inclusive_rounded,
                text: 'Unlimited Speaking practice',
              ),
              const _SpeakingPremiumBenefit(
                icon: Icons.smart_toy_outlined,
                text: 'AI Speaking Partner and Full Speaking Test',
              ),
              const _SpeakingPremiumBenefit(
                icon: Icons.analytics_outlined,
                text: 'Complete AI pronunciation and fluency report',
              ),
              const _SpeakingPremiumBenefit(
                icon: Icons.history_rounded,
                text: 'Extended Speaking result history',
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
                    backgroundColor: SColors.violet,
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
    await _openSpeakingPremium(context, source: title);
  }
}

class _SpeakingPremiumBenefit extends StatelessWidget {
  const _SpeakingPremiumBenefit({required this.icon, required this.text});

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
              color: SColors.green.withOpacity(.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: SColors.green, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: SColors.secondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: SColors.green,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class SpeakingPractice extends StatelessWidget {
  const SpeakingPractice({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SpeakingHomeAccess>(
      future: SpeakingPremiumManager.loadHomeAccess(),
      builder: (context, snapshot) {
        final access =
            snapshot.data ??
            const SpeakingHomeAccess(isPremium: false, counts: <String, int>{});

        return Scaffold(
          backgroundColor: SColors.background,
          body: Stack(
            children: [
              const Positioned.fill(child: _SpeakingBackground()),
              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
                        child: _SpeakingHeader(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                        child: _SpeakingPlanCard(access: access),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(18, 22, 18, 12),
                        child: _SectionTitle(
                          title: 'Speaking Modes',
                          subtitle:
                              'Practice a complete test or focus on one speaking skill',
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final mode = SpeakingModeOption.values[index];
                          return _ModeCard(
                            mode: mode,
                            access: access,
                            onTap: () =>
                                _openMode(context, mode, access: access),
                          );
                        }, childCount: SpeakingModeOption.values.length),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 11,
                              crossAxisSpacing: 11,
                              mainAxisExtent: 160,
                            ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(18, 24, 18, 12),
                        child: _SectionTitle(
                          title: 'Recent Speaking Results',
                          subtitle: 'Your latest estimated bands and feedback',
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                        child: _RecentSpeakingResults(
                          userId: FirebaseAuth.instance.currentUser?.uid,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _openMode(
    BuildContext context,
    SpeakingModeOption option, {
    required SpeakingHomeAccess access,
  }) async {
    if (!access.offlineMode && !access.isPremium && option.premiumOnly) {
      await _showSpeakingPremiumSheet(
        context,
        title: '${option.title} is Premium',
        message:
            '${option.title} is included with IELTS AI Master Premium. '
            'Upgrade for unlimited Speaking practice and advanced AI evaluation.',
      );
      return;
    }

    if (!access.offlineMode &&
        !access.isPremium &&
        access.usedFor(option.key) >=
            SpeakingPremiumManager.freeUsesPerModePerDay) {
      await _showSpeakingPremiumSheet(
        context,
        title: 'Free Speaking limit reached',
        message:
            'You already used today’s free ${option.title} activity. '
            'Free users receive 1 activity per Speaking mode each day. '
            'Upgrade to Premium to practice without limits.',
      );
      return;
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpeakingTestBrowserScreen(mode: option.key),
      ),
    );
  }
}

class _SpeakingCycleSelection {
  final SpeakingTest? test;
  final int cycleNumber;
  final int completedInCycle;

  const _SpeakingCycleSelection({
    required this.test,
    required this.cycleNumber,
    required this.completedInCycle,
  });
}

String _safeSpeakingCycleKey(String value) {
  final cleaned = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  return cleaned.isEmpty ? 'all' : cleaned;
}

int _compareSpeakingTestsNaturally(SpeakingTest a, SpeakingTest b) {
  final aNumber = _firstSpeakingNumber(a.title);
  final bNumber = _firstSpeakingNumber(b.title);

  if (aNumber != null && bNumber != null && aNumber != bNumber) {
    return aNumber.compareTo(bNumber);
  }

  final titleCompare = a.title.toLowerCase().compareTo(b.title.toLowerCase());

  if (titleCompare != 0) return titleCompare;

  return a.id.compareTo(b.id);
}

int? _firstSpeakingNumber(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(0)!);
}

Future<void> _completeSpeakingCycleAttempt({
  required User user,
  required String poolKey,
  required String mode,
  required int cycleNumber,
  required String testId,
  required String testTitle,
  required int totalTests,
  required double band,
}) async {
  if (!OfflineContentService.instance.isOnline) return;

  final firestore = FirebaseFirestore.instance;
  final userRef = firestore.collection('users').doc(user.uid);
  final progressRef = userRef.collection('speaking_cycles').doc(poolKey);

  try {
    await firestore
        .runTransaction((transaction) async {
          final snapshot = await transaction.get(progressRef);
          final data = snapshot.data() ?? <String, dynamic>{};

          final storedCycle = _asInt(data['cycleNumber'], cycleNumber);
          if (storedCycle != cycleNumber) return;

          final completedIds = _stringList(data['completedTestIds']).toSet();
          final alreadyCompleted = completedIds.contains(testId);

          if (!alreadyCompleted) {
            completedIds.add(testId);
          }

          final previousCount = _asInt(data['cycleResultCount'], 0);
          final previousBandSum = _asDouble(data['cycleBandSum']);

          final nextCount = alreadyCompleted
              ? previousCount
              : previousCount + 1;
          final nextBandSum = alreadyCompleted
              ? previousBandSum
              : previousBandSum + band;

          final averageBand = nextCount == 0 ? 0.0 : nextBandSum / nextCount;

          final safeTotal = math.max(1, totalTests);
          final completedCount = math.min(completedIds.length, safeTotal);
          final progressPercent = ((completedCount / safeTotal) * 100)
              .round()
              .clamp(0, 100);

          transaction.set(progressRef, {
            'poolKey': poolKey,
            'mode': mode,
            'cycleNumber': cycleNumber,
            'completedTestIds': completedIds.toList(),
            'completedCount': completedCount,
            'totalTestsAtLastLoad': safeTotal,
            'progressPercent': progressPercent,
            'currentTestId': FieldValue.delete(),
            'currentTestTitle': FieldValue.delete(),
            'lastCompletedTestId': testId,
            'lastCompletedTestTitle': testTitle,
            'lastBand': band,
            'cycleResultCount': nextCount,
            'cycleBandSum': nextBandSum,
            'cycleAverageBand': double.parse(averageBand.toStringAsFixed(2)),
            'cycleCompleted': completedCount >= safeTotal,
            'lastCompletedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          transaction.set(userRef, {
            'speakingBand': band,
            'lastSpeakingCycle': cycleNumber,
            'lastSpeakingTestAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        })
        .timeout(const Duration(seconds: 15));
  } catch (error, stackTrace) {
    debugPrint('Speaking cycle completion update failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class SpeakingTestBrowserScreen extends StatefulWidget {
  final String mode;

  const SpeakingTestBrowserScreen({super.key, required this.mode});

  @override
  State<SpeakingTestBrowserScreen> createState() =>
      _SpeakingTestBrowserScreenState();
}

class _SpeakingTestBrowserScreenState extends State<SpeakingTestBrowserScreen> {
  bool _loading = true;
  String? _error;
  List<SpeakingTest> _tests = [];
  int _currentCycle = 1;
  int _availableCount = 0;

  String get _cyclePoolKey => 'mode_${_safeSpeakingCycleKey(widget.mode)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _tests = [];
      _availableCount = 0;
    });

    try {
      final offline = OfflineContentService.instance;
      List<SpeakingTest> available;

      try {
        final published = await FirebaseFirestore.instance
            .collection('speaking_tests')
            .where('status', isEqualTo: 'published')
            .limit(200)
            .get();

        await offline.cacheMany(
          module: 'speaking',
          items: published.docs.map((doc) => MapEntry(doc.id, doc.data())),
        );

        available = published.docs
            .where((doc) => doc.data()['mode'] == widget.mode)
            .map(SpeakingTest.fromDocument)
            .where((test) => test.id.isNotEmpty && test.parts.isNotEmpty)
            .toList();
      } catch (_) {
        available = offline
            .cachedContent(
              'speaking',
              where: (data) => data['mode'] == widget.mode,
            )
            .map(
              (data) => SpeakingTest.fromMap(
                data,
                id: data['_offlineId']?.toString() ?? '',
              ),
            )
            .where((test) => test.id.isNotEmpty && test.parts.isNotEmpty)
            .toList();
      }

      available.sort(_compareSpeakingTestsNaturally);
      _availableCount = available.length;

      if (available.isEmpty) {
        if (!mounted) return;
        setState(() {
          _tests = [];
          _loading = false;
          _error = null;
        });
        return;
      }

      final selection = await _selectSpeakingCycleTest(available);

      if (!mounted) return;

      _currentCycle = selection.cycleNumber;

      setState(() {
        _tests = selection.test == null
            ? <SpeakingTest>[]
            : <SpeakingTest>[selection.test!];
        _loading = false;
      });
    } catch (error) {
      debugPrint('Speaking test loading failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Speaking tests could not be loaded. Check your connection and try again.';
      });
    }
  }

  Future<_SpeakingCycleSelection> _selectSpeakingCycleTest(
    List<SpeakingTest> tests,
  ) async {
    if (tests.isEmpty) {
      return const _SpeakingCycleSelection(
        test: null,
        cycleNumber: 1,
        completedInCycle: 0,
      );
    }

    final orderedTests = [...tests]..sort(_compareSpeakingTestsNaturally);
    final offline = OfflineContentService.instance;

    if (!offline.isOnline) {
      return _SpeakingCycleSelection(
        test: orderedTests.first,
        cycleNumber: 1,
        completedInCycle: 0,
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _SpeakingCycleSelection(
        test: orderedTests.first,
        cycleNumber: 1,
        completedInCycle: 0,
      );
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final progressRef = userRef
        .collection('speaking_cycles')
        .doc(_cyclePoolKey);

    try {
      var snapshot = await progressRef.get().timeout(
        const Duration(seconds: 10),
      );

      // First-time migration keeps existing users from suddenly receiving
      // already-completed Speaking tests again after this update.
      if (!snapshot.exists) {
        final legacyCompletedIds = <String>{};
        final availableIds = orderedTests.map((test) => test.id).toSet();

        try {
          final queue = ContentQueueService();
          final queueCompletedIds = await queue.completedIds('speaking');
          legacyCompletedIds.addAll(
            queueCompletedIds.where(availableIds.contains),
          );

          final resultSnapshot = await userRef
              .collection('speaking_results')
              .get()
              .timeout(const Duration(seconds: 10));

          for (final doc in resultSnapshot.docs) {
            final testId = (doc.data()['testId'] ?? '').toString().trim();
            if (availableIds.contains(testId)) {
              legacyCompletedIds.add(testId);
            }
          }
        } catch (error) {
          debugPrint('Speaking cycle migration lookup failed: $error');
        }

        await progressRef.set({
          'poolKey': _cyclePoolKey,
          'mode': widget.mode,
          'cycleNumber': 1,
          'completedTestIds': legacyCompletedIds.toList(),
          'completedCount': legacyCompletedIds.length,
          'totalTestsAtLastLoad': orderedTests.length,
          'cycleResultCount': 0,
          'cycleBandSum': 0.0,
          'cycleAverageBand': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        snapshot = await progressRef.get().timeout(const Duration(seconds: 10));
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      var cycleNumber = _asInt(data['cycleNumber'], 1);
      var completedIds = _stringList(data['completedTestIds']).toSet();
      final currentTestId = (data['currentTestId'] ?? '').toString().trim();

      final availableIds = orderedTests.map((test) => test.id).toSet();
      completedIds = completedIds.intersection(availableIds);

      // Reopen the same assigned test until its AI evaluation is completed.
      if (currentTestId.isNotEmpty &&
          availableIds.contains(currentTestId) &&
          !completedIds.contains(currentTestId)) {
        final currentTest = orderedTests.firstWhere(
          (test) => test.id == currentTestId,
        );

        return _SpeakingCycleSelection(
          test: currentTest,
          cycleNumber: cycleNumber,
          completedInCycle: completedIds.length,
        );
      }

      var remaining = orderedTests
          .where((test) => !completedIds.contains(test.id))
          .toList();

      // All published tests for this mode are complete: start a new cycle.
      // speaking_results history is NEVER deleted.
      if (remaining.isEmpty) {
        cycleNumber += 1;
        completedIds = <String>{};
        remaining = [...orderedTests];

        await progressRef.set({
          'cycleNumber': cycleNumber,
          'completedTestIds': <String>[],
          'completedCount': 0,
          'currentTestId': FieldValue.delete(),
          'currentTestTitle': FieldValue.delete(),
          'cycleResultCount': 0,
          'cycleBandSum': 0.0,
          'cycleAverageBand': 0.0,
          'cycleStartedAt': FieldValue.serverTimestamp(),
          'lastCycleResetAt': FieldValue.serverTimestamp(),
          'totalTestsAtLastLoad': orderedTests.length,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final selected = remaining.first;

      await progressRef.set({
        'poolKey': _cyclePoolKey,
        'mode': widget.mode,
        'cycleNumber': cycleNumber,
        'currentTestId': selected.id,
        'currentTestTitle': selected.title,
        'completedCount': completedIds.length,
        'totalTestsAtLastLoad': orderedTests.length,
        'lastAssignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return _SpeakingCycleSelection(
        test: selected,
        cycleNumber: cycleNumber,
        completedInCycle: completedIds.length,
      );
    } catch (error, stackTrace) {
      debugPrint('Speaking cycle selection failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      return _SpeakingCycleSelection(
        test: orderedTests.first,
        cycleNumber: 1,
        completedInCycle: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = SpeakingModeOption.labelFor(widget.mode);

    return Scaffold(
      backgroundColor: SColors.background,
      appBar: AppBar(backgroundColor: SColors.background, title: Text(label)),
      body: Stack(
        children: [
          const Positioned.fill(child: _SpeakingBackground()),
          if (_loading)
            const LearnerStateView.loading(
              title: 'Preparing your speaking session',
              message:
                  'Selecting a fresh activity for your mode and completed practice history.',
              icon: Icons.mic_rounded,
            )
          else if (_error != null)
            LearnerStateView.error(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load speaking tests',
              message:
                  'Your recordings and feedback are safe. Check your connection and try once more.',
              onAction: _load,
            )
          else if (_tests.isEmpty)
            LearnerStateView.empty(
              icon: Icons.mic_none_rounded,
              title: 'No speaking activity available',
              message: _availableCount == 0
                  ? 'No published Speaking activity is available for this mode yet.'
                  : 'Your next Speaking activity could not be prepared. Please try again.',
              actionLabel: 'Refresh activities',
              onAction: _load,
            )
          else
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
              itemCount: _tests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 11),
              itemBuilder: (context, index) {
                final test = _tests[index];
                return _SpeakingTestCard(
                  test: test,
                  onTap: () => _openTest(context, test),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openTest(BuildContext context, SpeakingTest test) async {
    final access = await SpeakingPremiumManager.consumeMode(widget.mode);

    if (!mounted || !context.mounted) return;

    if (!access.allowed) {
      await _showSpeakingPremiumSheet(
        context,
        title: access.premiumOnly
            ? '${SpeakingModeOption.labelFor(widget.mode)} is Premium'
            : 'Free Speaking limit reached',
        message: access.premiumOnly
            ? 'This Speaking mode is available with IELTS AI Master Premium.'
            : 'You have used today’s free ${SpeakingModeOption.labelFor(widget.mode)} activity. '
                  'Free users receive 1 activity per Speaking mode each day.',
      );
      return;
    }

    final examMode = test.mode == 'full_test';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpeakingSessionScreen(
          test: test,
          examMode: examMode,
          cyclePoolKey: _cyclePoolKey,
          cycleNumber: _currentCycle,
          cycleTotalTests: _availableCount,
        ),
      ),
    );
  }
}

class SpeakingSessionScreen extends StatefulWidget {
  final SpeakingTest test;
  final bool examMode;
  final String cyclePoolKey;
  final int cycleNumber;
  final int cycleTotalTests;

  const SpeakingSessionScreen({
    super.key,
    required this.test,
    required this.examMode,
    this.cyclePoolKey = 'speaking_all',
    this.cycleNumber = 1,
    this.cycleTotalTests = 1,
  });

  @override
  State<SpeakingSessionScreen> createState() => _SpeakingSessionScreenState();
}

class _SpeakingSessionScreenState extends State<SpeakingSessionScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _modelPlayer = AudioPlayer();
  final TextEditingController _notesController = TextEditingController();

  late final AnimationController _waveController;

  int _partIndex = 0;
  int _questionIndex = 0;
  int _remainingSeconds = 0;
  int _preparationSeconds = 0;
  int _recordedSeconds = 0;

  Timer? _timer;
  Timer? _recordTimer;

  bool _preparing = false;
  bool _recording = false;
  bool _uploading = false;
  bool _playingRecording = false;
  bool _playingModel = false;
  String? _recordingPath;

  SpeakingPart get _part => widget.test.parts[_partIndex];
  SpeakingQuestion get _question => _part.questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _setupCurrentQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordTimer?.cancel();
    _waveController.dispose();
    _notesController.dispose();
    _recorder.dispose();
    _player.dispose();
    _modelPlayer.dispose();
    super.dispose();
  }

  void _setupCurrentQuestion() {
    _timer?.cancel();
    _recordTimer?.cancel();
    _recordedSeconds = 0;
    _recordingPath = null;
    _preparationSeconds = _part.preparationSeconds;
    _remainingSeconds = _part.speakingSeconds;

    if (_preparationSeconds > 0) {
      _startPreparation();
    } else {
      setState(() => _preparing = false);
    }
  }

  void _startPreparation() {
    setState(() => _preparing = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_preparationSeconds <= 1) {
        timer.cancel();
        setState(() {
          _preparationSeconds = 0;
          _preparing = false;
        });
      } else {
        setState(() => _preparationSeconds--);
      }
    });
  }

  Future<void> _startRecording() async {
    if (_preparing || _recording) return;

    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
      }
      return;
    }

    final directory = await getTemporaryDirectory();
    final filePath =
        '${directory.path}/speaking_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    setState(() {
      _recording = true;
      _recordedSeconds = 0;
      _recordingPath = null;
    });
    _waveController.repeat(reverse: true);

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_recordedSeconds + 1 >= _remainingSeconds) {
        timer.cancel();
        _stopRecording();
      } else {
        setState(() => _recordedSeconds++);
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;

    _recordTimer?.cancel();
    final path = await _recorder.stop();
    _waveController.stop();

    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordingPath = path;
    });
  }

  Future<void> _playRecording() async {
    final path = _recordingPath;
    if (path == null) return;

    if (_playingRecording) {
      await _player.stop();
      if (mounted) setState(() => _playingRecording = false);
      return;
    }

    await _player.setFilePath(path);
    setState(() => _playingRecording = true);
    await _player.play();
    if (mounted) setState(() => _playingRecording = false);
  }

  Future<void> _playModelAudio() async {
    final url = widget.test.modelAudioUrl;
    if (url.isEmpty) return;

    if (_playingModel) {
      await _modelPlayer.stop();
      if (mounted) setState(() => _playingModel = false);
      return;
    }

    await _modelPlayer.setUrl(url);
    setState(() => _playingModel = true);
    await _modelPlayer.play();
    if (mounted) setState(() => _playingModel = false);
  }

  Future<void> _submitRecording() async {
    final user = FirebaseAuth.instance.currentUser;
    final path = _recordingPath;

    if (user == null || path == null || _uploading) return;

    setState(() => _uploading = true);

    try {
      final submissionRef = FirebaseFirestore.instance
          .collection('speaking_submissions')
          .doc();

      final storagePath =
          'speaking_recordings/${user.uid}/${submissionRef.id}.m4a';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      await storageRef.putFile(
        File(path),
        SettableMetadata(contentType: 'audio/mp4'),
      );

      final audioUrl = await storageRef.getDownloadURL();

      await submissionRef.set({
        'submissionId': submissionRef.id,
        'userId': user.uid,
        'testId': widget.test.id,
        'title': widget.test.title,
        'mode': widget.test.mode,
        'part': _part.part,
        'questionNumber': _question.number,
        'questionText': _question.question,
        'notes': _notesController.text.trim(),
        'audioUrl': audioUrl,
        'audioStoragePath': storagePath,
        'audioMimeType': 'audio/mp4',
        'durationSeconds': _recordedSeconds,
        'cyclePoolKey': widget.cyclePoolKey,
        'cycleNumber': widget.cycleNumber,
        'cycleTotalTests': widget.cycleTotalTests,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SpeakingEvaluationWaitingScreen(
            submissionId: submissionRef.id,
            test: widget.test,
            cyclePoolKey: widget.cyclePoolKey,
            cycleNumber: widget.cycleNumber,
            cycleTotalTests: widget.cycleTotalTests,
          ),
        ),
      );
    } catch (_) {
      final queuedId = await OfflineContentService.instance
          .queueSpeakingEvaluation(
            uid: user.uid,
            testId: widget.test.id,
            recordingPath: path,
            data: {
              'title': widget.test.title,
              'mode': widget.test.mode,
              'part': _part.part,
              'questionNumber': _question.number,
              'questionText': _question.question,
              'notes': _notesController.text.trim(),
              'durationSeconds': _recordedSeconds,
              'cyclePoolKey': widget.cyclePoolKey,
              'cycleNumber': widget.cycleNumber,
              'cycleTotalTests': widget.cycleTotalTests,
              'status': 'pending_ai_evaluation',
            },
          );
      await OfflineContentService.instance.markCompleted(
        module: 'speaking',
        contentId: widget.test.id,
        result: {'status': 'pending_ai_evaluation', 'queueId': queuedId},
      );
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Recording saved offline. AI evaluation will start after reconnecting.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _nextQuestion() {
    if (_questionIndex + 1 < _part.questions.length) {
      setState(() => _questionIndex++);
      _setupCurrentQuestion();
      return;
    }

    if (_partIndex + 1 < widget.test.parts.length) {
      setState(() {
        _partIndex++;
        _questionIndex = 0;
        _notesController.clear();
      });
      _setupCurrentQuestion();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You reached the final question.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _SpeakingBackground()),
          SafeArea(
            child: Column(
              children: [
                _SessionHeader(
                  title: widget.test.title,
                  part: _part.part,
                  questionNumber: _question.number,
                  totalQuestions: _part.questions.length,
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    children: [
                      const _ExaminerAvatar(),
                      const SizedBox(height: 16),
                      _QuestionCard(
                        part: _part,
                        question: _question,
                        examMode: widget.examMode,
                      ),
                      if (_part.part == 2) ...[
                        const SizedBox(height: 12),
                        _NotesArea(controller: _notesController),
                      ],
                      const SizedBox(height: 14),
                      _TimerRow(
                        preparing: _preparing,
                        preparationSeconds: _preparationSeconds,
                        speakingSeconds: math.max(
                          0,
                          _remainingSeconds - _recordedSeconds,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Waveform(
                        controller: _waveController,
                        active: _recording,
                      ),
                      const SizedBox(height: 16),
                      _RecordControls(
                        recording: _recording,
                        hasRecording: _recordingPath != null,
                        playing: _playingRecording,
                        uploading: _uploading,
                        preparing: _preparing,
                        onRecord: _startRecording,
                        onStop: _stopRecording,
                        onReplay: _playRecording,
                        onSubmit: _submitRecording,
                      ),
                      if (!widget.examMode &&
                          widget.test.modelAudioUrl.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _ModelAudioCard(
                          playing: _playingModel,
                          onPlay: _playModelAudio,
                        ),
                      ],
                      if (!widget.examMode) ...[
                        const SizedBox(height: 14),
                        _PracticeGuidance(question: _question),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _recording ? null : _nextQuestion,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Next Question'),
                      ),
                    ],
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

class SpeakingEvaluationWaitingScreen extends StatelessWidget {
  final String submissionId;
  final SpeakingTest test;
  final String cyclePoolKey;
  final int cycleNumber;
  final int cycleTotalTests;

  const SpeakingEvaluationWaitingScreen({
    super.key,
    required this.submissionId,
    required this.test,
    this.cyclePoolKey = 'speaking_all',
    this.cycleNumber = 1,
    this.cycleTotalTests = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _SpeakingBackground()),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('speaking_submissions')
                .doc(submissionId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _MessageState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Report connection interrupted',
                  subtitle:
                      'Your recording is safe. Check your connection and reopen this report in a moment.',
                  action: () => Navigator.pop(context),
                );
              }
              final data = snapshot.data?.data();
              final status = (data?['status'] ?? 'queued').toString();

              if (status == 'completed' && data?['report'] is Map) {
                final report = SpeakingReport.fromMap(
                  Map<String, dynamic>.from(data!['report']),
                );

                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  final user = FirebaseAuth.instance.currentUser;

                  if (user != null) {
                    await _completeSpeakingCycleAttempt(
                      user: user,
                      poolKey: cyclePoolKey,
                      mode: test.mode,
                      cycleNumber: cycleNumber,
                      testId: test.id,
                      testTitle: test.title,
                      totalTests: cycleTotalTests,
                      band: report.overallBand,
                    );
                  }

                  if (!context.mounted) return;

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SpeakingReportScreen(report: report, test: test),
                    ),
                  );
                });
              }

              if (status == 'failed') {
                return _MessageState(
                  icon: Icons.error_outline_rounded,
                  title: 'Speaking evaluation failed',
                  subtitle:
                      'We could not complete this speaking report. Your recording is safe—please try the evaluation again.',
                  action: () => Navigator.pop(context),
                );
              }

              return const IeltsAiAnalysisLoader(
                title: 'Building your speaking report',
                subtitle:
                    'Your recording is being assessed against all four IELTS Speaking criteria.',
                steps: [
                  'Analysing fluency and coherence',
                  'Reviewing vocabulary and grammar',
                  'Assessing pronunciation and delivery',
                  'Preparing actionable feedback',
                ],
                accent: SColors.cyan,
                icon: Icons.graphic_eq_rounded,
              );
            },
          ),
        ],
      ),
    );
  }
}

class SpeakingReportScreen extends StatelessWidget {
  final SpeakingReport report;
  final SpeakingTest? test;

  const SpeakingReportScreen({super.key, required this.report, this.test});

  List<(String, SpeakingCriterion)> get _criteria => [
    ('Fluency & Coherence', report.fluencyAndCoherence),
    ('Lexical Resource', report.lexicalResource),
    ('Grammatical Range & Accuracy', report.grammaticalRangeAndAccuracy),
    ('Pronunciation', report.pronunciation),
  ];

  List<String> get _strengths => _criteria
      .expand((item) => item.$2.strengths.map((text) => '${item.$1}: $text'))
      .toSet()
      .take(5)
      .toList();

  List<String> get _improvements => <String>[
    ..._criteria.expand(
      (item) => item.$2.improvements.map((text) => '${item.$1}: $text'),
    ),
    ...report.suggestedImprovements,
  ].toSet().take(5).toList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SpeakingPremiumManager.loadHomeAccess().then(
        (value) => value.isPremium,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: SColors.background,
            body: IeltsAiAnalysisLoader(
              title: 'Opening your speaking report',
              subtitle:
                  'Preparing your personalised evaluation and practice guidance.',
              steps: ['Loading score profile', 'Preparing report access'],
              accent: SColors.cyan,
              icon: Icons.mic_rounded,
            ),
          );
        }
        final isPremium = snapshot.data ?? false;

        return Scaffold(
          backgroundColor: SColors.background,
          appBar: AppBar(
            backgroundColor: SColors.background,
            title: const Text('Speaking Evaluation'),
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: _SpeakingBackground()),
              ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 35),
                children: [
                  IeltsResultHero(
                    accent: SColors.cyan,
                    band: report.overallBand,
                    title: 'Estimated Overall Band',
                    eyebrow: 'AI SPEAKING EVALUATION',
                    summary: report.summary,
                    aiEstimated: true,
                    meta: [
                      IeltsResultMetric(
                        value: '${report.answerRelevancePercent}%',
                        label: 'Answer relevance',
                        icon: Icons.center_focus_strong_rounded,
                      ),
                      IeltsResultMetric(
                        value: '${report.speakingSpeedWpm}',
                        label: 'Words / minute',
                        icon: Icons.speed_rounded,
                      ),
                      IeltsResultMetric(
                        value: '${report.pauseCount}',
                        label: 'Pauses detected',
                        icon: Icons.pause_circle_outline_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  IeltsResultSectionTitle(
                    title: 'IELTS criterion scores',
                    subtitle:
                        'A separate estimated band for every official scoring dimension',
                    icon: Icons.radar_rounded,
                    accent: SColors.cyan,
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
                                  accent: SColors.cyan,
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  _ReportSection(
                    title: 'Answer relevance',
                    icon: Icons.center_focus_strong_rounded,
                    child: IeltsResultProgressRow(
                      label: 'Response relevance',
                      value: report.answerRelevancePercent,
                      detail: report.answerRelevanceFeedback,
                      accent: SColors.cyan,
                    ),
                  ),
                  if (isPremium) ...[
                    const SizedBox(height: 10),
                    IeltsResultSectionTitle(
                      title: 'What matters most',
                      subtitle:
                          'Your strongest evidence and highest-impact improvements',
                      icon: Icons.insights_rounded,
                      accent: SColors.cyan,
                    ),
                    const SizedBox(height: 12),
                    IeltsInsightCard(
                      title: 'Strengths',
                      items: _strengths,
                      tone: IeltsInsightTone.strength,
                      emptyMessage:
                          'The report did not identify a specific strength in this recording.',
                    ),
                    const SizedBox(height: 10),
                    IeltsInsightCard(
                      title: 'Areas to improve',
                      items: _improvements,
                      tone: IeltsInsightTone.improvement,
                      emptyMessage:
                          'No major criterion weakness was identified.',
                    ),
                    const SizedBox(height: 10),
                    IeltsInsightCard(
                      title: 'Recommended next practice',
                      items: report.actionPlan,
                      tone: IeltsInsightTone.recommendation,
                      emptyMessage:
                          'Record the same prompt again while applying one fluency and one pronunciation improvement.',
                    ),
                    const SizedBox(height: 22),
                    IeltsResultSectionTitle(
                      title: 'Detailed criterion feedback',
                      subtitle:
                          'Open a criterion for its complete AI assessment',
                      icon: Icons.rate_review_outlined,
                      accent: SColors.cyan,
                    ),
                    const SizedBox(height: 12),
                    ..._criteria.map(
                      (item) => _SpeakingCriterionDetail(
                        title: item.$1,
                        criterion: item.$2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MetricsCard(report: report),
                    const SizedBox(height: 14),
                    _ReportSection(
                      title: 'Fillers and Repetition',
                      icon: Icons.repeat_rounded,
                      child: _StringItems(
                        items: [
                          ...report.fillerWords.map(
                            (item) => '${item.word}: ${item.count}',
                          ),
                          ...report.repetitions,
                        ],
                      ),
                    ),
                    _ReportSection(
                      title: 'Word Stress and Intonation',
                      icon: Icons.graphic_eq_rounded,
                      child: _StringItems(
                        items: [
                          ...report.wordStressAnalysis,
                          ...report.intonationAnalysis,
                        ],
                      ),
                    ),
                    _ReportSection(
                      title: 'Mispronounced Words',
                      icon: Icons.record_voice_over_outlined,
                      child: report.mispronouncedWords.isEmpty
                          ? const _EmptyFeedback()
                          : Column(
                              children: report.mispronouncedWords.map((item) {
                                return _FeedbackTile(
                                  title: item.word,
                                  body:
                                      'Heard as: ${item.heardAs}\n'
                                      'Practice: ${item.practiceHint}',
                                );
                              }).toList(),
                            ),
                    ),
                    _ReportSection(
                      title: 'Shadowing Practice',
                      icon: Icons.multitrack_audio_rounded,
                      child: Text(
                        '${report.shadowingText}\n\nFocus: '
                        '${report.shadowingFocus}',
                        style: const TextStyle(
                          color: SColors.secondary,
                          height: 1.55,
                        ),
                      ),
                    ),
                    if (report.transcript.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _ReportSection(
                        title: 'Transcript',
                        icon: Icons.notes_rounded,
                        child: SelectableText(
                          report.transcript,
                          style: const TextStyle(
                            color: SColors.secondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 14),
                    _SpeakingAdvancedReportLockedCard(
                      onTap: () => _openSpeakingPremium(
                        context,
                        source: 'advanced_speaking_report',
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  IeltsResultActions(
                    primaryLabel: test == null
                        ? 'Back to Speaking'
                        : 'Practice Again',
                    primaryIcon: test == null
                        ? Icons.mic_rounded
                        : Icons.replay_rounded,
                    onPrimary: () => test == null
                        ? _backToSpeaking(context)
                        : Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SpeakingSessionScreen(
                                test: test!,
                                examMode: false,
                              ),
                            ),
                          ),
                    secondaryLabel: 'Back to Speaking',
                    secondaryIcon: Icons.mic_none_rounded,
                    onSecondary: () => _backToSpeaking(context),
                    accent: SColors.cyan,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _backToSpeaking(BuildContext context) => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const SpeakingPractice()),
    (route) => route.isFirst,
  );
}

class _SpeakingCriterionDetail extends StatelessWidget {
  const _SpeakingCriterionDetail({
    required this.title,
    required this.criterion,
  });
  final String title;
  final SpeakingCriterion criterion;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: _panelDecoration(),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: SColors.cyan,
        collapsedIconColor: SColors.muted,
        title: Text(
          title,
          style: const TextStyle(
            color: SColors.text,
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
                color: SColors.cyan,
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
                color: SColors.secondary,
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

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class SpeakingTest {
  final String id;
  final String title;
  final String description;
  final String mode;
  final String accent;
  final String difficulty;
  final int estimatedDurationSeconds;
  final List<SpeakingPart> parts;
  final SpeakingDailyChallenge dailyChallenge;
  final SpeakingPronunciationPractice pronunciationPractice;
  final SpeakingFluencyTraining fluencyTraining;
  final List<String> evaluationFocus;
  final String modelAudioUrl;

  const SpeakingTest({
    required this.id,
    required this.title,
    required this.description,
    required this.mode,
    required this.accent,
    required this.difficulty,
    required this.estimatedDurationSeconds,
    required this.parts,
    required this.dailyChallenge,
    required this.pronunciationPractice,
    required this.fluencyTraining,
    required this.evaluationFocus,
    required this.modelAudioUrl,
  });

  factory SpeakingTest.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SpeakingTest.fromMap(doc.data(), id: doc.id);
  }

  factory SpeakingTest.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return SpeakingTest(
      id: id,
      title: (data['title'] ?? 'Speaking Practice').toString(),
      description: (data['description'] ?? '').toString(),
      mode: (data['mode'] ?? 'part_1').toString(),
      accent: (data['accent'] ?? 'British').toString(),
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      estimatedDurationSeconds: _asInt(data['estimatedDurationSeconds'], 600),
      parts: _list(data['parts'])
          .map(
            (item) =>
                SpeakingPart.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .where((part) => part.questions.isNotEmpty)
          .toList(),
      dailyChallenge: SpeakingDailyChallenge.fromMap(
        _map(data['dailyChallenge']),
      ),
      pronunciationPractice: SpeakingPronunciationPractice.fromMap(
        _map(data['pronunciationPractice']),
      ),
      fluencyTraining: SpeakingFluencyTraining.fromMap(
        _map(data['fluencyTraining']),
      ),
      evaluationFocus: _stringList(data['evaluationFocus']),
      modelAudioUrl: (data['modelAudioUrl'] ?? '').toString(),
    );
  }
}

class SpeakingPart {
  final int part;
  final String title;
  final String instructions;
  final int preparationSeconds;
  final int speakingSeconds;
  final List<SpeakingQuestion> questions;

  const SpeakingPart({
    required this.part,
    required this.title,
    required this.instructions,
    required this.preparationSeconds,
    required this.speakingSeconds,
    required this.questions,
  });

  factory SpeakingPart.fromMap(Map<String, dynamic> map) {
    return SpeakingPart(
      part: _asInt(map['part'], 1),
      title: (map['title'] ?? '').toString(),
      instructions: (map['instructions'] ?? '').toString(),
      preparationSeconds: _asInt(map['preparationSeconds'], 0),
      speakingSeconds: _asInt(map['speakingSeconds'], 120),
      questions: _list(map['questions'])
          .map(
            (item) => SpeakingQuestion.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class SpeakingQuestion {
  final int number;
  final String question;
  final List<String> followUpQuestions;
  final String modelAnswer;
  final List<String> answerGuide;
  final List<String> usefulVocabulary;
  final List<PronunciationTarget> pronunciationTargets;

  const SpeakingQuestion({
    required this.number,
    required this.question,
    required this.followUpQuestions,
    required this.modelAnswer,
    required this.answerGuide,
    required this.usefulVocabulary,
    required this.pronunciationTargets,
  });

  factory SpeakingQuestion.fromMap(Map<String, dynamic> map) {
    return SpeakingQuestion(
      number: _asInt(map['number'], 1),
      question: (map['question'] ?? '').toString(),
      followUpQuestions: _stringList(map['followUpQuestions']),
      modelAnswer: (map['modelAnswer'] ?? '').toString(),
      answerGuide: _stringList(map['answerGuide']),
      usefulVocabulary: _stringList(map['usefulVocabulary']),
      pronunciationTargets: _list(map['pronunciationTargets'])
          .map(
            (item) => PronunciationTarget.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class PronunciationTarget {
  final String word;
  final String stressHint;
  final String intonationHint;

  const PronunciationTarget({
    required this.word,
    required this.stressHint,
    required this.intonationHint,
  });

  factory PronunciationTarget.fromMap(Map<String, dynamic> map) {
    return PronunciationTarget(
      word: (map['word'] ?? '').toString(),
      stressHint: (map['stressHint'] ?? '').toString(),
      intonationHint: (map['intonationHint'] ?? '').toString(),
    );
  }
}

class SpeakingDailyChallenge {
  final String prompt;
  final int targetSeconds;
  final String focus;

  const SpeakingDailyChallenge({
    required this.prompt,
    required this.targetSeconds,
    required this.focus,
  });

  factory SpeakingDailyChallenge.fromMap(Map<String, dynamic> map) {
    return SpeakingDailyChallenge(
      prompt: (map['prompt'] ?? '').toString(),
      targetSeconds: _asInt(map['targetSeconds'], 60),
      focus: (map['focus'] ?? '').toString(),
    );
  }
}

class SpeakingPronunciationPractice {
  final List<String> sentences;
  final List<String> wordStressTips;
  final List<String> intonationTips;
  final String shadowingText;

  const SpeakingPronunciationPractice({
    required this.sentences,
    required this.wordStressTips,
    required this.intonationTips,
    required this.shadowingText,
  });

  factory SpeakingPronunciationPractice.fromMap(Map<String, dynamic> map) {
    return SpeakingPronunciationPractice(
      sentences: _stringList(map['sentences']),
      wordStressTips: _stringList(map['wordStressTips']),
      intonationTips: _stringList(map['intonationTips']),
      shadowingText: (map['shadowingText'] ?? '').toString(),
    );
  }
}

class SpeakingFluencyTraining {
  final String prompt;
  final int targetSeconds;
  final List<String> fillerReductionTips;
  final List<String> linkingPhrases;

  const SpeakingFluencyTraining({
    required this.prompt,
    required this.targetSeconds,
    required this.fillerReductionTips,
    required this.linkingPhrases,
  });

  factory SpeakingFluencyTraining.fromMap(Map<String, dynamic> map) {
    return SpeakingFluencyTraining(
      prompt: (map['prompt'] ?? '').toString(),
      targetSeconds: _asInt(map['targetSeconds'], 120),
      fillerReductionTips: _stringList(map['fillerReductionTips']),
      linkingPhrases: _stringList(map['linkingPhrases']),
    );
  }
}

class SpeakingReport {
  final double overallBand;
  final String summary;
  final String transcript;
  final SpeakingCriterion fluencyAndCoherence;
  final SpeakingCriterion lexicalResource;
  final SpeakingCriterion grammaticalRangeAndAccuracy;
  final SpeakingCriterion pronunciation;
  final int speakingSpeedWpm;
  final int pauseCount;
  final List<FillerWord> fillerWords;
  final List<String> repetitions;
  final int answerRelevancePercent;
  final String answerRelevanceFeedback;
  final List<String> wordStressAnalysis;
  final List<String> intonationAnalysis;
  final List<MispronouncedWord> mispronouncedWords;
  final List<String> suggestedImprovements;
  final String shadowingText;
  final String shadowingFocus;
  final List<String> actionPlan;

  const SpeakingReport({
    required this.overallBand,
    required this.summary,
    required this.transcript,
    required this.fluencyAndCoherence,
    required this.lexicalResource,
    required this.grammaticalRangeAndAccuracy,
    required this.pronunciation,
    required this.speakingSpeedWpm,
    required this.pauseCount,
    required this.fillerWords,
    required this.repetitions,
    required this.answerRelevancePercent,
    required this.answerRelevanceFeedback,
    required this.wordStressAnalysis,
    required this.intonationAnalysis,
    required this.mispronouncedWords,
    required this.suggestedImprovements,
    required this.shadowingText,
    required this.shadowingFocus,
    required this.actionPlan,
  });

  factory SpeakingReport.fromMap(Map<String, dynamic> map) {
    return SpeakingReport(
      overallBand: _asDouble(map['overallBand']),
      summary: (map['summary'] ?? '').toString(),
      transcript: (map['transcript'] ?? '').toString(),
      fluencyAndCoherence: SpeakingCriterion.fromMap(
        _map(map['fluencyAndCoherence']),
      ),
      lexicalResource: SpeakingCriterion.fromMap(_map(map['lexicalResource'])),
      grammaticalRangeAndAccuracy: SpeakingCriterion.fromMap(
        _map(map['grammaticalRangeAndAccuracy']),
      ),
      pronunciation: SpeakingCriterion.fromMap(_map(map['pronunciation'])),
      speakingSpeedWpm: _asInt(map['speakingSpeedWpm'], 0),
      pauseCount: _asInt(map['pauseCount'], 0),
      fillerWords: _list(map['fillerWords'])
          .map(
            (item) =>
                FillerWord.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      repetitions: _stringList(map['repetitions']),
      answerRelevancePercent: _asInt(
        _map(map['answerRelevance'])['scorePercent'],
        0,
      ),
      answerRelevanceFeedback: (_map(map['answerRelevance'])['feedback'] ?? '')
          .toString(),
      wordStressAnalysis: _stringList(map['wordStressAnalysis']),
      intonationAnalysis: _stringList(map['intonationAnalysis']),
      mispronouncedWords: _list(map['mispronouncedWords'])
          .map(
            (item) => MispronouncedWord.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      suggestedImprovements: _stringList(map['suggestedImprovements']),
      shadowingText: (_map(map['shadowingPractice'])['text'] ?? '').toString(),
      shadowingFocus: (_map(map['shadowingPractice'])['focus'] ?? '')
          .toString(),
      actionPlan: _stringList(map['actionPlan']),
    );
  }
}

class SpeakingCriterion {
  final double band;
  final String feedback;
  final List<String> strengths;
  final List<String> improvements;

  const SpeakingCriterion({
    required this.band,
    required this.feedback,
    required this.strengths,
    required this.improvements,
  });

  factory SpeakingCriterion.fromMap(Map<String, dynamic> map) {
    return SpeakingCriterion(
      band: _asDouble(map['band']),
      feedback: (map['feedback'] ?? '').toString(),
      strengths: _stringList(map['strengths']),
      improvements: _stringList(map['improvements']),
    );
  }
}

class FillerWord {
  final String word;
  final int count;

  const FillerWord({required this.word, required this.count});

  factory FillerWord.fromMap(Map<String, dynamic> map) {
    return FillerWord(
      word: (map['word'] ?? '').toString(),
      count: _asInt(map['count'], 0),
    );
  }
}

class MispronouncedWord {
  final String word;
  final String heardAs;
  final String practiceHint;

  const MispronouncedWord({
    required this.word,
    required this.heardAs,
    required this.practiceHint,
  });

  factory MispronouncedWord.fromMap(Map<String, dynamic> map) {
    return MispronouncedWord(
      word: (map['word'] ?? '').toString(),
      heardAs: (map['heardAs'] ?? '').toString(),
      practiceHint: (map['practiceHint'] ?? '').toString(),
    );
  }
}

enum SpeakingModeOption {
  aiPartner(
    'ai_partner',
    'AI Speaking Partner',
    'Adaptive questions and follow-ups',
    Icons.smart_toy_outlined,
  ),
  fullTest(
    'full_test',
    'Full Speaking Test',
    'Parts 1, 2 and 3',
    Icons.assignment_turned_in_outlined,
  ),
  part1(
    'part_1',
    'Part 1 Practice',
    'Introduction and familiar questions',
    Icons.looks_one_outlined,
  ),
  part2(
    'part_2',
    'Part 2 Cue Cards',
    'Preparation and 2-minute talk',
    Icons.looks_two_outlined,
  ),
  part3(
    'part_3',
    'Part 3 Discussion',
    'Abstract follow-up discussion',
    Icons.looks_3_outlined,
  ),
  pronunciation(
    'pronunciation',
    'Pronunciation Practice',
    'Stress, intonation and clarity',
    Icons.record_voice_over_outlined,
  ),
  fluency(
    'fluency',
    'Fluency Training',
    'Reduce pauses and fillers',
    Icons.speed_rounded,
  ),
  dailyChallenge(
    'daily_challenge',
    'Daily Speaking Challenge',
    'A focused 60-second task',
    Icons.local_fire_department_outlined,
  );

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  const SpeakingModeOption(this.key, this.title, this.subtitle, this.icon);

  bool get premiumOnly => SpeakingPremiumManager.premiumOnlyModes.contains(key);

  static String labelFor(String key) {
    for (final option in values) {
      if (option.key == key) return option.title;
    }
    return 'Speaking Practice';
  }
}

// ---------------------------------------------------------------------------
// UI widgets
// ---------------------------------------------------------------------------

class _SpeakingHeader extends StatelessWidget {
  const _SpeakingHeader();

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();

    return Row(
      children: [
        canGoBack
            ? _SpeakingBackButton(onPressed: () => Navigator.pop(context))
            : const _GradientIcon(icon: Icons.mic_rounded),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Speaking',
                style: TextStyle(
                  color: SColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Practice, record and receive detailed AI feedback',
                style: TextStyle(color: SColors.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeakingBackButton extends StatelessWidget {
  const _SpeakingBackButton({required this.onPressed});

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
          foregroundColor: SColors.text,
          backgroundColor: SColors.surface.withOpacity(.94),
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

class _SpeakingPlanCard extends StatelessWidget {
  const _SpeakingPlanCard({required this.access});

  final SpeakingHomeAccess access;

  @override
  Widget build(BuildContext context) {
    final isPremium = access.isPremium;
    final accent = isPremium ? SColors.green : SColors.violet;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [accent.withOpacity(.14), SColors.cyan.withOpacity(.06)],
        ),
        border: Border.all(color: accent.withOpacity(.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 20,
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPremium
                        ? [SColors.green, SColors.cyan]
                        : [SColors.violet, SColors.cyan],
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
                          ? 'PREMIUM SPEAKING ACTIVE'
                          : access.offlineMode
                          ? 'OFFLINE SPEAKING'
                          : 'FREE SPEAKING PLAN',
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
                          ? 'Unlimited IELTS Speaking practice'
                          : access.offlineMode
                          ? 'Practice your downloaded Speaking content'
                          : '1 free activity per mode every day',
                      style: const TextStyle(
                        color: SColors.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPremium
                          ? 'AI Partner, Full Test and complete advanced reports are unlocked.'
                          : access.offlineMode
                          ? 'AI evaluation will sync when you reconnect.'
                          : 'AI Speaking Partner and Full Speaking Test require Premium.',
                      style: const TextStyle(
                        color: SColors.secondary,
                        fontSize: 9.8,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isPremium && !access.offlineMode) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: () =>
                    _openSpeakingPremium(context, source: 'speaking_home'),
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: const Text(
                  'Unlock Unlimited Speaking',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: SColors.violet,
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
  }
}

class _SpeakingAdvancedReportLockedCard extends StatelessWidget {
  const _SpeakingAdvancedReportLockedCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              SColors.violet.withOpacity(.14),
              SColors.cyan.withOpacity(.05),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: SColors.violet.withOpacity(.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: SColors.violet),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Unlock Advanced Speaking Report',
                    style: TextStyle(
                      color: SColors.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Premium includes detailed fluency metrics, filler analysis, '
              'word stress, intonation, mispronounced words, shadowing, '
              'action plans and your full transcript.',
              style: TextStyle(
                color: SColors.secondary,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text(
                  'View Premium Report',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: SColors.violet,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final SpeakingModeOption mode;
  final SpeakingHomeAccess access;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.access,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final premiumOnly = mode.premiumOnly && !access.isPremium;
    final used = access.usedFor(mode.key);
    final limitReached =
        !access.offlineMode &&
        !access.isPremium &&
        !mode.premiumOnly &&
        used >= SpeakingPremiumManager.freeUsesPerModePerDay;

    final badgeText = access.isPremium
        ? 'UNLIMITED'
        : access.offlineMode
        ? 'OFFLINE'
        : premiumOnly
        ? 'PREMIUM'
        : limitReached
        ? 'USED TODAY'
        : 'FREE • 1/DAY';

    final badgeColor = access.isPremium
        ? SColors.green
        : premiumOnly || limitReached
        ? SColors.violet
        : SColors.cyan;

    return _TapCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(mode.icon, color: SColors.cyan, size: 27),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: badgeColor.withOpacity(.22)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 6.7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            mode.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SColors.text,
              fontSize: 12.3,
              fontWeight: FontWeight.w900,
              height: 1.16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            premiumOnly ? 'Premium speaking experience' : mode.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SColors.muted,
              fontSize: 8.9,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakingTestCard extends StatelessWidget {
  final SpeakingTest test;
  final VoidCallback onTap;

  const _SpeakingTestCard({required this.test, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: SColors.cyan.withOpacity(.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.mic_none_rounded, color: SColors.cyan),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  test.title,
                  style: const TextStyle(
                    color: SColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  test.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SColors.muted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Badge(SpeakingModeOption.labelFor(test.mode)),
                    _Badge(test.accent),
                    _Badge(_clock(test.estimatedDurationSeconds)),
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

class _SessionHeader extends StatelessWidget {
  final String title;
  final int part;
  final int questionNumber;
  final int totalQuestions;
  final VoidCallback onBack;

  const _SessionHeader({
    required this.title,
    required this.part,
    required this.questionNumber,
    required this.totalQuestions,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
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
                    color: SColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Part $part • Question $questionNumber/$totalQuestions',
                  style: const TextStyle(color: SColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExaminerAvatar extends StatelessWidget {
  const _ExaminerAvatar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [SColors.cyan, SColors.violet],
          ),
          boxShadow: [
            BoxShadow(color: SColors.cyan.withOpacity(.22), blurRadius: 28),
          ],
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 64),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final SpeakingPart part;
  final SpeakingQuestion question;
  final bool examMode;

  const _QuestionCard({
    required this.part,
    required this.question,
    required this.examMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            part.title,
            style: const TextStyle(
              color: SColors.cyan,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            question.question,
            style: const TextStyle(
              color: SColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.4,
            ),
          ),
          if (part.part == 2 && question.answerGuide.isNotEmpty) ...[
            const SizedBox(height: 13),
            ...question.answerGuide.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: SColors.cyan)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: SColors.secondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!examMode && question.followUpQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'AI follow-up: ${question.followUpQuestions.first}',
              style: const TextStyle(
                color: SColors.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotesArea extends StatelessWidget {
  final TextEditingController controller;

  const _NotesArea({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      child: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 6,
        style: const TextStyle(color: SColors.text),
        decoration: const InputDecoration(
          labelText: 'Preparation Notes',
          hintText: 'Add short keywords and ideas...',
          prefixIcon: Icon(Icons.edit_note_rounded),
        ),
      ),
    );
  }
}

class _TimerRow extends StatelessWidget {
  final bool preparing;
  final int preparationSeconds;
  final int speakingSeconds;

  const _TimerRow({
    required this.preparing,
    required this.preparationSeconds,
    required this.speakingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimerCard(
            title: 'Preparation',
            seconds: preparationSeconds,
            active: preparing,
            icon: Icons.hourglass_top_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimerCard(
            title: 'Speaking',
            seconds: speakingSeconds,
            active: !preparing,
            icon: Icons.timer_outlined,
          ),
        ),
      ],
    );
  }
}

class _TimerCard extends StatelessWidget {
  final String title;
  final int seconds;
  final bool active;
  final IconData icon;

  const _TimerCard({
    required this.title,
    required this.seconds,
    required this.active,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: active ? SColors.cyan.withOpacity(.10) : SColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: active ? SColors.cyan : SColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: active ? SColors.cyan : SColors.muted),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: SColors.muted, fontSize: 12),
              ),
              Text(
                _clock(seconds),
                style: const TextStyle(
                  color: SColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  final AnimationController controller;
  final bool active;

  const _Waveform({required this.controller, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _panelDecoration(),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(30, (index) {
              final phase = index / 30 * math.pi * 4;
              final double dynamicHeight = active
                  ? 12.0 +
                        (math
                                .sin(phase + controller.value * math.pi * 2)
                                .abs() *
                            48.0)
                  : 10.0 + ((index % 5) * 4.0);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 3,
                height: dynamicHeight,
                decoration: BoxDecoration(
                  color: active ? SColors.cyan : SColors.muted,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _RecordControls extends StatelessWidget {
  final bool recording;
  final bool hasRecording;
  final bool playing;
  final bool uploading;
  final bool preparing;
  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback onReplay;
  final VoidCallback onSubmit;

  const _RecordControls({
    required this.recording,
    required this.hasRecording,
    required this.playing,
    required this.uploading,
    required this.preparing,
    required this.onRecord,
    required this.onStop,
    required this.onReplay,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: preparing ? null : (recording ? onStop : onRecord),
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recording ? Colors.redAccent : SColors.cyan,
              boxShadow: [
                BoxShadow(
                  color: (recording ? Colors.redAccent : SColors.cyan)
                      .withOpacity(.30),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Icon(
              recording ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          preparing
              ? 'Preparation in progress'
              : recording
              ? 'Tap to stop recording'
              : 'Tap to start recording',
          style: const TextStyle(color: SColors.muted),
        ),
        if (hasRecording) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: playing ? onReplay : onReplay,
                  icon: Icon(
                    playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(playing ? 'Stop Replay' : 'Replay'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: uploading ? null : onSubmit,
                  icon: uploading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Evaluate'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ModelAudioCard extends StatelessWidget {
  final bool playing;
  final VoidCallback onPlay;

  const _ModelAudioCard({required this.playing, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: SColors.violet.withOpacity(.15),
            child: Icon(
              playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: SColors.violet,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Model Audio',
                  style: TextStyle(
                    color: SColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Listen, repeat and compare your delivery',
                  style: TextStyle(color: SColors.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onPlay,
            icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}

class _PracticeGuidance extends StatelessWidget {
  final SpeakingQuestion question;

  const _PracticeGuidance({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Practice Guidance',
            style: TextStyle(color: SColors.text, fontWeight: FontWeight.w900),
          ),
          if (question.usefulVocabulary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: question.usefulVocabulary.map(_Badge.new).toList(),
            ),
          ],
          if (question.pronunciationTargets.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...question.pronunciationTargets.map(
              (item) => _FeedbackTile(
                title: item.word,
                body:
                    'Stress: ${item.stressHint}\n'
                    'Intonation: ${item.intonationHint}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentSpeakingResults extends StatelessWidget {
  final String? userId;

  const _RecentSpeakingResults({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const _MessageState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in required',
        subtitle: 'Sign in to view speaking history.',
      );
    }

    return FutureBuilder<bool>(
      future: SpeakingPremiumManager.loadHomeAccess().then(
        (value) => value.isPremium,
      ),
      builder: (context, premiumSnapshot) {
        final isPremium = premiumSnapshot.data ?? false;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('speaking_results')
              .orderBy('completedAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _MessageState(
                icon: Icons.cloud_off_rounded,
                title: 'Speaking history could not be synced',
                subtitle:
                    'Your recordings and evaluations are safe. Check your connection and reopen this screen.',
              );
            }
            if (!snapshot.hasData) {
              return const _MessageState(
                icon: Icons.auto_awesome_rounded,
                title: 'Loading speaking history',
                subtitle:
                    'Bringing together your latest estimated bands and feedback.',
              );
            }

            final allDocs = snapshot.data!.docs;
            final docs = isPremium
                ? allDocs
                : allDocs
                      .take(SpeakingPremiumManager.freeHistoryItems)
                      .toList();

            if (docs.isEmpty) {
              return const _MessageState(
                icon: Icons.history_rounded,
                title: 'No speaking results yet',
                subtitle: 'Complete a speaking activity to see results.',
              );
            }

            return Column(
              children: [
                ...docs.map((doc) {
                  final data = doc.data();
                  final band = _asDouble(data['overallBand']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(14),
                    decoration: _panelDecoration(),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: SColors.cyan.withOpacity(.12),
                          child: Text(
                            band.toStringAsFixed(1),
                            style: const TextStyle(
                              color: SColors.cyan,
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
                                (data['title'] ?? 'Speaking Practice')
                                    .toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SColors.text,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if (_asInt(data['cycleNumber'], 0) > 0)
                                    'Cycle ${_asInt(data['cycleNumber'], 1)}',
                                  (data['summary'] ??
                                          data['feedback'] ??
                                          'Speaking evaluation completed.')
                                      .toString(),
                                ].join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SColors.muted,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (!isPremium && allDocs.length > docs.length)
                  InkWell(
                    onTap: () => _openSpeakingPremium(
                      context,
                      source: 'speaking_history',
                    ),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: SColors.violet.withOpacity(.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: SColors.violet.withOpacity(.22),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: SColors.violet,
                          ),
                          SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Unlock extended Speaking history with Premium',
                              style: TextStyle(
                                color: SColors.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: SColors.violet,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
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
            'Evaluating Your Speaking',
            style: TextStyle(
              color: SColors.text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Analysing fluency, vocabulary, grammar, pronunciation and delivery.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SColors.secondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  final SpeakingReport report;

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
            style: TextStyle(color: SColors.secondary),
          ),
          const SizedBox(height: 8),
          Text(
            report.overallBand.toStringAsFixed(1),
            style: const TextStyle(
              color: SColors.cyan,
              fontSize: 50,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.summary,
            textAlign: TextAlign.center,
            style: const TextStyle(color: SColors.secondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _CriteriaGrid extends StatelessWidget {
  final SpeakingReport report;

  const _CriteriaGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Fluency & Coherence', report.fluencyAndCoherence),
      ('Lexical Resource', report.lexicalResource),
      ('Grammar', report.grammaticalRangeAndAccuracy),
      ('Pronunciation', report.pronunciation),
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
  final SpeakingCriterion criterion;

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
              color: SColors.cyan,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: SColors.text,
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
              color: SColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final SpeakingReport report;

  const _MetricsCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              value: '${report.speakingSpeedWpm}',
              label: 'Words/min',
            ),
          ),
          Expanded(
            child: _Metric(value: '${report.pauseCount}', label: 'Pauses'),
          ),
          Expanded(
            child: _Metric(
              value: '${report.fillerWords.length}',
              label: 'Filler types',
            ),
          ),
          Expanded(
            child: _Metric(
              value: '${report.answerRelevancePercent}%',
              label: 'Relevance',
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: SColors.cyan,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: SColors.muted, fontSize: 12),
        ),
      ],
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
              Icon(icon, color: SColors.cyan),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: SColors.text,
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

class _StringItems extends StatelessWidget {
  final List<String> items;

  const _StringItems({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyFeedback();

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: SColors.cyan,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    color: SColors.secondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
        color: SColors.background.withOpacity(.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: SColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              color: SColors.secondary,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeedback extends StatelessWidget {
  const _EmptyFeedback();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'No major issue was identified in this category.',
      style: TextStyle(color: SColors.muted),
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
        color: SColors.green.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SColors.green.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Action Plan',
            style: TextStyle(color: SColors.green, fontWeight: FontWeight.w900),
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
                    color: SColors.green,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: SColors.secondary),
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
            Icon(icon, color: SColors.cyan, size: 50),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SColors.muted, height: 1.5),
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
            color: SColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: SColors.muted, fontSize: 11.5),
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
        gradient: const LinearGradient(colors: [SColors.cyan, SColors.violet]),
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
        color: SColors.cyan.withOpacity(.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SColors.cyan.withOpacity(.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: SColors.cyan,
          fontSize: 9.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SpeakingBackground extends StatelessWidget {
  const _SpeakingBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [SColors.background, Color(0xFF0D172B), SColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

abstract final class SColors {
  static const background = Color(0xFF08111F);
  static const surface = Color(0xFF111C2E);
  static const border = Color(0xFF22324A);
  static const cyan = Color(0xFF06B6D4);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
}

BoxDecoration _panelDecoration() => BoxDecoration(
  color: SColors.surface.withOpacity(.94),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: SColors.border),
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
      SColors.surface,
      SColors.cyan.withOpacity(.09),
      SColors.violet.withOpacity(.08),
    ],
  ),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: SColors.cyan.withOpacity(.22)),
);

String _clock(int seconds) {
  final safe = math.max(0, seconds);
  final minutes = safe ~/ 60;
  final remaining = safe % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remaining.toString().padLeft(2, '0')}';
}

int _asInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
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
