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
          'Summary: Manufacturers=${results['manufacturers']}, Vendors=${results['vendors']}, Materials=${results['materials']}, ManufacturerMaterials=${results['manufacturer_materials']}, VendorPriceLists=${results['vendor_price_lists']}');
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

      // Skip header row
      // CSV columns: uuid,id,name,description,updated_at
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];
          if (row.length < 5) continue;

          final uuid = row[0].toString().trim();
          final id = row[1].toString().trim().isNotEmpty
              ? int.tryParse(row[1].toString().trim())
              : null;
          final name = row[2].toString().trim();
          final description = row[3].toString().trim();
          final updatedAt = row[4].toString().trim().isNotEmpty
              ? DateTime.parse(row[4].toString().trim())
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

      // CSV columns: uuid,id,name,description,address,geo_location,updated_at
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];
          if (row.length < 7) continue;

          final uuid = row[0].toString().trim();
          final id = row[1].toString().trim().isNotEmpty
              ? int.tryParse(row[1].toString().trim())
              : null;
          final name = row[2].toString().trim();
          final description = row[3].toString().trim();
          final address = row[4].toString().trim();
          final geoLocation = row[5].toString().trim();
          final updatedAt = row[6].toString().trim().isNotEmpty
              ? DateTime.parse(row[6].toString().trim())
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

      // CSV columns: uuid,id,name,description,unit_of_measure,updated_at
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];
          if (row.length < 6) continue;

          final uuid = row[0].toString().trim();
          final id = row[1].toString().trim().isNotEmpty
              ? int.tryParse(row[1].toString().trim())
              : null;
          final name = row[2].toString().trim();
          final description = row[3].toString().trim();
          final unitOfMeasure = row[4].toString().trim();
          final updatedAt = row[5].toString().trim().isNotEmpty
              ? DateTime.parse(row[5].toString().trim())
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

      // CSV columns: uuid,manufacturer_uuid,material_uuid,model,selling_lot_size,max_retail_price,currency,updated_at
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];
          if (row.length < 8) continue;

          final uuid = row[0].toString().trim();
          final manufacturerId = row[1].toString().trim();
          final materialId = row[2].toString().trim();
          final model = row[3].toString().trim();
          final sellingLotSize = row[4].toString().trim().isNotEmpty
              ? int.tryParse(row[4].toString().trim())
              : null;
          final maxRetailPrice = row[5].toString().trim().isNotEmpty
              ? double.tryParse(row[5].toString().trim())
              : null;
          final currency = row[6].toString().trim();
          final updatedAt = row[7].toString().trim().isNotEmpty
              ? DateTime.parse(row[7].toString().trim())
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

      // CSV columns: uuid,manufacturer_material_uuid,vendor_uuid,rate,rate_before_tax,currency,tax_percent,tax_amount,updated_at
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        try {
          final row = rowsAsListOfValues[i];
          if (row.length < 9) continue;

          final uuid = row[0].toString().trim();
          final manufacturerMaterialId = row[1].toString().trim();
          final vendorId = row[2].toString().trim();
          final rate = double.tryParse(row[3].toString().trim()) ?? 0.0;
          final rateBeforeTax =
              double.tryParse(row[4].toString().trim()) ?? 0.0;
          final currency = row[5].toString().trim();
          final taxPercent = double.tryParse(row[6].toString().trim()) ?? 0.0;
          final taxAmount = double.tryParse(row[7].toString().trim()) ?? 0.0;
          final updatedAt = row[8].toString().trim().isNotEmpty
              ? DateTime.parse(row[8].toString().trim())
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
