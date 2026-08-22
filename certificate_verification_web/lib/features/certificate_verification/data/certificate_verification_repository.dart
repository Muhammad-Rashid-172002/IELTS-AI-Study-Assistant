import 'package:cloud_functions/cloud_functions.dart';

import '../models/certificate_verification_model.dart';

class CertificateVerificationRepository {
  CertificateVerificationRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<CertificateVerificationModel?> verify(String verificationCode) async {
    final normalized = verificationCode.trim().toUpperCase();

    if (normalized.isEmpty) {
      throw ArgumentError('Verification code is required.');
    }

    final result = await _functions.httpsCallable('verifyCertificate').call({
      'verificationCode': normalized,
    });
    final payload = Map<String, dynamic>.from(result.data as Map);
    if (payload['found'] != true || payload['certificate'] is! Map) {
      return null;
    }

    return CertificateVerificationModel.fromMap(
      Map<String, dynamic>.from(payload['certificate'] as Map),
    );
  }
}
