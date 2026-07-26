import 'package:sqflite/sqflite.dart';

import '../models/customer_balance_payment.dart';

class CustomerBalancePaymentRepository {
  CustomerBalancePaymentRepository(this._database);

  static const _tableName = 'customer_balance_payments';
  final Database _database;

  Future<List<CustomerBalancePayment>> getAll() async {
    final maps = await _database.query(_tableName, orderBy: 'created_at DESC, id DESC');
    return maps.map(CustomerBalancePayment.fromMap).toList();
  }

  Future<List<CustomerBalancePayment>> getByCustomerId(int customerId) async {
    final maps = await _database.query(
      _tableName,
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC, id DESC',
    );
    return maps.map(CustomerBalancePayment.fromMap).toList();
  }

  Future<CustomerBalancePayment> create(CustomerBalancePayment payment) async {
    final id = await _database.insert(_tableName, payment.toMap()..remove('id'));
    return payment.copyWith(id: id);
  }

  Future<void> delete(int id) async {
    await _database.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
