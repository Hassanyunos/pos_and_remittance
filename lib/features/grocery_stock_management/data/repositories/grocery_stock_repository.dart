import 'package:sqflite/sqflite.dart';

import '../models/grocery_stock_item.dart';

class GroceryStockRepository {
  GroceryStockRepository(this._database);

  static const _tableName = 'grocery_stock_items';
  final Database _database;

  Future<List<GroceryStockItem>> getAll() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NULL',
      orderBy: 'item_name COLLATE NOCASE ASC',
    );
    return maps.map(GroceryStockItem.fromMap).toList();
  }

  Future<GroceryStockItem?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : GroceryStockItem.fromMap(maps.first);
  }

  Future<List<GroceryStockItem>> getArchived() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NOT NULL',
      orderBy: 'archived_at DESC, item_name COLLATE NOCASE ASC',
    );
    return maps.map(GroceryStockItem.fromMap).toList();
  }

  Future<GroceryStockItem> create(GroceryStockItem item) async {
    final id = await _database.insert(_tableName, item.toMap()..remove('id'));
    return item.copyWith(id: id);
  }

  Future<GroceryStockItem> update(GroceryStockItem item) async {
    await _database.update(
      _tableName,
      item.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return item;
  }

  Future<void> delete(int id) async {
    await _database.update(
      _tableName,
      {'archived_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<void> restore(int id) async {
    await _database.update(
      _tableName,
      {'archived_at': null},
      where: 'id = ? AND archived_at IS NOT NULL',
      whereArgs: [id],
    );
  }
}
