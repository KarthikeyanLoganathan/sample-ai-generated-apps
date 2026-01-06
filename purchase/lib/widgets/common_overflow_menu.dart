import 'package:flutter/material.dart';
import '../utils/sync_helper.dart' as sync_helper;
import '../utils/database_browser_helper.dart';
import '../utils/app_helper.dart' as app_helper;
import '../screens/settings_screen.dart';

/// Reusable overflow menu widget for common app-wide menu items
///
/// This widget consolidates all common menu items (sync, debug, etc.) into a single
/// reusable component that can be used across all screens.
class CommonOverflowMenu extends StatelessWidget {
  /// Whether user is currently logged in
  final bool isLoggedIn;

  /// Whether delta sync is currently running
  final bool isDeltaSyncing;

  /// Whether sync is currently paused
  final bool isSyncPaused;

  /// Whether developer mode is enabled
  final bool isDeveloperMode;

  /// Optional screen-specific menu items to append
  final List<PopupMenuEntry<String>> additionalMenuItems;

  /// Callback when menu item is selected
  final Future<void> Function(String value) onMenuItemSelected;

  /// Callback to refresh screen state after menu actions
  final VoidCallback? onRefreshState;

  const CommonOverflowMenu({
    super.key,
    required this.isLoggedIn,
    required this.isDeltaSyncing,
    required this.isSyncPaused,
    required this.isDeveloperMode,
    required this.onMenuItemSelected,
    this.additionalMenuItems = const [],
    this.onRefreshState,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        await onMenuItemSelected(value);
        onRefreshState?.call();
      },
      itemBuilder: (context) => [
        // Settings
        const PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: 20, color: Colors.blue),
              SizedBox(width: 12),
              Text('Settings'),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // Sync with Google Sheets
        PopupMenuItem<String>(
          value: 'sync',
          enabled: isLoggedIn && !isDeltaSyncing,
          child: Row(
            children: [
              Icon(Icons.sync,
                  size: 20,
                  color: isLoggedIn && !isDeltaSyncing
                      ? Colors.blue
                      : Colors.grey),
              const SizedBox(width: 12),
              Text('Sync with Google Sheets',
                  style: TextStyle(
                      color:
                          isLoggedIn && !isDeltaSyncing ? null : Colors.grey)),
            ],
          ),
        ),

        // Stop Sync
        sync_helper.stopSyncMenuItemWidget(isSyncing: isDeltaSyncing),

        // Pause/Play Sync
        if (isLoggedIn)
          sync_helper.pausePlaySyncMenuItemWidget(isSyncPaused: isSyncPaused),

        // View Sync Log
        PopupMenuItem<String>(
          value: 'view_sync_log',
          enabled: isLoggedIn,
          child: Row(
            children: [
              Icon(Icons.list_alt,
                  size: 20, color: isLoggedIn ? Colors.blue : Colors.grey),
              const SizedBox(width: 12),
              Text('View Sync Log',
                  style: TextStyle(color: isLoggedIn ? null : Colors.grey)),
            ],
          ),
        ),

        // Developer mode items
        if (isDeveloperMode) ...[
          const PopupMenuDivider(),

          // Prepare Condensed Change Log
          const PopupMenuItem<String>(
            value: 'prepare_condensed_log',
            child: Row(
              children: [
                Icon(Icons.compress, size: 20, color: Colors.orange),
                SizedBox(width: 12),
                Text('Prepare Condensed Change Log'),
              ],
            ),
          ),

          const PopupMenuDivider(),

          // Data Statistics
          const PopupMenuItem<String>(
            value: 'data_statistics',
            child: Row(
              children: [
                Icon(Icons.analytics, size: 20, color: Colors.purple),
                SizedBox(width: 12),
                Text('Data Statistics'),
              ],
            ),
          ),

          // Data Browser
          const PopupMenuItem<String>(
            value: 'db_browser',
            child: Row(
              children: [
                Icon(Icons.storage, size: 20, color: Colors.teal),
                SizedBox(width: 12),
                Text('Data Browser'),
              ],
            ),
          ),
        ],

        // Additional screen-specific items
        ...additionalMenuItems,
      ],
    );
  }
}

/// Builder function to handle common menu actions
/// Returns true if action was handled, false if it should be handled by screen
Future<bool> handleCommonMenuAction(
  BuildContext context,
  String action, {
  required VoidCallback onRefreshState,
}) async {
  switch (action) {
    case 'settings':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      return true;

    case 'sync':
      await sync_helper.performDeltaSync(context);
      onRefreshState();
      return true;

    case 'stop_sync':
      sync_helper.stopSync(context);
      onRefreshState();
      return true;

    case 'toggle_sync_pause':
      await sync_helper.toggleSyncPauseWithFeedback(context);
      onRefreshState();
      return true;

    case 'view_sync_log':
      await sync_helper.openSyncLog(context);
      return true;

    case 'prepare_condensed_log':
      await sync_helper.prepareCondensedChangeLog(context);
      return true;

    case 'data_statistics':
      await app_helper.showDataStatistics(context);
      return true;

    case 'db_browser':
      openDatabaseBrowser(context);
      return true;

    default:
      return false; // Not a common action, let screen handle it
  }
}
