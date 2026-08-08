import '../../../core/database/app_database.dart';
import '../../fund_management/data/repositories/fund_repository.dart';
import '../data/models/customer.dart';
import '../data/models/customer_balance_payment.dart';

class CustomerBalanceService {
  CustomerBalanceService._();
  static final CustomerBalanceService instance = CustomerBalanceService._();

  Future<List<CustomerBalancePayment>> getPaymentsForCustomer(
      int customerId) async {
    await AppDatabase.instance.database;
    return AppDatabase.instance.customerBalancePaymentRepository!
        .getByCustomerId(customerId);
  }

  Future<Customer> updateCustomerStatus(
      {required int customerId, required CustomerStatus status}) async {
    await AppDatabase.instance.database;
    final repository = AppDatabase.instance.customerRepository!;
    final customer = await repository.getById(customerId);
    if (customer == null) {
      throw ArgumentError('Customer was not found.');
    }
    return repository.update(customer.copyWith(status: status));
  }

  Future<Customer> recordBalancePayment({
    required int customerId,
    required double amount,
    CustomerBalancePaymentSource source = CustomerBalancePaymentSource.grocery,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    await AppDatabase.instance.database;
    final repository = AppDatabase.instance.customerRepository!;
    final paymentRepository =
        AppDatabase.instance.customerBalancePaymentRepository!;
    final fundRepository = AppDatabase.instance.fundRepository!;
    final customer = await repository.getById(customerId);
    if (customer == null) {
      throw ArgumentError('Customer was not found.');
    }

    if (source == CustomerBalancePaymentSource.laundry) {
      throw ArgumentError(
        'Laundry balance payments must be processed from laundry workflow.',
      );
    }

    final remainingBalance = customer.currentBalance > amount
        ? customer.currentBalance - amount
        : 0.0;
    final updatedCustomer = await repository
        .update(customer.copyWith(currentBalance: remainingBalance));
    final funds = await fundRepository.getAll();
    for (final fund in funds) {
      if (fund.name == FundRepository.groceryCashName) {
        await fundRepository.update(
            fund.copyWith(currentBalance: fund.currentBalance + amount));
        break;
      }
    }
    await paymentRepository.create(
      CustomerBalancePayment(
        customerId: customerId,
        amount: amount,
        paymentType: CustomerBalancePaymentType.payment,
        source: source,
        note: note?.trim().isEmpty == true ? null : note?.trim(),
        createdAt: DateTime.now(),
      ),
    );

    return updatedCustomer;
  }
}
