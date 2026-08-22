import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fyproject/resources/components/learner_state_view.dart';

const String kCertificateVerificationBaseUrl =
    'https://ielts-ai-study-assistant.web.app';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _query = '';
  String _selectedType = 'All';

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User is not signed in.');
    return user;
  }

  Stream<List<AppCertificate>> _watchCertificates() {
    return _db
        .collection('users')
        .doc(_user.uid)
        .collection('certificates')
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(AppCertificate.fromDocument).toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CertificateColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: StreamBuilder<List<AppCertificate>>(
                    stream: _watchCertificates(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return LearnerStateView.error(
                          title: 'Certificates are temporarily unavailable',
                          message:
                              'Your verified achievements are safe. Reconnect and refresh to load them again.',
                          icon: Icons.workspace_premium_outlined,
                          onAction: () => setState(() {}),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const LearnerStateView.loading(
                          title: 'Checking your achievements',
                          message:
                              'Loading verified milestones and completion records.',
                          icon: Icons.workspace_premium_rounded,
                        );
                      }

                      final certificates = snapshot.data!;
                      final filtered = certificates.where((certificate) {
                        final query = _query.trim().toLowerCase();

                        final matchesSearch =
                            query.isEmpty ||
                            certificate.title.toLowerCase().contains(query) ||
                            certificate.verificationCode.toLowerCase().contains(
                              query,
                            ) ||
                            certificate.certificateType.toLowerCase().contains(
                              query,
                            );

                        final matchesType =
                            _selectedType == 'All' ||
                            certificate.certificateType == _selectedType;

                        return matchesSearch && matchesType;
                      }).toList();

                      return RefreshIndicator(
                        onRefresh: () async {
                          await Future<void>.delayed(
                            const Duration(milliseconds: 400),
                          );
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                          children: [
                            _overview(certificates),
                            const SizedBox(height: 16),
                            _filters(certificates),
                            const SizedBox(height: 16),
                            if (filtered.isEmpty)
                              const _EmptyState()
                            else
                              ...filtered.map(
                                (certificate) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _CertificateCard(
                                    certificate: certificate,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CertificateDetailScreen(
                                                certificate: certificate,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              backgroundColor: CertificateColors.surface,
              foregroundColor: CertificateColors.text,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: CertificateColors.gradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(.10)),
              boxShadow: [
                BoxShadow(
                  color: CertificateColors.cyan.withOpacity(.18),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 29,
                ),
                Positioned(
                  right: 7,
                  top: 7,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: CertificateColors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CertificateColors.blue,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certificates',
                  style: TextStyle(
                    color: CertificateColors.text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Verified IELTS AI Master achievements',
                  style: TextStyle(
                    color: CertificateColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overview(List<AppCertificate> certificates) {
    final valid = certificates
        .where((certificate) => certificate.status == 'valid')
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your verified achievements',
            style: TextStyle(
              color: CertificateColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Each certificate includes a unique verification code, QR code and public verification URL.',
            style: TextStyle(
              color: CertificateColors.secondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.verified_rounded,
                label: '$valid verified',
                color: CertificateColors.green,
              ),
              _InfoChip(
                icon: Icons.workspace_premium_outlined,
                label: '${certificates.length} total',
                color: CertificateColors.cyan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters(List<AppCertificate> certificates) {
    final types = <String>{
      'All',
      ...certificates.map((certificate) => certificate.certificateType),
    }.toList();

    return Column(
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          style: const TextStyle(color: CertificateColors.text),
          decoration: InputDecoration(
            hintText: 'Search certificate or verification code...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: CertificateColors.surface,
            border: _fieldBorder(CertificateColors.border),
            enabledBorder: _fieldBorder(CertificateColors.border),
            focusedBorder: _fieldBorder(CertificateColors.cyan, width: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 43,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final type = types[index];
              final selected = _selectedType == type;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedType = type),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: selected ? CertificateColors.gradient : null,
                      color: selected ? null : CertificateColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? Colors.white.withOpacity(.10)
                            : CertificateColors.border,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: CertificateColors.cyan.withOpacity(.15),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type == 'All'
                              ? Icons.grid_view_rounded
                              : Icons.workspace_premium_outlined,
                          size: 14,
                          color: selected
                              ? Colors.white
                              : CertificateColors.cyan,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : CertificateColors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CertificateDetailScreen extends StatelessWidget {
  final AppCertificate certificate;

  const CertificateDetailScreen({super.key, required this.certificate});

  Future<void> _copy(BuildContext context, String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openVerificationUrl(BuildContext context) async {
    final uri = Uri.tryParse(certificate.verificationUrl);

    if (uri == null || !await canLaunchUrl(uri)) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification URL could not be opened.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CertificateColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: CertificateColors.surface,
                        foregroundColor: CertificateColors.text,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Text(
                        'Certificate Details',
                        style: TextStyle(
                          color: CertificateColors.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _StatusBadge(status: certificate.status),
                  ],
                ),
                const SizedBox(height: 18),
                _CertificatePreview(certificate: certificate),
                const SizedBox(height: 16),
                _VerificationPanel(
                  certificate: certificate,
                  onCopyCode: () => _copy(
                    context,
                    certificate.verificationCode,
                    'Verification code copied.',
                  ),
                  onCopyUrl: () => _copy(
                    context,
                    certificate.verificationUrl,
                    'Verification URL copied.',
                  ),
                  onOpenUrl: () => _openVerificationUrl(context),
                ),
                const SizedBox(height: 16),
                _CertificateInformation(certificate: certificate),
                const SizedBox(height: 16),
                _Disclaimer(text: certificate.disclaimer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificatePreview extends StatelessWidget {
  final AppCertificate certificate;

  const _CertificatePreview({required this.certificate});

  @override
  Widget build(BuildContext context) {
    final valid = certificate.status.toLowerCase() == 'valid';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;

        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                CertificateColors.gold,
                CertificateColors.cyan,
                CertificateColors.blue,
                CertificateColors.gold,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.34),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: CertificateColors.gold.withOpacity(.08),
                blurRadius: 24,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF091321),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1828),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: CertificateColors.gold.withOpacity(.28),
                ),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: _FormalCertificateWatermark()),
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: _CertificateCorner(top: true, left: true),
                  ),
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: _CertificateCorner(top: true, left: false),
                  ),
                  const Positioned(
                    bottom: 10,
                    left: 10,
                    child: _CertificateCorner(top: false, left: true),
                  ),
                  const Positioned(
                    bottom: 10,
                    right: 10,
                    child: _CertificateCorner(top: false, left: false),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 17 : 23,
                      22,
                      compact ? 17 : 23,
                      20,
                    ),
                    child: Column(
                      children: [
                        _FormalCertificateHeader(
                          valid: valid,
                          status: certificate.status,
                        ),
                        SizedBox(height: compact ? 20 : 25),
                        const Text(
                          'CERTIFICATE OF COMPLETION',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CertificateColors.gold,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          certificate.certificateType.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: CertificateColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 22),
                        const Text(
                          'THIS CERTIFIES THAT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CertificateColors.secondary,
                            fontSize: 8.2,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          certificate.userName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CertificateColors.text,
                            fontSize: compact ? 25 : 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.45,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: compact ? 125 : 155,
                          height: 1.4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                CertificateColors.gold,
                                CertificateColors.cyan,
                                CertificateColors.gold,
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 19),
                        const Text(
                          'has successfully completed the required learning '
                          'activities and assessments for',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CertificateColors.secondary,
                            fontSize: 11.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          certificate.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CertificateColors.text,
                            fontSize: compact ? 15 : 17,
                            height: 1.35,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (certificate.band > 0) ...[
                          const SizedBox(height: 15),
                          _FormalBandBadge(band: certificate.band),
                        ],
                        SizedBox(height: compact ? 19 : 24),
                        Container(
                          width: double.infinity,
                          height: 1,
                          color: CertificateColors.gold.withOpacity(.15),
                        ),
                        const SizedBox(height: 16),
                        compact
                            ? Column(
                                children: [
                                  _FormalCredentialRow(
                                    certificate: certificate,
                                  ),
                                  const SizedBox(height: 15),
                                  _CertificateVerificationSeal(
                                    certificate: certificate,
                                    valid: valid,
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: _FormalCredentialRow(
                                      certificate: certificate,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  _CertificateVerificationSeal(
                                    certificate: certificate,
                                    valid: valid,
                                  ),
                                ],
                              ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: CertificateColors.background.withOpacity(
                              .46,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CertificateColors.border.withOpacity(.78),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: CertificateColors.muted,
                              ),
                              SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'IELTS AI Master learning credential. '
                                  'This is not an official IELTS Test Report Form '
                                  'or an official IELTS certificate.',
                                  style: TextStyle(
                                    color: CertificateColors.muted,
                                    fontSize: 7.8,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
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
      },
    );
  }
}

class _FormalCertificateHeader extends StatelessWidget {
  final bool valid;
  final String status;

  const _FormalCertificateHeader({required this.valid, required this.status});

  @override
  Widget build(BuildContext context) {
    final statusColor = valid
        ? CertificateColors.green
        : CertificateColors.orange;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: CertificateColors.gold.withOpacity(.09),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: CertificateColors.gold.withOpacity(.30)),
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: CertificateColors.gold,
            size: 27,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IELTS AI MASTER',
                style: TextStyle(
                  color: CertificateColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.55,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'DIGITAL LEARNING CREDENTIAL',
                style: TextStyle(
                  color: CertificateColors.gold,
                  fontSize: 7.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.15,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(.09),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: statusColor.withOpacity(.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                valid ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: statusColor,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                valid ? 'VERIFIED' : status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormalBandBadge extends StatelessWidget {
  final double band;

  const _FormalBandBadge({required this.band});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: CertificateColors.cyan.withOpacity(.06),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: CertificateColors.cyan.withOpacity(.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insights_rounded,
            color: CertificateColors.cyan,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'Estimated Band ${band.toStringAsFixed(1)}',
            style: const TextStyle(
              color: CertificateColors.cyan,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormalCredentialRow extends StatelessWidget {
  final AppCertificate certificate;

  const _FormalCredentialRow({required this.certificate});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CredentialField(
                label: 'ISSUED ON',
                value: _formatCertificateDate(certificate.issuedAt),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CredentialField(
                label: 'CERTIFICATE ID',
                value: certificate.certificateId,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CredentialField(
                label: 'ISSUED BY',
                value: certificate.issuer,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CredentialField(
                label: 'STATUS',
                value: certificate.status.toUpperCase(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CredentialField extends StatelessWidget {
  final String label;
  final String value;

  const _CredentialField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 61),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: CertificateColors.background.withOpacity(.43),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CertificateColors.gold.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: CertificateColors.gold,
              fontSize: 6.8,
              fontWeight: FontWeight.w900,
              letterSpacing: .75,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CertificateColors.secondary,
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateVerificationSeal extends StatelessWidget {
  final AppCertificate certificate;
  final bool valid;

  const _CertificateVerificationSeal({
    required this.certificate,
    required this.valid,
  });

  @override
  Widget build(BuildContext context) {
    final sealColor = valid
        ? CertificateColors.green
        : CertificateColors.orange;

    return Container(
      constraints: const BoxConstraints(minWidth: 135),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sealColor.withOpacity(.055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: sealColor.withOpacity(.19)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: sealColor.withOpacity(.45), width: 1.3),
            ),
            child: Icon(
              valid ? Icons.verified_user_rounded : Icons.shield_outlined,
              color: sealColor,
              size: 23,
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valid ? 'VERIFIED' : 'CHECK STATUS',
                  style: TextStyle(
                    color: sealColor,
                    fontSize: 7.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  certificate.verificationCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CertificateColors.secondary,
                    fontSize: 8.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Online verification available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CertificateColors.muted,
                    fontSize: 6.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormalCertificateWatermark extends StatelessWidget {
  const _FormalCertificateWatermark();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Center(
            child: Opacity(
              opacity: .025,
              child: Transform.rotate(
                angle: -.18,
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 205,
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CertificateColors.gold.withOpacity(.025),
              ),
            ),
          ),
          Positioned(
            bottom: -85,
            left: -65,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CertificateColors.cyan.withOpacity(.022),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateCorner extends StatelessWidget {
  final bool top;
  final bool left;

  const _CertificateCorner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _CertificateCornerPainter(top: top, left: left),
      ),
    );
  }
}

class _CertificateCornerPainter extends CustomPainter {
  final bool top;
  final bool left;

  const _CertificateCornerPainter({required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CertificateColors.gold.withOpacity(.42)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final path = Path();

    final horizontalY = top ? 0.0 : size.height;
    final verticalX = left ? 0.0 : size.width;

    if (left) {
      path.moveTo(0, horizontalY);
      path.lineTo(size.width * .75, horizontalY);
    } else {
      path.moveTo(size.width, horizontalY);
      path.lineTo(size.width * .25, horizontalY);
    }

    if (top) {
      path.moveTo(verticalX, 0);
      path.lineTo(verticalX, size.height * .75);
    } else {
      path.moveTo(verticalX, size.height);
      path.lineTo(verticalX, size.height * .25);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CertificateCornerPainter oldDelegate) {
    return oldDelegate.top != top || oldDelegate.left != left;
  }
}

String _formatCertificateDate(DateTime? value) {
  if (value == null) return 'Not available';

  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${value.day.toString().padLeft(2, '0')} '
      '${months[value.month - 1]} ${value.year}';
}

class _VerificationPanel extends StatelessWidget {
  final AppCertificate certificate;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyUrl;
  final VoidCallback onOpenUrl;

  const _VerificationPanel({
    required this.certificate,
    required this.onCopyCode,
    required this.onCopyUrl,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.verified_user_outlined,
            title: 'Certificate Verification',
            subtitle: 'Scan the QR code or use the verification code and URL.',
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    CertificateColors.gold,
                    CertificateColors.cyan,
                    CertificateColors.blue,
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: QrImageView(
                  data: certificate.verificationUrl,
                  version: QrVersions.auto,
                  size: 185,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
              ),
            ),
          ),
          const SizedBox(height: 17),
          _CopyField(
            label: 'Verification Code',
            value: certificate.verificationCode,
            onCopy: onCopyCode,
          ),
          const SizedBox(height: 11),
          _CopyField(
            label: 'Verification URL',
            value: certificate.verificationUrl,
            onCopy: onCopyUrl,
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onOpenUrl,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Verify Certificate Online'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateInformation extends StatelessWidget {
  final AppCertificate certificate;

  const _CertificateInformation({required this.certificate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.info_outline_rounded,
            title: 'Certificate Information',
            subtitle: 'Official app record attached to this achievement.',
          ),
          const SizedBox(height: 15),
          _InfoRow(
            label: 'Certificate Type',
            value: certificate.certificateType,
          ),
          _InfoRow(label: 'Recipient', value: certificate.userName),
          _InfoRow(label: 'Achievement', value: certificate.title),
          if (certificate.band > 0)
            _InfoRow(
              label: 'Estimated Band',
              value: certificate.band.toStringAsFixed(1),
            ),
          _InfoRow(label: 'Status', value: certificate.status.toUpperCase()),
          _InfoRow(
            label: 'Issued By',
            value: certificate.issuer,
            divider: false,
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final String text;

  const _Disclaimer({required this.text});

  @override
  Widget build(BuildContext context) {
    final value = text.trim().isEmpty
        ? AppCertificate.defaultDisclaimer
        : text.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(
        borderColor: CertificateColors.orange.withOpacity(.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: CertificateColors.orange),
              SizedBox(width: 9),
              Text(
                'Important Notice',
                style: TextStyle(
                  color: CertificateColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            value,
            style: const TextStyle(
              color: CertificateColors.secondary,
              height: 1.55,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final AppCertificate certificate;
  final VoidCallback onTap;

  const _CertificateCard({required this.certificate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: _panelDecoration(),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: CertificateColors.gradient,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: Colors.white.withOpacity(.10)),
                boxShadow: [
                  BoxShadow(
                    color: CertificateColors.cyan.withOpacity(.13),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          certificate.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CertificateColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _StatusBadge(status: certificate.status),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    certificate.certificateType,
                    style: const TextStyle(
                      color: CertificateColors.cyan,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Code: ${certificate.verificationCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CertificateColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: CertificateColors.muted,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _CopyField({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 7, 10),
      decoration: BoxDecoration(
        color: CertificateColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CertificateColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: CertificateColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CertificateColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onCopy, icon: const Icon(Icons.copy_rounded)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool divider;

  const _InfoRow({
    required this.label,
    required this.value,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: CertificateColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: CertificateColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (divider) const Divider(height: 1, color: CertificateColors.border),
      ],
    );
  }
}

// class _MiniField extends StatelessWidget {
//   final String label;
//   final String value;

//   const _MiniField({required this.label, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(13),
//       decoration: BoxDecoration(
//         color: CertificateColors.background.withOpacity(.48),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: CertificateColors.border),
//       ),
//       child: Column(
//         children: [
//           Text(
//             label,
//             style: const TextStyle(
//               color: CertificateColors.muted,
//               fontSize: 12,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               color: CertificateColors.text,
//               fontSize: 12,
//               fontWeight: FontWeight.w900,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: CertificateColors.cyan.withOpacity(.11),
          child: Icon(icon, color: CertificateColors.cyan),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: CertificateColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: CertificateColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final valid = status.toLowerCase() == 'valid';
    final color = valid ? CertificateColors.green : CertificateColors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.11),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _panelDecoration(),
      child: const Column(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            color: CertificateColors.cyan,
            size: 54,
          ),
          SizedBox(height: 14),
          Text(
            'No certificates yet',
            style: TextStyle(
              color: CertificateColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Complete an eligible course, diagnostic test, mock test or achievement to earn a verified certificate.',
            textAlign: TextAlign.center,
            style: TextStyle(color: CertificateColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(.7, -.9),
          radius: 1.1,
          colors: [
            CertificateColors.blue.withOpacity(.10),
            CertificateColors.background,
          ],
        ),
      ),
    );
  }
}

class AppCertificate {
  final String id;
  final String certificateId;
  final String title;
  final String certificateType;
  final String userName;
  final double band;
  final String verificationCode;
  final String verificationUrl;
  final String issuer;
  final String status;
  final String disclaimer;
  final DateTime? issuedAt;

  const AppCertificate({
    required this.id,
    required this.certificateId,
    required this.title,
    required this.certificateType,
    required this.userName,
    required this.band,
    required this.verificationCode,
    required this.verificationUrl,
    required this.issuer,
    required this.status,
    required this.disclaimer,
    required this.issuedAt,
  });

  static const defaultDisclaimer =
      'Certificate of Course Completion\n\n'
      'This certificate confirms completion of training and assessments '
      'within IELTS AI Master.\n\n'
      'This is NOT an official IELTS score or an official IELTS certificate.';

  factory AppCertificate.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    final code = _string(
      data['verificationCode'] ?? data['code'] ?? data['certificateCode'],
      fallback: doc.id,
    );

    return AppCertificate(
      id: doc.id,
      certificateId: _string(data['certificateId'], fallback: doc.id),
      title: _string(
        data['title'] ?? data['achievementTitle'],
        fallback: 'IELTS AI Master Achievement',
      ),
      certificateType: _string(
        data['certificateType'] ?? data['type'],
        fallback: 'Course Completion',
      ),
      userName: _string(
        data['userName'] ?? data['name'] ?? data['recipientName'],
        fallback: 'IELTS Learner',
      ),
      band: _double(
        data['band'] ?? data['overallBand'] ?? data['estimatedBand'],
      ),
      verificationCode: code,
      verificationUrl: '$kCertificateVerificationBaseUrl/verify/$code',
      issuer: _string(data['issuer'], fallback: 'IELTS AI Master'),
      status: _string(data['status'], fallback: 'valid').toLowerCase(),
      disclaimer: _string(data['disclaimer'], fallback: defaultDisclaimer),
      issuedAt: _date(
        data['issuedAt'] ?? data['createdAt'] ?? data['completedAt'],
      ),
    );
  }

  static String _string(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class CertificateColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF111D2F);
  static const border = Color(0xFF26374F);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
  static const cyan = Color(0xFF22D3EE);
  static const blue = Color(0xFF3B82F6);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const gold = Color(0xFFD6B45A);

  static const gradient = LinearGradient(colors: [cyan, blue, violet]);
}

BoxDecoration _panelDecoration({Color? borderColor}) {
  return BoxDecoration(
    color: CertificateColors.surface,
    borderRadius: BorderRadius.circular(21),
    border: Border.all(color: borderColor ?? CertificateColors.border),
  );
}

BoxDecoration _heroDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        CertificateColors.surface,
        CertificateColors.blue.withOpacity(.18),
        CertificateColors.cyan.withOpacity(.10),
        CertificateColors.violet.withOpacity(.10),
      ],
    ),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: CertificateColors.cyan.withOpacity(.22)),
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
}
