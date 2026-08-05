import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/verification_theme.dart';
import '../models/certificate_verification_model.dart';

BoxDecoration portalPanel(
  BuildContext context, {
  Color? borderColor,
  bool elevated = false,
  double radius = 24,
}) {
  final palette = PortalPalette(context);
  return BoxDecoration(
    color: palette.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? palette.border),
    boxShadow: elevated
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(
                palette.dark ? .22 : .08,
              ),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ]
        : null,
  );
}

class VerificationBrand extends StatelessWidget {
  const VerificationBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = PortalPalette(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: VerificationColors.premiumGradient,
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: VerificationColors.cyan.withOpacity(.18),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IELTS AI MASTER',
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const Text(
              'Certificate Verification',
              style: TextStyle(
                color: VerificationColors.cyan,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class VerificationSuccessCard extends StatelessWidget {
  const VerificationSuccessCard({
    super.key,
    required this.certificate,
  });

  final CertificateVerificationModel certificate;

  @override
  Widget build(BuildContext context) {
    final palette = PortalPalette(context);
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: VerificationColors.premiumGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: VerificationColors.cyan.withOpacity(.14),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(29),
        ),
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .45, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (_, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Container(
                width: 94,
                height: 94,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: VerificationColors.premiumGradient,
                  boxShadow: [
                    BoxShadow(
                      color: VerificationColors.green.withOpacity(.18),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.surface,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: VerificationColors.green,
                    size: 49,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'CERTIFICATE VERIFIED',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VerificationColors.green,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              certificate.userName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontSize: 29,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              certificate.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.secondary,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (certificate.band > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: VerificationColors.cyan.withOpacity(.10),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: VerificationColors.cyan.withOpacity(.24),
                  ),
                ),
                child: Text(
                  'Estimated Band ${certificate.band.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: VerificationColors.cyan,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Divider(color: palette.border),
            VerificationDetailRow(
              label: 'Certificate type',
              value: certificate.certificateType,
            ),
            VerificationDetailRow(
              label: 'Certificate ID',
              value: certificate.certificateId,
            ),
            VerificationDetailRow(
              label: 'Verification code',
              value: certificate.verificationCode,
              copyable: true,
            ),
            VerificationDetailRow(
              label: 'Issued on',
              value: _formatDate(certificate.issuedAt),
            ),
            VerificationDetailRow(
              label: 'Issued by',
              value: certificate.issuer,
              divider: false,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class VerificationDetailRow extends StatelessWidget {
  const VerificationDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.copyable = false,
    this.divider = true,
  });

  final String label;
  final String value;
  final bool copyable;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final palette = PortalPalette(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 10.5,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (copyable) ...[
                      const SizedBox(width: 7),
                      IconButton(
                        tooltip: 'Copy',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: value),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verification code copied.'),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: VerificationColors.cyan,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (divider) Divider(height: 1, color: palette.border),
      ],
    );
  }
}

class VerificationNotice extends StatelessWidget {
  const VerificationNotice({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = PortalPalette(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: portalPanel(
        context,
        borderColor: VerificationColors.orange.withOpacity(.35),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: VerificationColors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: palette.secondary,
                height: 1.55,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
