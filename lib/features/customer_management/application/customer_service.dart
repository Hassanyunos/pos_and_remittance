import '../../../core/database/app_database.dart';
import '../data/models/customer.dart';

class CustomerService {
  CustomerService._();
  static final CustomerService instance = CustomerService._();

  Future<List<Customer>> getCustomers() async {
    await AppDatabase.instance.database;
    return AppDatabase.instance.customerRepository.getAll();
  }

  Future<Customer?> getCustomer(int id) async {
    await AppDatabase.instance.database;
    return AppDatabase.instance.customerRepository.getById(id);
  }

  Future<Customer> createCustomer({
    required String name,
    String? address,
    String? contactNumber,
    String? idPicturePath,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Customer name is required.');

    final repository = AppDatabase.instance.customerRepository;
    final customer = Customer(
      name: name.trim(),
      address: address?.trim().isEmpty == true ? null : address?.trim(),
      contactNumber: contactNumber?.trim().isEmpty == true ? null : contactNumber?.trim(),
      idPicturePath: idPicturePath,
    );
    return repository.create(customer);
  }

  Future<Customer> updateCustomer({
    required int id,
    required String name,
    String? address,
    String? contactNumber,
    String? idPicturePath,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Customer name is required.');

    final repository = AppDatabase.instance.customerRepository;
    final customer = Customer(
      id: id,
      name: name.trim(),
      address: address?.trim().isEmpty == true ? null : address?.trim(),
      contactNumber: contactNumber?.trim().isEmpty == true ? null : contactNumber?.trim(),
      idPicturePath: idPicturePath,
    );
    return repository.update(customer.copyWith(id: id));
  }

  Future<void> deleteCustomer(int id) async {
    await AppDatabase.instance.database;
    await AppDatabase.instance.customerRepository.delete(id);
  }
}
