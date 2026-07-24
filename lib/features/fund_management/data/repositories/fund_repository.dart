import 'package:sqflite/sqflite.dart';

import '../models/fund.dart';

class FundRepository {
  FundRepository(this._database);

  static const _tableName = 'funds';
  static const groceryCashName = 'GroceryCash';
  static const remittanceECashName = 'Remittance-Cash';
  final Database _database;

  Future<void> seedDefaultFunds() async {
    await _seedIfMissing(groceryCashName, FundType.cash);
    await _seedIfMissing(remittanceECashName, FundType.cash);
  }

  Future<void> _seedIfMissing(String name, FundType type) async {
    final existing = await _database.query(
      _tableName,
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (existing.isEmpty) {
      await create(Fund(name: name, currentBalance: 0, fundType: type));
    }
  }

  Future<List<Fund>> getAll() async {
    final maps = await _database.query(_tableName, orderBy: 'id ASC');
    return maps.map(Fund.fromMap).toList();
  }

  Future<Fund?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : Fund.fromMap(maps.first);
  }

  Future<Fund> create(Fund fund) async {
    final id = await _database.insert(_tableName, fund.toMap()..remove('id'));
    return fund.copyWith(id: id);
  }

  Future<void> update(Fund fund) async {
    await _database.update(
      _tableName,
      fund.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [fund.id],
    );
  }

  Future<void> delete(int id) async {
    await _database.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
