import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../features/auth/data/repositories/user_repository.dart';
import '../../features/auth/application/password_hasher.dart';
import '../../features/fund_management/data/repositories/fund_repository.dart';
import 'database_seeder.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static const _databaseName = 'pos_remittance.db';
  static const _databaseVersion = 4;
  Database? _database;
  late final UserRepository userRepository;
  late final FundRepository fundRepository;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final databasePath = kIsWeb
        ? _databaseName
        : path.join(
            (await getApplicationDocumentsDirectory()).path,
            _databaseName,
          );
    _database = await openDatabase(databasePath, version: _databaseVersion,
        onCreate: _createTables, onUpgrade: _upgradeDatabase);
    userRepository = UserRepository(_database!);
    fundRepository = FundRepository(_database!);
    await DatabaseSeeder(userRepository).seedOwnerUser();
    await fundRepository.seedDefaultFunds();
    return _database!;
  }

  Future<void> _createTables(Database database, int version) async {
    await database.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'staff',
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ''');
    await database.execute('''
      CREATE TABLE funds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        current_balance REAL NOT NULL DEFAULT 0,
        fund_type TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDatabase(Database database, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await database.execute("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'staff'");
      await database.execute("UPDATE users SET role = 'admin' WHERE email = 'admin@example.com'");
    }
    if (oldVersion < 3) {
      await database.update(
        'users',
        {'password_hash': PasswordHasher.hash(DatabaseSeeder.ownerPassword)},
        where: 'email = ?',
        whereArgs: [DatabaseSeeder.ownerEmail],
      );
    }
    if (oldVersion < 4) {
      await database.execute("UPDATE users SET role = 'owner' WHERE role = 'admin'");
      await database.execute('''
        CREATE TABLE funds (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          current_balance REAL NOT NULL DEFAULT 0,
          fund_type TEXT NOT NULL
        )
      ''');
    }
  }
}
