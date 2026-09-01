import 'dart:convert';
import 'dart:io';

void main() {
  const expectedProject = 'ielts-ai-study-assistant';
  const expectedAndroidPackage = 'com.rashidapps.ieltsaimaster';
  const expectedIosBundle = 'com.rashidapps.ieltsaimaster';
  final issues = <String>[];

  final android =
      jsonDecode(File('android/app/google-services.json').readAsStringSync())
          as Map<String, dynamic>;
  final project = Map<String, dynamic>.from(android['project_info'] as Map);
  if (project['project_id'] != expectedProject) {
    issues.add('Android Firebase project ID does not match $expectedProject.');
  }
  final clients = (android['client'] as List).cast<Map>();
  final matchingAndroidClient = clients.where((client) {
    final info = Map<String, dynamic>.from(client['client_info'] as Map);
    final details = Map<String, dynamic>.from(
      info['android_client_info'] as Map,
    );
    return details['package_name'] == expectedAndroidPackage;
  }).toList();
  if (matchingAndroidClient.length != 1) {
    issues.add(
      'google-services.json must contain exactly one client for '
      '$expectedAndroidPackage.',
    );
  }

  final plist = File('ios/Runner/GoogleService-Info.plist').readAsStringSync();
  final plistBundle = _plistValue(plist, 'BUNDLE_ID');
  final plistProject = _plistValue(plist, 'PROJECT_ID');
  if (plistProject != expectedProject) {
    issues.add('iOS Firebase project ID does not match $expectedProject.');
  }
  if (plistBundle != expectedIosBundle) {
    issues.add(
      'GoogleService-Info.plist is registered for "$plistBundle", not '
      'the release bundle "$expectedIosBundle". Download the verified plist '
      'from Firebase Console; never edit or invent GOOGLE_APP_ID.',
    );
  }

  final xcode = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  if (!xcode.contains('PRODUCT_BUNDLE_IDENTIFIER = $expectedIosBundle;')) {
    issues.add('Xcode release bundle identifier is not $expectedIosBundle.');
  }

  if (issues.isNotEmpty) {
    stderr.writeln('Firebase mobile release configuration is NOT verified:');
    for (final issue in issues) {
      stderr.writeln('- $issue');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Firebase mobile release configuration is internally consistent.',
  );
}

String _plistValue(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>',
  ).firstMatch(plist);
  return match?.group(1)?.trim() ?? '';
}
