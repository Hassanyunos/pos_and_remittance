import 'package:sqflite/sqflite.dart';

import '../models/grocery_stock_item.dart';

class GroceryStockRepository {
  GroceryStockRepository(this._database);

  static const _tableName = 'grocery_stock_items';
  final Database _database;

  Future<List<GroceryStockItem>> getAll() async {
    final maps = await _database.query(_tableName, orderBy: 'item_name COLLATE NOCASE ASC');
    return maps.map(GroceryStockItem.fromMap).toList();
  }

  Future<GroceryStockItem?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : GroceryStockItem.fromMap(maps.first);
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
    await _database.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
