import 'package:sqflite/sqflite.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository(this._database);

  static const _tableName = 'users';
  final Database _database;

  Future<AppUser> create(AppUser user) async {
    final userId = await _database.insert(_tableName, user.toMap());
    return user.copyWith(id: userId);
  }

  Future<AppUser?> getByEmail(String email) async {
    final users = await _database.query(_tableName,
        where: 'email = ?', whereArgs: [email.trim().toLowerCase()], limit: 1);
    return users.isEmpty ? null : AppUser.fromMap(users.first);
  }

  Future<AppUser?> getByAccountName(String accountName) async {
    final normalized = accountName.trim().toLowerCase();
    final users = await _database.query(
      _tableName,
      where: 'account_name = ? OR email = ?',
      whereArgs: [normalized, normalized],
      limit: 1,
    );
    return users.isEmpty ? null : AppUser.fromMap(users.first);
  }

  Future<List<AppUser>> getAll() async {
    final users =
        await _database.query(_tableName, orderBy: 'created_at DESC, id DESC');
    return users.map(AppUser.fromMap).toList();
  }

  Future<void> updateActiveStatus(
      {required int userId, required bool isActive}) {
    return _database.update(
      _tableName,
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updatePassword({
    required int userId,
    required String passwordHash,
  }) {
    return _database.update(
      _tableName,
      {'password_hash': passwordHash},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
