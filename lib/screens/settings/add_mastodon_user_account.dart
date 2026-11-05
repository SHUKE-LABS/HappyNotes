import 'package:flutter/material.dart';
import 'package:happy_notes/entities/mastodon_user_account.dart';
import '../../dependency_injection.dart';
import '../../services/mastodon_service.dart';
import '../../utils/open_auth_url.dart';
import '../../utils/util.dart';

class AddMastodonUserAccount extends StatefulWidget {
  final MastodonUserAccount? setting;

  const AddMastodonUserAccount({super.key, this.setting});

  @override
  AddMastodonUserAccountState createState() => AddMastodonUserAccountState();
}

class AddMastodonUserAccountState extends State<AddMastodonUserAccount> {
  final _mastodonService = locator<MastodonService>();
  final TextEditingController _instanceController = TextEditingController(text: 'https://mastodon.social');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Sync Setting - Mastodon'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _instanceController,
              decoration: const InputDecoration(
                labelText: 'Mastodon Instance URL',
                hintText: 'https://mastodon.social',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _initializeAuthorization(context);
              },
              child: const Text('Authorize'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeAuthorization(BuildContext context) async {
    var scaffoldMessengerState = ScaffoldMessenger.of(context);
    var navigator = Navigator.of(context);
    try {
      var instanceUrl = _instanceController.text.toLowerCase().trim();
      if (!instanceUrl.startsWith('http://') && !instanceUrl.startsWith('https://')) {
        instanceUrl = 'https://$instanceUrl';
      }
      if (instanceUrl.endsWith('/')) {
        instanceUrl = instanceUrl.substring(0, instanceUrl.length - 1);
      }
      await _mastodonService.authorize(instanceUrl, (url) => openAuthUrl(context, url));
      Util.showInfo(scaffoldMessengerState, 'Authorization successful');
      navigator.pop();
    } catch (e) {
      Util.showError(scaffoldMessengerState, 'Authorization failed: $e');
    }
  }
}
