import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/entities/fanfou_user_account.dart';
import 'package:happy_notes/services/fanfou_service.dart';
import 'package:happy_notes/services/fanfou_user_account_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../test_helpers/seq_logger_setup.dart';
import 'fanfou_service_test.mocks.dart';

@GenerateMocks([FanfouUserAccountService])
FanfouUserAccount _account(int id) => FanfouUserAccount(id: id, syncType: 1, statusText: 'Normal');

/// Stubs getAll() to return each list in [sequence] on successive calls,
/// repeating the last entry once exhausted.
void _stubGetAllSequence(MockFanfouUserAccountService service, List<List<FanfouUserAccount>> sequence) {
  var call = 0;
  when(service.getAll()).thenAnswer((_) async {
    final index = call < sequence.length ? call : sequence.length - 1;
    call++;
    return sequence[index];
  });
}

void main() {
  setUpAll(setupSeqLoggerForTesting);

  late MockFanfouUserAccountService accountService;
  late FanfouService service;

  setUp(() {
    accountService = MockFanfouUserAccountService();
    service = FanfouService(
      fanfouUserAccountService: accountService,
      pollInterval: Duration.zero,
      maxPollAttempts: 5,
    );
  });

  group('waitForNewAccount', () {
    test('first-time link returns once the account appears', () async {
      _stubGetAllSequence(accountService, [
        [],
        [_account(2)],
      ]);

      final result = await service.waitForNewAccount(null);

      expect(result.single.id, 2);
    });

    test('re-authorization waits for a replacement id, not the pre-existing account', () async {
      // The stale account (id 1) is present throughout the early polls; only once
      // the backend swaps in a fresh id (2) should the flow resolve.
      _stubGetAllSequence(accountService, [
        [_account(1)],
        [_account(1)],
        [_account(2)],
      ]);

      final result = await service.waitForNewAccount(1);

      expect(result.single.id, 2);
    });

    test('a cancelled re-authorization is NOT reported as success', () async {
      // getAll keeps returning the same pre-existing account: authorization never
      // completed, so the poll must exhaust and throw rather than resolve.
      _stubGetAllSequence(accountService, [
        [_account(1)],
      ]);

      expect(service.waitForNewAccount(1), throwsA(isA<Exception>()));
    });
  });

  group('authorize', () {
    const authorizeUrl = 'https://fanfou.com/oauth/authorize?oauth_token=t';

    test('hands the authorize URL to openUrl, then waits for the new account', () async {
      when(accountService.requestToken()).thenAnswer((_) async => authorizeUrl);
      _stubGetAllSequence(accountService, [
        [],
        [],
        [_account(2)],
      ]);
      final opened = <Uri>[];

      final result = await service.authorize((url) async => opened.add(url));

      expect(opened, [Uri.parse(authorizeUrl)]);
      expect(result.single.id, 2);
    });

    test('stops without polling when openUrl fails (e.g. the user cancels)', () async {
      when(accountService.requestToken()).thenAnswer((_) async => authorizeUrl);
      when(accountService.getAll()).thenAnswer((_) async => []);

      await expectLater(
        service.authorize((url) async => throw Exception('Authorization cancelled')),
        throwsA(isA<Exception>()),
      );
      // Only the pre-authorization snapshot; no poll after the failed open.
      verify(accountService.getAll()).called(1);
    });
  });
}
