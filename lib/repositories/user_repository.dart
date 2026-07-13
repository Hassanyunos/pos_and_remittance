import 'package:sqflite/sqflite.dart';
import '../models/user.dart';

class UserRepository {
  final Database _db;

  UserRepository(this._db);

  // ============ Create ============
  Future<User> create(User user) async {
    final id = await _db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }

  // ============ Read ============
  Future<List<User>> getAll() async {
    final List<Map<String, dynamic>> maps = await _db.query('users');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<User?> getById(int id) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getByEmail(String email) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  // Find with conditions
  Future<List<User>> findWhere({
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'users',
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
    return maps.map((map) => User.fromMap(map)).toList();
  }

  // Check if email exists
  Future<bool> exists(String email) async {
    final result = await _db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase().trim()],
    );
    return result.isNotEmpty;
  }

  // ============ Update ============
  Future<User?> update(User user) async {
    if (user.id == null) return null;
    
    final result = await _db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
    
    if (result > 0) {
      return user;
    }
    return null;
  }

  // ============ Delete ============
  Future<bool> delete(int id) async {
    final result = await _db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result > 0;
  }

  // ============ Count ============
  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as count FROM users');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}