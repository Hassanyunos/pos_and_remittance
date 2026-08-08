import 'package:sqflite/sqflite.dart';

import '../models/laundry_stock_item.dart';

class LaundryStockRepository {
  LaundryStockRepository(this._database);

  static const _tableName = 'laundry_stock_items';
  final Database _database;

  Future<List<LaundryStockItem>> getAll() async {
    final maps = await _database.query(_tableName,
        orderBy: 'item_name COLLATE NOCASE ASC');
    return maps.map(LaundryStockItem.fromMap).toList();
  }

  Future<LaundryStockItem?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : LaundryStockItem.fromMap(maps.first);
  }

  Future<LaundryStockItem> create(LaundryStockItem item) async {
    final id = await _database.insert(_tableName, item.toMap()..remove('id'));
    return item.copyWith(id: id);
  }

  Future<LaundryStockItem> update(LaundryStockItem item) async {
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
