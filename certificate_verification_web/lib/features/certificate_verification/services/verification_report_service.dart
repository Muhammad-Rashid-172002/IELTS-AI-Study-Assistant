import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/certificate_verification_model.dart';

class VerificationReportService {
  static Future<Uint8List> build(
    CertificateVerificationModel certificate,
  ) async {
    final document = pw.Document(
      title: 'Platform Credential Verification Report',
      author: 'IELTS AI Master',
      subject: certificate.verificationCode,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(22),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue700),
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'IELTS AI MASTER',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Platform Credential Verification Report',
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  certificate.isValid
                      ? 'CREDENTIAL VERIFIED — VALID PLATFORM RECORD'
                      : 'CREDENTIAL STATUS: ${certificate.status.toUpperCase()}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: certificate.isValid
                        ? PdfColors.green700
                        : PdfColors.red700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          _row('Recipient', certificate.userName),
          _row('Achievement', certificate.title),
          _row('Certificate Type', certificate.certificateType),
          if (certificate.band > 0)
            _row(
              'Estimated Practice Band',
              certificate.band.toStringAsFixed(1),
            ),
          _row('Certificate ID', certificate.certificateId),
          _row('Verification Code', certificate.verificationCode),
          _row('Status', certificate.status.toUpperCase()),
          _row('Issued By', certificate.issuer),
          _row('Issue Date', _formatDate(certificate.issuedAt)),
          if (certificate.assessmentDate != null)
            _row('Assessment Date', _formatDate(certificate.assessmentDate)),
          if (certificate.scoringVersion != 'legacy_unversioned')
            _row('Scoring Version', certificate.scoringVersion),
          pw.SizedBox(height: 22),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Text(
            certificate.disclaimer,
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
              lineSpacing: 4,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Generated from the IELTS AI Master app-issued credential registry. Practice credential only — not an official IELTS result or Test Report Form (TRF).',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return document.save();
  }

  static Future<void> download(CertificateVerificationModel certificate) async {
    final bytes = await build(certificate);
    final safeCode = certificate.verificationCode.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'certificate_verification_$safeCode.pdf',
    );
  }

  static Future<void> printReport(
    CertificateVerificationModel certificate,
  ) async {
    await Printing.layoutPdf(
      name: 'Platform Credential Verification Report',
      onLayout: (_) => build(certificate),
    );
  }

  static pw.Widget _row(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 9),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 145,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
