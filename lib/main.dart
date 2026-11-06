import 'package:flutter/material.dart';
import 'package:happy_notes/services/seq_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:happy_notes/dependency_injection.dart' as di;
import 'package:happy_notes/providers/auth_provider.dart';
import 'package:happy_notes/providers/notes_provider.dart';
import 'package:happy_notes/providers/search_provider.dart';
import 'package:happy_notes/providers/tag_notes_provider.dart';
import 'package:happy_notes/providers/memories_provider.dart';
import 'package:happy_notes/providers/trash_provider.dart';
import 'package:happy_notes/providers/discovery_provider.dart';
import 'package:happy_notes/providers/linked_notes_provider.dart';
import 'package:happy_notes/providers/app_state_provider.dart';
import 'package:happy_notes/screens/account/user_session.dart';
import 'package:happy_notes/screens/initial_page.dart';
import 'package:happy_notes/screens/main_menu.dart';
import 'package:happy_notes/screens/navigation/bottom_navigation.dart';
import 'package:happy_notes/screens/new_note/new_note.dart';
import 'package:happy_notes/services/note_update_coordinator.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

import 'app_config.dart';
import 'utils/public_note_route.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependencies
  di.init();

  // Load environment variables
  await dotenv.load(
    fileName: '.env',
    mergeWith: kIsWeb ? {} : Platform.environment,
  );

  // Initialize logging
  SeqLogger.initialize();

  // Disable browser context menu for Flutter web double selection fix
  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }

  // Run the app with MultiProvider
  runApp(
    MultiProvider(
      providers: [
        // Create individual providers first
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => NotesProvider(di.locator()),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchProvider(di.locator()),
        ),
        ChangeNotifierProvider(
          create: (_) => TagNotesProvider(di.locator()),
        ),
        ChangeNotifierProvider(
          create: (_) => MemoriesProvider(di.locator()),
        ),
        ChangeNotifierProvider(
          create: (_) => TrashProvider(di.locator()),
        ),
        ChangeNotifierProvider(
          create: (_) => DiscoveryProvider(di.locator()),
        ),
        ChangeNotifierProvider(
          create: (_) => LinkedNotesProvider(di.locator()),
        ),
        // Create AppStateProvider after individual providers - lazy: false to force immediate creation
        ChangeNotifierProvider<AppStateProvider>(
          lazy: false,
          create: (context) {
            SeqLogger.info('Creating AppStateProvider in main.dart');
            final appStateProvider = AppStateProvider(
              Provider.of<AuthProvider>(context, listen: false),
              Provider.of<NotesProvider>(context, listen: false),
              Provider.of<SearchProvider>(context, listen: false),
              Provider.of<TagNotesProvider>(context, listen: false),
              Provider.of<MemoriesProvider>(context, listen: false),
              Provider.of<TrashProvider>(context, listen: false),
              Provider.of<DiscoveryProvider>(context, listen: false),
            );

            // Register NoteUpdateCoordinator after AppStateProvider is created
            di.locator.registerLazySingleton<NoteUpdateCoordinator>(
              () => NoteUpdateCoordinator(
                appStateProvider: appStateProvider,
              ),
            );

            return appStateProvider;
          },
        ),
      ],
      child: const HappyNotesApp(),
    ),
  );
}

class HappyNotesApp extends StatefulWidget {
  const HappyNotesApp({super.key});

  @override
  State<HappyNotesApp> createState() => HappyNotesState();
}

class HappyNotesState extends State<HappyNotesApp> {
  QuickActions? quickActions;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<MainMenuState> mainMenuKey = GlobalKey<MainMenuState>();

  @override
  void initState() {
    super.initState();
    initializeQuickActions();
  }

  void initializeQuickActions() {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    quickActions = const QuickActions();
    quickActions!.setShortcutItems([
      const ShortcutItem(
        type: 'takeNote',
        localizedTitle: 'Take note',
        icon: 'pencil',
      ),
    ]);

    quickActions!.initialize((String shortcutType) async {
      if (shortcutType == 'takeNote') {
        if (mainMenuKey.currentState != null) {
          // MainMenu is already in the widget tree - navigate to NewNote screen
          mainMenuKey.currentState?.switchToPage(indexNotes);
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => NewNote(isPrivate: AppConfig.privateNoteOnlyIsEnabled),
            ),
          );
        } else {
          // MainMenu is not in the widget tree, push it then navigate to NewNote
          await navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainMenu(
                key: mainMenuKey,
                initialPageIndex: indexNotes,
              ),
            ),
          );
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => NewNote(isPrivate: AppConfig.privateNoteOnlyIsEnabled),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Happy Notes',
      theme: ThemeData(
        fontFamily: AppConfig.fontFamily,
        textTheme: Theme.of(context).textTheme.apply(fontFamily: AppConfig.fontFamily).copyWith(
              titleLarge: const TextStyle(fontSize: 19.0),
              titleMedium: const TextStyle(fontSize: 17.0),
              titleSmall: const TextStyle(fontSize: 15.0),
              bodyLarge: const TextStyle(fontSize: 16.0),
              bodyMedium: const TextStyle(fontSize: 14.0),
              bodySmall: const TextStyle(fontSize: 12.0),
            ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Show main menu if already logged in, otherwise show login page
      home: const InitialPage(),
      onGenerateRoute: generatePublicNoteRoute,
      navigatorObservers: [UserSession.routeObserver],
    );
  }
}
