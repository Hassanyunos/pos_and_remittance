import 'package:sqflite/sqflite.dart';

import '../models/laundry_service_item.dart';

class LaundryServiceRepository {
  LaundryServiceRepository(this._database);

  static const _tableName = 'laundry_service_items';
  final Database _database;

  Future<List<LaundryServiceItem>> getAll() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NULL',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return maps.map(LaundryServiceItem.fromMap).toList();
  }

  Future<LaundryServiceItem?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : LaundryServiceItem.fromMap(maps.first);
  }

  Future<List<LaundryServiceItem>> getArchived() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NOT NULL',
      orderBy: 'archived_at DESC, name COLLATE NOCASE ASC',
    );
    return maps.map(LaundryServiceItem.fromMap).toList();
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
