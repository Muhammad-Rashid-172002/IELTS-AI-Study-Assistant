import 'package:flutter/material.dart';

class DiagnosticAdminColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF111D2F);
  static const surfaceSoft = Color(0xFF162438);
  static const border = Color(0xFF26374F);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const cyan = Color(0xFF22D3EE);
  static const blue = Color(0xFF3B82F6);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
}

BoxDecoration diagnosticPanel({
  Color? borderColor,
}) {
  return BoxDecoration(
    color: DiagnosticAdminColors.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: borderColor ?? DiagnosticAdminColors.border,
    ),
  );
}

class DiagnosticMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const DiagnosticMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: diagnosticPanel(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: DiagnosticAdminColors.muted,
                    fontSize: 10,
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

class DiagnosticStatusChip extends StatelessWidget {
  final String status;

  const DiagnosticStatusChip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'published' => DiagnosticAdminColors.green,
      'archived' => DiagnosticAdminColors.violet,
      _ => DiagnosticAdminColors.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class DiagnosticSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const DiagnosticSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(.12),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: DiagnosticAdminColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: DiagnosticAdminColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
