import 'package:sqflite/sqflite.dart';

import '../models/laundry_service_item.dart';

class LaundryServiceRepository {
  LaundryServiceRepository(this._database);

  static const _tableName = 'laundry_service_items';
  final Database _database;

  Future<List<LaundryServiceItem>> getAll() async {
    final maps = await _database.query(
      _tableName,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return maps.map(LaundryServiceItem.fromMap).toList();
  }

  Future<LaundryServiceItem?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : LaundryServiceItem.fromMap(maps.first);
  }

  Future<LaundryServiceItem> create(LaundryServiceItem item) async {
    final id = await _database.insert(_tableName, item.toMap()..remove('id'));
    return item.copyWith(id: id);
  }

  Future<LaundryServiceItem> update(LaundryServiceItem item) async {
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
