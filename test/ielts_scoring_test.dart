import 'package:flutter_test/flutter_test.dart';
import 'package:fyproject/services/ielts_scoring.dart';

void main() {
  test('overall rounding handles quarter and three-quarter boundaries', () {
    expect(IeltsScoring.roundOverall(6.24), 6);
    expect(IeltsScoring.roundOverall(6.25), 6.5);
    expect(IeltsScoring.roundOverall(6.74), 6.5);
    expect(IeltsScoring.roundOverall(6.75), 7);
  });

  test('Academic and General Training Reading conversions differ', () {
    final academic = IeltsScoring.convertObjective(
      skill: 'reading',
      track: 'Academic',
      rawScore: 30,
      maximumScore: 40,
    );
    final general = IeltsScoring.convertObjective(
      skill: 'reading',
      track: 'General Training',
      rawScore: 30,
      maximumScore: 40,
    );
    expect(academic.estimatedBand, 7);
    expect(general.estimatedBand, 6);
    expect(general.ieltsTrack, 'general_training');
  });

  test('short objective tests retain raw/max and normalize to 40', () {
    final result = IeltsScoring.convertObjective(
      skill: 'listening',
      track: 'academic',
      rawScore: 8,
      maximumScore: 10,
    );
    expect(result.rawScore, 8);
    expect(result.maximumScore, 10);
    expect(result.normalizedRawScore, 32);
    expect(result.estimatedBand, 7.5);
    expect(result.conversionTableVersion, isNotEmpty);
  });
}
