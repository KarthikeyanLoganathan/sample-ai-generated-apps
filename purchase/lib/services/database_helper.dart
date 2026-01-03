import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/manufacturer.dart';
import '../models/vendor.dart';
import '../models/material.dart';
import '../models/manufacturer_material.dart';
import '../models/vendor_price_list.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/purchase_order_payment.dart';
import '../models/basket_header.dart';
import '../models/basket_item.dart';
import '../models/basket_vendor.dart';
import '../models/basket_vendor_item.dart';
import '../config/sync_config.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const _uuid = Uuid();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('purchase_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add id column to basket_vendor_items table
      await db.execute(
        'ALTER TABLE basket_vendor_items ADD COLUMN id INTEGER',
      );
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Manufacturers table
    await db.execute('''
      CREATE TABLE manufacturers (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // Vendors table
    await db.execute('''
      CREATE TABLE vendors (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        address TEXT,
        geo_location TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // Materials table
    await db.execute('''
      CREATE TABLE materials (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        unit_of_measure TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Manufacturer Materials table
    await db.execute('''
      CREATE TABLE manufacturer_materials (
        uuid TEXT PRIMARY KEY,
        manufacturer_uuid TEXT NOT NULL,
        material_uuid TEXT NOT NULL,
        model TEXT NOT NULL,
        selling_lot_size INTEGER,
        max_retail_price REAL,
        currency TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (manufacturer_uuid) REFERENCES manufacturers (uuid),
        FOREIGN KEY (material_uuid) REFERENCES materials (uuid)
      )
    ''');

    // Vendor Price List table
    await db.execute('''
      CREATE TABLE vendor_price_lists (
        uuid TEXT PRIMARY KEY,
        manufacturer_material_uuid TEXT NOT NULL,
        vendor_uuid TEXT NOT NULL,
        rate REAL NOT NULL,
        rate_before_tax REAL DEFAULT 0.0,
        currency TEXT,
        tax_percent REAL NOT NULL,
        tax_amount REAL NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (manufacturer_material_uuid) REFERENCES manufacturer_materials (uuid),
        FOREIGN KEY (vendor_uuid) REFERENCES vendors (uuid)
      )
    ''');

    // Purchase Orders table
    await db.execute('''
      CREATE TABLE purchase_orders (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        vendor_uuid TEXT NOT NULL,
        date TEXT NOT NULL,
        base_price REAL NOT NULL,
        tax_amount REAL NOT NULL,
        total_amount REAL NOT NULL,
        currency TEXT,
        order_date TEXT NOT NULL,
        expected_delivery_date TEXT,
        amount_paid REAL DEFAULT 0.0,
        amount_balance REAL DEFAULT 0.0,
        completed INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vendor_uuid) REFERENCES vendors (uuid)
      )
    ''');

    // Purchase Order Items table
    await db.execute('''
      CREATE TABLE purchase_order_items (
        uuid TEXT PRIMARY KEY,
        purchase_order_uuid TEXT NOT NULL,
        manufacturer_material_uuid TEXT NOT NULL,
        material_uuid TEXT DEFAULT '',
        model TEXT DEFAULT '',
        quantity REAL NOT NULL,
        rate REAL NOT NULL,
        rate_before_tax REAL DEFAULT 0.0,
        base_price REAL NOT NULL,
        tax_percent REAL NOT NULL,
        tax_amount REAL NOT NULL,
        total_amount REAL NOT NULL,
        currency TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (purchase_order_uuid) REFERENCES purchase_orders (uuid),
        FOREIGN KEY (manufacturer_material_uuid) REFERENCES manufacturer_materials (uuid)
      )
    ''');

    // Purchase Order Payments table
    await db.execute('''
      CREATE TABLE purchase_order_payments (
        uuid TEXT PRIMARY KEY,
        purchase_order_uuid TEXT NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT DEFAULT 'INR',
        upi_ref_number TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (purchase_order_uuid) REFERENCES purchase_orders (uuid)
      )
    ''');

    // Basket Header table
    await db.execute('''
      CREATE TABLE basket_headers (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        date TEXT NOT NULL,
        description TEXT,
        expected_delivery_date TEXT,
        total_price REAL DEFAULT 0.0,
        currency TEXT DEFAULT 'INR',
        number_of_items INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // Basket Items table
    await db.execute('''
      CREATE TABLE basket_items (
        uuid TEXT PRIMARY KEY,
        basket_uuid TEXT NOT NULL,
        id INTEGER,
        manufacturer_material_uuid TEXT NOT NULL,
        material_uuid TEXT,
        model TEXT,
        manufacturer_uuid TEXT,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit_of_measure TEXT,
        max_retail_price REAL,
        price REAL DEFAULT 0.0,
        currency TEXT DEFAULT 'INR',
        updated_at TEXT NOT NULL,
        FOREIGN KEY (basket_uuid) REFERENCES basket_headers (uuid),
        FOREIGN KEY (manufacturer_material_uuid) REFERENCES manufacturer_materials (uuid)
      )
    ''');

    // Basket Vendors table
    await db.execute('''
      CREATE TABLE basket_vendors (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        basket_uuid TEXT NOT NULL,
        vendor_uuid TEXT NOT NULL,
        date TEXT NOT NULL,
        expected_delivery_date TEXT,
        base_price REAL DEFAULT 0.0,
        tax_amount REAL DEFAULT 0.0,
        total_amount REAL DEFAULT 0.0,
        currency TEXT DEFAULT 'INR',
        number_of_available_items INTEGER DEFAULT 0,
        number_of_unavailable_items INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (basket_uuid) REFERENCES basket_headers (uuid),
        FOREIGN KEY (vendor_uuid) REFERENCES vendors (uuid)
      )
    ''');

    // Basket Vendor Items table
    await db.execute('''
      CREATE TABLE basket_vendor_items (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        basket_vendor_uuid TEXT NOT NULL,
        basket_uuid TEXT NOT NULL,
        basket_item_uuid TEXT NOT NULL,
        vendor_price_list_uuid TEXT,
        item_available_with_vendor INTEGER DEFAULT 0,
        manufacturer_material_uuid TEXT,
        material_uuid TEXT,
        model TEXT,
        quantity REAL NOT NULL DEFAULT 1.0,
        max_retail_price REAL,
        rate REAL DEFAULT 0.0,
        rate_before_tax REAL DEFAULT 0.0,
        base_price REAL DEFAULT 0.0,
        tax_percent REAL DEFAULT 0.0,
        tax_amount REAL DEFAULT 0.0,
        total_amount REAL DEFAULT 0.0,
        currency TEXT DEFAULT 'INR',
        updated_at TEXT NOT NULL,
        FOREIGN KEY (basket_vendor_uuid) REFERENCES basket_vendors (uuid),
        FOREIGN KEY (basket_uuid) REFERENCES basket_headers (uuid),
        FOREIGN KEY (basket_item_uuid) REFERENCES basket_items (uuid),
        FOREIGN KEY (vendor_price_list_uuid) REFERENCES vendor_price_lists (uuid)
      )
    ''');

    // Sync metadata table for storing sync configuration and state
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Change log table for delta sync
    await db.execute('''
      CREATE TABLE change_log (
        uuid TEXT PRIMARY KEY,
        table_index INTEGER NOT NULL,
        table_key_uuid TEXT NOT NULL,
        change_mode TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Create indexes for better performance
    await db.execute(
        'CREATE INDEX idx_manufacturer_materials_manufacturer ON manufacturer_materials(manufacturer_uuid)');
    await db.execute(
        'CREATE INDEX idx_manufacturer_materials_material ON manufacturer_materials(material_uuid)');
    await db.execute(
        'CREATE INDEX idx_vendor_price_lists_vendor ON vendor_price_lists(vendor_uuid)');
    await db.execute(
        'CREATE INDEX idx_vendor_price_lists_material ON vendor_price_lists(manufacturer_material_uuid)');
    await db.execute(
        'CREATE INDEX idx_purchase_order_items_po ON purchase_order_items(purchase_order_uuid)');
    await db.execute(
        'CREATE INDEX idx_basket_items_basket ON basket_items(basket_uuid)');
    await db.execute(
        'CREATE INDEX idx_basket_items_manufacturer_material ON basket_items(manufacturer_material_uuid)');
    await db.execute(
        'CREATE INDEX idx_basket_vendors_basket ON basket_vendors(basket_uuid)');
    await db.execute(
        'CREATE INDEX idx_basket_vendors_vendor ON basket_vendors(vendor_uuid)');
    await db.execute(
        'CREATE INDEX idx_basket_vendor_items_basket_vendor ON basket_vendor_items(basket_vendor_uuid)');
    await db.execute(
        'CREATE INDEX idx_basket_vendor_items_basket ON basket_vendor_items(basket_uuid)');
    await db.execute(
        'CREATE INDEX idx_basket_vendor_items_basket_item ON basket_vendor_items(basket_item_uuid)');
    await db.execute(
        'CREATE INDEX idx_change_log_updated_at ON change_log(updated_at)');
    await db.execute(
        'CREATE INDEX idx_change_log_table_index ON change_log(table_index)');
  }

  // Manufacturers CRUD
  Future<int> insertManufacturer(Manufacturer manufacturer) async {
    final db = await database;

    // Get the next numeric id if not provided
    int? nextId = manufacturer.id;
    nextId ??= await _getNextId('manufacturers');

    final map = manufacturer.toMap();
    map['id'] = nextId;

    final result = await db.insert('manufacturers', map);

    // Log change for delta sync
    await logChange(
        'manufacturers', manufacturer.uuid, SyncConfig.changeModeInsert);

    return result;
  }

  Future<List<Manufacturer>> getAllManufacturers() async {
    final db = await database;
    final result = await db.query('manufacturers', orderBy: 'name');
    return result.map((map) => Manufacturer.fromMap(map)).toList();
  }

  Future<Manufacturer?> getManufacturer(String uuid) async {
    final db = await database;
    final result = await db.query(
      'manufacturers',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return Manufacturer.fromMap(result.first);
  }

  Future<int> updateManufacturer(Manufacturer manufacturer) async {
    final db = await database;
    final result = await db.update(
      'manufacturers',
      manufacturer.toMap(),
      where: 'uuid = ?',
      whereArgs: [manufacturer.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'manufacturers', manufacturer.uuid, SyncConfig.changeModeUpdate);
    }

    return result;
  }

  Future<int> deleteManufacturer(String uuid) async {
    final db = await database;

    final result = await db.delete(
      'manufacturers',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('manufacturers', uuid, SyncConfig.changeModeDelete);
    }

    return result;
  }

  // Check if manufacturer is in use
  Future<bool> isManufacturerInUse(String uuid) async {
    final db = await database;
    final result = await db.query(
      'manufacturer_materials',
      where: 'manufacturer_uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Vendors CRUD
  Future<int> insertVendor(Vendor vendor) async {
    final db = await database;

    // Get the next numeric id if not provided
    int? nextId = vendor.id;
    nextId ??= await _getNextId('vendors');

    final map = vendor.toMap();
    map['id'] = nextId;

    final result = await db.insert('vendors', map);

    // Log change for delta sync
    await logChange('vendors', vendor.uuid, SyncConfig.changeModeInsert);

    return result;
  }

  Future<List<Vendor>> getAllVendors() async {
    final db = await database;
    final result = await db.query('vendors', orderBy: 'name');
    return result.map((map) => Vendor.fromMap(map)).toList();
  }

  Future<Vendor?> getVendor(String uuid) async {
    final db = await database;
    final result = await db.query(
      'vendors',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return Vendor.fromMap(result.first);
  }

  Future<int> updateVendor(Vendor vendor) async {
    final db = await database;
    final result = await db.update(
      'vendors',
      vendor.toMap(),
      where: 'uuid = ?',
      whereArgs: [vendor.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('vendors', vendor.uuid, SyncConfig.changeModeUpdate);
    }

    return result;
  }

  Future<int> deleteVendor(String uuid) async {
    final db = await database;

    final result = await db.delete(
      'vendors',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('vendors', uuid, SyncConfig.changeModeDelete);
    }

    return result;
  }

  // Check if vendor is in use
  Future<bool> isVendorInUse(String uuid) async {
    final db = await database;

    // Check vendor_price_lists
    final vplResult = await db.query(
      'vendor_price_lists',
      where: 'vendor_uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (vplResult.isNotEmpty) return true;

    // Check purchase_orders
    final poResult = await db.query(
      'purchase_orders',
      where: 'vendor_uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return poResult.isNotEmpty;
  }

  // Materials CRUD
  Future<int> insertMaterial(Material material) async {
    final db = await database;

    // Get the next numeric id if not provided
    int? nextId = material.id;
    nextId ??= await _getNextId('materials');

    final map = material.toMap();
    map['id'] = nextId;

    final result = await db.insert('materials', map);

    // Log change for delta sync
    await logChange('materials', material.uuid, SyncConfig.changeModeInsert);

    return result;
  }

  Future<List<Material>> getAllMaterials() async {
    final db = await database;
    final result = await db.query('materials', orderBy: 'name');
    return result.map((map) => Material.fromMap(map)).toList();
  }

  Future<Material?> getMaterial(String uuid) async {
    final db = await database;
    final result = await db.query(
      'materials',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return Material.fromMap(result.first);
  }

  Future<int> updateMaterial(Material material) async {
    final db = await database;
    final result = await db.update(
      'materials',
      material.toMap(),
      where: 'uuid = ?',
      whereArgs: [material.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('materials', material.uuid, SyncConfig.changeModeUpdate);
    }

    return result;
  }

  Future<int> deleteMaterial(String uuid) async {
    final db = await database;

    final result = await db.delete(
      'materials',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('materials', uuid, SyncConfig.changeModeDelete);
    }

    return result;
  }

  // Check if material is in use
  Future<bool> isMaterialInUse(String uuid) async {
    final db = await database;

    // Check manufacturer_materials
    final mmResult = await db.query(
      'manufacturer_materials',
      where: 'material_uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (mmResult.isNotEmpty) return true;

    // Check purchase_order_items (uses material_uuid after denormalization)
    final poiResult = await db.query(
      'purchase_order_items',
      where: 'material_uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return poiResult.isNotEmpty;
  }

  // Manufacturer Materials CRUD
  Future<int> insertManufacturerMaterial(ManufacturerMaterial mm) async {
    final db = await database;
    final result = await db.insert('manufacturer_materials', mm.toMap());

    // Log change for delta sync
    await logChange(
        'manufacturer_materials', mm.uuid, SyncConfig.changeModeInsert);

    return result;
  }

  Future<List<ManufacturerMaterial>> getAllManufacturerMaterials() async {
    final db = await database;
    final result = await db.query('manufacturer_materials', orderBy: 'model');
    return result.map((map) => ManufacturerMaterial.fromMap(map)).toList();
  }

  // Efficient JOIN query to get all manufacturer materials with related data in one query
  Future<List<ManufacturerMaterialWithDetails>>
      getAllManufacturerMaterialsWithDetails({
    String? manufacturerUuid,
    String? materialUuid,
  }) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (manufacturerUuid != null && manufacturerUuid.isNotEmpty) {
      where += ' AND mfr.uuid = ?';
      whereArgs.add(manufacturerUuid);
    }
    if (materialUuid != null && materialUuid.isNotEmpty) {
      where += ' AND mat.uuid = ?';
      whereArgs.add(materialUuid);
    }

    final result = await db.rawQuery('''
      SELECT 
        mm.uuid,
        mm.manufacturer_uuid,
        mm.material_uuid,
        mm.model,
        mm.selling_lot_size,
        mm.max_retail_price,
        mm.currency,
        mm.updated_at,
        mfr.name as manufacturer_name,
        mat.name as material_name,
        mat.unit_of_measure as material_unit_of_measure
      FROM manufacturer_materials mm
      INNER JOIN manufacturers mfr ON mm.manufacturer_uuid = mfr.uuid
      INNER JOIN materials mat ON mm.material_uuid = mat.uuid
      WHERE $where
      ORDER BY mat.name, mfr.name, mm.model
    ''', whereArgs);

    return result
        .map((map) => ManufacturerMaterialWithDetails.fromMap(map))
        .toList();
  }

  Future<List<ManufacturerMaterial>> getManufacturerMaterialsByMaterial(
      String materialUuid) async {
    final db = await database;
    final result = await db.query(
      'manufacturer_materials',
      where: 'material_uuid = ?',
      whereArgs: [materialUuid],
      orderBy: 'model',
    );
    return result.map((map) => ManufacturerMaterial.fromMap(map)).toList();
  }

  Future<List<ManufacturerMaterial>> searchManufacturerMaterials({
    String? manufacturerUuid,
    String? materialUuid,
  }) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (manufacturerUuid != null && manufacturerUuid.isNotEmpty) {
      where += ' AND manufacturer_uuid = ?';
      whereArgs.add(manufacturerUuid);
    }
    if (materialUuid != null && materialUuid.isNotEmpty) {
      where += ' AND material_uuid = ?';
      whereArgs.add(materialUuid);
    }

    final result = await db.query(
      'manufacturer_materials',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'model',
    );
    return result.map((map) => ManufacturerMaterial.fromMap(map)).toList();
  }

  Future<ManufacturerMaterial?> getManufacturerMaterial(String uuid) async {
    final db = await database;
    final result = await db.query(
      'manufacturer_materials',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return ManufacturerMaterial.fromMap(result.first);
  }

  Future<ManufacturerMaterialWithDetails?> getManufacturerMaterialWithDetails(
      String uuid) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT mm.*, 
             m.name as manufacturer_name,
             mat.name as material_name,
             mat.unit_of_measure as material_unit_of_measure
      FROM manufacturer_materials mm
      INNER JOIN manufacturers m ON mm.manufacturer_uuid = m.uuid
      INNER JOIN materials mat ON mm.material_uuid = mat.uuid
      WHERE mm.uuid = ?
    ''', [uuid]);
    if (result.isEmpty) return null;
    return ManufacturerMaterialWithDetails.fromMap(result.first);
  }

  Future<int> updateManufacturerMaterial(ManufacturerMaterial mm) async {
    final db = await database;
    final result = await db.update(
      'manufacturer_materials',
      mm.toMap(),
      where: 'uuid = ?',
      whereArgs: [mm.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'manufacturer_materials', mm.uuid, SyncConfig.changeModeUpdate);
    }

    return result;
  }

  Future<int> deleteManufacturerMaterial(String uuid) async {
    final db = await database;

    final result = await db.delete(
      'manufacturer_materials',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'manufacturer_materials', uuid, SyncConfig.changeModeDelete);
    }

    return result;
  }

  // Check if manufacturer material is in use
  Future<bool> isManufacturerMaterialInUse(String uuid) async {
    final db = await database;
    final vplResult = await db.query(
      'vendor_price_lists',
      where: 'manufacturer_material_uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (vplResult.isNotEmpty) return true;

    final poiResult = await db.query(
      'purchase_order_items',
      where: 'manufacturer_material_uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return poiResult.isNotEmpty;
  }

  // Vendor Price Lists CRUD
  Future<int> insertVendorPriceList(VendorPriceList vpl) async {
    final db = await database;
    final result = await db.insert('vendor_price_lists', vpl.toMap());

    // Log change for delta sync
    await logChange(
        'vendor_price_lists', vpl.uuid, SyncConfig.changeModeInsert);

    return result;
  }

  Future<List<VendorPriceList>> getAllVendorPriceLists() async {
    final db = await database;
    final result =
        await db.query('vendor_price_lists', orderBy: 'updated_at DESC');
    return result.map((map) => VendorPriceList.fromMap(map)).toList();
  }

  // Efficient JOIN query to get all vendor price lists with related data in one query
  Future<List<VendorPriceListWithDetails>> getAllVendorPriceListsWithDetails({
    String? vendorUuid,
    String? manufacturerUuid,
    String? materialUuid,
  }) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (vendorUuid != null && vendorUuid.isNotEmpty) {
      where += ' AND v.uuid = ?';
      whereArgs.add(vendorUuid);
    }
    if (manufacturerUuid != null && manufacturerUuid.isNotEmpty) {
      where += ' AND mfr.uuid = ?';
      whereArgs.add(manufacturerUuid);
    }
    if (materialUuid != null && materialUuid.isNotEmpty) {
      where += ' AND mat.uuid = ?';
      whereArgs.add(materialUuid);
    }

    final result = await db.rawQuery('''
      SELECT 
        vpl.uuid,
        vpl.manufacturer_material_uuid,
        vpl.vendor_uuid,
        vpl.rate,
        vpl.rate_before_tax,
        vpl.currency,
        vpl.tax_percent,
        vpl.tax_amount,
        vpl.updated_at,
        v.name as vendor_name,
        mfr.name as manufacturer_name,
        mat.name as material_name,
        mat.unit_of_measure as material_unit_of_measure,
        mm.model as manufacturer_material_model
      FROM vendor_price_lists vpl
      INNER JOIN vendors v ON vpl.vendor_uuid = v.uuid
      INNER JOIN manufacturer_materials mm ON vpl.manufacturer_material_uuid = mm.uuid
      INNER JOIN manufacturers mfr ON mm.manufacturer_uuid = mfr.uuid
      INNER JOIN materials mat ON mm.material_uuid = mat.uuid
      WHERE $where
      ORDER BY v.name, mfr.name, mat.name, mm.model
    ''', whereArgs);

    return result
        .map((map) => VendorPriceListWithDetails.fromMap(map))
        .toList();
  }

  Future<List<VendorPriceList>> searchVendorPriceLists({
    String? vendorUuid,
    String? manufacturerUuid,
    String? materialUuid,
  }) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (vendorUuid != null && vendorUuid.isNotEmpty) {
      where += ' AND vpl.vendor_uuid = ?';
      whereArgs.add(vendorUuid);
    }
    if (manufacturerUuid != null && manufacturerUuid.isNotEmpty) {
      where += ' AND mm.manufacturer_uuid = ?';
      whereArgs.add(manufacturerUuid);
    }
    if (materialUuid != null && materialUuid.isNotEmpty) {
      where += ' AND mm.material_uuid = ?';
      whereArgs.add(materialUuid);
    }

    final result = await db.rawQuery('''
      SELECT vpl.* FROM vendor_price_lists vpl
      INNER JOIN manufacturer_materials mm ON vpl.manufacturer_material_uuid = mm.uuid
      WHERE $where
      ORDER BY vpl.updated_at DESC
    ''', whereArgs);

    return result.map((map) => VendorPriceList.fromMap(map)).toList();
  }

  Future<List<VendorPriceList>> getVendorPriceListsByVendor(
      String vendorUuid) async {
    final db = await database;
    final result = await db.query(
      'vendor_price_lists',
      where: 'vendor_uuid = ?',
      whereArgs: [vendorUuid],
      orderBy: 'updated_at DESC',
    );
    return result.map((map) => VendorPriceList.fromMap(map)).toList();
  }

  Future<List<VendorPriceList>> getVendorPriceListsByManufacturerMaterial(
      String mmId) async {
    final db = await database;
    final result = await db.query(
      'vendor_price_lists',
      where: 'manufacturer_material_uuid = ?',
      whereArgs: [mmId],
      orderBy: 'updated_at DESC',
    );
    return result.map((map) => VendorPriceList.fromMap(map)).toList();
  }

  Future<VendorPriceList?> getVendorPriceList(String uuid) async {
    final db = await database;
    final result = await db.query(
      'vendor_price_lists',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return VendorPriceList.fromMap(result.first);
  }

  Future<VendorPriceList?> getVendorPriceListByVendorAndMaterial(
      String vendorUuid, String manufacturerMaterialUuid) async {
    final db = await database;
    final result = await db.query(
      'vendor_price_lists',
      where: 'vendor_uuid = ? AND manufacturer_material_uuid = ?',
      whereArgs: [vendorUuid, manufacturerMaterialUuid],
    );
    if (result.isEmpty) return null;
    return VendorPriceList.fromMap(result.first);
  }

  Future<int> updateVendorPriceList(VendorPriceList vpl) async {
    final db = await database;
    final result = await db.update(
      'vendor_price_lists',
      vpl.toMap(),
      where: 'uuid = ?',
      whereArgs: [vpl.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'vendor_price_lists', vpl.uuid, SyncConfig.changeModeUpdate);
    }

    return result;
  }

  Future<int> deleteVendorPriceList(String uuid) async {
    final db = await database;

    final result = await db.delete(
      'vendor_price_lists',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('vendor_price_lists', uuid, SyncConfig.changeModeDelete);
    }

    return result;
  }

  // Purchase Orders CRUD
  Future<int> insertPurchaseOrder(PurchaseOrder po) async {
    final db = await database;

    // Get the next numeric id if not provided
    int? nextId = po.id;
    nextId ??= await _getNextId('purchase_orders');

    // Create a new map with the generated id
    final poMap = po.toMap();
    poMap['id'] = nextId;

    await db.insert('purchase_orders', poMap);

    // Log change for delta sync
    await logChange('purchase_orders', po.uuid, SyncConfig.changeModeInsert);

    return nextId;
  }

  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    final db = await database;
    final result = await db.query('purchase_orders',
        orderBy:
            'updated_at DESC, order_date DESC, expected_delivery_date DESC');
    return result.map((map) => PurchaseOrder.fromMap(map)).toList();
  }

  Future<PurchaseOrder?> getPurchaseOrder(String uuid) async {
    final db = await database;
    final result = await db.query(
      'purchase_orders',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return PurchaseOrder.fromMap(result.first);
  }

  Future<int> updatePurchaseOrder(PurchaseOrder po) async {
    final db = await database;
    final result = await db.update(
      'purchase_orders',
      po.toMap(),
      where: 'uuid = ?',
      whereArgs: [po.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('purchase_orders', po.uuid, SyncConfig.changeModeUpdate);
    }

    return result;
  }

  Future<int> deletePurchaseOrder(String uuid) async {
    final db = await database;

    // Get all child items to track their deletion
    final items = await db.query(
      'purchase_order_items',
      columns: ['uuid'],
      where: 'purchase_order_uuid = ?',
      whereArgs: [uuid],
    );

    // Track deletion of all child items
    for (final item in items) {
      // Log change for delta sync
      await logChange('purchase_order_items', item['uuid'] as String,
          SyncConfig.changeModeDelete);
    }

    // Delete items first
    await db.delete(
      'purchase_order_items',
      where: 'purchase_order_uuid = ?',
      whereArgs: [uuid],
    );

    // Then delete the order
    final result = await db.delete(
      'purchase_orders',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('purchase_orders', uuid, SyncConfig.changeModeDelete);
    }

    return result;
  }

  // Purchase Order Items CRUD
  Future<int> insertPurchaseOrderItem(PurchaseOrderItem poi) async {
    final db = await database;
    final result = await db.insert('purchase_order_items', poi.toMap());

    // Log change for delta sync
    await logChange(
        'purchase_order_items', poi.uuid, SyncConfig.changeModeInsert);

    return result;
  }

  Future<List<PurchaseOrderItem>> getPurchaseOrderItems(
      String purchaseOrderUuid) async {
    final db = await database;
    final result = await db.query(
      'purchase_order_items',
      where: 'purchase_order_uuid = ?',
      whereArgs: [purchaseOrderUuid],
      orderBy: 'updated_at',
    );
    return result.map((map) => PurchaseOrderItem.fromMap(map)).toList();
  }

  Future<PurchaseOrderItem?> getPurchaseOrderItem(String uuid) async {
    final db = await database;
    final result = await db.query(
      'purchase_order_items',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return PurchaseOrderItem.fromMap(result.first);
  }

  Future<int> updatePurchaseOrderItem(PurchaseOrderItem poi) async {
    final db = await database;
    final result = await db.update(
      'purchase_order_items',
      poi.toMap(),
      where: 'uuid = ?',
      whereArgs: [poi.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'purchase_order_items', poi.uuid, SyncConfig.changeModeUpdate);
    }

    return result;
  }

  Future<int> deletePurchaseOrderItem(String uuid) async {
    final db = await database;

    final result = await db.delete(
      'purchase_order_items',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'purchase_order_items', uuid, SyncConfig.changeModeDelete);
    }

    return result;
  }

  // Purchase Order Payments CRUD
  Future<int> insertPurchaseOrderPayment(PurchaseOrderPayment payment) async {
    final db = await database;
    final result = await db.insert('purchase_order_payments', payment.toMap());

    // Log change for delta sync
    await logChange(
        'purchase_order_payments', payment.uuid, SyncConfig.changeModeInsert);

    return result;
  }

  Future<List<PurchaseOrderPayment>> getPurchaseOrderPayments(
      String purchaseOrderUuid) async {
    final db = await database;
    final result = await db.query(
      'purchase_order_payments',
      where: 'purchase_order_uuid = ?',
      whereArgs: [purchaseOrderUuid],
      orderBy: 'date DESC',
    );
    return result.map((map) => PurchaseOrderPayment.fromMap(map)).toList();
  }

  Future<PurchaseOrderPayment?> getPurchaseOrderPayment(String uuid) async {
    final db = await database;
    final result = await db.query(
      'purchase_order_payments',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return PurchaseOrderPayment.fromMap(result.first);
  }

  Future<int> updatePurchaseOrderPayment(PurchaseOrderPayment payment) async {
    final db = await database;
    final result = await db.update(
      'purchase_order_payments',
      payment.toMap(),
      where: 'uuid = ?',
      whereArgs: [payment.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'purchase_order_payments', payment.uuid, SyncConfig.changeModeUpdate);
    }

    return result;
  }

  Future<int> deletePurchaseOrderPayment(String uuid) async {
    final db = await database;

    final result = await db.delete(
      'purchase_order_payments',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'purchase_order_payments', uuid, SyncConfig.changeModeDelete);
    }

    return result;
  }

  // Get manufacturer materials available for a vendor (through vendor price list)
  Future<List<ManufacturerMaterial>> getManufacturerMaterialsByVendor(
      String vendorUuid) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT mm.* FROM manufacturer_materials mm
      INNER JOIN vendor_price_lists vpl ON mm.uuid = vpl.manufacturer_material_uuid
      WHERE vpl.vendor_uuid = ?
      ORDER BY mm.model
    ''', [vendorUuid]);
    return result.map((map) => ManufacturerMaterial.fromMap(map)).toList();
  }

  // Get manufacturer materials with details and vendor pricing - for purchase order item selection
  Future<List<ManufacturerMaterialWithDetails>>
      getManufacturerMaterialsWithPricingByVendor(String vendorUuid) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        mm.uuid,
        mm.manufacturer_uuid,
        mm.material_uuid,
        mm.model,
        mm.selling_lot_size,
        mm.max_retail_price,
        mm.currency,
        mm.updated_at,
        mfr.name as manufacturer_name,
        mat.name as material_name,
        mat.unit_of_measure as material_unit_of_measure,
        vpl.rate as vendor_rate,
        vpl.rate_before_tax as vendor_rate_before_tax,
        vpl.currency as vendor_currency,
        vpl.tax_percent as vendor_tax_percent
      FROM manufacturer_materials mm
      INNER JOIN manufacturers mfr ON mm.manufacturer_uuid = mfr.uuid
      INNER JOIN materials mat ON mm.material_uuid = mat.uuid
      INNER JOIN vendor_price_lists vpl ON mm.uuid = vpl.manufacturer_material_uuid
      WHERE vpl.vendor_uuid = ?
      ORDER BY mat.name, mfr.name, mm.model
    ''', [vendorUuid]);
    return result
        .map((map) => ManufacturerMaterialWithDetails.fromMap(map))
        .toList();
  }

  // Check if model is in use (for materials screen)
  Future<bool> isModelInUse(String manufacturerMaterialUuid) async {
    return await isManufacturerMaterialInUse(manufacturerMaterialUuid);
  }

  // Clear all data from database
  Future<void> clearAllData() async {
    final db = await database;

    // Delete in reverse order of dependencies
    // Note: Using direct db.delete() to bypass change logging
    // This is intentional - cleanup is for local testing, not for sync
    await db.delete('purchase_order_payments');
    await db.delete('purchase_order_items');
    await db.delete('purchase_orders');
    await db.delete('basket_vendor_items');
    await db.delete('basket_items');
    await db.delete('basket_vendors');
    await db.delete('basket_headers');
    await db.delete('vendor_price_lists');
    await db.delete('manufacturer_materials');
    await db.delete('materials');
    await db.delete('vendors');
    await db.delete('manufacturers');

    // Also clear change log since we're starting fresh
    await db.delete('change_log');

    // Clear change log for delta sync
    await db.delete('change_log');

    // Reset sync timestamp so next sync pulls all data from server
    // Keep web_app_url and secret_code as they are configuration values
    await db.delete(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: ['last_sync_timestamp'],
    );
  }

  // Sync metadata operations
  Future<void> setSyncMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSyncMetadata(String key) async {
    final db = await database;
    final result = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );
    return result.isNotEmpty ? result.first['value'] as String : null;
  }

  Future<void> deleteSyncMetadata(String key) async {
    final db = await database;
    await db.delete(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  /// Log a change to the change_log table for delta sync
  Future<void> logChange(
      String tableName, String uuid, String changeMode) async {
    final db = await database;
    final tableIndex = SyncConfig.getTableIndex(tableName);

    if (tableIndex == null) {
      // Table not configured for delta sync, skip logging
      return;
    }

    // Generate UUID for change log entry
    final changeLogUuid = _uuid.v4();

    await db.insert('change_log', {
      'uuid': changeLogUuid,
      'table_index': tableIndex,
      'table_key_uuid': uuid,
      'change_mode': changeMode,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get change log entries since a specific timestamp
  Future<List<Map<String, dynamic>>> getChangeLog(
      String? sinceTimestamp) async {
    final db = await database;

    if (sinceTimestamp != null) {
      return await db.query(
        'change_log',
        where: 'updated_at > ?',
        whereArgs: [sinceTimestamp],
        orderBy: 'updated_at ASC',
      );
    } else {
      return await db.query(
        'change_log',
        orderBy: 'updated_at ASC',
      );
    }
  }

  /// Clear change log up to a specific timestamp
  Future<void> clearChangeLog(String upToTimestamp) async {
    final db = await database;
    await db.delete(
      'change_log',
      where: 'updated_at <= ?',
      whereArgs: [upToTimestamp],
    );
  }

  /// Check if there are pending changes in the change log
  Future<bool> hasPendingChanges() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM change_log');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  // Basket Header CRUD
  Future<int> insertBasketHeader(BasketHeader basket) async {
    final db = await database;

    // Get the next numeric id if not provided
    int? nextId = basket.id;
    nextId ??= await _getNextId('basket_headers');

    final basketWithId = basket.copyWith(id: nextId);
    final result = await db.insert('basket_headers', basketWithId.toMap());

    // Log change for delta sync
    await logChange('basket_headers', basket.uuid, SyncConfig.changeModeInsert);

    return result;
  }

  Future<List<BasketHeader>> getAllBasketHeaders() async {
    final db = await database;
    final result =
        await db.query('basket_headers', orderBy: 'date DESC, id DESC');
    return result.map((map) => BasketHeader.fromMap(map)).toList();
  }

  Future<BasketHeader?> getBasketHeader(String uuid) async {
    final db = await database;
    final result = await db.query(
      'basket_headers',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return BasketHeader.fromMap(result.first);
  }

  Future<int> updateBasketHeader(BasketHeader basket) async {
    final db = await database;
    final result = await db.update(
      'basket_headers',
      basket.toMap(),
      where: 'uuid = ?',
      whereArgs: [basket.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'basket_headers', basket.uuid, SyncConfig.changeModeUpdate);
    }

    return result;
  }

  Future<int> deleteBasketHeader(String uuid) async {
    final db = await database;

    // Delete related basket items first
    await db
        .delete('basket_items', where: 'basket_uuid = ?', whereArgs: [uuid]);

    // Delete related basket vendors and their items
    final vendors = await getBasketVendors(uuid);
    for (var vendor in vendors) {
      await db.delete('basket_vendor_items',
          where: 'basket_vendor_uuid = ?', whereArgs: [vendor.uuid]);
    }
    await db
        .delete('basket_vendors', where: 'basket_uuid = ?', whereArgs: [uuid]);

    final result = await db.delete(
      'basket_headers',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('basket_headers', uuid, SyncConfig.changeModeDelete);
    }

    return result;
  }

  // Basket Item CRUD
  Future<int> insertBasketItem(BasketItem item) async {
    final db = await database;

    // Get the next numeric id if not provided
    int? nextId = item.id;
    nextId ??= await _getNextIdForBasket('basket_items', item.basketUuid);

    final itemWithId = item.copyWith(id: nextId);
    final result = await db.insert('basket_items', itemWithId.toMap());

    // Log change for delta sync
    await logChange('basket_items', item.uuid, SyncConfig.changeModeInsert);

    // Update basket header totals
    await _updateBasketHeaderTotals(item.basketUuid);

    // Add corresponding vendor items to all existing vendor quotations
    await _syncVendorItemsForBasketItem(item.basketUuid, itemWithId, 'insert');

    return result;
  }

  Future<List<BasketItem>> getBasketItems(String basketUuid) async {
    final db = await database;
    final result = await db.query(
      'basket_items',
      where: 'basket_uuid = ?',
      whereArgs: [basketUuid],
      orderBy: 'id ASC',
    );
    return result.map((map) => BasketItem.fromMap(map)).toList();
  }

  Future<BasketItem?> getBasketItem(String uuid) async {
    final db = await database;
    final result = await db.query(
      'basket_items',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return BasketItem.fromMap(result.first);
  }

  Future<int> updateBasketItem(BasketItem item) async {
    final db = await database;
    final result = await db.update(
      'basket_items',
      item.toMap(),
      where: 'uuid = ?',
      whereArgs: [item.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('basket_items', item.uuid, SyncConfig.changeModeUpdate);

      // Update basket header totals
      await _updateBasketHeaderTotals(item.basketUuid);

      // Update corresponding vendor items
      await _syncVendorItemsForBasketItem(item.basketUuid, item, 'update');
    }

    return result;
  }

  Future<int> deleteBasketItem(String uuid) async {
    final db = await database;

    // Get the item to find basket_uuid
    final item = await getBasketItem(uuid);
    if (item == null) return 0;

    // Get all affected vendor quotations before deleting
    final affectedVendors = await db.query(
      'basket_vendor_items',
      columns: ['basket_vendor_uuid'],
      where: 'basket_item_uuid = ?',
      whereArgs: [uuid],
      distinct: true,
    );

    // Delete related basket vendor items
    await db.delete('basket_vendor_items',
        where: 'basket_item_uuid = ?', whereArgs: [uuid]);

    final result = await db.delete(
      'basket_items',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('basket_items', uuid, SyncConfig.changeModeDelete);

      // Update basket header totals
      await _updateBasketHeaderTotals(item.basketUuid);

      // Update totals for all affected vendor quotations
      for (var vendorMap in affectedVendors) {
        final vendorUuid = vendorMap['basket_vendor_uuid'] as String;
        await _updateBasketVendorTotals(vendorUuid);
      }
    }

    return result;
  }

  // Basket Vendor CRUD
  Future<int> insertBasketVendor(BasketVendor vendor) async {
    final db = await database;

    // Get the next numeric id if not provided
    int? nextId = vendor.id;
    nextId ??= await _getNextIdForBasket('basket_vendors', vendor.basketUuid);

    final vendorWithId = vendor.copyWith(id: nextId);
    final result = await db.insert('basket_vendors', vendorWithId.toMap());

    // Log change for delta sync
    await logChange('basket_vendors', vendor.uuid, SyncConfig.changeModeInsert);

    return result;
  }

  Future<List<BasketVendor>> getBasketVendors(String basketUuid) async {
    final db = await database;
    final result = await db.query(
      'basket_vendors',
      where: 'basket_uuid = ?',
      whereArgs: [basketUuid],
      orderBy: 'id ASC',
    );
    return result.map((map) => BasketVendor.fromMap(map)).toList();
  }

  Future<BasketVendor?> getBasketVendor(String uuid) async {
    final db = await database;
    final result = await db.query(
      'basket_vendors',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return BasketVendor.fromMap(result.first);
  }

  Future<int> updateBasketVendor(BasketVendor vendor) async {
    final db = await database;
    final result = await db.update(
      'basket_vendors',
      vendor.toMap(),
      where: 'uuid = ?',
      whereArgs: [vendor.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'basket_vendors', vendor.uuid, SyncConfig.changeModeUpdate);
    }

    return result;
  }

  Future<int> deleteBasketVendor(String uuid) async {
    final db = await database;

    // Delete related basket vendor items
    await db.delete('basket_vendor_items',
        where: 'basket_vendor_uuid = ?', whereArgs: [uuid]);

    final result = await db.delete(
      'basket_vendors',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('basket_vendors', uuid, SyncConfig.changeModeDelete);
    }

    return result;
  }

  // Basket Vendor Item CRUD
  Future<int> insertBasketVendorItem(BasketVendorItem item) async {
    final db = await database;
    final result = await db.insert('basket_vendor_items', item.toMap());

    // Log change for delta sync
    await logChange(
        'basket_vendor_items', item.uuid, SyncConfig.changeModeInsert);

    // Update basket vendor totals
    await _updateBasketVendorTotals(item.basketVendorUuid);

    return result;
  }

  Future<List<BasketVendorItem>> getBasketVendorItems(
      String basketVendorUuid) async {
    final db = await database;
    final result = await db.query(
      'basket_vendor_items',
      where: 'basket_vendor_uuid = ?',
      whereArgs: [basketVendorUuid],
    );
    return result.map((map) => BasketVendorItem.fromMap(map)).toList();
  }

  Future<BasketVendorItem?> getBasketVendorItem(String uuid) async {
    final db = await database;
    final result = await db.query(
      'basket_vendor_items',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (result.isEmpty) return null;
    return BasketVendorItem.fromMap(result.first);
  }

  Future<int> updateBasketVendorItem(BasketVendorItem item) async {
    final db = await database;
    final result = await db.update(
      'basket_vendor_items',
      item.toMap(),
      where: 'uuid = ?',
      whereArgs: [item.uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange(
          'basket_vendor_items', item.uuid, SyncConfig.changeModeUpdate);

      // Update basket vendor totals
      await _updateBasketVendorTotals(item.basketVendorUuid);
    }

    return result;
  }

  Future<int> deleteBasketVendorItem(String uuid) async {
    final db = await database;

    // Get the item to find basket_vendor_uuid
    final item = await getBasketVendorItem(uuid);
    if (item == null) return 0;

    final result = await db.delete(
      'basket_vendor_items',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log change for delta sync
    if (result > 0) {
      await logChange('basket_vendor_items', uuid, SyncConfig.changeModeDelete);

      // Update basket vendor totals
      await _updateBasketVendorTotals(item.basketVendorUuid);
    }

    return result;
  }

  // Helper methods for basket operations
  Future<int> _getNextIdForBasket(String tableName, String basketUuid) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(id) as max_id FROM $tableName WHERE basket_uuid = ?',
      [basketUuid],
    );
    final maxId = result.first['max_id'] as int?;
    return (maxId ?? 0) + 1;
  }

  Future<void> _updateBasketHeaderTotals(String basketUuid) async {
    final db = await database;

    // Get all basket items for this basket
    final items = await getBasketItems(basketUuid);

    // Calculate totals
    double totalPrice = 0.0;
    int numberOfItems = items.length;

    for (var item in items) {
      totalPrice += item.price;
    }

    // Update basket header
    await db.update(
      'basket_headers',
      {
        'total_price': totalPrice,
        'number_of_items': numberOfItems,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'uuid = ?',
      whereArgs: [basketUuid],
    );
  }

  Future<void> _updateBasketVendorTotals(String basketVendorUuid) async {
    final db = await database;

    // Get all basket vendor items for this vendor
    final items = await getBasketVendorItems(basketVendorUuid);

    // Calculate totals
    double basePrice = 0.0;
    double taxAmount = 0.0;
    double totalAmount = 0.0;
    int numberOfAvailableItems = 0;
    int numberOfUnavailableItems = 0;

    for (var item in items) {
      basePrice += item.basePrice;
      taxAmount += item.taxAmount;
      totalAmount += item.totalAmount;

      if (item.itemAvailableWithVendor) {
        numberOfAvailableItems++;
      } else {
        numberOfUnavailableItems++;
      }
    }

    // Update basket vendor
    await db.update(
      'basket_vendors',
      {
        'base_price': basePrice,
        'tax_amount': taxAmount,
        'total_amount': totalAmount,
        'number_of_available_items': numberOfAvailableItems,
        'number_of_unavailable_items': numberOfUnavailableItems,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'uuid = ?',
      whereArgs: [basketVendorUuid],
    );
  }

  /// Sync vendor items when basket items are added/updated
  Future<void> _syncVendorItemsForBasketItem(
      String basketUuid, BasketItem basketItem, String operation) async {
    final db = await database;

    // Get all vendor quotations for this basket
    final vendors = await getBasketVendors(basketUuid);

    for (var vendor in vendors) {
      if (operation == 'insert') {
        // Add new vendor item for this basket item
        await _createVendorItemForBasketItem(vendor, basketItem);
      } else if (operation == 'update') {
        // Update existing vendor item
        await _updateVendorItemForBasketItem(vendor, basketItem);
      }
    }
  }

  /// Create vendor item for a basket item
  Future<void> _createVendorItemForBasketItem(
      BasketVendor vendor, BasketItem basketItem) async {
    final db = await database;

    // Check if vendor item already exists
    final existing = await db.query(
      'basket_vendor_items',
      where: 'basket_vendor_uuid = ? AND basket_item_uuid = ?',
      whereArgs: [vendor.uuid, basketItem.uuid],
    );

    if (existing.isNotEmpty) return; // Already exists

    // Get vendor price list for this item
    final vplList = await db.query(
      'vendor_price_lists',
      where: 'vendor_uuid = ? AND manufacturer_material_uuid = ?',
      whereArgs: [vendor.vendorUuid, basketItem.manufacturerMaterialUuid],
    );

    VendorPriceList? vpl;
    if (vplList.isNotEmpty) {
      vpl = VendorPriceList.fromMap(vplList.first);
    }

    // Get next ID for vendor item
    int? nextId =
        await _getNextIdForBasket('basket_vendor_items', vendor.basketUuid);

    // Create vendor item
    final item = BasketVendorItem(
      uuid: const Uuid().v4(),
      id: nextId,
      basketVendorUuid: vendor.uuid,
      basketUuid: vendor.basketUuid,
      basketItemUuid: basketItem.uuid,
      vendorPriceListUuid: vpl?.uuid,
      itemAvailableWithVendor: vpl != null,
      manufacturerMaterialUuid: basketItem.manufacturerMaterialUuid,
      materialUuid: basketItem.materialUuid,
      model: basketItem.model,
      quantity: basketItem.quantity,
      maxRetailPrice: basketItem.maxRetailPrice,
      rate: vpl?.rate ?? 0.0,
      rateBeforeTax: vpl?.rateBeforeTax ?? 0.0,
      basePrice: vpl != null ? (vpl.rateBeforeTax * basketItem.quantity) : 0.0,
      taxPercent: vpl?.taxPercent ?? 0.0,
      taxAmount: vpl != null
          ? (vpl.rateBeforeTax * basketItem.quantity * vpl.taxPercent / 100.0)
          : 0.0,
      totalAmount: vpl != null ? (vpl.rate * basketItem.quantity) : 0.0,
      currency: vendor.currency,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await db.insert('basket_vendor_items', item.toMap());
    await logChange(
        'basket_vendor_items', item.uuid, SyncConfig.changeModeInsert);

    // Update vendor totals
    await _updateBasketVendorTotals(vendor.uuid);
  }

  /// Update vendor item when basket item quantity changes
  Future<void> _updateVendorItemForBasketItem(
      BasketVendor vendor, BasketItem basketItem) async {
    final db = await database;

    // Find existing vendor item
    final existing = await db.query(
      'basket_vendor_items',
      where: 'basket_vendor_uuid = ? AND basket_item_uuid = ?',
      whereArgs: [vendor.uuid, basketItem.uuid],
    );

    if (existing.isEmpty) {
      // Item doesn't exist yet, create it
      await _createVendorItemForBasketItem(vendor, basketItem);
      return;
    }

    final vendorItem = BasketVendorItem.fromMap(existing.first);

    // Recalculate prices based on new quantity
    final updatedItem = vendorItem.copyWith(
      quantity: basketItem.quantity,
      basePrice: vendorItem.rateBeforeTax * basketItem.quantity,
      taxAmount: vendorItem.rateBeforeTax *
          basketItem.quantity *
          vendorItem.taxPercent /
          100.0,
      totalAmount: vendorItem.rate * basketItem.quantity,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await db.update(
      'basket_vendor_items',
      updatedItem.toMap(),
      where: 'uuid = ?',
      whereArgs: [vendorItem.uuid],
    );

    await logChange(
        'basket_vendor_items', vendorItem.uuid, SyncConfig.changeModeUpdate);

    // Update vendor totals
    await _updateBasketVendorTotals(vendor.uuid);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// Helper to get the next numeric ID for manual auto-numbering
  Future<int> _getNextId(String tableName) async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT MAX(id) as max_id FROM $tableName');
    final maxId = result.first['max_id'] as int?;
    return (maxId ?? 0) + 1;
  }
}
