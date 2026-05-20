import 'package:flutter/material.dart';
import 'package:fyproject/screens/Full_Mock_Test/test_runner.dart';
import 'package:fyproject/screens/pages/Listening_Practice/ListeningPractice.dart';
import 'package:fyproject/screens/pages/Reading_Practice/ReadingPractice.dart';
import 'package:fyproject/screens/pages/Speaking_Practice/SpeakingPractice.dart';
import 'package:fyproject/screens/pages/Writing_Checker/WritingChecker.dart';
import 'package:get/get.dart';
import 'package:fyproject/controller/feedback_controller/feedback_controller.dart';

class FullMockTest extends StatefulWidget {
  const FullMockTest({super.key});

  @override
  State<FullMockTest> createState() => _FullMockTestState();
}

class _FullMockTestState extends State<FullMockTest>
    with SingleTickerProviderStateMixin {
  final IELTSController ieltsController = Get.put(IELTSController());

  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  Color get primary => const Color(0xFF14B8A6);
  Color get secondary => const Color(0xFF0F766E);
  Color get bg => const Color(0xFF08111F);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _topHeader(),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              child: Column(
                children: [
                  _mainCard(),

                  const SizedBox(height: 18),

                  _sectionTile(
                    "Listening",
                    Icons.headphones_rounded,
                    "30 min • 40 questions",
                    const Color(0xFF38BDF8),
                    onTap: () => Get.to(() => const ListeningPractice()),
                  ),

                  _sectionTile(
                    "Reading",
                    Icons.menu_book_rounded,
                    "60 min • Academic passage",
                    const Color(0xFFA78BFA),
                    onTap: () => Get.to(() => const ReadingPractice()),
                  ),

                  _sectionTile(
                    "Writing",
                    Icons.edit_note_rounded,
                    "60 min • Task 1 & Task 2",
                    const Color(0xFFF472B6),
                    onTap: () => Get.to(() => const WritingChecker()),
                  ),

                  _sectionTile(
                    "Speaking",
                    Icons.mic_rounded,
                    "11–14 min • AI examiner",
                    const Color(0xFF2DD4BF),
                    onTap: () => Get.to(() => const SpeakingPractice()),
                  ),

                  const SizedBox(height: 18),

                  _startButton(),

                  const SizedBox(height: 18),

                  _beforeStartCard(),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF08111F),
            Color(0xFF102A43),
            Color(0xFF0F766E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Get.back(),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Full Mock Test",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Complete IELTS Simulation",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              _circleButton(
                icon: Icons.workspace_premium_rounded,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: _headerInfoCard(
                  icon: Icons.timer_outlined,
                  title: "Duration",
                  value: "165 min",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _headerInfoCard(
                  icon: Icons.quiz_outlined,
                  title: "Sections",
                  value: "4 Parts",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  Widget _headerInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
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
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
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

  Widget _mainCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.school_rounded, "Academic IELTS"),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _instruction("Complete all four sections in order"),
                _instruction("Each section has its own time limit"),
                _instruction("Review your answers before submitting"),
                _instruction("Results will be available instantly"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primary, secondary]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _instruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTile(
    String title,
    IconData icon,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 27),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.58),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 17,
              color: Colors.white.withOpacity(0.60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _startButton() {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: () {
          Get.to(() => const TestRunner());
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2DD4BF),
                Color(0xFF14B8A6),
                Color(0xFF0F766E),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                "Start Mock Test",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _beforeStartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            color: Color(0xFFFBBF24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Find a quiet space and ensure stable internet before starting.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}