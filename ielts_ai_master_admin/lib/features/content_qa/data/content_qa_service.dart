import 'package:cloud_functions/cloud_functions.dart';

class ContentQaService {
  ContentQaService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<ContentQaDashboardData> loadDashboard() async {
    final response = await _functions
        .httpsCallable('getContentQaDashboard')
        .call<Map<String, dynamic>>();
    return ContentQaDashboardData.fromMap(response.data);
  }

  Future<ContentQaTransitionResult> transition({
    required String documentPath,
    required String targetState,
    String? copyrightStatus,
    String? sourceType,
    String? sourceReference,
  }) async {
    final payload = <String, dynamic>{
      'documentPath': documentPath,
      'targetState': targetState,
    };
    if (copyrightStatus != null) {
      payload['copyrightStatus'] = copyrightStatus;
    }
    if (sourceType != null) {
      payload['sourceType'] = sourceType;
    }
    if (sourceReference != null) {
      payload['sourceReference'] = sourceReference;
    }
    final response = await _functions
        .httpsCallable('transitionContentQaState')
        .call<Map<String, dynamic>>(payload);
    return ContentQaTransitionResult.fromMap(response.data);
  }

  Future<ContentQaTransitionResult> changeStatus({
    required String documentPath,
    required String status,
  }) {
    final targetState = status == 'draft' ? 'draft' : status;
    return transition(documentPath: documentPath, targetState: targetState);
  }

  Future<Map<String, dynamic>?> inspectCredential(String code) async {
    final response = await _functions
        .httpsCallable('verifyCertificate')
        .call<Map<String, dynamic>>({'verificationCode': code});
    if (response.data['found'] != true ||
        response.data['certificate'] is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(response.data['certificate'] as Map);
  }

  Future<String> updateCredentialStatus({
    required String verificationCode,
    required String status,
    required String reason,
  }) async {
    final response = await _functions
        .httpsCallable('updateCertificateStatus')
        .call<Map<String, dynamic>>({
          'verificationCode': verificationCode,
          'status': status,
          'reason': reason,
        });
    return (response.data['status'] ?? 'unknown').toString();
  }
}

class ContentQaDashboardData {
  const ContentQaDashboardData({required this.counts, required this.items});

  final Map<String, int> counts;
  final List<ContentQaItem> items;

  factory ContentQaDashboardData.fromMap(Map<String, dynamic> data) {
    final rawCounts = data['counts'] is Map
        ? Map<String, dynamic>.from(data['counts'] as Map)
        : const <String, dynamic>{};
    final rawItems = data['items'] is List ? data['items'] as List : const [];
    return ContentQaDashboardData(
      counts: rawCounts.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      items: rawItems
          .whereType<Map>()
          .map((item) => ContentQaItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class ContentQaItem {
  const ContentQaItem({
    required this.documentPath,
    required this.title,
    required this.state,
    required this.validationStatus,
    required this.sourceType,
    required this.missingProvenance,
    required this.legacy,
  });

  final String documentPath;
  final String title;
  final String state;
  final String validationStatus;
  final String sourceType;
  final bool missingProvenance;
  final bool legacy;

  String? get nextState => switch (state) {
    'draft' => 'validation_passed',
    'validation_passed' => 'approved',
    'approved' => 'published',
    _ => null,
  };

  factory ContentQaItem.fromMap(Map<String, dynamic> data) {
    return ContentQaItem(
      documentPath: (data['documentPath'] ?? '').toString(),
      title: (data['title'] ?? 'Untitled content').toString(),
      state: (data['state'] ?? 'draft').toString(),
      validationStatus: (data['validationStatus'] ?? '').toString(),
      sourceType: (data['sourceType'] ?? '').toString(),
      missingProvenance: data['missingProvenance'] == true,
      legacy: data['legacy'] == true,
    );
  }
}

class ContentQaTransitionResult {
  const ContentQaTransitionResult({
    required this.success,
    required this.state,
    required this.errors,
  });

  final bool success;
  final String state;
  final List<String> errors;

  factory ContentQaTransitionResult.fromMap(Map<String, dynamic> data) {
    return ContentQaTransitionResult(
      success: data['success'] == true,
      state: (data['state'] ?? '').toString(),
      errors: data['errors'] is List
          ? (data['errors'] as List).map((value) => value.toString()).toList()
          : const [],
    );
  }
}
