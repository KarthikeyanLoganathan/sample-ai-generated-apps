import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/delta_sync_service.dart';
import '../screens/home_screen.dart';
import '../screens/import_data_screen.dart';
import '../screens/login_screen.dart';
import '../utils/app_helper.dart' as app_helper;
import '../widgets/common_overflow_menu.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _developerMode = false;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isSyncPaused = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkLoginStatus();
    _loadSyncPauseState();
  }

  Future<void> _loadSyncPauseState() async {
    final isPaused = await app_helper.isSyncPaused();
    setState(() {
      _isSyncPaused = isPaused;
    });
  }

  Future<void> _checkLoginStatus() async {
    final syncService = DeltaSyncService.instance;
    final webAppUrl = await syncService.getWebAppUrl();
    final secretCode = await syncService.getSecretCode();
    setState(() {
      _isLoggedIn = webAppUrl != null &&
          webAppUrl.isNotEmpty &&
          secretCode != null &&
          secretCode.isNotEmpty;
    });
  }

  Future<void> _loadSettings() async {
    final dbHelper = DatabaseHelper.instance;
    final developerModeValue = await dbHelper.getLocalSetting('developer-mode');
    setState(() {
      _developerMode = developerModeValue == 'TRUE';
      _isLoading = false;
    });
  }

  Future<void> _toggleDeveloperMode(bool value) async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.setLocalSetting('developer-mode', value ? 'TRUE' : 'FALSE');
    setState(() {
      _developerMode = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Developer mode enabled' : 'Developer mode disabled',
          ),
          backgroundColor: value ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _importSampleData() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportDataScreen()),
    );
  }

  Future<void> _clearAllData() async {
    // Build the table list dynamically from the displayNames map
    final tableList =
        TableNames.displayNames.values.map((name) => '• $name').join('\n');

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: Text(
          'This will permanently delete all data from the database including:\n\n'
          '$tableList\n\n'
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (shouldClear == true && mounted) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Clearing database...'),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        final dbHelper = DatabaseHelper.instance;
        await dbHelper.clearAllData();

        // Clear last sync timestamp
        await dbHelper.deleteLocalSetting('last_sync_timestamp');

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data has been cleared successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        // Close loading dialog if still open
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing data: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _login() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    // If login was successful, refresh login status
    if (result == true && mounted) {
      await _checkLoginStatus();
    }
  }

  Future<void> _logout() async {
    // Check for pending sync changes
    final dbHelper = DatabaseHelper.instance;
    final hasPending = await dbHelper.hasPendingChanges();

    String logoutMessage =
        'Are you sure you want to logout? This will clear your sync credentials';
    if (hasPending) {
      logoutMessage +=
          ' and you have unsynced changes that will remain on this device';
    }
    logoutMessage += '.';

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(logoutMessage),
            if (hasPending) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have pending changes that are not synced!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Logout',
              style: TextStyle(color: hasPending ? Colors.orange : null),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Clear database and credentials
      await dbHelper.clearAllData();
      await dbHelper.setLocalSetting('web_app_url', '');
      await dbHelper.setLocalSetting('secret_code', '');

      if (mounted) {
        // Navigate to home screen and replace the entire stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _handleLoginLogout() {
    if (_isLoggedIn) {
      _logout();
    } else {
      _login();
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncService = DeltaSyncService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          CommonOverflowMenu(
            isLoggedIn: _isLoggedIn,
            isDeltaSyncing: syncService.isSyncing,
            isSyncPaused: _isSyncPaused,
            isDeveloperMode: _developerMode,
            onMenuItemSelected: (value) async {
              await handleCommonMenuAction(
                context,
                value,
                onRefreshState: () async {
                  if (value == 'toggle_sync_pause') {
                    await _loadSyncPauseState();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Developer Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Developer Mode'),
                  subtitle: const Text(
                    'Enable additional menu options for debugging and data management',
                  ),
                  value: _developerMode,
                  onChanged: _toggleDeveloperMode,
                  secondary: const Icon(Icons.developer_mode),
                ),
                if (_developerMode) ...[
                  ListTile(
                    leading: Icon(Icons.upload_file,
                        color: _isLoggedIn ? Colors.grey : Colors.blue),
                    title: const Text('Import Sample Data'),
                    subtitle: Text(_isLoggedIn
                        ? 'Disabled when sync credentials are configured'
                        : 'Load sample data for testing'),
                    enabled: !_isLoggedIn,
                    onTap: _isLoggedIn ? null : _importSampleData,
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('Clear All Data'),
                    subtitle:
                        const Text('Permanently delete all data from database'),
                    onTap: _clearAllData,
                  ),
                ],
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    _isLoggedIn ? Icons.logout : Icons.login,
                    color: _isLoggedIn ? Colors.red : Colors.green,
                  ),
                  title: Text(_isLoggedIn ? 'Logout' : 'Login'),
                  subtitle: Text(
                    _isLoggedIn
                        ? 'Clear sync credentials and logout'
                        : 'Login to sync with Google Sheets',
                  ),
                  onTap: _handleLoginLogout,
                ),
              ],
            ),
    );
  }
}

// Widget Preview for VS Code
class SettingsScreenPreview extends StatelessWidget {
  const SettingsScreenPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SettingsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
