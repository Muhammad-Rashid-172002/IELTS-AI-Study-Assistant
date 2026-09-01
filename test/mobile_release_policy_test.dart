import 'package:flutter_test/flutter_test.dart';
import 'package:fyproject/services/mobile_release_policy.dart';

void main() {
  test('release policy safely parses server-controlled minimum versions', () {
    final policy = MobileReleasePolicy.fromMap({
      'updateRequired': true,
      'minimumBuildNumber': '15',
      'minimumVersion': '1.3.0',
      'message': 'Update required',
      'storeUrl': 'https://example.test/store',
      'policyVersion': 'mobile_release_v1_2026_08',
    });

    expect(policy.updateRequired, isTrue);
    expect(policy.minimumBuildNumber, 15);
    expect(policy.minimumVersion, '1.3.0');
    expect(policy.policyVersion, 'mobile_release_v1_2026_08');
  });

  test('release policy defaults malformed numeric data to zero', () {
    final policy = MobileReleasePolicy.fromMap({
      'minimumBuildNumber': 'not-a-number',
    });
    expect(policy.updateRequired, isFalse);
    expect(policy.minimumBuildNumber, 0);
  });
}
