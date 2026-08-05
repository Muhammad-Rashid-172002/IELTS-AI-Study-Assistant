import 'package:flutter/material.dart';

import '../../../core/theme_controller.dart';
import '../../../core/verification_theme.dart';
import '../data/certificate_verification_repository.dart';
import '../models/certificate_verification_model.dart';
import '../services/verification_report_service.dart';
import '../widgets/verification_widgets.dart';
import 'qr_scanner_dialog.dart';

enum VerificationState { idle, loading, verified, invalid, error }

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    super.key,
    required this.themeController,
  });

  final ThemeController themeController;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  final _repository = CertificateVerificationRepository();
  final _controller = TextEditingController();

  late final AnimationController _pulseController;
  VerificationState _state = VerificationState.idle;
  CertificateVerificationModel? _certificate;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _loadCodeFromUrl();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _loadCodeFromUrl() {
    final uri = Uri.base;
    String code = uri.queryParameters['code'] ?? '';

    final verifyIndex = uri.pathSegments.indexOf('verify');
    if (code.isEmpty &&
        verifyIndex >= 0 &&
        verifyIndex + 1 < uri.pathSegments.length) {
      code = uri.pathSegments[verifyIndex + 1];
    }

    if (code.trim().isEmpty) return;
    _controller.text = code.trim().toUpperCase();

    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _scanQr() async {
    final code = await QrScannerDialog.show(context);
    if (code == null || code.trim().isEmpty || !mounted) return;

    _controller.text = code.trim().toUpperCase();
    await _verify();
  }

  Future<void> _verify() async {
    final code = _controller.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _state = VerificationState.error;
        _message = 'Enter a certificate verification code.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _state = VerificationState.loading;
      _certificate = null;
      _message = '';
    });

    try {
      final certificate = await _repository.verify(code);
      if (!mounted) return;

      if (certificate == null) {
        setState(() {
          _state = VerificationState.invalid;
          _message = 'No certificate was found for this verification code.';
        });
        return;
      }

      if (!certificate.isValid) {
        setState(() {
          _state = VerificationState.invalid;
          _certificate = certificate;
          _message = 'This certificate exists but is not currently valid.';
        });
        return;
      }

      setState(() {
        _state = VerificationState.verified;
        _certificate = certificate;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = VerificationState.error;
        _message =
            'Certificate verification could not be completed. Please try again.';
      });
    }
  }

  void _reset() {
    setState(() {
      _controller.clear();
      _state = VerificationState.idle;
      _certificate = null;
      _message = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _PageBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 980;
                final tablet = constraints.maxWidth >= 650;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: desktop ? 42 : 18,
                    vertical: 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        children: [
                          _topBar(desktop),
                          SizedBox(height: desktop ? 50 : 30),
                          if (desktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _hero()),
                                const SizedBox(width: 28),
                                Expanded(child: _verificationPanel()),
                              ],
                            )
                          else ...[
                            _hero(compact: !tablet),
                            const SizedBox(height: 22),
                            _verificationPanel(),
                          ],
                          const SizedBox(height: 100),
                          _footer(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(bool desktop) {
    final palette = PortalPalette(context);
    return Row(
      children: [
        const VerificationBrand(),
        const Spacer(),
        if (desktop)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: palette.border),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: VerificationColors.green,
                  size: 15,
                ),
                SizedBox(width: 7),
                Text(
                  'Secure public verification',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: widget.themeController.isDark
              ? 'Switch to light mode'
              : 'Switch to dark mode',
          onPressed: widget.themeController.toggle,
          style: IconButton.styleFrom(
            backgroundColor: palette.surface,
            side: BorderSide(color: palette.border),
          ),
          icon: Icon(
            widget.themeController.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
          ),
        ),
      ],
    );
  }

  Widget _hero({bool compact = false}) {
    final palette = PortalPalette(context);
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: VerificationColors.premiumGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Container(
        padding: EdgeInsets.all(compact ? 22 : 30),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(29),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: VerificationColors.cyan.withOpacity(.10),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: VerificationColors.cyan.withOpacity(.24),
                ),
              ),
              child: const Text(
                'OFFICIAL APP RECORD',
                style: TextStyle(
                  color: VerificationColors.cyan,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Verify an IELTS AI Master certificate',
              style: TextStyle(
                color: palette.text,
                fontSize: compact ? 31 : 40,
                height: 1.06,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Search by verification code or scan the QR code printed on the certificate. The result is checked directly against the secure public registry.',
              style: TextStyle(
                color: palette.secondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            const _HeroFeature(
              icon: Icons.verified_user_outlined,
              title: 'Authenticity check',
              subtitle: 'Confirms that the certificate exists and is valid.',
            ),
            const SizedBox(height: 13),
            const _HeroFeature(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Camera QR scanner',
              subtitle: 'Scan a certificate on mobile, tablet or desktop.',
            ),
            const SizedBox(height: 13),
            const _HeroFeature(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Verification report',
              subtitle: 'Download or print a professional PDF report.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _verificationPanel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .04),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: switch (_state) {
        VerificationState.verified when _certificate != null => Column(
            key: const ValueKey('verified'),
            children: [
              VerificationSuccessCard(certificate: _certificate!),
              const SizedBox(height: 14),
              _reportActions(_certificate!),
              const SizedBox(height: 14),
              VerificationNotice(text: _certificate!.disclaimer),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Verify Another Certificate'),
                ),
              ),
            ],
          ),
        _ => _searchCard(),
      },
    );
  }

  Widget _reportActions(CertificateVerificationModel certificate) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final download = FilledButton.icon(
          onPressed: () => VerificationReportService.download(certificate),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download Report'),
        );
        final print = OutlinedButton.icon(
          onPressed: () => VerificationReportService.printReport(certificate),
          icon: const Icon(Icons.print_rounded),
          label: const Text('Print'),
        );

        if (compact) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: download),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: print),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: download),
            const SizedBox(width: 10),
            Expanded(child: print),
          ],
        );
      },
    );
  }

  Widget _searchCard() {
    final palette = PortalPalette(context);
    final isLoading = _state == VerificationState.loading;
    final hasError = _state == VerificationState.invalid ||
        _state == VerificationState.error;

    return Container(
      key: const ValueKey('search'),
      padding: const EdgeInsets.all(24),
      decoration: portalPanel(context, elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Certificate Verification',
            style: TextStyle(
              color: palette.text,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Use the exact code or scan the certificate QR code.',
            style: TextStyle(color: palette.muted, fontSize: 11),
          ),
          const SizedBox(height: 19),
          TextField(
            controller: _controller,
            enabled: !isLoading,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _verify(),
            style: TextStyle(
              color: palette.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
            decoration: const InputDecoration(
              labelText: 'Verification Code',
              hintText: 'IAM-2026-XXXXXXXXXX',
              prefixIcon: Icon(Icons.password_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : _scanQr,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan QR Code'),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 13),
            _InvalidMessage(
              message: _message,
              controller: _pulseController,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading ? null : _verify,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_rounded),
              label: Text(
                isLoading ? 'Verifying Certificate...' : 'Verify Certificate',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: palette.border),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: VerificationColors.orange,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'This service verifies IELTS AI Master completion and achievement certificates only. It does not verify official IELTS examination results.',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final palette = PortalPalette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(.80),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.copyright_rounded, color: palette.muted, size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'IELTS AI Master • Certificate Verification Service',
              style: TextStyle(color: palette.muted, fontSize: 9.5),
            ),
          ),
          const Text(
            'Secure • Read-only',
            style: TextStyle(
              color: VerificationColors.green,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvalidMessage extends StatelessWidget {
  const _InvalidMessage({
    required this.message,
    required this.controller,
  });

  final String message;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final palette = PortalPalette(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) => Transform.scale(
        scale: 1 + controller.value * .006,
        child: child,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: VerificationColors.red.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: VerificationColors.red.withOpacity(.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cancel_rounded,
              color: VerificationColors.red,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: palette.secondary,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFeature extends StatelessWidget {
  const _HeroFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = PortalPalette(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: VerificationColors.cyan.withOpacity(.10),
          child: Icon(icon, color: VerificationColors.cyan, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageBackground extends StatelessWidget {
  const _PageBackground();

  @override
  Widget build(BuildContext context) {
    final palette = PortalPalette(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(.72, -.88),
          radius: 1.18,
          colors: [
            VerificationColors.blue.withOpacity(
              palette.dark ? .16 : .09,
            ),
            VerificationColors.violet.withOpacity(
              palette.dark ? .07 : .035,
            ),
            palette.background,
          ],
        ),
      ),
    );
  }
}
