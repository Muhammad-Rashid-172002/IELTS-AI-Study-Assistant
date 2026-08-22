import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'published' ||
      'active' ||
      'completed' ||
      'approved' => AdminColors.success,
      'draft' => AdminColors.cyan,
      'archived' => AdminColors.violet,
      'queued' ||
      'generating' ||
      'validating' ||
      'review' ||
      'pending' => AdminColors.warning,
      'failed' || 'suspended' || 'rejected' || 'invalid' => AdminColors.danger,
      _ => AdminColors.textMuted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
