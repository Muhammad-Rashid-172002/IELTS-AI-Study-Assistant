import 'package:flutter/material.dart';

import '../core/theme/admin_theme.dart';
import '../features/auth/presentation/admin_auth_gate.dart';

class IELTSAdminApp extends StatelessWidget {
  const IELTSAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IELTS AI Master Admin',
      theme: AdminTheme.darkTheme,
      home: const AdminAuthGate(),
    );
  }
}
