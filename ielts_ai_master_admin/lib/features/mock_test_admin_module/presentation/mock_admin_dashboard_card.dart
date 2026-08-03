import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';

class MockAdminDashboardCard extends StatelessWidget {
  final VoidCallback? onTap;

  const MockAdminDashboardCard({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('mock_tests')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final published = docs
            .where((doc) => doc.data()['status'] == 'published')
            .length;
        final drafts = docs
            .where((doc) => doc.data()['status'] == 'draft')
            .length;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AdminColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AdminColors.cyan.withOpacity(.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.fact_check_outlined,
                          color: AdminColors.cyan,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${docs.length}',
                        style: const TextStyle(
                          color: AdminColors.cyan,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Mock Tests',
                    style: TextStyle(
                      color: AdminColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Full simulations, question bank and analytics',
                    style: TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 9.7,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Published',
                          value: published,
                          color: AdminColors.success,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _Metric(
                          label: 'Draft',
                          value: drafts,
                          color: AdminColors.cyan,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }
}
