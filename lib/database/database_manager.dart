import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user.dart';
import '../repositories/user_repository.dart';

class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  static Database? _database;

  // Repositories
  late final UserRepository users;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath;
    
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      dbPath = 'pos_remittance.db';
      print('🌐 Web mode: Using database at $dbPath');
    } else {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      dbPath = path.join(documentsDirectory.path, 'pos_remittance.db');
      print('📱 Mobile mode: Database at $dbPath');
    }

    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Initialize repositories
    users = UserRepository(db);

    print('✅ Database and repositories initialized successfully!');
    
    // Ensure default users exist
    await _ensureDefaultUsers();

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    print('🔄 Creating database tables...');
    
    // Create Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    print('✅ Database tables created successfully!');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('⬆️ Upgrading database from version $oldVersion to $newVersion');
    // Add migration logic here when needed
  }

  Future<void> _ensureDefaultUsers() async {
    try {
      final allUsers = await users.getAll();
      
      if (allUsers.isEmpty) {
        // Create default admin user
        await users.create(User(
          name: 'Admin User',
          email: 'admin@example.com',
          passwordHash: 'admin123',
        ));
        
        // Create test user
        await users.create(User(
          name: 'Test User',
          email: 'test@example.com',
          passwordHash: 'password123',
        ));
        
        print('✅ Default users created:');
        print('   - admin@example.com / admin123');
        print('   - test@example.com / password123');
      } else {
        print('📊 Existing users found: ${allUsers.length}');
      }
    } catch (e) {
      print('⚠️ Error ensuring default users: $e');
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}