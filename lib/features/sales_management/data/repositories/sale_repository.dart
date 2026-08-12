import 'package:sqflite/sqflite.dart';

import '../models/sale.dart';

class SaleRepository {
  SaleRepository(this._database);

  static const _tableName = 'sales';
  final Database _database;

  Future<List<Sale>> getAll() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NULL',
      orderBy: 'sold_at DESC',
    );
    return maps.map(Sale.fromMap).toList();
  }

  Future<Sale?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : Sale.fromMap(maps.first);
  }

  Future<Sale> create(Sale sale) async {
    final id = await _database.insert(_tableName, sale.toMap()..remove('id'));
    return sale.copyWith(id: id);
  }

  Future<Sale> update(Sale sale) async {
    await _database.update(_tableName, sale.toMap()..remove('id'), where: 'id = ?', whereArgs: [sale.id]);
    return sale;
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
