import 'package:sqflite/sqflite.dart';

import '../models/remittance.dart';

class RemittanceRepository {
  RemittanceRepository(this._database);

  static const _tableName = 'remittances';
  final Database _database;

  Future<List<Remittance>> getAll() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NULL',
      orderBy: 'processed_at DESC, id DESC',
    );
    return maps.map(Remittance.fromMap).toList();
  }

  Future<Remittance?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : Remittance.fromMap(maps.first);
  }

  Future<List<Remittance>> getArchived() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NOT NULL',
      orderBy: 'archived_at DESC, id DESC',
    );
    return maps.map(Remittance.fromMap).toList();
  }

  Future<Remittance> create(Remittance remittance) async {
    final id = await _database.insert(_tableName, remittance.toMap()..remove('id'));
    return remittance.copyWith(id: id);
  }

  Future<Remittance> update(Remittance remittance) async {
    await _database.update(
      _tableName,
      remittance.toMap(),
      where: 'id = ?',
      whereArgs: [remittance.id],
    );
    return remittance;
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
