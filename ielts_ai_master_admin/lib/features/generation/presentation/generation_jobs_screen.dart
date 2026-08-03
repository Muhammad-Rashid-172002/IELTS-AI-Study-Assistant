import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';

class GenerationJobsScreen extends StatelessWidget {
  const GenerationJobsScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchJobs() {
    // Client-side sorting use ki gayi hai taake composite index ki
    // requirement na aaye aur Listening + Reading dono jobs show hon.
    return FirebaseFirestore.instance.collection('generation_jobs').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'AI Generation Jobs',
      subtitle: 'Listening and Reading Gemini generation queue',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _watchJobs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _JobsErrorView(message: _friendlyError(snapshot.error));
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LoadingView();
          }

          final docs = [...?snapshot.data?.docs];

          docs.sort((a, b) {
            final firstDate = _timestampMillis(a.data()['createdAt']);
            final secondDate = _timestampMillis(b.data()['createdAt']);

            return secondDate.compareTo(firstDate);
          });

          if (docs.isEmpty) {
            return const _EmptyJobsView();
          }

          final total = docs.length;
          final queued = docs.where((doc) {
            return _status(doc.data()) == 'queued';
          }).length;

          final generating = docs.where((doc) {
            return _status(doc.data()) == 'generating';
          }).length;

          final completed = docs.where((doc) {
            return _status(doc.data()) == 'completed';
          }).length;

