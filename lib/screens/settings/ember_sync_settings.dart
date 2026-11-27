import 'package:flutter/material.dart';

import '../../dependency_injection.dart';
import '../../entities/ember_user_account.dart';
import '../../services/dialog_services.dart';
import '../../utils/util.dart';
import 'add_ember_account.dart';
import 'ember_sync_settings_controller.dart';

class EmberSyncSettings extends StatefulWidget {
  const EmberSyncSettings({super.key});

  @override
  State<EmberSyncSettings> createState() => EmberSyncSettingsState();
}

class EmberSyncSettingsState extends State<EmberSyncSettings> {
  final EmberSyncSettingsController _settingsController = locator<EmberSyncSettingsController>();
  bool _isLoading = true;
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      _hasLoaded = true;
      _loadAccounts();
    }
  }

  Future<void> _loadAccounts() async {
    if (mounted) setState(() => _isLoading = true);
    await _settingsController.load(context);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _runAction(
    Future<bool> Function() action, {
    String? successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await action()) {
      if (successMessage != null) Util.showInfo(messenger, successMessage);
      await _loadAccounts();
    }
  }

  Color _statusColor(EmberUserAccount account) {
    if (account.isActive) return Colors.green;
    if (account.isDisabled) return Colors.orange;
    return Colors.red;
  }

  Widget _buildAccountCard(EmberUserAccount account) {
    final iconOnly = MediaQuery.of(context).size.width < 600;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              account.emberUrl,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor(account).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                account.status,
                style: TextStyle(
                  color: _statusColor(account),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (account.lastError?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                account.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Sync mode: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => _runAction(
                    () => _settingsController.nextSyncType(context, account.id),
                  ),
                  child: Text(account.syncTypeText),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (account.isActive || account.isDisabled)
                    _actionButton(
                      icon: account.isActive ? Icons.pause : Icons.play_arrow,
                      label: account.isActive ? 'Disable' : 'Activate',
                      iconOnly: iconOnly,
                      color: account.isActive ? Colors.orange : Colors.green,
                      onPressed: () => _runAction(
                        () => account.isActive
                            ? _settingsController.disable(context, account.id)
                            : _settingsController.activate(context, account.id),
                      ),
                    ),
                  _actionButton(
                    icon: Icons.send,
                    label: 'Test',
                    iconOnly: iconOnly,
                    color: Colors.blue,
                    onPressed: () => _runAction(
                      () => _settingsController.test(context, account.id),
                      successMessage: 'Ember connection test succeeded.',
                    ),
                  ),
                  _actionButton(
                    icon: Icons.delete,
                    label: 'Delete',
                    iconOnly: iconOnly,
                    color: Colors.red,
                    onPressed: () async {
                      if (await DialogService.showConfirmDialog(context) == true && mounted) {
                        await _runAction(
                          () => _settingsController.delete(context, account.id),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required bool iconOnly,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text(iconOnly ? '' : label),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: iconOnly ? 8 : 12),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sync_disabled, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Ember Accounts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Tap Add to configure Ember sync.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ember Sync'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEmberAccount()),
              ).then((_) => _loadAccounts());
            },
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAccounts,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _settingsController.emberAccounts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _settingsController.emberAccounts.length,
                    itemBuilder: (_, index) => _buildAccountCard(_settingsController.emberAccounts[index]),
                  ),
      ),
    );
  }
}
