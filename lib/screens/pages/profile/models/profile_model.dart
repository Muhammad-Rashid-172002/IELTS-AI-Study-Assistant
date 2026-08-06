import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileModel {
  final String uid, name, email, photoUrl, ieltsType, educationLevel;
  final String subscription, language, appearance, reminderTime;
  final double targetBand, estimatedBand;
  final DateTime? examDate, subscriptionExpiry;
  final bool isPremium, notificationsEnabled, dailyReminderEnabled;
  final int savedTests, savedWords, certificates, completedLessons;
  final int completedMocks, streak, longestStreak;
  final Map<String, double> skillBands;

  const ProfileModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.ieltsType,
    required this.educationLevel,
    required this.subscription,
    required this.language,
    required this.appearance,
    required this.reminderTime,
    required this.targetBand,
    required this.estimatedBand,
    required this.examDate,
    required this.subscriptionExpiry,
    required this.isPremium,
    required this.notificationsEnabled,
    required this.dailyReminderEnabled,
    required this.savedTests,
    required this.savedWords,
    required this.certificates,
    required this.completedLessons,
    required this.completedMocks,
    required this.streak,
    required this.longestStreak,
    required this.skillBands,
  });

  factory ProfileModel.fromMap({
    required String uid,
    required String email,
    required Map<String, dynamic> data,
    required Map<String, int> counts,
    required Map<String, double> skillBands,
  }) {
    DateTime? date(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    double number(dynamic v, [double fallback = 0]) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? fallback;
    }

    int integer(dynamic v) {
      if (v is num) return v.round();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return ProfileModel(
      uid: uid,
      name: (data['name'] ?? data['fullName'] ?? 'IELTS Learner').toString(),
      email: (data['email'] ?? email).toString(),
      photoUrl: (data['photoUrl'] ?? '').toString(),
      ieltsType: (data['ieltsType'] ?? 'Academic').toString(),
      educationLevel: (data['educationLevel'] ?? 'University').toString(),
      subscription: (data['subscriptionPlan'] ?? data['plan'] ?? 'Free')
          .toString(),
      language: (data['language'] ?? 'English').toString(),
      appearance: (data['appearance'] ?? 'System').toString(),
      reminderTime: (data['reminderTime'] ?? '19:00').toString(),
      targetBand: number(data['targetBand'], 7),
      estimatedBand: number(
        data['estimatedBand'] ?? data['overallBand'] ?? data['currentBand'],
        _averageBand(skillBands),
      ),
      examDate: date(data['examDate']),
      subscriptionExpiry: date(
        data['subscriptionExpiry'] ?? data['premiumExpiry'],
      ),
      isPremium: data['isPremium'] == true || data['premium'] == true,
      notificationsEnabled: data['notificationsEnabled'] != false,
      dailyReminderEnabled: data['dailyReminderEnabled'] != false,
      savedTests: counts['savedTests'] ?? 0,
      savedWords: counts['savedWords'] ?? 0,
      certificates: counts['certificates'] ?? 0,
      completedLessons: counts['completedLessons'] ?? 0,
      completedMocks: counts['completedMocks'] ?? 0,
      streak: integer(data['streak']),
      longestStreak: integer(data['longestStreak']),
      skillBands: skillBands,
    );
  }

  static double _averageBand(Map<String, double> values) {
    final valid = values.values.where((value) => value > 0).toList();
    if (valid.isEmpty) return 0;
    return valid.reduce((a, b) => a + b) / valid.length;
  }
}
