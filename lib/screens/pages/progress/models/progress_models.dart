import 'package:cloud_firestore/cloud_firestore.dart';

enum ProgressPeriod { week, month, all }

extension ProgressPeriodX on ProgressPeriod {
  String get label => switch (this) {
        ProgressPeriod.week => '7 Days',
        ProgressPeriod.month => '30 Days',
        ProgressPeriod.all => 'All Time',
      };

  DateTime? get startDate {
    final now = DateTime.now();

    return switch (this) {
      ProgressPeriod.week => now.subtract(const Duration(days: 7)),
      ProgressPeriod.month => now.subtract(const Duration(days: 30)),
      ProgressPeriod.all => null,
    };
  }
}

class SkillBandPoint {
  final DateTime date;
  final double band;

  const SkillBandPoint({
    required this.date,
    required this.band,
  });
}

class SkillProgress {
  final String skill;
  final double band;
  final double previousBand;
  final int attempts;
  final double accuracy;
  final int timeSpentMinutes;
  final Map<String, double> questionTypeAccuracy;
  final List<SkillBandPoint> trend;
  final Map<String, dynamic> details;

  const SkillProgress({
    required this.skill,
    required this.band,
    required this.previousBand,
    required this.attempts,
    required this.accuracy,
    required this.timeSpentMinutes,
    required this.questionTypeAccuracy,
    required this.trend,
    required this.details,
  });

  double get change => band - previousBand;
}

class ProgressOverview {
  final double overallBand;
  final double targetBand;
  final double examReadiness;
  final int weeklyStudyMinutes;
  final int completedLessons;
  final int completedMocks;
  final int currentStreak;
  final int longestStreak;
  final Map<String, SkillProgress> skills;
  final DateTime? updatedAt;

  const ProgressOverview({
    required this.overallBand,
    required this.targetBand,
    required this.examReadiness,
    required this.weeklyStudyMinutes,
    required this.completedLessons,
    required this.completedMocks,
    required this.currentStreak,
    required this.longestStreak,
    required this.skills,
    required this.updatedAt,
  });

  factory ProgressOverview.empty() {
    return const ProgressOverview(
      overallBand: 0,
      targetBand: 7,
      examReadiness: 0,
      weeklyStudyMinutes: 0,
      completedLessons: 0,
      completedMocks: 0,
      currentStreak: 0,
      longestStreak: 0,
      skills: {},
      updatedAt: null,
    );
  }
}

class ProgressReport {
  final String title;
  final String subtitle;
  final DateTime from;
  final DateTime to;
  final double overallBand;
  final double targetBand;
  final double readiness;
  final int studyMinutes;
  final int attempts;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> recommendations;
  final Map<String, double> skillBands;

  const ProgressReport({
    required this.title,
    required this.subtitle,
    required this.from,
    required this.to,
    required this.overallBand,
    required this.targetBand,
    required this.readiness,
    required this.studyMinutes,
    required this.attempts,
    required this.strengths,
    required this.weaknesses,
    required this.recommendations,
    required this.skillBands,
  });
}

class ProgressDocument {
  final String id;
  final Map<String, dynamic> data;
  final DateTime date;

  const ProgressDocument({
    required this.id,
    required this.data,
    required this.date,
  });

  factory ProgressDocument.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return ProgressDocument(
      id: doc.id,
      data: data,
      date: _readDate(data),
    );
  }

  static DateTime _readDate(Map<String, dynamic> data) {
    for (final key in [
      'timestamp',
      'createdAt',
      'completedAt',
      'startedAt',
      'updatedAt',
      'date',
    ]) {
      final value = data[key];

      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;

      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }

    return DateTime.now();
  }
}
