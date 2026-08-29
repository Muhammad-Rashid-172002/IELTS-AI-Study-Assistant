import 'package:flutter_test/flutter_test.dart';
import 'package:fyproject/models/mock_test_models.dart';

void main() {
  MockFinalResult result({
    bool complete = true,
    bool attested = true,
    List<String> completed = const [
      'listening',
      'reading',
      'writing',
      'speaking',
    ],
  }) {
    return MockFinalResult(
      attemptId: 'attempt',
      overallBand: 7,
      targetBand: 7,
      targetGap: 0,
      skillResults: const [],
      strengths: const [],
      weaknesses: const [],
      suggestedNextMockDate: DateTime(2026),
      sevenDayPlan: const [],
      isComplete: complete,
      serverAttested: attested,
      completedSkills: completed,
    );
  }

  test('certificate eligibility requires attested four-skill completion', () {
    expect(result().certificateEligible, isTrue);
    expect(result(attested: false).certificateEligible, isFalse);
    expect(
      result(
        completed: const ['listening', 'reading', 'writing'],
      ).certificateEligible,
      isFalse,
    );
  });

  test('legacy defaults remain visible but certificate-ineligible', () {
    final legacy = MockFinalResult(
      attemptId: 'legacy',
      overallBand: 8,
      targetBand: 7,
      targetGap: 0,
      skillResults: const [],
      strengths: const [],
      weaknesses: const [],
      suggestedNextMockDate: DateTime(2026),
      sevenDayPlan: const [],
    );
    expect(legacy.scoringVersion, 'legacy_unattested');
    expect(legacy.certificateEligible, isFalse);
  });
}
