class IeltsScoring {
  IeltsScoring._();

  static const scoringVersion = 'estimated_ielts_v3_2026_08';
  static const objectiveConversionVersion = 'practice_raw40_v2_2026_08';

  static double roundOverall(double value) {
    final safe = value.clamp(0, 9).toDouble();
    final whole = safe.floor();
    final fraction = safe - whole;
    if (fraction < .25) return whole.toDouble();
    if (fraction < .75) return (whole + .5).clamp(0, 9).toDouble();
    return (whole + 1).clamp(0, 9).toDouble();
  }

  static String normalizeTrack(String value) {
    return value.toLowerCase().contains('general')
        ? 'general_training'
        : 'academic';
  }

  static ObjectiveScoreConversion convertObjective({
    required String skill,
    required String track,
    required int rawScore,
    required int maximumScore,
  }) {
    if (maximumScore <= 0 || rawScore < 0 || rawScore > maximumScore) {
      throw RangeError('Raw score must be between zero and maximum score.');
    }
    final normalizedRawScore = ((rawScore / maximumScore) * 40).round().clamp(
      0,
      40,
    );
    final normalizedTrack = normalizeTrack(track);
    final table = skill.toLowerCase() == 'listening'
        ? _listening
        : normalizedTrack == 'general_training'
        ? _readingGeneral
        : _readingAcademic;
    final band = table.firstWhere((entry) => normalizedRawScore >= entry.$1).$2;
    return ObjectiveScoreConversion(
      ieltsTrack: normalizedTrack,
      rawScore: rawScore,
      maximumScore: maximumScore,
      normalizedRawScore: normalizedRawScore,
      estimatedBand: band,
      conversionTableVersion: objectiveConversionVersion,
    );
  }

  static const _listening = <(int, double)>[
    (39, 9),
    (37, 8.5),
    (35, 8),
    (32, 7.5),
    (30, 7),
    (26, 6.5),
    (23, 6),
    (18, 5.5),
    (16, 5),
    (13, 4.5),
    (11, 4),
    (8, 3.5),
    (6, 3),
    (4, 2.5),
    (0, 0),
  ];

  static const _readingAcademic = <(int, double)>[
    (39, 9),
    (37, 8.5),
    (35, 8),
    (33, 7.5),
    (30, 7),
    (27, 6.5),
    (23, 6),
    (19, 5.5),
    (15, 5),
    (13, 4.5),
    (10, 4),
    (8, 3.5),
    (6, 3),
    (4, 2.5),
    (0, 0),
  ];

  static const _readingGeneral = <(int, double)>[
    (40, 9),
    (39, 8.5),
    (37, 8),
    (36, 7.5),
    (34, 7),
    (32, 6.5),
    (30, 6),
    (27, 5.5),
    (23, 5),
    (19, 4.5),
    (15, 4),
    (12, 3.5),
    (9, 3),
    (6, 2.5),
    (0, 0),
  ];
}

class ObjectiveScoreConversion {
  const ObjectiveScoreConversion({
    required this.ieltsTrack,
    required this.rawScore,
    required this.maximumScore,
    required this.normalizedRawScore,
    required this.estimatedBand,
    required this.conversionTableVersion,
  });

  final String ieltsTrack;
  final int rawScore;
  final int maximumScore;
  final int normalizedRawScore;
  final double estimatedBand;
  final String conversionTableVersion;

  Map<String, dynamic> toMap() => {
    'ieltsTrack': ieltsTrack,
    'rawScore': rawScore,
    'maximumScore': maximumScore,
    'normalizedRawScore': normalizedRawScore,
    'estimatedBand': estimatedBand,
    'conversionTableVersion': conversionTableVersion,
  };
}
