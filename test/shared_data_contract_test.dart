import 'package:flutter_test/flutter_test.dart';
import 'package:fyproject/models/shared_data_contract.dart';

void main() {
  test('legacy profile aliases remain readable', () {
    final data = {
      'name': 'Legacy Learner',
      'phone': '+92',
      'profileImage': 'https://example.test/photo.png',
      'targetBands': {'overall': 7.5},
    };
    expect(SharedDataContract.learnerName(data), 'Legacy Learner');
    expect(SharedDataContract.phone(data), '+92');
    expect(SharedDataContract.photoUrl(data), 'https://example.test/photo.png');
    expect(SharedDataContract.targetBand(data), 7.5);
  });

  test('criterion and Speaking grammar aliases dual-read legacy fields', () {
    expect(
      SharedDataContract.writingTaskCriterion({'taskAchievement': 6.5}),
      6.5,
    );
    expect(SharedDataContract.speakingGrammar({'grammarBand': 7}), 7);
    expect(
      SharedDataContract.diagnosticResultCollections,
      containsAll(['diagnostic_results', 'diagnosticResults']),
    );
    expect(
      SharedDataContract.speakingResultCollections,
      containsAll(['speaking_results', 'speaking']),
    );
  });
}
