import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:happy_notes/app_config.dart';
import 'package:happy_notes/utils/app_version.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'HappyNotes',
      packageName: 'com.shukebeta.happynotes',
      version: '2.0.0',
      buildNumber: '101',
      buildSignature: '',
    );
  });

  test('formats the store version for Android and iOS', () async {
    final packageInfo = await PackageInfo.fromPlatform();

    expect(
      buildVersionText(packageInfo, isWeb: false),
      'Version: 2.0.0 (101) · ${AppConfig.version}',
    );
  });

  test('keeps the existing version text on web', () async {
    final packageInfo = await PackageInfo.fromPlatform();

    expect(
      buildVersionText(packageInfo, isWeb: true),
      'Version: ${AppConfig.version}',
    );
  });
}
