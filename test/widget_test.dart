import 'package:flutter_test/flutter_test.dart';
import 'package:fyproject/models/mock_test_models.dart';

void main() {
  test('full mock configuration includes all IELTS skills and durations', () {
    final config = MockTestConfig(
      track: MockTrack.academic,
      scope: MockScope.fullMock,
      mode: MockMode.computerDelivered,
      singleSkill: null,
      difficulty: 'Adaptive',
      testDate: DateTime(2026, 8, 22),
      targetBand: 7,
    );

    expect(config.skills, MockSkill.values);
    expect(config.totalDurationMinutes, 164);
    expect(config.toMap()['track'], 'academic');
  });
}
