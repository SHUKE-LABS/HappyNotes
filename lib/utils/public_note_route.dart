import 'package:flutter/material.dart';

import '../screens/public_note/public_note_page.dart';
import '../services/notes_services.dart';

class PublicNoteRoute {
  final int? noteId;

  const PublicNoteRoute({required this.noteId});

  /// Parses `/note/{id}` paths while retaining malformed note paths so they
  /// can render the same not-found state as inaccessible notes.
  static PublicNoteRoute? parse(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) return null;

    final uri = Uri.tryParse(routeName.trim());
    if (uri == null) return null;

    var path = uri.path;
    if (uri.fragment.isNotEmpty && (path.isEmpty || path == '/')) {
      path = uri.fragment;
    }
    if (path.startsWith('#')) path = path.substring(1);
    if (!path.startsWith('/')) path = '/$path';

    final pathUri = Uri.tryParse(path);
    if (pathUri == null) return null;

    final segments = pathUri.pathSegments;
    if (segments.isEmpty || segments.first != 'note') return null;

    final rawId = segments.length == 2 ? segments[1] : null;
    final parsedId = rawId == null ? null : int.tryParse(rawId);
    return PublicNoteRoute(
      noteId: parsedId != null && parsedId > 0 ? parsedId : null,
    );
  }
}

Route<dynamic>? generatePublicNoteRoute(
  RouteSettings settings, {
  NotesService? notesService,
}) {
  final publicNoteRoute = PublicNoteRoute.parse(settings.name);
  if (publicNoteRoute == null) return null;

  return MaterialPageRoute(
    settings: settings,
    builder: (context) => PublicNotePage(
      noteId: publicNoteRoute.noteId,
      notesService: notesService,
    ),
  );
}
