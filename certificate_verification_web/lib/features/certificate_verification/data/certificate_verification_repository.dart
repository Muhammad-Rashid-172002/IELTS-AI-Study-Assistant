import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/certificate_verification_model.dart';

class CertificateVerificationRepository {
  CertificateVerificationRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<CertificateVerificationModel?> verify(
    String verificationCode,
  ) async {
    final normalized = verificationCode.trim().toUpperCase();

    if (normalized.isEmpty) {
      throw ArgumentError('Verification code is required.');
    }

    final document = await _firestore
        .collection('certificate_verifications')
        .doc(normalized)
        .get();

    if (!document.exists) return null;

    return CertificateVerificationModel.fromDocument(document);
  }
}
