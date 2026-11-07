import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/client_version_update_service.dart';
import '../services/seq_logger.dart';

class ClientVersionUpdateDialog extends StatelessWidget {
  final ClientUpdatePrompt prompt;
  final Future<bool> Function(Uri)? launchUrlOverride;

  const ClientVersionUpdateDialog({
    super.key,
    required this.prompt,
    this.launchUrlOverride,
  });

  static Future<bool> _launchStoreUrl(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _update(BuildContext context) async {
    try {
      final launched =
          await (launchUrlOverride ?? _launchStoreUrl)(prompt.storeUri);
      if (!launched) {
        SeqLogger.warning(
            'Could not open client update URL: ${prompt.storeUri}');
      }
    } catch (error, stackTrace) {
      try {
        SeqLogger.warning(
            'Could not open client update URL: $error', error, stackTrace);
      } catch (_) {
        // Logging must not interfere with the update prompt.
      }
    }

    if (context.mounted && !prompt.isForced) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !prompt.isForced,
      child: AlertDialog(
        title: Text(prompt.isForced ? 'Update required' : 'Update available'),
        content: Text(
          prompt.isForced
              ? 'This version of Happy Notes is no longer supported. Update to continue.'
              : 'Happy Notes ${prompt.latestVersion} is available.',
        ),
        actions: [
          if (!prompt.isForced)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
          TextButton(
            onPressed: () => _update(context),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
