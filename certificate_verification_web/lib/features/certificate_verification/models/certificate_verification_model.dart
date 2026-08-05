import 'package:cloud_firestore/cloud_firestore.dart';

class CertificateVerificationModel {
  final String verificationCode;
  final String certificateId;
  final String certificatePath;
  final String achievementType;
  final String certificateType;
  final String title;
  final String userName;
  final String issuer;
  final String status;
  final String disclaimer;
  final double band;
  final DateTime? issuedAt;

  const CertificateVerificationModel({
    required this.verificationCode,
    required this.certificateId,
    required this.certificatePath,
    required this.achievementType,
    required this.certificateType,
    required this.title,
    required this.userName,
    required this.issuer,
    required this.status,
    required this.disclaimer,
    required this.band,
    required this.issuedAt,
  });

  bool get isValid => status.toLowerCase() == 'valid';

  factory CertificateVerificationModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return CertificateVerificationModel(
      verificationCode: _string(
        data['verificationCode'],
        fallback: document.id,
      ),
      certificateId: _string(
        data['certificateId'],
        fallback: 'Unavailable',
      ),
      certificatePath: _string(
        data['certificatePath'],
        fallback: '',
      ),
      achievementType: _string(
        data['achievementType'],
        fallback: 'course_completion',
      ),
      certificateType: _string(
        data['certificateType'],
        fallback: 'Course Completion',
      ),
      title: _string(
        data['title'],
        fallback: 'IELTS AI Master Achievement',
      ),
      userName: _string(
        data['userName'],
        fallback: 'IELTS Learner',
      ),
      issuer: _string(
        data['issuer'],
        fallback: 'IELTS AI Master',
      ),
      status: _string(
        data['status'],
        fallback: 'valid',
      ),
      disclaimer: _string(
        data['disclaimer'],
        fallback: defaultDisclaimer,
      ),
      band: _double(
        data['band'] ??
            data['overallBand'] ??
            data['estimatedBand'],
      ),
      issuedAt: _date(
        data['issuedAt'] ??
            data['createdAt'],
      ),
    );
  }

  static const defaultDisclaimer =
      'Certificate of Course Completion\n\n'
      'This certificate confirms completion of training and assessments '
      'within IELTS AI Master.\n\n'
      'This is NOT an official IELTS score or an official IELTS certificate.';

  static String _string(
    dynamic value, {
    required String fallback,
  }) {
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
