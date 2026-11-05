import 'package:flutter/material.dart';
import '../../dependency_injection.dart';
import '../../services/fanfou_service.dart';
import '../../utils/open_auth_url.dart';
import '../../utils/util.dart';

class AddFanfouUserAccount extends StatefulWidget {
  const AddFanfouUserAccount({super.key});

  @override
  AddFanfouUserAccountState createState() => AddFanfouUserAccountState();
}

class AddFanfouUserAccountState extends State<AddFanfouUserAccount> {
  final _fanfouService = locator<FanfouService>();
  bool _authorizing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Sync Setting - Fanfou'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Authorize Happy Notes to post to your Fanfou (饭否) account. '
              'A browser will open for you to log in and approve access; '
              'return here once done.',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _authorizing ? null : () => _initializeAuthorization(context),
              child: _authorizing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Authorize'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeAuthorization(BuildContext context) async {
    var scaffoldMessengerState = ScaffoldMessenger.of(context);
    var navigator = Navigator.of(context);
    setState(() => _authorizing = true);
    try {
      await _fanfouService.authorize((url) => openAuthUrl(context, url));
      Util.showInfo(scaffoldMessengerState, 'Authorization successful');
      navigator.pop();
    } catch (e) {
      Util.showError(scaffoldMessengerState, 'Authorization failed: $e');
    } finally {
      if (mounted) setState(() => _authorizing = false);
    }
  }
}
