class SharedDataContract {
  SharedDataContract._();

  static const schemaVersion = 2;

  static String learnerName(Map<String, dynamic> data) =>
      _text(data['fullName'] ?? data['name']);

  static String phone(Map<String, dynamic> data) =>
      _text(data['phoneNumber'] ?? data['phone']);

  static String photoUrl(Map<String, dynamic> data) =>
      _text(data['photoUrl'] ?? data['profileImage']);

  static double targetBand(Map<String, dynamic> data, {double fallback = 0}) {
    final targetBands = data['targetBands'] is Map
        ? Map<String, dynamic>.from(data['targetBands'] as Map)
        : const <String, dynamic>{};
    return _number(targetBands['overall'] ?? data['targetBand'], fallback);
  }

  static double writingTaskCriterion(Map<String, dynamic> data) =>
      _number(data['taskResponse'] ?? data['taskAchievement'], 0);

  static double speakingGrammar(Map<String, dynamic> data) => _number(
    data['grammaticalRangeAndAccuracy'] ??
        data['grammarAccuracy'] ??
        data['grammarBand'],
    0,
  );

  static const diagnosticResultCollections = <String>[
    'diagnostic_results',
    'diagnosticResults',
  ];

  static const speakingResultCollections = <String>[
    'speaking_results',
    'speaking',
  ];

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static double _number(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
