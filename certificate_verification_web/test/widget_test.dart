import 'package:certificate_verification_web/features/certificate_verification/models/certificate_verification_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public certificate model accepts the server allow-list projection', () {
    final certificate = CertificateVerificationModel.fromMap({
      'verificationCode': 'IAM-2026-1A2B3C4D5E',
      'certificateId': 'diagnostic_result-1',
      'certificateType': 'Diagnostic Completion',
      'title': 'IELTS Diagnostic Assessment Completion',
      'userName': 'Example Learner',
      'issuer': 'IELTS AI Master',
      'status': 'valid',
      'band': 7.5,
      'issuedAt': {'_seconds': 1787356800},
    });

    expect(certificate.isValid, isTrue);
    expect(certificate.band, 7.5);
    expect(certificate.userName, 'Example Learner');
    expect(certificate.issuedAt, isNotNull);
  });
}
