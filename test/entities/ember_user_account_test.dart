import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/entities/ember_user_account.dart';

void main() {
  test('serializes an Ember account and preserves masked API keys', () {
    final account = EmberUserAccount.fromJson({
      'id': 7,
      'userId': 11,
      'emberUrl': 'https://ember.example',
      'apiKey': '****abcd',
      'syncType': 'PublicOnly',
      'status': 'Normal',
      'lastError': null,
    });

    expect(account.id, 7);
    expect(account.userId, 11);
    expect(account.syncType, EmberUserAccount.publicOnlySyncType);
    expect(account.isActive, isTrue);
    expect(account.toJson(), {
      'id': 7,
      'userId': 11,
      'emberUrl': 'https://ember.example',
      'apiKey': '****abcd',
      'syncType': 1,
      'status': 'Normal',
      'lastError': null,
    });
  });

  test('uses statusText when the API provides the standard display field', () {
    final account = EmberUserAccount.fromJson({
      'emberUrl': 'https://ember.example',
      'apiKey': '****',
      'syncType': 1,
      'status': 1,
      'statusText': 'Disabled',
    });

    expect(account.status, 'Disabled');
    expect(account.isDisabled, isTrue);
  });

  test('maps sync types to their display labels', () {
    EmberUserAccount accountWithSyncType(int syncType) => EmberUserAccount(
          emberUrl: 'https://ember.example',
          apiKey: '****',
          syncType: syncType,
        );

    expect(
      accountWithSyncType(EmberUserAccount.publicOnlySyncType).syncTypeText,
      'Public notes',
    );
    expect(
      accountWithSyncType(EmberUserAccount.tagEmberOnlySyncType).syncTypeText,
      'Notes tagged #ember',
    );
    expect(accountWithSyncType(99).syncTypeText, 'Unknown');
    expect(
      EmberUserAccount.fromJson({
        'emberUrl': 'https://ember.example',
        'apiKey': '****',
        'syncType': 'TagEmberOnly',
      }).syncType,
      EmberUserAccount.tagEmberOnlySyncType,
    );
  });
}
