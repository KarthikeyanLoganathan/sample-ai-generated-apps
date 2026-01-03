import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'database_helper.dart';
import '../config/sync_config.dart';

/// Callback for sync progress updates
typedef DeltaSyncProgressCallback = void Function(String message);

class DeltaSyncService {
  static final DeltaSyncService instance = DeltaSyncService._internal();
  factory DeltaSyncService() => instance;
  DeltaSyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _webAppUrlKey = 'web_app_url';
  static const String _secretCodeKey = 'secret_code';

  bool _isSyncing = false;

  // Logger instance for structured logging
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  // Debug logging
  final List<String> _debugLogs = [];
  bool enableDebugLogging = true;

  /// Check if sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Get debug logs for troubleshooting
  List<String> getDebugLogs() => List.unmodifiable(_debugLogs);

  /// Clear debug logs
  void clearDebugLogs() => _debugLogs.clear();

  /// Add debug log entry
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';
    if (enableDebugLogging) {
      _logger.d(message);
      _debugLogs.add(logEntry);
      if (_debugLogs.length > 500) {
        _debugLogs.removeRange(0, _debugLogs.length - 500);
      }
    }
  }

  /// Get saved web app URL
  Future<String?> getWebAppUrl() async {
    return await _dbHelper.getSyncMetadata(_webAppUrlKey);
  }

  /// Get saved secret code
  Future<String?> getSecretCode() async {
    return await _dbHelper.getSyncMetadata(_secretCodeKey);
  }

  /// Save sync credentials
  Future<void> saveCredentials(String webAppUrl, String secretCode) async {
    await _dbHelper.setSyncMetadata(_webAppUrlKey, webAppUrl);
    await _dbHelper.setSyncMetadata(_secretCodeKey, secretCode);
  }

  /// Validate credentials by making a test API call
  Future<bool> validateCredentials(String webAppUrl, String secretCode) async {
    try {
      final response = await http
          .post(
            Uri.parse(webAppUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'secret': secretCode,
              'operation': 'login',
            }),
          )
          .timeout(const Duration(seconds: 10));

      _log('Login response status: ${response.statusCode}');

      // Handle response with redirect support (same as _handleResponse)
      final data = await _handleResponse(response);

      // Check for error in response
      if (data['error'] != null) {
        _log('Login failed with error: ${data['error']}');
        return false;
      }

      return data['success'] == true;
    } catch (e) {
      _log('Credential validation error: $e');
      return false;
    }
  }

  /// Perform delta sync using change_log
  Future<DeltaSyncResult> deltaSync(
      {DeltaSyncProgressCallback? onProgress}) async {
    clearDebugLogs();

    final webAppUrl = await getWebAppUrl();
    final secretCode = await getSecretCode();

    if (webAppUrl == null || secretCode == null) {
      return DeltaSyncResult(
        success: false,
        error: 'Sync credentials not configured',
      );
    }

    if (_isSyncing) {
      return DeltaSyncResult(
        success: false,
        error: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    final result = DeltaSyncResult();
    final syncStartTime = DateTime.now();
    _log('========== DELTA SYNC START ==========');
    _log('Timestamp: ${DateTime.now()}');

    try {
      final lastSync = await _dbHelper.getSyncMetadata(_lastSyncKey);

      // PULL: Get changes from server
      _log('Starting DELTA PULL phase');
      onProgress?.call('📥 Pulling changes from server...');
      final pullResult = await _pullDeltaChanges(
        lastSync,
        webAppUrl,
        secretCode,
        onProgress: onProgress,
      );
      result.downloaded = pullResult.downloaded;
      result.errors.addAll(pullResult.errors);

      // PUSH: Send local changes to server
      if (lastSync != null) {
        _log('Starting DELTA PUSH phase');
        onProgress?.call('📤 Pushing local changes to server...');
        final pushResult = await _pushDeltaChanges(
          lastSync,
          webAppUrl,
          secretCode,
          onProgress: onProgress,
        );
        result.uploaded = pushResult.uploaded;
        result.errors.addAll(pushResult.errors);
      } else {
        _log('Skipping DELTA PUSH phase - first sync');
        onProgress?.call('⏭️ Skipping push (first sync)');
      }

      // Update last sync timestamp
      final newSyncTimestamp = DateTime.now().toUtc().toIso8601String();
      await _dbHelper.setSyncMetadata(_lastSyncKey, newSyncTimestamp);

      result.success = true;
      result.timestamp = DateTime.now();

      final syncDuration = DateTime.now().difference(syncStartTime);
      _log('========== DELTA SYNC COMPLETE ==========');
      _log('Duration: ${syncDuration.inSeconds}s');
      _log('Downloaded: ${result.downloaded}');
      _log('Uploaded: ${result.uploaded}');
      _log('Errors: ${result.errors.length}');
      _log('==========================================');

      onProgress?.call('✅ Delta sync complete! (${syncDuration.inSeconds}s)');
    } catch (e) {
      _log('ERROR: Delta sync failed - $e');
      result.error = e.toString();
    } finally {
      _isSyncing = false;
    }

    return result;
  }

  /// Pull delta changes from server using change_log with pagination
  Future<DeltaSyncResult> _pullDeltaChanges(
    String? sinceTimestamp,
    String webAppUrl,
    String secretCode, {
    DeltaSyncProgressCallback? onProgress,
  }) async {
    final result = DeltaSyncResult();
    final url = Uri.parse(webAppUrl);
    const int pageSize = 200;
    int offset = 0;
    int totalRecords = 0;
    bool hasMore = true;

    try {
      while (hasMore) {
        final requestBody = {
          'operation': 'delta_pull',
          'secret': secretCode,
          'offset': offset,
          'limit': pageSize,
        };

        if (sinceTimestamp != null) {
          requestBody['since'] = sinceTimestamp;
        }

        _log('Pulling changes: offset=$offset, limit=$pageSize');
        onProgress?.call(
            '📥 Pulling changes... (${offset + 1}-${offset + pageSize})');

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        );

        dynamic data = await _handleResponse(response);

        if (data['error'] != null) {
          throw Exception(data['error']);
        }

        final log = data['log'] as List? ?? [];
        totalRecords = (data['totalRecords'] as num?)?.toInt() ?? 0;
        final tableRecords =
            data['tableRecords'] as Map<String, dynamic>? ?? {};

        _log(
            'Received ${log.length} changes out of $totalRecords total (offset: $offset)');

        if (log.isEmpty) {
          hasMore = false;
          break;
        }

        // Process this batch of changes
        final batchProcessed =
            await _processPullBatch(log, tableRecords, onProgress);
        result.downloaded += batchProcessed;

        // Update offset for next iteration
        offset += log.length;

        // Check if we've processed all records
        if (offset >= totalRecords) {
          hasMore = false;
        }

        // Small delay to avoid overwhelming the server
        if (hasMore) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      _log('Pull complete: downloaded ${result.downloaded} records');
    } catch (e) {
      _log('ERROR in delta pull: $e');
      result.errors.add('Delta pull: $e');
    }

    return result;
  }

  /// Process a batch of pulled changes
  Future<int> _processPullBatch(
    List<dynamic> log,
    Map<String, dynamic> tableRecords,
    DeltaSyncProgressCallback? onProgress,
  ) async {
    int processed = 0;

    // Group changes by table for efficient processing
    final changesByTable = <int, List<Map<String, dynamic>>>{};
    for (final change in log) {
      final tableIndex = change['table_index'] as int;
      changesByTable.putIfAbsent(tableIndex, () => []).add(change);
    }

    // Process changes in table dependency order
    final sortedTableIndices = changesByTable.keys.toList()..sort();

    for (final tableIndex in sortedTableIndices) {
      final tableChanges = changesByTable[tableIndex];
      if (tableChanges == null || tableChanges.isEmpty) continue;

      final tableName = SyncConfig.getTableName(tableIndex);
      if (tableName == null) continue;

      _log('Processing ${tableChanges.length} changes for $tableName');
      onProgress
          ?.call('📥 Processing $tableName (${tableChanges.length} changes)');

      for (final change in tableChanges) {
        try {
          final changeMode = change['change_mode'] as String;
          final key = change['table_key_uuid'] as String;

          if (changeMode == SyncConfig.changeModeDelete || changeMode == 'D') {
            // Delete record locally - directly call table-specific delete
            await _deleteRecord(tableName, key);
            processed++;
          } else {
            // Insert or update - get record from tableRecords
            final record = tableRecords[tableName]?[key];
            if (record != null) {
              await _upsertRecord(tableName, record);
              processed++;
            }
          }
        } catch (e) {
          _log('ERROR processing change for $tableName: $e');
          // Note: errors are logged but don't stop processing
        }
      }
    }

    return processed;
  }

  /// Push delta changes to server using local change_log with pagination
  Future<DeltaSyncResult> _pushDeltaChanges(
    String sinceTimestamp,
    String webAppUrl,
    String secretCode, {
    DeltaSyncProgressCallback? onProgress,
  }) async {
    final result = DeltaSyncResult();
    final url = Uri.parse(webAppUrl);
    const int pageSize = 200;

    try {
      // Get total count of local changes
      final changeLog = await _dbHelper.getChangeLog(sinceTimestamp);

      if (changeLog.isEmpty) {
        _log('No local changes to push');
        return result;
      }

      _log('Pushing ${changeLog.length} local changes in batches of $pageSize');

      // Process in batches
      for (int offset = 0; offset < changeLog.length; offset += pageSize) {
        final batch = changeLog.skip(offset).take(pageSize).toList();

        _log('Pushing batch: offset=$offset, count=${batch.length}');
        onProgress?.call(
            '📤 Uploading changes... (${offset + 1}-${offset + batch.length})');

        // Prepare batch data
        final batchData = await _preparePushBatch(batch);

        // Push batch to server
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'operation': 'delta_push',
            'secret': secretCode,
            'log': batchData['log'],
            'tableRecords': batchData['tableRecords'],
          }),
        );

        dynamic data = await _handleResponse(response);

        if (data['error'] != null) {
          throw Exception(data['error']);
        }

        final processed = (data['processed'] as num?)?.toInt() ?? batch.length;
        result.uploaded += processed;

        // Small delay between batches
        if (offset + pageSize < changeLog.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // Clear processed change log entries
      if (changeLog.isNotEmpty) {
        final latestTimestamp = changeLog
            .map((c) => c['updated_at'] as String)
            .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
        await _dbHelper.clearChangeLog(latestTimestamp);
      }

      _log('Successfully pushed ${result.uploaded} changes');
    } catch (e) {
      _log('ERROR in delta push: $e');
      result.errors.add('Delta push: $e');
    }

    return result;
  }

  /// Prepare a batch of changes for push
  Future<Map<String, dynamic>> _preparePushBatch(
      List<Map<String, dynamic>> batch) async {
    final log = <Map<String, dynamic>>[];
    final tableRecords = <String, Map<String, dynamic>>{};

    for (final change in batch) {
      final tableIndex = change['table_index'] as int;
      final key = change['table_key_uuid'] as String;
      final changeMode = change['change_mode'] as String;
      final tableName = SyncConfig.getTableName(tableIndex);

      if (tableName == null) continue;

      // Add to log
      log.add({
        'table_index': tableIndex,
        'table_key_uuid': key,
        'change_mode': changeMode,
        'updated_at': change['updated_at'],
      });

      // For insert/update, include the record data
      if (changeMode != SyncConfig.changeModeDelete) {
        final db = await _dbHelper.database;
        final records = await db.query(
          tableName,
          where: 'uuid = ?',
          whereArgs: [key],
          limit: 1,
        );

        if (records.isNotEmpty) {
          // Initialize table in tableRecords if needed
          if (!tableRecords.containsKey(tableName)) {
            tableRecords[tableName] = {};
          }
          tableRecords[tableName]![key] = records.first;
        }
      }
    }

    return {
      'log': log,
      'tableRecords': tableRecords,
    };
  }

  /// Handle HTTP response with redirect support
  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode == 302 || response.statusCode == 301) {
      final redirectMatch = RegExp(r'HREF="([^"]+)"').firstMatch(response.body);
      if (redirectMatch != null) {
        final redirectUrl = redirectMatch.group(1)!.replaceAll('&amp;', '&');
        final redirectResponse = await http.get(Uri.parse(redirectUrl));
        //POST → 301/302 → GET loses the request body. For API operations
        //like delta_pull and delta_push, the request body contains critical
        //data (operation type, secret, pagination params, etc.).
        //Converting POST to GET would break these operations
        //However, this might work for Google Apps Script specifically because:
        //Google Apps Script sometimes uses a unique redirect pattern
        //After POST processing, it redirects to a GET endpoint with the
        //JSON result already available
        //The redirect URL might already contain the response data

        if (redirectResponse.statusCode != 200) {
          throw Exception(
              'HTTP ${redirectResponse.statusCode}: ${redirectResponse.body}');
        }

        return json.decode(redirectResponse.body);
      }
    } else if (response.statusCode == 200) {
      return json.decode(response.body);
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  /// Insert or update a record in local database
  Future<void> _upsertRecord(String table, Map<String, dynamic> record) async {
    final db = await _dbHelper.database;
    final uuid = record['uuid'];

    if (uuid == null) return;

    // Get valid column names for this table
    final validColumns = await _getTableColumns(table);

    // Filter record to only include valid columns
    final filteredRecord = <String, dynamic>{};
    for (final key in record.keys) {
      if (validColumns.contains(key)) {
        filteredRecord[key] = record[key];
      }
    }

    final existing = await db.query(
      table,
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isEmpty) {
      // Insert new record
      await db.insert(table, filteredRecord);
    } else {
      // Update only if server record is newer
      final localUpdatedAt =
          DateTime.parse(existing.first['updated_at'] as String);
      final remoteUpdatedAt =
          DateTime.parse(filteredRecord['updated_at'] as String);

      if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
        await db.update(
          table,
          filteredRecord,
          where: 'uuid = ?',
          whereArgs: [uuid],
        );
      }
    }
  }

  /// Delete a record from local database
  Future<void> _deleteRecord(String table, String uuid) async {
    final db = await _dbHelper.database;

    // Direct deletion without tracking (since this is from remote sync)
    await db.delete(
      table,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Get column names for a table
  Future<Set<String>> _getTableColumns(String table) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('PRAGMA table_info($table)');
    return result.map((row) => row['name'] as String).toSet();
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = await _dbHelper.getSyncMetadata(_lastSyncKey);
    return timestamp != null ? DateTime.parse(timestamp).toLocal() : null;
  }
}

/// Result of a delta sync operation
class DeltaSyncResult {
  bool success;
  int downloaded;
  int uploaded;
  DateTime? timestamp;
  String? error;
  List<String> errors;

  DeltaSyncResult({
    this.success = false,
    this.downloaded = 0,
    this.uploaded = 0,
    this.timestamp,
    this.error,
    List<String>? errors,
  }) : errors = errors ?? [];

  @override
  String toString() {
    if (!success && error != null) {
      return 'Delta sync failed: $error';
    }
    return 'Delta synced: ↓$downloaded ↑$uploaded${errors.isNotEmpty ? ' (${errors.length} errors)' : ''}';
  }
}
