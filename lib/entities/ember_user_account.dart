class EmberUserAccount {
  static const int publicOnlySyncType = 1;
  static const int tagEmberOnlySyncType = 2;

  final int id;
  final int userId;
  final String emberUrl;
  final String apiKey;
  final int syncType;
  final String status;
  final String? lastError;

  const EmberUserAccount({
    this.id = 0,
    this.userId = 0,
    required this.emberUrl,
    required this.apiKey,
    this.syncType = publicOnlySyncType,
    this.status = 'Untested',
    this.lastError,
  });

  bool get isActive => status == 'Normal';

  bool get isDisabled => status == 'Disabled';

  bool get isUntested => status == 'Untested';

  String get syncTypeText {
    switch (syncType) {
      case publicOnlySyncType:
        return 'Public notes';
      case tagEmberOnlySyncType:
        return 'Notes tagged #ember';
      default:
        return 'Unknown';
    }
  }

  factory EmberUserAccount.fromJson(Map<String, dynamic> json) {
    return EmberUserAccount(
      id: _asInt(json['id']),
      userId: _asInt(json['userId']),
      emberUrl: json['emberUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      syncType: _syncTypeFromJson(json['syncType']),
      status: (json['statusText'] ?? json['status'])?.toString() ?? 'Untested',
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'emberUrl': emberUrl,
      'apiKey': apiKey,
      'syncType': syncType,
      'status': status,
      'lastError': lastError,
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _syncTypeFromJson(dynamic value) {
    if (value == null || value == 'PublicOnly') return publicOnlySyncType;
    if (value == 'TagEmberOnly') return tagEmberOnlySyncType;
    return _asInt(value);
  }
}
