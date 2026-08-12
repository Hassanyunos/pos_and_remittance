import 'package:sqflite/sqflite.dart';

import '../models/customer.dart';

class CustomerRepository {
  CustomerRepository(this._database);

  static const _tableName = 'customers';
  final Database _database;

  Future<List<Customer>> getAll() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NULL',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return maps.map(Customer.fromMap).toList();
  }

  Future<Customer?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : Customer.fromMap(maps.first);
  }

  Future<List<Customer>> getArchived() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NOT NULL',
      orderBy: 'archived_at DESC, name COLLATE NOCASE ASC',
    );
    return maps.map(Customer.fromMap).toList();
  }

  Future<Customer> create(Customer customer) async {
    final id = await _database.insert(_tableName, customer.toMap()..remove('id'));
    return customer.copyWith(id: id);
  }

  Future<Customer> update(Customer customer) async {
    await _database.update(
      _tableName,
      customer.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    return customer;
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
