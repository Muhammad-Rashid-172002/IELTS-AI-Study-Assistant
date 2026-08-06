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
      subtitle: 'Listening, Reading, Writing and Speaking AI generation queue',
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
                  child: _JobsOverviewHero(
                    total: total,
                    active: queued + generating,
                    completed: completed,
                    failed: failed,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
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

class _JobsOverviewHero extends StatelessWidget {
  final int total;
  final int active;
  final int completed;
  final int failed;

  const _JobsOverviewHero({
    required this.total,
    required this.active,
    required this.completed,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    final completionRate = total == 0 ? 0.0 : completed / total;
    final safeRate = completionRate.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF102A43), Color(0xFF173B57), Color(0xFF2A245E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(.08)),
        boxShadow: [
          BoxShadow(
            color: AdminColors.cyan.withOpacity(.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.08),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white.withOpacity(.08)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: AdminColors.cyan,
                      size: 15,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'AI CONTENT PIPELINE',
                      style: TextStyle(
                        color: AdminColors.cyan,
                        fontSize: 9.5,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Generation Operations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$active active job${active == 1 ? '' : 's'} across all IELTS modules',
                style: TextStyle(
                  color: Colors.white.withOpacity(.70),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          );

          final progress = Container(
            width: compact ? double.infinity : 220,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Completion rate',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(safeRate * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: safeRate,
                    backgroundColor: Colors.white.withOpacity(.10),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AdminColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _HeroMiniStat(
                      icon: Icons.check_circle_rounded,
                      value: '$completed',
                      label: 'Done',
                      color: AdminColors.success,
                    ),
                    const SizedBox(width: 16),
                    _HeroMiniStat(
                      icon: Icons.error_rounded,
                      value: '$failed',
                      label: 'Failed',
                      color: Color(0xFFFF6B6B),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 18), progress],
            );
          }

          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 20),
              progress,
            ],
          );
        },
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _HeroMiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$value $label',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
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
      height: 94,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withOpacity(.20)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            top: -18,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(.06),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(.22), color.withOpacity(.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: color.withOpacity(.18)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: const TextStyle(
                        color: AdminColors.text,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        letterSpacing: .3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  String get _contentType {
    final raw = (data['contentType'] ?? data['module'] ?? data['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (raw.contains('read')) return 'reading';
    if (raw.contains('writ')) return 'writing';
    if (raw.contains('speak')) return 'speaking';
    return 'listening';
  }

  bool get _isReading => _contentType == 'reading';
  bool get _isWriting => _contentType == 'writing';
  bool get _isSpeaking => _contentType == 'speaking';

  String get _status => (data['status'] ?? 'queued').toString();

  String get _moduleLabel {
    switch (_contentType) {
      case 'reading':
        return 'Reading';
      case 'writing':
        return 'Writing';
      case 'speaking':
        return 'Speaking';
      default:
        return 'Listening';
    }
  }

  String get _title {
    if (_isReading) {
      final mode = _readingModeTitle((data['mode'] ?? 'passage').toString());
      final questionType =
          (data['primaryQuestionType'] ?? data['questionType'] ?? '')
              .toString()
              .trim();
      return questionType.isEmpty ? 'Reading • $mode' : '$questionType • $mode';
    }

    if (_isWriting) {
      final task =
          (data['taskType'] ?? data['task'] ?? data['questionType'] ?? '')
              .toString()
              .trim();
      final mode = (data['mode'] ?? data['ieltsType'] ?? '').toString().trim();
      if (task.isNotEmpty && mode.isNotEmpty) return '$task • $mode';
      if (task.isNotEmpty) return 'Writing • $task';
      return 'Writing Content Generation';
    }

    if (_isSpeaking) {
      final part = (data['part'] ?? data['section'] ?? '').toString().trim();
      final topic = (data['topic'] ?? data['questionType'] ?? '')
          .toString()
          .trim();
      if (topic.isNotEmpty && part.isNotEmpty) return '$topic • Part $part';
      if (part.isNotEmpty) return 'Speaking • Part $part';
      return 'Speaking Test Generation';
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

    if (_isWriting) {
      final prompts = _asInt(data['promptCount'], fallback: requested);
      return '$prompts writing prompt(s)\n'
          'Requested $requested • Generated $generated • Failed $failed';
    }

    if (_isSpeaking) {
      final questions = _asInt(data['questionCount'], fallback: requested);
      return '$questions speaking question(s)\n'
          'Requested $requested • Generated $generated • Failed $failed';
    }

    return 'Requested $requested • Generated $generated • Failed $failed';
  }

  IconData get _icon {
    switch (_contentType) {
      case 'reading':
        return Icons.menu_book_rounded;
      case 'writing':
        return Icons.edit_note_rounded;
      case 'speaking':
        return Icons.record_voice_over_rounded;
      default:
        return Icons.headphones_rounded;
    }
  }

  Color get _moduleColor {
    switch (_contentType) {
      case 'reading':
        return AdminColors.success;
      case 'writing':
        return AdminColors.violet;
      case 'speaking':
        return const Color(0xFFFF9F43);
      default:
        return AdminColors.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastError = (data['lastError'] ?? data['errorMessage'] ?? '')
        .toString()
        .trim();
    final normalizedStatus = _status.trim().toLowerCase();
    final statusColor = _statusColor(normalizedStatus);
    final createdAt = _formatTimestamp(data['createdAt']);
    final progress = _progressValue();

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _moduleColor.withOpacity(.16)),
        boxShadow: [
          BoxShadow(
            color: _moduleColor.withOpacity(.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showDetails(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 460;
                final icon = _ModuleIcon(icon: _icon, color: _moduleColor);
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AdminColors.text,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        StatusBadge(status: _status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: _moduleColor.withOpacity(.10),
                                valueColor: AlwaysStoppedAnimation(
                                  _moduleColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(progress * 100).round()}%',
                            style: TextStyle(
                              color: _moduleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (lastError.isNotEmpty) ...[
                      const SizedBox(height: 11),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(.20),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFFF6B6B),
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lastError,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFF8A8A),
                                  fontSize: 10.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        _ModulePill(label: _moduleLabel, color: _moduleColor),
                        const SizedBox(width: 8),
                        if (createdAt.isNotEmpty)
                          Expanded(
                            child: Text(
                              createdAt,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AdminColors.textMuted,
                                fontSize: 9.5,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: AdminColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [icon, const SizedBox(height: 13), content],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: 14),
                    Expanded(child: content),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double? _progressValue() {
    final requested = _asInt(data['requestedCount']);
    final generated = _asInt(data['generatedCount']);
    if (requested <= 0) return null;
    return (generated / requested).clamp(0.0, 1.0);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AdminColors.success;
      case 'failed':
        return const Color(0xFFEF4444);
      case 'generating':
        return AdminColors.violet;
      case 'queued':
      default:
        return AdminColors.warning;
    }
  }

  String _formatTimestamp(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (date == null) return '';

    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} • $hour:$minute $period';
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .84,
          ),
          decoration: const BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AdminColors.textMuted.withOpacity(.35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _ModuleIcon(icon: _icon, color: _moduleColor, size: 44),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _title,
                                style: const TextStyle(
                                  color: AdminColors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _moduleLabel,
                                style: TextStyle(
                                  color: _moduleColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(label: 'Content type', value: _moduleLabel),
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
                    ..._moduleDetailRows(),
                    _DetailRow(label: 'Job ID', value: jobId),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _moduleDetailRows() {
    if (_isReading) {
      return [
        _DetailRow(
          label: 'Mode',
          value: _readingModeTitle((data['mode'] ?? 'passage').toString()),
        ),
        _DetailRow(
          label: 'IELTS type',
          value: (data['ieltsType'] ?? 'Academic').toString(),
        ),
        _DetailRow(
          label: 'Question type',
          value:
              (data['primaryQuestionType'] ?? data['questionType'] ?? 'Mixed')
                  .toString(),
        ),
      ];
    }

    if (_isWriting) {
      return [
        _DetailRow(
          label: 'Task type',
          value: (data['taskType'] ?? data['task'] ?? 'Mixed').toString(),
        ),
        _DetailRow(
          label: 'IELTS type',
          value: (data['ieltsType'] ?? 'Academic').toString(),
        ),
      ];
    }

    if (_isSpeaking) {
      return [
        _DetailRow(
          label: 'Speaking part',
          value: (data['part'] ?? data['section'] ?? 'Mixed').toString(),
        ),
        _DetailRow(
          label: 'Topic',
          value: (data['topic'] ?? data['questionType'] ?? 'General')
              .toString(),
        ),
      ];
    }

    return [
      _DetailRow(label: 'Section', value: (data['section'] ?? '-').toString()),
      _DetailRow(
        label: 'Question type',
        value: (data['questionType'] ?? '-').toString(),
      ),
    ];
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

class _ModuleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _ModuleIcon({required this.icon, required this.color, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(.24), color.withOpacity(.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * .31),
        border: Border.all(color: color.withOpacity(.22)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * .48),
    );
  }
}

class _ModulePill extends StatelessWidget {
  final String label;
  final Color color;

  const _ModulePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              letterSpacing: .7,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AdminColors.background.withOpacity(.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 360;

          final labelWidget = Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 9,
              letterSpacing: .7,
              fontWeight: FontWeight.w800,
            ),
          );

          final valueWidget = SelectableText(
            value,
            style: const TextStyle(
              color: AdminColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              height: 1.35,
            ),
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 6), valueWidget],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 112, child: labelWidget),
              const SizedBox(width: 12),
              Expanded(child: valueWidget),
            ],
          );
        },
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
              'Listening, Reading, Writing ya Speaking module se AI generation job create karein.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
