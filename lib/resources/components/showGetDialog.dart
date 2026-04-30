import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

void showGetDialog({
  required String title,
  required String message,
  required bool isSuccess,
}) {
  Get.defaultDialog(
    title: title,
    middleText: message,
    radius: 12,
    backgroundColor: Colors.white,
    titleStyle: TextStyle(
      fontWeight: FontWeight.bold,
      color: isSuccess ? Colors.green : Colors.red,
    ),
    middleTextStyle: const TextStyle(fontSize: 14),
    textConfirm: "OK",
    confirmTextColor: Colors.white,
    buttonColor: isSuccess ? Colors.green : Colors.red,
    onConfirm: () => Get.back(),
  );
}