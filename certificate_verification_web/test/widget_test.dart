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

  test('missing lifecycle status is never treated as valid', () {
    final certificate = CertificateVerificationModel.fromMap({
      'verificationCode': 'IAM-2026-1A2B3C4D5E',
      'certificateId': 'legacy',
    });
    expect(certificate.status, 'unknown');
    expect(certificate.isValid, isFalse);
  });

  test('revoked credentials remain readable with their reason', () {
    final certificate = CertificateVerificationModel.fromMap({
      'verificationCode': 'IAM-2026-1A2B3C4D5E',
      'certificateId': 'revoked',
      'status': 'revoked',
      'revocationReason': 'Administrative review completed.',
      'credentialType': 'mock_assessment_report',
      'estimatedPracticeBand': 7,
      'skillEstimatedPracticeBands': {
        'listening': 7.5,
        'reading': 7,
        'writing': 6.5,
        'speaking': 7,
      },
    });
    expect(certificate.isValid, isFalse);
    expect(certificate.status, 'revoked');
    expect(certificate.revocationReason, contains('Administrative'));
    expect(certificate.skillEstimatedPracticeBands.length, 4);
  });
}
