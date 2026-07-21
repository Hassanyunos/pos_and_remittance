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
