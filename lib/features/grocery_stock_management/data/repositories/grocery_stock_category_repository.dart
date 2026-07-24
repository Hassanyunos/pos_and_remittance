import 'package:sqflite/sqflite.dart';

import '../models/grocery_stock_category.dart';

class GroceryStockCategoryRepository {
  GroceryStockCategoryRepository(this._database);

  static const _tableName = 'grocery_stock_categories';
  final Database _database;

  Future<List<GroceryStockCategory>> getAll() async {
    final maps = await _database.query(_tableName, orderBy: 'name COLLATE NOCASE ASC');
    return maps.map(GroceryStockCategory.fromMap).toList();
  }

  Future<GroceryStockCategory> create(GroceryStockCategory category) async {
    final id = await _database.insert(_tableName, category.toMap()..remove('id'));
    return category.copyWith(id: id);
  }

  Future<void> delete(int id) async {
    await _database.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
