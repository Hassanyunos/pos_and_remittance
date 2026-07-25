import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../features/auth/data/repositories/user_repository.dart';
import '../../features/auth/application/password_hasher.dart';
import '../../features/customer_management/data/repositories/customer_repository.dart';
import '../../features/expense_management/data/repositories/expense_repository.dart';
import '../../features/fund_management/data/repositories/fund_repository.dart';
import '../../features/grocery_stock_management/data/repositories/grocery_stock_category_repository.dart';
import '../../features/grocery_stock_management/data/repositories/grocery_stock_repository.dart';
import '../../features/remittance_management/data/repositories/remittance_repository.dart';
import '../../features/sales_management/data/repositories/sale_item_repository.dart';
import '../../features/sales_management/data/repositories/sale_repository.dart';
import 'database_seeder.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static const _databaseName = 'pos_remittance.db';
  static const _databaseVersion = 11;
  Database? _database;
  UserRepository? userRepository;
  FundRepository? fundRepository;
  CustomerRepository? customerRepository;
  RemittanceRepository? remittanceRepository;
  ExpenseRepository? expenseRepository;
  GroceryStockRepository? groceryStockRepository;
  GroceryStockCategoryRepository? groceryStockCategoryRepository;
  SaleRepository? saleRepository;
  SaleItemRepository? saleItemRepository;

  Future<Database> get database async {
    if (_database != null) {
      _initializeRepositories(_database!);
      return _database!;
    }
    final databasePath = kIsWeb
        ? _databaseName
        : path.join(
            (await getApplicationDocumentsDirectory()).path,
            _databaseName,
          );
    _database = await openDatabase(databasePath, version: _databaseVersion,
        onCreate: _createTables, onUpgrade: _upgradeDatabase);
    _initializeRepositories(_database!);
    await DatabaseSeeder(userRepository!).seedOwnerUser();
    await fundRepository!.seedDefaultFunds();
    return _database!;
  }

  void _initializeRepositories(Database database) {
    userRepository = UserRepository(database);
    fundRepository = FundRepository(database);
    customerRepository = CustomerRepository(database);
    remittanceRepository = RemittanceRepository(database);
    expenseRepository = ExpenseRepository(database);
    groceryStockRepository = GroceryStockRepository(database);
    groceryStockCategoryRepository = GroceryStockCategoryRepository(database);
    saleRepository = SaleRepository(database);
    saleItemRepository = SaleItemRepository(database);
  }

  Future<double> getDashboardTarget(String name) async {
    final database = await this.database;
    final rows = await database.query('dashboard_targets', where: 'name = ?', whereArgs: [name], limit: 1);
    if (rows.isEmpty) {
      return 0;
    }
    return (rows.first['daily_target'] as num).toDouble();
  }

  Future<void> saveDashboardTarget(String name, double dailyTarget) async {
    final database = await this.database;
    final existing = await database.query('dashboard_targets', where: 'name = ?', whereArgs: [name], limit: 1);
    if (existing.isEmpty) {
      await database.insert('dashboard_targets', {'name': name, 'daily_target': dailyTarget});
    } else {
      await database.update('dashboard_targets', {'daily_target': dailyTarget}, where: 'name = ?', whereArgs: [name]);
    }
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
    await database.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        contact_number TEXT,
        id_picture_path TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE remittances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fund_id INTEGER NOT NULL,
        remittance_type TEXT NOT NULL,
        reference_number TEXT NOT NULL,
        amount REAL NOT NULL,
        charge REAL NOT NULL,
        processed_at TEXT,
        customer_id INTEGER,
        customer_name TEXT,
        customer_id_picture_path TEXT,
        processed_by TEXT,
        edited_by TEXT,
        remittance_status TEXT NOT NULL,
        notes TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fund_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        expense_date TEXT NOT NULL,
        person_name TEXT NOT NULL,
        purpose TEXT NOT NULL,
        details TEXT,
        notes TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE grocery_stock_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await database.execute('''
      CREATE TABLE grocery_stock_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name TEXT NOT NULL,
        stock_number TEXT NOT NULL,
        quantity_in_stock INTEGER NOT NULL DEFAULT 0,
        capital_price REAL NOT NULL DEFAULT 0,
        retail_price REAL NOT NULL DEFAULT 0,
        minimum_alert_quantity INTEGER NOT NULL DEFAULT 0,
        picture_path TEXT,
        category TEXT NOT NULL DEFAULT 'General',
        expiration_date TEXT,
        notes TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        customer_name TEXT,
        total_price REAL NOT NULL DEFAULT 0,
        amount_payable REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        change_amount REAL NOT NULL DEFAULT 0,
        sold_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        item_barcode TEXT NOT NULL,
        quantity_bought INTEGER NOT NULL DEFAULT 1,
        retail_price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE dashboard_targets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        daily_target REAL NOT NULL DEFAULT 0
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
    if (oldVersion < 5) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          address TEXT,
          contact_number TEXT,
          id_picture_path TEXT
        )
      ''');
    }
    if (oldVersion < 6) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS remittances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fund_id INTEGER NOT NULL,
          remittance_type TEXT NOT NULL,
          reference_number TEXT NOT NULL,
          amount REAL NOT NULL,
          charge REAL NOT NULL,
          processed_at TEXT,
          customer_id INTEGER,
          customer_name TEXT,
          customer_id_picture_path TEXT,
          processed_by TEXT,
          edited_by TEXT,
          remittance_status TEXT NOT NULL,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fund_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          expense_date TEXT NOT NULL,
          person_name TEXT NOT NULL,
          purpose TEXT NOT NULL,
          details TEXT,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 8) {
      await database.execute('ALTER TABLE expenses ADD COLUMN fund_id INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 9) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS grocery_stock_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )
      ''');
      await database.execute('''
        CREATE TABLE IF NOT EXISTS grocery_stock_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_name TEXT NOT NULL,
          stock_number TEXT NOT NULL,
          quantity_in_stock INTEGER NOT NULL DEFAULT 0,
          capital_price REAL NOT NULL DEFAULT 0,
          retail_price REAL NOT NULL DEFAULT 0,
          minimum_alert_quantity INTEGER NOT NULL DEFAULT 0,
          picture_path TEXT,
          category TEXT NOT NULL DEFAULT 'General',
          expiration_date TEXT,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 10) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS sales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          receipt_number TEXT NOT NULL UNIQUE,
          customer_id INTEGER,
          customer_name TEXT,
          total_price REAL NOT NULL DEFAULT 0,
          amount_payable REAL NOT NULL DEFAULT 0,
          amount_paid REAL NOT NULL DEFAULT 0,
          change_amount REAL NOT NULL DEFAULT 0,
          sold_at TEXT NOT NULL
        )
      ''');
      await database.execute('''
        CREATE TABLE IF NOT EXISTS sale_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          item_name TEXT NOT NULL,
          item_barcode TEXT NOT NULL,
          quantity_bought INTEGER NOT NULL DEFAULT 1,
          retail_price REAL NOT NULL DEFAULT 0,
          FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 11) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS dashboard_targets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          daily_target REAL NOT NULL DEFAULT 0
        )
      ''');
    }
  }
}
