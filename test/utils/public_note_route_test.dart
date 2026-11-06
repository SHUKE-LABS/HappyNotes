import 'package:flutter_test/flutter_test.dart';
import 'package:happy_notes/utils/public_note_route.dart';

void main() {
  group('PublicNoteRoute.parse', () {
    test('parses a hash route note ID', () {
      expect(PublicNoteRoute.parse('/note/42')?.noteId, 42);
      expect(
        PublicNoteRoute.parse(
          'https://happynotes.shukebeta.com/#/note/42',
        )?.noteId,
        42,
      );
    });

    test('keeps malformed note paths in the public route', () {
      expect(PublicNoteRoute.parse('/note')?.noteId, isNull);
      expect(PublicNoteRoute.parse('/note/not-a-number')?.noteId, isNull);
      expect(PublicNoteRoute.parse('/note/0')?.noteId, isNull);
      expect(PublicNoteRoute.parse('/note/42/extra')?.noteId, isNull);
    });

    test('ignores unrelated routes', () {
      expect(PublicNoteRoute.parse('/'), isNull);
      expect(PublicNoteRoute.parse('/login'), isNull);
    });
  });
}
