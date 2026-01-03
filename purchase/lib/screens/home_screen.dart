import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import '../services/delta_sync_service.dart';
import '../main.dart';
import 'login_screen.dart';
import 'manufacturers_screen.dart';
import 'vendors_screen.dart';
import 'materials_screen.dart';
import 'manufacturer_materials_screen.dart';
import 'vendor_price_lists_screen.dart';
import 'purchase_orders_screen.dart';
import 'baskets_screen.dart';
import 'import_data_screen.dart';
import 'sync_debug_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  final _deltaSyncService = DeltaSyncService.instance;
  bool _isDeltaSyncing = false;
  DateTime? _lastDeltaSyncTime;
  bool _hasShownFirstLoginSync = false;
  bool _hasShownFirstTimeImportDialog = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLoginStatus();
    _loadLastSyncTime();
    _checkForFirstTimeImport();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route observer
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when a route has been popped and this route is now visible
    _checkForPendingChangesAndSync();
  }

  Future<void> _checkLoginStatus() async {
    final webAppUrl = await _deltaSyncService.getWebAppUrl();
    final secretCode = await _deltaSyncService.getSecretCode();
    setState(() {
      _isLoggedIn = webAppUrl != null && secretCode != null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForPendingChangesAndSync();
    }
  }

  Future<void> _checkForPendingChangesAndSync() async {
    // Only check if logged in and not already syncing
    if (!_isLoggedIn || _isDeltaSyncing) return;

    final dbHelper = DatabaseHelper.instance;
    final hasPending = await dbHelper.hasPendingChanges();

    if (hasPending && mounted) {
      // Auto-trigger sync in background without dialog
      await _performDeltaSync(showProgressDialog: false);
    }
  }

  Future<void> _loadLastSyncTime() async {
    final lastDeltaSync = await _deltaSyncService.getLastSyncTime();
    setState(() {
      _lastDeltaSyncTime = lastDeltaSync;
    });

    // Show first-time sync popup if this is the first login and user is logged in
    if (_isLoggedIn &&
        lastDeltaSync == null &&
        !_hasShownFirstLoginSync &&
        mounted) {
      _hasShownFirstLoginSync = true;
      // Use addPostFrameCallback to show dialog after build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFirstLoginSyncDialog();
      });
    }
  }

  Future<void> _checkForFirstTimeImport() async {
    // Only show if not logged in and haven't shown before
    if (_isLoggedIn || _hasShownFirstTimeImportDialog) return;

    // Check if database is empty
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    // Check if any of the main tables have data
    final manufacturersCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM manufacturers')) ??
        0;

    final vendorsCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM vendors')) ??
        0;

    final materialsCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM materials')) ??
        0;

    final hasData =
        manufacturersCount > 0 || vendorsCount > 0 || materialsCount > 0;

    if (!hasData && mounted) {
      _hasShownFirstTimeImportDialog = true;
      // Use addPostFrameCallback to show dialog after build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFirstTimeImportDialog();
      });
    }
  }

  Future<void> _showFirstTimeImportDialog() async {
    if (!mounted) return;

    final shouldImport = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome!'),
        content: const Text(
          'Your database is empty. Would you like to import sample data to get started? '
          'This will add sample manufacturers, vendors, materials, and price lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import Sample Data'),
          ),
        ],
      ),
    );

    if (shouldImport == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ImportDataScreen()),
      );
    }
  }

  Future<void> _showFirstLoginSyncDialog() async {
    if (!mounted) return;

    final shouldSync = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome!'),
        content: const Text(
          'Would you like to download data from Google Sheets now? '
          'This will sync all manufacturers, vendors, materials, and price lists to your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );

    if (shouldSync == true && mounted) {
      await _performDeltaSync();
    }
  }

  Future<void> _performDeltaSync({bool showProgressDialog = true}) async {
    final hasCredentials = await _deltaSyncService.getWebAppUrl() != null &&
        await _deltaSyncService.getSecretCode() != null;

    if (!hasCredentials) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync credentials not configured'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isDeltaSyncing = true;
    });

    // Show progress dialog only if requested
    if (showProgressDialog && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _SyncProgressDialog(),
      );
    }

    try {
      final result = await _deltaSyncService.deltaSync(
        onProgress: (message) {
          // Update dialog content via setState in dialog
          if (showProgressDialog && mounted) {
            final dialog =
                context.findAncestorStateOfType<_SyncProgressDialogState>();
            dialog?.updateMessage(message);
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDeltaSyncing = false;
          _lastDeltaSyncTime = result.timestamp;
        });

        // Close progress dialog if it was shown
        if (showProgressDialog) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Delta sync complete: Downloaded ${result.downloaded}, Uploaded ${result.uploaded}'
                  : 'Delta sync failed: ${result.error}',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeltaSyncing = false;
        });

        // Close progress dialog if it was shown
        if (showProgressDialog) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delta sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleLogin() async {
    // Navigate to login screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    // If login was successful, refresh login status
    if (result == true && mounted) {
      // Clear all local data to avoid collision with synced data
      await _clearAllData(context);

      await _checkLoginStatus();
      await _loadLastSyncTime();
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'This will clear your sync credentials. You will need to enter them again to sync. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Clear credentials from sync metadata
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.setSyncMetadata('web_app_url', '');
      await dbHelper.setSyncMetadata('secret_code', '');

      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _lastDeltaSyncTime = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Purchase Application'),
            if (_lastDeltaSyncTime != null)
              Text(
                'Last sync: ${DateFormat('MMM d, h:mm a').format(_lastDeltaSyncTime!)}',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'sync':
                  if (_isLoggedIn) _performDeltaSync();
                  break;
                case 'debug':
                  if (_isLoggedIn) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SyncDebugScreen()),
                    );
                  }
                  break;
                case 'import':
                  if (!_isLoggedIn) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ImportDataScreen()),
                    );
                  }
                  break;
                case 'clear':
                  _showClearDataDialog(context);
                  break;
                case 'login':
                  _handleLogin();
                  break;
                case 'logout':
                  _handleLogout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'sync',
                enabled: _isLoggedIn && !_isDeltaSyncing,
                child: Row(
                  children: [
                    _isDeltaSyncing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.sync,
                            color: _isLoggedIn ? null : Colors.grey),
                    const SizedBox(width: 12),
                    Text('Sync with Google Sheets',
                        style:
                            TextStyle(color: _isLoggedIn ? null : Colors.grey)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'debug',
                enabled: _isLoggedIn,
                child: Row(
                  children: [
                    Icon(Icons.bug_report,
                        color: _isLoggedIn ? Colors.orange : Colors.grey),
                    const SizedBox(width: 12),
                    Text('Sync Log',
                        style:
                            TextStyle(color: _isLoggedIn ? null : Colors.grey)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'import',
                enabled: !_isLoggedIn,
                child: Row(
                  children: [
                    Icon(Icons.upload_file,
                        color: !_isLoggedIn ? null : Colors.grey),
                    const SizedBox(width: 12),
                    Text('Import Sample Data',
                        style: TextStyle(
                            color: !_isLoggedIn ? null : Colors.grey)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep),
                    SizedBox(width: 12),
                    Text('Clear All Data'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: _isLoggedIn ? 'logout' : 'login',
                child: Row(
                  children: [
                    Icon(_isLoggedIn ? Icons.logout : Icons.login),
                    const SizedBox(width: 12),
                    Text(_isLoggedIn ? 'Logout' : 'Login'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildMenuCard(
            context,
            'Manufacturers',
            Icons.business,
            Colors.blue,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManufacturersScreen()),
            ),
          ),
          _buildMenuCard(
            context,
            'Vendors',
            Icons.store,
            Colors.green,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorsScreen()),
            ),
          ),
          _buildMenuCard(
            context,
            'Materials',
            Icons.inventory,
            Colors.orange,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MaterialsScreen()),
            ),
          ),
          _buildMenuCard(
            context,
            'Manufacturer Materials',
            Icons.category,
            Colors.purple,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ManufacturerMaterialsScreen()),
            ),
          ),
          _buildMenuCard(
            context,
            'Vendor Price Lists',
            Icons.price_check,
            Colors.teal,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorPriceListsScreen()),
            ),
          ),
          _buildMenuCard(
            context,
            'Baskets',
            Icons.shopping_basket,
            Colors.deepOrange,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BasketsScreen()),
            ),
          ),
          _buildMenuCard(
            context,
            'Purchase Orders',
            Icons.shopping_cart,
            Colors.red,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear All Data'),
          content: const Text(
            'This will permanently delete all data from the database including:\n\n'
            '• Manufacturers\n'
            '• Vendors\n'
            '• Materials\n'
            '• Manufacturer Materials\n'
            '• Vendor Price Lists\n'
            '• Purchase Orders\n\n'
            'This action cannot be undone. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _clearAllData(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAllData(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('All data has been cleared successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error clearing data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress dialog for sync operations with live updates
class _SyncProgressDialog extends StatefulWidget {
  const _SyncProgressDialog();

  @override
  State<_SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends State<_SyncProgressDialog> {
  String _message = 'Starting sync...';
  final List<String> _messageHistory = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void updateMessage(String message) {
    if (mounted) {
      setState(() {
        _message = message;
        _messageHistory.add(message);

        // Auto-scroll to bottom when new message arrives
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('Syncing'),
          const Spacer(),
          Text(
            '${_messageHistory.length} steps',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            // Current message prominently displayed
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Message history
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: _messageHistory.length,
                itemBuilder: (context, index) {
                  final msg = _messageHistory[index];
                  final isLatest = index == _messageHistory.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    color: isLatest ? Colors.blue[50] : null,
                    child: Text(
                      msg,
                      style: TextStyle(
                        fontSize: 11,
                        color: isLatest ? Colors.blue[900] : Colors.grey[700],
                        fontWeight:
                            isLatest ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Note: Sync may take several minutes on first run',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SyncDebugScreen()),
            );
          },
          child: const Text('View Sync Log'),
        ),
        TextButton(
          onPressed: () {
            // Note: This won't actually cancel the sync in progress,
            // but will close the dialog so user can continue using app
            Navigator.of(context).pop();
          },
          child: const Text('Close Dialog'),
        ),
      ],
    );
  }
}
