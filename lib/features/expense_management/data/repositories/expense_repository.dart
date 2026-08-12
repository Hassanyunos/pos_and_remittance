import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this._database);

  static const _tableName = 'expenses';
  final Database _database;

  Future<List<Expense>> getAll() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NULL',
      orderBy: 'expense_date DESC, id DESC',
    );
    return maps.map(Expense.fromMap).toList();
  }

  Future<Expense?> getById(int id) async {
    final maps = await _database.query(
      _tableName,
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isEmpty ? null : Expense.fromMap(maps.first);
  }

  Future<List<Expense>> getArchived() async {
    final maps = await _database.query(
      _tableName,
      where: 'archived_at IS NOT NULL',
      orderBy: 'archived_at DESC, id DESC',
    );
    return maps.map(Expense.fromMap).toList();
  }

  Future<Expense> create(Expense expense) async {
    final id = await _database.insert(_tableName, expense.toMap()..remove('id'));
    return expense.copyWith(id: id);
  }

  Future<void> update(Expense expense) async {
    await _database.update(
      _tableName,
      expense.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
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
