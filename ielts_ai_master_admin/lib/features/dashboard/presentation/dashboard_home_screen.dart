import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ielts_ai_master_admin/core/theme/admin_theme.dart';
import 'package:ielts_ai_master_admin/core/widgets/admin_scaffold.dart';

class DashboardHomeScreen extends StatefulWidget {
  final VoidCallback? onOpenListening;
  final VoidCallback? onOpenReading;
  final VoidCallback? onOpenWriting;
  final VoidCallback? onOpenSpeaking;
  final VoidCallback? onOpenVocabulary;
  final VoidCallback? onOpenMockTests;
  final VoidCallback? onOpenJobs;
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenDiagnostics;
  final VoidCallback? onOpenSubscriptions;

  const DashboardHomeScreen({
    super.key,
    this.onOpenListening,
    this.onOpenReading,
    this.onOpenWriting,
    this.onOpenSpeaking,
    this.onOpenVocabulary,
    this.onOpenMockTests,
    this.onOpenJobs,
    this.onOpenUsers,
    this.onOpenDiagnostics,
    this.onOpenSubscriptions,
  });

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subscriptions = [];

  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _collections = {};

  bool _loading = true;
  String? _error;

  static const List<String> _contentCollections = [
    'listening_tests',
    'reading_tests',
    'writing_tasks',
    'speaking_tests',
    'vocabulary_words',
  ];

  static const List<String> _rootCollections = [
    ..._contentCollections,
    'generation_jobs',
    'users',
    'subscription_requests',
    'diagnostic_tests',
    'mock_tests',
  ];

  static const List<String> _learnerCollectionGroups = [
    'listening_results',
    'reading_results',
    'writing_results',
    'speaking_results',
    'mock_attempts',
    'diagnostic_results',
    'certificates',
  ];

  static const List<String> _allCollections = [
    ..._rootCollections,
    ..._learnerCollectionGroups,
  ];

  @override
  void initState() {
    super.initState();
    _listenToDashboardData();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _listenToDashboardData() {
    for (final collection in _rootCollections) {
      final subscription = _firestore
          .collection(collection)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted) return;

              setState(() {
                _collections[collection] = snapshot.docs;
                _loading = !_allCollections.every(_collections.containsKey);
                _error = null;
              });
            },
            onError: (Object error) {
              if (!mounted) return;

              setState(() {
                _collections.putIfAbsent(collection, () => []);
                _loading = !_allCollections.every(_collections.containsKey);
                _error =
                    'Some dashboard data could not be loaded. Check Firestore rules.';
              });
            },
          );

