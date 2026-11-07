import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../apis/client_version_policy_api.dart';
import '../models/client_version_policy.dart';
import '../utils/client_platform.dart';
import 'seq_logger.dart';

enum ClientUpdateType { forced, soft }

class ClientUpdatePrompt {
  final ClientUpdateType type;
  final String latestVersion;
  final int latestBuild;
  final Uri storeUri;

  const ClientUpdatePrompt({
    required this.type,
    required this.latestVersion,
    required this.latestBuild,
    required this.storeUri,
  });

  bool get isForced => type == ClientUpdateType.forced;
}

class ClientVersionUpdateService {
  static const _dismissedBuildKeyPrefix =
      'client_version_update_dismissed_build_';

  final ClientVersionPolicyApi _policyApi;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final String _platform;
  final Set<int> _shownSoftBuilds = <int>{};

  ClientVersionUpdateService({
    ClientVersionPolicyApi? policyApi,
    Future<PackageInfo> Function()? packageInfoLoader,
    Future<SharedPreferences> Function()? preferencesLoader,
    String? platform,
  })  : _policyApi = policyApi ?? ClientVersionPolicyApi(),
        _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
        _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
        _platform = platform ?? getClientPlatform();

  Future<ClientUpdatePrompt?> checkForUpdate() async {
    if (!isMobileClientPlatform(_platform)) return null;

    try {
      final packageInfo = await _packageInfoLoader();
      final currentBuild = int.tryParse(packageInfo.buildNumber);
      if (currentBuild == null) {
        throw FormatException(
            'Invalid client build number: ${packageInfo.buildNumber}');
      }

      final policy = await _policyApi.getPolicy(_platform);
      final updateType = _classify(policy, currentBuild);
      if (updateType == null) return null;

      final storeUri = Uri.tryParse(policy.storeUrl);
      if (storeUri == null || !_isStoreUri(storeUri)) {
        throw FormatException(
            'Invalid client update store URL: ${policy.storeUrl}');
      }

      if (updateType == ClientUpdateType.soft) {
        if (!_shownSoftBuilds.add(policy.latestBuild)) return null;

        final preferences = await _preferencesLoader();
        final dismissedBuild = preferences.getInt(_dismissedBuildKey);
        if (dismissedBuild == policy.latestBuild) return null;
      }

      return ClientUpdatePrompt(
        type: updateType,
        latestVersion: policy.latestVersion,
        latestBuild: policy.latestBuild,
        storeUri: storeUri,
      );
    } catch (error, stackTrace) {
      _logWarning(
          'Client version policy check failed: $error', error, stackTrace);
      return null;
    }
  }

  Future<void> dismissSoftUpdate(ClientUpdatePrompt prompt) async {
    if (prompt.isForced) return;

    try {
      final preferences = await _preferencesLoader();
      await preferences.setInt(_dismissedBuildKey, prompt.latestBuild);
    } catch (error, stackTrace) {
      _logWarning('Could not remember dismissed client update: $error', error,
          stackTrace);
    }
  }

  String get _dismissedBuildKey => '$_dismissedBuildKeyPrefix$_platform';

  static ClientUpdateType? _classify(
      ClientVersionPolicy policy, int currentBuild) {
    if (currentBuild < policy.minSupportedBuild) return ClientUpdateType.forced;
    if (currentBuild < policy.latestBuild) return ClientUpdateType.soft;
    return null;
  }

  static bool _isStoreUri(Uri uri) {
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  static void _logWarning(String message, Object error, StackTrace stackTrace) {
    try {
      SeqLogger.warning(message, error, stackTrace);
    } catch (_) {
      // SeqLogger is initialized by main, but policy checks must remain fail-open
      // even if they run in an isolated test or before logging is ready.
    }
  }
}
