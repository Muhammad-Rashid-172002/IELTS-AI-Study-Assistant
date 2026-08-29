class CertificateVerificationModel {
  final String verificationCode;
  final String certificateId;
  final String certificatePath;
  final String achievementType;
  final String certificateType;
  final String credentialType;
  final String title;
  final String userName;
  final String issuer;
  final String status;
  final String disclaimer;
  final double band;
  final DateTime? issuedAt;
  final DateTime? assessmentDate;
  final DateTime? revokedAt;
  final String revocationReason;
  final String scoringVersion;
  final Map<String, double> skillEstimatedPracticeBands;

  const CertificateVerificationModel({
    required this.verificationCode,
    required this.certificateId,
    required this.certificatePath,
    required this.achievementType,
    required this.certificateType,
    required this.credentialType,
    required this.title,
    required this.userName,
    required this.issuer,
    required this.status,
    required this.disclaimer,
    required this.band,
    required this.issuedAt,
    required this.assessmentDate,
    required this.revokedAt,
    required this.revocationReason,
    required this.scoringVersion,
    required this.skillEstimatedPracticeBands,
  });

  bool get isValid => status.toLowerCase() == 'valid';

  factory CertificateVerificationModel.fromMap(
    Map<String, dynamic> data, {
    String? fallbackCode,
  }) {
    return CertificateVerificationModel(
      verificationCode: _string(
        data['verificationCode'],
        fallback: fallbackCode ?? 'Unavailable',
      ),
      certificateId: _string(data['certificateId'], fallback: 'Unavailable'),
      certificatePath: _string(data['certificatePath'], fallback: ''),
      achievementType: _string(
        data['achievementType'],
        fallback: 'course_completion',
      ),
      certificateType: _string(
        data['certificateType'],
        fallback: 'Course Completion',
      ),
      credentialType: _string(
        data['credentialType'],
        fallback: 'legacy_certificate',
      ).toLowerCase(),
      title: _string(data['title'], fallback: 'IELTS AI Master Achievement'),
      userName: _string(data['userName'], fallback: 'IELTS Learner'),
      issuer: _string(data['issuer'], fallback: 'IELTS AI Master'),
      status: _string(data['status'], fallback: 'unknown'),
      disclaimer: _string(data['disclaimer'], fallback: defaultDisclaimer),
      band: _double(
        data['estimatedPracticeBand'] ??
            data['band'] ??
            data['overallBand'] ??
            data['estimatedBand'],
      ),
      issuedAt: _date(data['issuedAt'] ?? data['createdAt']),
      assessmentDate: _date(data['assessmentDate']),
      revokedAt: _date(data['revokedAt']),
      revocationReason: _string(data['revocationReason'], fallback: ''),
      scoringVersion: _string(
        data['scoringVersion'],
        fallback: 'legacy_unversioned',
      ),
      skillEstimatedPracticeBands: _bandMap(
        data['skillEstimatedPracticeBands'] ?? data['skillBands'],
      ),
    );
  }

  static const defaultDisclaimer =
      'Practice credential only — not an official IELTS result or Test '
      'Report Form (TRF). IELTS AI Master is an independent preparation '
      'platform and is not endorsed by or affiliated with IELTS, the British '
      'Council, IDP or Cambridge.';

  static String _string(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static double _double(dynamic value) {
    if (value is Map) {
      return _double(value['estimatedBand'] ?? value['band']);
    }
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, double> _bandMap(dynamic value) {
    if (value is! Map) return const {};
    final source = Map<String, dynamic>.from(value);
    return {
      for (final skill in const ['listening', 'reading', 'writing', 'speaking'])
        if (_double(source[skill]) > 0) skill: _double(source[skill]),
    };
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds.toInt() * 1000,
          isUtc: true,
        ).toLocal();
      }
    }
    return null;
  }
}
