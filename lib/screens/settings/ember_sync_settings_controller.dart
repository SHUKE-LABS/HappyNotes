import 'package:flutter/material.dart';

import '../../entities/ember_user_account.dart';
import '../../services/ember_user_account_service.dart';
import '../../utils/util.dart';

class EmberSyncSettingsController {
  final EmberUserAccountService _emberUserAccountService;
  List<EmberUserAccount> emberAccounts = [];

  EmberSyncSettingsController({
    required EmberUserAccountService emberUserAccountService,
  }) : _emberUserAccountService = emberUserAccountService;

  Future<bool> load(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      emberAccounts = await _emberUserAccountService.getAll();
      return true;
    } catch (error) {
      Util.showError(messenger, 'Failed to load Ember accounts: $error');
      return false;
    }
  }

  Future<bool> add(BuildContext context, String emberUrl, String apiKey) {
    return _run(
      context,
      'Failed to add Ember account',
      () => _emberUserAccountService.add(emberUrl, apiKey),
    );
  }

  Future<bool> activate(BuildContext context, int accountId) {
    return _run(
      context,
      'Failed to activate Ember account',
      () => _emberUserAccountService.activate(accountId),
    );
  }

  Future<bool> disable(BuildContext context, int accountId) {
    return _run(
      context,
      'Failed to disable Ember account',
      () => _emberUserAccountService.disable(accountId),
    );
  }

  Future<bool> delete(BuildContext context, int accountId) {
    return _run(
      context,
      'Failed to delete Ember account',
      () => _emberUserAccountService.delete(accountId),
    );
  }

  Future<bool> test(BuildContext context, int accountId) {
    return _run(
      context,
      'Ember connection test failed',
      () => _emberUserAccountService.test(accountId),
    );
  }

  Future<bool> nextSyncType(BuildContext context, int accountId) {
    return _run(
      context,
      'Failed to change Ember sync mode',
      () => _emberUserAccountService.nextSyncType(accountId),
    );
  }

  Future<bool> _run(
    BuildContext context,
    String message,
    Future<bool> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      return await action();
    } catch (error) {
      Util.showError(messenger, '$message: $error');
      return false;
    }
  }
}
