import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/manufacturer.dart';
import '../models/vendor.dart';
import '../models/material.dart';
import '../models/manufacturer_material.dart';
import '../models/vendor_price_list.dart';
import 'database_helper.dart';

class CsvImportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Map<String, dynamic>> importFromAssets() async {
    debugPrint('===== IMPORT STARTING =====');
    final results = <String, int>{};
    final errors = <String>[];
    int totalImported = 0;
    int totalErrors = 0;

    try {
      // Import Unit of Measures (configuration)
      final uomResult = await _importUnitOfMeasures();
      results['unit_of_measures'] = uomResult['imported'] as int;
      totalImported += uomResult['imported'] as int;
      totalErrors += uomResult['errors'] as int;
      if (uomResult['error'] != null) {
        errors.add('Unit of Measures: ${uomResult['error']}');
      }

      // Import Currencies (configuration)
      final currenciesResult = await _importCurrencies();
      results['currencies'] = currenciesResult['imported'] as int;
      totalImported += currenciesResult['imported'] as int;
      totalErrors += currenciesResult['errors'] as int;
      if (currenciesResult['error'] != null) {
        errors.add('Currencies: ${currenciesResult['error']}');
      }

      // Import Manufacturers
      final manufacturersResult = await _importManufacturers();
      results['manufacturers'] = manufacturersResult['imported'] as int;
      totalImported += manufacturersResult['imported'] as int;
      totalErrors += manufacturersResult['errors'] as int;
      if (manufacturersResult['error'] != null) {
        errors.add('Manufacturers: ${manufacturersResult['error']}');
      }

      // Import Vendors
      final vendorsResult = await _importVendors();
      results['vendors'] = vendorsResult['imported'] as int;
      totalImported += vendorsResult['imported'] as int;
      totalErrors += vendorsResult['errors'] as int;
      if (vendorsResult['error'] != null) {
        errors.add('Vendors: ${vendorsResult['error']}');
      }

      // Import Materials
      final materialsResult = await _importMaterials();
      results['materials'] = materialsResult['imported'] as int;
      totalImported += materialsResult['imported'] as int;
      totalErrors += materialsResult['errors'] as int;
      if (materialsResult['error'] != null) {
        errors.add('Materials: ${materialsResult['error']}');
      }

      // Import Manufacturer Materials
      final mmResult = await _importManufacturerMaterials();
      results['manufacturer_materials'] = mmResult['imported'] as int;
      totalImported += mmResult['imported'] as int;
      totalErrors += mmResult['errors'] as int;
      if (mmResult['error'] != null) {
        errors.add('Manufacturer Materials: ${mmResult['error']}');
      }

      // Import Vendor Price Lists
      final vplResult = await _importVendorPriceLists();
      results['vendor_price_lists'] = vplResult['imported'] as int;
      totalImported += vplResult['imported'] as int;
      totalErrors += vplResult['errors'] as int;
      if (vplResult['error'] != null) {
        errors.add('Vendor Price Lists: ${vplResult['error']}');
      }

      debugPrint(
          '===== IMPORT COMPLETED: $totalImported imported, $totalErrors errors =====');
      debugPrint(
          'Summary: UnitOfMeasures=${results['unit_of_measures']}, Currencies=${results['currencies']}, Manufacturers=${results['manufacturers']}, Vendors=${results['vendors']}, Materials=${results['materials']}, ManufacturerMaterials=${results['manufacturer_materials']}, VendorPriceLists=${results['vendor_price_lists']}');
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

  Future<Map<String, dynamic>> _importUnitOfMeasures() async {
    int imported = 0;
    int errors = 0;
    String? lastError;

    try {
      debugPrint('Loading unit_of_measures.csv...');
      final String csvData =
          await rootBundle.loadString('data/unit_of_measures.csv');
      debugPrint('CSV loaded, length: ${csvData.length} chars');
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

      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];
          if (row.isEmpty) continue;

          final name =
              columnMap.containsKey('name') && row.length > columnMap['name']!
                  ? row[columnMap['name']!].toString().trim()
                  : '';
          final description = columnMap.containsKey('description') &&
                  row.length > columnMap['description']!
              ? row[columnMap['description']!].toString().trim()
              : '';
          final numberOfDecimalPlaces =
              columnMap.containsKey('number_of_decimal_places') &&
                      row.length > columnMap['number_of_decimal_places']!
                  ? int.tryParse(row[columnMap['number_of_decimal_places']!]
                          .toString()
                          .trim()) ??
                      2
                  : 2;
          final isDefault = columnMap.containsKey('is_default') &&
                  row.length > columnMap['is_default']!
              ? (row[columnMap['is_default']!]
                          .toString()
                          .trim()
                          .toLowerCase() ==
                      'true' ||
                  row[columnMap['is_default']!].toString().trim() == '1')
              : false;
          final updatedAt = columnMap.containsKey('updated_at') &&
                  row.length > columnMap['updated_at']! &&
                  row[columnMap['updated_at']!].toString().trim().isNotEmpty
              ? DateTime.parse(row[columnMap['updated_at']!].toString().trim())
              : DateTime.now().toUtc();

          if (name.isEmpty) {
            errors++;
            continue;
          }

          // Check if already exists (using name as primary key)
          final db = await _dbHelper.database;
          final existing = await db.query(
            'unit_of_measures',
            where: 'name = ?',
            whereArgs: [name],
          );

          if (existing.isNotEmpty) {
            // Update existing
            await db.update(
              'unit_of_measures',
              {
                'description': description.isEmpty ? null : description,
                'number_of_decimal_places': numberOfDecimalPlaces,
                'is_default': isDefault ? 1 : 0,
                'updated_at': updatedAt.toIso8601String(),
              },
              where: 'name = ?',
              whereArgs: [name],
            );
          } else {
            // Insert new
            await db.insert('unit_of_measures', {
              'name': name,
              'description': description.isEmpty ? null : description,
              'number_of_decimal_places': numberOfDecimalPlaces,
              'is_default': isDefault ? 1 : 0,
              'updated_at': updatedAt.toIso8601String(),
            });
          }
          imported++;
        } catch (e) {
          errors++;
          lastError = e.toString();
          debugPrint('Error importing unit_of_measure row: $e');
        }
      }
    } catch (e) {
      errors++;
      lastError = e.toString();
      debugPrint('Error loading unit_of_measures.csv: $e');
    }

    if (lastError != null && imported == 0) {
      debugPrint('Failed to import unit of measures. Last error: $lastError');
    }
    debugPrint('Unit of Measures: imported=$imported, errors=$errors');
    return {
      'imported': imported,
      'errors': errors,
      'error': lastError,
    };
  }

  Future<Map<String, dynamic>> _importCurrencies() async {
    int imported = 0;
    int errors = 0;
    String? lastError;

    try {
      debugPrint('Loading currencies.csv...');
      final String csvData = await rootBundle.loadString('data/currencies.csv');
      debugPrint('CSV loaded, length: ${csvData.length} chars');
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

      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];
          if (row.isEmpty) continue;

          final name =
              columnMap.containsKey('name') && row.length > columnMap['name']!
                  ? row[columnMap['name']!].toString().trim()
                  : '';
          final description = columnMap.containsKey('description') &&
                  row.length > columnMap['description']!
              ? row[columnMap['description']!].toString().trim()
              : '';
          final symbol = columnMap.containsKey('symbol') &&
                  row.length > columnMap['symbol']!
              ? row[columnMap['symbol']!].toString().trim()
              : '';
          final numberOfDecimalPlaces =
              columnMap.containsKey('number_of_decimal_places') &&
                      row.length > columnMap['number_of_decimal_places']!
                  ? int.tryParse(row[columnMap['number_of_decimal_places']!]
                          .toString()
                          .trim()) ??
                      2
                  : 2;
          final isDefault = columnMap.containsKey('is_default') &&
                  row.length > columnMap['is_default']!
              ? (row[columnMap['is_default']!]
                          .toString()
                          .trim()
                          .toLowerCase() ==
                      'true' ||
                  row[columnMap['is_default']!].toString().trim() == '1')
              : false;
          final updatedAt = columnMap.containsKey('updated_at') &&
                  row.length > columnMap['updated_at']! &&
                  row[columnMap['updated_at']!].toString().trim().isNotEmpty
              ? DateTime.parse(row[columnMap['updated_at']!].toString().trim())
              : DateTime.now().toUtc();

          if (name.isEmpty) {
            errors++;
            continue;
          }

          // Check if already exists (using name as primary key)
          final db = await _dbHelper.database;
          final existing = await db.query(
            'currencies',
            where: 'name = ?',
            whereArgs: [name],
          );

          if (existing.isNotEmpty) {
            // Update existing
            await db.update(
              'currencies',
              {
                'description': description.isEmpty ? null : description,
                'symbol': symbol.isEmpty ? null : symbol,
                'number_of_decimal_places': numberOfDecimalPlaces,
                'is_default': isDefault ? 1 : 0,
                'updated_at': updatedAt.toIso8601String(),
              },
              where: 'name = ?',
              whereArgs: [name],
            );
          } else {
            // Insert new
            await db.insert('currencies', {
              'name': name,
              'description': description.isEmpty ? null : description,
              'symbol': symbol.isEmpty ? null : symbol,
              'number_of_decimal_places': numberOfDecimalPlaces,
              'is_default': isDefault ? 1 : 0,
              'updated_at': updatedAt.toIso8601String(),
            });
          }
          imported++;
        } catch (e) {
          errors++;
          lastError = e.toString();
          debugPrint('Error importing currency row: $e');
        }
      }
    } catch (e) {
      errors++;
      lastError = e.toString();
      debugPrint('Error loading currencies.csv: $e');
    }

    if (lastError != null && imported == 0) {
      debugPrint('Failed to import currencies. Last error: $lastError');
    }
    debugPrint('Currencies: imported=$imported, errors=$errors');
    return {
      'imported': imported,
      'errors': errors,
      'error': lastError,
    };
  }

  Future<Map<String, dynamic>> _importManufacturers() async {
    int imported = 0;
    int errors = 0;
    String? lastError;

    try {
      debugPrint('Loading manufacturers.csv...');
      final String csvData =
          await rootBundle.loadString('data/manufacturers.csv');
      debugPrint('CSV loaded, length: ${csvData.length} chars');
      debugPrint(
          'First 200 chars: ${csvData.substring(0, csvData.length > 200 ? 200 : csvData.length)}');
      debugPrint('Contains \\n: ${csvData.contains('\n')}');
      debugPrint('Contains \\r\\n: ${csvData.contains('\r\n')}');
      final List<List<dynamic>> rowsAsListOfValues =
          const CsvToListConverter(eol: '\n').convert(csvData);
      debugPrint('Parsed ${rowsAsListOfValues.length} rows (including header)');

      if (rowsAsListOfValues.isEmpty) {
        debugPrint('CSV is empty');
        return {'imported': 0, 'errors': 0, 'error': 'CSV file is empty'};
      }

      // Read headers from the first row
      final headers = rowsAsListOfValues[0]
          .map((h) => h.toString().trim().toLowerCase())
          .toList();
      final Map<String, int> columnMap = {};
      for (int i = 0; i < headers.length; i++) {
        columnMap[headers[i]] = i;
      }

      // CSV columns: uuid,id,name,description,updated_at
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];

          final uuid =
              columnMap.containsKey('uuid') && row.length > columnMap['uuid']!
                  ? row[columnMap['uuid']!].toString().trim()
                  : '';
          final id =
              columnMap.containsKey('id') && row.length > columnMap['id']!
                  ? (row[columnMap['id']!].toString().trim().isNotEmpty
                      ? int.tryParse(row[columnMap['id']!].toString().trim())
                      : null)
                  : null;
          final name =
              columnMap.containsKey('name') && row.length > columnMap['name']!
                  ? row[columnMap['name']!].toString().trim()
                  : '';
          final description = columnMap.containsKey('description') &&
                  row.length > columnMap['description']!
              ? row[columnMap['description']!].toString().trim()
              : '';
          final updatedAt = columnMap.containsKey('updated_at') &&
                  row.length > columnMap['updated_at']!
              ? (row[columnMap['updated_at']!].toString().trim().isNotEmpty
                  ? DateTime.parse(
                      row[columnMap['updated_at']!].toString().trim())
                  : DateTime.now().toUtc())
              : DateTime.now().toUtc();

          if (uuid.isEmpty || name.isEmpty) {
            errors++;
            continue;
          }

          // Check if already exists
          final existing = await _dbHelper.getManufacturer(uuid);
          if (existing != null) {
            // Update existing
            await _dbHelper.updateManufacturer(Manufacturer(
              uuid: uuid,
              id: id ?? existing.id,
              name: name,
              description: description.isEmpty ? null : description,
              updatedAt: updatedAt,
            ));
          } else {
            // Insert new
            await _dbHelper.insertManufacturer(Manufacturer(
              uuid: uuid,
              id: id,
              name: name,
              description: description.isEmpty ? null : description,
              updatedAt: updatedAt,
            ));
          }
          imported++;
        } catch (e) {
          errors++;
          lastError = e.toString();
          debugPrint('Error importing manufacturer row: $e');
        }
      }
    } catch (e) {
      errors++;
      lastError = e.toString();
      debugPrint('Error loading manufacturers.csv: $e');
    }

    if (lastError != null && imported == 0) {
      debugPrint('Failed to import manufacturers. Last error: $lastError');
    }
    debugPrint('Manufacturers: imported=$imported, errors=$errors');
    return {
      'imported': imported,
      'errors': errors,
      'error': lastError,
    };
  }

  Future<Map<String, dynamic>> _importVendors() async {
    int imported = 0;
    int errors = 0;
    String? lastError;

    try {
      debugPrint('Loading vendors.csv...');
      final String csvData = await rootBundle.loadString('data/vendors.csv');
      debugPrint('CSV loaded, length: ${csvData.length} chars');
      debugPrint(
          'First 200 chars: ${csvData.substring(0, csvData.length > 200 ? 200 : csvData.length)}');
      debugPrint('Contains \\n: ${csvData.contains('\n')}');
      final List<List<dynamic>> rowsAsListOfValues =
          const CsvToListConverter(eol: '\n').convert(csvData);
      debugPrint('Parsed ${rowsAsListOfValues.length} rows (including header)');

      if (rowsAsListOfValues.isEmpty) {
        debugPrint('CSV is empty');
        return {'imported': 0, 'errors': 0, 'error': 'CSV file is empty'};
      }

      // Read headers from the first row
      final headers = rowsAsListOfValues[0]
          .map((h) => h.toString().trim().toLowerCase())
          .toList();
      final Map<String, int> columnMap = {};
      for (int i = 0; i < headers.length; i++) {
        columnMap[headers[i]] = i;
      }

      // CSV columns: uuid,id,name,description,address,geo_location,updated_at
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];

          final uuid =
              columnMap.containsKey('uuid') && row.length > columnMap['uuid']!
                  ? row[columnMap['uuid']!].toString().trim()
                  : '';
          final id =
              columnMap.containsKey('id') && row.length > columnMap['id']!
                  ? (row[columnMap['id']!].toString().trim().isNotEmpty
                      ? int.tryParse(row[columnMap['id']!].toString().trim())
                      : null)
                  : null;
          final name =
              columnMap.containsKey('name') && row.length > columnMap['name']!
                  ? row[columnMap['name']!].toString().trim()
                  : '';
          final description = columnMap.containsKey('description') &&
                  row.length > columnMap['description']!
              ? row[columnMap['description']!].toString().trim()
              : '';
          final address = columnMap.containsKey('address') &&
                  row.length > columnMap['address']!
              ? row[columnMap['address']!].toString().trim()
              : '';
          final geoLocation = columnMap.containsKey('geo_location') &&
                  row.length > columnMap['geo_location']!
              ? row[columnMap['geo_location']!].toString().trim()
              : '';
          final updatedAt = columnMap.containsKey('updated_at') &&
                  row.length > columnMap['updated_at']!
              ? (row[columnMap['updated_at']!].toString().trim().isNotEmpty
                  ? DateTime.parse(
                      row[columnMap['updated_at']!].toString().trim())
                  : DateTime.now().toUtc())
              : DateTime.now().toUtc();

          if (uuid.isEmpty || name.isEmpty) {
            errors++;
            continue;
          }

          final existing = await _dbHelper.getVendor(uuid);
          if (existing != null) {
            await _dbHelper.updateVendor(Vendor(
              uuid: uuid,
              id: id ?? existing.id,
              name: name,
              description: description.isEmpty ? null : description,
              address: address.isEmpty ? null : address,
              geoLocation: geoLocation.isEmpty ? null : geoLocation,
              updatedAt: updatedAt,
            ));
          } else {
            await _dbHelper.insertVendor(Vendor(
              uuid: uuid,
              id: id,
              name: name,
              description: description.isEmpty ? null : description,
              address: address.isEmpty ? null : address,
              geoLocation: geoLocation.isEmpty ? null : geoLocation,
              updatedAt: updatedAt,
            ));
          }
          imported++;
        } catch (e) {
          errors++;
          lastError = e.toString();
          debugPrint('Error importing vendor row: $e');
        }
      }
    } catch (e) {
      errors++;
      lastError = e.toString();
      debugPrint('Error loading vendors.csv: $e');
    }

    if (lastError != null && imported == 0) {
      debugPrint('Failed to import vendors. Last error: $lastError');
    }
    debugPrint('Vendors: imported=$imported, errors=$errors');
    return {
      'imported': imported,
      'errors': errors,
      'error': lastError,
    };
  }

  Future<Map<String, dynamic>> _importMaterials() async {
    int imported = 0;
    int errors = 0;
    String? lastError;

    try {
      debugPrint('Loading materials.csv...');
      final String csvData = await rootBundle.loadString('data/materials.csv');
      debugPrint('CSV loaded, length: ${csvData.length} chars');
      debugPrint(
          'First 200 chars: ${csvData.substring(0, csvData.length > 200 ? 200 : csvData.length)}');
      debugPrint('Contains \\n: ${csvData.contains('\n')}');
      final List<List<dynamic>> rowsAsListOfValues =
          const CsvToListConverter(eol: '\n').convert(csvData);
      debugPrint('Parsed ${rowsAsListOfValues.length} rows (including header)');

      if (rowsAsListOfValues.isEmpty) {
        debugPrint('CSV is empty');
        return {'imported': 0, 'errors': 0, 'error': 'CSV file is empty'};
      }

      // Read headers from the first row
      final headers = rowsAsListOfValues[0]
          .map((h) => h.toString().trim().toLowerCase())
          .toList();
      final Map<String, int> columnMap = {};
      for (int i = 0; i < headers.length; i++) {
        columnMap[headers[i]] = i;
      }

      // CSV columns: uuid,id,name,description,unit_of_measure,updated_at
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];

          final uuid =
              columnMap.containsKey('uuid') && row.length > columnMap['uuid']!
                  ? row[columnMap['uuid']!].toString().trim()
                  : '';
          final id =
              columnMap.containsKey('id') && row.length > columnMap['id']!
                  ? (row[columnMap['id']!].toString().trim().isNotEmpty
                      ? int.tryParse(row[columnMap['id']!].toString().trim())
                      : null)
                  : null;
          final name =
              columnMap.containsKey('name') && row.length > columnMap['name']!
                  ? row[columnMap['name']!].toString().trim()
                  : '';
          final description = columnMap.containsKey('description') &&
                  row.length > columnMap['description']!
              ? row[columnMap['description']!].toString().trim()
              : '';
          final unitOfMeasure = columnMap.containsKey('unit_of_measure') &&
                  row.length > columnMap['unit_of_measure']!
              ? row[columnMap['unit_of_measure']!].toString().trim()
              : '';
          final updatedAt = columnMap.containsKey('updated_at') &&
                  row.length > columnMap['updated_at']!
              ? (row[columnMap['updated_at']!].toString().trim().isNotEmpty
                  ? DateTime.parse(
                      row[columnMap['updated_at']!].toString().trim())
                  : DateTime.now().toUtc())
              : DateTime.now().toUtc();

          if (uuid.isEmpty || name.isEmpty || unitOfMeasure.isEmpty) {
            errors++;
            continue;
          }

          final existing = await _dbHelper.getMaterial(uuid);
          if (existing != null) {
            await _dbHelper.updateMaterial(Material(
              uuid: uuid,
              id: id ?? existing.id,
              name: name,
              description: description.isEmpty ? null : description,
              unitOfMeasure: unitOfMeasure,
              updatedAt: updatedAt,
            ));
          } else {
            await _dbHelper.insertMaterial(Material(
              uuid: uuid,
              id: id,
              name: name,
              description: description.isEmpty ? null : description,
              unitOfMeasure: unitOfMeasure,
              updatedAt: updatedAt,
            ));
          }
          imported++;
        } catch (e) {
          errors++;
          lastError = e.toString();
          debugPrint('Error importing material row: $e');
        }
      }
    } catch (e) {
      errors++;
      lastError = e.toString();
      debugPrint('Error loading materials.csv: $e');
    }

    if (lastError != null && imported == 0) {
      debugPrint('Failed to import materials. Last error: $lastError');
    }
    debugPrint('Materials: imported=$imported, errors=$errors');
    return {
      'imported': imported,
      'errors': errors,
      'error': lastError,
    };
  }

  Future<Map<String, dynamic>> _importManufacturerMaterials() async {
    int imported = 0;
    int errors = 0;
    String? lastError;

    try {
      debugPrint('Loading manufacturer_materials.csv...');
      final String csvData =
          await rootBundle.loadString('data/manufacturer_materials.csv');
      debugPrint('CSV loaded, length: ${csvData.length} chars');
      debugPrint(
          'First 200 chars: ${csvData.substring(0, csvData.length > 200 ? 200 : csvData.length)}');
      debugPrint('Contains \\n: ${csvData.contains('\n')}');
      final List<List<dynamic>> rowsAsListOfValues =
          const CsvToListConverter(eol: '\n').convert(csvData);
      debugPrint('Parsed ${rowsAsListOfValues.length} rows (including header)');

      if (rowsAsListOfValues.isEmpty) {
        debugPrint('CSV is empty');
        return {'imported': 0, 'errors': 0, 'error': 'CSV file is empty'};
      }

      // Read headers from the first row
      final headers = rowsAsListOfValues[0]
          .map((h) => h.toString().trim().toLowerCase())
          .toList();
      final Map<String, int> columnMap = {};
      for (int i = 0; i < headers.length; i++) {
        columnMap[headers[i]] = i;
      }

      // CSV columns: uuid,manufacturer_uuid,material_uuid,model,selling_lot_size,max_retail_price,currency,updated_at
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];

          final uuid =
              columnMap.containsKey('uuid') && row.length > columnMap['uuid']!
                  ? row[columnMap['uuid']!].toString().trim()
                  : '';
          final manufacturerId = columnMap.containsKey('manufacturer_uuid') &&
                  row.length > columnMap['manufacturer_uuid']!
              ? row[columnMap['manufacturer_uuid']!].toString().trim()
              : '';
          final materialId = columnMap.containsKey('material_uuid') &&
                  row.length > columnMap['material_uuid']!
              ? row[columnMap['material_uuid']!].toString().trim()
              : '';
          final model =
              columnMap.containsKey('model') && row.length > columnMap['model']!
                  ? row[columnMap['model']!].toString().trim()
                  : '';
          final sellingLotSize = columnMap.containsKey('selling_lot_size') &&
                  row.length > columnMap['selling_lot_size']!
              ? (row[columnMap['selling_lot_size']!]
                      .toString()
                      .trim()
                      .isNotEmpty
                  ? double.tryParse(
                      row[columnMap['selling_lot_size']!].toString().trim())
                  : null)
              : null;
          final maxRetailPrice = columnMap.containsKey('max_retail_price') &&
                  row.length > columnMap['max_retail_price']!
              ? (row[columnMap['max_retail_price']!]
                      .toString()
                      .trim()
                      .isNotEmpty
                  ? double.tryParse(
                      row[columnMap['max_retail_price']!].toString().trim())
                  : null)
              : null;
          final currency = columnMap.containsKey('currency') &&
                  row.length > columnMap['currency']!
              ? row[columnMap['currency']!].toString().trim()
              : '';
          final updatedAt = columnMap.containsKey('updated_at') &&
                  row.length > columnMap['updated_at']!
              ? (row[columnMap['updated_at']!].toString().trim().isNotEmpty
                  ? DateTime.parse(
                      row[columnMap['updated_at']!].toString().trim())
                  : DateTime.now().toUtc())
              : DateTime.now().toUtc();

          if (uuid.isEmpty ||
              manufacturerId.isEmpty ||
              materialId.isEmpty ||
              model.isEmpty) {
            errors++;
            continue;
          }

          // Verify manufacturer and material exist
          final manufacturer = await _dbHelper.getManufacturer(manufacturerId);
          final material = await _dbHelper.getMaterial(materialId);
          if (manufacturer == null) {
            errors++;
            lastError = 'Manufacturer not found: $manufacturerId';
            debugPrint('Row $i: Manufacturer not found: $manufacturerId');
            continue;
          }
          if (material == null) {
            errors++;
            lastError = 'Material not found: $materialId';
            debugPrint('Row $i: Material not found: $materialId');
            continue;
          }

          final existing = await _dbHelper.getManufacturerMaterial(uuid);
          if (existing != null) {
            await _dbHelper.updateManufacturerMaterial(ManufacturerMaterial(
              uuid: uuid,
              manufacturerUuid: manufacturerId,
              materialUuid: materialId,
              model: model,
              sellingLotSize: sellingLotSize,
              maxRetailPrice: maxRetailPrice,
              currency: currency.isEmpty ? null : currency,
              updatedAt: updatedAt,
            ));
          } else {
            await _dbHelper.insertManufacturerMaterial(ManufacturerMaterial(
              uuid: uuid,
              manufacturerUuid: manufacturerId,
              materialUuid: materialId,
              model: model,
              sellingLotSize: sellingLotSize,
              maxRetailPrice: maxRetailPrice,
              currency: currency.isEmpty ? null : currency,
              updatedAt: updatedAt,
            ));
          }
          imported++;
        } catch (e) {
          errors++;
          lastError = e.toString();
          debugPrint('Error importing manufacturer material row: $e');
        }
      }
    } catch (e) {
      errors++;
      lastError = e.toString();
      debugPrint('Error loading manufacturer_materials.csv: $e');
    }

    if (lastError != null && imported == 0) {
      debugPrint(
          'Failed to import manufacturer materials. Last error: $lastError');
    }
    debugPrint('Vendor Price Lists: imported=$imported, errors=$errors');
    debugPrint('Manufacturer Materials: imported=$imported, errors=$errors');
    return {
      'imported': imported,
      'errors': errors,
      'error': lastError,
    };
  }

  Future<Map<String, dynamic>> _importVendorPriceLists() async {
    int imported = 0;
    int errors = 0;
    String? lastError;

    try {
      debugPrint('Loading vendor_price_lists.csv...');
      final String csvData =
          await rootBundle.loadString('data/vendor_price_lists.csv');
      debugPrint('CSV loaded, length: ${csvData.length} chars');
      debugPrint(
          'First 200 chars: ${csvData.substring(0, csvData.length > 200 ? 200 : csvData.length)}');
      debugPrint('Contains \\n: ${csvData.contains('\n')}');
      final List<List<dynamic>> rowsAsListOfValues =
          const CsvToListConverter(eol: '\n').convert(csvData);
      debugPrint('Parsed ${rowsAsListOfValues.length} rows (including header)');

      if (rowsAsListOfValues.isEmpty) {
        debugPrint('CSV is empty');
        return {'imported': 0, 'errors': 0, 'error': 'CSV file is empty'};
      }

      // Read headers from the first row
      final headers = rowsAsListOfValues[0]
          .map((h) => h.toString().trim().toLowerCase())
          .toList();
      final Map<String, int> columnMap = {};
      for (int i = 0; i < headers.length; i++) {
        columnMap[headers[i]] = i;
      }

      // CSV columns: uuid,manufacturer_material_uuid,vendor_uuid,rate,rate_before_tax,currency,tax_percent,tax_amount,updated_at
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];

          final uuid =
              columnMap.containsKey('uuid') && row.length > columnMap['uuid']!
                  ? row[columnMap['uuid']!].toString().trim()
                  : '';
          final manufacturerMaterialId = columnMap
                      .containsKey('manufacturer_material_uuid') &&
                  row.length > columnMap['manufacturer_material_uuid']!
              ? row[columnMap['manufacturer_material_uuid']!].toString().trim()
              : '';
          final vendorId = columnMap.containsKey('vendor_uuid') &&
                  row.length > columnMap['vendor_uuid']!
              ? row[columnMap['vendor_uuid']!].toString().trim()
              : '';
          final rate = columnMap.containsKey('rate') &&
                  row.length > columnMap['rate']!
              ? (double.tryParse(row[columnMap['rate']!].toString().trim()) ??
                  0.0)
              : 0.0;
          final rateBeforeTax = columnMap.containsKey('rate_before_tax') &&
                  row.length > columnMap['rate_before_tax']!
              ? (double.tryParse(
                      row[columnMap['rate_before_tax']!].toString().trim()) ??
                  0.0)
              : 0.0;
          final currency = columnMap.containsKey('currency') &&
                  row.length > columnMap['currency']!
              ? row[columnMap['currency']!].toString().trim()
              : '';
          final taxPercent = columnMap.containsKey('tax_percent') &&
                  row.length > columnMap['tax_percent']!
              ? (double.tryParse(
                      row[columnMap['tax_percent']!].toString().trim()) ??
                  0.0)
              : 0.0;
          final taxAmount = columnMap.containsKey('tax_amount') &&
                  row.length > columnMap['tax_amount']!
              ? (double.tryParse(
                      row[columnMap['tax_amount']!].toString().trim()) ??
                  0.0)
              : 0.0;
          final updatedAt = columnMap.containsKey('updated_at') &&
                  row.length > columnMap['updated_at']!
              ? (row[columnMap['updated_at']!].toString().trim().isNotEmpty
                  ? DateTime.parse(
                      row[columnMap['updated_at']!].toString().trim())
                  : DateTime.now().toUtc())
              : DateTime.now().toUtc();

          if (uuid.isEmpty ||
              manufacturerMaterialId.isEmpty ||
              vendorId.isEmpty) {
            errors++;
            continue;
          }

          // Verify vendor and manufacturer material exist
          final vendor = await _dbHelper.getVendor(vendorId);
          final mm =
              await _dbHelper.getManufacturerMaterial(manufacturerMaterialId);
          if (vendor == null) {
            errors++;
            lastError = 'Vendor not found: $vendorId';
            debugPrint('Row $i: Vendor not found: $vendorId');
            continue;
          }
          if (mm == null) {
            errors++;
            lastError =
                'Manufacturer Material not found: $manufacturerMaterialId';
            debugPrint(
                'Row $i: Manufacturer Material not found: $manufacturerMaterialId');
            continue;
          }

          final existing = await _dbHelper.getVendorPriceList(uuid);
          if (existing != null) {
            await _dbHelper.updateVendorPriceList(VendorPriceList(
              uuid: uuid,
              manufacturerMaterialUuid: manufacturerMaterialId,
              vendorUuid: vendorId,
              rate: rate,
              rateBeforeTax: rateBeforeTax,
              currency: currency.isEmpty ? null : currency,
              taxPercent: taxPercent,
              taxAmount: taxAmount,
              updatedAt: updatedAt,
            ));
          } else {
            await _dbHelper.insertVendorPriceList(VendorPriceList(
              uuid: uuid,
              manufacturerMaterialUuid: manufacturerMaterialId,
              vendorUuid: vendorId,
              rate: rate,
              rateBeforeTax: rateBeforeTax,
              currency: currency.isEmpty ? null : currency,
              taxPercent: taxPercent,
              taxAmount: taxAmount,
              updatedAt: updatedAt,
            ));
          }
          imported++;
        } catch (e) {
          errors++;
          lastError = e.toString();
          debugPrint('Error importing vendor price list row: $e');
        }
      }
    } catch (e) {
      errors++;
      lastError = e.toString();
      debugPrint('Error loading vendor_price_lists.csv: $e');
    }

    if (lastError != null && imported == 0) {
      debugPrint('Failed to import vendor price lists. Last error: $lastError');
    }
    return {
      'imported': imported,
      'errors': errors,
      'error': lastError,
    };
  }

  Future<Map<String, dynamic>> importFromFile(String filePath) async {
    // This can be extended to import from user-selected files
    // For now, we'll use the assets import
    return await importFromAssets();
  }
}
