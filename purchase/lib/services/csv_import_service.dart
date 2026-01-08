import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'database_helper.dart';
import '../models/currency.dart';
import '../models/unit_of_measure.dart';
import '../models/manufacturer.dart';
import '../models/vendor.dart';
import '../models/material.dart';
import '../models/manufacturer_material.dart';
import '../models/vendor_price_list.dart';
import '../models/project.dart';

class CsvImportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Map of table names to their model factory constructors
  /// This allows us to use the model's fromMap method which knows the correct types
  final Map<String, Function(Map<String, dynamic>)> _modelFactories = {
    'currencies': (map) => Currency.fromMap(map),
    'unit_of_measures': (map) => UnitOfMeasure.fromMap(map),
    'manufacturers': (map) => Manufacturer.fromMap(map),
    'vendors': (map) => Vendor.fromMap(map),
    'materials': (map) => Material.fromMap(map),
    'manufacturer_materials': (map) => ManufacturerMaterial.fromMap(map),
    'vendor_price_lists': (map) => VendorPriceList.fromMap(map),
    'projects': (map) => Project.fromMap(map),
  };

  /// Get list of CSV files from AssetManifest
  /// Properly decodes AssetManifest.bin (Flutter 3.x+) or AssetManifest.json (older)
  Future<List<String>> getCsvFiles() async {
    List<String> allAssets = [];

    // Try AssetManifest.json first (simpler and works in most cases)
    try {
      final String manifestContent =
          await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);

      allAssets = manifestMap.keys.toList();
      debugPrint('Loaded ${allAssets.length} assets from AssetManifest.json');
    } catch (e) {
      // AssetManifest.json not available (normal in Flutter 3.x+), try .bin
      try {
        // Try AssetManifest.bin (Flutter 3.x+)
        final ByteData manifestData =
            await rootBundle.load('AssetManifest.bin');
        allAssets = await _decodeAssetManifestBin(manifestData);
        debugPrint('Loaded ${allAssets.length} assets from AssetManifest.bin');
      } catch (e2) {
        debugPrint('Failed to load asset manifest: $e2');
        // Return hardcoded list as last resort
        debugPrint('Using hardcoded CSV list as fallback');
        return [
          'data/currencies.csv',
          'data/manufacturer_materials.csv',
          'data/manufacturers.csv',
          'data/materials.csv',
          'data/projects.csv',
          'data/unit_of_measures.csv',
          'data/vendor_price_lists.csv',
          'data/vendors.csv',
        ];
      }
    }

    // Filter for .csv files in the data directory
    final csvFiles = allAssets
        .where((String key) => key.startsWith('data/') && key.endsWith('.csv'))
        .toList();

    csvFiles.sort();
    debugPrint('Found ${csvFiles.length} CSV files: $csvFiles');
    return csvFiles;
  }

  /// Decode AssetManifest.bin format using a more robust approach
  Future<List<String>> _decodeAssetManifestBin(ByteData data) async {
    final List<String> assets = [];

    try {
      // AssetManifest.bin is a custom binary format
      // Try to extract asset paths by looking for valid UTF-8 strings
      final buffer = data.buffer.asUint8List();
      final List<int> currentString = [];

      for (int i = 0; i < buffer.length; i++) {
        final byte = buffer[i];

        // Check if this looks like a path character
        if ((byte >= 32 && byte < 127) || byte == 0) {
          if (byte == 0 && currentString.isNotEmpty) {
            // End of string
            try {
              final str = utf8.decode(currentString);
              // Check if it looks like a valid asset path
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
          // Non-ASCII character, reset
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

      // Handle last string if any
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

      // Remove duplicates
      return assets.toSet().toList();
    } catch (e) {
      debugPrint('Error decoding AssetManifest.bin: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> importFromAssets() async {
    debugPrint('===== IMPORT STARTING =====');
    final results = <String, int>{};
    final errors = <String>[];
    int totalImported = 0;
    int totalErrors = 0;

    try {
      // Dynamically discover all CSV files
      final csvFiles = await getCsvFiles();
      debugPrint('Found ${csvFiles.length} CSV files to import: $csvFiles');

      // Import each CSV file
      for (String csvFileName in csvFiles) {
        // Extract table name from file name: data/currencies.csv -> currencies
        final tableName =
            csvFileName.replaceFirst('data/', '').replaceFirst('.csv', '');

        debugPrint('Importing $csvFileName into table $tableName...');

        final result = await importSingleCsv(tableName, csvFileName);
        results[tableName] = result['imported'] as int;
        totalImported += result['imported'] as int;
        totalErrors += result['errors'] as int;

        if (result['error'] != null) {
          errors.add('$tableName: ${result['error']}');
        }
      }

      debugPrint(
          '===== IMPORT COMPLETED: $totalImported imported, $totalErrors errors =====');
      debugPrint('Summary: $results');
      return {
        'success': totalImported > 0 || errors.isEmpty,
        'totalImported': totalImported,
        'totalErrors': totalErrors,
        'details': results,
        'errorDetails': errors.isEmpty ? null : errors.join('\n'),
      };
    } catch (e, stackTrace) {
      debugPrint('===== IMPORT FAILED WITH EXCEPTION =====');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'totalImported': totalImported,
        'totalErrors': totalErrors,
        'details': results,
        'errorDetails': '$e\n$stackTrace',
      };
    }
  }

  /// Import a single CSV file into the specified table
  /// Uses the model's fromMap factory for proper type conversion
  Future<Map<String, dynamic>> importSingleCsv(
      String tableName, String csvFileName) async {
    int imported = 0;
    int errors = 0;
    String? lastError;

    try {
      debugPrint('Loading $csvFileName...');
      final String csvData = await rootBundle.loadString(csvFileName);
      debugPrint('CSV loaded, length: ${csvData.length} chars');

      // Parse CSV with proper line ending handling
      final List<List<dynamic>> rowsAsListOfValues =
          const CsvToListConverter(eol: '\n').convert(csvData);
      debugPrint('Parsed ${rowsAsListOfValues.length} rows (including header)');

      if (rowsAsListOfValues.isEmpty) {
        return {'imported': 0, 'errors': 0, 'error': 'Empty CSV file'};
      }

      // Read header row and create column map
      final headers = rowsAsListOfValues[0]
          .map((h) => h.toString().trim().toLowerCase())
          .toList();
      final Map<String, int> columnMap = {};
      for (int i = 0; i < headers.length; i++) {
        columnMap[headers[i]] = i;
      }

      debugPrint('Headers: $headers');

      // Collect records for batch insert
      final List<Map<String, dynamic>> recordsToInsert = [];
      final List<Map<String, dynamic>> recordsToUpdate = [];

      final db = await _dbHelper.database;
      final modelFactory = _modelFactories[tableName];

      // Process each data row
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];

          // Skip empty rows
          if (row.isEmpty ||
              row.every((cell) => cell.toString().trim().isEmpty)) {
            continue;
          }

          // Build raw record map from row data (string values from CSV)
          final Map<String, dynamic> rawRecord = {};

          for (String header in headers) {
            final colIndex = columnMap[header]!;
            if (colIndex < row.length) {
              final cellValue = row[colIndex];
              final stringValue = cellValue.toString().trim();
              rawRecord[header] = stringValue.isEmpty ? null : stringValue;
            }
          }

          // Ensure updated_at is set if not present
          if (!rawRecord.containsKey('updated_at') ||
              rawRecord['updated_at'] == null) {
            rawRecord['updated_at'] = DateTime.now().toUtc().toIso8601String();
          }

          // Pre-convert CSV strings to typed values for model factory
          final Map<String, dynamic> preTypedRecord =
              _preConvertTypes(rawRecord);

          // Convert to properly typed record using model's fromMap
          Map<String, dynamic> typedRecord;
          if (modelFactory != null) {
            try {
              // Use the model's fromMap to get proper types, then convert back to map
              final modelInstance = modelFactory(preTypedRecord);
              typedRecord = _modelToMap(modelInstance, tableName);
            } catch (e) {
              // If model factory fails, fall back to heuristic parsing
              debugPrint(
                  'Model factory failed for $tableName row $i: $e. Using fallback.');
              typedRecord = _convertRecordTypes(rawRecord, headers);
            }
          } else {
            // No model factory available, use heuristic parsing
            typedRecord = _convertRecordTypes(rawRecord, headers);
          }

          // Check if record already exists (based on uuid or name)
          final primaryKey = typedRecord.containsKey('uuid') ? 'uuid' : 'name';
          if (typedRecord.containsKey(primaryKey)) {
            final existing = await db.query(
              tableName,
              where: '$primaryKey = ?',
              whereArgs: [typedRecord[primaryKey]],
            );

            if (existing.isNotEmpty) {
              recordsToUpdate.add(typedRecord);
            } else {
              recordsToInsert.add(typedRecord);
            }
          } else {
            recordsToInsert.add(typedRecord);
          }
        } catch (e) {
          errors++;
          lastError = e.toString();
          debugPrint('Error processing row $i: $e');
        }
      }

      // Batch insert new records
      if (recordsToInsert.isNotEmpty) {
        debugPrint('Batch inserting ${recordsToInsert.length} records...');
        await db.transaction((txn) async {
          for (final record in recordsToInsert) {
            await txn.insert(tableName, record);
            imported++;
          }
        });
      }

      // Batch update existing records
      if (recordsToUpdate.isNotEmpty) {
        debugPrint('Batch updating ${recordsToUpdate.length} records...');
        await db.transaction((txn) async {
          for (final record in recordsToUpdate) {
            final primaryKey = record.containsKey('uuid') ? 'uuid' : 'name';
            await txn.update(
              tableName,
              record,
              where: '$primaryKey = ?',
              whereArgs: [record[primaryKey]],
            );
            imported++;
          }
        });
      }

      debugPrint(
          '$tableName: imported=$imported (${recordsToInsert.length} new, ${recordsToUpdate.length} updated), errors=$errors');

      return {
        'imported': imported,
        'errors': errors,
        'error': lastError,
      };
    } catch (e, stackTrace) {
      errors++;
      lastError = e.toString();
      debugPrint('Error loading $csvFileName: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'imported': imported,
        'errors': errors,
        'error': lastError,
      };
    }
  }

  /// Convert a model instance back to a map for database storage
  /// Uses the model's toMap method
  Map<String, dynamic> _modelToMap(dynamic modelInstance, String tableName) {
    // All our models have a toMap method
    if (modelInstance is Currency) return modelInstance.toMap();
    if (modelInstance is UnitOfMeasure) return modelInstance.toMap();
    if (modelInstance is Manufacturer) return modelInstance.toMap();
    if (modelInstance is Vendor) return modelInstance.toMap();
    if (modelInstance is Material) return modelInstance.toMap();
    if (modelInstance is ManufacturerMaterial) return modelInstance.toMap();
    if (modelInstance is VendorPriceList) return modelInstance.toMap();
    if (modelInstance is Project) return modelInstance.toMap();

    throw Exception('Unknown model type for table: $tableName');
  }

  /// Pre-convert CSV strings to types expected by model factories
  /// This handles int, bool conversions that models expect
  Map<String, dynamic> _preConvertTypes(Map<String, dynamic> rawRecord) {
    final Map<String, dynamic> converted = {};

    rawRecord.forEach((key, value) {
      if (value == null) {
        converted[key] = null;
        return;
      }

      final stringValue = value.toString().trim();
      if (stringValue.isEmpty) {
        converted[key] = null;
        return;
      }

      // Handle known integer fields
      if (key == 'number_of_decimal_places' ||
          key.endsWith('_id') && key != 'uuid' ||
          key.contains('decimal_places') ||
          key.contains('size') ||
          key.contains('quantity')) {
        converted[key] = int.tryParse(stringValue);
        return;
      }

      // Handle boolean fields (keep as int 0/1 for SQLite)
      if (key.startsWith('is_') || key == 'active' || key == 'completed') {
        final boolValue = stringValue == '1' ||
            stringValue.toLowerCase() == 'true' ||
            stringValue.toLowerCase() == 'yes';
        converted[key] = boolValue ? 1 : 0;
        return;
      }

      // Handle decimal/double fields
      if (key.contains('price') ||
          key.contains('rate') ||
          key.contains('amount') ||
          key.contains('tax') ||
          key.contains('percent')) {
        converted[key] = double.tryParse(stringValue);
        return;
      }

      // Default: keep as string
      converted[key] = stringValue;
    });

    return converted;
  }

  /// Fallback method to convert record types using heuristics
  /// Used when model factory is not available or fails
  Map<String, dynamic> _convertRecordTypes(
      Map<String, dynamic> rawRecord, List<String> headers) {
    final Map<String, dynamic> typedRecord = {};

    for (String header in headers) {
      final value = rawRecord[header];
      typedRecord[header] = _parseValue(header, value);
    }

    return typedRecord;
  }

  /// Parse cell value based on column name/type (fallback heuristic method)
  /// Returns SQLite-compatible types: num, String, or Uint8List
  dynamic _parseValue(String columnName, dynamic cellValue) {
    if (cellValue == null) return null;

    final stringValue = cellValue.toString().trim();
    if (stringValue.isEmpty) return null;

    // Handle dates - return ISO8601 string
    if (columnName.contains('updated_at') ||
        columnName.contains('created_at') ||
        columnName.contains('_date')) {
      try {
        return DateTime.parse(stringValue).toIso8601String();
      } catch (e) {
        return DateTime.now().toUtc().toIso8601String();
      }
    }

    // Handle booleans - SQLite needs 0/1 (int), not true/false
    if (columnName.contains('is_') ||
        columnName == 'active' ||
        columnName == 'completed') {
      final boolValue = stringValue == '1' ||
          stringValue.toLowerCase() == 'true' ||
          stringValue.toLowerCase() == 'yes';
      return boolValue ? 1 : 0; // Convert to int for SQLite
    }

    // Handle integers
    if (columnName.contains('_id') && columnName != 'uuid') {
      return int.tryParse(stringValue);
    }

    if (columnName.contains('decimal_places') ||
        columnName.contains('size') ||
        columnName.contains('quantity')) {
      return int.tryParse(stringValue) ?? 0;
    }

    // Handle decimals/doubles
    if (columnName.contains('price') ||
        columnName.contains('rate') ||
        columnName.contains('amount') ||
        columnName.contains('tax') ||
        columnName.contains('percent')) {
      return double.tryParse(stringValue) ?? 0.0;
    }

    // Default: return as string
    return stringValue;
  }

  Future<Map<String, dynamic>> importFromFile(String filePath) async {
    // This can be extended to import from user-selected files
    // For now, we'll use the assets import
    return await importFromAssets();
  }
}
