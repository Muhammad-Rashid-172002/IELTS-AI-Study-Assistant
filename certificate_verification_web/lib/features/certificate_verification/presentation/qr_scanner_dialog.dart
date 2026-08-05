import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/verification_theme.dart';

class QrScannerDialog extends StatefulWidget {
  const QrScannerDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const QrScannerDialog(),
    );
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isEmpty) continue;

      final code = _extractCode(raw);
      if (code.isEmpty) continue;

      _handled = true;
      Navigator.pop(context, code);
      return;
    }
  }

  String _extractCode(String raw) {
    final uri = Uri.tryParse(raw);

    if (uri != null) {
      final queryCode = uri.queryParameters['code'];
      if (queryCode != null && queryCode.trim().isNotEmpty) {
        return queryCode.trim().toUpperCase();
      }

      final verifyIndex = uri.pathSegments.indexOf('verify');
      if (verifyIndex >= 0 && verifyIndex + 1 < uri.pathSegments.length) {
        return uri.pathSegments[verifyIndex + 1].trim().toUpperCase();
      }
    }

    final match = RegExp(
      r'IAM-\d{4}-[A-Z0-9_-]+',
      caseSensitive: false,
    ).firstMatch(raw);

    return (match?.group(0) ?? raw).trim().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 10, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan Certificate QR',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Allow camera access when requested.',
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                    Center(
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: VerificationColors.cyan,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _controller.toggleTorch,
                        icon: const Icon(Icons.flash_on_rounded),
                        label: const Text('Torch'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _controller.switchCamera,
                        icon: const Icon(Icons.cameraswitch_rounded),
                        label: const Text('Camera'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
