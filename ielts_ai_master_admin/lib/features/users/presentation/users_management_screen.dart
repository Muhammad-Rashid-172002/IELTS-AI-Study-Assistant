import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';

class UsersManagementScreen extends StatelessWidget {
  const UsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Users',
      subtitle: 'View registered learners',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingView();
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AdminColors.cyan.withOpacity(.14),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AdminColors.cyan,
                    ),
                  ),
                  title: Text(
                    (data['fullName'] ?? data['name'] ?? 'User').toString(),
                  ),
                  subtitle: Text(
                    (data['email'] ?? '').toString(),
                  ),
                  trailing: Text(
                    (data['role'] ?? 'learner').toString(),
                    style: const TextStyle(
                      color: AdminColors.textMuted,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
