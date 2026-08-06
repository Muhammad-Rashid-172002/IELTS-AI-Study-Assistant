import 'package:flutter/material.dart';
import 'package:fyproject/models/mock_test_models.dart';

IconData skillIcon(MockSkill skill) => switch (skill) {
  MockSkill.listening => Icons.headphones_rounded,
  MockSkill.reading => Icons.menu_book_rounded,
  MockSkill.writing => Icons.edit_note_rounded,
  MockSkill.speaking => Icons.mic_rounded,
};

class MockColors {
  static const background = Color(0xFF08111F);
  static const surface = Color(0xFF111C2E);
  static const border = Color(0xFF22324A);
  static const primary = Color(0xFF2563EB);
  static const cyan = Color(0xFF06B6D4);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
}

BoxDecoration panelDecoration() {
  return BoxDecoration(
    color: MockColors.surface.withOpacity(.96),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: MockColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.12),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration heroDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        MockColors.surface,
        MockColors.cyan.withOpacity(.09),
        MockColors.violet.withOpacity(.08),
      ],
    ),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: MockColors.cyan.withOpacity(.22)),
  );
}

class MockBackground extends StatelessWidget {
  const MockBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MockColors.background,
            Color(0xFF0D172B),
            MockColors.background,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class GradientIcon extends StatelessWidget {
  final IconData icon;

  const GradientIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MockColors.cyan, MockColors.primary, MockColors.violet],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class Tag extends StatelessWidget {
  final String label;

  const Tag(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: MockColors.cyan.withOpacity(.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: MockColors.cyan.withOpacity(.24)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MockColors.cyan,
          fontSize: 8.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const StatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 430),
      margin: const EdgeInsets.all(22),
      padding: const EdgeInsets.all(24),
      decoration: panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: MockColors.cyan, size: 50),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MockColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: MockColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
