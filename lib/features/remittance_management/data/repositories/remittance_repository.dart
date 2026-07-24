import 'package:sqflite/sqflite.dart';

import '../models/remittance.dart';

class RemittanceRepository {
  RemittanceRepository(this._database);

  static const _tableName = 'remittances';
  final Database _database;

  Future<List<Remittance>> getAll() async {
    final maps = await _database.query(
      _tableName,
      orderBy: 'processed_at DESC, id DESC',
    );
    return maps.map(Remittance.fromMap).toList();
  }

  Future<Remittance?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : Remittance.fromMap(maps.first);
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
    await _database.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
