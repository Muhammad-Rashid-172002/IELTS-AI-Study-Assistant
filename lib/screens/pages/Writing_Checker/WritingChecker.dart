import 'dart:async';
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: primary),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              retry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
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
          _cardTitle(
            Icons.lightbulb_outline,
            "Writing Task $selectedTask Prompt",
          ),
          const SizedBox(height: 18),

          if (isTopicLoading)
            Center(child: CircularProgressIndicator(color: primary))
          else
            _buildFormattedPrompt(topic),

          const SizedBox(height: 16),

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
        tableLines.add(line.trim());
      } else {
        normalLines.add(line);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _boldText(normalLines.join('\n').trim()),

        if (tableLines.length >= 2) ...[
          const SizedBox(height: 18),
          _markdownTable(tableLines),
        ],
      ],
    );
  }

  Widget _boldText(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');

    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontWeight: FontWeight.w600,
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
          style: const TextStyle(
            color: Color(0xff111827),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return RichText(
      softWrap: true,
      overflow: TextOverflow.visible,
      text: TextSpan(
        children: spans,
        style: const TextStyle(
          fontSize: 16,
          height: 1.7,
          color: Color(0xff111827),
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
          _cardTitle(Icons.article_outlined, "Your Essay"),
          const SizedBox(height: 12),
          TextField(
            controller: essayController,
            maxLines: 15,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText:
                  "Write your IELTS Task 2 essay here...\n\nIntroduction\nBody paragraph 1\nBody paragraph 2\nConclusion",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.40)),
              fillColor: Colors.white.withOpacity(0.08),
              filled: true,

              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xffE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: primary, width: 1.4),
              ),
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
            cursorColor: primary,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (wordCount / minWords).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.grey.shade200,
            color: wordCount >= minWords ? Colors.green : primary,
          ),
          const SizedBox(height: 8),
          Text(
            wordCount >= minWords
                ? "Good. You reached the minimum word count."
                : "${minWords - wordCount} more words needed.",
            style: TextStyle(
              color: wordCount >= minWords ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w600,
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
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.check_circle_outline, title),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              height: 1.55,
              color: Colors.white.withOpacity(0.78),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primary, secondary]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallButton({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xffF3F4F6)
              : primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap == null
                ? const Color(0xffE5E7EB)
                : primary.withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: onTap == null ? Colors.grey : primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: onTap == null ? Colors.grey : primary,
                ),
              ),
            ),
          ],
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
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onTap == null
                ? [Colors.grey, Colors.grey.shade500]
                : [primary, secondary],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _loadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.35),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(22),
          margin: const EdgeInsets.symmetric(horizontal: 34),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircularProgressIndicator(color: primary),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "AI examiner is checking your essay...",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
