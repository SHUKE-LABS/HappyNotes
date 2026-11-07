import 'package:happy_notes/apis/account_api.dart';
import 'package:happy_notes/apis/client_version_policy_api.dart';
import 'package:happy_notes/apis/ember_user_account_api.dart';
import 'package:happy_notes/apis/file_uploader_api.dart';
import 'package:happy_notes/apis/user_settings_api.dart';
import 'package:happy_notes/screens/new_note/new_note_controller.dart';
import 'package:happy_notes/screens/settings/ember_sync_settings_controller.dart';
import 'package:happy_notes/screens/settings/mastodon_sync_settings_controller.dart';
import 'package:happy_notes/screens/settings/fanfou_sync_settings_controller.dart';
import 'package:happy_notes/screens/settings/telegram_sync_settings_controller.dart';
import 'package:happy_notes/screens/settings/settings_controller.dart';
import 'package:happy_notes/screens/components/controllers/tag_cloud_controller.dart';
import 'package:happy_notes/services/account_service.dart';
import 'package:happy_notes/services/client_version_update_service.dart';
import 'package:happy_notes/services/clipboard_service.dart';
import 'package:happy_notes/services/google_auth_service.dart';
import 'package:happy_notes/services/image_service.dart';
import 'package:happy_notes/services/mastodon_application_service.dart';
import 'package:happy_notes/services/mastodon_service.dart';
import 'package:happy_notes/services/mastodon_user_account_service.dart';
import 'package:happy_notes/services/fanfou_service.dart';
import 'package:happy_notes/services/fanfou_user_account_service.dart';
import 'package:happy_notes/services/note_tag_service.dart';
import 'package:happy_notes/services/draft_service.dart';
import 'package:happy_notes/services/ember_user_account_service.dart';
import 'package:happy_notes/services/notes_services.dart';
import 'package:get_it/get_it.dart';
import 'package:happy_notes/services/telegram_settings_service.dart';
import 'package:happy_notes/services/user_settings_service.dart';
import 'package:happy_notes/utils/token_utils.dart';
import 'package:happy_notes/screens/components/controllers/html_to_markdown_converter.dart';

import 'apis/mastodon_application_api.dart';
import 'apis/mastodon_user_account_api.dart';
import 'apis/fanfou_user_account_api.dart';
import 'apis/note_tag_api.dart';
import 'apis/telegram_settings_api.dart';

final locator = GetIt.instance;

void init() {
  _registerUtils();
  _registerApis();
  _registerServices();
  _registerProviders();
  _registerControllers();
}

void _registerApis() {
  locator.registerLazySingleton(() => NoteTagApi());
  locator.registerLazySingleton(() => FileUploaderApi());
  locator.registerLazySingleton(() => AccountApi());
  locator.registerLazySingleton(() => ClientVersionPolicyApi());
  locator.registerLazySingleton(() => UserSettingsApi());
  locator.registerLazySingleton(() => EmberUserAccountApi());
  locator.registerLazySingleton(() => TelegramSettingsApi());
  locator.registerLazySingleton(() => MastodonApplicationApi());
  locator.registerLazySingleton(() => MastodonUserAccountApi());
  locator.registerLazySingleton(() => FanfouUserAccountApi());
}

void _registerServices() {
  locator.registerLazySingleton(() => NoteTagService(noteTagApi: locator()));
  locator.registerLazySingleton(() => NotesService());
  locator.registerLazySingleton(() => DraftService());
  locator.registerLazySingleton(() => HtmlToMarkdownConverter());
  locator.registerLazySingleton(() => ClipboardService());
  locator.registerLazySingleton(() => ImageService());
  locator.registerLazySingleton(() => GoogleAuthService());
  locator.registerLazySingleton(() => AccountService(
        accountApi: locator(),
        userSettingsService: locator(),
        tokenUtils: locator(),
      ));
  locator.registerLazySingleton(
    () => ClientVersionUpdateService(policyApi: locator()),
  );
  locator.registerLazySingleton(() => UserSettingsService(userSettingsApi: locator()));
  locator.registerLazySingleton(() => EmberUserAccountService(emberUserAccountApi: locator()));
  locator.registerLazySingleton(() => TelegramSettingsService(telegramSettingsApi: locator()));
  locator.registerLazySingleton(() => MastodonApplicationService(mastodonApplicationApi: locator()));
  locator.registerLazySingleton(() => MastodonUserAccountService(mastodonUserAccountApi: locator()));
  locator.registerLazySingleton(
      () => MastodonService(mastodonApplicationService: locator(), mastodonUserAccountService: locator()));
  locator.registerLazySingleton(() => FanfouUserAccountService(fanfouUserAccountApi: locator()));
  locator.registerLazySingleton(() => FanfouService(fanfouUserAccountService: locator()));

  // Note: NoteUpdateCoordinator will be registered later in main.dart
  // after AppStateProvider is created, due to circular dependency
}

void _registerControllers() {
  locator.registerFactory(() => SettingsController(
        accountService: locator(),
        userSettingsService: locator(),
      ));
  locator.registerLazySingleton(() => TelegramSyncSettingsController(telegramSettingService: locator()));
  locator.registerLazySingleton(() => EmberSyncSettingsController(emberUserAccountService: locator()));
  locator.registerLazySingleton(() => MastodonSyncSettingsController(mastodonUserAccountService: locator()));
  locator.registerLazySingleton(() => FanfouSyncSettingsController(fanfouUserAccountService: locator()));
  locator.registerFactory(() => NewNoteController());
  locator.registerFactory(() => TagCloudController());
}

void _registerProviders() {
  // Register providers for dependency injection when needed
  // Note: Providers will be created via MultiProvider in main.dart
}

void _registerUtils() {
  locator.registerLazySingleton(() => TokenUtils());
}
