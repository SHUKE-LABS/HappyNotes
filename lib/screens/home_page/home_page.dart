import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happy_notes/app_config.dart';
import 'package:happy_notes/providers/notes_provider.dart';
import 'package:happy_notes/providers/auth_provider.dart';
import 'package:happy_notes/providers/note_list_provider.dart';
import 'package:happy_notes/screens/components/note_list/note_list.dart';
import 'package:happy_notes/screens/note_detail/note_detail.dart';
import '../../entities/note.dart';
import '../../utils/navigation_helper.dart';
import '../../utils/util.dart';
import '../components/floating_pagination.dart';
import '../memories/memories_on_day.dart';
import '../components/note_list/note_list_callbacks.dart';
import '../components/pagination_controls.dart';
import '../../dependency_injection.dart';
import '../account/user_session.dart';
import '../new_note/new_note.dart';
import '../components/controllers/tag_cloud_controller.dart';
import 'package:happy_notes/screens/components/create_note_fab.dart';
import '../components/tappable_app_bar_title.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late ScrollController _scrollController;
  late TagCloudController _tagCloudController;
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    _tagCloudController = locator<TagCloudController>();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);

    // Initialize provider data after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<NotesProvider>(context, listen: false);
        if (provider.notes.isEmpty && !provider.isLoadingList) {
          provider.loadPage(1);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _wasInBackground) {
      _handleAppResumed();
    }

    _wasInBackground = (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive);
  }

  void _handleAppResumed() {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    // Auto-reload if logged in but notes list is empty (iOS Safari memory management fix)
    if (authProvider.isAuthenticated &&
        notesProvider.notes.isEmpty &&
        !notesProvider.isLoadingList) {
      notesProvider.loadPage(1);
    }
  }

  Future<void> navigateToPage(int pageNumber) async {
    if (!mounted) return;
    final provider = Provider.of<NotesProvider>(context, listen: false);
    await provider.loadPage(pageNumber);
  }

  Future<void> refreshPage() async {
    if (!mounted) return;
    final provider = Provider.of<NotesProvider>(context, listen: false);
    await provider.refreshCurrentPage();
  }

  /// Handle the result from NoteDetail editing
  void _handleEditResult(bool? saved) {
    // No action needed - cache updates are handled by NoteUpdateCoordinator
    // This method is kept for potential future use (e.g., analytics, UI feedback)
  }

  @override
  Widget build(BuildContext context) {
    UserSession().isDesktop = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (UserSession().isDesktop)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: refreshPage,
              tooltip: 'Refresh',
            ),
        ],
        title: TappableAppBarTitle(
          title: AppConfig.envName == 'production' ? 'My Notes' : 'My Notes [${AppConfig.envName.toUpperCase()}]',
          onTap: () => NavigationHelper.showTagInputDialog(context),
          onLongPress: () async {
            final navigator = Navigator.of(context);
            var tagData = await _tagCloudController.loadTagCloud(context);
            if (!mounted) return;
            NavigationHelper.showTagDiagram(navigator.context, tagData);
          },
        ),
      ),
      body: Stack(
        children: [
          Consumer<NotesProvider>(
            builder: (ctx, notesProvider, child) {
              return Stack(
                children: [
                  ChangeNotifierProvider<NoteListProvider>.value(
                    value: notesProvider,
                    child: _buildBody(notesProvider),
                  ),
                  if (notesProvider.totalPages > 1 && !UserSession().isDesktop)
                    FloatingPagination(
                      currentPage: notesProvider.currentPage,
                      totalPages: notesProvider.totalPages,
                      navigateToPage: (pageNumber) =>
                          navigateToPage(pageNumber),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: CreateNoteFAB(
        key: const ValueKey<String>('e2e-new-note-entry'),
        isPrivate: AppConfig.privateNoteOnlyIsEnabled,
        heroTag: 'fab_home',
        onPressed: () async {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final provider = Provider.of<NotesProvider>(context, listen: false);
          final Note? savedNote = await Navigator.push<Note>(
            context,
            MaterialPageRoute(
              builder: (context) => NewNote(
                isPrivate: AppConfig.privateNoteOnlyIsEnabled,
              ),
            ),
          );
          if (!mounted) return;
          if (savedNote != null) {
            if (provider.currentPage == 1) {
              if (_scrollController.hasClients &&
                  _scrollController.offset > 0) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            } else {
              Util.showInfo(scaffoldMessenger, 'Note saved successfully.');
            }
          }
        },
      ),
    );
  }

  Widget _buildBody(NotesProvider notesProvider) {
    if (notesProvider.isLoadingList) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notesProvider.listError != null) {
      return RefreshIndicator(
        onRefresh: refreshPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 200),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load notes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      notesProvider.listError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: refreshPage,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (notesProvider.notes.isEmpty) {
      return RefreshIndicator(
        onRefresh: refreshPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No notes available. Create a new note to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: NoteList(
            groupedNotes: notesProvider.groupedNotes,
            scrollController: _scrollController,
            showDateHeader: true,
            callbacks: ListItemCallbacks<Note>(
              onTap: (note) async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NoteDetail(note: note),
                  ),
                );
                _handleEditResult(saved);
              },
              onDoubleTap: (note) async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NoteDetail(
                        note: note,
                        enterEditing: note.userId == UserSession().id),
                  ),
                );
                _handleEditResult(saved);
              },
              onDelete: (note) async {
                final result = await notesProvider.deleteNote(note.id);
                if (!result.isSuccess && mounted) {
                  Util.showError(
                      ScaffoldMessenger.of(context), result.errorMessage!);
                }
              },
              onTogglePrivacy: (note) async {
                final result = await notesProvider.setNotePrivacy(note.id, !note.isPrivate);
                if (!result.isSuccess && mounted) {
                  Util.showError(ScaffoldMessenger.of(context), result.errorMessage!);
                }
              },
            ),
            noteCallbacks: NoteListCallbacks(
              onRefresh: refreshPage,
              onTagTap: (note, tag) =>
                  NavigationHelper.onTagTap(context, note, tag),
              onDateHeaderTap: (date) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MemoriesOnDay(date: date),
                ),
              ),
            ),
            config: const ListItemConfig(
              showDate:
                  false, // Don't show individual dates when showDateHeader is true
              showAuthor: false,
              enableDismiss: true,
            ),
          ),
        ),
        if (notesProvider.totalPages > 1 && UserSession().isDesktop)
          PaginationControls(
            currentPage: notesProvider.currentPage,
            totalPages: notesProvider.totalPages,
            navigateToPage: (pageNumber) => navigateToPage(pageNumber),
          ),
      ],
    );
  }
}
