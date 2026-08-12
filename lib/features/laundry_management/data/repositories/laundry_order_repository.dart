import 'package:sqflite/sqflite.dart';

import '../models/laundry_order.dart';

class LaundryOrderRepository {
  LaundryOrderRepository(this._database);

  static const _tableName = 'laundry_orders';
  final Database _database;

  Future<List<LaundryOrder>> getAll() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NULL',
      orderBy: 'updated_at DESC, id DESC',
    );
    return maps.map(LaundryOrder.fromMap).toList();
  }

  Future<LaundryOrder?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : LaundryOrder.fromMap(maps.first);
  }

  Future<List<LaundryOrder>> getArchived() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NOT NULL',
      orderBy: 'archived_at DESC, id DESC',
    );
    return maps.map(LaundryOrder.fromMap).toList();
  }

  Future<LaundryOrder> create(LaundryOrder order) async {
    final id = await _database.insert(_tableName, order.toMap()..remove('id'));
    return order.copyWith(id: id);
  }

  Future<LaundryOrder> update(LaundryOrder order) async {
    await _database.update(
      _tableName,
      order.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [order.id],
    );
    return order;
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
