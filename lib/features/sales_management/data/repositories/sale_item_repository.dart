import 'package:sqflite/sqflite.dart';

import '../models/sale_item.dart';

class SaleItemRepository {
  SaleItemRepository(this._database);

  static const _tableName = 'sale_items';
  final Database _database;

  Future<List<SaleItem>> getAll() async {
    final maps = await _database.query(_tableName, orderBy: 'id ASC');
    return maps.map(SaleItem.fromMap).toList();
  }

  Future<List<SaleItem>> getBySaleId(int saleId) async {
    final maps = await _database.query(_tableName, where: 'sale_id = ?', whereArgs: [saleId], orderBy: 'id ASC');
    return maps.map(SaleItem.fromMap).toList();
  }

  Future<SaleItem> create(SaleItem item) async {
    final id = await _database.insert(_tableName, item.toMap()..remove('id'));
    return item.copyWith(id: id);
  }

  Future<void> delete(int id) async {
    await _database.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
