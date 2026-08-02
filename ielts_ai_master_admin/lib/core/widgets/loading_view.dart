import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

class LoadingView extends StatelessWidget {
  final String message;

  const LoadingView({
    super.key,
    this.message = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AdminColors.cyan),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(color: AdminColors.textMuted),
          ),
        ],
      ),
    );
  }
}
