import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an OAuth authorize page for the user.
///
/// A browser lets a page open a new tab only from inside the user's tap. The
/// authorize URL is known only after a network round trip, by which time that
/// tap is over, so Safari and other popup blockers silently drop the window.
/// On web this asks for one more tap and opens the page from its handler.
///
/// Throws if the page cannot be opened or the user cancels.
Future<void> openAuthUrl(BuildContext context, Uri url) async {
  if (!kIsWeb) {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
    return;
  }
  if (!context.mounted) {
    throw Exception('Authorization cancelled');
  }
  final opened = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Continue in browser'),
      content: Text('Open ${url.host} to log in and approve access, then return here.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // launchUrl must start inside this tap: no await before it.
            launchUrl(url);
            Navigator.of(dialogContext).pop(true);
          },
          child: const Text('Open'),
        ),
      ],
    ),
  );
  if (opened != true) {
    throw Exception('Authorization cancelled');
  }
}
