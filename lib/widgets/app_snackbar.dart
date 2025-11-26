import 'package:flutter/material.dart';

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
        backgroundColor = Color(0xff16A34A); // green
        icon = Icons.check_circle;
        break;
      case SnackBarType.error:
        backgroundColor = Color(0xffDC2626); // red
        icon = Icons.error;
        break;
      case SnackBarType.info:
      default:
        backgroundColor = Color(0xff4F46E5); // indigo
        icon = Icons.info;
        break;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      duration: Duration(seconds: 2),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
