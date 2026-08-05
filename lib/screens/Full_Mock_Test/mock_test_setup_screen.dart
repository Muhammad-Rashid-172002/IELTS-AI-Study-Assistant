import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/data/mock_test_repository.dart';
import 'package:fyproject/models/mock_test_models.dart';

import '../content_queue_service.dart';

import 'mock_shared_ui.dart';
import 'mock_test_runner_screen.dart';

class MockTestSetupScreen extends StatefulWidget {
  const MockTestSetupScreen({super.key});

  @override
  State<MockTestSetupScreen> createState() => _MockTestSetupScreenState();
}

class _MockTestSetupScreenState extends State<MockTestSetupScreen> {
  final _repository = MockTestRepository();

  String? _selectedMockId;
  List<PublishedMockTest> _publishedTests = const [];
  MockTrack _track = MockTrack.academic;
  MockScope _scope = MockScope.fullMock;
  MockMode _mode = MockMode.computerDelivered;
  MockSkill _singleSkill = MockSkill.listening;
  String _difficulty = 'Intermediate';
  double _targetBand = 7;
  DateTime _testDate = DateTime.now();
  bool _loading = false;
  bool _loadingHistory = true;
  Set<String> _completedMockIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadCompletedMocks();
  }

  Future<void> _loadCompletedMocks() async {
    final completed = await ContentQueueService().completedIds('mock_test');
    if (!mounted) return;
    setState(() {
      _completedMockIds = completed;
      _loadingHistory = false;
    });
  }

  Future<void> _startMock() async {
    if (_loading) return;

    PublishedMockTest? selected;
    for (final test in _publishedTests) {
      if (test.id == _selectedMockId) {
        selected = test;
        break;
      }
    }

    final config = MockTestConfig(
      mockTestId: selected?.id ?? '',
      mockTitle: selected?.title ?? '',
      track: _track,
      scope: _scope,
      mode: _mode,
      singleSkill: _scope == MockScope.singleSkill ? _singleSkill : null,
      difficulty: _difficulty,
      testDate: _testDate,
      targetBand: _targetBand,
    );

    setState(() => _loading = true);

    try {
      final attemptId = await _repository.createAttempt(config);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MockTestRunnerScreen(attemptId: attemptId, config: config),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start the mock test: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PublishedMockTest> _uniquePublishedTests(List<PublishedMockTest> tests) {
    final unique = <String, PublishedMockTest>{};

    for (final test in tests) {
      if (test.id.trim().isEmpty) continue;
      unique[test.id] = test;
    }

    return unique.values.toList(growable: false);
  }

  void _applyPublishedMock(PublishedMockTest test, {bool rebuild = true}) {
    void apply() {
      _selectedMockId = test.id;
      _track = test.track;
      _scope = test.scope;
      _mode = test.mode;
      _difficulty = test.difficulty;

      if (test.skills.length == 1) {
        _singleSkill = test.skills.first;
      }
    }

    if (rebuild) {
      setState(apply);
    } else {
      apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MockColors.background,
      appBar: AppBar(
        backgroundColor: MockColors.background,
        foregroundColor: MockColors.text,
        surfaceTintColor: Colors.transparent,
        title: const Text('Full Mock Test'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: MockBackground()),
          SafeArea(
            top: false,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
              children: [
                _hero(),
                const SizedBox(height: 18),
                StreamBuilder<List<PublishedMockTest>>(
                  stream: _repository.watchPublishedMockTests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _PublishedMockStatus(
                        icon: Icons.sync_rounded,
                        message: 'Loading published mock tests...',
                        showProgress: true,
                      );
                    }

                    if (snapshot.hasError) {
                      return _PublishedMockStatus(
                        icon: Icons.error_outline_rounded,
                        message:
                            'Published mock tests could not be loaded. ${snapshot.error}',
                      );
                    }

                    final rawTests =
                        snapshot.data ?? const <PublishedMockTest>[];
                    if (_loadingHistory) {
                      return const _PublishedMockStatus(
                        icon: Icons.history_rounded,
                        message: 'Checking your completed mock tests...',
                        showProgress: true,
                      );
                    }
                    final tests = _uniquePublishedTests(rawTests)
                        .where((test) => !_completedMockIds.contains(test.id))
                        .toList(growable: false);
                    _publishedTests = tests;

                    if (tests.isEmpty) {
                      _selectedMockId = null;
                      return const _PublishedMockStatus(
                        icon: Icons.info_outline_rounded,
                        message:
                            'No new mock test is available. Completed mocks are hidden and the next mock will appear when the administrator publishes it.',
                      );
                    }

                    final selectedId =
                        tests.any((test) => test.id == _selectedMockId)
                        ? _selectedMockId!
                        : tests.first.id;

                    if (_selectedMockId != selectedId) {
                      _selectedMockId = selectedId;
                      _applyPublishedMock(tests.first, rebuild: false);
                    }

                    return DropdownButtonFormField<String>(
                      key: ValueKey(selectedId),
                      initialValue: selectedId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Published Mock Test',
                        prefixIcon: Icon(Icons.fact_check_outlined),
                      ),
                      items: tests.map((test) {
                        return DropdownMenuItem<String>(
                          value: test.id,
                          child: Text(
                            '${test.title} • ${test.track.label} • ${test.difficulty}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _loading
                          ? null
                          : (id) {
                              if (id == null) return;

                              PublishedMockTest? selectedTest;
                              for (final test in tests) {
                                if (test.id == id) {
                                  selectedTest = test;
                                  break;
                                }
                              }

                              if (selectedTest == null) return;
                              _applyPublishedMock(selectedTest);
                            },
                    );
                  },
                ),
                const SizedBox(height: 18),
                const _SectionTitle(
                  title: 'Choose IELTS Type',
                  subtitle: 'Select the test version you want to simulate.',
                ),
                const SizedBox(height: 10),
                _ResponsiveOptionRow(
                  children: [
                    _OptionCard(
                      selected: _track == MockTrack.academic,
                      icon: Icons.school_outlined,
                      title: 'Academic',
                      subtitle: 'University and professional study',
                      onTap: () => setState(() => _track = MockTrack.academic),
                    ),
                    _OptionCard(
                      selected: _track == MockTrack.generalTraining,
                      icon: Icons.work_outline_rounded,
                      title: 'General Training',
                      subtitle: 'Migration, work and daily life',
                      onTap: () =>
                          setState(() => _track = MockTrack.generalTraining),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionTitle(
                  title: 'Mock Scope',
                  subtitle: 'Take all four skills or focus on one module.',
                ),
                const SizedBox(height: 10),
                _ResponsiveOptionRow(
                  children: [
                    _OptionCard(
                      selected: _scope == MockScope.fullMock,
                      icon: Icons.dashboard_customize_outlined,
                      title: 'Full Mock',
                      subtitle: 'Listening, Reading, Writing, Speaking',
                      onTap: () => setState(() => _scope = MockScope.fullMock),
                    ),
                    _OptionCard(
                      selected: _scope == MockScope.singleSkill,
                      icon: Icons.center_focus_strong_outlined,
                      title: 'Single Skill',
                      subtitle: 'Practise one IELTS module',
                      onTap: () =>
                          setState(() => _scope = MockScope.singleSkill),
                    ),
                  ],
                ),
                if (_scope == MockScope.singleSkill) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MockSkill.values.map((skill) {
                      return ChoiceChip(
                        selected: _singleSkill == skill,
                        label: Text(skill.label),
                        onSelected: (_) {
                          setState(() => _singleSkill = skill);
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 18),
                const _SectionTitle(
                  title: 'Test Mode',
                  subtitle:
                      'Choose how closely the mock follows exam conditions.',
                ),
                const SizedBox(height: 10),
                ...MockMode.values.map((mode) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _ModeTile(
                      mode: mode,
                      selected: _mode == mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                  );
                }),
                const SizedBox(height: 18),
                const _SectionTitle(
                  title: 'Difficulty and Goal',
                  subtitle: 'Set the challenge level and your target band.',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey(_difficulty),
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items:
                      const [
                            'Foundation',
                            'Intermediate',
                            'Upper Intermediate',
                            'Advanced',
                            'Expert',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _difficulty = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: panelDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Band ${_targetBand.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: MockColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Slider(
                        value: _targetBand,
                        min: 4,
                        max: 9,
                        divisions: 10,
                        label: _targetBand.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() => _targetBand = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _datePicker(),
                const SizedBox(height: 18),
                _structurePreview(),
                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _startMock,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _loading ? 'Preparing Mock...' : 'Start Mock Test',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: heroDecoration(),
      child: const Row(
        children: [
          GradientIcon(icon: Icons.fact_check_outlined),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IELTS Mock Simulator',
                  style: TextStyle(
                    color: MockColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Persistent timer, autosave, question palette, recovery and full exam result.',
                  style: TextStyle(
                    color: MockColors.secondary,
                    fontSize: 10.5,
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

  Widget _datePicker() {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: _testDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );

        if (!mounted || selected == null) return;
        setState(() => _testDate = selected);
      },
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: panelDecoration(),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: MockColors.cyan),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Date',
                    style: TextStyle(color: MockColors.muted, fontSize: 9.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_testDate.day}/${_testDate.month}/${_testDate.year}',
                    style: const TextStyle(
                      color: MockColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: MockColors.muted,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  Widget _structurePreview() {
    final skills = _scope == MockScope.fullMock
        ? MockSkill.values
        : [_singleSkill];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mock Structure',
            style: TextStyle(
              color: MockColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...skills.map((skill) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(skillIcon(skill), color: MockColors.cyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      skill.label,
                      style: const TextStyle(
                        color: MockColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${skill.questionCount} ${skill == MockSkill.writing
                          ? 'tasks'
                          : skill == MockSkill.speaking
                          ? 'parts'
                          : 'questions'} • ${skill.durationMinutes} min',
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MockColors.muted,
                        fontSize: 9.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PublishedMockStatus extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool showProgress;

  const _PublishedMockStatus({
    required this.icon,
    required this.message,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: panelDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showProgress)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, color: MockColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: MockColors.secondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveOptionRow extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveOptionRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalLayout = constraints.maxWidth < 360;

        if (useVerticalLayout) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                SizedBox(width: double.infinity, child: children[index]),
                if (index != children.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return SizedBox(
          height: 136,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                Expanded(child: children[index]),
                if (index != children.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ModeTile extends StatelessWidget {
  final MockMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (mode) {
      MockMode.practice => 'Hints, flexible navigation and learning support',
      MockMode.exam => 'Strict timer, no hints and automatic submission',
      MockMode.computerDelivered =>
        'Full-screen computer-delivered exam simulation',
    };

    final icon = switch (mode) {
      MockMode.practice => Icons.lightbulb_outline_rounded,
      MockMode.exam => Icons.lock_clock_outlined,
      MockMode.computerDelivered => Icons.desktop_windows_outlined,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? MockColors.primary.withValues(alpha: .15)
              : MockColors.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? MockColors.primary : MockColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? MockColors.cyan : MockColors.muted),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: const TextStyle(
                      color: MockColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MockColors.muted,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: MockColors.cyan),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? MockColors.primary.withValues(alpha: .15)
              : MockColors.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? MockColors.primary : MockColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? MockColors.cyan : MockColors.muted),
            const SizedBox(height: 24),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MockColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MockColors.muted,
                fontSize: 9.2,
                height: 1.3,
              ),
            ),
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
            color: MockColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: MockColors.muted, fontSize: 10),
        ),
      ],
    );
  }
}
