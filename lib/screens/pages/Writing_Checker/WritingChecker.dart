import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fyproject/services/ai_service.dart';

class WritingChecker extends StatefulWidget {
  const WritingChecker({super.key});

  @override
  State<WritingChecker> createState() => _WritingCheckerState();
}

class _WritingCheckerState extends State<WritingChecker> {
  final TextEditingController essayController = TextEditingController();
  final AIService ai = AIService();

  String topic = "";
  String bandScore = "";
  String taskAchievement = "";
  String coherence = "";
  String lexical = "";
  String grammar = "";
  String improvement = "";
  String improvedVersion = "";

  bool isTopicLoading = false;
  bool isChecking = false;

  int wordCount = 0;
  int totalSeconds = 2400;
  Timer? timer;
  String selectedTask = "2";

  int get minWords => selectedTask == "1" ? 150 : 250;

  int get examTime => selectedTask == "1" ? 1200 : 2400;

  File? chartImage;
  bool isAnalyzingChart = false;

  String mainTrends = "";
  String highestValue = "";
  String lowestValue = "";
  String overview = "";
  String band9Sample = "";

  Color get primary => const Color(0xFF14B8A6);
  Color get secondary => const Color(0xFF0F766E);
  Color get bg => const Color(0xFF08111F);

  String get timeFormatted {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();

    essayController.addListener(() {
      final text = essayController.text.trim();
      final words = text.isEmpty ? [] : text.split(RegExp(r'\s+'));

      setState(() {
        wordCount = words.length;
      });
    });

    loadTopic();
    startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    essayController.dispose();
    super.dispose();
  }

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (totalSeconds > 0) {
        setState(() => totalSeconds--);
      } else {
        timer?.cancel();
      }
    });
  }

  Future<void> loadTopic() async {
    setState(() => isTopicLoading = true);

    try {
      final result = await ai.generateWritingTopic(selectedTask);

      setState(() {
        topic = result;
      });
    } catch (e) {
      _showInternetDialog(
        title: "Topic Loading Failed",
        message:
            "Your internet connection is not working properly, or the AI service is unavailable. Please check your network and try again.",
        retry: loadTopic,
      );
    } finally {
      if (mounted) setState(() => isTopicLoading = false);
    }
  }

  Future<void> checkEssay() async {
    final essay = essayController.text.trim();

    if (essay.isEmpty) {
      _showSnack("Please write your essay first.");
      return;
    }

    if (wordCount < minWords) {
      _showSnack("IELTS Task $selectedTask requires at least $minWords words.");
      return;
    }

    setState(() => isChecking = true);
    timer?.cancel();

    try {
      final result = await ai.evaluateWriting(
        text: essay,
        taskType: selectedTask,
      );

      setState(() {
        bandScore = result["overall_band"]?.toString() ?? "0";

        taskAchievement = selectedTask == "1"
            ? (result["task_achievement"]?["feedback"]?.toString() ?? "")
            : (result["task_response"]?["feedback"]?.toString() ?? "");

        coherence = result["coherence_cohesion"]?["feedback"]?.toString() ?? "";

        lexical = result["lexical_resource"]?["feedback"]?.toString() ?? "";

        grammar = result["grammar"]?["feedback"]?.toString() ?? "";

        improvement = result["examiner_advice"]?.toString() ?? "";

        improvedVersion = result["improved_version"]?.toString() ?? "";
      });

      await saveToFirebase();
      _showSnack("Essay checked successfully.");
    } catch (e) {
      _showInternetDialog(
        title: "Checking Failed",
        message:
            "Your internet connection is not working properly, or the AI examiner could not check your essay. Please try again.",
        retry: checkEssay,
      );
    } finally {
      if (mounted) setState(() => isChecking = false);
    }
  }

  Future<void> saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("writing_results")
        .add({
          "topic": topic,
          "essay": essayController.text.trim(),
          "band": bandScore,
          "task_achievement": taskAchievement,
          "coherence": coherence,
          "lexical": lexical,
          "grammar": grammar,
          "improvement": improvement,
          "improved_version": improvedVersion,
          "word_count": wordCount,
          "createdAt": FieldValue.serverTimestamp(),
        });
  }

  void _showInternetDialog({
    required String title,
    required String message,
    required VoidCallback retry,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),

      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),

          child: Container(
            padding: const EdgeInsets.all(28),

            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

              borderRadius: BorderRadius.circular(34),

              border: Border.all(color: Colors.white.withOpacity(0.10)),

              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.20),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),

                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// ICON
                Container(
                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),

                    shape: BoxShape.circle,

                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),

                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),

                const SizedBox(height: 24),

                /// TITLE
                Text(
                  title,
                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),

                const SizedBox(height: 12),

                /// MESSAGE
                Text(
                  message,
                  textAlign: TextAlign.center,

                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 30),

                /// BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,

                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),

                          borderRadius: BorderRadius.circular(18),

                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),

                        child: Material(
                          color: Colors.transparent,

                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),

                            onTap: () {
                              Navigator.pop(context);
                            },

                            child: const Center(
                              child: Text(
                                "Close",

                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Container(
                        height: 56,

                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primary, secondary],
                          ),

                          borderRadius: BorderRadius.circular(18),

                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.30),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),

                        child: Material(
                          color: Colors.transparent,

                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),

                            onTap: () {
                              Navigator.pop(context);
                              retry();
                            },

                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),

                                  SizedBox(width: 8),

                                  Text(
                                    "Retry",

                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      body: Stack(
        children: [
          Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _taskButton(
                              title: "Task 1",
                              subtitle: "150 words",
                              selected: selectedTask == "1",
                              onTap: () {
                                setState(() {
                                  selectedTask = "1";
                                  totalSeconds = 1200;
                                });

                                loadTopic();
                              },
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: _taskButton(
                              title: "Task 2",
                              subtitle: "250 words",
                              selected: selectedTask == "2",
                              onTap: () {
                                setState(() {
                                  selectedTask = "2";
                                  totalSeconds = 2400;
                                });

                                loadTopic();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _topicCard(),
                      const SizedBox(height: 16),
                      _essayCard(),
                      const SizedBox(height: 16),
                      _gradientButton(
                        text: isChecking ? "Checking Essay..." : "Submit Essay",
                        icon: Icons.auto_awesome_rounded,
                        loading: isChecking,
                        onTap: isChecking ? null : checkEssay,
                      ),
                      if (bandScore.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _resultSection(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isChecking) _loadingOverlay(),
        ],
      ),
    );
  }

  Widget _taskButton({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [primary, secondary])
              : null,
          color: selected ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withOpacity(0.10),
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 52, 18, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF08111F), Color(0xFF102A43), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleButton(
                icon: Icons.arrow_back_ios_new,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "IELTS Writing",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "AI examiner essay evaluation",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _circleButton(icon: Icons.edit_note_rounded, onTap: () {}),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  title: "Time Left",
                  value: timeFormatted,
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  title: "Words",
                  value: "$wordCount / $minWords",
                  icon: Icons.description_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topicCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Writing Task $selectedTask Prompt",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "AI generated IELTS writing question",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.62),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withOpacity(0.12),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primary.withOpacity(0.20)),
            ),
            child: isTopicLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : _buildFormattedPrompt(topic),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _smallButton(
                  icon: Icons.refresh_rounded,
                  text: "New Topic",
                  onTap: isTopicLoading ? null : loadTopic,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _smallButton(
                  icon: Icons.rule_rounded,
                  text: "Min $minWords words",
                  onTap: null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedPrompt(String text) {
    final lines = text.split('\n');

    final normalLines = <String>[];
    final tableLines = <String>[];

    for (final line in lines) {
      if (line.trim().startsWith('|')) {
        tableLines.add(line.replaceAll("**", "").replaceAll("#", "").trim());
      } else {
        normalLines.add(line);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// NORMAL IELTS TEXT
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),

          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),

            borderRadius: BorderRadius.circular(22),

            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),

          child: _boldText(normalLines.join('\n').trim()),
        ),

        /// IELTS TASK 1 TABLE
        if (tableLines.length >= 2) ...[
          const SizedBox(height: 22),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),

                  borderRadius: BorderRadius.circular(14),
                ),

                child: const Icon(
                  Icons.table_chart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              const Text(
                "Visual Data Table",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _markdownTable(tableLines),
        ],
      ],
    );
  }

  Widget _boldText(String text) {
    final spans = <TextSpan>[];

    text = text
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll(RegExp(r'^\s*[-•]\s*', multiLine: true), '• ');

    final regex = RegExp(r'\*\*(.*?)\*\*');

    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: TextStyle(
              color: Colors.white.withOpacity(0.84),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(color: primary, fontWeight: FontWeight.w900),
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: TextStyle(
            color: Colors.white.withOpacity(0.86),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return RichText(
      softWrap: true,
      overflow: TextOverflow.visible,
      text: TextSpan(
        children: spans,
        style: TextStyle(
          fontSize: 16,
          height: 1.75,
          color: Colors.white.withOpacity(0.86),
        ),
      ),
    );
  }

  Widget _markdownTable(List<String> lines) {
    final rows = lines
        .where((line) => !line.contains('---'))
        .map((line) {
          return line
              .split('|')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        })
        .where((row) => row.isNotEmpty)
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Table(
        border: TableBorder.all(color: Colors.white.withOpacity(0.12)),
        columnWidths: const {
          0: FlexColumnWidth(1.4),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
          3: FlexColumnWidth(),
        },
        children: List.generate(rows.length, (index) {
          final isHeader = index == 0;

          return TableRow(
            decoration: BoxDecoration(
              color: isHeader
                  ? primary.withOpacity(0.22)
                  : Colors.white.withOpacity(0.06),
            ),
            children: rows[index].map((cell) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Text(
                  cell,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isHeader ? FontWeight.w900 : FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ),
    );
  }

  Widget _essayCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TOP TITLE
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),

                  borderRadius: BorderRadius.circular(16),

                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Essay",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),

                    SizedBox(height: 4),

                    Text(
                      "Write a professional IELTS response",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          /// WRITING AREA
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

              borderRadius: BorderRadius.circular(28),

              border: Border.all(color: primary.withOpacity(0.18)),

              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),

            child: TextField(
              controller: essayController,

              maxLines: 18,

              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),

              cursorColor: primary,

              decoration: InputDecoration(
                hintText:
                    "Introduction\nBody Paragraph 1\nBody Paragraph 2\nConclusion",

                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  height: 1.8,
                  fontSize: 15,
                ),

                filled: true,
                fillColor: Colors.transparent,

                contentPadding: const EdgeInsets.all(24),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          /// STATS
          Row(
            children: [
              Expanded(
                child: _writingStat(
                  icon: Icons.description_outlined,
                  title: "Words",
                  value: "$wordCount",
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _writingStat(
                  icon: Icons.rule_rounded,
                  title: "Minimum",
                  value: "$minWords",
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          /// PROGRESS
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: (wordCount / minWords).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(
                wordCount >= minWords ? const Color(0xFF22C55E) : primary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                wordCount >= minWords
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,

                color: wordCount >= minWords
                    ? const Color(0xFF22C55E)
                    : Colors.white54,

                size: 18,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  wordCount >= minWords
                      ? "Excellent. Minimum word count achieved."
                      : "${minWords - wordCount} more words needed.",

                  style: TextStyle(
                    color: wordCount >= minWords
                        ? const Color(0xFF86EFAC)
                        : Colors.white70,

                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// WRITING TIPS
          Container(
            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withOpacity(0.16),
                  secondary.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

              borderRadius: BorderRadius.circular(24),

              border: Border.all(color: primary.withOpacity(0.22), width: 1.2),

              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.14),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),

                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),

                    shape: BoxShape.circle,

                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.30),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),

                  child: const Icon(
                    Icons.lightbulb_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "IELTS Writing Tip",
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Use clear paragraphs, formal vocabulary and strong grammar to achieve a higher IELTS band score.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.84),
                          height: 1.7,
                          fontWeight: FontWeight.w500,
                          fontSize: 14.5,
                        ),
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

  Widget _writingStat({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, secondary]),

              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(icon, color: Colors.white, size: 18),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultSection() {
    return Column(
      children: [
        _bandCard(),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _writingStat(
                icon: Icons.description_outlined,
                title: "Words",
                value: "$wordCount",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _writingStat(
                icon: Icons.assignment_outlined,
                title: "Task",
                value: "Task $selectedTask",
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        _detailCard(
          selectedTask == "1" ? "Task Achievement" : "Task Response",
          taskAchievement,
        ),
        _detailCard("Coherence & Cohesion", coherence),
        _detailCard("Lexical Resource", lexical),
        _detailCard("Grammar Range & Accuracy", grammar),
        _detailCard("Examiner Advice", improvement),

        if (improvedVersion.isNotEmpty)
          _detailCard("Improved Version", improvedVersion),
      ],
    );
  }

  Widget _bandCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff111827), Color(0xff1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Text(
            "Estimated IELTS Band",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            bandScore,
            style: const TextStyle(
              color: Color(0xFF86EFAC),
              fontSize: 56,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text("$wordCount words", style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _detailCard(String title, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(30),

        border: Border.all(color: primary.withOpacity(0.14), width: 1.2),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.18),
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
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),

                  borderRadius: BorderRadius.circular(16),

                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),

              borderRadius: BorderRadius.circular(22),

              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),

            child: Text(
              value,
              style: TextStyle(
                height: 1.75,
                fontSize: 14.8,
                color: Colors.white.withOpacity(0.84),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(34),

        border: Border.all(color: primary.withOpacity(0.12), width: 1.2),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),

      child: child,
    );
  }

  Widget _smallButton({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),

      decoration: BoxDecoration(
        gradient: isDisabled
            ? LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.03),
                ],
              )
            : LinearGradient(
                colors: [
                  primary.withOpacity(0.22),
                  secondary.withOpacity(0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

        borderRadius: BorderRadius.circular(22),

        border: Border.all(
          color: isDisabled
              ? Colors.white.withOpacity(0.06)
              : primary.withOpacity(0.22),
          width: 1.1,
        ),

        boxShadow: [
          BoxShadow(
            color: isDisabled
                ? Colors.black.withOpacity(0.10)
                : primary.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,

          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,

              children: [
                Container(
                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(
                    color: isDisabled
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.12),

                    shape: BoxShape.circle,
                  ),

                  child: Icon(
                    icon,
                    size: 18,
                    color: isDisabled ? Colors.white24 : Colors.white,
                  ),
                ),

                const SizedBox(width: 10),

                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      letterSpacing: 0.2,

                      color: isDisabled ? Colors.white38 : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradientButton({
    required String text,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    final isDisabled = onTap == null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),

        gradient: LinearGradient(
          colors: isDisabled
              ? [Colors.grey.shade700, Colors.grey.shade600]
              : [primary, secondary, const Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        boxShadow: [
          BoxShadow(
            color: isDisabled
                ? Colors.black.withOpacity(0.12)
                : primary.withOpacity(0.35),

            blurRadius: 28,
            offset: const Offset(0, 14),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: loading ? null : onTap,

          child: Container(
            width: double.infinity,

            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),

            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),

                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),

                          child: Icon(icon, color: Colors.white, size: 20),
                        ),

                        const SizedBox(width: 14),

                        Flexible(
                          child: Text(
                            text,
                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.55),

      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(26),

          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF111827), const Color(0xFF1F2937)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

            borderRadius: BorderRadius.circular(32),

            border: Border.all(color: primary.withOpacity(0.18), width: 1.2),

            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.22),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),

              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 88,
                width: 88,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  gradient: LinearGradient(colors: [primary, secondary]),

                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),

                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 68,
                      width: 68,

                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        backgroundColor: Colors.white.withOpacity(0.12),
                      ),
                    ),

                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "AI Examiner is Evaluating",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Checking grammar, vocabulary, coherence, task response and IELTS band score...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 14,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 22),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _loadingChip("Grammar"),
                  _loadingChip("Vocabulary"),
                  _loadingChip("Band Score"),
                  _loadingChip("Feedback"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
        ),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: primary.withOpacity(0.18)),
      ),

      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.84),
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(18),

        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF111827), const Color(0xFF1F2937)],
            ),

            borderRadius: BorderRadius.circular(22),

            border: Border.all(color: primary.withOpacity(0.25)),

            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),

          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),

                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        duration: const Duration(seconds: 3),
      ),
    );
  }
}
