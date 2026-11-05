import 'package:flutter/foundation.dart';
import 'package:happy_notes/entities/fanfou_user_account.dart';
import 'package:happy_notes/services/fanfou_user_account_service.dart';
import 'seq_logger.dart';

class FanfouService {
  final FanfouUserAccountService _fanfouUserAccountService;

  // Fanfou has no per-instance URL: a user links a single account. The backend
  // callback persists it, so we poll getAll until it appears. Bound the wait so
  // a cancelled/abandoned authorization doesn't hang the future forever.
  final Duration pollInterval;
  final int maxPollAttempts;

  FanfouService({
    required FanfouUserAccountService fanfouUserAccountService,
    this.pollInterval = const Duration(seconds: 2),
    this.maxPollAttempts = 60,
  }) : _fanfouUserAccountService = fanfouUserAccountService;

  /// [openUrl] shows the Fanfou authorize page to the user (see `openAuthUrl`).
  Future<List<FanfouUserAccount>> authorize(Future<void> Function(Uri url) openUrl) async {
    // Snapshot the current linkage first: the backend replaces the account on a
    // successful authorization (delete + insert), minting a fresh id. Waiting
    // for an id that differs from this snapshot means a cancelled re-authorization
    // — which leaves the old account untouched — is never reported as success.
    final currentList = await _fanfouUserAccountService.getAll();
    final int? previousId = currentList.isNotEmpty ? currentList.first.id : null;

    final authorizeUrl = await _fanfouUserAccountService.requestToken();
    await openUrl(Uri.parse(authorizeUrl));
    return await waitForNewAccount(previousId);
  }

  /// Polls the backend until a Fanfou account distinct from [previousId] is
  /// linked, or throws once [maxPollAttempts] is exhausted.
  @visibleForTesting
  Future<List<FanfouUserAccount>> waitForNewAccount(int? previousId) async {
    for (var attempt = 0; attempt < maxPollAttempts; attempt++) {
      final userList = await _fanfouUserAccountService.getAll();
      final linked = userList.where((account) => account.id != previousId);
      if (linked.isNotEmpty) {
        return userList;
      }
      SeqLogger.info('Waiting for Fanfou authorization completion');
      await Future.delayed(pollInterval);
    }
    throw Exception('Timed out waiting for Fanfou authorization');
  }
}
