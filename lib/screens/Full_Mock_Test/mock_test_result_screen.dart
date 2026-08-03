import 'package:flutter/material.dart';
import 'package:fyproject/data/mock_test_repository.dart';
import 'package:fyproject/models/mock_test_models.dart';


import 'mock_shared_ui.dart';

class MockTestResultScreen extends StatefulWidget {
  final String attemptId;

  const MockTestResultScreen({
    super.key,
    required this.attemptId,
  });

  @override
  State<MockTestResultScreen> createState() =>
      _MockTestResultScreenState();
}

class _MockTestResultScreenState
    extends State<MockTestResultScreen> {
  final _repository = MockTestRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MockColors.background,
      appBar: AppBar(
        backgroundColor: MockColors.background,
        automaticallyImplyLeading: false,
        title: const Text('Mock Test Result'),
      ),
      body: StreamBuilder(
        stream: _repository.watchAttempt(widget.attemptId),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();

          if (data == null ||
              data['result'] == null ||
              data['status'] == 'submitted') {
            return _EvaluationWaiting(
              attemptId: widget.attemptId,
            );
          }

          return FutureBuilder<MockFinalResult?>(
            future: _repository.loadFinalResult(
              widget.attemptId,
            ),
            builder: (context, resultSnapshot) {
              if (!resultSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final result = resultSnapshot.data;
              if (result == null) {
                return const Center(
                  child: StatePanel(
                    icon: Icons.pending_actions_outlined,
                    title: 'Result is being prepared',
                    subtitle:
                        'AI evaluation is still processing your mock test.',
                  ),
                );
              }

              return _ResultContent(result: result);
            },
          );
        },
      ),
    );
  }
}

class _EvaluationWaiting extends StatelessWidget {
  final String attemptId;

  const _EvaluationWaiting({
    required this.attemptId,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: MockBackground()),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            margin: const EdgeInsets.all(22),
            padding: const EdgeInsets.all(27),
            decoration: heroDecoration(),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 18),
                Text(
                  'Evaluating Your Mock Test',
                  style: TextStyle(
                    color: MockColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Raw scores, writing criteria, speaking criteria, strengths, weaknesses and your 7-day plan are being prepared.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MockColors.secondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultContent extends StatelessWidget {
  final MockFinalResult result;

  const _ResultContent({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: MockBackground()),
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
          children: [
            _resultHero(),
            const SizedBox(height: 14),
            _skillBands(),
            const SizedBox(height: 14),
            _strengthWeakness(),
            const SizedBox(height: 14),
            _targetGap(),
            const SizedBox(height: 14),
            _sevenDayPlan(),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.popUntil(
                  context,
                  (route) => route.isFirst,
                );
              },
              icon: const Icon(Icons.home_rounded),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: heroDecoration(),
      child: Column(
        children: [
          const Text(
            'Overall Estimated Band',
            style: TextStyle(
              color: MockColors.muted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            result.overallBand.toStringAsFixed(1),
            style: const TextStyle(
              color: MockColors.cyan,
              fontSize: 52,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Target ${result.targetBand.toStringAsFixed(1)} • '
            'Gap ${result.targetGap.toStringAsFixed(1)}',
            style: const TextStyle(
              color: MockColors.secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillBands() {
    return _ResultSection(
      title: 'Module Performance',
      icon: Icons.insights_rounded,
      child: Column(
        children: result.skillResults.map((skill) {
          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: MockColors.background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: MockColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  skillIcon(skill.skill),
                  color: MockColors.cyan,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.skill.label,
                        style: const TextStyle(
                          color: MockColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Raw ${skill.rawScore}/${skill.totalMarks} • '
                        '${skill.accuracy.toStringAsFixed(0)}% • '
                        '${_duration(skill.timeSpentSeconds)}',
                        style: const TextStyle(
                          color: MockColors.muted,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  skill.band.toStringAsFixed(1),
                  style: const TextStyle(
                    color: MockColors.cyan,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _strengthWeakness() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ResultSection(
            title: 'Strengths',
            icon: Icons.trending_up_rounded,
            child: _BulletList(
              items: result.strengths,
              color: MockColors.green,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ResultSection(
            title: 'Weaknesses',
            icon: Icons.warning_amber_rounded,
            child: _BulletList(
              items: result.weaknesses,
              color: MockColors.warning,
            ),
          ),
        ),
      ],
    );
  }

  Widget _targetGap() {
    return _ResultSection(
      title: 'Target Band Gap',
      icon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.targetGap <= 0
                ? 'Target achieved.'
                : 'You need approximately ${result.targetGap.toStringAsFixed(1)} more band points.',
            style: const TextStyle(
              color: MockColors.secondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Suggested next mock: '
            '${result.suggestedNextMockDate.day}/'
            '${result.suggestedNextMockDate.month}/'
            '${result.suggestedNextMockDate.year}',
            style: const TextStyle(
              color: MockColors.cyan,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sevenDayPlan() {
    return _ResultSection(
      title: 'Personalized 7-Day Plan',
      icon: Icons.calendar_view_week_outlined,
      child: Column(
        children: result.sevenDayPlan.map((day) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: MockColors.background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: MockColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day ${day['day'] ?? '-'} • ${day['skill'] ?? ''}',
                  style: const TextStyle(
                    color: MockColors.cyan,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  (day['task'] ?? '').toString(),
                  style: const TextStyle(
                    color: MockColors.secondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _duration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes}m ${remaining}s';
  }
}

class _ResultSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ResultSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MockColors.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: MockColors.text,
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

class _BulletList extends StatelessWidget {
  final List<String> items;
  final Color color;

  const _BulletList({
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'No data available.',
        style: TextStyle(color: MockColors.muted),
      );
    }

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.circle,
                color: color,
                size: 8,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    color: MockColors.secondary,
                    fontSize: 10,
                    height: 1.4,
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
