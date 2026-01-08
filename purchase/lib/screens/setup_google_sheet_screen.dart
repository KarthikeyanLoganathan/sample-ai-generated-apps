import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/script/v1.dart' as script;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/delta_sync_service.dart';

/// Screen for automating Google Sheets setup with Apps Script deployment
class SetupGoogleSheetScreen extends StatefulWidget {
  const SetupGoogleSheetScreen({super.key});

  @override
  State<SetupGoogleSheetScreen> createState() => _SetupGoogleSheetScreenState();
}

class _SetupGoogleSheetScreenState extends State<SetupGoogleSheetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sheetNameController = TextEditingController();
  final _appCodeController = TextEditingController();
  final _deltaSyncService = DeltaSyncService.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/script.projects',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  GoogleSignInAccount? _currentUser;
  bool _isLoading = false;
  String _statusMessage = '';
  String? _deployedWebAppUrl;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() {
        _currentUser = account;
        _isSignedIn = account != null;
      });
    });
    _googleSignIn.signInSilently();
  }

  @override
  void dispose() {
    _sheetNameController.dispose();
    _appCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Signing in to Google...';
      });

      await _googleSignIn.signIn();

      setState(() {
        _isLoading = false;
        _statusMessage = 'Successfully signed in!';
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Sign in failed: $error';
      });

      if (mounted) {
        // Show detailed error information and configuration instructions
        _showSignInErrorDialog(error.toString());
      }
    }
  }

  void _showSignInErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Sign-In Configuration Required'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'Google Sign-In requires Android configuration. Please follow these steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Go to Google Cloud Console\n'
                '2. Create or select a project\n'
                '3. Enable Google Sheets API and Apps Script API\n'
                '4. Create OAuth 2.0 credentials:\n'
                '   • Application type: Android\n'
                '   • Package name: com.example.purchase_app\n'
                '5. Get your SHA-1 certificate fingerprint:\n'
                '   Run: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android\n'
                '6. Add the SHA-1 to your OAuth client\n'
                '7. Download google-services.json\n'
                '8. Place it in android/app/\n\n'
                'Alternative: Use the manual setup option below.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualSetupInstructions();
            },
            child: const Text('Manual Setup Guide'),
          ),
        ],
      ),
    );
  }

  void _showManualSetupInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Google Sheets Setup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Follow these steps to set up Google Sheets manually:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Create a new Google Sheet\n'
                '2. Extensions → Apps Script\n'
                '3. Create a sheet named "config" with:\n'
                '   • Headers: name, value, description\n'
                '   • Row 2: APP_CODE, [your-secret-code], the secret\n'
                '4. Copy all files from backend-google-app-script-code/ to the Apps Script project\n'
                '5. Deploy as Web App:\n'
                '   • Execute as: Me\n'
                '   • Who has access: Anyone\n'
                '6. Copy the Web App URL\n'
                '7. In this app, go to Settings/Login and enter:\n'
                '   • Web App URL\n'
                '   • Your secret code (APP_CODE)\n'
                '8. Call the setup endpoint manually or use the setupSheets operation',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.signOut();
    setState(() {
      _statusMessage = '';
      _deployedWebAppUrl = null;
    });
  }

  Future<auth.AuthClient> _getAuthenticatedClient() async {
    final authentication = await _currentUser!.authentication;
    final credentials = auth.AccessCredentials(
      auth.AccessToken(
        'Bearer',
        authentication.accessToken!,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      [
        'https://www.googleapis.com/auth/spreadsheets',
        'https://www.googleapis.com/auth/script.projects',
        'https://www.googleapis.com/auth/drive.file',
      ],
    );
    return auth.authenticatedClient(http.Client(), credentials);
  }

  Future<void> _setupGoogleSheet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to Google first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Starting setup process...';
    });

    try {
      final sheetName = _sheetNameController.text.trim();
      final appCode = _appCodeController.text.trim();

      // Step 1: Create Google Sheet
      setState(() => _statusMessage = 'Creating Google Sheet...');
      final spreadsheetId = await _createGoogleSheet(sheetName);

      // Step 2: Create config sheet
      setState(() => _statusMessage = 'Setting up configuration sheet...');
      await _createConfigSheet(spreadsheetId, appCode);

      // Step 3: Get Apps Script project ID
      setState(() => _statusMessage = 'Accessing Apps Script project...');
      final scriptId = await _getScriptProjectId(spreadsheetId);

      // Step 4: Copy backend JavaScript files
      setState(() => _statusMessage = 'Deploying backend code...');
      await _copyBackendFiles(scriptId);

      // Step 5: Deploy as Web App
      setState(() => _statusMessage = 'Deploying Web App...');
      final webAppUrl = await _deployWebApp(scriptId);

      // Step 6: Setup sheets via Web App
      setState(() => _statusMessage = 'Initializing Google Sheets...');
      await _setupSheets(webAppUrl, appCode);

      // Step 7: Save credentials
      await _deltaSyncService.saveCredentials(webAppUrl, appCode);

      setState(() {
        _isLoading = false;
        _statusMessage = 'Setup completed successfully!';
        _deployedWebAppUrl = webAppUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sheets setup completed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Return success to trigger login-like behavior
        Navigator.pop(context, true);
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Setup failed: $error';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup failed: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<String> _createGoogleSheet(String sheetName) async {
    final client = await _getAuthenticatedClient();
    final sheetsApi = sheets.SheetsApi(client);

    final spreadsheet = sheets.Spreadsheet(
      properties: sheets.SpreadsheetProperties(title: sheetName),
    );

    final response = await sheetsApi.spreadsheets.create(spreadsheet);
    client.close();

    return response.spreadsheetId!;
  }

  Future<void> _createConfigSheet(String spreadsheetId, String appCode) async {
    final client = await _getAuthenticatedClient();
    final sheetsApi = sheets.SheetsApi(client);

    // Create a new sheet named "config"
    final addSheetRequest = sheets.Request(
      addSheet: sheets.AddSheetRequest(
        properties: sheets.SheetProperties(title: 'config'),
      ),
    );

    await sheetsApi.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: [addSheetRequest]),
      spreadsheetId,
    );

    // Add header and data rows
    final valueRange = sheets.ValueRange.fromJson({
      'values': [
        ['name', 'value', 'description'],
        ['APP_CODE', appCode, 'the secret'],
      ],
    });

    await sheetsApi.spreadsheets.values.update(
      valueRange,
      spreadsheetId,
      'config!A1:C2',
      valueInputOption: 'RAW',
    );

    client.close();
  }

  Future<String> _getScriptProjectId(String spreadsheetId) async {
    final client = await _getAuthenticatedClient();
    final scriptApi = script.ScriptApi(client);

    // Create a new Apps Script project bound to the spreadsheet
    final project = script.CreateProjectRequest(
      title: 'Purchase App Backend',
      parentId: spreadsheetId,
    );

    final createdProject = await scriptApi.projects.create(project);
    client.close();

    return createdProject.scriptId!;
  }

  Future<void> _copyBackendFiles(String scriptId) async {
    final client = await _getAuthenticatedClient();
    final scriptApi = script.ScriptApi(client);

    // Get list of all assets (try JSON first, then BIN)
    List<String> allAssets = [];

    try {
      // Try AssetManifest.json first
      final assetManifest = await rootBundle.loadString('AssetManifest.json');
      final manifestMap = jsonDecode(assetManifest) as Map<String, dynamic>;
      allAssets = manifestMap.keys.toList();
    } catch (e) {
      // AssetManifest.json not available, try .bin (Flutter 3.x+)
      try {
        final ByteData manifestData =
            await rootBundle.load('AssetManifest.bin');
        allAssets = await _decodeAssetManifestBin(manifestData);
      } catch (e2) {
        throw Exception('Failed to load asset manifest: $e2');
      }
    }

    // Filter for backend JS files
    final jsFiles = allAssets
        .where((key) =>
            key.startsWith('backend-google-app-script-code/') &&
            key.endsWith('.js'))
        .toList();

    if (jsFiles.isEmpty) {
      throw Exception('No backend JavaScript files found in assets');
    }

    // Load all JS files
    final List<script.File> files = [];
    for (final filePath in jsFiles) {
      final fileName = filePath.split('/').last.replaceAll('.js', '');
      final content = await rootBundle.loadString(filePath);

      files.add(script.File(
        name: fileName,
        type: 'SERVER_JS',
        source: content,
      ));
    }

    // Update the project content
    final content = script.Content(files: files);
    await scriptApi.projects.updateContent(content, scriptId);

    client.close();
  }

  /// Decode AssetManifest.bin format
  Future<List<String>> _decodeAssetManifestBin(ByteData data) async {
    final List<String> assets = [];

    try {
      final buffer = data.buffer.asUint8List();
      final List<int> currentString = [];

      for (int i = 0; i < buffer.length; i++) {
        final byte = buffer[i];

        if ((byte >= 32 && byte < 127) || byte == 0) {
          if (byte == 0 && currentString.isNotEmpty) {
            try {
              final str = utf8.decode(currentString);
              if (str.contains('/') || str.contains('.')) {
                assets.add(str);
              }
            } catch (e) {
              // Invalid UTF-8, skip
            }
            currentString.clear();
          } else if (byte != 0) {
            currentString.add(byte);
          }
        } else {
          if (currentString.isNotEmpty) {
            try {
              final str = utf8.decode(currentString);
              if (str.contains('/') || str.contains('.')) {
                assets.add(str);
              }
            } catch (e) {
              // Invalid UTF-8, skip
            }
          }
          currentString.clear();
        }
      }

      // Handle last string
      if (currentString.isNotEmpty) {
        try {
          final str = utf8.decode(currentString);
          if (str.contains('/') || str.contains('.')) {
            assets.add(str);
          }
        } catch (e) {
          // Invalid UTF-8, skip
        }
      }

      return assets.toSet().toList();
    } catch (e) {
      throw Exception('Error decoding AssetManifest.bin: $e');
    }
  }

  Future<String> _deployWebApp(String scriptId) async {
    final client = await _getAuthenticatedClient();
    final scriptApi = script.ScriptApi(client);

    // Create a version
    final versionRequest = script.Version(description: 'Initial deployment');
    final version =
        await scriptApi.projects.versions.create(versionRequest, scriptId);

    // Create deployment configuration
    final deployConfig = script.DeploymentConfig(
      scriptId: scriptId,
      versionNumber: version.versionNumber,
      manifestFileName: 'appsscript',
      description: 'Web App Deployment',
    );

    final deploy =
        await scriptApi.projects.deployments.create(deployConfig, scriptId);
    client.close();

    // Extract the web app URL from deployment
    final entryPoints = deploy.entryPoints;
    if (entryPoints != null && entryPoints.isNotEmpty) {
      final webAppEntry = entryPoints.firstWhere(
        (entry) => entry.entryPointType == 'WEB_APP',
        orElse: () => throw Exception('No Web App entry point found'),
      );
      return webAppEntry.webApp!.url!;
    }

    throw Exception('Failed to get Web App URL');
  }

  Future<void> _setupSheets(String webAppUrl, String appCode) async {
    int attempts = 0;
    const maxAttempts = 3;
    const timeout = Duration(seconds: 30);

    while (attempts < maxAttempts) {
      try {
        attempts++;
        setState(() => _statusMessage =
            'Initializing sheets (attempt $attempts/$maxAttempts)...');

        final response = await http
            .post(
              Uri.parse(webAppUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'secret': appCode,
                'operation': 'setupSheets',
              }),
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            return; // Success!
          } else {
            throw Exception(data['error'] ?? 'Setup failed');
          }
        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        if (attempts >= maxAttempts) {
          rethrow;
        }
        // Wait before retry
        await Future.delayed(Duration(seconds: 2 * attempts));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Google Sheets'),
        actions: [
          if (_isSignedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleSignOut,
              tooltip: 'Sign Out',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Google Sign-in Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Step 1: Google Sign-in',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_isSignedIn)
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleSignIn,
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        )
                      else
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Signed in as ${_currentUser?.email ?? "Unknown"}',
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Configuration Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Step 2: Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sheetNameController,
                        decoration: const InputDecoration(
                          labelText: 'Google Sheet Name',
                          hintText: 'e.g., Purchase App Data',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a sheet name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _appCodeController,
                        decoration: const InputDecoration(
                          labelText: 'App Code (Secret)',
                          hintText: 'Enter a secure code',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an app code';
                          }
                          if (value.trim().length < 8) {
                            return 'App code must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Setup Button
              ElevatedButton.icon(
                onPressed:
                    _isLoading || !_isSignedIn ? null : _setupGoogleSheet,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label:
                    Text(_isLoading ? 'Setting up...' : 'Setup Google Sheets'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 16),

              // Status Section
              if (_statusMessage.isNotEmpty)
                Card(
                  color: _isLoading
                      ? Colors.blue.shade50
                      : _statusMessage.contains('failed')
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (_isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            else if (_statusMessage.contains('failed'))
                              const Icon(Icons.error, color: Colors.red)
                            else
                              const Icon(Icons.check_circle,
                                  color: Colors.green),
                            const SizedBox(width: 12),
                            const Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_statusMessage),
                        if (_deployedWebAppUrl != null) ...[
                          const SizedBox(height: 8),
                          const Divider(),
                          const Text(
                            'Web App URL:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _deployedWebAppUrl!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Instructions
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Instructions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Sign in with your Google account\n'
                        '2. Enter a name for your Google Sheet\n'
                        '3. Create a secure app code (at least 8 characters)\n'
                        '4. Click "Setup Google Sheets"\n'
                        '5. Wait for the setup to complete\n\n'
                        'This will automatically:\n'
                        '• Create a new Google Sheet\n'
                        '• Deploy the backend Apps Script code\n'
                        '• Configure the sync service\n'
                        '• Save your credentials',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Configuration notice
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Android Configuration Required',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Google Sign-In requires OAuth configuration. If sign-in fails, you can:\n\n'
                        '1. Configure OAuth in Google Cloud Console (recommended)\n'
                        '2. Use the Manual Setup option instead\n\n'
                        'Tap the error message for detailed configuration steps.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
