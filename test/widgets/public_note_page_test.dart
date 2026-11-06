import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/entities/public_note.dart';
import 'package:happy_notes/exceptions/public_note_not_found_exception.dart';
import 'package:happy_notes/screens/components/markdown_body_here.dart';
import 'package:happy_notes/screens/public_note/public_note_page.dart';
import 'package:happy_notes/services/notes_services.dart';
import 'package:happy_notes/utils/public_note_route.dart';

import '../test_helpers/seq_logger_setup.dart';

class _FakeNotesService extends NotesService {
  PublicNote? note;
  Object? error;
  int calls = 0;

  @override
  Future<PublicNote> getPublic(int noteId) async {
    calls++;
    if (error != null) throw error!;
    return note!;
  }
}

PublicNote _note({bool isMarkdown = false, String content = 'public content'}) {
  return PublicNote(
    id: 42,
    content: content,
    createdAt: 1700000000,
    isMarkdown: isMarkdown,
  );
}

void main() {
  setUpAll(setupSeqLoggerForTesting);

  testWidgets('keeps the existing root route on the home widget', (
    tester,
  ) async {
    final fakeService = _FakeNotesService()..note = _note();

    await tester.pumpWidget(
      MaterialApp(
        home: const Text('existing root'),
        onGenerateRoute: (settings) =>
            generatePublicNoteRoute(settings, notesService: fakeService),
      ),
    );

    expect(find.text('existing root'), findsOneWidget);
    expect(fakeService.calls, 0);
  });

  testWidgets('opens the public page for a direct named hash route', (
    tester,
  ) async {
    final fakeService = _FakeNotesService()..note = _note();

    await tester.pumpWidget(
      MaterialApp(
        home: const Text('existing root'),
        initialRoute: '/note/42',
        onGenerateRoute: (settings) => generatePublicNoteRoute(
          settings,
          notesService: fakeService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('public content'), findsOneWidget);
    expect(fakeService.calls, 1);
  });

  testWidgets('renders a public plain-text note without edit controls', (
    tester,
  ) async {
    final fakeService = _FakeNotesService()
      ..note = _note(content: 'full plain text');

    await tester.pumpWidget(
      MaterialApp(home: PublicNotePage(noteId: 42, notesService: fakeService)),
    );
    await tester.pumpAndSettle();

    expect(find.text('full plain text'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('renders Markdown notes with the existing Markdown renderer', (
    tester,
  ) async {
    final fakeService = _FakeNotesService()
      ..note = _note(isMarkdown: true, content: '# Heading\n\nMarkdown body');

    await tester.pumpWidget(
      MaterialApp(home: PublicNotePage(noteId: 42, notesService: fakeService)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBodyHere), findsOneWidget);
  });

  testWidgets(
    'uses the same not-found state for malformed and inaccessible notes',
    (tester) async {
      final fakeService = _FakeNotesService()
        ..error = const PublicNoteNotFoundException();

      await tester.pumpWidget(
        MaterialApp(
          home: PublicNotePage(noteId: null, notesService: fakeService),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Note not found'), findsOneWidget);
      expect(fakeService.calls, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: PublicNotePage(noteId: 42, notesService: fakeService),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Note not found'), findsOneWidget);
      expect(find.text('Unable to load public note'), findsNothing);
    },
  );

  testWidgets('shows a retryable error and retries the public fetch', (
    tester,
  ) async {
    final fakeService = _FakeNotesService()
      ..error = Exception('network failure');

    await tester.pumpWidget(
      MaterialApp(home: PublicNotePage(noteId: 42, notesService: fakeService)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load public note'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    fakeService
      ..error = null
      ..note = _note(content: 'loaded after retry');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('loaded after retry'), findsOneWidget);
    expect(fakeService.calls, 2);
  });
}
