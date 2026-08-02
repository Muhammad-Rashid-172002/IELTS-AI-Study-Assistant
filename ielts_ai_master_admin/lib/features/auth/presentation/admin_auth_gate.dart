import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../dashboard/presentation/admin_shell.dart';
import '../data/admin_auth_service.dart';
import 'admin_login_screen.dart';

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminAuthService();

    return StreamBuilder<User?>(
      stream: service.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Checking session...');
        }

        if (snapshot.data == null) {
          return const AdminLoginScreen();
        }

        return FutureBuilder<bool>(
          future: service.isCurrentUserAdmin(),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(
                message: 'Checking admin permission...',
              );
            }

            if (adminSnapshot.data != true) {
              return ErrorView(
                message:
                    'Access denied. Firestore users/{uid} mein role: admin ya isAdmin: true add karein.',
                onRetry: service.signOut,
              );
            }

            return const AdminShell();
          },
        );
      },
    );
  }
}
