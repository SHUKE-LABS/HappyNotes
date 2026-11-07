import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/main.dart' as app;
import 'package:integration_test/integration_test.dart';

const _stateEnvironmentKey = 'HAPPYNOTES_E2E_STATE';
const _usernameEnvironmentKey = 'E2E_SEED_USERNAME';
const _passwordEnvironmentKey = 'E2E_SEED_PASSWORD';
const _evidenceEnvironmentKey = 'HAPPYNOTES_E2E_EVIDENCE_DIR';

const _appBoundaryKey = ValueKey<String>('e2e-app-boundary');
const _loginUsernameKey = ValueKey<String>('e2e-login-username');
const _loginPasswordKey = ValueKey<String>('e2e-login-password');
const _loginSubmitKey = ValueKey<String>('e2e-login-submit');
const _newNoteEntryKey = ValueKey<String>('e2e-new-note-entry');
const _noteEditorKey = ValueKey<String>('e2e-note-editor');
const _noteSaveKey = ValueKey<String>('e2e-note-save');
const _searchEntryKey = ValueKey<String>('e2e-search-entry');
const _searchResultsKey = ValueKey<String>('e2e-search-results-page');

void main() {
  final stateFile = Platform.environment[_stateEnvironmentKey];
  if (stateFile == null || stateFile.isEmpty) {
    testWidgets(
      'live e2e smoke is opt-in through tool/e2e/run.sh',
      (tester) async {},
      skip: true,
    );
    return;
  }

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('core note lifecycle smoke test', (tester) async {
    expect(File(stateFile).existsSync(), isTrue,
        reason: 'API e2e state file is missing');

    final username = _requiredEnvironment(_usernameEnvironmentKey);
    final password = _requiredEnvironment(_passwordEnvironmentKey);
    final evidenceDirectory = Directory(
      '${_requiredEnvironment(_evidenceEnvironmentKey)}/app',
    );
    await evidenceDirectory.create(recursive: true);

    final noteContent = 'e2eui${DateTime.now().toUtc().microsecondsSinceEpoch}';

    app.main();
    await _pumpUntilFound(tester, find.byKey(_loginUsernameKey));
    await _captureScreenshot(tester, evidenceDirectory, '01-login');

    await tester.enterText(find.byKey(_loginUsernameKey), username);
    await tester.enterText(find.byKey(_loginPasswordKey), password);
    await tester.tap(find.byKey(_loginSubmitKey));
    await _pumpUntilFound(tester, find.byKey(_newNoteEntryKey),
        timeout: const Duration(seconds: 60));

    await tester.tap(find.byKey(_newNoteEntryKey));
    await _pumpUntilFound(tester, find.byKey(_noteEditorKey));
    await tester.enterText(find.byKey(_noteEditorKey), noteContent);
    await tester.pump();
    await _captureScreenshot(tester, evidenceDirectory, '02-note-editor');

    await tester.tap(find.byKey(_noteSaveKey));
    await _pumpUntilFound(tester, find.text(noteContent),
        timeout: const Duration(seconds: 60));
    await _captureScreenshot(tester, evidenceDirectory, '03-note-created');

    await _openSearchTab(tester);
    await _searchUntilFound(tester, noteContent);
    await _captureScreenshot(tester, evidenceDirectory, '04-search-results');

    final searchResult = _searchResultText(noteContent);
    final noteItem = find.ancestor(
      of: searchResult,
      matching: find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('e2e-note-list-item-');
      }),
    );
    expect(noteItem, findsOneWidget);
    await tester.drag(noteItem, const Offset(-500, 0));
    await tester.pumpAndSettle();
    final deleteAction = find.descendant(
      of: find.byKey(_searchResultsKey),
      matching: find.text('Delete'),
    );
    expect(deleteAction, findsOneWidget);
    await tester.tap(deleteAction);
    await _pumpUntilFound(
      tester,
      find.text('Note deleted successfully.'),
      timeout: const Duration(seconds: 60),
    );
    await _pumpUntilAbsent(tester, searchResult,
        timeout: const Duration(seconds: 30));
    await _captureScreenshot(tester, evidenceDirectory, '05-note-deleted');
  });
}

String _requiredEnvironment(String key) {
  final value = Platform.environment[key];
  if (value == null || value.trim().isEmpty) {
    throw StateError('$key must be set by tool/e2e/run.sh');
  }
  return value;
}

Future<void> _openSearchTab(WidgetTester tester) async {
  final searchNavigation = find.byIcon(Icons.search);
  await _pumpUntilFound(tester, searchNavigation);
  expect(searchNavigation, findsOneWidget);
  await tester.tap(searchNavigation);
  await _pumpUntilFound(tester, find.byKey(_searchEntryKey));
}

Future<void> _searchUntilFound(WidgetTester tester, String query) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  final searchEntry = find.byKey(_searchEntryKey);

  while (DateTime.now().isBefore(deadline)) {
    await tester.tap(searchEntry);
    await tester.enterText(searchEntry, query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpUntil(
      tester,
      () =>
          find.byKey(_searchResultsKey).evaluate().isNotEmpty &&
          (_searchResultText(query).evaluate().isNotEmpty ||
              find
                  .descendant(
                    of: find.byKey(_searchResultsKey),
                    matching: find.text('No notes found matching your query.'),
                  )
                  .evaluate()
                  .isNotEmpty),
      timeout: const Duration(seconds: 30),
    );

    if (_searchResultText(query).evaluate().isNotEmpty) {
      return;
    }

    await tester.pageBack();
    await _pumpUntilFound(tester, searchEntry);
  }

  throw TestFailure(
      'Timed out waiting for the note to appear in search results');
}

Finder _searchResultText(String query) {
  return find.descendant(
    of: find.byKey(_searchResultsKey),
    matching: find.text(query),
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  await _pumpUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    timeout: timeout,
  );
}

Future<void> _pumpUntilAbsent(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  await _pumpUntil(
    tester,
    () => finder.evaluate().isEmpty,
    timeout: timeout,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (!DateTime.now().isBefore(deadline)) {
      throw TestFailure('Timed out waiting for the expected UI state');
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _captureScreenshot(
  WidgetTester tester,
  Directory evidenceDirectory,
  String name,
) async {
  final boundaryFinder = find.byKey(_appBoundaryKey);
  expect(boundaryFinder, findsOneWidget);

  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  final image = await boundary.toImage(pixelRatio: 1.0);
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Could not encode screenshot $name');
    }

    final file = File('${evidenceDirectory.path}/$name.png');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    expect(file.existsSync(), isTrue,
        reason: 'Screenshot was not written: ${file.path}');
  } finally {
    image.dispose();
  }
}
