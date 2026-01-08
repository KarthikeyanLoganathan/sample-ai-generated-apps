import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_app/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper dbHelper;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper.instance;
    await dbHelper.database; // Initialize the database
  });

  group('Change Log Condensing Tests', () {
    test('Multiple UPDATEs should keep only the first', () async {
      final db = await dbHelper.database;

      // Clear change_log
      await db.delete('change_log');

      // Insert multiple UPDATE entries for the same record
      await db.insert('change_log', {
        'uuid': 'change-1',
        'table_index': 1,
        'table_key_uuid': 'basket-123',
        'change_mode': 'U',
        'updated_at': '2024-01-01 10:00:00',
      });
      await db.insert('change_log', {
        'uuid': 'change-2',
        'table_index': 1,
        'table_key_uuid': 'basket-123',
        'change_mode': 'U',
        'updated_at': '2024-01-01 10:01:00',
      });
      await db.insert('change_log', {
        'uuid': 'change-3',
        'table_index': 1,
        'table_key_uuid': 'basket-123',
        'change_mode': 'U',
        'updated_at': '2024-01-01 10:02:00',
      });

      // Condense
      final condensed = await dbHelper.condenseChangeLog(null);

      // Should keep only the first UPDATE
      expect(condensed.length, 1);
      expect(condensed[0]['uuid'], 'change-1');
      expect(condensed[0]['change_mode'], 'U');
    });

    test('INSERT followed by DELETE should remove both', () async {
      final db = await dbHelper.database;

      // Clear change_log
      await db.delete('change_log');

      // Insert an INSERT entry
      await db.insert('change_log', {
        'uuid': 'change-1',
        'table_index': 1,
        'table_key_uuid': 'basket-456',
        'change_mode': 'I',
        'updated_at': '2024-01-01 10:00:00',
      });

      // Insert a DELETE entry
      await db.insert('change_log', {
        'uuid': 'change-2',
        'table_index': 1,
        'table_key_uuid': 'basket-456',
        'change_mode': 'D',
        'updated_at': '2024-01-01 10:01:00',
      });

      // Condense
      final condensed = await dbHelper.condenseChangeLog(null);

      // Should remove both entries (INSERT cancelled by DELETE)
      expect(condensed.length, 0);
    });

    test('UPDATE followed by DELETE should remove both', () async {
      final db = await dbHelper.database;

      // Clear change_log
      await db.delete('change_log');

      // Insert an UPDATE entry
      await db.insert('change_log', {
        'uuid': 'change-1',
        'table_index': 1,
        'table_key_uuid': 'basket-789',
        'change_mode': 'U',
        'updated_at': '2024-01-01 10:00:00',
      });

      // Insert a DELETE entry
      await db.insert('change_log', {
        'uuid': 'change-2',
        'table_index': 1,
        'table_key_uuid': 'basket-789',
        'change_mode': 'D',
        'updated_at': '2024-01-01 10:01:00',
      });

      // Condense
      final condensed = await dbHelper.condenseChangeLog(null);

      // Should remove both entries (UPDATE cancelled by DELETE)
      expect(condensed.length, 0);
    });

    test('DELETE only should be kept', () async {
      final db = await dbHelper.database;

      // Clear change_log
      await db.delete('change_log');

      // Insert a standalone DELETE entry
      await db.insert('change_log', {
        'uuid': 'change-1',
        'table_index': 1,
        'table_key_uuid': 'basket-999',
        'change_mode': 'D',
        'updated_at': '2024-01-01 10:00:00',
      });

      // Condense
      final condensed = await dbHelper.condenseChangeLog(null);

      // Should keep the DELETE entry
      expect(condensed.length, 1);
      expect(condensed[0]['uuid'], 'change-1');
      expect(condensed[0]['change_mode'], 'D');
    });

    test('Multiple tables should be processed independently', () async {
      final db = await dbHelper.database;

      // Clear change_log
      await db.delete('change_log');

      // Table 1: Multiple UPDATEs
      await db.insert('change_log', {
        'uuid': 'change-1',
        'table_index': 1,
        'table_key_uuid': 'basket-111',
        'change_mode': 'U',
        'updated_at': '2024-01-01 10:00:00',
      });
      await db.insert('change_log', {
        'uuid': 'change-2',
        'table_index': 1,
        'table_key_uuid': 'basket-111',
        'change_mode': 'U',
        'updated_at': '2024-01-01 10:01:00',
      });

      // Table 2: INSERT then DELETE
      await db.insert('change_log', {
        'uuid': 'change-3',
        'table_index': 2,
        'table_key_uuid': 'item-222',
        'change_mode': 'I',
        'updated_at': '2024-01-01 10:00:00',
      });
      await db.insert('change_log', {
        'uuid': 'change-4',
        'table_index': 2,
        'table_key_uuid': 'item-222',
        'change_mode': 'D',
        'updated_at': '2024-01-01 10:01:00',
      });

      // Condense
      final condensed = await dbHelper.condenseChangeLog(null);

      // Should keep only the first UPDATE from table 1
      // Table 2 entries should cancel out
      expect(condensed.length, 1);
      expect(condensed[0]['table_index'], 1);
      expect(condensed[0]['uuid'], 'change-1');
    });

    test('Sorting by table_index then updated_at', () async {
      final db = await dbHelper.database;

      // Clear change_log
      await db.delete('change_log');

      // Insert entries with different table_index and timestamps
      await db.insert('change_log', {
        'uuid': 'change-1',
        'table_index': 2,
        'table_key_uuid': 'record-2',
        'change_mode': 'U',
        'updated_at': '2024-01-01 10:00:00',
      });
      await db.insert('change_log', {
        'uuid': 'change-2',
        'table_index': 1,
        'table_key_uuid': 'record-1',
        'change_mode': 'U',
        'updated_at': '2024-01-01 10:02:00',
      });
      await db.insert('change_log', {
        'uuid': 'change-3',
        'table_index': 1,
        'table_key_uuid': 'record-3',
        'change_mode': 'U',
        'updated_at': '2024-01-01 10:01:00',
      });

      // Condense
      final condensed = await dbHelper.condenseChangeLog(null);

      // Should sort by table_index first, then by updated_at
      expect(condensed.length, 3);
      expect(condensed[0]['table_index'], 1);
      expect(condensed[0]['updated_at'], '2024-01-01 10:01:00');
      expect(condensed[1]['table_index'], 1);
      expect(condensed[1]['updated_at'], '2024-01-01 10:02:00');
      expect(condensed[2]['table_index'], 2);
      expect(condensed[2]['updated_at'], '2024-01-01 10:00:00');
    });
  });
}
