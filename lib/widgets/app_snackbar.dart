import 'package:flutter/material.dart';
// import 'package:fyproject/utils/app_colors.dart';
enum SnackBarType { success, error, info }

class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
  }) {
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = const Color(0xff16A34A); // green
        icon = Icons.check_circle_rounded;
        break;
      case SnackBarType.error:
        backgroundColor = const Color(0xffDC2626); // red
        icon = Icons.error_rounded;
        break;
      case SnackBarType.info:
      default:
        backgroundColor = const Color(0xff4F46E5); // indigo
        icon = Icons.info_rounded;
        break;
    }

    final snackBar = SnackBar(
      elevation: 6,
      dismissDirection: DismissDirection.horizontal,
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),

      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                height: 1.2,
                fontWeight: FontWeight.w600,
                fontSize: 15.5,
              ),
            ),
          ),
        ],
      ),
    );

    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars(); // Prevent stacking
    messenger.showSnackBar(snackBar);
  }
}
