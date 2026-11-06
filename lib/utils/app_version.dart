import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

import '../app_config.dart';

/// Builds the version text shown in the Settings screen.
///
/// Web keeps using the environment-provided version because web builds are
/// continuous. Store builds include the package version and build number.
String buildVersionText(PackageInfo packageInfo, {bool? isWeb}) {
  final web = isWeb ?? kIsWeb;
  if (web) {
    return 'Version: ${AppConfig.version}';
  }

  return 'Version: ${packageInfo.version} (${packageInfo.buildNumber}) · ${AppConfig.version}';
}
