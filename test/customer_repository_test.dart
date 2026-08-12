import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_and_remittance/features/customer_management/data/models/customer.dart';
import 'package:pos_and_remittance/features/customer_management/data/repositories/customer_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database database;
  late CustomerRepository repository;

  setUp(() async {
    final databasePath = p.join(await getDatabasesPath(), 'customer_repository_test.db');
    if (await databaseExists(databasePath)) {
      await deleteDatabase(databasePath);
    }
    database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
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
      },
    );
    repository = CustomerRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates, reads, updates, and deletes a customer', () async {
    final created = await repository.create(
      const Customer(
        name: 'Amina Yusuf',
        address: 'Kampala',
        contactNumber: '+256700000000',
        idPicturePath: 'assets/kyc/amina.jpg',
      ),
    );

    expect(created.id, isNotNull);

    final allCustomers = await repository.getAll();
    expect(allCustomers, hasLength(1));
    expect(allCustomers.first.name, 'Amina Yusuf');

    final updated = await repository.update(
      created.copyWith(address: 'Nairobi', contactNumber: '+254700000000'),
    );
    expect(updated.address, 'Nairobi');
    expect(updated.contactNumber, '+254700000000');

    final fetched = await repository.getById(created.id!);
    expect(fetched?.name, 'Amina Yusuf');
    expect(fetched?.address, 'Nairobi');

    await repository.delete(created.id!);
    final remaining = await repository.getAll();
    expect(remaining, isEmpty);
  });

  test('returns customers in alphabetical order by first name', () async {
    await repository.create(const Customer(name: 'Zara Smith'));
    await repository.create(const Customer(name: 'Alice Brown'));
    await repository.create(const Customer(name: 'Bob Green'));

    final customers = await repository.getAll();

    expect(customers.map((customer) => customer.name).toList(), ['Alice Brown', 'Bob Green', 'Zara Smith']);
  });
}
