import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/progress_models.dart';

class ProgressRepository {
  ProgressRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User is not signed in.');
    }
    return user.uid;
  }

  Stream<ProgressOverview> watchOverview({
    ProgressPeriod period = ProgressPeriod.all,
  }) {
    return _firestore.collection('users').doc(_uid).snapshots().asyncMap((
      userDoc,
    ) async {
      final userData = userDoc.data() ?? const <String, dynamic>{};

      final results = await Future.wait([
        _loadSkill(
          collection: 'listening_results',
          skill: 'Listening',
          period: period,
        ),
        _loadSkill(
          collection: 'reading_results',
          skill: 'Reading',
          period: period,
        ),
        _loadSkill(
          collection: 'writing_results',
          skill: 'Writing',
          period: period,
        ),
        _loadSkill(
          collection: 'speaking_results',
          skill: 'Speaking',
          period: period,
        ),
        _loadCompletedLessons(period),
        _loadCompletedMocks(period),
        _loadWeeklyStudyMinutes(),
      ]);

      final listening = results[0] as SkillProgress;
      final reading = results[1] as SkillProgress;
      final writing = results[2] as SkillProgress;
      final speaking = results[3] as SkillProgress;
      final completedLessons = results[4] as int;
      final completedMocks = results[5] as int;
      final weeklyStudyMinutes = results[6] as int;

      final skills = {
        'Listening': listening,
        'Reading': reading,
        'Writing': writing,
        'Speaking': speaking,
      };

      // Show a provisional estimated band from the skills the learner has
      // actually completed. The dashboard clearly labels this as incomplete
      // until all four IELTS skills have been attempted.
      final attemptedSkills = skills.values
          .where(
            (skill) => skill.attempts > 0 && skill.band > 0 && skill.band <= 9,
          )
          .toList();

      final overallBand = attemptedSkills.isEmpty
          ? 0.0
          : _roundBand(
              attemptedSkills
                      .map((skill) => skill.band)
                      .reduce((a, b) => a + b) /
                  attemptedSkills.length,
            );

      // Registration/onboarding may store the selected overall target inside
      // targetBands.overall, while newer profile screens use targetBand.
      // Prefer the onboarding value first so Home, Progress and Profile show
      // the same real target selected by the user.
      final targetBands = _map(userData['targetBands']);
      final targetBand = _double(
        targetBands['overall'] ?? userData['targetBand'],
        7,
      ).clamp(0.5, 9.0).toDouble();
      final readiness = _calculateReadiness(
        overallBand: overallBand,
        targetBand: targetBand,
        skills: skills,
        completedMocks: completedMocks,
        weeklyStudyMinutes: weeklyStudyMinutes,
      );

      return ProgressOverview(
        overallBand: overallBand,
        targetBand: targetBand,
        examReadiness: readiness,
        weeklyStudyMinutes: weeklyStudyMinutes,
        completedLessons: completedLessons,
        completedMocks: completedMocks,
        currentStreak: _int(userData['streak']),
        longestStreak: _int(userData['longestStreak']),
        skills: skills,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<SkillProgress> _loadSkill({
    required String collection,
    required String skill,
    required ProgressPeriod period,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection(collection)
        .limit(200)
        .get();

    final start = period.startDate;

    final documents =
        snapshot.docs
            .map(ProgressDocument.fromDocument)
            .where((doc) => start == null || !doc.date.isBefore(start))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final bandValues = documents
        .map((doc) => _extractBand(doc.data))
        .where((value) => value > 0)
        .toList();

    final currentBand = bandValues.isEmpty ? 0.0 : _roundBand(bandValues.last);

    final previousBand = bandValues.length < 2
        ? currentBand
        : _roundBand(bandValues[bandValues.length - 2]);

    final rawScores = documents
        .map((doc) => _extractScore(doc.data))
        .where((score) => score.$2 > 0)
        .toList();

    final totalCorrect = rawScores.fold<int>(0, (sum, item) => sum + item.$1);
    final totalQuestions = rawScores.fold<int>(0, (sum, item) => sum + item.$2);

    final accuracy = totalQuestions == 0
        ? 0.0
        : totalCorrect / totalQuestions * 100;

    final questionTypeStats = <String, List<double>>{};

    for (final doc in documents) {
      final performance =
          doc.data['questionTypePerformance'] ??
          doc.data['questionTypeAccuracy'] ??
          doc.data['typePerformance'];

      if (performance is Map) {
        for (final entry in performance.entries) {
          final raw = entry.value;
          final value = raw is Map
              ? _double(raw['accuracy'] ?? raw['percentage'] ?? raw['score'])
              : _double(raw);

          questionTypeStats
              .putIfAbsent(entry.key.toString(), () => [])
              .add(value);
        }
      }
    }

    final questionTypeAccuracy = questionTypeStats.map(
      (key, values) => MapEntry(
        key,
        values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length,
      ),
    );

    final trend = documents
        .map(
          (doc) => SkillBandPoint(date: doc.date, band: _extractBand(doc.data)),
        )
        .where((point) => point.band > 0)
        .toList();

    return SkillProgress(
      skill: skill,
      band: currentBand,
      previousBand: previousBand,
      attempts: documents.length,
      accuracy: accuracy,
      timeSpentMinutes: documents.fold<int>(
        0,
        (sum, doc) =>
            sum +
            _secondsToMinutes(
              doc.data['timeSpentSeconds'] ??
                  doc.data['durationSeconds'] ??
                  doc.data['timeSpent'],
            ),
      ),
      questionTypeAccuracy: Map<String, double>.from(questionTypeAccuracy),
      trend: trend,
      details: _buildSkillDetails(skill, documents),
    );
  }

  Map<String, dynamic> _buildSkillDetails(
    String skill,
    List<ProgressDocument> documents,
  ) {
    if (skill == 'Listening') {
      return {
        'sectionPerformance': _averageMap(documents, const [
          'sectionPerformance',
          'sectionScores',
        ]),
        'spellingIssues': documents.fold<int>(
          0,
          (sum, doc) =>
              sum +
              _int(doc.data['spellingIssues'] ?? doc.data['spellingErrors']),
        ),
        'accentPerformance': _averageMap(documents, const [
          'accentPerformance',
          'accentScores',
        ]),
      };
    }

    if (skill == 'Reading') {
      return {
        'passagePerformance': _averageMap(documents, const [
          'passagePerformance',
          'passageScores',
        ]),
        'readingSpeed': _averageValue(documents, const [
          'readingSpeed',
          'wordsPerMinute',
        ]),
        'timeManagement': _averageValue(documents, const [
          'timeManagement',
          'timeManagementScore',
        ]),
      };
    }

    if (skill == 'Writing') {
      return {
        'criteria': _averageMap(documents, const [
          'criteria',
          'criterionScores',
          'feedback',
        ]),
        'grammarErrors': _sumMap(documents, const [
          'grammarErrorCategories',
          'grammarErrors',
        ]),
        'vocabularyGrowth': _averageValue(documents, const [
          'vocabularyScore',
          'lexicalResource',
        ]),
      };
    }

    return {
      'criteria': _averageMap(documents, const [
        'criteria',
        'criterionScores',
        'feedback',
      ]),
      'fluency': _averageValue(documents, const [
        'fluency',
        'fluencyAndCoherence',
      ]),
      'pronunciation': _averageValue(documents, const ['pronunciation']),
      'grammar': _averageValue(documents, const [
        'grammar',
        'grammaticalRangeAndAccuracy',
      ]),
      'vocabulary': _averageValue(documents, const [
        'vocabulary',
        'lexicalResource',
      ]),
    };
  }

  Future<int> _loadCompletedLessons(ProgressPeriod period) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('lesson_progress')
        .where('completed', isEqualTo: true)
        .get();

    final start = period.startDate;

    if (start == null) return snapshot.size;

    return snapshot.docs.where((doc) {
      final progress = ProgressDocument.fromDocument(doc);
      return !progress.date.isBefore(start);
    }).length;
  }

  Future<int> _loadCompletedMocks(ProgressPeriod period) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('mock_attempts')
        .where('status', isEqualTo: 'completed')
        .get();

    final start = period.startDate;

    if (start == null) return snapshot.size;

    return snapshot.docs.where((doc) {
      final progress = ProgressDocument.fromDocument(doc);
      return !progress.date.isBefore(start);
    }).length;
  }

  Future<int> _loadWeeklyStudyMinutes() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    final snapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('study_sessions')
        .get();

    return snapshot.docs.fold<int>(0, (sum, doc) {
      final progress = ProgressDocument.fromDocument(doc);

      if (progress.date.isBefore(sevenDaysAgo)) return sum;

      return sum +
          _secondsToMinutes(
            progress.data['durationSeconds'] ??
                progress.data['timeSpentSeconds'] ??
                progress.data['minutes'],
          );
    });
  }

  Future<ProgressReport> buildReport({required ProgressPeriod period}) async {
    final overview = await watchOverview(period: period).first;
    final now = DateTime.now();
    final from = period.startDate ?? now.subtract(const Duration(days: 365));

    final ordered = overview.skills.values.toList()
      ..sort((a, b) => b.band.compareTo(a.band));

    final strengths = <String>[];
    final weaknesses = <String>[];
    final recommendations = <String>[];

    for (final skill in ordered) {
      final attempted = skill.attempts > 0 && skill.band > 0;

      if (!attempted) {
        weaknesses.add('${skill.skill} has not been attempted yet.');
        recommendations.add(
          'Complete the ${skill.skill} assessment to calculate your '
          'overall IELTS band.',
        );
        continue;
      }

      if (skill.band >= overview.targetBand) {
        strengths.add('${skill.skill} is at or above the target band.');
      } else {
        weaknesses.add(
          '${skill.skill} is '
          '${(overview.targetBand - skill.band).toStringAsFixed(1)} '
          'band below target.',
        );
      }

      if (skill.accuracy > 0 && skill.accuracy < 70) {
        recommendations.add(
          'Complete targeted ${skill.skill} question-type practice.',
        );
      }

      if (skill.change < 0) {
        recommendations.add(
          'Review recent ${skill.skill} mistakes before the next test.',
        );
      }
    }

    if (overview.weeklyStudyMinutes < 180) {
      recommendations.add('Increase weekly study time to at least 3 hours.');
    }

    if (overview.completedMocks == 0) {
      recommendations.add(
        'Complete one full mock test to improve readiness accuracy.',
      );
    }

    return ProgressReport(
      title: switch (period) {
        ProgressPeriod.week => 'Weekly Progress Report',
        ProgressPeriod.month => 'Monthly Progress Report',
        ProgressPeriod.all => 'Target Readiness Report',
      },
      subtitle: '${_formatDate(from)} – ${_formatDate(now)}',
      from: from,
      to: now,
      overallBand: overview.overallBand,
      targetBand: overview.targetBand,
      readiness: overview.examReadiness,
      studyMinutes: overview.weeklyStudyMinutes,
      attempts: overview.skills.values.fold<int>(
        0,
        (sum, skill) => sum + skill.attempts,
      ),
      strengths: strengths.isEmpty
          ? const ['Complete more practice to identify strengths.']
          : strengths,
      weaknesses: weaknesses.isEmpty
          ? const ['No major weakness detected in current data.']
          : weaknesses,
      recommendations: recommendations.isEmpty
          ? const ['Maintain consistency and complete one mock test weekly.']
          : recommendations.toSet().toList(),
      skillBands: overview.skills.map(
        (key, value) => MapEntry(key, value.band),
      ),
    );
  }

  double _calculateReadiness({
    required double overallBand,
    required double targetBand,
    required Map<String, SkillProgress> skills,
    required int completedMocks,
    required int weeklyStudyMinutes,
  }) {
    final completedSkillCount = skills.values
        .where(
          (skill) => skill.attempts > 0 && skill.band > 0 && skill.band <= 9,
        )
        .length;

    if (completedSkillCount == 0 || overallBand <= 0) return 0;

    // A provisional readiness score is allowed, but it is weighted by how
    // many IELTS skills are complete so partial data cannot look final.
    final completionRatio = completedSkillCount / 4;

    final bandComponent =
        (overallBand / math.max(targetBand, 1) * 60 * completionRatio)
            .clamp(0, 60)
            .toDouble();

    final consistencyComponent = (completedSkillCount / 4 * 15)
        .clamp(0, 15)
        .toDouble();

    final mockComponent = (completedMocks * 5).clamp(0, 15).toDouble();

    final studyComponent = (weeklyStudyMinutes / 300 * 10)
        .clamp(0, 10)
        .toDouble();

    return (bandComponent +
            consistencyComponent +
            mockComponent +
            studyComponent)
        .clamp(0, 100);
  }

  Map<String, double> _averageMap(
    List<ProgressDocument> documents,
    List<String> keys,
  ) {
    final values = <String, List<double>>{};

    for (final doc in documents) {
      dynamic map;

      for (final key in keys) {
        if (doc.data[key] is Map) {
          map = doc.data[key];
          break;
        }
      }

      if (map is! Map) continue;

      for (final entry in map.entries) {
        final raw = entry.value;
        final value = raw is Map
            ? _double(
                raw['band'] ?? raw['score'] ?? raw['accuracy'] ?? raw['value'],
              )
            : _double(raw);

        values.putIfAbsent(entry.key.toString(), () => []).add(value);
      }
    }

    return values.map(
      (key, list) => MapEntry(
        key,
        list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length,
      ),
    );
  }

  Map<String, double> _sumMap(
    List<ProgressDocument> documents,
    List<String> keys,
  ) {
    final values = <String, double>{};

    for (final doc in documents) {
      dynamic map;

      for (final key in keys) {
        if (doc.data[key] is Map) {
          map = doc.data[key];
          break;
        }
      }

      if (map is! Map) continue;

      for (final entry in map.entries) {
        values.update(
          entry.key.toString(),
          (current) => current + _double(entry.value),
          ifAbsent: () => _double(entry.value),
        );
      }
    }

    return values;
  }

  double _averageValue(List<ProgressDocument> documents, List<String> keys) {
    final values = <double>[];

    for (final doc in documents) {
      for (final key in keys) {
        final value = _double(doc.data[key]);

        if (value > 0) {
          values.add(value);
          break;
        }

        final feedback = doc.data['feedback'];
        if (feedback is Map) {
          final nested = _double(feedback[key]);

          if (nested > 0) {
            values.add(nested);
            break;
          }
        }
      }
    }

    return values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
  }

  double _extractBand(Map<String, dynamic> data) {
    final direct = _double(
      data['band'] ??
          data['overallBand'] ??
          data['estimatedBand'] ??
          data['scoreBand'],
    );

    if (direct > 0) return direct;

    final result = data['result'];
    if (result is Map) {
      return _double(
        result['overallBand'] ?? result['band'] ?? result['estimatedBand'],
      );
    }

    return 0;
  }

  (int, int) _extractScore(Map<String, dynamic> data) {
    final correct = _int(
      data['score'] ?? data['correctAnswers'] ?? data['rawScore'],
    );

    final total = _int(
      data['total'] ?? data['totalQuestions'] ?? data['totalMarks'],
    );

    return (correct, total);
  }

  static int _secondsToMinutes(dynamic value) {
    if (value is num) {
      if (value <= 600) return value.round();
      return (value / 60).round();
    }

    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null) return 0;

    if (parsed <= 600) return parsed.round();
    return (parsed / 60).round();
  }

  static int _int(dynamic value, [int fallback = 0]) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const <String, dynamic>{};
  }

  static double _double(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _roundBand(double value) {
    return (value * 2).round() / 2;
  }

  static String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}
