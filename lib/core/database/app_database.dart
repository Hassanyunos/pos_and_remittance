import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../features/auth/data/repositories/user_repository.dart';
import '../../features/auth/application/password_hasher.dart';
import '../../features/customer_management/data/repositories/customer_balance_payment_repository.dart';
import '../../features/customer_management/data/repositories/customer_repository.dart';
import '../../features/expense_management/data/repositories/expense_repository.dart';
import '../../features/fund_management/data/repositories/fund_repository.dart';
import '../../features/grocery_stock_management/data/repositories/grocery_stock_category_repository.dart';
import '../../features/grocery_stock_management/data/repositories/grocery_stock_repository.dart';
import '../../features/laundry_management/data/repositories/laundry_order_repository.dart';
import '../../features/laundry_stock_management/data/repositories/laundry_service_repository.dart';
import '../../features/laundry_stock_management/data/repositories/laundry_stock_repository.dart';
import '../../features/remittance_management/data/repositories/remittance_repository.dart';
import '../../features/sales_management/data/repositories/sale_item_repository.dart';
import '../../features/sales_management/data/repositories/sale_repository.dart';
import 'database_seeder.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static const _databaseName = 'pos_remittance.db';
  static const _databaseVersion = 20;
  Database? _database;
  UserRepository? userRepository;
  FundRepository? fundRepository;
  CustomerRepository? customerRepository;
  CustomerBalancePaymentRepository? customerBalancePaymentRepository;
  RemittanceRepository? remittanceRepository;
  ExpenseRepository? expenseRepository;
  GroceryStockRepository? groceryStockRepository;
  GroceryStockCategoryRepository? groceryStockCategoryRepository;
  LaundryStockRepository? laundryStockRepository;
  LaundryServiceRepository? laundryServiceRepository;
  LaundryOrderRepository? laundryOrderRepository;
  SaleRepository? saleRepository;
  SaleItemRepository? saleItemRepository;

  Future<Database> get database async {
    if (_database != null) {
      await _ensureSchema(_database!);
      _initializeRepositories(_database!);
      return _database!;
    }
    final databasePath = kIsWeb
        ? _databaseName
        : path.join(
            (await getApplicationDocumentsDirectory()).path,
            _databaseName,
          );
    _database = await openDatabase(databasePath,
        version: _databaseVersion,
        onCreate: _createTables,
        onUpgrade: _upgradeDatabase);
    await _ensureSchema(_database!);
    _initializeRepositories(_database!);
    await DatabaseSeeder(userRepository!, fundRepository!).seedAll();
    return _database!;
  }

  Future<void> _ensureSchema(Database database) async {
    await _ensureColumn(
        database, 'users', 'account_name', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(
        database, 'users', 'is_active', 'INTEGER NOT NULL DEFAULT 1');
    await database.execute(
        "UPDATE users SET account_name = LOWER(email) WHERE (account_name IS NULL OR account_name = '') AND email IS NOT NULL");
    await database.execute(
        "UPDATE users SET account_name = '${DatabaseSeeder.ownerAccountName}' WHERE LOWER(email) = 'admin@example.com'");
    await _ensureColumn(
        database, 'sales', 'outstanding_balance', 'REAL NOT NULL DEFAULT 0');
    await _ensureColumn(
        database, 'sales', 'is_credit_sale', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(
        database, 'customers', 'status', "TEXT NOT NULL DEFAULT 'standard'");
    await _ensureColumn(
        database, 'customers', 'current_balance', 'REAL NOT NULL DEFAULT 0');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS customer_balance_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        sale_id INTEGER,
        laundry_order_id INTEGER,
        amount REAL NOT NULL DEFAULT 0,
        payment_type TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'grocery',
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE SET NULL,
        FOREIGN KEY (laundry_order_id) REFERENCES laundry_orders(id) ON DELETE SET NULL
      )
    ''');
    await _ensureColumn(
        database, 'customer_balance_payments', 'laundry_order_id', 'INTEGER');
    await _ensureColumn(database, 'customer_balance_payments', 'source',
        "TEXT NOT NULL DEFAULT 'grocery'");
    await _ensureColumn(database, 'customers', 'archived_at', 'TEXT');
    await _ensureColumn(database, 'funds', 'archived_at', 'TEXT');
    await _ensureColumn(database, 'expenses', 'archived_at', 'TEXT');
    await _ensureColumn(database, 'remittances', 'archived_at', 'TEXT');
    await _ensureColumn(database, 'grocery_stock_items', 'archived_at', 'TEXT');
    await _ensureColumn(database, 'laundry_stock_items', 'archived_at', 'TEXT');
    await _ensureColumn(database, 'laundry_service_items', 'archived_at', 'TEXT');
    await _ensureColumn(database, 'laundry_orders', 'archived_at', 'TEXT');
    await _ensureColumn(database, 'sales', 'archived_at', 'TEXT');
    await _ensureColumn(database, 'laundry_service_items', 'max_weight_kg',
      'REAL NOT NULL DEFAULT 1');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS laundry_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference_number TEXT NOT NULL,
        customer_id INTEGER,
        is_walk_in INTEGER NOT NULL DEFAULT 1,
        customer_name TEXT NOT NULL,
        customer_contact TEXT,
        weight_kg REAL NOT NULL DEFAULT 0,
        clothes_count INTEGER NOT NULL DEFAULT 0,
        laundry_base_amount REAL NOT NULL DEFAULT 0,
        add_ons TEXT,
        add_on_item_ids TEXT,
        add_on_total REAL NOT NULL DEFAULT 0,
        amount_payable REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        change_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        item_image_path TEXT,
        pickup_proof_image_path TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS laundry_service_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        add_on_item_ids TEXT,
        notes TEXT
      )
    ''');
    await _ensureColumn(database, 'laundry_orders', 'customer_id', 'INTEGER');
    await _ensureColumn(
        database, 'laundry_orders', 'is_walk_in', 'INTEGER NOT NULL DEFAULT 1');
    await _ensureColumn(database, 'laundry_orders', 'laundry_base_amount',
        'REAL NOT NULL DEFAULT 0');
    await _ensureColumn(database, 'laundry_orders', 'add_on_item_ids', 'TEXT');
    await _ensureColumn(
        database, 'laundry_orders', 'add_on_total', 'REAL NOT NULL DEFAULT 0');
    await _ensureColumn(database, 'laundry_orders', 'item_image_path', 'TEXT');
    await _ensureColumn(
        database, 'laundry_orders', 'pickup_proof_image_path', 'TEXT');
    await _ensureColumn(database, 'laundry_orders', 'service_id', 'INTEGER');
    await _ensureColumn(database, 'laundry_orders', 'service_name', 'TEXT');
    await _ensureColumn(database, 'laundry_orders', 'service_add_ons', 'TEXT');
    await _ensureColumn(
        database, 'laundry_orders', 'service_add_on_item_ids', 'TEXT');
    await _ensureColumn(database, 'laundry_orders', 'paid_add_ons', 'TEXT');
    await _ensureColumn(
        database, 'laundry_orders', 'paid_add_on_item_ids', 'TEXT');
    await database.execute('''
      UPDATE laundry_orders
      SET laundry_base_amount = amount_payable
      WHERE laundry_base_amount = 0 AND amount_payable > 0
    ''');
  }

  Future<void> _ensureColumn(Database database, String tableName,
      String columnName, String columnDefinition) async {
    final tableInfo = await database.rawQuery('PRAGMA table_info($tableName)');
    final columnExists = tableInfo.any((row) => row['name'] == columnName);
    if (!columnExists) {
      try {
        await database.execute(
            'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition');
      } catch (error) {
        // Guard against duplicate migration attempts from concurrent startup.
        if (error is DatabaseException) {
          final message = error.toString().toLowerCase();
          if (message.contains('duplicate column name')) {
            return;
          }
        }
        rethrow;
      }
    }
  }
  void _initializeRepositories(Database database) {
    userRepository = UserRepository(database);
    fundRepository = FundRepository(database);
    customerRepository = CustomerRepository(database);
    customerBalancePaymentRepository =
        CustomerBalancePaymentRepository(database);
    remittanceRepository = RemittanceRepository(database);
    expenseRepository = ExpenseRepository(database);
    groceryStockRepository = GroceryStockRepository(database);
    groceryStockCategoryRepository = GroceryStockCategoryRepository(database);
    laundryStockRepository = LaundryStockRepository(database);
    laundryServiceRepository = LaundryServiceRepository(database);
    laundryOrderRepository = LaundryOrderRepository(database);
    saleRepository = SaleRepository(database);
    saleItemRepository = SaleItemRepository(database);
  }

  Future<double> getDashboardTarget(String name) async {
    final database = await this.database;
    final rows = await database.query('dashboard_targets',
        where: 'name = ?', whereArgs: [name], limit: 1);
    if (rows.isEmpty) {
      return 0;
    }
    return (rows.first['daily_target'] as num).toDouble();
  }

  Future<void> saveDashboardTarget(String name, double dailyTarget) async {
    final database = await this.database;
    final existing = await database.query('dashboard_targets',
        where: 'name = ?', whereArgs: [name], limit: 1);
    if (existing.isEmpty) {
      await database.insert(
          'dashboard_targets', {'name': name, 'daily_target': dailyTarget});
    } else {
      await database.update('dashboard_targets', {'daily_target': dailyTarget},
          where: 'name = ?', whereArgs: [name]);
    }
  }

  Future<void> _createTables(Database database, int version) async {
    await database.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      account_name TEXT NOT NULL UNIQUE,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'staff',
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ''');
    await database.execute('''
      CREATE TABLE funds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        current_balance REAL NOT NULL DEFAULT 0,
        fund_type TEXT NOT NULL,
        archived_at TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        contact_number TEXT,
        id_picture_path TEXT,
        status TEXT NOT NULL DEFAULT 'standard',
        current_balance REAL NOT NULL DEFAULT 0,
        archived_at TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE customer_balance_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        sale_id INTEGER,
        laundry_order_id INTEGER,
        amount REAL NOT NULL DEFAULT 0,
        payment_type TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'grocery',
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE SET NULL,
        FOREIGN KEY (laundry_order_id) REFERENCES laundry_orders(id) ON DELETE SET NULL
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
        notes TEXT,
        archived_at TEXT
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
        notes TEXT,
        archived_at TEXT
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
        notes TEXT,
        archived_at TEXT
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
        sold_at TEXT NOT NULL,
        archived_at TEXT
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
    await database.execute('''
      CREATE TABLE laundry_stock_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name TEXT NOT NULL,
        stock_number TEXT NOT NULL,
        quantity_in_stock INTEGER NOT NULL DEFAULT 0,
        capital_price REAL NOT NULL DEFAULT 0,
        retail_price REAL NOT NULL DEFAULT 0,
        minimum_alert_quantity INTEGER NOT NULL DEFAULT 0,
        picture_path TEXT,
        category TEXT NOT NULL DEFAULT 'General',
        notes TEXT,
        archived_at TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE laundry_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference_number TEXT NOT NULL,
        customer_id INTEGER,
        is_walk_in INTEGER NOT NULL DEFAULT 1,
        customer_name TEXT NOT NULL,
        customer_contact TEXT,
        weight_kg REAL NOT NULL DEFAULT 0,
        clothes_count INTEGER NOT NULL DEFAULT 0,
        laundry_base_amount REAL NOT NULL DEFAULT 0,
        service_add_ons TEXT,
        service_add_on_item_ids TEXT,
        add_ons TEXT,
        add_on_item_ids TEXT,
        add_on_total REAL NOT NULL DEFAULT 0,
        paid_add_ons TEXT,
        paid_add_on_item_ids TEXT,
        amount_payable REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        change_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        item_image_path TEXT,
        pickup_proof_image_path TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE laundry_service_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        max_weight_kg REAL NOT NULL DEFAULT 1,
        add_on_item_ids TEXT,
        notes TEXT,
        archived_at TEXT
      )
    ''');
  }

  Future<void> _upgradeDatabase(
      Database database, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await database.execute(
          "ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'staff'");
      await database.execute(
          "UPDATE users SET role = 'admin' WHERE email = 'admin@example.com'");
    }
    if (oldVersion < 3) {
      await database.update(
        'users',
        {'password_hash': PasswordHasher.hash(DatabaseSeeder.ownerPassword)},
        where: 'email = ? OR email = ? OR account_name = ?',
        whereArgs: [
          'admin@example.com',
          DatabaseSeeder.ownerAccountName,
          DatabaseSeeder.ownerAccountName
        ],
      );
    }
    if (oldVersion < 4) {
      await database
          .execute("UPDATE users SET role = 'owner' WHERE role = 'admin'");
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
      await database.execute(
          'ALTER TABLE expenses ADD COLUMN fund_id INTEGER NOT NULL DEFAULT 1');
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
    if (oldVersion < 13) {
      await _ensureColumn(
          database, 'users', 'account_name', "TEXT NOT NULL DEFAULT ''");
      await _ensureColumn(
          database, 'users', 'is_active', 'INTEGER NOT NULL DEFAULT 1');
      await database.execute(
          "UPDATE users SET account_name = LOWER(email) WHERE (account_name IS NULL OR account_name = '') AND email IS NOT NULL");
      await database.execute(
          "UPDATE users SET account_name = '${DatabaseSeeder.ownerAccountName}' WHERE LOWER(email) = 'admin@example.com'");
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
    if (oldVersion < 12) {
      await database.execute(
          "ALTER TABLE customers ADD COLUMN status TEXT NOT NULL DEFAULT 'standard'");
      await database.execute(
          'ALTER TABLE customers ADD COLUMN current_balance REAL NOT NULL DEFAULT 0');
      await database.execute('''
        CREATE TABLE IF NOT EXISTS customer_balance_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          sale_id INTEGER,
          amount REAL NOT NULL DEFAULT 0,
          payment_type TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
          FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE SET NULL
        )
      ''');
      await database.execute(
          "ALTER TABLE sales ADD COLUMN outstanding_balance REAL NOT NULL DEFAULT 0");
      await database.execute(
          "ALTER TABLE sales ADD COLUMN is_credit_sale INTEGER NOT NULL DEFAULT 0");
    }
    if (oldVersion < 14) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS laundry_stock_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_name TEXT NOT NULL,
          stock_number TEXT NOT NULL,
          quantity_in_stock INTEGER NOT NULL DEFAULT 0,
          capital_price REAL NOT NULL DEFAULT 0,
          retail_price REAL NOT NULL DEFAULT 0,
          minimum_alert_quantity INTEGER NOT NULL DEFAULT 0,
          picture_path TEXT,
          category TEXT NOT NULL DEFAULT 'General',
          notes TEXT
        )
      ''');
      await database.execute('''
        CREATE TABLE IF NOT EXISTS laundry_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reference_number TEXT NOT NULL,
          customer_id INTEGER,
          is_walk_in INTEGER NOT NULL DEFAULT 1,
          customer_name TEXT NOT NULL,
          customer_contact TEXT,
          weight_kg REAL NOT NULL DEFAULT 0,
          clothes_count INTEGER NOT NULL DEFAULT 0,
          laundry_base_amount REAL NOT NULL DEFAULT 0,
          add_ons TEXT,
          add_on_item_ids TEXT,
          add_on_total REAL NOT NULL DEFAULT 0,
          amount_payable REAL NOT NULL DEFAULT 0,
          amount_paid REAL NOT NULL DEFAULT 0,
          change_amount REAL NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'pending',
          pickup_proof_image_path TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 15) {
      await _ensureColumn(database, 'laundry_orders', 'customer_id', 'INTEGER');
      await _ensureColumn(database, 'laundry_orders', 'is_walk_in',
          'INTEGER NOT NULL DEFAULT 1');
      await _ensureColumn(database, 'laundry_orders', 'laundry_base_amount',
          'REAL NOT NULL DEFAULT 0');
      await _ensureColumn(
          database, 'laundry_orders', 'add_on_item_ids', 'TEXT');
      await _ensureColumn(database, 'laundry_orders', 'add_on_total',
          'REAL NOT NULL DEFAULT 0');
      await _ensureColumn(
          database, 'laundry_orders', 'pickup_proof_image_path', 'TEXT');
      await database.execute('''
        UPDATE laundry_orders
        SET laundry_base_amount = amount_payable
        WHERE laundry_base_amount = 0 AND amount_payable > 0
      ''');
    }
    if (oldVersion < 16) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS laundry_service_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          price REAL NOT NULL DEFAULT 0,
          max_weight_kg REAL NOT NULL DEFAULT 1,
          add_on_item_ids TEXT,
          notes TEXT
        )
      ''');
      await _ensureColumn(database, 'laundry_orders', 'service_id', 'INTEGER');
      await _ensureColumn(database, 'laundry_orders', 'service_name', 'TEXT');
    }
    if (oldVersion < 17) {
      await _ensureColumn(
          database, 'laundry_orders', 'service_add_ons', 'TEXT');
      await _ensureColumn(
          database, 'laundry_orders', 'service_add_on_item_ids', 'TEXT');
      await _ensureColumn(database, 'laundry_orders', 'paid_add_ons', 'TEXT');
      await _ensureColumn(
          database, 'laundry_orders', 'paid_add_on_item_ids', 'TEXT');
    }
    if (oldVersion < 18) {
      await _ensureColumn(
          database, 'customer_balance_payments', 'laundry_order_id', 'INTEGER');
      await _ensureColumn(database, 'customer_balance_payments', 'source',
          "TEXT NOT NULL DEFAULT 'grocery'");
    }
    if (oldVersion < 19) {
      await _ensureColumn(database, 'customers', 'archived_at', 'TEXT');
      await _ensureColumn(database, 'funds', 'archived_at', 'TEXT');
      await _ensureColumn(database, 'expenses', 'archived_at', 'TEXT');
      await _ensureColumn(database, 'remittances', 'archived_at', 'TEXT');
      await _ensureColumn(database, 'grocery_stock_items', 'archived_at', 'TEXT');
      await _ensureColumn(database, 'laundry_stock_items', 'archived_at', 'TEXT');
      await _ensureColumn(database, 'laundry_service_items', 'archived_at', 'TEXT');
      await _ensureColumn(database, 'laundry_orders', 'archived_at', 'TEXT');
      await _ensureColumn(database, 'sales', 'archived_at', 'TEXT');
    }
    if (oldVersion < 20) {
      await _ensureColumn(database, 'laundry_service_items', 'max_weight_kg',
          'REAL NOT NULL DEFAULT 1');
    }
  }
}
