import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MobileReleasePolicy {
  const MobileReleasePolicy({
    required this.updateRequired,
    required this.minimumBuildNumber,
    required this.minimumVersion,
    required this.message,
    required this.storeUrl,
    required this.policyVersion,
  });

  final bool updateRequired;
  final int minimumBuildNumber;
  final String minimumVersion;
  final String message;
  final String storeUrl;
  final String policyVersion;

  factory MobileReleasePolicy.fromMap(Map<String, dynamic> data) {
    return MobileReleasePolicy(
      updateRequired: data['updateRequired'] == true,
      minimumBuildNumber: _integer(data['minimumBuildNumber']),
      minimumVersion: (data['minimumVersion'] ?? '').toString().trim(),
      message: (data['message'] ?? '').toString().trim(),
      storeUrl: (data['storeUrl'] ?? '').toString().trim(),
      policyVersion: (data['policyVersion'] ?? '').toString().trim(),
    );
  }

  static const current = MobileReleasePolicy(
    updateRequired: false,
    minimumBuildNumber: 0,
    minimumVersion: '',
    message: '',
    storeUrl: '',
    policyVersion: 'unavailable',
  );
}

class MobileReleasePolicyService {
  MobileReleasePolicyService({
    FirebaseFunctions? functions,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  final FirebaseFunctions _functions;
  final Future<PackageInfo> Function() _packageInfoLoader;

  Future<MobileReleasePolicy> check() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return MobileReleasePolicy.current;
    }
    final platform = defaultTargetPlatform == TargetPlatform.android
        ? 'android'
        : 'ios';
    final info = await _packageInfoLoader();
    final buildNumber = int.tryParse(info.buildNumber) ?? 0;
    final response = await _functions
        .httpsCallable('getMobileReleasePolicy')
        .call({
          'platform': platform,
          'version': info.version,
          'buildNumber': buildNumber,
        });
    final data = Map<String, dynamic>.from(response.data as Map);
    return MobileReleasePolicy.fromMap(data);
  }
}

int _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
