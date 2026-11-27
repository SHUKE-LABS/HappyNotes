import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:happy_notes/apis/ember_user_account_api.dart';
import 'package:happy_notes/entities/ember_user_account.dart';
import 'package:happy_notes/exceptions/api_exception.dart';
import 'package:happy_notes/screens/settings/ember_sync_settings.dart';
import 'package:happy_notes/screens/settings/ember_sync_settings_controller.dart';
import 'package:happy_notes/services/ember_user_account_service.dart';

import '../test_helpers/seq_logger_setup.dart';

class FailingEmberService extends EmberUserAccountService {
  FailingEmberService()
      : super(
          emberUserAccountApi: EmberUserAccountApi(dio: Dio()),
        );

  int? testedAccountId;

  @override
  Future<bool> test(int accountId) async {
    testedAccountId = accountId;
    throw Exception('offline');
  }
}

class StubEmberListController extends EmberSyncSettingsController {
  StubEmberListController(FailingEmberService service)
      : super(emberUserAccountService: service) {
    emberAccounts = const [
      EmberUserAccount(
        id: 42,
        userId: 5,
        emberUrl: 'https://ember.example',
        apiKey: '****',
        status: 'Normal',
      ),
    ];
  }

  @override
  Future<bool> load(BuildContext context) async => true;
}

class SequenceEmberService extends EmberUserAccountService {
  SequenceEmberService({required this.responses, this.failureMessage})
      : super(emberUserAccountApi: EmberUserAccountApi(dio: Dio()));

  final List<List<EmberUserAccount>> responses;
  final String? failureMessage;
  int getAllCalls = 0;
  int? toggledAccountId;

  @override
  Future<List<EmberUserAccount>> getAll() async {
    final response = responses[
        getAllCalls < responses.length ? getAllCalls : responses.length - 1];
    getAllCalls++;
    return response;
  }

  @override
  Future<bool> nextSyncType(int accountId) async {
    toggledAccountId = accountId;
    if (failureMessage != null) {
      throw ApiException({
        'successful': false,
        'message': failureMessage,
        'errorCode': 'EMBER_SYNC_TYPE_FAILED',
      });
    }
    return true;
  }
}

EmberUserAccount accountWithSyncType(int syncType) => EmberUserAccount(
      id: 42,
      userId: 5,
      emberUrl: 'https://ember.example',
      apiKey: '****',
      syncType: syncType,
      status: 'Normal',
    );

void main() {
  setUp(() async {
    setupSeqLoggerForTesting();
    await GetIt.instance.reset();
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('lists account status and required actions', (tester) async {
    final service = FailingEmberService();
    final controller = StubEmberListController(service);
    GetIt.instance.registerSingleton<EmberSyncSettingsController>(controller);

    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: EmberSyncSettings()));
    await tester.pumpAndSettle();

    expect(find.text('https://ember.example'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Disable'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Test'));
    await tester.pump();
    expect(service.testedAccountId, 42);
    expect(find.textContaining('Ember connection test failed'), findsOneWidget);
  });

  testWidgets('switches the sync mode and reloads the account list',
      (tester) async {
    final service = SequenceEmberService(
      responses: [
        [accountWithSyncType(EmberUserAccount.publicOnlySyncType)],
        [accountWithSyncType(EmberUserAccount.tagEmberOnlySyncType)],
      ],
    );
    GetIt.instance.registerSingleton<EmberSyncSettingsController>(
      EmberSyncSettingsController(emberUserAccountService: service),
    );

    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: EmberSyncSettings()));
    await tester.pumpAndSettle();

    expect(find.text('Public notes'), findsOneWidget);
    expect(service.getAllCalls, 1);

    await tester.tap(find.text('Public notes'));
    await tester.pumpAndSettle();

    expect(service.toggledAccountId, 42);
    expect(service.getAllCalls, 2);
    expect(find.text('Notes tagged #ember'), findsOneWidget);
  });

  testWidgets('shows a failed toggle message without reloading the account',
      (tester) async {
    final service = SequenceEmberService(
      responses: [
        [accountWithSyncType(EmberUserAccount.publicOnlySyncType)],
      ],
      failureMessage: 'The Ember server rejected the sync mode change',
    );
    GetIt.instance.registerSingleton<EmberSyncSettingsController>(
      EmberSyncSettingsController(emberUserAccountService: service),
    );

    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: EmberSyncSettings()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Public notes'));
    await tester.pump();

    expect(
      find.textContaining('The Ember server rejected the sync mode change'),
      findsOneWidget,
    );
    expect(find.text('Public notes'), findsOneWidget);
    expect(find.text('Notes tagged #ember'), findsNothing);
    expect(service.getAllCalls, 1);
  });
}
