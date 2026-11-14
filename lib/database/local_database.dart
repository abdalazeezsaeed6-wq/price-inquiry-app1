import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/inventory_item.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    final dbPath = p.join(await getDatabasesPath(), 'price_inquiry.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            item_code TEXT NOT NULL UNIQUE,
            barcode TEXT,
            purchase_price REAL NOT NULL DEFAULT 0,
            selling_price REAL NOT NULL DEFAULT 0,
            unit TEXT NOT NULL DEFAULT 'حبة',
            quantity REAL NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_items_name ON items(name)');
        await db.execute('CREATE INDEX idx_items_code ON items(item_code)');
        await db.execute("CREATE UNIQUE INDEX idx_items_barcode ON items(barcode) WHERE barcode IS NOT NULL AND barcode <> ''");
        await db.execute('''
          CREATE TABLE settings (
            setting_key TEXT PRIMARY KEY,
            setting_value TEXT NOT NULL
          )
        ''');
        await db.insert('settings', {
          'setting_key': 'currency_symbol',
          'setting_value': 'ر.ي',
        });
      },
    );
    return _database!;
  }

  Future<List<InventoryItem>> getAllItems() async {
    final db = await database;
    final rows = await db.query('items', orderBy: 'name COLLATE NOCASE');
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<List<InventoryItem>> searchItems(String query) async {
    final db = await database;
    final q = query.trim();
    final rows = q.isEmpty
        ? await db.query('items', orderBy: 'name COLLATE NOCASE', limit: 300)
        : await db.query(
            'items',
            where: 'name LIKE ? OR item_code LIKE ? OR barcode LIKE ?',
            whereArgs: ['%$q%', '%$q%', '%$q%'],
            orderBy: 'name COLLATE NOCASE',
            limit: 300,
          );
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<int> saveItem(InventoryItem item) async {
    final db = await database;
    if (item.id == null) {
      return db.insert('items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
    }
    return db.update(
      'items',
      item.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [item.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setBarcode(int id, String barcode) async {
    final db = await database;
    await db.update(
      'items',
      {'barcode': barcode},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> importItems(List<InventoryItem> items, {required bool replaceAll}) async {
    final db = await database;
    var saved = 0;
    await db.transaction((txn) async {
      if (replaceAll) await txn.delete('items');
      for (final item in items) {
        try {
          if (item.barcode.trim().isNotEmpty) {
            final barcodeOwner = await txn.query(
              'items',
              columns: ['id'],
              where: 'barcode = ? AND item_code <> ?',
              whereArgs: [item.barcode.trim(), item.itemCode.trim()],
              limit: 1,
            );
            if (barcodeOwner.isNotEmpty) continue;
          }

          final sameCode = await txn.query(
            'items',
            columns: ['id'],
            where: 'item_code = ?',
            whereArgs: [item.itemCode.trim()],
            limit: 1,
          );
          if (sameCode.isNotEmpty) {
            await txn.update(
              'items',
              item.toMap()..remove('id'),
              where: 'id = ?',
              whereArgs: [sameCode.first['id']],
            );
          } else {
            await txn.insert('items', item.toMap());
          }
          saved++;
        } on DatabaseException {
          // تخطّي الصف المكرر أو غير الصالح دون إلغاء بقية عملية الاستيراد.
        }
      }
    });
    return saved;
  }

  Future<String> getCurrencySymbol() async {
    final db = await database;
    final rows = await db.query(
      'settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: ['currency_symbol'],
      limit: 1,
    );
    return rows.isEmpty ? 'ر.ي' : rows.first['setting_value'] as String;
  }

  Future<void> setCurrencySymbol(String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'setting_key': 'currency_symbol', 'setting_value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Uint8List> createBackup() async {
    final db = await database;
    await db.execute('PRAGMA wal_checkpoint(FULL)');
    final dbPath = p.join(await getDatabasesPath(), 'price_inquiry.db');
    await db.close();
    _database = null;
    return File(dbPath).readAsBytes();
  }

  Future<void> restoreBackup(Uint8List bytes) async {
    if (bytes.length < 16 ||
        String.fromCharCodes(bytes.take(15)) != 'SQLite format 3') {
      throw const FormatException('الملف المحدد ليس نسخة SQLite صحيحة.');
    }
    final dbPath = p.join(await getDatabasesPath(), 'price_inquiry.db');
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$dbPath$suffix');
      if (await file.exists()) await file.delete();
    }
    await File(dbPath).writeAsBytes(bytes, flush: true);
    await database;
  }
}
