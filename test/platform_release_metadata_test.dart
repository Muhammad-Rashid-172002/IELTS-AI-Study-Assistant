import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release metadata uses the product display name', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:label="IELTS AI Master"'));
  });

  test('iOS declares the product name and speaking permissions', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<string>IELTS AI Master</string>'));
    expect(plist, contains('<key>NSMicrophoneUsageDescription</key>'));
    expect(plist, contains('<key>NSSpeechRecognitionUsageDescription</key>'));
    expect(plist, contains('speaking feedback'));
    expect(plist, contains('speech recognition'));
  });
}