      _subscriptions.add(subscription);
    }

    for (final collection in _learnerCollectionGroups) {
      final subscription = _firestore
          .collectionGroup(collection)
          .limit(1000)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted) return;
              setState(() {
                _collections[collection] = snapshot.docs;
                _loading = !_allCollections.every(_collections.containsKey);
                _error = null;
              });
            },
            onError: (Object error) {
              if (!mounted) return;
              setState(() {
                _collections.putIfAbsent(collection, () => []);
                _loading = !_allCollections.every(_collections.containsKey);
                _error =
                    'Some learner activity could not be loaded. Check Firestore rules and indexes.';
              });
            },
          );
      _subscriptions.add(subscription);
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs(String collection) =>
      _collections[collection] ?? const [];

  int _statusCount(String collection, String status) {
    return _docs(collection)
        .where(
          (doc) =>
              (doc.data()['status'] ?? '').toString().toLowerCase() == status,
        )
        .length;
  }

  int get _totalContent => _contentCollections.fold(
    0,
    (total, collection) => total + _docs(collection).length,
  );

  int get _publishedContent => _contentCollections.fold(
    0,
    (total, collection) => total + _statusCount(collection, 'published'),
  );

  int get _draftContent => _contentCollections.fold(
    0,
    (total, collection) => total + _statusCount(collection, 'draft'),
  );

  int get _archivedContent => _contentCollections.fold(
    0,
    (total, collection) => total + _statusCount(collection, 'archived'),
  );

  int get _activeJobs {
    const activeStatuses = {'queued', 'generating', 'processing'};
    return _docs('generation_jobs')
        .where(
          (doc) => activeStatuses.contains(
            (doc.data()['status'] ?? '').toString().toLowerCase(),
          ),
        )
        .length;
  }

  int get _failedJobs => _statusCount('generation_jobs', 'failed');

  int get _completedJobs => _statusCount('generation_jobs', 'completed');

  int get _pendingSubscriptions =>
      _statusCount('subscription_requests', 'pending');

  int get _approvedSubscriptions =>
      _statusCount('subscription_requests', 'approved');

  int get _rejectedSubscriptions =>
      _statusCount('subscription_requests', 'rejected');

  int get _activePremiumUsers => _docs('users').where((doc) {
    final data = doc.data();
    final premium = data['isPremium'] == true || data['premium'] == true;
    final status = (data['subscriptionStatus'] ?? '').toString().toLowerCase();

    return premium || status == 'active';
  }).length;

  double get _jobSuccessRate {
    final completed = _completedJobs;
    final failed = _failedJobs;
    final finished = completed + failed;

    if (finished == 0) return 0;
    return completed / finished;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _recentJobs {
    final jobs = [..._docs('generation_jobs')];

    jobs.sort((a, b) {
      final aDate = a.data()['createdAt'];
      final bDate = b.data()['createdAt'];

      final aMillis = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
      final bMillis = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;

      return bMillis.compareTo(aMillis);
    });

    return jobs.take(6).toList();
  }

  DateTime? _dateFrom(Map<String, dynamic> data, List<String> candidateFields) {
    for (final field in candidateFields) {
      final value = data[field];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  int _usersActiveWithin(Duration duration) {
    final threshold = DateTime.now().subtract(duration);
    return _docs('users').where((doc) {
      final data = doc.data();
      final status = (data['accountStatus'] ?? 'active')
          .toString()
          .toLowerCase();
      if (data['isDisabled'] == true || status == 'suspended') return false;
      final lastActive = _dateFrom(data, const [
        'lastActive',
        'lastSeen',
        'lastLoginAt',
        'updatedAt',
      ]);
      return lastActive != null && !lastActive.isBefore(threshold);
    }).length;
  }

  int get _newRegistrations {
    final threshold = DateTime.now().subtract(const Duration(days: 30));
    return _docs('users').where((doc) {
      final created = _dateFrom(doc.data(), const [
        'createdAt',
        'registrationDate',
      ]);
      return created != null && !created.isBefore(threshold);
    }).length;
  }

  int _ieltsTrackCount(bool generalTraining) {
    return _docs('users').where((doc) {
      final data = doc.data();
      final type =
          (data['ieltsType'] ??
                  data['selectedIeltsType'] ??
                  data['testType'] ??
                  'Academic')
              .toString()
              .toLowerCase();
      return generalTraining
          ? type.contains('general')
          : !type.contains('general');
    }).length;
  }

  double get _averageEstimatedBand {
    final bands = _docs('users')
        .map((doc) {
          final data = doc.data();
          final value =
              data['currentBand'] ??
              data['estimatedBand'] ??
              data['overallBand'];
          return value is num
              ? value.toDouble()
              : double.tryParse(value?.toString() ?? '');
        })
        .whereType<double>()
        .where((band) => band > 0 && band <= 9)
        .toList();
    if (bands.isEmpty) return 0;
    return bands.reduce((a, b) => a + b) / bands.length;
  }

  int get _completedDiagnostics => _docs('diagnostic_results').where((doc) {
    final status = (doc.data()['status'] ?? 'completed')
        .toString()
        .toLowerCase();
    return status == 'completed' || status == 'evaluated';
  }).length;

  int get _completedMocks => _docs('mock_attempts').where((doc) {
    final status = (doc.data()['status'] ?? '').toString().toLowerCase();
    return const {
      'completed',
      'evaluated',
      'ready',
      'submitted',
    }.contains(status);
  }).length;

  @override
  Widget build(BuildContext context) {
    final errorMessage = _error;

    return AdminScaffold(
      title: 'Dashboard',
      subtitle: 'Content, users, subscriptions and platform health',
      body: _loading
          ? const _DashboardLoading()
          : RefreshIndicator(
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 450));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (errorMessage != null) ...[
                    _WarningBanner(message: errorMessage),
                    const SizedBox(height: 14),
                  ],
                  _buildHero(),
                  const SizedBox(height: 18),
                  _buildPrimaryMetrics(),
                  const SizedBox(height: 22),
                  const _SectionHeading(
                    title: 'Learner Intelligence',
                    subtitle:
                        'Live engagement, track mix and assessment outcomes',
                  ),
                  const SizedBox(height: 12),
                  _buildLearnerIntelligence(),
                  const SizedBox(height: 22),
                  const _SectionHeading(
                    title: 'Content Inventory',
                    subtitle: 'Live content totals across every IELTS module',
                  ),
                  const SizedBox(height: 12),
                  _buildModuleCards(),
                  const SizedBox(height: 22),
                  _buildAnalyticsRow(),
                  const SizedBox(height: 22),
                  _buildSubscriptionOverview(),
                  const SizedBox(height: 22),
                  _buildBottomContent(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.primary.withOpacity(.26),
            AdminColors.cyan.withOpacity(.11),
            AdminColors.violet.withOpacity(.20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AdminColors.cyan.withOpacity(.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;

          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  _HeroIcon(),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IELTS AI Content Platform',
                          style: TextStyle(
                            color: AdminColors.text,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.4,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Generate, validate, publish and monitor all IELTS learning content from one place.',
                          style: TextStyle(
                            color: AdminColors.textMuted,
                            height: 1.45,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _HeroChip(icon: Icons.headphones_rounded, label: 'Listening'),
                  _HeroChip(icon: Icons.menu_book_rounded, label: 'Reading'),
                  _HeroChip(icon: Icons.edit_note_rounded, label: 'Writing'),
                  _HeroChip(icon: Icons.mic_rounded, label: 'Speaking'),
                  _HeroChip(icon: Icons.translate_rounded, label: 'Vocabulary'),
                  _HeroChip(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Premium',
                  ),
                ],
              ),
            ],
          );

          final actions = Wrap(
            spacing: 9,
            runSpacing: 9,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _QuickAction(
                label: 'Listening',
                icon: Icons.headphones_rounded,
                color: AdminColors.cyan,
                onPressed: widget.onOpenListening,
              ),
              _QuickAction(
                label: 'Reading',
                icon: Icons.menu_book_rounded,
                color: AdminColors.success,
                onPressed: widget.onOpenReading,
              ),
              _QuickAction(
                label: 'Writing',
                icon: Icons.edit_note_rounded,
                color: AdminColors.violet,
                onPressed: widget.onOpenWriting,
              ),
              _QuickAction(
                label: 'Speaking',
                icon: Icons.mic_rounded,
                color: const Color(0xFFF97316),
                onPressed: widget.onOpenSpeaking,
              ),
              _QuickAction(
                label: 'Vocabulary',
                icon: Icons.translate_rounded,
                color: const Color(0xFFEAB308),
                onPressed: widget.onOpenVocabulary,
              ),
              _QuickAction(
                label: 'AI Jobs',
                icon: Icons.auto_awesome_rounded,
                color: AdminColors.primary,
                onPressed: widget.onOpenJobs,
              ),
              _QuickAction(
                label: 'Subscriptions',
                icon: Icons.workspace_premium_rounded,
                color: const Color(0xFFF59E0B),
                onPressed: widget.onOpenSubscriptions,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 18), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: intro),
              const SizedBox(width: 20),
              Expanded(child: actions),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPrimaryMetrics() {
    final metrics = [
      _MetricData(
        title: 'Total Content',
        value: '$_totalContent',
        subtitle: 'Across all IELTS modules',
        icon: Icons.inventory_2_outlined,
        color: AdminColors.warning,
      ),
      _MetricData(
        title: 'Published',
        value: '$_publishedContent',
        subtitle: 'Available to learners',
        icon: Icons.public_rounded,
        color: AdminColors.success,
      ),
      _MetricData(
        title: 'Registered Users',
        value: '${_docs('users').length}',
        subtitle: 'Learner accounts',
        icon: Icons.people_rounded,
        color: AdminColors.violet,
      ),
      _MetricData(
        title: 'Premium Users',
        value: '$_activePremiumUsers',
        subtitle: 'Active paid access',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _MetricData(
        title: 'Pending Payments',
        value: '$_pendingSubscriptions',
        subtitle: 'Require admin review',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFF97316),
      ),
      _MetricData(
        title: 'Active AI Jobs',
        value: '$_activeJobs',
        subtitle: 'Queued or generating',
        icon: Icons.sync_rounded,
        color: AdminColors.cyan,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1180
            ? 6
            : width >= 800
            ? 3
            : width >= 520
            ? 2
            : 1;
        const spacing = 12.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: cardWidth,
                  child: _MetricCard(data: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildModuleCards() {
    final modules = [
      _ModuleData(
        title: 'Listening',
        subtitle: 'Audio-based IELTS practice',
        collection: 'listening_tests',
        icon: Icons.headphones_rounded,
        color: AdminColors.cyan,
        onTap: widget.onOpenListening,
      ),
      _ModuleData(
        title: 'Reading',
        subtitle: 'Passages, questions and analytics',
        collection: 'reading_tests',
        icon: Icons.menu_book_rounded,
        color: AdminColors.success,
        onTap: widget.onOpenReading,
      ),
      _ModuleData(
        title: 'Writing',
        subtitle: 'Tasks, prompts and AI evaluation',
        collection: 'writing_tasks',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: widget.onOpenWriting,
      ),
      _ModuleData(
        title: 'Speaking',
        subtitle: 'Tests, recordings and band feedback',
        collection: 'speaking_tests',
        icon: Icons.mic_rounded,
        color: const Color(0xFFF97316),
        onTap: widget.onOpenSpeaking,
      ),
      _ModuleData(
        title: 'Vocabulary',
        subtitle: 'Words, translations and mastery',
        collection: 'vocabulary_words',
        icon: Icons.translate_rounded,
        color: const Color(0xFFEAB308),
        onTap: widget.onOpenVocabulary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 700
            ? 3
            : constraints.maxWidth >= 460
            ? 2
            : 1;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: modules.map((module) {
            final docs = _docs(module.collection);
            final published = _statusCount(module.collection, 'published');
            final draft = _statusCount(module.collection, 'draft');

            return SizedBox(
              width: width,
              child: _ModuleCard(
                data: module,
                total: docs.length,
                published: published,
                drafts: draft,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLearnerIntelligence() {
    final averageBand = _averageEstimatedBand;
    final metrics = [
      _MetricData(
        title: 'Daily Active',
        value: '${_usersActiveWithin(const Duration(days: 1))}',
        subtitle: 'Active in the last 24 hours',
        icon: Icons.today_rounded,
        color: AdminColors.success,
      ),
      _MetricData(
        title: 'Weekly Active',
        value: '${_usersActiveWithin(const Duration(days: 7))}',
        subtitle: 'Active in the last 7 days',
        icon: Icons.date_range_rounded,
        color: AdminColors.cyan,
      ),
      _MetricData(
        title: 'Monthly Active',
        value: '${_usersActiveWithin(const Duration(days: 30))}',
        subtitle: 'Active in the last 30 days',
        icon: Icons.calendar_month_rounded,
        color: AdminColors.primary,
      ),
      _MetricData(
        title: 'New Registrations',
        value: '$_newRegistrations',
        subtitle: 'Joined in the last 30 days',
        icon: Icons.person_add_alt_1_rounded,
        color: AdminColors.violet,
      ),
      _MetricData(
        title: 'Academic',
        value: '${_ieltsTrackCount(false)}',
        subtitle: 'Academic-track learners',
        icon: Icons.school_outlined,
        color: const Color(0xFF38BDF8),
      ),
      _MetricData(
        title: 'General Training',
        value: '${_ieltsTrackCount(true)}',
        subtitle: 'General Training learners',
        icon: Icons.work_outline_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _MetricData(
        title: 'Average Band',
        value: averageBand == 0 ? '—' : averageBand.toStringAsFixed(1),
        subtitle: 'Across stored estimates',
        icon: Icons.insights_rounded,
        color: AdminColors.warning,
      ),
      _MetricData(
        title: 'Diagnostics',
        value: '$_completedDiagnostics',
        subtitle: 'Completed assessments',
        icon: Icons.health_and_safety_outlined,
        color: AdminColors.success,
      ),
      _MetricData(
        title: 'Mock Tests',
        value: '$_completedMocks',
        subtitle: 'Submitted or evaluated',
        icon: Icons.fact_check_outlined,
        color: AdminColors.violet,
      ),
      _MetricData(
        title: 'Writing Evaluations',
        value: '${_docs('writing_results').length}',
        subtitle: 'AI reports completed',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFFA78BFA),
      ),
      _MetricData(
        title: 'Speaking Evaluations',
        value: '${_docs('speaking_results').length}',
        subtitle: 'AI reports completed',
        icon: Icons.mic_rounded,
        color: const Color(0xFFF97316),
      ),
      _MetricData(
        title: 'Skill Attempts',
        value:
            '${_docs('listening_results').length + _docs('reading_results').length}',
        subtitle: 'Listening and reading attempts',
        icon: Icons.stacked_bar_chart_rounded,
        color: AdminColors.cyan,
      ),
      _MetricData(
        title: 'Certificates',
        value: '${_docs('certificates').length}',
        subtitle: 'Credentials issued',
        icon: Icons.workspace_premium_outlined,
        color: const Color(0xFFEAB308),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 800
            ? 3
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricCard(data: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildAnalyticsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        final successCard = _SuccessRateCard(
          completed: _completedJobs,
          failed: _failedJobs,
          rate: _jobSuccessRate,
        );

        final publishingCard = _PublishingCard(
          published: _publishedContent,
          drafts: _draftContent,
          archived: _archivedContent,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [successCard, const SizedBox(height: 12), publishingCard],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: successCard),
            const SizedBox(width: 12),
            Expanded(child: publishingCard),
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionOverview() {
    final total = _docs('subscription_requests').length;
    final reviewed = _approvedSubscriptions + _rejectedSubscriptions;
    final approvalRate = reviewed == 0
        ? 0.0
        : _approvedSubscriptions / reviewed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(.12),
            AdminColors.primary.withOpacity(.12),
            AdminColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0x22F59E0B),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subscription Operations',
                          style: TextStyle(
                            color: AdminColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Monitor payment requests and premium activation',
                          style: TextStyle(
                            color: AdminColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SubscriptionMiniMetric(
                    label: 'Total Requests',
                    value: '$total',
                    color: AdminColors.cyan,
                  ),
                  _SubscriptionMiniMetric(
                    label: 'Pending',
                    value: '$_pendingSubscriptions',
                    color: const Color(0xFFF97316),
                  ),
                  _SubscriptionMiniMetric(
                    label: 'Approved',
                    value: '$_approvedSubscriptions',
                    color: AdminColors.success,
                  ),
                  _SubscriptionMiniMetric(
                    label: 'Rejected',
                    value: '$_rejectedSubscriptions',
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ],
          );

          final action = Column(
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: approvalRate,
                      strokeWidth: 10,
                      color: AdminColors.success,
                      backgroundColor: AdminColors.border,
                    ),
                    Text(
                      '${(approvalRate * 100).round()}%',
                      style: const TextStyle(
                        color: AdminColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Approval rate',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 9.5),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onOpenSubscriptions,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Review Payments'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [heading, const SizedBox(height: 18), action],
            );
          }

          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 24),
              action,
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;

        final jobs = _RecentJobsPanel(jobs: _recentJobs);
        final actions = _QuickActionsPanel(
          onListening: widget.onOpenListening,
          onReading: widget.onOpenReading,
          onWriting: widget.onOpenWriting,
          onSpeaking: widget.onOpenSpeaking,
          onVocabulary: widget.onOpenVocabulary,
          onJobs: widget.onOpenJobs,
          onUsers: widget.onOpenUsers,
          onSubscriptions: widget.onOpenSubscriptions,
        );

        if (compact) {
          return Column(children: [jobs, const SizedBox(height: 12), actions]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: jobs),
            const SizedBox(width: 12),
            Expanded(child: actions),
          ],
        );
      },
    );
  }
}

class _SubscriptionMiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SubscriptionMiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 8.8),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 18),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminColors.cyan, AdminColors.primary],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AdminColors.surface.withOpacity(.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AdminColors.cyan),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(.28)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AdminColors.text,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: data.color.withOpacity(.13),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(height: 15),
          Text(
            data.value,
            style: TextStyle(
              color: data.color,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.title,
            style: const TextStyle(
              color: AdminColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _ModuleData {
  final String title;
  final String subtitle;
  final String collection;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ModuleData({
    required this.title,
    required this.subtitle,
    required this.collection,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

class _ModuleCard extends StatelessWidget {
  final _ModuleData data;
  final int total;
  final int published;
  final int drafts;

  const _ModuleCard({
    required this.data,
    required this.total,
    required this.published,
    required this.drafts,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AdminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: data.color.withOpacity(.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(data.icon, color: data.color),
                  ),
                  const Spacer(),
                  Text(
                    '$total',
                    style: TextStyle(
                      color: data.color,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                data.title,
                style: const TextStyle(
                  color: AdminColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminColors.textMuted,
                  fontSize: 9.7,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MiniStat(
                    label: 'Published',
                    value: published,
                    color: AdminColors.success,
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    label: 'Draft',
                    value: drafts,
                    color: AdminColors.cyan,
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

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;

        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AdminColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ],
        );

        if (trailing == null) return heading;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 10), trailing!],
          );
        }

        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 12),
            trailing!,
          ],
        );
      },
    );
  }
}

class _SuccessRateCard extends StatelessWidget {
  final int completed;
  final int failed;
  final double rate;

  const _SuccessRateCard({
    required this.completed,
    required this.failed,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (rate * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 9,
                  color: AdminColors.success,
                  backgroundColor: AdminColors.border,
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: AdminColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
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
                  'AI Generation Success Rate',
                  style: TextStyle(
                    color: AdminColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$completed completed • $failed failed',
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Calculated from completed and failed generation jobs.',
                  style: TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 9.5,
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

class _PublishingCard extends StatelessWidget {
  final int published;
  final int drafts;
  final int archived;

  const _PublishingCard({
    required this.published,
    required this.drafts,
    required this.archived,
  });

  @override
  Widget build(BuildContext context) {
    final total = published + drafts + archived;
    final publishRate = total == 0 ? 0.0 : published / total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Publishing Overview',
            style: TextStyle(
              color: AdminColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: publishRate,
            minHeight: 9,
            borderRadius: BorderRadius.circular(20),
            color: AdminColors.cyan,
            backgroundColor: AdminColors.border,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatusLegend(
                label: 'Published',
                value: published,
                color: AdminColors.success,
              ),
              _StatusLegend(
                label: 'Draft',
                value: drafts,
                color: AdminColors.cyan,
              ),
              _StatusLegend(
                label: 'Archived',
                value: archived,
                color: AdminColors.violet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatusLegend({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _RecentJobsPanel extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs;

  const _RecentJobsPanel({required this.jobs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Recent AI Generation Jobs',
            subtitle: 'Latest activity across every content module',
          ),
          const SizedBox(height: 12),
          if (jobs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No generation jobs yet.',
                  style: TextStyle(color: AdminColors.textMuted),
                ),
              ),
            )
          else
            ...jobs.map((doc) {
              final data = doc.data();
              final contentType = (data['contentType'] ?? 'content').toString();
              final status = (data['status'] ?? 'queued').toString();
              final isReading = contentType == 'reading';

              final title = isReading
                  ? '${data['mode'] ?? 'Reading'} • ${data['ieltsType'] ?? 'Academic'}'
                  : '${data['questionType'] ?? 'Listening'} • Section ${data['section'] ?? '-'}';

              return _JobTile(
                title: title,
                subtitle:
                    '${data['requestedCount'] ?? 0} requested • ${contentType.toUpperCase()}',
                status: status,
                icon: isReading
                    ? Icons.menu_book_rounded
                    : Icons.headphones_rounded,
              );
            }),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final IconData icon;

  const _JobTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'completed' => AdminColors.success,
      'failed' => const Color(0xFFEF4444),
      'generating' || 'processing' => AdminColors.warning,
      _ => AdminColors.cyan,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(.10),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(.09),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color.withOpacity(.24)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  final VoidCallback? onListening;
  final VoidCallback? onReading;
  final VoidCallback? onWriting;
  final VoidCallback? onSpeaking;
  final VoidCallback? onVocabulary;
  final VoidCallback? onJobs;
  final VoidCallback? onUsers;
  final VoidCallback? onSubscriptions;

  const _QuickActionsPanel({
    required this.onListening,
    required this.onReading,
    required this.onWriting,
    required this.onSpeaking,
    required this.onVocabulary,
    required this.onJobs,
    required this.onUsers,
    required this.onSubscriptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Quick Actions',
            subtitle: 'Open content and platform tools instantly',
          ),
          const SizedBox(height: 14),
          _ActionTile(
            icon: Icons.headphones_rounded,
            title: 'Manage Listening',
            subtitle: 'Audio tests, sections and publishing',
            color: AdminColors.cyan,
            onTap: onListening,
          ),
          _ActionTile(
            icon: Icons.menu_book_rounded,
            title: 'Manage Reading',
            subtitle: 'Passages, question types and tests',
            color: AdminColors.success,
            onTap: onReading,
          ),
          _ActionTile(
            icon: Icons.edit_note_rounded,
            title: 'Manage Writing',
            subtitle: 'Tasks, model answers and evaluation',
            color: AdminColors.violet,
            onTap: onWriting,
          ),
          _ActionTile(
            icon: Icons.mic_rounded,
            title: 'Manage Speaking',
            subtitle: 'Cue cards, recordings and reports',
            color: const Color(0xFFF97316),
            onTap: onSpeaking,
          ),
          _ActionTile(
            icon: Icons.translate_rounded,
            title: 'Manage Vocabulary',
            subtitle: 'Words, translations and mastery',
            color: const Color(0xFFEAB308),
            onTap: onVocabulary,
          ),
          _ActionTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Review AI Jobs',
            subtitle: 'Generation queue, success and failures',
            color: AdminColors.primary,
            onTap: onJobs,
          ),
          _ActionTile(
            icon: Icons.people_rounded,
            title: 'Manage Users',
            subtitle: 'Learners, access and activity',
            color: AdminColors.violet,
            onTap: onUsers,
          ),
          _ActionTile(
            icon: Icons.workspace_premium_rounded,
            title: 'Review Subscriptions',
            subtitle: 'Payments, approvals and premium access',
            color: const Color(0xFFF59E0B),
            onTap: onSubscriptions,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AdminColors.background.withOpacity(.48),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AdminColors.textMuted,
                          fontSize: 8.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;

  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AdminColors.warning.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.warning.withOpacity(.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AdminColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AdminColors.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AdminColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.10),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
