import 'package:flutter/material.dart';

class IeltsResultHero extends StatefulWidget {
  const IeltsResultHero({
    super.key,
    required this.accent,
    required this.band,
    required this.summary,
    this.eyebrow = 'IELTS AI MASTER REPORT',
    this.title = 'Estimated Band',
    this.meta = const [],
    this.aiEstimated = false,
  });

  final Color accent;
  final double band;
  final String eyebrow;
  final String title;
  final String summary;
  final List<IeltsResultMetric> meta;
  final bool aiEstimated;

  @override
  State<IeltsResultHero> createState() => _IeltsResultHeroState();
}

class _IeltsResultHeroState extends State<IeltsResultHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _band;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _band = Tween<double>(
      begin: 0,
      end: widget.band,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant IeltsResultHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.band != widget.band) {
      _band = Tween<double>(begin: _band.value, end: widget.band).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.accent.withValues(alpha: .20),
            const Color(0xFF10243A),
            const Color(0xFF171A3A),
          ],
        ),
        border: Border.all(color: widget.accent.withValues(alpha: .30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .26),
            blurRadius: 34,
            offset: const Offset(0, 17),
          ),
          BoxShadow(
            color: widget.accent.withValues(alpha: .08),
            blurRadius: 34,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.eyebrow,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          AnimatedBuilder(
            animation: _band,
            builder: (context, _) => Text(
              _band.value.toStringAsFixed(1),
              semanticsLabel:
                  '${widget.title} ${widget.band.toStringAsFixed(1)}',
              style: TextStyle(
                color: widget.accent,
                fontSize: 52,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
              ),
            ),
          ),
          if (widget.aiEstimated) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: const Text(
                'AI estimate · not an official IELTS examiner score',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (widget.meta.isNotEmpty) ...[
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final width =
                    (constraints.maxWidth - 10 * (widget.meta.length - 1)) /
                    widget.meta.length;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.meta
                      .map(
                        (item) => SizedBox(
                          width: width,
                          child: _HeroMetric(metric: item),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
          if (widget.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              widget.summary,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class IeltsResultMetric {
  const IeltsResultMetric({
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.metric});

  final IeltsResultMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF07111F).withValues(alpha: .48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (metric.icon != null) ...[
                Icon(metric.icon, color: const Color(0xFF94A3B8), size: 15),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  metric.value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class IeltsCriterionCard extends StatelessWidget {
  const IeltsCriterionCard({
    super.key,
    required this.title,
    required this.band,
    required this.feedback,
    required this.accent,
  });

  final String title;
  final double band;
  final String feedback;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 174),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2E).withValues(alpha: .94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                band.toStringAsFixed(1),
                style: TextStyle(
                  color: accent,
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 720),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: (band / 9).clamp(0, 1)),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              borderRadius: BorderRadius.circular(20),
              color: accent,
              backgroundColor: Colors.white.withValues(alpha: .07),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            feedback,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class IeltsResultProgressRow extends StatelessWidget {
  const IeltsResultProgressRow({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    this.detail,
  });

  final String label;
  final int value;
  final Color accent;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2E).withValues(alpha: .92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$value%',
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 680),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: (value / 100).clamp(0, 1)),
            builder: (context, progress, _) => LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(20),
              color: accent,
              backgroundColor: Colors.white.withValues(alpha: .07),
            ),
          ),
        ],
      ),
    );
  }
}

enum IeltsInsightTone { strength, improvement, recommendation }

class IeltsInsightCard extends StatelessWidget {
  const IeltsInsightCard({
    super.key,
    required this.title,
    required this.items,
    required this.tone,
    this.emptyMessage,
  });

  final String title;
  final List<String> items;
  final IeltsInsightTone tone;
  final String? emptyMessage;

  Color get _accent => switch (tone) {
    IeltsInsightTone.strength => const Color(0xFF34D399),
    IeltsInsightTone.improvement => const Color(0xFFF59E0B),
    IeltsInsightTone.recommendation => const Color(0xFF22D3EE),
  };

  IconData get _icon => switch (tone) {
    IeltsInsightTone.strength => Icons.verified_rounded,
    IeltsInsightTone.improvement => Icons.trending_up_rounded,
    IeltsInsightTone.recommendation => Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.isEmpty
        ? [emptyMessage ?? 'No major issue was identified here.']
        : items;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, color: _accent, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...visibleItems
              .take(5)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 7),
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12.5,
                            height: 1.45,
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

class IeltsResultSectionTitle extends StatelessWidget {
  const IeltsResultSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class IeltsCorrectionTile extends StatelessWidget {
  const IeltsCorrectionTile({
    super.key,
    required this.original,
    required this.improved,
    required this.reason,
    required this.accent,
  });

  final String original;
  final String improved;
  final String reason;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2E).withValues(alpha: .92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORIGINAL',
            style: TextStyle(
              color: Color(0xFFFB7185),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            original,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Icon(Icons.arrow_downward_rounded, color: Color(0xFF64748B)),
          ),
          Text(
            'IMPROVED',
            style: TextStyle(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            improved,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (reason.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              reason,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class IeltsResultActions extends StatelessWidget {
  const IeltsResultActions({
    super.key,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondary,
    required this.accent,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback onSecondary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 410;
        final primary = FilledButton.icon(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(backgroundColor: accent),
          icon: Icon(primaryIcon),
          label: Text(primaryLabel),
        );
        final secondary = OutlinedButton.icon(
          onPressed: onSecondary,
          icon: Icon(secondaryIcon),
          label: Text(secondaryLabel),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, const SizedBox(height: 10), secondary],
          );
        }
        return Row(
          children: [
            Expanded(child: primary),
            const SizedBox(width: 10),
            Expanded(child: secondary),
          ],
        );
      },
    );
  }
}

class IeltsAiAnalysisLoader extends StatefulWidget {
  const IeltsAiAnalysisLoader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<String> steps;
  final Color accent;
  final IconData icon;

  @override
  State<IeltsAiAnalysisLoader> createState() => _IeltsAiAnalysisLoaderState();
}

class _IeltsAiAnalysisLoaderState extends State<IeltsAiAnalysisLoader> {
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _advance();
  }

  Future<void> _advance() async {
    while (mounted && _active < widget.steps.length - 1) {
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (mounted) setState(() => _active++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF101C2E),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: widget.accent.withValues(alpha: .24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: widget.accent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(widget.steps.length, (index) {
                final complete = index < _active;
                final active = index == _active;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? widget.accent.withValues(alpha: .09)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        complete
                            ? Icons.check_circle_rounded
                            : active
                            ? widget.icon
                            : Icons.radio_button_unchecked_rounded,
                        color: complete || active
                            ? widget.accent
                            : const Color(0xFF64748B),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.steps[index],
                          style: TextStyle(
                            color: complete || active
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF64748B),
                            fontSize: 12.5,
                            fontWeight: active
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
