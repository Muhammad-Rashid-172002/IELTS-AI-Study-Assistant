import 'dart:ui';

import 'package:flutter/material.dart';

import 'core/theme_controller.dart';
import 'core/verification_theme.dart';
import 'features/certificate_verification/presentation/verification_screen.dart';

class CertificateVerificationApp extends StatefulWidget {
  const CertificateVerificationApp({super.key});

  @override
  State<CertificateVerificationApp> createState() =>
      _CertificateVerificationAppState();
}

class _CertificateVerificationAppState
    extends State<CertificateVerificationApp> {
  final ThemeController _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    _themeController.load();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'IELTS AI Master Certificate Verification',
          theme: VerificationTheme.light,
          darkTheme: VerificationTheme.dark,
          themeMode: _themeController.mode,
          home: VerificationScreen(
            themeController: _themeController,
          ),
          builder: (context, child) {
            return ScrollConfiguration(
              behavior: const _AppScrollBehavior(),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
