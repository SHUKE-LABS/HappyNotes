class ClientVersionPolicy {
  final int minSupportedBuild;
  final String latestVersion;
  final int latestBuild;
  final String storeUrl;

  const ClientVersionPolicy({
    required this.minSupportedBuild,
    required this.latestVersion,
    required this.latestBuild,
    required this.storeUrl,
  });

  factory ClientVersionPolicy.fromJson(dynamic value) {
    if (value is! Map) {
      throw const FormatException(
          'Client version policy data is not an object');
    }

    final json = Map<String, dynamic>.from(value);
    return ClientVersionPolicy(
      minSupportedBuild:
          _requiredInt(json, 'minSupportedBuild', 'MinSupportedBuild'),
      latestVersion: _requiredString(json, 'latestVersion', 'LatestVersion'),
      latestBuild: _requiredInt(json, 'latestBuild', 'LatestBuild'),
      storeUrl: _requiredString(json, 'storeUrl', 'StoreUrl'),
    );
  }

  static String _requiredString(
    Map<String, dynamic> json,
    String camelCaseKey,
    String pascalCaseKey,
  ) {
    final value = json[camelCaseKey] ?? json[pascalCaseKey];
    if (value is! String) {
      throw FormatException('Client version policy is missing $camelCaseKey');
    }
    return value;
  }

  static int _requiredInt(
    Map<String, dynamic> json,
    String camelCaseKey,
    String pascalCaseKey,
  ) {
    final value = json[camelCaseKey] ?? json[pascalCaseKey];
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    throw FormatException('Client version policy is missing $camelCaseKey');
  }
}