          final failed = docs.where((doc) {
            return _status(doc.data()) == 'failed';
          }).length;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                sliver: SliverToBoxAdapter(
                  child: _JobsSummary(
                    total: total,
                    queued: queued,
                    generating: generating,
                    completed: completed,
                    failed: failed,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                sliver: SliverList.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 11),
                  itemBuilder: (context, index) {
                    final document = docs[index];

                    return _GenerationJobCard(
                      jobId: document.id,
                      data: document.data(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _status(Map<String, dynamic> data) {
    return (data['status'] ?? 'queued').toString().trim().toLowerCase();
  }

  static int _timestampMillis(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }

  static String _friendlyError(Object? error) {
    final message = error?.toString() ?? '';

    if (message.contains('permission-denied')) {
      return 'Firestore permission denied. Admin Firestore rules check karein.';
    }

    if (message.contains('failed-precondition') ||
        message.toLowerCase().contains('index')) {
      return 'Firestore index required hai. Lekin updated screen client-side sorting use karti hai, isliye app ko full restart karein.';
    }

    return 'Generation jobs load nahi huay.\n$message';
  }
}

class _JobsSummary extends StatelessWidget {
  final int total;
  final int queued;
  final int generating;
  final int completed;
  final int failed;

  const _JobsSummary({
    required this.total,
    required this.queued,
    required this.generating,
    required this.completed,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _JobMetric(
        title: 'Total',
        value: total,
        icon: Icons.auto_awesome_rounded,
        color: AdminColors.cyan,
      ),
      _JobMetric(
        title: 'Queued',
        value: queued,
        icon: Icons.schedule_rounded,
        color: AdminColors.warning,
      ),
      _JobMetric(
        title: 'Generating',
        value: generating,
        icon: Icons.sync_rounded,
        color: AdminColors.violet,
      ),
      _JobMetric(
        title: 'Completed',
        value: completed,
        icon: Icons.check_circle_outline_rounded,
        color: AdminColors.success,
      ),
      _JobMetric(
        title: 'Failed',
        value: failed,
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFEF4444),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 5
            : constraints.maxWidth >= 650
            ? 3
            : 2;

        const spacing = 10.0;

        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics.map((metric) {
            return SizedBox(width: cardWidth, child: metric);
          }).toList(),
        );
      },
    );
  }
}

class _JobMetric extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _JobMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 10.5,
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

class _GenerationJobCard extends StatelessWidget {
  final String jobId;
  final Map<String, dynamic> data;

  const _GenerationJobCard({required this.jobId, required this.data});

  bool get _isReading {
    return (data['contentType'] ?? '').toString().toLowerCase() == 'reading';
  }

  String get _status {
    return (data['status'] ?? 'queued').toString();
  }

  String get _title {
    if (_isReading) {
      final mode = _readingModeTitle((data['mode'] ?? 'passage').toString());

      final questionType =
          (data['primaryQuestionType'] ?? data['questionType'] ?? '')
              .toString()
              .trim();

      if (questionType.isNotEmpty) {
        return '$questionType • $mode';
      }

      return 'Reading • $mode';
    }

    final questionType = (data['questionType'] ?? 'Listening').toString();

    final section = (data['section'] ?? '-').toString();

    return '$questionType • Section $section';
  }

  String get _subtitle {
    final requested = _asInt(data['requestedCount']);
    final generated = _asInt(data['generatedCount']);
    final failed = _asInt(data['failedCount']);

    if (_isReading) {
      final passages = _asInt(data['passageCount'], fallback: 1);

      final questions = _asInt(data['questionCount'], fallback: 10);

      return '$passages passage(s) • $questions questions\n'
          'Requested $requested • Generated $generated • Failed $failed';
    }

    return 'Requested $requested • Generated $generated • Failed $failed';
  }

  IconData get _icon {
    if (_isReading) {
      return Icons.menu_book_rounded;
    }

    return Icons.headphones_rounded;
  }

  Color get _moduleColor {
    if (_isReading) {
      return AdminColors.success;
    }

    return AdminColors.cyan;
  }

  @override
  Widget build(BuildContext context) {
    final lastError = (data['lastError'] ?? data['errorMessage'] ?? '')
        .toString()
        .trim();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _moduleColor.withOpacity(.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon, color: _moduleColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _title,
                            style: const TextStyle(
                              color: AdminColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        StatusBadge(status: _status),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                    if (lastError.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(.20),
                          ),
                        ),
                        child: Text(
                          lastError,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Job ID: $jobId',
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: AdminColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_icon, color: _moduleColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _title,
                          style: const TextStyle(
                            color: AdminColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    label: 'Content type',
                    value: _isReading ? 'Reading' : 'Listening',
                  ),
                  _DetailRow(label: 'Status', value: _status),
                  _DetailRow(
                    label: 'Requested',
                    value: '${_asInt(data['requestedCount'])}',
                  ),
                  _DetailRow(
                    label: 'Generated',
                    value: '${_asInt(data['generatedCount'])}',
                  ),
                  _DetailRow(
                    label: 'Failed',
                    value: '${_asInt(data['failedCount'])}',
                  ),
                  if (_isReading) ...[
                    _DetailRow(
                      label: 'Mode',
                      value: _readingModeTitle(
                        (data['mode'] ?? 'passage').toString(),
                      ),
                    ),
                    _DetailRow(
                      label: 'IELTS type',
                      value: (data['ieltsType'] ?? 'Academic').toString(),
                    ),
                    _DetailRow(
                      label: 'Question type',
                      value:
                          (data['primaryQuestionType'] ??
                                  data['questionType'] ??
                                  'Mixed')
                              .toString(),
                    ),
                  ] else ...[
                    _DetailRow(
                      label: 'Section',
                      value: (data['section'] ?? '-').toString(),
                    ),
                    _DetailRow(
                      label: 'Question type',
                      value: (data['questionType'] ?? '-').toString(),
                    ),
                  ],
                  _DetailRow(label: 'Job ID', value: jobId),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _readingModeTitle(String mode) {
    switch (mode.trim().toLowerCase()) {
      case 'academic':
        return 'Academic Reading';
      case 'general':
        return 'General Training';
      case 'question_type':
        return 'Question Type Practice';
      case 'timed':
        return 'Timed Reading';
      case 'full':
        return 'Full Reading Test';
      case 'speed':
        return 'Speed Reading';
      case 'exam':
        return 'Strict Exam Mode';
      case 'practice':
      case 'passage':
      default:
        return 'Passage Practice';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: AdminColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsErrorView extends StatelessWidget {
  final String message;

  const _JobsErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 48,
            ),
            const SizedBox(height: 14),
            const Text(
              'Generation jobs load nahi huay',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AdminColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminColors.textMuted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyJobsView extends StatelessWidget {
  const _EmptyJobsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: AdminColors.cyan,
              size: 54,
            ),
            SizedBox(height: 15),
            Text(
              'No generation jobs yet',
              style: TextStyle(
                color: AdminColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Listening ya Reading module se AI generation job create karein.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
