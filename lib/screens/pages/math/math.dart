

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../controller/firebase_services/firebase_services.dart';
import '../../../controller/math_controller/math_controller.dart';

class Math extends StatefulWidget {
  const Math({super.key});

  @override
  State<Math> createState() => _MathState();
}

class _MathState extends State<Math> {
  final TextEditingController _controller = TextEditingController();
  final controller = Get.put(MathController());

  // Insert correct operators for Gemini
  String _mapValue(String v) {
    if (v == "×") return "*";
    if (v == "÷") return "/";
    return v;
  }

  void _insertText(String value) {
    final insert = _mapValue(value);
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;

    if (cursor < 0) {
      _controller.text = text + insert;
      _controller.selection =
          TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    } else {
      final newText =
          text.substring(0, cursor) + insert + text.substring(cursor);
      _controller.text = newText;

      _controller.selection =
          TextSelection.fromPosition(TextPosition(offset: cursor + insert.length));
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _buildAppBar(),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _howItWorksCard(),
            const SizedBox(height: 18),

            _quickExamples(),
            const SizedBox(height: 18),

            _inputCard(),
            const SizedBox(height: 26),

            _solveButton(),
            const SizedBox(height: 26),

            Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8E44FF)),
                );
              }
              if (controller.result.value.isEmpty) return const SizedBox();

              return _mathResultCard(controller.result.value);
            }),
          ],
        ),
      ),
    );
  }

  // ------------------- APP BAR -------------------
  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,

      title: Row(
        children: [
          _roundButton(Icons.arrow_back, onTap: () => Get.back()),
          const SizedBox(width: 14),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8E44FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calculate_rounded,
              color: Color(0xFF8E44FF),
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Math Solver",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                "AI-Powered Calculator",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),

          const Spacer(),

          // ---------------- MORE MENU ----------------
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == "clear") {
                _controller.clear();
                controller.result.value = "";
                Get.snackbar("Cleared", "Math input cleared",
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                    duration: Duration(seconds: 1));
              }
              else if (value == "copy") {
                Clipboard.setData(ClipboardData(text: controller.result.value));
                Get.snackbar("Copied", "Solution copied",
                    backgroundColor: Colors.blue,
                    colorText: Colors.white,
                    duration: Duration(seconds: 1));
              }
              else if (value == "about") {
                Get.snackbar("About", "Math Solver by Rashid",
                    backgroundColor: Colors.purple,
                    colorText: Colors.white);
              }
            },

            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "clear",
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 10),
                    Text("Clear Input"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: "copy",
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 20),
                    SizedBox(width: 10),
                    Text("Copy Result"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: "about",
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 10),
                    Text("About"),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.black87),
          ),
        ],
      ),
    );
  }



  Widget _mathResultCard(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF8E44FF),
                  Color(0xFFB27CFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "AI Math Solution",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: text));
                    Get.snackbar(
                      "Copied",
                      "Solution copied",
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 1),
                    );
                  },
                  child: const Icon(Icons.copy, color: Colors.white),
                )
              ],
            ),
          ),

          // Result Content
          Container(
            padding: const EdgeInsets.all(18),
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 350),

            child: SingleChildScrollView(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- HOW IT WORKS ----------------------
  Widget _howItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8DBFF), Color(0xFFF3EDFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: Color(0xFF8E44FF), width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),

      child: const Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 22, color: Color(0xFF8E44FF)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Smart Math Assistant\nType any math problem. AI will solve it step-by-step.",
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- QUICK EXAMPLES ----------------------
  Widget _quickExamples() {
    final examples = ["50% of 240", "√144", "15 * 20²", "(24 + 36) ÷ 5", "2 + 2"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "QUICK EXAMPLES",
          style: TextStyle(fontSize: 13, color: Colors.black54, letterSpacing: 0.5),
        ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 10,
          children: examples.map((ex) {
            return Padding(
              padding: const EdgeInsets.all(2.0),
              child: GestureDetector(
                onTap: () {
                  _controller.text = ex;
                  setState(() {});
                },

                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),

                  child: Text(
                    ex,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ---------------------- INPUT CARD ----------------------
  Widget _inputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Clear
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Math Problem",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () => _controller.clear(),
                child: const Text(
                  "Clear",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E44FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),

          const SizedBox(height: 14),

          // Input Field
          Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),

            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "e.g., (24 + 36) ÷ 5",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.black38),
                    ),
                  ),
                ),
                const Icon(Icons.mic_none, color: Colors.black54),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _keypad(),
        ],
      ),
    );
  }

  // ---------------------- KEYPAD ----------------------
  Widget _keypad() {
    final buttons = [
      ["7", "8", "9", "÷"],
      ["4", "5", "6", "×"],
      ["1", "2", "3", "-"],
      ["0", ".", "%", "+"],
    ];

    return Column(
      children: [
        // Existing rows
        ...buttons.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: row.map((btn) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _insertText(btn),
                    child: Container(
                      height: 55,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: "+-×÷".contains(btn)
                            ? const Color(0xFFF2E9FF)
                            : const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          btn,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),

        // NEW ROW — Delete + Equal
        // NEW ROW — Delete + Parentheses
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              // DELETE BUTTON
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_controller.text.isNotEmpty) {
                      _controller.text = _controller.text
                          .substring(0, _controller.text.length - 1);
                      setState(() {});
                    }
                  },
                  child: Container(
                    height: 55,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.backspace_outlined,
                        size: 22,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),

              // PARENTHESES BUTTON (NEW)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _insertText("()");
                    // Move cursor inside parentheses
                    final pos = _controller.text.length - 1;
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: pos),
                    );
                    setState(() {});
                  },
                  child: Container(
                    height: 55,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2E9FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "( )",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8E44FF),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }

  Widget _solveButton() {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB28DFE), Color(0xFF9C6BFF)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),

      child: TextButton.icon(
        onPressed: () async {
          if (_controller.text.trim().isEmpty) {
            Get.snackbar("Error", "Please enter a math problem",
                backgroundColor: Colors.red, colorText: Colors.white);
            return;
          }

          // 1. Start solving
          await controller.solve(_controller.text.trim());

          // 2. When solving finishes, update daily progress
          if (controller.result.value.isNotEmpty) {
            final fs = Get.find<FirebaseServices>();

            await fs.updateDailyProgress(
              summaries: 0,
              questions: 0,
              solved: 1,   // 👈 Math solved +1
            );
          }
        },


        icon: const Icon(Icons.calculate, color: Colors.white),
        label: const Text(
          "Solve Problem",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ---------------------- SMALL COMPONENTS ----------------------
  Widget _roundButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
