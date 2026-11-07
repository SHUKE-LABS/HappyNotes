import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/services/client_version_update_service.dart';
import 'package:happy_notes/widgets/client_version_update_dialog.dart';

ClientUpdatePrompt _prompt(ClientUpdateType type) {
  return ClientUpdatePrompt(
    type: type,
    latestVersion: '2.1.0',
    latestBuild: 102,
    storeUri: Uri.parse('https://example.com/happynotes'),
  );
}

Widget _host(ClientUpdatePrompt prompt) {
  return MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: !prompt.isForced,
          builder: (_) => ClientVersionUpdateDialog(
            prompt: prompt,
            launchUrlOverride: (_) async => true,
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  );
}

void main() {
  testWidgets('forced update is non-dismissible and has no Later action',
      (tester) async {
    await tester.pumpWidget(_host(_prompt(ClientUpdateType.forced)));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Later'), findsNothing);

    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
  });

  testWidgets('soft update can be dismissed', (tester) async {
    await tester.pumpWidget(_host(_prompt(ClientUpdateType.soft)));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
  });
}
