import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:happy_notes/services/seq_logger.dart';
import 'package:provider/provider.dart';
import 'package:happy_notes/screens/settings/ember_sync_settings.dart';
import 'package:happy_notes/screens/settings/mastodon_sync_settings.dart';
import 'package:happy_notes/screens/settings/fanfou_sync_settings.dart';
import 'package:happy_notes/screens/settings/settings_controller.dart';
import 'package:happy_notes/screens/settings/telegram_sync_settings.dart';
import 'package:happy_notes/screens/settings/profile_page.dart';
import 'package:happy_notes/entities/user.dart';
import 'package:happy_notes/apis/account_api.dart';
import 'package:happy_notes/providers/auth_provider.dart';

import '../../app_config.dart';
import '../../app_constants.dart';
import '../../dependency_injection.dart';
import '../../utils/timezone_helper.dart';
import '../../utils/app_version.dart';
import '../components/timezone_dropdown_item.dart';
import '../trash_bin/trash_bin_page.dart';

class Settings extends StatefulWidget {
  final VoidCallback? onLogout;

  const Settings({super.key, this.onLogout});

  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends State<Settings> {
  final SettingsController _settingsController = locator<SettingsController>();
  User? _currentUser;
  bool _isLoadingAvatar = true;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _fetchUserInfoForAvatar();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    if (kIsWeb) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = packageInfo;
        });
      }
    } catch (e, stackTrace) {
      SeqLogger.warning('Error loading package information: $e', e, stackTrace);
    }
  }

  Future<void> _fetchUserInfoForAvatar() async {
    // Don't fetch user info if not authenticated
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      if (mounted) {
        setState(() {
          _isLoadingAvatar = false;
          _currentUser = null;
        });
      }
      return;
    }

    setState(() {
      _isLoadingAvatar = true;
    });
    try {
      final user = await AccountApi.getMyInformation();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoadingAvatar = false;
        });
      }
    } catch (e) {
      SeqLogger.severe("Error fetching user info for avatar: $e");
      if (mounted) {
        setState(() {
          _isLoadingAvatar = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          _isLoadingAvatar
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: (_currentUser?.gravatar != null && _currentUser!.gravatar.isNotEmpty)
                      ? CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(_currentUser!.gravatar),
                          onBackgroundImageError: (_, __) {},
                          backgroundColor: Colors.grey[300],
                        )
                      : CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[300],
                          child: const Icon(Icons.person, size: 18),
                        ),
                  tooltip: 'Profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                    );
                  },
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        child: ListView(
          children: [
            ListTile(
              title: const Text('Page Size'),
              subtitle: const Text('Number of notes per page.'),
              trailing: DropdownButton<int>(
                value: AppConfig.pageSize,
                onChanged: (int? newValue) async {
                  if (newValue == null) return;
                  final result = await _settingsController.save(context, AppConstants.pageSize, newValue.toString());
                  if (result && mounted) {
                    setState(() {});
                  }
                },
                items: <int>[10, 20, 30, 40, 50, 60].map<DropdownMenuItem<int>>(
                  (int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(value.toString()),
                    );
                  },
                ).toList(),
              ),
            ),
            ListTile(
              title: const Text('Timezone'),
              trailing: SizedBox(
                width: 245,
                child: TimezoneDropdownItem(
                  items: TimezoneHelper.timezones,
                  value: AppConfig.timezone,
                  onChanged: (String? newValue) async {
                    if (newValue != null) {
                      final result = await _settingsController.save(context, AppConstants.timezone, newValue);
                      if (result && mounted) {
                        setState(() {});
                      }
                    }
                  },
                ),
              ),
            ),
            ListTile(
              title: const Text('Markdown'),
              subtitle: const Text('Format notes with Markdown.'),
              trailing: Switch(
                value: AppConfig.markdownIsEnabled,
                onChanged: (bool newValue) async {
                  final result =
                      await _settingsController.save(context, AppConstants.markdownIsEnabled, newValue ? "1" : "0");
                  if (result && mounted) {
                    setState(() {});
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('Private notes by default'),
              subtitle: const Text('New notes will be private by default.'),
              trailing: Switch(
                value: AppConfig.privateNoteOnlyIsEnabled,
                onChanged: (bool newValue) async {
                  final result = await _settingsController.save(
                      context, AppConstants.privateNoteOnlyIsEnabled, newValue ? "1" : "0");
                  if (result && mounted) {
                    setState(() {});
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('Telegram Sync'),
              subtitle: const Text('Sync notes to Telegram.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TelegramSyncSettings()),
                );
              },
            ),
            ListTile(
              title: const Text('Mastodon Sync'),
              subtitle: const Text('Sync notes to Mastodon.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MastodonSyncSettings()),
                );
              },
            ),
            ListTile(
              title: const Text('Fanfou Sync'),
              subtitle: const Text('Sync notes to Fanfou.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FanfouSyncSettings()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Ember Sync'),
              subtitle: const Text('Sync public notes to Ember.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmberSyncSettings(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Trash Bin'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrashBinPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_support),
              title: const Text('Contact Us'),
              subtitle: const Text('Get help and support'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showContactDialog(context),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                _packageInfo == null
                    ? 'Version: ${AppConfig.version}'
                    : buildVersionText(_packageInfo!),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final authProvider = context.read<AuthProvider>();
                  await authProvider.logout();
                  // Navigation will be handled automatically by InitialPage Consumer<AuthProvider>
                  // No need to call widget.onLogout
                },
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Contact Us',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('GitHub Repository'),
              subtitle: const Text('Source code and issue tracking'),
              onTap: () => _launchGitHub(context),
            ),
            ListTile(
              leading: const Icon(Icons.telegram),
              title: const Text('Telegram Support'),
              subtitle: const Text('Join our support group'),
              onTap: () => _launchTelegram(context),
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email Support'),
              subtitle: const Text('weizhong2004@gmail.com'),
              onTap: () => _launchEmail(context),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _launchGitHub(BuildContext context) async {
    const url = 'https://github.com/shukebeta/HappyNotes';
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch GitHub: $e')),
        );
      }
    }
  }

  Future<void> _launchTelegram(BuildContext context) async {
    const url = 'https://t.me/happynotes_support';
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch Telegram: $e')),
        );
      }
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    const url = 'mailto:weizhong2004@gmail.com?subject=Happy%20Notes%20Support';
    try {
      await launchUrlString(url);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch email client: $e')),
        );
      }
    }
  }
}
