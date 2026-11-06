import 'dart:async';

import 'package:flutter/material.dart';

import '../../dependency_injection.dart';
import '../../entities/public_note.dart';
import '../../exceptions/public_note_not_found_exception.dart';
import '../../services/notes_services.dart';
import '../../services/seq_logger.dart';
import '../components/markdown_body_here.dart';

enum _PublicNoteLoadState { loading, loaded, notFound, error }

class PublicNotePage extends StatefulWidget {
  final int? noteId;
  final NotesService? notesService;

  const PublicNotePage({super.key, required this.noteId, this.notesService});

  @override
  State<PublicNotePage> createState() => _PublicNotePageState();
}

class _PublicNotePageState extends State<PublicNotePage> {
  late final NotesService _notesService;
  late _PublicNoteLoadState _loadState;
  PublicNote? _note;

  @override
  void initState() {
    super.initState();
    _notesService = widget.notesService ?? locator<NotesService>();
    _loadState = widget.noteId == null
        ? _PublicNoteLoadState.notFound
        : _PublicNoteLoadState.loading;

    if (widget.noteId != null) {
      unawaited(_loadNote());
    }
  }

  Future<void> _loadNote() async {
    final noteId = widget.noteId;
    if (noteId == null) return;

    setState(() {
      _loadState = _PublicNoteLoadState.loading;
      _note = null;
    });

    try {
      final note = await _notesService.getPublic(noteId);
      if (!mounted) return;
      setState(() {
        _note = note;
        _loadState = _PublicNoteLoadState.loaded;
      });
    } on PublicNoteNotFoundException {
      if (!mounted) return;
      setState(() {
        _note = null;
        _loadState = _PublicNoteLoadState.notFound;
      });
    } catch (error) {
      SeqLogger.severe('PublicNotePage failed to load note $noteId: $error');
      if (!mounted) return;
      setState(() {
        _note = null;
        _loadState = _PublicNoteLoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_loadState) {
      case _PublicNoteLoadState.loading:
        return _buildScaffold(
          body: const Center(child: CircularProgressIndicator()),
        );
      case _PublicNoteLoadState.loaded:
        return _buildLoadedPage(_note!);
      case _PublicNoteLoadState.notFound:
        return _buildScaffold(
          body: const Center(child: Text('Note not found')),
        );
      case _PublicNoteLoadState.error:
        return _buildScaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load public note'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => unawaited(_loadNote()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildScaffold({required Widget body}) {
    return Scaffold(
      appBar: AppBar(title: const Text('Public note')),
      body: body,
    );
  }

  Widget _buildLoadedPage(PublicNote note) {
    final content = note.isMarkdown
        ? MarkdownBodyHere(data: note.content)
        : Text(note.content, style: const TextStyle(fontSize: 16.0));

    return Scaffold(
      appBar: AppBar(title: Text('Public note #${note.id}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectionArea(
            child: SizedBox(width: double.infinity, child: content),
          ),
        ),
      ),
    );
  }
}
