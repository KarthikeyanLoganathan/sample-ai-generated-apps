/// Sync configuration for delta sync mechanism
class SyncConfig {
  /// Table indices for change log tracking
  static const Map<String, int> tableIndices = {
    'manufacturers': 1,
    'vendors': 2,
    'materials': 3,
    'manufacturer_materials': 4,
    'vendor_price_lists': 5,
    'purchase_orders': 6,
    'purchase_order_items': 7,
    'purchase_order_payments': 8,
    'basket_headers': 9,
    'basket_items': 10,
    'basket_vendors': 11,
    'basket_vendor_items': 12,
  };

  static const Map<int, String> tableNamesByIndices = {
    1: 'manufacturers',
    2: 'vendors',
    3: 'materials',
    4: 'manufacturer_materials',
    5: 'vendor_price_lists',
    6: 'purchase_orders',
    7: 'purchase_order_items',
    8: 'purchase_order_payments',
    9: 'basket_headers',
    10: 'basket_items',
    11: 'basket_vendors',
    12: 'basket_vendor_items',
  };

  /// Change modes
  static const String changeModeInsert = 'I';
  static const String changeModeUpdate = 'U';
  static const String changeModeDelete = 'D';

  /// Get table index by name
  static int? getTableIndex(String tableName) {
    return tableIndices[tableName];
  }

  /// Get table name by index
  static String? getTableName(int tableIndex) {
    return tableNamesByIndices[tableIndex];
  }

  /// Get all sync table names in order
  static List<String> getSyncTables() {
    final entries = tableIndices.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries.map((e) => e.key).toList();
  }
}
