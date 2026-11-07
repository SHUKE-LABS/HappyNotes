import 'package:flutter/foundation.dart';

/// Returns the platform value understood by the API client-version contract.
///
/// Store clients are the only native clients covered by the policy endpoint.
/// Other native targets use the web value for identity purposes and never run
/// the mobile update check.
String getClientPlatform() {
  if (kIsWeb) return 'web';

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return 'web';
  }
}

bool isMobileClientPlatform(String platform) {
  return platform == 'ios' || platform == 'android';
}
